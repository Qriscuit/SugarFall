# Native monetization status

## Production AdMob configuration - CHG-052, 10 November 2026

The unpublished Sugarfall Android app is present in the owner’s AdMob account. **Result bonus** and **Campaign results** are the configured production rewarded and interstitial units. The public preset embeds the owner’s app ID and matching ad configuration. The shared preview embeds Google demo inventory under its separate Android package. The public build rejects demo IDs and embedded test overrides.

The signed **0.8.0-rc4/code 45** Play APK and AAB passed 663 exact artifact checks with the existing release signing identity. Preview **0.7.18-preview/code 45** passed 630 artifact checks and eight Drive metadata readbacks after in-place replacement. [Play build](ANDROID_SUGARFALL_v0.8.0-rc4.md) · [Drive preview](ANDROID_SUGARFALL_v0.7.18.md).

The isolated ad provider and integration suites passed 72 and 40 checks. Exported desktop policy probes passed 85 preview, 103 public debug and 103 public release checks. These results cover configuration separation, consent gating, reward handling and public simulator exclusion. AdMob reports limited serving and requires review. Publishing the consent messages, linking the public Play listing, verifying `app-ads.txt` and confirming phone playback remain open. [Account setup](monetization/ACCOUNT_SETUP.md).

## Native SDK integration - CHG-051, 5 November 2026

5 November 2026. Preview **0.7.17-preview/code 44** and public **0.8.0-rc3/code 43** are verified and delivered in the existing testing Drive files. The preview passes 624 exact-artifact checks; the public APK/AAB pass 652. All three replacements pass eight independent metadata readback checks each, retaining file IDs, folder and permissions. No remote checksum comparison is claimed.

The official Billing 3.3.0 plugin (Billing Library 9.1.0) and Poing AdMob 5.1.0/native 4.6.3 plugin (Google Next-Gen SDK 1.6.0) are vendored. The three permanent `early-unlock` products retain a US$2.99 design price per area; Play supplies localized catalog prices. There are no consumable currency products.

The billing lifecycle, proof expiry/revocation, ability UI and isolated disk-restore suites pass 418 assertions. The Home recovery renderer passes 49 checks in 12 captures. The HTTP verifier passes 65 fixture assertions. The backend passes 29 unit tests and six local Firestore-emulator tests. These results do not establish a live backend or real payment. [Billing evidence](monetization/BILLING_VALIDATION.json), [HTTP verifier evidence](../../verification/firebase-verifier-peer-20261105/validation.json), [server evidence](../../server/commerce/VALIDATION.json) and [ad evidence](../../verification/native-ad-integration-20261105/validation.json) retain the scopes.

The owner chose `sungatientertainment@gmail.com` and reports no Firebase project and no AdMob app record yet. No verifier is deployed. Current billing fields are empty, so checkout fails closed. Ads use Google's demo IDs and test mode. [Account setup](monetization/ACCOUNT_SETUP.md) and the [backend handoff](../../server/commerce/README.md) list the remaining configuration. No active Play product, real purchase, live revenue, Console upload or release is established.

Both variants use the official release engine. The preview retains the `developer` feature and existing preview signing identity; this keeps the native SDK-equipped APK below the connector's 100 MiB limit. The public variant uses `sugarfall_public` and the existing public signing identity. A retained-input recheck proves that the later preview-preset adjustment leaves every public block and runtime input unchanged.

The owner's adb command succeeded with an empty device list. Physical installation, native SDK playback, purchase/cancellation/pending/restore/reinstall/refund/expiry, retained saves, sustained performance, legal progression and the Bakery tray-10 retest remain open. All existing area states and phone-test statuses are unchanged.

- Preview: [verified record](ANDROID_SUGARFALL_v0.7.17.json); Drive delivery verified by metadata readback.
- Public: [verified record](ANDROID_SUGARFALL_v0.8.0-rc3.json); Drive delivery verified by metadata readback.

[Machine-readable status](NATIVE_MONETIZATION_STATUS.json). Account setup and phone acceptance remain OPEN.
