# Sugarfall store assets — 5 November 2026

Delivered seven new screenshots and a feature graphic matching the supplied Mabel banner at exactly **1024 × 500**. The local review is `outputs/storefront-20261105/review.html` at the repository root; `Sugarfall-Store-Assets-20261105.zip` contains all eight final images, the review and capture evidence.

The banner is **828,221 bytes (0.83 MB)**, a lossless 24-bit RGB PNG. SHA-256: `146af74e24da0ca6a3d629ca332deb209228316834b240ed93faf2e304db4b3d`. It preserves the cream/copper Sugarfall title, Mabel on the right, mint tray, three food collisions and pastel decorative background. Built-in Imagegen used the supplied image as its edit target; a format-only Lanczos reduction produces the requested dimensions. The prompt, reference, generated source, export script and validation are under `concept-art/storefront-v3/`.

All screenshots are **1080 × 1920**, RGB PNGs, with no extra caption, frame, generated gameplay or developer overlay. The first three show gameplay in all three areas before upgrades and earned abilities.

| Order / file | Content | Suggested alt text |
| --- | --- | --- |
| 1 — `01-bakery-gameplay.png` | Bakery tray 4, live doughnuts, cookie contacts, damage values, time pickup and cups. | Doughnuts hit silver cookie pegs above five collecting cups in Bakery. |
| 2 — `02-gelato-aim.png` | Gelato tray 4, aligned launcher, curved dotted preview and ice cream in flight. | Gelato ice cream follows a curved dotted aim preview toward waffle pegs. |
| 3 — `03-crystal-prism.png` | Crystal tray 4, straight shots and a live timed ×2 pickup. | Crystal candy ricochets through pegs beside a floating timed ×2 pickup. |
| 4 — `04-gelato-upgrades.png` | Current Gelato garden map after 22 successful coin purchases. | Gelato upgrades branch across a ceramic garden map with owned and available nodes. |
| 5 — `05-bakery-jam.png` | First natural Jam Burst contact after buying the ability through its earned route. | A Jam Burst hit links gold cookie pegs while doughnuts fall through Bakery. |
| 6 — `06-gelato-twins.png` | Earned Dual Shot, Power reset, two launchers and two aim previews. | Two Gelato launchers show dotted aim paths above ice cream and gold waffle pegs. |
| 7 — `07-crystal-multiply.png` | A real ×2 pickup duplicates five live balls to ten; capture follows after 0.2 seconds of normal simulation. | Ten live candy balls appear after collecting Crystal’s ×2 pickup. |

The isolated fixture exports the current workspace game as a nondebug public Windows build and inherits production drawing and physics. It stages progress and wallets in memory, uses real coin-purchase and ability APIs, and records zero player-profile IO. All **491** script/data resources in its project match the current-workspace source hashes recorded at capture. The Git revision alone does not describe those inputs because the workspace contains ongoing game/interface changes; use `source-evidence.json`.

Capture sources and run instructions are under `verification/storefront-20261105/`; a versioned copy is under `concept-art/storefront-v3/capture/`. Evidence beside the final PNGs includes the capture state, resource hashes, structural validation and independent visual review. Separate banner QA verifies exact dimensions, RGB format, file size, matching delivery copy and the composition at native size. The review page is checked at desktop and phone widths; the ZIP is CRC-tested and every entry is compared with its source bytes.

These screenshots are desktop-rendered store-review captures of staged campaign states. They are **not physical Android captures or phone acceptance**. Compare them with the exact intended signed Android release before store submission, especially while ongoing interface changes are being tested. The 4 November capture set and its evidence are retained as history.

No production game content changed in this asset task. No APK was built, and no files were uploaded to Google Play or Drive.
