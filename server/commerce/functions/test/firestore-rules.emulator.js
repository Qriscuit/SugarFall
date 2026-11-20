import test, {after, before} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {initializeTestEnvironment, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc} from 'firebase/firestore';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';
import {FirestoreCommerceStore} from '../src/firestore-store.js';
import {PACKAGE, PRODUCTS, hashToken} from '../src/service.js';

const projectId = 'demo-sugarfall-commerce';
let environment, app, db, store;
before(async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'This test refuses to contact a real Firestore database');
  environment = await initializeTestEnvironment({projectId, firestore: {
    rules: await fs.readFile(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
  app = initializeApp({projectId}, 'commerce-emulator-test'); db = getFirestore(app);
  store = new FirestoreCommerceStore(db);
});
after(async () => {await environment?.cleanup(); if (app) await deleteApp(app);});

for (const [label, context] of [
  ['unauthenticated', () => environment.unauthenticatedContext()],
  ['anonymous authenticated', () => environment.authenticatedContext('uid-a', {firebase: {sign_in_provider: 'anonymous'}})],
  ['other authenticated', () => environment.authenticatedContext('uid-b')],
]) test(`${label} cannot read, query, create, modify or delete server data`, async () => {
  const client = context().firestore();
  for (const path of ['commercePurchases/example', 'commerceRateLimits/example', 'unrelated/example']) {
    const ref = doc(client, path);
    await assertFails(getDoc(ref)); await assertFails(getDocs(collection(client, path.split('/')[0])));
    await assertFails(setDoc(ref, {status: 'granted', admin: true, token: 'stolen'}));
    await assertFails(updateDoc(ref, {status: 'granted'})); await assertFails(deleteDoc(ref));
  }
});

test('real Firestore transactions retain the Remove Ads option across grant, acknowledgement and restore', async () => {
  const token = 'emulator-remove-ads-token'; const key = hashToken(token);
  const request = {package_name: PACKAGE, product_id: 'remove_ads', purchase_token: token};
  const proof = {purchaseOptionId: 'remove-ads', acknowledged: false};
  await store.acquire(key, request, 'lease-one', 1000);
  await assert.rejects(store.acquire(key, request, 'lease-two', 1001), {code: 'purchase_busy'});
  await store.grant(key, 'lease-one', request, proof, 1002);
  let saved = (await store.purchase(key).get()).data();
  assert.equal(saved.status, 'granted'); assert.equal(saved.acknowledged, false);
  assert.equal(saved.product_id, 'remove_ads'); assert.equal(saved.purchase_option_id, 'remove-ads');
  assert.equal(saved.purchase_token, undefined); assert.equal(saved.uid, undefined);
  const first = saved.first_verified_at.toMillis();
  await store.confirmAcknowledgement(key, 'lease-one', 1003);
  await store.release(key, 'lease-one');
  await store.acquire(key, request, 'restore-with-fresh-uid', 2000);
  await store.grant(key, 'restore-with-fresh-uid', request, {...proof, acknowledged: true}, 2001);
  saved = (await store.purchase(key).get()).data(); assert.equal(saved.first_verified_at.toMillis(), first);
  assert.equal(saved.purchase_option_id, 'remove-ads'); assert.equal(saved.acknowledged, true);
  await assert.rejects(store.deny(key, 'lease-one', 'purchase_cancelled', 2002), {code: 'purchase_busy'});
  await store.deny(key, 'restore-with-fresh-uid', 'purchase_cancelled', 2002);
  assert.equal((await store.purchase(key).get()).data().status, 'denied');
  await store.release(key, 'restore-with-fresh-uid');
  await assert.rejects(store.acquire(key, {...request, product_id: PRODUCTS[1]}, 'wrong-product', 3000), {code: 'purchase_record_mismatch'});
});

test('expired leases cannot overwrite a later request', async () => {
  const key = hashToken('expired-token'); const request = {package_name: PACKAGE, product_id: PRODUCTS[0]};
  await store.acquire(key, request, 'expired', 1000);
  await store.acquire(key, request, 'new', 92000);
  await assert.rejects(store.grant(key, 'expired', request, {purchaseOptionId: 'early-unlock', acknowledged: true}, 92001), {code: 'purchase_busy'});
  await store.release(key, 'expired');
  assert.equal((await store.purchase(key).get()).data().lease_id, 'new');
  await store.release(key, 'new');
});

test('real transaction rate limit is bounded, rolls over and stores no raw UID', async () => {
  const uid = 'rate-uid'; const key = hashToken(uid);
  for (let i = 0; i < 30; i++) await store.rateLimit(key, 10000);
  await assert.rejects(store.rateLimit(key, 10001), {code: 'rate_limited'});
  await store.rateLimit(key, 70000);
  const saved = (await db.collection('commerceRateLimits').doc(key).get()).data();
  assert.equal(saved.requests, 1); assert.equal(JSON.stringify(saved).includes(uid), false);
  assert.ok(saved.expires_at.toMillis() > 70000);
});
