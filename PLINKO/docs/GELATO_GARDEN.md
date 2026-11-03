# Gelato Garden

Current design: 3 November 2026. Gelato Garden is the second of three playable areas, between Bakery and Crystal Candyworks. It has its own artwork, twelve authored peg arrangements, wallet, upgrades and progress. The currently delivered Android build is [v0.7.4-preview, code 29](ANDROID_SUGARFALL_v0.7.4.json), replacing the existing private Drive APK in place. The area first shipped on 24 October; earlier test results below remain historical.

This delivery adds [full portrait scenery, padded HUD text and cup-face labels](SCREEN_LAYOUT.md), including a higher label on Gelato’s gold bowl. Home Play uses the tray zoom/morph and results sit over the frozen board; neither uses cream. The [studio heartbeat introduced in v0.7.3](STUDIO_STARTUP.md) and ordinary menu cream remain. Gelato’s wallet, exact node ownership, aiming and economy are preserved. The [1,877-check software validation](../../verification/screen-polish-20261103/validation.json) covers current layout/flow and startup/save cases; [legal progression measurements](AREA_PROGRESSION_BALANCE.md) remain the earlier synthetic baseline. Physical Android and human pacing acceptance remain open.

This document describes the implemented behavior. The [launcher design](GELATO_LAUNCHER.md) covers gravity-aware aiming and Dual Shot; the [winding mixed tree](GELATO_U_MAP.md) covers current purchase routes and ceramic garden. The earlier [next-area proposal](NEXT_AREA_PROGRESSION_DRAFT.md) is an archived design reference. The [2 November rebalance](ECONOMY_REBALANCE.md) sets the current coin budgets, Impact rules and 1,000-coin entry fee. See [ART_DIRECTION.md](ART_DIRECTION.md) for the visual system and asset-authoring rules. Current gaps and evidence are in the [area checklist](areas/gelato_checklist.md) and [area fix register](../../AREA_STATUS.md).

## Entering Gelato Garden

Clear Bakery tray 12, collect the finished result, and save **1,000 Bakery coins**. Open the winding level journey from the Home level plaque. At the top of the Bakery trail, the Gelato Garden gate shows the coin requirement and completed tray count. Entry is enabled only when all twelve destination boards and the required food, environment and UI art are available.

The gate opens a short confirmation with the destination illustration and three functional statements:

- Upgrades restart
- Purchases stay
- Leftover coins stay in Bakery

The Enter button displays the live fee. Cancel and system Back close the confirmation without spending or changing progress. The fee is rechecked when Enter is released. Active runs, uncollected rewards, trials, purchase/ad requests and another pending area transaction prevent entry.

The first successful entry charges 1,000 Bakery coins once, creates Gelato's local record, and opens Gelato Home on tray 1. It starts neither a run nor an ad. For example, entering with 1,500 Bakery coins leaves 500 in Bakery and starts Gelato with 0.

## What starts fresh and what stays

| State | First entry to Gelato Garden |
| --- | --- |
| Eight upgrade families | All tier 0, with no exact nodes owned. The winding mixed tree begins at Feed 1. |
| Dual Shot and Power rebuild | One launcher; no reset history or rebuild nodes. |
| Equipped specials | Empty. Their upgrade tiers must be earned in Gelato. |
| Current and highest unlocked tray | Both 1; area not complete. |
| Wallet | 0 Gelato coins. Bakery keeps its exact remainder after the displayed fee. |
| Treat vouchers and milestone claims | Empty. Gelato's own tray 2, 5 and 8 milestones can be earned once each. |
| Best tray and trial records | Fresh local records. Bakery's records stay in Bakery. |
| Remove Automatic Ads | Retained; continues suppressing automatic ads. |
| Baker Toolkit | Retained; the existing 20% normal campaign payout benefit applies in Gelato. |
| Sound and Reduced Motion | Retained. |
| Attempt counts, active-play cooldown and request serials | Retained globally. Area navigation does not reset or trigger ad eligibility. |
| Run serials and claimed reward identity | Retained globally so changing area cannot reuse a run or claim. |

“Upgrades restart” describes the new area's empty build. It does not erase Bakery's build. Each area's coins, upgrades, equipment, unlocked trays, completion state, vouchers, milestone claims and trial records remain separate. Replaying Bakery earns Bakery coins; they do not become a Gelato starter wallet.

Benefits still use the existing `remove_ads` and `baker_toolkit` IDs and survive ordinary area entry and switching. Monetization remains the local test service; this work does not connect store accounts, real purchases, production ads or cloud ownership. The game now has one campaign. Its separate **Settings → Reset progress** action clears progress in every area and all simulated purchase/ad state after confirmation, retaining Sound and Reduced Motion. That reset is distinct from entering or revisiting Gelato.

## Returning to an owned area

Tap the area title in the winding journey to open the three-area picker. Selecting an owned area saves the outgoing local state and opens the destination Home with its saved tray, wallet and upgrade build. It charges no fee and performs no reset. Selecting the current area only closes the picker.

