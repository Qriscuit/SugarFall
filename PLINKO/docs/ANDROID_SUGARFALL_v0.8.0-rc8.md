# Sugarfall 0.8.0-rc8

19 November 2026 · Local signed release candidate · Version code **49** · Package `com.sungati.sugarfall`

Code 49 is the next unused code in the project release records after code 48. The signed bundle uses the same upload certificate as the recorded code-48 bundle. Both public Android presets now use `0.8.0-rc8`.

- [Signed AAB](../builds/android-release/0.8.0-rc8-code49-attempt02/Sugarfall-v0.8.0-rc8-Android.aab) · 102,142,217 bytes · SHA-256 `50f26807cf640630d61d135e79761c80e7165bb055f54a910819d824bfc1ffd4`
- [Signed APK](../builds/android-release/0.8.0-rc8-code49-attempt02/Sugarfall-v0.8.0-rc8-Android.apk) · 102,323,181 bytes · SHA-256 `9547f95db9b1f74ee840a6d18e2b95372c4a25657067808589a46777f49d9d85`
- Upload certificate SHA-256 `e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29`

The release workflow passed **667** checks across the exact signed APK and AAB. Bundletool validated the AAB and read its package and version. Jarsigner verified its signature. Direct inspection of the AAB confirmed 34 markers across six compiled scripts for Settings → Purchases, Google Play checkout and restore, automatic ad suppression for verified owners, and optional rewarded ads. The bundle includes the native billing bridge and Play Billing permission. [Artifact verification](../builds/android-release/0.8.0-rc8-code49-attempt02/verification/validation.json).

The isolated Godot suites passed 741 checks, including 35 for ad removal. The backend passed 32 mocked commerce tests and four syntax checks. Release tooling passed 29 tests. The checks used simulated purchase and ad responses. [Remove automatic ads test log](../../verification/android-release-rc8-code49/remove_ads_qa.log).

## Remaining acceptance

- Deploy the Firebase HTTPS verifier with Anonymous Auth, native Firestore, and Android Publisher permissions to verify and acknowledge purchases. Fill the verifier URL, Firebase web API key, and Firebase project ID in the app and rebuild. All three fields are empty in this bundle, so live checkout is disabled.
- Confirm and activate the permanent Play product `remove_ads` with purchase option `remove-ads`, localized pricing, and availability for the test account.
- Install the configured build through a Play test track on an Android device. Use a licensed tester, a Google test payment method, and a registered AdMob test device. Check successful and pending or cancelled checkout, automatic ad suppression, optional rewards, restore after relaunch and reinstall, and refund or revocation. [Account and device acceptance checklist](monetization/ACCOUNT_SETUP.md).
