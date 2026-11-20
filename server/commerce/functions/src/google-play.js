import {PlayApiError} from './errors.js';

const ORIGIN = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/';
export const ANDROID_PUBLISHER_SCOPE = 'https://www.googleapis.com/auth/androidpublisher';

// The caller supplies a GoogleAuth instance using Application Default
// Credentials. No key JSON, user OAuth token or caller-selected URL is accepted.
export class GooglePlay {
  constructor(auth) { this.auth = auth; }

  async request(method, url, data) {
    try {
      const client = await this.auth.getClient();
      const response = await client.request({
        method, url, ...(data === undefined ? {} : {data}),
        timeout: 10000, retry: false,
      });
      return response.data;
    } catch (error) {
      // Google errors can contain a request URL with the bearer purchase token.
      // Deliberately discard the raw error, headers and response body.
      throw new PlayApiError(Number(error?.response?.status) || 0);
    }
  }

  getPurchase(packageName, token) {
    return this.request('GET', ORIGIN + encodeURIComponent(packageName) +
      '/purchases/productsv2/tokens/' + encodeURIComponent(token));
  }

  acknowledge(packageName, productId, token) {
    return this.request('POST', ORIGIN + encodeURIComponent(packageName) +
      '/purchases/products/' + encodeURIComponent(productId) + '/tokens/' +
      encodeURIComponent(token) + ':acknowledge', {});
  }
}
