import {createHash, randomUUID} from 'node:crypto';
import {CommerceError, PlayApiError} from './errors.js';

export const PACKAGE = 'com.sungati.sugarfall';
const PURCHASE_OPTIONS = new Map([
  ['sugarfall_bakery_ability', 'early-unlock'],
  ['sugarfall_gelato_ability', 'early-unlock'],
  ['sugarfall_crystal_ability', 'early-unlock'],
  ['remove_ads', 'remove-ads'],
]);
export const PRODUCTS = Object.freeze([...PURCHASE_OPTIONS.keys()]);
export const hashToken = token => createHash('sha256').update(token, 'utf8').digest('hex');
const ACKNOWLEDGED = 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';
const ACK_PENDING = 'ACKNOWLEDGEMENT_STATE_PENDING';

export function validateRequest(body) {
  if (!body || typeof body !== 'object' || Array.isArray(body) ||
      Object.keys(body).sort().join(',') !== 'package_name,product_id,purchase_token') {
    throw new CommerceError('invalid_request');
  }
  if (body.package_name !== PACKAGE || !PRODUCTS.includes(body.product_id)) {
    throw new CommerceError('unsupported_product');
  }
  if (typeof body.purchase_token !== 'string' || body.purchase_token.length < 1 ||
      body.purchase_token.length > 4096 || !/^[\x21-\x7e]+$/.test(body.purchase_token)) {
    throw new CommerceError('invalid_purchase_token');
  }
  return body;
}

export function validatePurchase(purchase, request, auth, allowTestPurchases) {
  const state = purchase?.purchaseStateContext?.purchaseState;
  if (state === 'PENDING') throw new CommerceError('purchase_pending', 409, true, 'pending');
  if (state === 'CANCELLED') throw new CommerceError('purchase_cancelled', 403, false, 'cancelled');
  if (state !== 'PURCHASED') throw new CommerceError('purchase_not_purchased', 403);
  if (purchase.testPurchaseContext && !allowTestPurchases) {
    throw new CommerceError('test_purchase_not_enabled', 403);
  }
  const items = purchase.productLineItem;
  if (!Array.isArray(items) || items.length !== 1 || items[0]?.productId !== request.product_id) {
    throw new CommerceError('purchase_product_mismatch', 403);
  }
  const offer = items[0].productOfferDetails;
  const option = PURCHASE_OPTIONS.get(request.product_id);
  if (!option || !offer || offer.purchaseOptionId !== option || offer.rentOfferDetails ||
      offer.preorderOfferDetails || offer.offerId) {
    throw new CommerceError('purchase_option_mismatch', 403);
  }
  if (offer.quantity !== 1 || offer.refundableQuantity !== 1) {
    throw new CommerceError('purchase_refunded_or_invalid_quantity', 403, false, 'revoked');
  }
  if (offer.consumptionState !== 'CONSUMPTION_STATE_YET_TO_BE_CONSUMED') {
    throw new CommerceError('purchase_consumed_or_unknown', 403, false, 'revoked');
  }
  if (![ACKNOWLEDGED, ACK_PENDING].includes(purchase.acknowledgementState)) {
    throw new CommerceError('purchase_acknowledgement_unknown', 403);
  }
  // This release omits account obfuscation and treats a verified token as a
  // bearer entitlement. A future stable mapping must come from a trusted ID-token
  // custom claim, never a request-body value or a new anonymous UID.
  if (purchase.obfuscatedExternalAccountId || purchase.obfuscatedExternalProfileId) {
    if (!auth.commerce_account_id || purchase.obfuscatedExternalAccountId !== auth.commerce_account_id ||
        purchase.obfuscatedExternalProfileId) {
      throw new CommerceError('purchase_account_mismatch', 403);
    }
  }
  return {purchaseOptionId: option, acknowledged: purchase.acknowledgementState === ACKNOWLEDGED};
}

export function createCommerceService({auth, store, play, allowTestPurchases = false,
  now = () => Date.now(), leaseId = randomUUID}) {
  return async (authorization, body) => {
    const request = validateRequest(body);
    if (typeof authorization !== 'string' || !/^Bearer [A-Za-z0-9._-]+$/.test(authorization) ||
        authorization.length > 8192) throw new CommerceError('unauthenticated', 401);
    let identity;
    try { identity = await auth.verifyIdToken(authorization.slice(7), true); }
    catch { throw new CommerceError('unauthenticated', 401); }
    if (!identity || typeof identity.uid !== 'string' || !identity.uid || identity.uid.length > 128) {
      throw new CommerceError('unauthenticated', 401);
    }
    const key = hashToken(request.purchase_token);
    const lease = leaseId();
    // Request identity throttles anonymous calls; it is not the purchase owner.
    await store.rateLimit(hashToken(identity.uid), now());
    await store.acquire(key, request, lease, now());
    try {
      let purchase;
      try { purchase = await play.getPurchase(PACKAGE, request.purchase_token); }
      catch (error) {
        if (error instanceof PlayApiError && [404, 410].includes(error.status)) {
          await store.deny(key, lease, 'purchase_not_found', now());
          throw new CommerceError('purchase_not_found', 403, false, 'revoked');
        }
        throw new CommerceError('verification_unavailable', 503, true);
      }
      let verified;
      try { verified = validatePurchase(purchase, request, identity, allowTestPurchases); }
      catch (error) {
        // A caller with the wrong stable account cannot revoke somebody else's
        // entitlement. All other authoritative invalid states revoke this token.
        if (error.code !== 'purchase_account_mismatch') await store.deny(key, lease, error.code, now());
        throw error;
      }
      // Required order: Google verification -> durable delivery -> acknowledgement.
      // There is no currency grant, UID-owned copy, consumption or offline fallback.
      await store.grant(key, lease, request, verified, now());
      if (!verified.acknowledged) {
        try { await play.acknowledge(PACKAGE, request.product_id, request.purchase_token); }
        catch { /* Re-read below also resolves an already-acknowledged race. */ }
        let after;
        try { after = await play.getPurchase(PACKAGE, request.purchase_token); }
        catch { throw new CommerceError('acknowledgement_unconfirmed', 503, true); }
        try { verified = validatePurchase(after, request, identity, allowTestPurchases); }
        catch (error) {
          if (error.code !== 'purchase_account_mismatch') await store.deny(key, lease, error.code, now());
          throw error;
        }
        if (!verified.acknowledged) throw new CommerceError('acknowledgement_unconfirmed', 503, true);
        await store.confirmAcknowledgement(key, lease, now());
      }
      return {...request, verified: true, acknowledged: true, purchase_state: 'purchased',
        purchase_option_id: verified.purchaseOptionId, verified_at: now(), revalidate_after_seconds: 300};
    } finally {
      // A failed release never changes delivery/acknowledgement state. The lease
      // expires, so a transient Firestore outage cannot strand the purchase.
      try { await store.release(key, lease); } catch { /* No sensitive logging. */ }
    }
  };
}
