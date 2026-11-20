# Sugarfall purchase verification

This Firebase Functions v2 / Node.js 22 backend verifies the three permanent ability unlocks and Remove automatic ads. Deployment, Firebase project and database selection, runtime service account, Play API permission and live purchase verification remain open.

The public package is `com.sungati.sugarfall`. Products `sugarfall_bakery_ability`, `sugarfall_gelato_ability` and `sugarfall_crystal_ability` use the permanent `early-unlock` purchase option. Product `remove_ads` uses the permanent `remove-ads` option. Rentals, preorders, discounted offer IDs, consumed items, multi-quantity purchases, missing fields and refunded quantities fail verification. These products are non-consumable.

## HTTP contract

`POST` to the deployed `verifyPurchase` function over HTTPS, with `Content-Type: application/json` and `Authorization: Bearer <Firebase ID token>`:

```json
{
  "package_name": "com.sungati.sugarfall",
  "product_id": "sugarfall_bakery_ability",
  "purchase_token": "<token from native Google Play owned-purchases query or callback>"
}
```

The three request fields are mandatory and extra fields are rejected. The body is limited to 8 KiB and purchase tokens to 4,096 printable ASCII characters. The Admin SDK validates the ID token's issuer/audience/expiry and checks revocation. Anonymous Firebase Auth is supported.

Only a successful Google verification, durable delivery and confirmed acknowledgement produce HTTP 200:

```json
{
  "package_name": "com.sungati.sugarfall",
  "product_id": "sugarfall_bakery_ability",
  "purchase_token": "<same token>",
  "verified": true,
  "acknowledged": true,
  "purchase_state": "purchased",
  "purchase_option_id": "early-unlock",
  "verified_at": 0,
  "revalidate_after_seconds": 300
}
```

`verified_at` is the server's Unix time in milliseconds; the example zero is not a real verification. Errors return a non-200 status and `verified:false`, `acknowledged:false`, an error code, retryable flag and request ID. Treat pending payment as pending, never owned. Do not accept any result from a local save or purchase-dictionary boolean as this response. Bind the response to the exact package, product and token of the outstanding request.

## Ownership and restore policy

The purchase token is a **bearer credential**, and this first release has no required player account. A fresh anonymous Firebase UID after reinstall can restore the same token after Google verifies it again. Anonymous UID authenticates and throttles requests; it does not establish ownership of the Google Play account. This does not prevent someone who steals a valid token from replaying that permanent entitlement. No claim of protected cross-account binding is made.

Keep tokens private. Send them only in HTTPS request bodies; never in query parameters, logs, analytics, screenshots or crash reports. Firestore stores `SHA256(token)`, not the raw token, and has no client read/write access. No per-UID entitlement copy, consumable balance or repeat reward is minted. Each token maps to one durable record. Leases serialize concurrent verification and fence expired requests.

The app queries native Play owned purchases on launch, on restore and on foreground return, verifies supported products with this endpoint, and refreshes every 240 seconds. The last successful result may remain in memory for at most 300 seconds. A transient verification/network failure can retain that bounded memory grace. Missing Play ownership or an authoritative rejection, refund or revocation removes the entitlement. A cold start restores from Play inventory and fresh verification. Automatic ads in a billing-configured build require fresh confirmed absence of ad removal.

An active run already pins its starting ability state, so a refresh failure does not change airborne gameplay midway. Apply entitlement changes at the game's existing safe boundary. Preserve the exact paid pending checkpoint for a later verified retry. Earned campaign access remains independent of paid access and can remain offline.

Restore is polling: every endpoint call performs a fresh Google GET. A canceled/refunded/consumed purchase marks its token record denied. No RTDN, Pub/Sub webhook, scheduled refund poll or administrative grant endpoint is exposed. A dormant/offline app has no immediate push revocation guarantee. The backend cannot poll stored tokens because it intentionally does not retain their plaintext. This policy must be implemented and tested in the native/Godot adapter before enabling purchases.

Omit `obfuscatedAccountId`/`obfuscatedProfileId` for anonymous purchases. A future stable-account design may set a trusted Firebase custom claim `commerce_account_id`; Google must return that exact obfuscated account ID. Request-body mappings and new anonymous UIDs cannot supply it. Purchases with an unexpected external account/profile ID fail closed and are not silently transferred or used to revoke another account's record.

## Verification and acknowledgement

The runtime identity obtains the Android Publisher OAuth scope through Application Default Credentials and calls Google's `purchases.productsv2.getproductpurchasev2` for the fixed package. It validates the product line, exact option, purchased state, quantity, refundable quantity, unconsumed state and acknowledgement state.

It commits the permanent token entitlement in Firestore **before** calling `purchases.products.acknowledge`. A failed durable write does not acknowledge. After acknowledgement it re-reads Google and only succeeds when acknowledgement is confirmed. A failed/interrupted acknowledgement is retried by calling the same endpoint; delivery stays idempotent. Clients must retain the pending verification attempt securely and retry promptly with bounded backoff, including after process restart. They must not consume the purchase or acknowledge independently. A previously acknowledged purchase is still freshly verified and durably recorded.