Selecting an unowned Gelato Garden brings its gate into view. If all requirements are met, it opens the same first-entry confirmation. The map remains full-screen beneath its floating controls; the picker and confirmation temporarily consume covered controls and map gestures.

After clearing Gelato tray 12 and collecting the result, the [Crystal Candyworks](CRYSTAL_CANDYWORKS.md) gate requires **1,500 Gelato coins**. The first entry debits Gelato's wallet even if the picker was opened from Bakery, and creates Crystal at tray 1 with zero coins, upgrades or Second Prism. The outgoing state, fee, new record and entry ledger save atomically. Failed writes leave all areas intact; revisits are free. Crystal has twelve trays and its own straight-shot, timed-Prism mechanic.

## Controls and upgrades

A fixed nozzle at `(360,267)` solves a downward gravity trajectory toward the finger at speed 260 and gravity 400. The dotted curve stops at its first live wafer or reachable target; it does not predict later rebounds. Unreachable high, wide targets clamp to the common reachable range. Dual Shot uses nozzles at `(318,267)` and `(402,267)`, with separate mint and berry curves aimed at the same target.

Dual Shot is the optional map node below Feed 1. It costs **3,000 Gelato coins** and requires **tray 8 unlocked AND six active Power upgrades**. Buying it resets only Power and retains exact previously purchased Power nodes for rebuilding. Each launcher fires at 65% of the single-launcher rate. Rebuilt Power costs twice as much before rounding and gains 35% more per tier. Other upgrades, equipment, map discovery and remaining coins stay intact. The two winding main routes and six terminal branches use a fixed family shuffle; owning a node grants only that exact slot and the next aggregate tier of its family.

The same Dual Shot ability also has a planned US$2.99 permanent early route from tray 1. The preview test flow is implemented; real public billing remains unfinished. See [signature access](AREA_SIGNATURE_ABILITIES.md). These CHG-036 changes and [Flow rules 2](AREA_FLOW_RULES.md) are delivered in the [v0.7.6 APK](ANDROID_SUGARFALL_v0.7.6.json).

## Twelve authored trays

The layouts are explicit coordinates in [gelato_board_design.json](../data/gelato_board_design.json). Home previews use those same coordinates and role assignment as the live board. These are new arrangements rather than copies of Bakery's layout families.

| Tray | Layout | Pegs | New-run HP | Chocolate armor | Clock wafers |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | First Fan | 8 | 6 | 0 | 0 |
| 2 | Sundae Fork | 10 | 6 | 0 | 2 |
| 3 | Wafer Cascade | 12 | 6 | 0 | 2 |
| 4 | Ribbon Lanes | 16 | 12 | 0 | 2 |
| 5 | Open Chevron | 18 | 12 | 0 | 2 |
| 6 | Sprinkle Sweeps | 20 | 12 | 0 | 2 |
| 7 | Twin Fans | 24 | 18 | 0 | 3 |
| 8 | Broken Arches | 26 | 20.7 | 0 | 3 |
| 9 | Zigzag Lanes | 28 | 20.7 | 0 | 3 |
| 10 | Chocolate Lattice | 30 | 27.6 | 2 | 3 |
| 11 | Stepped Crown | 32 | 27.6 | 3 | 3 |
| 12 | Grand Cascade | 36 | 27.6 | 4 | 3 |

The Bronze/Silver/Gold/Diamond boundaries remain at trays 1/4/7/10. Current Flow-2 new-run HP is 6 on trays 1–3, 12 on 4–6, 18 on 7, 20.7 on 8–9 and 27.6 on 10–12. Legacy active runs retain their pinned values. Late armor has twice the listed base HP. The existing bonus-role assignment begins at tray 3; armor and clock roles take precedence. Current centers span x=100–620 and y=350–835, with at least 73 logical pixels between neighboring centers.

Area-selected food sprites retain the normal, Splitter, Impact, Ricochet and shard roles and existing collision footprints. Wafers replace cookie pegs and sundae cups replace collection buckets. Existing peg damage stages, hit feedback, cup bounce, whole-number coin display and seamless Home-to-run entry remain in use. The art inventory records reused assets and native Gelato originals separately.

The damage payout is a fixed six-coin budget per ordinary/clock/prism wafer, or nine for armor, before tray 8. Flow 2 uses 8/11 from tray 8 and independently scales completed break/clear rewards once with whole-coin rounding. Budgets remain independent of HP and the number of hits. Separate break, cup and clear rewards remain. Gelato overrides upgrade price growth to 1.65, Power growth to 1.60, and the Twin/rebuild rules; it does not reuse Bakery's upgrade price curve. See [the current reward contract](ECONOMY_REBALANCE.md).

## Saves and interrupted play

The campaign writes a **version 5** profile envelope with an active area, three independent area records as unlocked, and a first-entry ledger. Entry and owned-area switches write the complete candidate save before applying any live wallet or area changes. If writing fails, the current area stays intact and the confirmation remains open. The loader retains older Bakery-only version 1/2 migration and accepts area envelopes 3–5.

