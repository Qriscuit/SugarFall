# Area acceptance playtest

Use this record for AF-008 (human progression/teaching) and AF-009 (physical phone). Automated runs and desktop screenshots are separate evidence. Leave a result blank until it has actually been observed.

## Session

| Field | Record |
|---|---|
| Tester and date | Pending |
| Phone model / Android version / refresh rate | Pending |
| APK filename / version / SHA-256 | Use the exact manifest for the installed build |
| Previous installed preview / update or clean install | Pending |
| Starting area wallets, unlocked trays and special ownership | Pending |
| Battery / thermal state / battery-saver state | Pending |
| Sound / Reduced Motion settings | Pending |

Use the normal preview update flow to retain progress. Do not reset the player's only save for a fresh-progression experiment; use a separate test device/profile or a deliberate, user-chosen reset. Developer area switching retains each area's independent records. Infinite money is useful for effect inspection; turn it off for progression measurements.

## CHG-036 source follow-up

The delivered v0.7.6 APK includes the area frames, Jam Burst, tray-8 Second Prism gate, Flow-2 rules and ownership-aware checkpoint restoration. Extend D02/D06 to earned gates, exact charges, failed/duplicate purchases and retained ownership; D03 to every-fifth Jam charge/spent state; D05 to both Prism opportunities; D07/D17 to each themed frame and offer. Check old active-run continuation and new-run HP/rewards separately. Compare normal-wallet earned progression against any explicitly labeled preview early access. A preview test purchase charges no money and cannot verify real Play payment/restore. Public billing acceptance remains U08, outside the current simulated flow. All existing device checks remain Pending.

## Device checks

Working performance targets: a 60 FPS gameplay target on the recorded device, no sustained slowdown during normal play, no input freeze or crash, and no steadily growing memory use across repeated runs. Record frame timing and the device's supported refresh rate; desktop timings do not satisfy these targets. Log any sustained drop below 50 FPS or hitch over 250 ms as a finding to investigate.

| ID | Action and acceptance | Result / evidence |
|---|---|---|
| D01 | Install over the previous preview. Existing wallets, nodes, selected/unlocked trays and global settings remain. | Pending |
| D02 | Load each area, run a tray, buy an affordable node, leave and revisit. Each area retains its own state. | Pending |
| D03 | Bakery: drag the dropper across the width; its drop-column cue follows, including near edges. | Pending |
| D04 | Gelato: aim left/center/right with a finger. Observe the falling curve up to its first collision. Repeat with both Twin emitters. | Pending |
| D05 | Crystal: aim and ricochet; tap a Prism within four seconds. Live balls duplicate once, including spent-special state. Let an offer expire; check Second Prism. | Pending |
| D06 | Pan/pinch each upgrade map, select deep nodes, inspect cards and press Buy. Extra/canceled touches and drags do not purchase accidentally. | Pending |
| D07 | Review Help, loadout, Trials, Settings, Pause and clear/fail results. Functional titles, action/state labels and necessary explanations are clear without repeated or decorative prose. Related controls form readable groups; text stays inside panel padding and touch targets feel comfortable at the actual device scale. Confirm destructive actions and important costs/rewards remain explained. | Pending |
| D08 | Play a crowded late build in each area. Hits, damage numbers, break effects, catch feedback, timer and coins remain readable. Repeat with Reduced Motion. | Pending |
| D09 | Listen for ordinary hits, breaks, catches where specified, pickups and upgrades. Confirm Crystal Prism now sounds; Sound off suppresses cues. | Pending |
| D10 | Background during play, an active pickup and an uncollected result. Resume safely paused; collect once. Repeat after process restart. | Pending |
| D11 | Finish a tray with splitter/Prism balls active. The final balls settle and the result appears without hanging or repeated rewards. | Pending |
| D12 | Play for at least 20 minutes, cycling all areas and crowded builds. Record FPS/slow frames, hitches, heat and memory at start/end. | Pending |
| D13 | In every area, move between Home, Upgrades and Settings through the cream wave where used. Confirm a smooth fully covered change, no lost run time, and no purchase/launch from an extra tap. Background during the wave and resume safely; repeat with Reduced Motion. Check Home symbols, the single Settings title and centered control group, and damage numbers without boxes at actual phone scale. Home Play/results follow D16; pause/resume follows D17. | Pending |
| D14 | Record cold launch (process absent), warm launch (activity recreated) and hot return (activity still running). Check the Android system-icon handoff, warm spotlight and smooth heartbeat brightening/scaling from the lower center, then the cream reveal without a flash or extra action. Listen to the gentle hum on speakers/headphones; saved Sound off must be silent from the first sample, and background/return must not stack voices. Hot return retains state without restarting the studio unnecessarily. Stored Reduced Motion gives a static logo and immediate handoff once loaded. Background during loading/wave; retain the correct area, paused run or uncollected result and collect only once. Record stalls, crops, sound levels and touch issues; preserve the only player save. | Pending |
| D15 | On a tall phone in each area, inspect Home, play, maps, menus, entry and results: the background fills the usable viewport without black bands or an exposed seam. The Tray HUD fits without overlap/cropping. All six cup faces show their current multipliers clearly and stay aligned with the cups, including bonus/late-build values. Record aspect ratio, cutout/navigation-bar behavior and screenshots. | Pending |
| D16 | Press Home Play in each area: the preview tray/cookies zoom and morph into the board while equipment enters, with no cream wipe. End by clear, timeout and Finish & Collect: the result is a modal over the darkened frozen board, without cream. Check no hidden motion, time loss or extra input and exactly-once collection. After process restart, pending earnings/history remain but the window uses an empty themed tray; peg/ball poses are not saved. Repeat with Reduced Motion; D13/D14 menu/startup routes remain intact. | Pending |
| D17 | On v0.7.6-preview, which includes CHG-034, pause each area during moving balls and an active pickup. The sharp pause menu fades in over a gentle full-screen blur/shade, without cream. Resume fades the menu away first, then the blur; gameplay and its timer resume only after both finish. Check tall-screen edges, rapid extra taps/Back, abandon-confirmation and cancel, background/return during opening and closing, and Reduced Motion's immediate settled state. Startup into a saved paused run keeps its cream reveal; ordinary menu and Home/result routes remain D13/D14/D16. Record readability, blur strength, smoothness and input feel. The unchanged public v0.8.0-rc1 packages predate the pause/menu revision. | Pending |

## Normal-wallet progression and teaching

Use `AREA_PROGRESSION_BALANCE.md` for the current targets and synthetic findings when that report is available. Record actual legal purchases; retain failed attempts and route choices. Developer money and manually granted nodes must be off. A simulator's clears do not establish human pacing or comprehension.

| Area / tray | Starting upgrades / wallet | Attempt / seconds / clear? | Earned coins | Purchase and remaining wallet | Lesson understood / friction |
|---|---|---|---|---|---|
| Pending | | | | | |

Observe the first encounter with each control without explaining it outside the game. At trays 4, 7 and 10, note whether the stronger material is recognized and whether the next useful purchase is affordable within a reasonable number of retries. Record entry costs between areas separately from in-area spending.

For Gelato, capture the legal path to tray 8 + Power 6, the 3,000-coin Dual Shot purchase, and the Power rebuilding period. For Crystal, record the four-second pickup's discoverability and whether buying Second Prism feels useful. Record confusion or an unfun grind as a finding even if the player eventually clears.

## Current availability

On 3 November 2026, `adb devices -l` returned no attached Android device. No phone installation, listening session, sustained device performance pass or human progression session was performed by the implementation work. AF-008 and AF-009 retain those open acceptance steps.
