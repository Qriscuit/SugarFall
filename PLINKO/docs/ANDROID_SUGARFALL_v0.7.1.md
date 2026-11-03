# Sugarfall v0.7.1 preview — area fixes

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Build manifest](ANDROID_SUGARFALL_v0.7.1.json)

This build fixes the Crystal Prism pickup sound, clarifies Gelato's Dual Shot Help, adds a readable backing to damage numbers, and gives Bakery trays 2–12 specific teaching briefs. Prices, durability and authored peg layouts are unchanged.

Version code **26** retains the v0.7.0 preview package and signing identity. The save format remains profile 5, with Bakery/Gelato checkpoint schema 4 and Crystal schema 5. Bakery's teaching-text change has an explicitly pinned compatibility mapping; all gameplay board fields and economy values match v0.7.0.

Validation passed: **465 payload checks**, **16 Android metadata/signature/alignment checks**, and frozen source evidence comprising **1,210 assertions across 11 suites**, including **58 desktop captures**. APK size: **87,125,393 bytes**. SHA-256:

```text
d1e4f1defc01523479cbdc8f0a859810230ee28b0dcd133f4d6336b089905485
```

The existing private Drive file was replaced in place and eight metadata checks passed, preserving its link, folder and permissions. The previous local v0.7.0 APK and manifest are preserved. The connector did not expose a remote checksum; exact local SHA-256 and remote size/name are recorded. Physical-phone installation, install-over-save behavior, speaker listening, touch feel and sustained Android performance remain open for the user's playtest.

Six linked legal campaigns passed 9,044 separate assertions and cleared all 18 sampled area campaigns. Prices and HP remain unchanged; five unique tray/seed stall cases are recorded for human review in [the progression report](AREA_PROGRESSION_BALANCE.md). Follow [the playtest protocol](AREA_PLAYTEST.md) and record any findings against AF-008/AF-009.

Detailed evidence: [packaging readiness](../../verification/android-preview-v071/packaging-readiness.json), [payload inspection](../../verification/android-preview-v071/package-inspection.json), [Android validation](../../verification/android-preview-v071/android-validation.json).