The canonical production file is now `user://sugarfall_save.json`. On the first updated launch, the previously selected older campaign is migrated, using its version 3 area save or corresponding version 1/2 Bakery save. The original files are retained. Once the canonical save exists, it is authoritative; resetting progress cannot re-import old area ownership on the next launch. The older `sugarfall_areas_v3.json` and `sugarfall_fresh_test_areas_v3.json` files are migration/recovery sources, and Main/Fresh Test selection is no longer exposed. See [the reset and migration contract](NEW_PLAYER_EXPERIENCE_GDD.md#reset-progress).

Active-run snapshots and pending results carry area identity. Bakery and Gelato retain checkpoint schema **4**; Crystal uses schema **5** for its Prism offer state. Gelato's exact owned/reset node metadata, Twin ownership and Power count remain campaign state, preserved across Trials and area changes. A result belongs to its originating area's wallet and tray progression. Snapshot compatibility checks use the relevant area's content; valid interrupted runs resume paused, without automatic dropping or an entry fee.

The entry illustration can draw Gelato art while Bakery is still active. All three art helpers select and cache area resources; that preview does not switch the live campaign.

## Current validation and limits

The current [v0.7.4 APK record](ANDROID_SUGARFALL_v0.7.4.json) records this delivery and its package/source checks. Gelato Help retains the visible Dual Shot node's tray 8 AND Power 6 requirement. [The legal progression baseline](AREA_PROGRESSION_BALANCE.md) completed all twelve Gelato trays in 41–51 attempts under two bounded shopping policies across three seeds, with real mixed-route purchases, earned vouchers, paid entry fees and Dual Shot resetting/rebuilding. The full six linked campaigns across all three areas passed 9,044 legality assertions. These are synthetic results, not physical-phone execution or human pacing acceptance. The shared [cream-wave menu update](MENU_TRANSITIONS.md) changes presentation without changing these economy values.

The [3 November area audit](areas/gelato_checklist.md) separates built content from missing evidence. AF-003's current design documentation is synchronized with the delivered v0.7.4 build. Human understanding of detours, the feel of the Dual Shot reset, phone comfort and performance remain open. The legal trace flags Gelato tray 11 for 12 attempts in one seed; that issue is tracked for phone testing before changing balance numbers.

Historical v0.7.0 [source validation](../../verification/crystal-area-20261103/validation.json) records 2,494 passing checks across 21 suites, including 175 renderer checks across 40 captures. Its [historical APK record](ANDROID_SUGARFALL_v0.7.0.json) separately records 462 payload and 16 Android package checks and that build's private Drive delivery. These retained counts describe v0.7.0 rather than the current package.

### Historical 24 October area validation

The original isolated Windows regression run passed **13 suites / 965 reported checks** with the then-current art imported. Its retained report is [summary.json](../../QA/gelato-final-regression-20261024/summary.json).

The original focused navigation suites passed **89 Bakery checks** and **57 Gelato checks**. They exercised actual navigation and area commits with player persistence replaced by memory. Coverage included insufficient funds, unavailable content, cancellation, failed writes, repeated taps, two-finger gestures, focus loss, safe-area transforms, owned-area round trips, and the then-deliberate absence of a third-area fee. Crystal entry now supersedes that last historical expectation.

The original area progression suite passed **65 checks**, including isolated-file restart, legacy version 1/2 migration, authoritative version 3 behavior, exact fees and fractional balances, wallet limits, each permanent purchase ownership combination and restore effects, ad cadence, the former separate test profiles, and area-bound active runs and pending rewards. This is historical validation of the 24 October implementation; the profile feature is now retired. These fixtures did not read or write the player's save. Current reset and migration evidence is recorded in [the first-player-experience GDD](NEW_PLAYER_EXPERIENCE_GDD.md#implementation-and-verification-record).

Those twelve earlier layouts passed bounds, distinctness and spacing checks, with matching Home previews. An earlier zero-upgrade fixture earned its first Feed upgrade within three no-ad idle attempts. Current launcher layouts and legal purchase cadence have their separately dated evidence above; these original figures are not current pacing results.

These historical checks were functional, not human pacing validation. The original shared pricing and later-HP choices were replaced by the launcher economy, material bands and reward rebalance described above. No 2–3-hour Gelato completion target, retention result or physical-phone test is claimed by those earlier checks.

Run the complete Windows regression set from the project directory using the isolated runner:

```text
powershell -NoProfile -File .\tests\run_windows_tests.ps1 -Godot "C:\Tools\Godot_v4.6.3-stable_win64_console.exe"
```

Replace the example engine path with the installed Godot console executable. The runner copies the project into a disposable directory and isolates Windows user data before running save fixtures. The area progression fixture deliberately refuses a direct invocation unless its isolated scratch path and explicit isolation flag are provided.

The independent `tests/gelato_art_qa.gd` fixture checks imported assets and renders the real screens at desktop phone-shaped resolutions. Its visual outputs are separate from device testing.
