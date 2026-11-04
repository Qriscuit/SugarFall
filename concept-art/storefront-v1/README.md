# Sugarfall storefront draft

Prepared 4 November 2026 for Google Play, using the current 0.8.0-rc2 game.

Open `preview.html` to review the artwork, text and six screenshots together. If using the ZIP, extract the whole folder first so the images remain next to the page.

## Files for the listing

| Field | File | Format |
| --- | --- | --- |
| App name | `exports/title.txt` | Exact plain text |
| Short description | `exports/short-description.txt` | Exact plain text, 76 characters |
| Full description | `exports/full-description.txt` | Exact plain text |
| Feature graphic | `exports/google-play-feature-1024x500.png` | 1024 × 500, RGB PNG |
| App icon | `exports/google-play-icon-512.png` | 512 × 512, RGBA PNG; existing game icon |
| Phone screenshots | `screenshots/01-…png` through `06-…png` | 1080 × 1920, RGB PNG |

Screenshot order: Bakery gameplay; Gelato curved aiming; Crystal's timed ×2 pickup; Gelato's upgrade map; Bakery Jam Burst; Gelato Dual Shot. Use the images without added captions by default. The optional captions and alt text are in `screenshot-plan.txt` and the manifest.

The feature graphic is promotional artwork made with the built-in imagegen tool. It combines the three areas in one illustration. It is not a gameplay screenshot. The final prompt set is in `prompts.json`. The selected source is `source/feature-v2.png`; the technical export preserves proportions and trims six resampled pixels from each vertical edge. The original game icon is retained.

The six screenshots are actual nondebug public-renderer captures from the unchanged game, with staged campaign progress and wallets. No generated gameplay, added UI or painted effects are used. They were captured on Windows; compare them with the final Android build before submission and replace any frame whose Android layout differs. This package does not record Android acceptance or Play Console submission.

Google's [preview asset requirements](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en) specify the feature and icon sizes above. The six portrait screenshots also meet its recommended game screenshot dimensions. Copy limits and claim evidence are recorded in the project's `PLINKO/docs/store/STORE_COPY.md`; the detailed capture plan is in `PLINKO/docs/store/SCREENSHOT_PLAN.md`.

No game content, release preset or APK was changed by this storefront work. The existing Play release candidate and phone preview remain the current builds. Store contact, privacy, audience, commercial declarations and final Console entry remain separate release tasks.
