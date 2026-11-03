# Developer settings

Open **Home menu → Settings → Developer settings** in the editor, a debug build, or an export explicitly tagged with the custom `developer` feature, provided the build is not tagged `sugarfall_public`. The public feature overrides both debug and developer access. The page has three cards: **Bakery**, **Gelato Garden** and **Crystal Candyworks**. Choose **Start fresh** for an unvisited area or **Continue** for a saved area. The game opens that area's Home screen. **Current** identifies the active area and cannot reset it.

The same page has **Infinite money** for the active area. Turning it on lets upgrade, Jam Burst, Dual Shot and Second Prism earned purchases succeed without spending the real wallet. Normal prerequisites, tray gates, upgrade caps and Gelato's Twin Power reset still apply. Gelato buys the selected exact node and grants one next aggregate family tier; it does not grant other same-family nodes. Bakery Jam Burst requires tray 8 and Power 4; Crystal Second Prism now requires tray 8 and Power 4. Preview early purchases use a separate explicit test flow; Infinite money does not fabricate a real payment. The shop shows an infinity wallet while enabled. Each area keeps its own toggle for the current session; restarting the app or Reset progress clears the toggle. Upgrades purchased during testing remain saved. This feature is disabled in normal release builds and in Trials.

Developer entry skips both normal first-entry gates: Bakery tray 12 plus 1,000 Bakery coins for Gelato, and Gelato tray 12 plus 1,500 Gelato coins for Crystal. Crystal can be opened directly without first creating a Gelato record. Developer entry does not spend coins, grant coins, or record a paid entry. Normal campaign entry retains those requirements and charges the predecessor area's wallet even if another area is active. Normal release builds hide and reject developer entry unless deliberately tagged `developer`; public builds reject it regardless of that tag. Public Settings also omits the performance toggle and simulated commerce entry.

## Independent area progress

The first visit creates the normal empty area record: tray 1, zero coins, no upgrades, no modules, no Trial records, no Twin launchers and no Second Prism. Returning to a visited area restores its wallet, aggregate upgrade levels, exact Gelato node ownership, Power nodes awaiting rebuild, Crystal's Second Prism, selected and unlocked trays, completion state, module inventory/loadout and Trial records. The area also reloads its own board designs, gameplay rules, art and economy tuning. Gelato's authored shuffle remains fixed across every visit.

These are the existing per-area records in the current profile. They persist through ordinary saves and restarts; there is no separate temporary developer profile. An area opened here stays owned in that profile, including when the same profile is later opened in a normal release build. Sound and Reduced Motion remain profile-wide. Preview simulated purchase benefits are profile-wide only in preview builds. A public build discards the optional simulated ownership field and pending simulated reward flag while retaining ordinary earned progress and the unclaimed base result. **Reset progress** still clears the whole profile using its existing confirmation.

The Android **v0.7.0 preview** includes Crystal and the three-card developer page. See the [verified delivery record](ANDROID_SUGARFALL_v0.7.0.json) and [download links](../BUILD_LINKS.txt). Physical Android playtesting remains open. The earlier Android v0.6.14 preview introduced the winding mixed tree with its ceramic courtyard background and [profile version 4](GELATO_NODE_OWNERSHIP.md). Current source writes profile version 5 and reads area records from versions 3–5. Legacy records default Second Prism to false; version 5 requires an explicit area-local field. Bakery and Gelato interrupted runs keep checkpoint schema 4, while Crystal uses schema 5. See [Crystal Candyworks](CRYSTAL_CANDYWORKS.md).

Old count-based Gelato records still migrate automatically. Developers staging count-only runtime fixtures must explicitly select legacy revision 0 before calling `ensure_gelato_shop_state()`. A malformed revision-1 record is rejected rather than repaired from counters. Fixtures changing areas must also apply that area's record instead of leaving the previous area's ownership metadata in memory.

## Save and input behavior

The outgoing area's latest state and the destination record are written together before the active area changes. A failed save leaves the current area and progress intact. Switching is unavailable during an unfinished or uncollected run, a Trial, an active transition, Mabel's guide, a pending simulated purchase/ad, another area transaction, or a blocked profile load.

Unsupported profile versions block ordinary saves, purchases and area changes. The existing **Reset progress** confirmation can intentionally replace any blocked profile; failure to write that reset leaves the blocked file intact. Developer entry and Infinite money never perform that reset implicitly.

Area selection activates on touch release. Dragging, canceled touches, multiple fingers and a held touch carried over from Settings cannot trigger an area change. Back returns to Settings.

## Verification

The v0.8.0-rc1 public policy is exercised both in a debug editor (60 checks) and a real nondebug Windows export tagged `sugarfall_public` (66 checks), using isolated profiles. The exported test covers all three areas, hidden and directly invoked test paths, developer/diagnostic access, forged simulated callbacks, old preview ownership import and exactly-once base collection. Evidence: `verification/release-candidate-v080/public-qa-03`. This does not claim Android device execution.


The final [Crystal source validation](../../verification/crystal-area-20261103/validation.json) passed 2,494 checks across 21 suites. Its 40 GPU captures include the three-area picker and developer page at 720×1280 and 450×800. The focused developer counts below are included in that total, not additional to it.

Current Crystal source verification is recorded in `verification/crystal-candyworks-20261103/ui-01`, `ui-02` and `ui-03`. Focused area/UI coverage passes 35 Crystal checks, 101 developer area checks, 59 developer page checks and 50 developer money checks. Crystal coverage includes direct developer entry, independent revisit records, normal entry from an active Bakery without debiting Bakery, Second Prism gates and failed-write rollback. The page test checks all three cards and separation from the money control. These are functional checks; phone playtesting remains open.

Earlier mixed-tree coverage includes exact purchased-node restoration, free Twin reset/rebuild, Trial restoration and failed-write rollback in `verification/gelato-tree-20261102/regression/run-01`. These suites use a disposable project and verify Godot's actual isolated user directory before running save fixtures.

`tests/developer_area_qa.gd` exercises first visits, repeat visits, real isolated save/reload, failed-write rollback, area-specific tuning, developer-build gating and unchanged normal entry requirements. `tests/developer_area_ui_qa.gd` exercises Settings entry, labels, input gestures and transaction guards. Both are included in `tests/run_windows_tests.ps1`; the save fixture refuses to run without its explicit isolation flag and environment path.

The original developer-settings task's regression logs, rendered previews and validation record remain under `verification/developer-areas-20261102` at the workspace root. Visual previews use frozen in-memory state and never load a player's profile.

Historical developer-settings verification, November 2, 2026: eleven regression suites passed 936 assertions, including 91 area-transaction checks and 47 developer-UI checks. The renderer passed 65 checks across sixteen captures at 720×1280 and 450×800; all captures were visually reviewed. Tested production scripts/data and rendered UI sources matched that revision. Release gating was checked with an availability-disabled fixture and source review; that task did not create a release export.
