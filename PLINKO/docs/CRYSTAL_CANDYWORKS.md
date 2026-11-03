# Crystal Candyworks

Implemented and delivered in the **Android v0.7.0 preview on 3 November 2026**. The [verified APK record](ANDROID_SUGARFALL_v0.7.0.json) and [download links](../BUILD_LINKS.txt) identify the package now in the existing private Drive folder. Windows remains v0.6.1. These are initial tuning values; physical Android playtesting remains open.

## Area identity and control

Crystal Candyworks uses a rotating spout at the top center of the board. The player's touch sets its downward direction. Candy travels in straight lines without gravity, banks off the sides and pegs, and falls into the reward cups only when its direction takes it there. The dotted preview follows the shot to its first collision; it does not predict subsequent rebounds.

| Feature | Bakery | Gelato Garden | Crystal Candyworks |
|---|---|---|---|
| Control | Move the dispenser across the top | Aim a fixed top-center dropper at a reachable point | Aim a fixed top-center spout in a straight direction |
| Flight | Gravity-driven drops | Calculated gravity-driven arcs | Constant-speed straight travel and rebounds, no gravity |
| Base Power | 1 damage | 1 damage | 2 damage |
| Upgrade map | Original sequential family paths | Winding mixed tree with exact node ownership | Three faceted spires using sequential family prerequisites |
| Area-specific purchase | None | Dual Shot: two launchers and a Power reset | Second Prism: a second opportunity to duplicate live candy |
| Paid first entry | Starting area | Clear Bakery tray 12, pay 1,000 Bakery coins | Clear Gelato tray 12, pay 1,500 Gelato coins |

Crystal's initial launch speed is 360 logical pixels per second. The base firing interval is 1.15 seconds. Feed divides that interval by `1 + Feed × 0.055`, with a minimum of 0.74 seconds. These settings deliberately start slower and stronger than the earlier areas, but their pacing remains provisional until played on a phone.

The upgrade family stored internally as Bounce appears as **Flight** in Crystal. Each tier adds 0.5 seconds to an eight-second candy lifetime. Equipped Ricochet candy lasts another two seconds. These upgrades extend time in play; they do not add gravity or change the rebound multiplier. Cards explain the function without percentage arithmetic: “Fire candy faster,” “Keep shots in play,” and “Stay in play longer when equipped.”

## Twelve trays and separate reward tuning

Boards use gaps, shelves, crowns and side banks for straight shots. Peg centers stay within the playable board and are at least 65 logical pixels apart. Ordinary peg durability increases at three clear boundaries:

| Tray | Layout | Pegs | Ordinary HP | Armored pegs |
|---|---|---:|---:|---:|
| 1 | First Refraction | 9 | 6 | 0 |
| 2 | Mirror Wings | 11 | 6 | 0 |
| 3 | Split Gate | 14 | 6 | 0 |
| 4 | Silver Shelves | 16 | 12 | 1 |
| 5 | Banking Hall | 19 | 12 | 1 |
| 6 | Prism Workshop | 19 | 12 | 1 |
| 7 | Gold Galleries | 22 | 18 | 2 |
| 8 | Faceted Crown | 24 | 18 | 2 |
| 9 | Glass Foundry | 26 | 18 | 2 |
| 10 | Diamond Arcade | 29 | 24 | 3 |
| 11 | Crystal Loom | 31 | 24 | 3 |
| 12 | Candyworks Heart | 33 | 24 | 3 |

The four material bands are Bronze, Silver, Gold and Diamond. Armor uses 1.8 times the tray's ordinary HP. Tray 1 has no clock pegs; the remaining trays have two. The initial run timer is ten seconds before Time upgrades and earned extensions.

HP and rewards are configured independently. Ordinary, clock and prism pegs each have an eight-coin damage budget; armored pegs have twelve. The shared damage reward code distributes that fixed budget as HP is removed and pays any remainder on breaking the peg. Extra HP or a greater number of small hits cannot create extra damage coins.

Crystal also keeps the separate break reward `2 + floor((tray − 1) × 0.2)` and tray-clear reward `45 + tray × 5`. Only productive candy earns cup income. These are separate reward components, so the damage budget alone is not a tray's total payout. Power and other upgrade price growth are configured in `data/crystal_economy.json`; Bakery and Gelato retain their existing board and economy files.

## Prisms and the shop

