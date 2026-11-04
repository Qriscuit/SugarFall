# Sugarfall Google Play screenshots

Prepared 4 November 2026 for the current `0.8.0-rc2` game. Six review captures are saved in `outputs/storefront-20261104/screenshots` at the repository root.

Use the order below. The first three images show gameplay in all three areas before introducing upgrades. Keep the six images as full-screen game captures; captions are optional and are not baked into the delivered PNGs. The feature artwork belongs in the separate feature-graphic field.

| Order / file | What the image shows | Purpose | Optional caption | Alt text |
| --- | --- | --- | --- | --- |
| 1 — `01-bakery-gameplay.png` | Bakery tray 4, with falling doughnuts, damaged silver cookie pegs, damage values, coins, a time pickup and collecting cups. | Establish the basic peg-and-ball game immediately. | Break pegs. Earn coins. | Doughnuts bounce through silver cookie pegs in Bakery, with damage values, a time pickup and five collecting cups. |
| 2 — `02-gelato-aim.png` | Gelato tray 4, with the top launcher aimed right, the curved dotted preview and ice cream in flight. | Show that Gelato adds directional aiming and gravity. | Aim along the curve | Gelato's launcher aims along a curved dotted path while ice cream hits waffle pegs above five cups. |
| 3 — `03-crystal-prism.png` | Crystal tray 4, with straight shots, damaged crystal pegs and an active floating ×2 pickup. | Show the third area's straight shots and timed multiplication pickup. | Tap to multiply candy | Crystal candy travels through crystal pegs beside a floating ×2 pickup with a visible countdown ring. |
| 4 — `04-gelato-upgrades.png` | Gelato's tiled garden upgrade map after 22 real coin purchases, with owned nodes and green available choices. | Show the branching upgrade system and the area art between runs. | Choose your upgrades | Gelato's upgrade map has branching paths, green purchase choices, garden buildings and ceramic floor tiles. |
| 5 — `05-bakery-jam.png` | Bakery tray 8 at the first natural Jam Burst impact, with the real effect linking the contact peg and a nearby peg. | Show an earned area ability and stronger gold pegs. | Hit nearby pegs with Jam Burst | A Jam Burst hit links nearby gold cookie pegs while doughnuts fall through Bakery's tray. |
| 6 — `06-gelato-twins.png` | Gelato tray 8 after buying Dual Shot through its earned route. Two launchers, two preview paths and their balls are visible; Power has reset. | Finish with a clear upgrade that changes how the area plays. | Two launchers. Rebuild Power. | Two Gelato launchers show separate dotted aim paths above ice cream balls and gold waffle pegs. |

## Capture status

These are actual, uncomposited frames from the unchanged game renderer. The harness exports a nondebug Windows build with the `sugarfall_public` feature and renders the same portrait UI used by the Android candidate at **1080 × 1920**, directly into a Godot viewport. The PNGs are **24-bit RGB with no alpha**. No extra title, caption, finger, device frame, store badge or generated gameplay is added.

The capture harness stages campaign progress and wallets in memory. It advances the real game at fixed timesteps with recorded aim positions. Jam Burst and Dual Shot are purchased through the normal earned coin APIs; the map uses the normal purchase and reveal rules. This establishes what those states look like, not how long a player takes to reach them. No player profile is read or written. There is no simulated paid entitlement or developer UI in the images.

These are **desktop-rendered store-review captures**, not screenshots taken from a physical Android phone. Before submission, check the exact Android release on a phone for matching layout, safe-area behavior, fonts, effects and cup labels. Replace any image whose Android presentation differs. No Play Console upload or device acceptance is recorded by this capture task.

## Reproduce and verify

The isolated harness and launcher are under `verification/storefront-20261104`. The final run uses `capture-04`; its project copy contains the original game scripts and assets, plus a separate entry scene and capture fixture. The fixture freezes automatic frame processing and performs fixed-step simulation. It does not override production drawing functions.

Evidence next to the PNGs:

- `capture-report.json`: public/nondebug flags, renderer, dimensions, staged states, real ability ownership, ball counts and zero profile IO.
- `source-evidence.json`: source revision, file hashes, unchanged runtime/art/data parity and capture executable hash.
- `screenshots-validation.json`: exact PNG dimensions, RGB format, file hashes and per-image visual review.

The source revision is the repository revision recorded by `source-evidence.json`. Runtime content is the same as the signed `0.8.0-rc2` candidate; this task does not change gameplay or create a new APK.

## Google Play format and presentation

Google Play accepts JPEG or 24-bit PNG screenshots with dimensions from 320 to 3840 pixels and a long edge no more than twice the short edge. A listing needs at least two screenshots. For game recommendation formats, Google specifies at least three gameplay screenshots at **1080 × 1920 portrait** or **1920 × 1080 landscape**. Up to eight screenshots can be supplied per device type. The six portrait images meet those dimensional recommendations. [Google Play preview-asset guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

Google recommends actual in-game content, especially in the first three images. Any added tagline should occupy at most 20% of the image. Avoid price promotions, rankings, awards, download calls to action and device frames. Keep alt text within 140 characters. Our default is to upload the six uncaptioned game captures and enter the alt text separately. [Google Play presentation guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

## Optional later additions

If a seventh image adds useful information, capture Crystal immediately after tapping the live ×2 pickup, with both the original balls and their duplicates still visible. If an eighth is needed, use a normal end-of-tray results window over its dimmed board. Both should come from the final Android release. Neither is needed to fill the current six-image plan, and neither has been captured or claimed here.
