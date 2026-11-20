import test from 'node:test';
import assert from 'node:assert/strict';
import {createCommerceService, PACKAGE, PRODUCTS, hashToken} from '../src/service.js';
import {CommerceError, PlayApiError} from '../src/errors.js';
import {GooglePlay} from '../src/google-play.js';
import {createHttpHandler} from '../src/http.js';

const token = 'opaque-google-play-purchase-token-for-test';
const request = product => ({package_name: PACKAGE, product_id: product, purchase_token: token});
const purchaseOption = product => product === 'remove_ads' ? 'remove-ads' : 'early-unlock';
function validPurchase(product = PRODUCTS[0]) {
  return {purchaseStateContext: {purchaseState: 'PURCHASED'},
    acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
    productLineItem: [{productId: product, productOfferDetails: {purchaseOptionId: purchaseOption(product),
      quantity: 1, refundableQuantity: 1, consumptionState: 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED'}}]};
}

class MemoryStore {
  records = new Map();
  events = [];
  rates = [];
  async rateLimit(uid) { this.rates.push(uid); }
  async acquire(key, body, lease) {
    const old = this.records.get(key) || {};
    if (old.lease) throw new CommerceError('purchase_busy', 409, true);
    if (old.product_id && old.product_id !== body.product_id) throw new CommerceError('purchase_record_mismatch', 409);
    this.records.set(key, {...old, lease});
  }
  async grant(key, lease, body, {purchaseOptionId, acknowledged}, now) {
    if (this.failGrant) throw new Error('storage failed');
    const old = this.records.get(key);
    assert.equal(old.lease, lease);
    this.events.push('grant');
    this.records.set(key, {...old, product_id: body.product_id, purchase_option_id: purchaseOptionId, status: 'granted',
      acknowledged, first_verified_at: old.first_verified_at || now});
  }
  async deny(key, lease, reason) { this.events.push('deny'); Object.assign(this.records.get(key), {status: 'denied', reason, acknowledged: false}); }
  async confirmAcknowledgement(key) { this.events.push('confirmed'); this.records.get(key).acknowledged = true; }
  async release(key, lease) { const value = this.records.get(key); if (value?.lease === lease) delete value.lease; }
}

function fixture(product = PRODUCTS[0], allowTestPurchases = false) {
  const store = new MemoryStore();
  const f = {store, purchase: validPurchase(product), uid: 'first-anonymous-uid', calls: [], claim: {}};
  const play = {
    async getPurchase(pkg, value) {
      assert.equal(pkg, PACKAGE); assert.equal(value, token); f.calls.push('get');
      if (f.getError) throw f.getError;
      if (f.wait) await f.wait;
      return structuredClone(f.purchase);
    },
    async acknowledge(pkg, id, value) {
      assert.equal(pkg, PACKAGE); assert.equal(id, product); assert.equal(value, token);
      assert.equal(store.records.get(hashToken(token))?.status, 'granted', 'delivery is durable before Google acknowledgement');
      f.calls.push('ack');
      if (f.ackError) throw new Error('ack failed');
      f.purchase.acknowledgementState = 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';
    },
  };
  const auth = {async verifyIdToken(value, checkRevoked) {
    assert.equal(value, 'firebase.id.token'); assert.equal(checkRevoked, true);
    if (f.authError) throw new Error('invalid');
    return {uid: f.uid, firebase: {sign_in_provider: 'anonymous'}, ...f.claim};
  }};
  f.service = createCommerceService({store, auth, play, now: () => 100000,
    allowTestPurchases});
  f.run = () => f.service('Bearer firebase.id.token', request(product));
  return f;
}

test('only the Play Console package can reach the Google purchase API', async () => {
  assert.equal(PACKAGE, 'com.sungati.sugarfall');
  const f = fixture();
  for (const packageName of ['com.qriscuit.sugarfall', 'org.pegfoundry.prototype.preview']) {
    await assert.rejects(f.service('Bearer firebase.id.token', {
      ...request(PRODUCTS[0]), package_name: packageName,
    }), {code: 'unsupported_product'});
  }
  assert.deepEqual(f.calls, []);
  assert.equal(f.store.records.size, 0);
});

for (const product of PRODUCTS) test(`durable ${product} delivery precedes acknowledgement`, async () => {
  const f = fixture(product); const result = await f.run();
  assert.equal(result.verified, true); assert.equal(result.acknowledged, true);
  assert.equal(result.purchase_state, 'purchased'); assert.equal(result.purchase_option_id, purchaseOption(product));
  assert.equal(result.package_name, PACKAGE); assert.equal(result.product_id, product);
  assert.equal(result.purchase_token, token); assert.equal(result.revalidate_after_seconds, 300);
  assert.deepEqual(f.calls, ['get', 'ack', 'get']);
  assert.deepEqual(f.store.events, ['grant', 'confirmed']);
});

test('Remove Ads requires its own permanent option and restores by the Play token', async () => {
  const f = fixture('remove_ads');
  f.purchase.productLineItem[0].productOfferDetails.purchaseOptionId = 'early-unlock';
  await assert.rejects(f.run(), {code: 'purchase_option_mismatch'});
  assert.deepEqual(f.calls, ['get']);
  f.purchase.productLineItem[0].productOfferDetails.purchaseOptionId = 'remove-ads';
  assert.equal((await f.run()).acknowledged, true);
  f.uid = 'fresh-anonymous-after-reinstall';
  const restored = await f.run();
  assert.equal(restored.product_id, 'remove_ads');
  assert.equal(restored.purchase_option_id, 'remove-ads');
  assert.equal(f.store.records.size, 1);
  assert.equal(f.store.records.get(hashToken(token)).purchase_option_id, 'remove-ads');
  assert.deepEqual(f.store.events, ['deny', 'grant', 'confirmed', 'grant']);
  assert.deepEqual(f.calls, ['get', 'get', 'ack', 'get', 'get']);
});

test('same token restores after reinstall with a fresh anonymous UID and no per-user reward', async () => {
  const f = fixture(); await f.run(); const first = f.store.records.get(hashToken(token)).first_verified_at;
  f.uid = 'fresh-anonymous-after-reinstall'; await f.run();
  assert.equal(f.store.records.size, 1);
  assert.equal(f.store.records.get(hashToken(token)).first_verified_at, first);
  assert.deepEqual(f.calls, ['get', 'ack', 'get', 'get']);
  assert.notEqual(f.store.rates[0], f.store.rates[1]);
  assert.equal(JSON.stringify([...f.store.records.values()]).includes(token), false);
  assert.equal(JSON.stringify([...f.store.records.values()]).includes(f.uid), false);
});

test('concurrent token verification uses a lease instead of double delivery', async () => {
  const f = fixture(); let resume; f.wait = new Promise(resolve => { resume = resolve; });
  const first = f.run(); await new Promise(resolve => setImmediate(resolve));
  await assert.rejects(f.run(), {code: 'purchase_busy'}); resume(); await first;
  assert.equal(f.calls.filter(x => x === 'ack').length, 1);
});

test('failed durable write cannot acknowledge a purchase', async () => {
  const f = fixture(); f.store.failGrant = true;
  await assert.rejects(f.run()); assert.deepEqual(f.calls, ['get']);
  assert.equal(f.store.records.get(hashToken(token)).lease, undefined);
});

test('unconfirmed acknowledgement fails closed and is recoverable on retry', async () => {
  const f = fixture(); f.ackError = true;
  await assert.rejects(f.run(), {code: 'acknowledgement_unconfirmed'});
  assert.equal(f.store.records.get(hashToken(token)).acknowledged, false);
  f.ackError = false; assert.equal((await f.run()).acknowledged, true);
  assert.equal(f.store.records.size, 1);
});

const invalid = [
  ['pending', p => {p.purchaseStateContext.purchaseState = 'PENDING';}, 'purchase_pending'],
  ['cancelled', p => {p.purchaseStateContext.purchaseState = 'CANCELLED';}, 'purchase_cancelled'],
  ['unspecified', p => {p.purchaseStateContext.purchaseState = 'PURCHASE_STATE_UNSPECIFIED';}, 'purchase_not_purchased'],
  ['wrong product', p => {p.productLineItem[0].productId = PRODUCTS[1];}, 'purchase_product_mismatch'],
  ['multiple items', p => {p.productLineItem.push(structuredClone(p.productLineItem[0]));}, 'purchase_product_mismatch'],
  ['missing option', p => {delete p.productLineItem[0].productOfferDetails.purchaseOptionId;}, 'purchase_option_mismatch'],
  ['rental', p => {p.productLineItem[0].productOfferDetails.rentOfferDetails = {};}, 'purchase_option_mismatch'],
  ['preorder', p => {p.productLineItem[0].productOfferDetails.preorderOfferDetails = {};}, 'purchase_option_mismatch'],
  ['discount offer', p => {p.productLineItem[0].productOfferDetails.offerId = 'unrelated-discount';}, 'purchase_option_mismatch'],
  ['multiple quantity', p => {p.productLineItem[0].productOfferDetails.quantity = 2;}, 'purchase_refunded_or_invalid_quantity'],
  ['refunded', p => {p.productLineItem[0].productOfferDetails.refundableQuantity = 0;}, 'purchase_refunded_or_invalid_quantity'],
  ['consumed', p => {p.productLineItem[0].productOfferDetails.consumptionState = 'CONSUMPTION_STATE_CONSUMED';}, 'purchase_consumed_or_unknown'],
  ['unknown ack', p => {delete p.acknowledgementState;}, 'purchase_acknowledgement_unknown'],
  ['test purchase in production', p => {p.testPurchaseContext = {fopType: 'TEST'};}, 'test_purchase_not_enabled'],
];
for (const [label, mutate, code] of invalid) test(`${label} never grants or acknowledges`, async () => {
  const f = fixture(); mutate(f.purchase);
  await assert.rejects(f.run(), {code}); assert.equal(f.store.events.includes('grant'), false);
  assert.deepEqual(f.calls, ['get']); assert.equal(f.store.records.get(hashToken(token)).status, 'denied');
});

test('a later refund revokes the token record during restore', async () => {
  const f = fixture(); await f.run(); f.purchase.productLineItem[0].productOfferDetails.refundableQuantity = 0;
  await assert.rejects(f.run(), {code: 'purchase_refunded_or_invalid_quantity'});
  assert.equal(f.store.records.get(hashToken(token)).status, 'denied');
});

test('explicit test deployment still requires Google purchased state and full verification', async () => {
  const f = fixture(PRODUCTS[0], true); f.purchase.testPurchaseContext = {fopType: 'TEST'};
  assert.equal((await f.run()).verified, true);
  assert.deepEqual(f.calls, ['get', 'ack', 'get']);
  f.purchase.purchaseStateContext.purchaseState = 'PENDING';
  await assert.rejects(f.run(), {code: 'purchase_pending'});
});

test('transient Google errors never become a grant or expose API error detail', async () => {
  const f = fixture(); f.getError = new PlayApiError(503);
  await assert.rejects(f.run(), {code: 'verification_unavailable', retryable: true});
  assert.equal(f.store.events.includes('grant'), false);
  f.getError = new PlayApiError(404); await assert.rejects(f.run(), {code: 'purchase_not_found'});
  assert.equal(f.store.records.get(hashToken(token)).status, 'denied');
});

test('future stable account IDs require a trusted custom claim and never bind the anonymous UID', async () => {
  const f = fixture(); f.purchase.obfuscatedExternalAccountId = 'stable-trusted-account';
  await assert.rejects(f.run(), {code: 'purchase_account_mismatch'});
  assert.equal(f.store.events.includes('deny'), false);
  f.claim.commerce_account_id = 'stable-trusted-account'; assert.equal((await f.run()).verified, true);
});

test('revoked/missing auth and body-supplied proof are rejected before Google', async () => {
  const f = fixture(); f.authError = true;
  await assert.rejects(f.run(), {code: 'unauthenticated'});
  await assert.rejects(f.service('', request(PRODUCTS[0])), {code: 'unauthenticated'});
  await assert.rejects(f.service('Bearer firebase.id.token', {...request(PRODUCTS[0]), verified: true}), {code: 'invalid_request'});
  await assert.rejects(f.service('Bearer firebase.id.token', {...request(PRODUCTS[0]), package_name: 'other.package'}), {code: 'unsupported_product'});
  for (const value of ['', 'has space', '\n', 'x'.repeat(4097)]) {
    await assert.rejects(f.service('Bearer firebase.id.token', {...request(PRODUCTS[0]), purchase_token: value}), {code: 'invalid_purchase_token'});
  }
  assert.deepEqual(f.calls, []);
});

test('Google adapter uses exact fixed-origin v2 GET and product acknowledge paths', async () => {
  const calls = []; const api = new GooglePlay({async getClient() {return {async request(options) {calls.push(options); return {data: {ok: true}};}};}});
  await api.getPurchase(PACKAGE, 'opaque/with?reserved'); await api.acknowledge(PACKAGE, PRODUCTS[0], token);
  assert.equal(calls[0].method, 'GET'); assert.equal(calls[0].data, undefined);
  assert.match(calls[0].url, /\/purchases\/productsv2\/tokens\/opaque%2Fwith%3Freserved$/);
  assert.match(calls[1].url, /\/purchases\/products\/sugarfall_bakery_ability\/tokens\/.*:acknowledge$/);
  assert.deepEqual(calls[1].data, {}); assert.equal(calls[0].retry, false);
  const broken = new GooglePlay({async getClient() {return {async request() {throw {response: {status: 403}, message: token, config: {url: token}};}};}});
  await assert.rejects(broken.getPurchase(PACKAGE, token), error => error.status === 403 && !JSON.stringify(error).includes(token));
});

function response() {return {headers: {}, set(k,v) {this.headers[k]=v;}, status(v) {this.code=v; return this;}, json(v) {this.body=v;}};}
function httpRequest(extra = {}) {return {method: 'POST', path: '/', secure: true, body: request(PRODUCTS[0]),
  rawBody: Buffer.from('{}'), get(name) {return {'content-type': 'application/json', authorization: 'Bearer firebase.id.token'}[name];}, ...extra};}

test('HTTP failures redact credentials and prevent cache storage', async () => {
  const logs = []; const handler = createHttpHandler(async () => {throw new Error(token);}, {logFailure: value => logs.push(value)});
  const res = response(); await handler(httpRequest(), res);
  assert.equal(res.code, 503); assert.equal(res.body.verified, false); assert.equal(res.body.acknowledged, false);
  assert.equal(res.headers['Cache-Control'], 'no-store'); assert.equal(res.headers['Retry-After'], '5');
  assert.equal(JSON.stringify({logs, body: res.body}).includes(token), false);
});

test('HTTP bounds/method/TLS/content-type reject before the verifier runs', async () => {
  let calls = 0; const handler = createHttpHandler(async () => {calls++;});
  const bad = [[{method: 'GET'},405], [{path: '/other'},404], [{secure: false},400],
    [{get: () => 'text/plain'},415], [{rawBody: Buffer.alloc(8193)},413]];
  for (const [extra, status] of bad) {const res = response(); await handler(httpRequest(extra),res); assert.equal(res.code,status);}
  assert.equal(calls, 0);
});
