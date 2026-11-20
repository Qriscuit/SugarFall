# Sugarfall v0.7.14 Android preview

Delivered 5 November 2026 · `0.7.14-preview` · version code `40` · CHG-048 / AF-012.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Build manifest](ANDROID_SUGARFALL_v0.7.14.json) · [Verification](COIN_ONBOARDING_VALIDATION.json)

Mabel uses shorter action instructions, with 10 guide states instead of 14. Body, name and hint text are two logical pixels larger. Dialogue is visible immediately; one tap continues the earnings message and highlighted actions work on the first tap. Peg rewards show a gold coin icon and the actual positive coin amount, including break rewards, across all three areas. Zero-coin contacts do not show an invented reward. The guide teaches hitting cookies for coins and auto-selects Feed 1 for the first purchase.

The four removed steps are the separate welcome, aiming explanation, Feed selection and post-purchase speech. The real steering gesture, time pickup, collection and purchase remain. Version-1 tutorial saves migrate to the shorter flow; completed guides stay completed. Skip, replay, pause and reset remain supported.

Coin labels use credited whole coins, combine rapid rewards at the same peg, and include the break bonus without repeating it in a second popup. They stay stationary with Reduced Motion. The existing Mabel portrait is reused; the gold coin symbol is drawn at runtime. No additional bitmap art is needed. Mechanics, reward budgets and gameplay data are unchanged.

The final checks pass 1127 functional assertions and 193 renderer assertions across 72 captures at 450×800 and 720×1280. Touch and Windows guide copy are covered. Isolated saves and renderer fixtures record zero normal-profile access. The exact APK passes 1500 payload checks and 16 Android metadata, signing and alignment checks. Eight Drive readback checks preserve the file ID, folder, permissions and URL. The connector returned no remote checksum.

| Artifact | Value |
|---|---|
| Filename | `Sugarfall-v0.7.14-Android-Preview-2026-11-05.apk` |
| Size | 98,872,682 bytes |
| SHA-256 | `80b8c6493c1400b02eb1099b0a1c61fba2528c4bb1289137f2321905251d6577` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

The preview retains its signing identity and increments code 39 to 40. Android skips version 0.7.13 because the separately recorded Windows preview already uses that version. Physical-phone readability, touch comfort, install-over save retention and performance remain open, as do the Bakery tray-10 retest, natural-wallet progression and real billing. This delivery does not establish phone acceptance or area completion.