The base run has one possible floating **×2 Prism** offer, scheduled at three seconds. It appears only when live candy is available, with a 1.5-second grace window for that condition. The offer remains tappable for four seconds. **One tap** duplicates the live candy; it does not require four taps. A clone retains its original's age, spent special effects and damage cooldown, so collecting a Prism does not rearm Impact or Splitter. The total live-object cap still applies.

**Second Prism** is the separate map node below the central Feed starter. It is visible while locked, requires both tray 6 unlocked and Power 4, and costs 900 Crystal coins. Buying it allows another offer at 7.5 seconds, subject to the same live-candy and expiry rules. It preserves existing upgrades and Power. An expired or missed offer is not rerolled. The second offer is an opportunity, not a guarantee of two successful collections.

The Crystal map has the same 62 ordinary upgrade identities and legal sequential prerequisites as Bakery, in a new portrait composition with three rising faceted routes. The special purchase makes 63 displayed positions. Buying Feed 1 reveals the three route heads. Eligible affordable nodes are green, including when Infinite money is enabled. Owned nodes remain inspectable, and selecting a node does not buy it.

## Campaign, developer access and saves

First paid entry creates Crystal at tray 1 with zero coins, zero upgrades and no Second Prism. The 1,500-coin fee is taken from Gelato's record even when the player opens the area picker from Bakery. Bakery's wallet stays intact. The outgoing state, Gelato debit, new Crystal record and entry ledger save as one transaction; a failed write leaves them unchanged. Returning to Crystal restores its own progress without another fee.

The developer page now offers Bakery, Gelato Garden and Crystal Candyworks. Starting an unvisited area there bypasses completion and entry payment, creates its normal empty record, and keeps it on later visits. Each area's Infinite money toggle remains session-local, while upgrades purchased during testing persist. See [Developer settings](DEVELOPER_AREAS.md).

Profiles now write version **5**. The area decoder accepts versions 3–5. Legacy version 3 or 4 records without `crystal_second_prism` receive `false`; a version 5 record must contain the field, and it cannot be true outside Crystal. Existing Gelato exact-node ownership and Power rebuild metadata remain intact.

Interrupted Bakery and Gelato runs retain checkpoint schema **4**. Crystal uses schema **5**, adding Second Prism ownership and run-local offer state so resume cannot grant another chance at an already spent offer. This is separate from the profile version. Unsupported or malformed state follows the existing blocked-load and transactional-save behavior.

## Verified and still open

The [consolidated source validation](../../verification/crystal-area-20261103/validation.json) records **2,494 passing checks across 21 suites**. This includes 253 focused art, real-disk persistence and GPU checks, with 40 captures at 720×1280 and 450×800. The seven native ImageGen assets, atlas regions, entry flow, Prism pickup and Second Prism card were reviewed in the production renderer. [Asset provenance](../../concept-art/crystal-candyworks-v1/sources.json) retains the exact prompts and unchanged generated source files.

The [physics and pacing record](../../verification/crystal-20261103/physics-pacing-manifest.json) includes 216 synthetic runs across fixed builds, aim policies and Prism collection settings. Every run terminated. Some comparisons force Second Prism ownership below its normal gates to isolate the mechanic; they are not simulations of a legal purchase path. The initial tuning is retained for phone feedback, without claiming a human completion time.

The isolated Godot 4.6.3 source checks in `verification/crystal-candyworks-20261103/ui-01`, `ui-02` and `ui-03` cover Crystal entry and UI, Gelato navigation and launcher shop, both existing upgrade maps, developer area switching, developer touch controls and Infinite money. The final passing results across these nine suites contain 966 assertions. They include entering Crystal while Bakery is active, charging only Gelato, failure rollback, legacy flag defaults, three-card developer layout, all twelve Crystal board records and the Second Prism gates and purchase.

The authoring tool checks all 63 map footprints, minimum node spacing, route intersections and unrelated-node clearance. Its guide and geometry report are in `concept-art/crystal-candyworks-v1`. Runtime persistence fixtures use disposable project copies and isolated user directories; UI fixtures do not read a player's profile.

These checks establish functional behavior, not a completion-time or human difficulty result. Remaining phone playtests should assess aiming and bank-shot comfort, Prism visibility and one-tap collection, screen crowding after duplication, the three durability walls, coin income and purchase cadence, and whether Flight is useful without making runs feel stalled. Record findings before finalizing the provisional economy. APK integrity and Drive delivery are recorded separately in the release manifest; the focused UI checks alone are not evidence of physical Android execution.
