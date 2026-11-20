import {initializeApp, getApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {getFirestore} from 'firebase-admin/firestore';
import {onRequest} from 'firebase-functions/v2/https';
import {defineString, defineBoolean} from 'firebase-functions/params';
import {warn} from 'firebase-functions/logger';
import {GoogleAuth} from 'google-auth-library';
import {GooglePlay, ANDROID_PUBLISHER_SCOPE} from './google-play.js';
import {FirestoreCommerceStore} from './firestore-store.js';
import {createCommerceService} from './service.js';
import {createHttpHandler} from './http.js';

const region = defineString('COMMERCE_REGION');
const serviceAccount = defineString('COMMERCE_SERVICE_ACCOUNT');
const databaseId = defineString('COMMERCE_DATABASE_ID');
const allowTestPurchases = defineBoolean('COMMERCE_ALLOW_TEST_PURCHASES', {default: false});
const emulator = process.env.FUNCTIONS_EMULATOR === 'true';
if (!emulator && (process.env.FIREBASE_AUTH_EMULATOR_HOST || process.env.FIRESTORE_EMULATOR_HOST)) {
  throw new Error('Emulator environment is forbidden for the deployed commerce function');
}
initializeApp();
let service;

export const verifyPurchase = onRequest({region, serviceAccount, invoker: 'public',
  cors: false, timeoutSeconds: 60, memory: '256MiB', minInstances: 0,
  maxInstances: 5, concurrency: 20}, async (req, res) => {
  if (!service) {
    const selectedDatabase = databaseId.value();
    if (!selectedDatabase) throw new Error('COMMERCE_DATABASE_ID must name the confirmed native Firestore database');
    service = createCommerceService({auth: getAuth(getApp()),
      store: new FirestoreCommerceStore(getFirestore(getApp(), selectedDatabase)),
      play: new GooglePlay(new GoogleAuth({scopes: [ANDROID_PUBLISHER_SCOPE]})),
      allowTestPurchases: allowTestPurchases.value()});
  }
  return createHttpHandler(service, {emulator, logFailure: fields => warn('commerce_request_failed', fields)})(req, res);
});
