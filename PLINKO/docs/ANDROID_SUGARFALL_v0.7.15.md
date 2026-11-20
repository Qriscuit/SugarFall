# Sugarfall v0.7.15 Android preview

Delivered 5 November 2026 · `0.7.15-preview` · version code `41` · CHG-049 / AF-013.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Build manifest](ANDROID_SUGARFALL_v0.7.15.json) · [Verification](UPGRADE_PULSE_VALIDATION.json)

The signature upgrade below Feed 1 has a smooth 2.5-second growing and shrinking gold backdrop in all three areas. Locked, available and unaffordable states pulse; owned uses half opacity. Reduced Motion uses a static highlight. Node art, hit bounds, cards, camera, costs and gates stay fixed. Offscreen and inactive views stop animating.

Peg earnings show gold +amount with a dark gold outline and no coin symbol or icon spacing. Actual credited coins, break rewards, merging and stationary Reduced Motion behavior are retained.

Global bottom notifications are removed from Home and other pages, along with their invisible map input blockers and notification-driven redraws. Existing inline card messages and transactional note state remain supported.

The backdrop is drawn at runtime; no new bitmap art is needed. Existing artwork, hit targets, prices, gates, purchase behavior and reward budgets remain supported. The shortened v0.7.14 guide remains in this build.

1,030 functional and 702 renderer assertions pass across 84 final captures at 450x800, 450x1000 and 720x1280. 54 note/no-note pixel comparisons and 12 pulse-locality comparisons pass. Zero normal-profile access. 454 source files and 620 export inputs are frozen.

v0.7.15-preview/code 41 passes 1,500 payload and 16 Android metadata/signature/alignment checks; 98,872,682 bytes; SHA-256 58768ef3a5e3ef7d78ac952bce94632cb80f2b7bb8b0b7534c88037252821067. Preview package and signing identity are retained. Only upgrade_map, impact_feedback, main and level_map compiled scripts differ from v0.7.14; gameplay JSONs and native art remain unchanged.

All 8 Drive metadata readback checks pass after in-place replacement in the existing testing file. Same file ID, folder, URL and permissions; new filename/revision and exact byte count verified. No remote checksum returned. Physical-phone acceptance remains open.

| Artifact | Value |
|---|---|
| Filename | `Sugarfall-v0.7.15-Android-Preview-2026-11-05.apk` |
| Size | 98,872,682 bytes |
| SHA-256 | `58768ef3a5e3ef7d78ac952bce94632cb80f2b7bb8b0b7534c88037252821067` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

The preview retains its signing identity and increments code 40 to 41. Physical-phone pulse feel, readability, input, install-over save retention and performance remain open, as do the Bakery tray-10 retest, natural-wallet progression and real billing. This delivery does not establish phone acceptance or area completion.
