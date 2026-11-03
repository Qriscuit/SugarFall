# Sugarfall v0.5.4 pacing

The target is about 2–3 hours of active play to clear Bakery and build the bank required for its next-area gate. This is a design estimate, not a human playtest result or a minimum-time restriction.

## Shipping tuning

- Upgrade prices start about 25% higher and increase more strongly at later tiers. The first Feed costs 38 coins; all five no-ad campaign simulations afforded it after one attempt.
- Price = `ceil(base × 1.25 × growth^owned_tiers)`. Growth is 1.85 for Power and 1.75 for the other branches. All prices are positive whole coins.
- The next-area requirement is **400,000 banked coins**, after clearing all 12 Bakery trays. It is a visible savings goal. The next area's content is unavailable, so this build cannot charge the fee, reset upgrades, or enter that area.
- Existing upgrades, free treat vouchers, permanent purchases, and banked progress remain owned. Timers, peg HP, damage, caps, payouts, free retries, and optional monetization benefits are unchanged by the economy tuning.

| Upgrade | Tier 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Feed | 38 | 66 | 115 | 201 | 352 | 616 | 1,078 | 1,885 | 3,299 | 5,773 |
| Power | 50 | 93 | 172 | 317 | 586 | 1,084 | 2,005 | 3,709 | 6,861 | 12,692 |
| Bounce | 38 | 66 | 115 | 201 | 352 | 616 | — | — | — | — |
| Ricochet | 63 | 110 | 192 | 335 | 587 | 1,026 | — | — | — | — |
| Split | 75 | 132 | 230 | 402 | 704 | 1,231 | — | — | — | — |
| Impact | 88 | 154 | 268 | 469 | 821 | 1,437 | — | — | — | — |
| Gold | 44 | 77 | 134 | 235 | 411 | 719 | 1,257 | 2,200 | — | — |
| Time | 19 | 33 | 58 | 101 | 176 | 308 | 539 | 943 | 1,650 | 2,887 |

Buying every upgrade costs **62,495 coins** before free vouchers. No refund or retroactive charge is applied to previously owned tiers.

## Measurements

The harness executes the shipping game at 60 Hz in unattached `testing=true` instances. It uses the shipped per-level RNG seed, two reaction/movement speeds, two sensible purchase priorities, and different input timing phases. It honors the map's first-Feed visibility gate and free vouchers. It does not load, write, or reset user profiles.

Active time includes food travel and final catch settling, and excludes menu navigation, thinking, ad viewing, pauses, and offline time. Thus these are optimistic active-play estimates, not elapsed real-world session lengths.

| Upgrade curve | Clear attempts, no ads | Active minutes to clear 12 trays |
|---|---:|---:|
| Previous: ×1.0, 1.40 / 1.55 growth | 16–18 | 3.4–4.2 |
| Candidate: ×1.25, 1.50 / 1.65 | 19–22 | 4.4–4.9 |
| Candidate: ×1.40, 1.55 / 1.70 | 21–25 | 4.8–5.5 |
| Shipping: ×1.25, 1.75 / 1.85 | 24–30 | 5.2–6.6 |

**Clearing the 12 trays itself still takes about 5–7 active minutes with these strong aiming policies.** The hours-long goal comes mainly from replaying trays, improving upgrades, and saving for the next area. If the first clear itself should take hours, additional authored challenge or a separate progression design is needed; this price pass does not accomplish that.

| No-ad approach after first clear | Projected total active minutes, fresh profile to gate funds |
|---|---:|
| Continue buying until every upgrade is maxed, then save | 137–164 |
| Keep the first-clear build and immediately save | 173–184 |

The investment approach actually simulates progression to all-max upgrades (90–94 further attempts in the no-ad cases), then projects the remaining savings from 36 farming attempts per case. The savings-only approach projects from 36 farming attempts at the achieved first-clear build. It is not a multi-hour human session and should not be described as one.

A separate farming matrix checks every unlocked tray, both aim speeds, and two upgrade profiles (15 attempts per cell, 720 total). At all-max upgrades its best observed rate was about 3,423 coins/minute on tray 11, with tray 12 close at 3,412. The 36-attempt final-board samples reached 3,406–3,569 with targeted aiming. Selecting earlier trays did not reveal a much faster farm in these policies. Different human strategies can still change the outcome.

## Existing optional benefits

These single-policy comparisons use the same shipping prices and the invest-then-save approach. Optional rewards are assumed to complete successfully every attempt; the estimates exclude time spent watching ads. The test fixture applies the resulting entitlement/reward state directly and does not change production authorization rules.

| Existing benefit | Projected active minutes to clear and fund gate |
|---|---:|
| No optional benefit, targeted balanced reference | 143 |
| Baker Toolkit: +20% normal payout | 119 |
| Rewarded bonus every attempt: +50% normal payout | 96 |
| Toolkit + rewarded bonus: +70% normal payout | 84 |

The 400,000-coin goal is based on the free path; no purchase or ad is required. Real ad viewing would add elapsed time to rewarded runs. The Remove Automatic Ads product does not change coin yield.

## Evidence and rerun

Evidence is in `verification/economy-pacing-v1/` at the workspace root: `summary.json`, the per-attempt `results-*.json`, `farm-matrix.json`, `investment-matrix.json`, and logs. `simulate.gd` contains explicit bounds (1,600 campaign attempts; 600 investment attempts; 70 seconds per attempt); all final cases completed within those bounds. `economy-baseline.json` preserves the previous exact bytes for migration verification.

Run the workspace Godot 4.6.3 executable with `--headless --path PLINKO --log-file <writable-log> --script <absolute-path-to-verification/economy-pacing-v1/simulate.gd> -- final`. Then run `-- farm` and `-- invest`, and run `summarize.py` to rebuild this summary. Candidate names are `baseline`, `medium`, `steep`, and `late`; `final` reads production prices directly.

Before retuning, play a fresh profile through early purchases and several later trays. Check how repetitive the post-clear savings phase feels, how often upgrades remain meaningful, and whether the next area's eventual content justifies the coin goal. Do not infer a one-calendar-day retention guarantee from an active-play target.
