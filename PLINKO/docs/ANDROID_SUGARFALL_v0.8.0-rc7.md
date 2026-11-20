# Sugarfall 0.8.0-rc7

10 November 2026 · CHG-055 · Version code **48** · Package `com.sungati.sugarfall`

The owner reported that Play Console requires `com.sungati.sugarfall`. This candidate uses that package in its public manifests and purchase-verification contract. The existing Sugarfall release certificate signs the APK and AAB. They passed **665** artifact checks. Local package tests passed 67 native billing, 68 Firebase verifier, 30 backend and 29 build and artifact verifier checks. Independent manifest checks confirmed the package, provider authorities and existing certificate. [Exact build record](ANDROID_SUGARFALL_v0.8.0-rc7.json).

- [Signed AAB](../builds/android-release/0.8.0-rc7-code48-attempt01/Sugarfall-v0.8.0-rc7-Android.aab) · 102,137,945 bytes · SHA-256 `251ac7a14e73b9793142dc85d5c555e7b80175b2da9e5f0017316690ad71077a`
- [Signed APK](../builds/android-release/0.8.0-rc7-code48-attempt01/Sugarfall-v0.8.0-rc7-Android.apk) · 102,318,910 bytes · SHA-256 `edb521c7bb8c6282ae0e5c4427c7771f2c174cef324a8a3021672a6b2a709b4a`
- Release signing certificate SHA-256 `e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29`

RC1–RC6 artifacts document the earlier `com.qriscuit.sugarfall` identity. RC7 installs as a separate Android app from those candidates. The preview continues using `org.pegfoundry.prototype.preview`. Play Console acceptance, Play App Signing enrollment and physical Android acceptance are pending.

[Play Console release notes](store/RELEASE_NOTES_0.8.0-rc7.en-US.txt)

The owner reported two crash reporting warnings in Play Console for version code 48. The Gradle release build did not enable R8 minification and generated no mapping file. [Android R8 guidance](https://developer.android.com/topic/performance/app-optimization/troubleshoot-the-optimization).

The replacement native symbols ZIP is 27.4 MB. It contains function symbols for both ARM64 libraries, with GNU Build IDs matching the signed AAB. The earlier archive retained restricted Windows file permissions from its temporary folder. The replacement inherits the builds folder permissions and passes Explorer, extraction, and Java ZIP checks. In Play Console, open bundle 48 and use Downloads → Assets → Native debug symbols to attach the ZIP. [Replacement ZIP](../builds/Sugarfall-48-native-symbols.zip) · [Symbol validation](../../verification/rc7-native-symbols/compatible-validation.json) · [Windows validation](../../verification/rc7-native-symbols/compatible-windows-validation.json) · [Upload instructions](https://docs.godotengine.org/en/4.6/tutorials/platform/android/resolving_crashes_on_android.html#uploading-symbols-to-google-play-console).

The owner confirmed that Play Console accepted the native symbols ZIP for version 48. Tester rollout is pending confirmation. The deobfuscation warning is expected for this build because Gradle did not run R8. [Play release guidance](https://support.google.com/googleplay/android-developer/answer/9859348).