Thirty requests per Firebase UID per minute, strict request bounds, a 90-second token lease, 10-second Google call timeouts and five maximum function instances limit routine pressure. Anonymous accounts can be recreated, so this is not a complete abuse or cost-control system. Configure project/API quotas and monitor invalid-request rates before public exposure. The function logs only a generated request ID and safe error code; Google errors and HTTP credentials are not logged by application code.

## Local tests

Use Node.js 22 and pnpm. From `server/commerce/functions`:

```text
pnpm install --frozen-lockfile --ignore-scripts
pnpm test
pnpm run check
pnpm run test:rules
```

The last command starts only a local Firestore emulator under the `demo-sugarfall-commerce` demo project. Java 21 or newer is needed by current emulator tooling. No real project or account is used. It validates deny-all client rules and the actual Admin SDK transaction store. The unit suite injects fake external dependencies for deterministic error cases; the exported production endpoint always uses Admin Auth, Firestore and the real Google API. No Google API fake or environment-based grant bypass is shipped in runtime code.

## Deployment handoff

1. Connect the intended Firebase/Google account and explicitly select or create the actual project. Confirm ownership and cost/billing choices before any creation or deployment. There is no `.firebaserc` or inferred project ID here.
2. Inspect the selected Firestore database edition and ID with `firebase firestore:databases:list --project <confirmed-project-id>` and `firebase firestore:databases:get <confirmed-database-id> --project <confirmed-project-id>`. This source requires the **native Firestore Core transaction API**; it does not target MongoDB compatibility. Point transactions are necessary for lease/rate-limit consistency in either native edition. Set `firestore.database` in `firebase.json` to that same inspected database ID before deployment; the current omitted value is used only for the default **demo emulator** and must not silently select a live database. No database edition or location has been assumed or provisioned.
3. Confirm the Functions region and a dedicated runtime service account. Enable the Android Publisher API in the corresponding Google Cloud project. Invite that service account in Play Console and grant the documented app-level purchase/order verification and acknowledgement permissions for `com.sungati.sugarfall`. The account existing is not proof of permission. Do not download or embed a key: Cloud Functions uses its attached service account through ADC.
4. Give that runtime identity the minimum native Firestore read/write transaction permissions and Firebase Auth user-read permissions needed for revoked-token checks. Enable Firebase Anonymous Auth in the **same** confirmed project and register/configure the Android client. Do not infer Auth/provider setup from SDK installation.
5. Activate the permanent products and options listed above in Play Console and verify their localized pricing and tester eligibility. For license-test purchases, use a test deployment with `COMMERCE_ALLOW_TEST_PURCHASES=true`. Production defaults to false. Both deployments require a Google-verified purchase token.
6. Copy `functions/.env.example` to the confirmed project's local `.env.<project-id>` and supply `COMMERCE_REGION`, `COMMERCE_SERVICE_ACCOUNT` and `COMMERCE_DATABASE_ID` (including literal `(default)` only if that database was inspected). Keep this configuration out of Git. Review the selected project's billing requirements for Functions deployment; no billing plan is activated by this repository.
7. Review and validate the server-only Firestore rules, indexes/TTL and IAM. If the selected project already stores other app data, do not deploy this deny-all rules file over unrelated client rules; merge only the isolated commerce paths with the existing policy and test that combined policy first. Prefer a dedicated commerce database/project when appropriate.
8. After the above account choices and permissions are authorized and verified, run `firebase deploy --project <confirmed-project-id> --only functions:commerce,firestore` from `server/commerce`. This command is documentation, not an executed deployment. Record the returned HTTPS function URL in the Godot provider config and verify its identity from actual deployment output.
9. Test a real Play license purchase, duplicate callback, fresh-UID reinstall restore, pending/cancelled payment, missing Google permission, storage outage before acknowledgement, acknowledgement retry, refund/revocation, offline expiry and an interrupted restore. Confirm no token/credential appears in logs. No AAB or source-only test establishes those live results.

## Primary references

- [Google purchase v2 fields](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2)
- [Purchase v2 GET](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.productsv2/getproductpurchasev2)
- [Product acknowledgement](https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.products/acknowledge)
- [Google purchase verification and replay guidance](https://developer.android.com/google/play/billing/security)
- [Firebase ID-token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens)
- [Firebase HTTP functions](https://firebase.google.com/docs/functions/http-events)
- [Node.js runtime configuration](https://firebase.google.com/docs/functions/manage-functions)
- [Firestore transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)
- [Google buildpack pnpm lockfile support](https://docs.cloud.google.com/docs/buildpacks/nodejs)

The included Firestore rules are a server-only prototype: all client reads and writes are denied, and backend IAM must be reviewed separately. Review the actual project's rules and validate the deployed policy before broad release. Local emulator success is not a live payment or production security audit.
