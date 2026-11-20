export class CommerceError extends Error {
  constructor(code, status = 400, retryable = false, purchaseState = 'unknown') {
    super(code);
    this.code = code;
    this.status = status;
    this.retryable = retryable;
    this.purchaseState = purchaseState;
  }
}

export class PlayApiError extends Error {
  constructor(status) {
    super('google_play_request_failed');
    this.status = status;
  }
}
