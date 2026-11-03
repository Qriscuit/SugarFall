# Sugarfall v0.7.2 preview — menu polish

[Download from Drive](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Local APK](../builds/Sugarfall-v0.7.2-Android-Preview-2026-11-03.apk) · [Build manifest](ANDROID_SUGARFALL_v0.7.2.json)

Adds the shared illustrated cream-wave page transition, centered Home action icons and a clearer Settings heading. Damage numbers use outlined text without rectangular backing. Reduced Motion keeps immediate page changes. Prices, HP, economies and authored layouts are unchanged.

The transition holds the outgoing rendered page until a fully opaque midpoint, then reveals the destination. Input, run clocks, guide text, coin pulses and checkpoints wait while it plays. Restore and background events settle presentation without replaying actions.

Version **0.7.2-preview / code 27** retains the same preview package and signing identity. All three gameplay fingerprints equal v0.7.1. The previous local APK and manifest are preserved.

Validation passed: **475 payload checks**, **16 Android metadata/signature/alignment checks**, and **1,143 source, renderer and asset assertions**, including **62 desktop captures**. APK size: **88,575,758 bytes**.

```text
SHA-256 75ad508806f07ccafbb5bf5700012e6e49a508e4b9e70bbfaa9eba68dc962220
```

The existing Drive APK was replaced in place and its identity, size, folder, permissions and download link were checked. Physical-phone installation, install-over-save retention, touch comfort, background/resume and sustained performance remain open; desktop checks do not establish Android smoothness or human campaign pacing.

Evidence: [source validation](../../verification/menu-polish-20261103/validation.json), [payload inspection](../../verification/android-preview-v072/package-inspection.json), [Android validation](../../verification/android-preview-v072/android-validation.json).

Delivery evidence: [Drive readback](../../verification/android-upload-v072/verification.json). Eight metadata checks passed; the connector did not return a remote checksum. The checksum above identifies the locally verified file supplied for upload.
