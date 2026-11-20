# Native permanent ability purchases

The Android project vendors the official GodotGooglePlayBilling 3.3.0 plugin under `addons/GodotGooglePlayBilling`. Its release and debug AARs are present. The plugin exports the Maven dependency `com.android.billingclient:billing-ktx:9.1.0`. Upstream source files and AARs are unmodified. `NATIVE_BILLING_PLUGIN.json` records the archive digest, per-file hashes and MIT license. The archive SHA-256 matches the digest published with the official GitHub release.

The ability products `sugarfall_bakery_ability`, `sugarfall_gelato_ability` and `sugarfall_crystal_ability` use the permanent base purchase option `early-unlock`. US$2.99 is the design price for each ability. **Remove automatic ads** uses product `remove_ads` and permanent base purchase option `remove-ads`. Checkout uses Google Play's fetched localized price. These products are never consumed, and pending payments never grant access.

## Application integration

Configure `ability_ui.billing.configure_backend(verifier, obfuscated_account_id, obfuscated_profile_id)` before `ability_ui.setup_store()`. The verifier is an authenticated asynchronous application adapter. Account identifiers must be obfuscated, at most 64 characters, and must not be email addresses. Reconfiguring the same verifier/account preserves verified rights. Changing account identity invalidates previous rights and in-flight results.

The verifier receives `package_name`, `product_id`, `purchase_token`, `obfuscated_account_id` and `obfuscated_profile_id`. Its successful response must echo the exact package, product and token and include `verified: true`, `acknowledged: true` and `purchase_state: "purchased"`. Firebase anonymous authentication protects and rate-limits the API. The backend validates the permanent Play token with Google, fulfills idempotently by token and acknowledges delivery. The first release treats a valid Play token as the bearer proof for a permanent entitlement; it can restore under a fresh anonymous UID after reinstall. It does not grant consumable currency. Client purchase dictionaries and saved booleans cannot substitute for that verification. The first release sends empty obfuscated account/profile IDs so anonymous installation identity cannot prevent legitimate reinstall restoration. The developer account email is not a player credential.

The provider exposes:

- `initial_restore_finished()` for the initial restore barrier.
- `restore_status()` with `phase`, `initial_finished`, `restoring`, `success`, `configured`, `has_verified_inventory`, `verifying` and `error`.
- `restore_state_changed(status)` and `restore_finished(success, message)` signals.
- `can_restore()` and `needs_restore(product_id)` for retry UI.
- `has_authoritative_absence(product_id)` for fresh verified absence and `has_authoritative_revocation(product_id)` for a request-bound terminal denial; proof expiration alone is never revocation.

A missing verifier or native plugin fails closed and finishes the initial barrier with an error. Startup must retain a saved paid run while waiting for verification, rather than rejecting it as an unowned checkpoint. A native query that never returns requires the application's bounded startup/retry handling; no entitlement is inferred from timeout.

## Refresh and purchase behavior

A refresh retains already verified in-memory rights while token verification runs, up to their existing deadline. Successful responses require `revalidate_after_seconds` and `verified_at`; only a verified callback starts a new local monotonic lifetime, capped at 300 seconds. A 240-second native Timer refreshes inventory. Expiry redraws availability and requests reconciliation. Native callbacks, server timestamps and local files cannot independently extend the proof lifetime. A complete successful inventory response commits atomically; a successful empty inventory revokes access, while malformed replies and transient verification failures preserve earlier verified rights. Newer native grants, pending states and payment errors survive older inventory snapshots. Queries are serialized and tied to their issuing account generation, so an old empty response cannot finish a newly configured account's initial restore.

An explicit backend denial can revoke only the requested package/product/token when the verifier returns exact `verified:false`, `acknowledged:false`, `revoked:true` and terminal `revoked`/`cancelled` state. The HTTP adapter creates that marker only for known non-retryable Google purchase denials. A generic HTTP error cannot revoke access. An old refunded token cannot remove a newer verified purchase, and one SKU's explicit revocation can resolve its saved checkpoint even while another SKU has a transient error.

SDK pending payments and in-flight verification lock checkout. Duplicate callbacks share verification and grant once. Pending cancellation, errors, incomplete updates and suspension request authoritative reconciliation. Failed verification exposes Restore. A verified purchase whose game activation cannot be saved remains restorable and does not claim successful activation. Existing gameplay run pinning keeps an airborne run's ability stable.

There is no persistent production entitlement cache. Fresh-process paid access requires verified restoration; a saved `store` source flag is not proof of ownership. Startup defers only a store-paid active checkpoint, preserving the original file and its area/rules/provenance while showing Home with Restore run. Campaign transactions and replacement runs are blocked until resolution. Normal offline campaign saves remain playable. Verified retry resumes the original paused run without replaying an ability transformation. Only fresh authoritative absence or a matching explicit backend revocation can retire that paid checkpoint; timeout, expiry, malformed data and snapshot incompatibility keep it available for recovery. The native ads namespace imports before SDK initialization and exports with the profile. Real Play configuration, authenticated backend availability and actual phone purchase/restore acceptance are separate from these source tests.

On public Android, **Settings → Purchases** offers ad removal and manual restore. An acknowledged, verified `remove_ads` purchase blocks automatic interstitials in every area. With billing configured, automatic ads require fresh confirmation of absence or revocation, so startup, proof expiry and an unavailable verifier do not play an automatic ad to a returning owner. Builds with empty billing configuration retain their ordinary ad cadence and cannot sell the purchase. Rewarded ads remain opt-in and follow the existing result and consent rules. Play ownership is rechecked on launch, foreground return and restore using the same Google Play account, including after reinstall. Game saves carry ad cadence and earned reward receipts.

## Local verification

`tests/remove_ads_qa.gd` passes 35 checks through the real Settings controls, billing provider, HTTPS response validation and result flow with simulated Play, HTTP and ad SDK responses. It covers checkout, pending and cancelled payments, rejected proof, saved-profile restart, verified restore and the separate rewarded bonus. The fixture requires an absolute `--output-dir` for its disposable saves.

`tests/native_billing_qa.gd` passes 83 billing lifecycle and proof assertions, and `tests/firebase_purchase_verifier_qa.gd` passes 70 response checks. The commerce backend passes 32 unit tests and six Firestore emulator tests. Fixtures isolate profile IO and use simulated Play transactions.

`tests/area_ability_access_qa.gd` passes 74 assertions. `tests/area_ability_integration_qa.gd` passes 205 assertions, including game activation, save rollback and immediate native-error UI paths. `tests/purchase_restore_qa.gd` passes 74 isolated disk and checkpoint assertions. The Home renderer passed 49 checks across 12 captures at 450x800 and 720x1280. Earlier evidence is under `verification/native-commerce/billing-unit/`.

Official sources: [plugin release](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.3.0), [installation](https://godot-sdk-integrations.github.io/godot-google-play-billing/installation.html), [methods](https://godot-sdk-integrations.github.io/godot-google-play-billing/api/methods.html), [native signal dictionaries](https://godot-sdk-integrations.github.io/godot-google-play-billing/api/signals.html).
