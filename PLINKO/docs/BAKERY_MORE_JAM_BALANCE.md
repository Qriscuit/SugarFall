# More Jam: bounded Bakery pacing evidence

2026-11-03 · Godot 4.6.3 · Flow rules revision 2

The requested upgrade changes Jam from every fifth normal doughnut to every fourth. It increases splash opportunities, but this probe does **not** establish that the reported tray-10 difficulty problem is solved. Tray 10 can be cleared by a legal maximum build with targeted aiming; broad sweeping still times out on a few remaining pegs.

## Method and limits

The probe purchases all 62 ordinary nodes through the real graph, buys earned Jam Burst, and claims More Jam through its real free milestone API for the upgraded variant. The synthetic starting wallet is 1,000,000 coins. It uses the unchanged two-slot limit and separately tests Splitter + Impact, Ricochet + Impact, and Ricochet + Splitter. All caps are `[10,10,6,6,6,6,8,10]`, Power is 4.55, the base timer is 15 seconds, and normal bonus-time mechanics retain the three-second cap. No paid/preview entitlement is used.

There are 78 comparison runs: 54 tracking runs across trays 10–12, 18 tray-10 sweeping runs, and six instant-target reference runs. One complete baseline run is repeated and compared exactly to establish determinism. The run uses a copied source snapshot and verified disposable user directories; the fixture reads no player profile. All runs reach a result with zero setup, HP-conservation, bounded-splash, or repeatability failures.

Tracking selects the topmost live peg every 0.35 seconds, moves at no more than 600 logical pixels per second, and adds uniform ±14-pixel horizontal error. Sweeping moves across x=80–640 with a 2.8-second sinusoidal period. The instant reference uses immediate exact targeting. All policies collect time pickups automatically. Tracking therefore has ideal board-state knowledge, and automatic pickup collection is optimistic. These are modeled policies, **not human phone testing or a natural-wallet campaign**.

The seed variants are 0, 1 and 2, starting the real gameplay RNG at `1719 + tray * 104729 + seed_variant * 7919`. A separate RNG controls aiming error. Changed collisions, breaks and random effects consume gameplay RNG differently, so matching starting seeds do not enforce identical later drop sequences. Three seeds per pairing/policy are bounded examples, not a statistically powered win-rate estimate.

## Observed results

| Policy | Tray | Every fifth clears | Every fourth clears | Every fifth mean HP left | Every fourth mean HP left |
| --- | ---: | ---: | ---: | ---: | ---: |
| Bounded tracking, three pairs × three seeds | 10 | 8 / 9 | 8 / 9 | 0.03 | 0.16 |
| Bounded tracking, three pairs × three seeds | 11 | 8 / 9 | 9 / 9 | 0.57 | 0.00 |
| Bounded tracking, three pairs × three seeds | 12 | 8 / 9 | 6 / 9 | 0.16 | 1.65 |
| Broad sweeping, three pairs × three seeds | 10 | 0 / 9 | 0 / 9 | 26.64 | 20.33 |
| Instant reference, Splitter + Impact, one seed | 10 | 1 / 1 | 1 / 1 | 0.00 | 0.00 |
| Instant reference, Splitter + Impact, one seed | 11 | 1 / 1 | 1 / 1 | 0.00 | 0.00 |
| Instant reference, Splitter + Impact, one seed | 12 | 1 / 1 | 1 / 1 | 0.00 | 0.00 |

Of the 39 matched cases, both variants clear 23, only the upgrade clears three, only the baseline clears four, and neither clears nine. This is why a universally faster or easier completion claim would be unsupported.

Measured mean Jam damage rises in each policy/tray group. For tray-10 tracking it rises from 24.78 to 34.57 damage; for tray-10 sweeping, 26.21 to 33.98. These are observed per-run totals, affected by run duration and collision divergence as well as cadence. The upgrade's exact mechanical benefit is one jam-filled doughnut per four normal drops instead of per five; damage, radius and target limit remain unchanged.

Tray 10 begins with 883.2 HP. Broad-sweep remaining HP falls from a mean 3.02% to 2.30%; the upgraded worst case still leaves 42.45 HP (4.81%) and the sweep failures leave one to six pegs. The upgrade helps damage output without making broad sweeping reliably finish the board in these examples.

## Cleanup observations and next balance decision

All seven tracking timeouts across both variants leave one or two bottom-row pegs, totaling 0.30–9.40 HP, while 7–17 balls remain airborne. This points toward final-target cleanup and timer margin rather than an absolute maximum-build damage-capacity barrier.

There is also a sharp hit-count breakpoint: ordinary late-tray HP is 27.60, while six max-Power hits deal 27.30, leaving 0.30 HP. Several failed runs end at that exact remainder. If the phone test still feels unfair, targeted candidates for a separate balance pass are a small late-tray HP breakpoint adjustment or a short, bounded airborne-ball grace after the timer with no new drops. Neither candidate was implemented or evaluated here; changes affecting live checkpoints need versioned run rules and save verification.

The reported player difficulty remains open for phone verification. This probe supports shipping the requested milestone for testing; it does not justify marking general balance or free campaign attainability verified.

## Evidence

- Portable result details, all 78 observations, paired comparisons, source hashes and limitations: [BAKERY_MORE_JAM_BALANCE.json](BAKERY_MORE_JAM_BALANCE.json).
- Reproducible fixture: [bakery_quick_jam_balance_probe.gd](../tests/bakery_quick_jam_balance_probe.gd).
- Local frozen project, raw output, isolation check and execution log: `verification/more-jam-20261103/balance-01/` at the workspace root.
- Runner and report generation: `verification/more-jam-20261103/run-balance.ps1` and `analyze_balance.py`.

The six-run smoke result is superseded by the full run and is not added to the comparison count. Backend gating/save and UI/render checks are separate evidence scopes owned by the corresponding change validation.
