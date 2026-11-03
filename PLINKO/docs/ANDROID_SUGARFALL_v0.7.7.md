# Sugarfall v0.7.7 Android preview

Delivered 3 November 2026 · `0.7.7-preview` · version code `33`.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Local APK](../builds/Sugarfall-v0.7.7-Android-Preview-2026-11-03.apk) · [Build manifest](ANDROID_SUGARFALL_v0.7.7.json)

This build adds 33 original sounds for 25 action types, including distinct Bakery, Gelato and Crystal materials. A six-voice cached controller keeps purchases, pickups and results audible above frequent impacts, stops on mute/background, and never queues stale sounds. The studio logo and original hum now follow a slower 1.30-second double beat, with a 2.60-second presentation minimum and a quieter second pulse.

The APK passed **823 payload checks** and **16 Android metadata, signature and alignment checks**. All 41 runtime scripts, 33 feedback imports and the updated studio hum are present. Export inputs and current imported bytes match the frozen source; ten gameplay JSON files remain byte-identical to v076. These are package checks, not phone execution or listening acceptance. Existing [action-audio](AUDIO_FEEDBACK_VALIDATION.json) and [studio](SLOW_STUDIO_VALIDATION.json) source evidence remains separately scoped.

| Artifact | Value |
| --- | --- |
| Filename | `Sugarfall-v0.7.7-Android-Preview-2026-11-03.apk` |
| Size | 93,047,202 bytes |
| SHA-256 | `dd1eaa5982985a6e180a91ba214b1da0500f90f541d7b9104396faeb8c12adc9` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

The preview retains the same package and signing identity as v076 for an install-over update. Physical save retention, phone audio balance, startup feel and normal-wallet pacing remain open. Real Play billing is still unconnected. v076 and the separate public v0.8.0-rc1 APK/AAB are preserved.

The existing private Drive file and permissions were retained, and all eight uploaded-metadata checks passed. Drive returned no remote checksum; the APK hash is verified locally.
