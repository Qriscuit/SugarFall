# Sugarfall v0.7.16 Android preview

Delivered 5 November 2026 · `0.7.16-preview` · version code `42` · CHG-050 / AF-014.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Build manifest](ANDROID_SUGARFALL_v0.7.16.json) · [Guide verification](CLEAR_TRAY_INTRO_VALIDATION.json)

Mabel's earned-coins instruction now says:

> Hits earn coins. Destroy every cookie to clear the tray before time runs out.

Mabel's earned-coins instruction is now: “Hits earn coins. Destroy every cookie to clear the tray before time runs out.” It explicitly teaches destroying every target and clearing the tray while keeping coin earnings clear. The opening, ten states, tap progression and 28/27/22 body/name/hint sizes are retained.

The existing introduction suite passes 192 assertions. Four touch/mouse captures at 450x800 and 720x1280 have zero layout failures; the revised message fits in three readable lines with controls and the earned-total close-up clear. Isolated source matches the delivered source, with zero player-profile IO. Only first_run_guide.gd changes from v0.7.15; 451 approved source files and 620 export inputs are frozen.

v0.7.16-preview/code 42 passes 1,498 payload and 16 Android metadata/signature/alignment checks; 98,872,682 bytes; SHA-256 7a9a7309af270377f67ac44478a44ee7d27a099cf21efc7dc6918a4e2a41c363. Preview package and signing identity are retained. Only first_run_guide compiled bytecode differs from v0.7.15. The initial export timed out before producing an APK; the logged retry used identical frozen inputs and passed all exact-artifact checks.

All 8 Drive metadata readback checks pass after replacing the existing testing APK in place. File ID, folder, URL and permissions are retained; new filename/revision and exact byte count verified. No remote checksum returned. Physical-phone readability and fresh-player understanding remain open.

| Artifact | Value |
|---|---|
| Filename | `Sugarfall-v0.7.16-Android-Preview-2026-11-05.apk` |
| Size | 98,872,682 bytes |
| SHA-256 | `7a9a7309af270377f67ac44478a44ee7d27a099cf21efc7dc6918a4e2a41c363` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

Physical-phone readability and fresh-player comprehension remain open. The existing phone/install-over checks, Bakery tray-10 retest, natural-wallet progression and real ads/billing work remain separate. This delivery does not establish area completion.
