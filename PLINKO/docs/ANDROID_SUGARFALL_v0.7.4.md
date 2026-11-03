# Sugarfall v0.7.4 preview — gameplay entrance and result windows

[Download from Drive](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Local APK](../builds/Sugarfall-v0.7.4-Android-Preview-2026-11-03.apk) · [Build manifest](ANDROID_SUGARFALL_v0.7.4.json)

Home Play and the Home tray now morph into the gameplay board, with pegs aligned and the cups and dispenser sliding into place. The cream wave remains on studio startup and normal menu navigation.

Results appear as a window over the darkened, frozen board. The existing payout, reward confirmation and Trial return rules are preserved. Reopened pending results show an empty themed tray because older and current result saves do not contain the finished board pose.

The viewport now fills tall and wider portrait displays while keeping the board proportions and safe-area fitting. HUD counters and cup payout multipliers are clearer. No artwork pixels, prices, HP, economies or authored layouts changed.

Version **0.7.4-preview / code 29** retains the same package and signing identity. All ten gameplay JSON files and all three gameplay fingerprints equal v0.7.3. The previous local APK and manifest are preserved.

Validation passed: **500 payload checks**, **16 Android metadata/signature/alignment checks**, and **1,877 software/desktop assertions**. APK size: **88,969,934 bytes**.

```text
SHA-256 1a319430bd1ccc352ecee7af5635ce03a522c847086148ee31967242084e09d3
```

The existing Drive APK was replaced in place and its identity, size, folder, permissions and download link were checked. Physical-phone installation, fit/touch comfort, background/resume and sustained performance remain open, along with human campaign pacing.

Evidence: [source validation](../../verification/screen-polish-20261103/validation.json), [payload inspection](../../verification/android-preview-v074/package-inspection.json), [Android validation](../../verification/android-preview-v074/android-validation.json).

Delivery evidence: [Drive readback](../../verification/android-upload-v074/verification.json). Eight metadata checks passed; the connector did not return a remote checksum. The checksum above identifies the locally verified file supplied for upload.
