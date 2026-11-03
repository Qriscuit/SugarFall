# Tray 8 flow rules

3 November 2026 · Run rules revision 2.

New campaign runs keep the existing Bronze/Silver/Gold/Diamond boundaries at trays 1/4/7/10. From tray 8, [`flow_rules.gd`](../scripts/flow_rules.gd) adds a 1.15 multiplier to normal HP and a separate 1.25 multiplier to damage coin budgets, final break rewards and clear rewards. Armor applies its existing multiplier after normal HP. Cup rewards, Power, ordinary upgrade prices and Trials are unchanged. No paid/ability ownership is consulted by these rules.

Coin amounts round once to the nearest whole coin, with positive halves rounded upward. This means the effective income gain is sometimes larger than 25% on small budgets: Bakery/Gelato ordinary damage budgets become 8 from 6, armored budgets 11 from 9; Crystal budgets become 10 from 8 and 15 from 12. A three-coin break becomes 4, while its nine-coin prism version becomes 11. Scale the completed prism/combo reward once; do not scale a component then multiply it again.

Normal HP is 18 at tray 7, 20.7 on trays 8–9 and 27.6 on trays 10–12. Combined with the authored peg-count increase, total board HP rises approximately 24.6–24.8% between trays 7 and 8. This is a stronger part of the Gold stretch, not a fifth material band.

| Area | Tray | Board HP, old → new | Damage + breaks + clear, old → new |
|---|---:|---:|---:|
| Bakery | 8 | 468 → 538.2 | 326 → 426 |
| Bakery | 12 | 912 → 1,048.8 | 468 → 599 |
| Gelato | 8 | 468 → 538.2 | 326 → 426 |
| Gelato | 12 | 960 → 1,104 | 488 → 625 |
| Crystal | 8 | 460.8 → 529.92 | 369 → 466 |
| Crystal | 12 | 849.6 → 977.04 | 529 → 661 |

These are complete-board arithmetic budgets excluding cup catches, missed shots and commerce bonuses. They are not predicted player earnings per minute or human pacing results. Actual earning speed still depends on upgrades, aim and how much of the board is cleared.

## Compatibility contract

The ten existing gameplay JSON files remain unchanged. The run owns a pinned revision: new campaign runs use 2; active saves lacking the explicit revision field use 1. Validate the field as an exact supported integer and set it before validating/building the restored board. Revision 1 keeps its original HP and coin budget until the run finishes. Revisions are not inferred from currently owned upgrades or the new-run default.

The root profile stores `active_run_rules` alongside the existing run snapshot. Old fingerprints and snapshot schemas do not change merely to express these numbers. Home previews explicitly request the current revision; they must not inherit an older active run's pinned revision. Trials always retain their authored rules, including resumed Trials.

Switching a partly damaged peg from the old six-coin budget to eight during restoration could pay extra coins. The version pin prevents that: existing cumulative-damage accounting divides the run's fixed budget over the HP already saved, and repeated hits or overkill cannot exceed it.

## Verification and limits

[`flow_rules_qa.gd`](../tests/flow_rules_qa.gd) passed 131 checks covering all twelve tray boundaries, exact legacy and Trial behavior, finite/revision guards, rounding, fractional hit conservation, dead-peg replay, and checkpoint splits under the pinned budget. `verification/flow-rules-20261103/numbers.json` records the table calculation and unchanged data hashes.

[`flow_rules_save_qa.gd`](../tests/flow_rules_save_qa.gd) passed 128 checks against actual files in an isolated profile. Across all three areas at trays 8 and 12, current and missing-field legacy saves restore their pinned rules, partial HP, already-paid coins and unchanged fingerprint. Subsequent hits pay the same remainder as an uninterrupted run; a later new run adopts revision 2. Invalid revisions reject only the active checkpoint while keeping the wallet. A saved Gelato Trial retains authored HP. No player profile was read or written.

The updated live combat and durability suites passed 364 and 266 checks respectively. They now distinguish the authored material bands from the current run overlay; Twin rebuild testing activates the earned ability before starting the run, consistent with the production ability pin.

[`flow_rules_playability_probe.gd`](../tests/flow_rules_playability_probe.gd) exercises live simulation with every ordinary upgrade purchased through its actual graph, Splitter and Impact equipped, a fixed topmost-surviving-target aim policy, and immediate collection of time/Prism pickups. It uses a synthetic starting wallet and no early-access entitlement. Every run terminated normally; upgrade purchases succeeded and no profile was loaded.

| Build and rules | Tray 8 | Tray 9 | Tray 10 | Tray 11 | Tray 12 |
|---|---:|---:|---:|---:|---:|
| Bakery, current, no Jam Burst | Clear | Clear | Clear | Clear | Clear |
| Gelato, current, no Dual Shot | Clear | Clear | Clear | Clear | Clear |
| Crystal, legacy, no Second Prism | Clear | Clear | 24/29 | 26/31 | 27/33 |
| Crystal, current, no Second Prism | 23/24 | Clear | 24/29 | 28/31 | 26/33 |
| Crystal, current, gameplay-bought Second Prism | Clear | Clear | Clear | Clear | 32/33 |

Fractions are pegs destroyed before time expired. The last row buys Second Prism through the real 900-coin gameplay route and records `earned` ownership with no paid or preview entitlement. These results show the intended tray-8 difficulty increase in Crystal and the benefit of its free earned ability. The same policy already missed late Crystal boards under the older rules. Crystal tray 12 still needs a pacing check; these probes do not prove that every timed board is finishable without the signature ability, or that human progression is balanced.

Max ordinary Power remains 4.55 in Bakery/Gelato and 7.4 in Crystal. A 27.6-HP normal peg needs 7 ordinary hits in Bakery/Gelato or 4 in Crystal, before existing special balls and ricochets. No target has an ability-only damage gate. Phone playtests with normal wallets, ordinary aiming and realistic pickup timing remain open. The synthetic wallet does not verify upgrade affordability over a campaign, and automatic pickup collection is not representative of player accuracy. Detailed logs and source hashes are in `verification/flow-rules-20261103/integrated-01/`.
