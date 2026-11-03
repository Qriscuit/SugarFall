# Gelato launcher, layouts and economy

Current design: 3 November 2026. Gelato uses a fixed top-center launcher aimed downward toward the player's finger, with gravity retained. Bakery keeps its movable dispenser and separate economy. The delivered [v0.7.4-preview (code 29)](ANDROID_SUGARFALL_v0.7.4.json) retains this launcher, the ceramic mixed tree, profile 5 and Crystal Candyworks as Gelato's successor, with the corrected Dual Shot Help requirements. Its shared [cream-wave navigation](MENU_TRANSITIONS.md) leaves Gelato's launcher and purchase rules unchanged. The implementation and pacing records from earlier builds below remain historical where labeled.

This delivery adds [full portrait scenery, padded HUD text and cup-face labels](SCREEN_LAYOUT.md), including a higher label on Gelato’s gold bowl. Home Play uses the tray zoom/morph and results sit over the frozen board; neither uses cream. The [studio heartbeat introduced in v0.7.3](STUDIO_STARTUP.md) and ordinary menu cream remain. Gelato’s wallet, exact node ownership, aiming and economy are preserved. The [1,877-check software validation](../../verification/screen-polish-20261103/validation.json) covers current layout/flow and startup/save cases; [legal progression measurements](AREA_PROGRESSION_BALANCE.md) remain the earlier synthetic baseline. Physical Android and human pacing acceptance remain open.

## Controls and boards

The single launch point is `(360,267)` in board coordinates. A touch or drag below it selects the point the ice cream should reach. The launcher solves the downward ballistic trajectory at 260 pixels per second with gravity of 400 pixels per second squared, and rotates to that curve's initial tangent. Round dots show the calculated path through its full flight time, stopping at the first live wafer or target. An unobstructed endpoint ring marks the reachable target. Shots continue automatically at the Feed-controlled rate. Pause and the Home entry animation stop gameplay; Reduced Motion retains the same aiming path.

Touch input supports x=66–654 and y=330–1000. Very high, wide points outside the downward flight envelope are clamped horizontally to a reachable endpoint at the same height; firing speed never increases to compensate. With twins, the target lies inside both launchers' reachable ranges, and each nozzle solves its own arc to that shared point. Every authored peg center is reachable from both nozzles at the original speed.

Gelato launcher shots have no random initial spread. Simulation uses the exact constant-gravity step `p += v*dt + 0.5*g*dt²`, then `v += g*dt`, so free flight matches the preview regardless of the physics step size. Collisions still bounce and scatter normally; the dots do not predict those later bounces. The contact preview uses the ordinary ball radius; larger special foods follow the same curve but touch a wafer slightly earlier. Bakery's movement and launch spread remain unchanged.

Twelve authored fan, arc and lane layouts replace the former Gelato arrangements. Upper rows are narrow and lower rows open outward, leaving aiming lanes from the fixed launcher. Peg counts grow from 8 to 36, center spacing is at least 73 pixels, and every peg has a gravity-driven direct trajectory from the single launch point within the allowed touch controls. Collisions can still block that path until earlier pegs break.

| Trays | Material | Ordinary, clock and prism HP |
| --- | --- | ---: |
| 1–3 | Bronze | 6 |
| 4–6 | Silver | 12 |
| 7–9 | Gold | 18 |
| 10–12 | Diamond | 24 |

Late armored wafers have twice the ordinary HP. Tints use existing sprites and damage frames. Gelato's golden waffle body is corrected before tinting to keep Silver and Diamond distinct. Material names appear on Home and the gameplay HUD.

## Twin launchers and rebuilding Power

In the current [winding mixed tree](GELATO_U_MAP.md), Dual Shot (Twin launchers) remains visible below Feed 1, including while locked. Its displayed link connects to Feed 1; purchase still costs 3,000 coins and requires both tray 8 to be unlocked and six active Power upgrades. The left main path can supply six Power purchases without optional branches. Existing owners keep the upgrade even below these requirements. The card explains the tradeoffs before purchase. The mixed tree and exact-node ownership first shipped in the historical [v0.6.13 APK](ANDROID_SUGARFALL_v0.6.13.json), retaining the below-entry placement from v0.6.12; the current delivered build is v0.7.4.

- Buying it permanently unlocks two nozzles at `(318,267)` and `(402,267)` aimed at the same finger position.
- Power resets once to tier 0, dealing 1 damage per ordinary ball. All other upgrades, equipment and progression remain owned.
- Each launcher fires at 65% of the corresponding single-launcher rate, giving 130% combined output.
- Power repurchases cost 2× before rounding and have 35% stronger tier gains. Power 1/2/3 rebuild to 1.675/2.35/3.025 damage per ball, applied to both launchers.
- The exact previously purchased Power nodes remain visible and rebuildable. Their historical purchase state keeps discovered paths open, including legacy nodes whose shuffled parent is missing. Eligible, affordable rebuilds are green, unaffordable rebuilds red, and locked new nodes neutral. Rebuilding grants the next actual Power tier; internal node ordinals impose no order. New unpurchased nodes still require their drawn parent.

The purchase, reset-node transfer and wallet save together. A failed write restores the previous build, node sets and wallet. The upgrade cannot be bought twice, inside Trials, or over an uncollected run. The ordinary single-launcher campaign remains playable without buying twins; the changed map's human pacing still needs testing.

## Area economy

