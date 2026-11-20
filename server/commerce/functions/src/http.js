import {randomUUID} from 'node:crypto';
import {CommerceError} from './errors.js';

export function createHttpHandler(service, {emulator = false, logFailure = () => {}} = {}) {
  return async (req, res) => {
    const requestId = randomUUID();
    res.set('Cache-Control', 'no-store');
    res.set('X-Content-Type-Options', 'nosniff');
    res.set('X-Request-Id', requestId);
    try {
      if (req.method !== 'POST') throw new CommerceError('method_not_allowed', 405);
      if (req.path && req.path !== '/') throw new CommerceError('not_found', 404);
      if (!emulator && !req.secure && req.get('x-forwarded-proto') !== 'https') {
        throw new CommerceError('https_required', 400);
      }
      if (!/^application\/json(?:;|$)/i.test(req.get('content-type') || '')) {
        throw new CommerceError('json_required', 415);
      }
      if ((req.rawBody?.length || 0) > 8192 || Number(req.get('content-length') || 0) > 8192) {
        throw new CommerceError('request_too_large', 413);
      }
      const value = await service(req.get('authorization'), req.body);
      res.status(200).json(value);
    } catch (error) {
      const safe = error instanceof CommerceError ? error : new CommerceError('verification_unavailable', 503, true);
      // Never pass the error object, request body, headers, UID or Google URL.
      logFailure({request_id: requestId, code: safe.code});
      if (safe.retryable) res.set('Retry-After', safe.status === 429 ? '60' : '5');
      res.status(safe.status).json({verified: false, acknowledged: false,
        purchase_state: safe.purchaseState, error: safe.code, retryable: safe.retryable,
        request_id: requestId});
    }
  };
}
