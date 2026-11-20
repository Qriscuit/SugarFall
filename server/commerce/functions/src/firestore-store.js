import {CommerceError} from './errors.js';

const LEASE_MS = 90000;
const WINDOW_MS = 60000;
const MAX_REQUESTS = 30;

export class FirestoreCommerceStore {
  constructor(db) { this.db = db; }
  purchase(key) { return this.db.collection('commercePurchases').doc(key); }

  async rateLimit(uidHash, now) {
    const ref = this.db.collection('commerceRateLimits').doc(uidHash);
    await this.db.runTransaction(async tx => {
      const old = (await tx.get(ref)).data() || {};
      const sameWindow = Number.isFinite(old.window_start_ms) && now >= old.window_start_ms &&
        now - old.window_start_ms < WINDOW_MS;
      const count = sameWindow ? old.requests : 0;
      if (count >= MAX_REQUESTS) throw new CommerceError('rate_limited', 429, true);
      tx.set(ref, {window_start_ms: sameWindow ? old.window_start_ms : now,
        requests: count + 1, expires_at: new Date(now + 86400000)});
    });
  }

  async acquire(key, request, lease, now) {
    const ref = this.purchase(key);
    await this.db.runTransaction(async tx => {
      const old = (await tx.get(ref)).data() || {};
      if (old.product_id && (old.product_id !== request.product_id || old.package_name !== request.package_name)) {
        throw new CommerceError('purchase_record_mismatch', 409);
      }
      if (old.lease_id && old.lease_until_ms > now) throw new CommerceError('purchase_busy', 409, true);
      tx.set(ref, {lease_id: lease, lease_until_ms: now + LEASE_MS}, {merge: true});
    });
  }

  async change(key, lease, now, update) {
    const ref = this.purchase(key);
    await this.db.runTransaction(async tx => {
      const old = (await tx.get(ref)).data() || {};
      if (old.lease_id !== lease || old.lease_until_ms <= now) {
        throw new CommerceError('purchase_busy', 409, true);
      }
      tx.set(ref, update(old), {merge: true});
    });
  }

  grant(key, lease, request, {purchaseOptionId, acknowledged}, now) {
    return this.change(key, lease, now, old => ({token_hash: key,
      package_name: request.package_name, product_id: request.product_id,
      purchase_option_id: purchaseOptionId, status: 'granted', acknowledged,
      first_verified_at: old.first_verified_at || new Date(now), verified_at: new Date(now),
      reason: null}));
  }

  deny(key, lease, reason, now) {
    return this.change(key, lease, now, () => ({status: 'denied', acknowledged: false,
      reason, verified_at: new Date(now)}));
  }

  confirmAcknowledgement(key, lease, now) {
    return this.change(key, lease, now, () => ({acknowledged: true, verified_at: new Date(now)}));
  }

  async release(key, lease) {
    const ref = this.purchase(key);
    await this.db.runTransaction(async tx => {
      const old = (await tx.get(ref)).data();
      if (old?.lease_id === lease) tx.set(ref, {lease_id: null, lease_until_ms: 0}, {merge: true});
    });
  }
}