`data/gelato_economy.json` overrides the shared starting rules only while Gelato is active. Ordinary upgrade cost growth is 1.65 per tier and Power growth is 1.60, compared with Bakery's 1.75 and 1.85. First Feed remains 38 coins. The current [reward rebalance](ECONOMY_REBALANCE.md) fixes damage income at 6 coins per ordinary/clock/prism wafer or 9 per armor wafer, separate from break, cup and clear rewards. Loading or switching areas starts from a fresh copy of Bakery tuning before applying Gelato overrides.

First Gelato entry requires Bakery completion and 1,000 Bakery coins. After completing Gelato, first entry to Crystal Candyworks costs 1,500 Gelato coins and starts a fresh Crystal wallet/build. Both fees are one-time, and each owned area's revisits are free. These area-entry requirements are distinct from optional Dual Shot and ordinary shop purchases.

### Current legal progression measurements

The [3 November legal progression experiment](AREA_PROGRESSION_BALANCE.md) measured the production economy and actual mixed-node graph before the menu and startup presentation updates. Gelato clears in 47–51 attempts under the cheapest-eligible policy without buying Dual Shot, and in 41–45 under the signature policy that reserves its 3,000-coin price. In all three signature seeds, Power 6 is reset and legally rebuilt within five further runs. First entry still pays 1,000 Bakery coins; the later 1,500-coin Crystal fee needs zero or one extra Gelato replay. The six linked three-area campaigns pass 9,044 legality assertions. Human timing, reset value and phone feel remain open; no economy or physics values changed in v0.7.4.

### Historical launcher pacing

The automated figures below were measured before the gravity-aware aiming correction, branching map, later 3,000-coin Twin gate and fixed-budget damage rebalance. They are a historical baseline, not current difficulty or purchase timing. AF-008 now has the current legal experiment above and retains human pacing acceptance as open.

All twelve sampled campaigns completed in 36–62 attempts without ads or purchases. Balanced policies required 44–49 attempts without twins, 36–44 with early twins and 42–44 with later twins. Zero-wallet reset fixtures rebuilt Power 3 in three attempts; previous nominal output recovered after two, three or six attempts when resetting from Power 3, 6 or 10. Frozen maximum-build checks found clears in all 30 milestone/loadout/launcher combinations across 150 attempts.

These measurements use deterministic automated aiming and purchase policies. They do not establish human difficulty or session length. The opening tray's 8–10 balanced-policy attempts, touch feel, device performance and perceived value of the reset still need human playtesting.

## Saves and Trials

Twin ownership, the Power count at reset, exact active upgrade nodes and Power nodes awaiting rebuild are stored per area. Existing launcher-era saves migrate their exact counts and old reset history without spending coins or granting effects. Older saves without Twin fields still start with one launcher. The [node-ownership format](GELATO_NODE_OWNERSHIP.md) was introduced with profile 4; the current writer emits **profile 5**, retaining that Gelato metadata and adding Crystal ownership. Bakery/Gelato run checkpoints remain schema **4**; Crystal's run schema is **5**. The mixed-map revision changed neither gameplay fingerprint, launcher revision nor combat rules. Compatible unfinished runs and pending results retain their normal resume/collection behavior.

The earlier trajectory revision 2 changed Gelato's physics fingerprint: runs from before that physics revision returned Home with campaign progression intact, and obsolete Gelato Trial times cleared. Those historical rules are unchanged here. Current Gelato Trials use the existing aim calculation, one fixed launcher, the fixed upgrade profile and six-HP ordinary pegs. Entering, resuming and leaving a Trial preserves campaign Twin ownership, exact node sets and rebuilt Power.

## Verification scope

The delivered [v0.7.4 APK record](ANDROID_SUGARFALL_v0.7.4.json), [legal progression baseline](AREA_PROGRESSION_BALANCE.md) and [area checklist](areas/gelato_checklist.md) separate packaged fixes, synthetic progression and remaining human/device acceptance. Current documentation is synchronized with that delivery; it does not imply phone verification.

Historical v0.7.0 [source validation](../../verification/crystal-area-20261103/validation.json) records 2,494 checks across the three-area build, including Gelato map, shop, migration, Trial and navigation regressions. Its 175 GPU checks across 40 captures include a Gelato control frame. These remain dated evidence for the preceding package.

### Historical launcher and trajectory verification

The original launcher implementation passed 2,512 assertions across 26 isolated suites and 343 graphics checks across 98 captures at 720×1280 and 450×800. Tests covered touch input, shot origins and gravity, rate/cap limits, purchase/reset rollback, red-node rebuilding, cross-area isolation, migrations and the existing Bakery systems. All nine Gelato Trial/loadout combinations had clears across 45 feasibility attempts. Player-profile IO was zero in simulation and rendering fixtures; persistence fixtures used isolated files.

The subsequent ballistic-aim correction passed 1,180 assertions across twelve isolated suites and 75 GPU checks across sixteen reviewed captures. Actual free-flight positions at 60 and 120 Hz matched independently calculated parabolas, including both nozzles and special foods. See [trajectory verification](../../verification/gelato-trajectory-20261102/).

Pacing evidence and source hashes are in [launcher/economy verification](../../verification/gelato-launcher-v1/). Regression, graphics captures and the final manifest are in [implementation verification](../../verification/gelato-launcher-implementation-20261102/). Focused save-migration evidence is in [save verification](../../verification/gelato-launcher-save-20261102/).
