# Sugarfall 0.8.0-rc1 — local signed release candidate

Built 3 November 2026 with Godot 4.6.3, Android package `com.qriscuit.sugarfall`, version code 30. The nondebug APK and Google Play AAB are signed with the protected release identity. Neither was published or uploaded; the v0.7.4 Drive preview is unchanged.

The studio now has a warm spotlight, grounded heartbeat and quiet hum that respects Sound. Public builds hide and reject developer controls, diagnostics and simulated commerce. Old simulated ownership cannot grant public benefits; earned progress and base result collection remain intact. Real ads and billing are still unconnected, so this is not a finished Play launch.

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| [APK](../builds/Sugarfall-v0.8.0-rc1-Android-2026-11-03.apk) | 87,583,943 | `f1e0ba502e2fbfc755479b44c6801660a53653d0bcdf3067b64e00ff103c122c` |
| [AAB](../builds/Sugarfall-v0.8.0-rc1-Android-2026-11-03.aab) | 86,872,100 | `f37bc66695ae39402dc6330349f732f1713977e7da3df954237c8f09450ed48b` |

Both use certificate `e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29`. The new package installs separately from the preview; it does not automatically copy the preview app's save.

Validation passed 1,520 functional/rendering assertions, plus 6 native-asset and 7 toolchain checks recorded separately. The APK passed 508 payload and 16 Android metadata checks. The AAB passed 30 checks, including official bundletool validation, complete signed-entry digests and 335 game payloads byte-identical to the APK. All 24 launcher bitmaps also match. SDK 24/36, ARM64, nondebug mode, public feature, current studio shader/audio, notices, signing and 16 KiB APK alignment are verified.

All 33 runtime scripts are packaged; all 10 gameplay JSON files and area fingerprints remain unchanged from v0.7.4. Physical phone behavior, Play upload/testing, production commerce, off-device key recovery and a clean-machine rebuild remain open. See [the complete manifest](ANDROID_SUGARFALL_v0.8.0-rc1.json), [signing recovery](RELEASE_SIGNING.md), and `verification/android-release-v080` for exact evidence and build warnings.

Rebuild from the tracked [Android release procedure](ANDROID_RELEASE_BUILD.md). Local evidence/cache folders are intentionally excluded from Git; the procedure uses the tracked presets and restored private signing identity.
