# Legal area progression and balance

**Historical Flow-1 baseline.** CHG-036 adds Jam Burst, moves Second Prism to tray 8 and changes late HP/rewards under [Flow rules 2](AREA_FLOW_RULES.md). The six linked campaigns and 9,044 assertions below are preserved as earlier evidence; they do not verify current fresh-wallet progression. Current bounded probes are recorded in the Flow-2 report. AF-008 remains Ready to test.

AF-008 · 3 November 2026 · synthetic normal-wallet measurement complete; phone pacing and teaching acceptance remain open.

No HP, coin reward, price, cadence or physics values were changed by this pass. Six linked campaigns use current production code, actual earned balances and the actual purchase graph. Each campaign starts Bakery with zero money and upgrades, clears it, pays 1,000 from Bakery to enter Gelato with a fresh local wallet, then pays 1,500 from Gelato to enter Crystal with another fresh local wallet.

Two shopping policies use seeds 0, 1 and 2. **Economical** buys the cheapest eligible node, including a special node when it becomes the cheapest option. **Signature** reserves money for Dual Shot or Second Prism as soon as its actual tray/Power gates permit, then prioritizes rebuilding the Power that Dual Shot reset. Both claim only earned milestone vouchers, buy exact shuffled Gelato nodes, and freely equip owned modules within the slot limit. Neither uses developer money, ads, paid boosts, Trials, free tier grants or forced special drops. There is no normal upgrade-refund operation in production; rejected buys are checked for no charge, and Twin reset is treated as its real paid transformation rather than a refund.

Input is a deterministic synthetic policy: choose a living frontmost peg every 0.4 seconds, move the finger at 250 board pixels/second, divert toward reachable time pickups, and move to tap Crystal Prism offers while they remain live. Simulation steps are 1/60 second. The ordinary tutorial is marked already seen to avoid its intentional pauses. Random seeds are perturbed to sample outcomes; this is not a record of human aim, comprehension, menu-reading time or total session length.

The experiment overrides disk writes with in-memory transactions, while normal entry still calls the real gate/fee/profile-validation path. It checks exact debits, voucher consumption, unchanged balances after rejected buys, one payout per Collect, independent fresh-area defaults and entry ledger counts. The runner also verifies Godot’s actual `user://` directory inside a disposable workspace project before any existing save regressions execute.

| Policy | Seed | Area | Clear attempts | Active minutes to clear | Mean earned/run | Last wallet before entry | Special purchase |
|---|---:|---|---:|---:|---:|---:|---|
| economical | 0 | bakery | 73 | 19.29 | 339.02 | 1727.35 | None bought |
| economical | 0 | gelato | 47 | 12.48 | 339.70 | 1907.90 | None bought |
| economical | 0 | crystal | 73 | 16.78 | 235.83 | 1222.75 | second_prism at attempt 67 / tray 10 |
| economical | 1 | bakery | 63 | 16.44 | 298.84 | 1835.80 | None bought |
| economical | 1 | gelato | 51 | 13.71 | 356.66 | 1521.55 | None bought |
| economical | 1 | crystal | 90 | 20.97 | 264.46 | 1234.35 | second_prism at attempt 69 / tray 8 |
| economical | 2 | bakery | 66 | 17.40 | 326.79 | 1373.25 | None bought |
| economical | 2 | gelato | 51 | 13.73 | 347.26 | 1727.05 | None bought |
| economical | 2 | crystal | 86 | 19.99 | 266.90 | 1075.40 | second_prism at attempt 67 / tray 10 |
| signature | 0 | bakery | 73 | 19.29 | 339.02 | 1727.35 | None bought |
| signature | 0 | gelato | 45 | 11.77 | 322.92 | 1997.65 | twins at attempt 36 / tray 9 |
| signature | 0 | crystal | 79 | 18.26 | 265.69 | 1529.15 | second_prism at attempt 44 / tray 6 |
| signature | 1 | bakery | 63 | 16.44 | 298.84 | 1835.80 | None bought |
| signature | 1 | gelato | 41 | 10.74 | 318.18 | 1784.50 | twins at attempt 34 / tray 10 |
| signature | 1 | crystal | 85 | 19.79 | 275.97 | 890.55 | second_prism at attempt 47 / tray 6 |
| signature | 2 | bakery | 66 | 17.40 | 326.79 | 1373.25 | None bought |
| signature | 2 | gelato | 45 | 11.87 | 315.22 | 1684.35 | twins at attempt 37 / tray 8 |
| signature | 2 | crystal | 66 | 14.97 | 244.12 | 1255.65 | second_prism at attempt 41 / tray 6 |

The last-wallet column is after legal purchases and any explicitly recorded fee-funding replay; entry fees are deducted afterward. Crystal has no next-area fee. `summary.json` preserves the exact before/after fee balances and extra replay count, so these are not mistaken for free carryover.

Provisional engineering targets:

- First paid purchase within 3 attempts; Bakery 60–90 campaign attempts, Gelato 35–80 and Crystal 50–100 under these bounded policies.
- Review more than 20 attempts on wall trays 4/7/10, more than 10 on another tray, or more than 8 consecutive runs without a purchase while the campaign is still uncleared.
- Review more than 3 extra runs solely to fund the next area, or more than 12 attempts after Dual Shot to rebuild its previous Power tier.
- These envelopes preserve the established Bakery four-band baseline and identify outliers for another policy or a phone playtest. They are not promises of human session length. The actual desired session length and acceptable retry counts remain a human design decision.

Recorded review flags:

