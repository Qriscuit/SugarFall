# Sugarfall v0.7.3 preview — studio startup

[Download from Drive](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Local APK](../builds/Sugarfall-v0.7.3-Android-Preview-2026-11-03.apk) · [Build manifest](ANDROID_SUGARFALL_v0.7.3.json)

The supplied vertical studio stamp now replaces the Godot boot image. Deep-red ink rests on a dark stage, grows and brightens in a double heartbeat, then settles before the shared cream wave reveals the game. The original image is preserved; its appearance is animated at runtime.

Startup waits for real asset loading and profile restoration. Gameplay and onboarding remain held until reveal, background time does not consume a run, and loading errors offer Retry and Close. Saved Reduced Motion uses a static stamp and immediate reveal once ready. The Android system launch icon remains Sugarfall's existing icon.

Version **0.7.3-preview / code 28** keeps the same preview package and signing identity. All ten gameplay JSON files and all three gameplay fingerprints equal v0.7.2. The previous local APK and manifest are preserved.

Validation passed: **498 payload checks**, **16 Android metadata/signature/alignment checks**, **1,371 software and desktop renderer assertions**, and **6 separate native-asset checks**. This includes **13 isolated profile cases** and **48 desktop captures**. APK size: **88,957,646 bytes**.

```text
SHA-256 4381dd75f0ae7a44ff13fa05da7f4a91841217fc03ae2b5cc1130fa6bd9a1544
```

The existing Drive APK was replaced in place and its identity, size, folder, permissions and download link were checked. Physical Android cold/warm launch, install-over-save retention, touch, background/resume and sustained performance remain open; desktop checks do not establish phone smoothness or human campaign pacing.

Evidence: [source validation](../../verification/studio-startup-20261103/validation.json), [payload inspection](../../verification/android-preview-v073/package-inspection.json), [Android validation](../../verification/android-preview-v073/android-validation.json).

Delivery evidence: [Drive readback](../../verification/android-upload-v073/verification.json). Eight metadata checks passed; the connector did not return a remote checksum. The checksum above identifies the locally verified file supplied for upload.