- policy: economical, seed: 1, area: bakery, tray: 4, kind: tray_attempts, observed: 23, review_above: 20.
- policy: economical, seed: 1, area: crystal, tray: 4, kind: tray_attempts, observed: 24, review_above: 20.
- policy: economical, seed: 1, area: crystal, tray: 11, kind: tray_attempts, observed: 14, review_above: 10.
- policy: economical, seed: 2, area: gelato, tray: 11, kind: tray_attempts, observed: 12, review_above: 10.
- policy: economical, seed: 2, area: crystal, tray: 12, kind: tray_attempts, observed: 14, review_above: 10.
- policy: signature, seed: 1, area: bakery, tray: 4, kind: tray_attempts, observed: 23, review_above: 20.
- policy: signature, seed: 1, area: crystal, tray: 4, kind: tray_attempts, observed: 24, review_above: 20.
- policy: signature, seed: 1, area: crystal, tray: 11, kind: tray_attempts, observed: 14, review_above: 10.

Dual Shot rebuild and progression economy:

- signature seed 0: bought on attempt 36, reset Power 6 to zero, paid to restore it by attempt 41 (5 further attempts).
- signature seed 1: bought on attempt 34, reset Power 6 to zero, paid to restore it by attempt 39 (5 further attempts).
- signature seed 2: bought on attempt 37, reset Power 6 to zero, paid to restore it by attempt 42 (5 further attempts).

Difficulty and money remain independent: damage earnings use each peg’s fixed coin budget, rather than scaling coin income with HP. Damage, break, productive-catch and clear rewards all come from production code. The per-run trace records coins, remaining HP, purchases, exact nodes, rebuild slots, build tiers, peak ball count and Prism taps; this lets later tuning separate a damage wall from a savings delay.

The initial pilot deliberately skipped optional special nodes in its economical arm. That ablation cleared Crystal seed 0 in 201 attempts versus 79 when Second Prism was reserved, with a 69-attempt stay on tray 10 in the no-Prism arm. It is retained as a warning about dependency on that mechanic, not mislabeled as the final economical policy. The final economical policy includes Second Prism as an eligible purchase. A separate aim/loadout policy and a human player should test whether avoiding that node feels unduly punitive before changing durability or making the node compulsory.

Expected arrival builds for future tests (**Feed / Power / Clock**; ranges across the six legal campaigns):

| Tray | Bakery | Gelato | Crystal |
|---|---|---|---|
| 1 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| 2 | 1–2 / 1 / 2 | 2–3 / 2 / 1–2 | 3 / 2 / 2 |
| 3 | 2 / 2 / 2–3 | 3 / 2 / 2–3 | 4 / 3 / 4 |
| 4 | 3 / 2–3 / 4 | 3 / 2 / 3 | 4 / 3 / 5 |
| 5 | 5 / 4–5 / 6–7 | 4 / 4 / 5 | 6 / 5 / 7 |
| 6 | 5 / 5 / 7 | 4–5 / 4 / 5–6 | 6–7 / 5 / 7–8 |
| 7 | 5–6 / 5 / 7 | 5–6 / 4–5 / 6 | 6–7 / 5–6 / 7–8 |
| 8 | 6 / 5 / 7 | 6 / 6 / 7–8 | 7–8 / 5–6 / 7–9 |
| 9 | 6 / 5 / 7–8 | 6 / 4–6 / 7–8 | 7–8 / 6–7 / 8–9 |
| 10 | 6–7 / 5 / 8 | 6–7 / 4–7 / 7–8 | 8–9 / 6–7 / 9 |
| 11 | 7 / 6 / 8–9 | 6–8 / 2–7 / 7–8 | 8–9 / 7 / 9–10 |
| 12 | 7–8 / 6 / 8–9 | 6–8 / 6–8 / 7–9 | 9–10 / 7–9 / 9–10 |

These ranges describe the builds actually reached through purchases. They are not hand-assigned tiers, minimum gates or a substitute for player choices. The full eight-family arrival/clear vectors and per-tray earnings ranges are retained in the summary.

Evidence:

- [Final six-campaign output](../../verification/area-fixes-20261103/pacing/final-02/campaigns.json): 9,044 legality assertions, zero failures; eighteen area playthroughs.
- [Readable metrics and exact flags](../../verification/area-fixes-20261103/pacing/summary.json), [machine-readable expected builds](../../verification/area-fixes-20261103/pacing/expected_builds.json), [provisional targets](../../verification/area-fixes-20261103/pacing/targets.json), and [source hashes](../../verification/area-fixes-20261103/pacing/final-02/source_manifest.json).
- [Current-source parity review](../../verification/area-fixes-20261103/pacing/source_parity.json): the only later source difference adds a cream backing behind damage text in `draw_damage`. Its exact three-line diff is checked. It changes no physics, rewards, timer, RNG or policy and is never called by this headless experiment.
- [Validation and isolated save probe](../../verification/area-fixes-20261103/pacing/final-02/validation.json). The focused Bakery metadata test, organic layouts, durability and broad resume suite also pass.
- [Initial ablation pilot](../../verification/area-fixes-20261103/pacing/pilot-02/campaigns.json). Its preserved project copy contains the different policy implementation.
- [Runner](../../verification/area-fixes-20261103/pacing/run_pacing.py), [production-rule harness](../tests/area_progression_pacing.gd), [Bakery tray intent](BAKERY_TRAY_LESSONS.md).

Reproduce from the workspace root with the bundled Python executable: `verification/area-fixes-20261103/pacing/run_pacing.py --name <new-directory> --seeds 0,1,2 --policies economical,signature --checks`. Godot is pinned to the bundled 4.6.3 console executable. The runner refuses to reuse an output directory.

AF-008 remains open for normal-wallet phone sessions and teaching observations. Do not mark Q07 or physical-phone acceptance Verified from this experiment. Review any flagged tray with a second bounded aim/loadout policy and real-player notes before a numerical balance change.
