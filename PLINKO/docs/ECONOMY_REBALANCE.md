# Coin budgets, Impact and Gelato entry

Implemented tuning pass, 2 November 2026. Covers SF-011, SF-012 and SF-015, plus the requested hit and money feedback. These are tested starting values for phone playtesting, not a claim that the final release economy is calibrated.

3 November follow-up: [legal progression across all three areas](AREA_PROGRESSION_BALANCE.md) now measures the current shuffled Gelato graph and Crystal Second Prism with earned wallets, paid entry and paid Dual Shot rebuilding. All six linked campaigns clear under two bounded shopping policies; no coin, price, HP or cadence values changed. The historical two-area experiments below remain evidence for this original implementation, not the latest three-area pacing acceptance. Human sessions and flagged trays still need review.

## Design decisions

Keep the four difficulty walls: ordinary pegs have 6 / 12 / 18 / 24 HP across Bronze / Silver / Gold / Diamond; armor retains its authored HP multiplier. Control coin rewards independently of these values.

| Rule | Previous | Implemented |
| --- | --- | --- |
| Ordinary, clock and prism damage reward | One coin per HP removed | Six total damage coins per peg |
| Armored damage reward | One coin per HP removed | Nine total damage coins per peg |
| Break reward | 2 coins on trays 1–4, 3 on 5–8, 4 on 9–12 | Unchanged; prism still triples this part |
| Impact first hit | 9,999 damage | Four times current Power; six times against armor |
| Impact later hits | Ordinary Power | Ordinary Power |
| Gelato first entry | 40,000 Bakery coins | 1,000 Bakery coins after clearing Bakery |

An ordinary Bronze peg still pays eight coins in total. A Diamond ordinary peg now pays ten instead of 28; a Diamond armored peg pays 13 instead of 52. Clock pegs keep their time reward, and prism pegs keep their special break bonus. Cup income and tray-clear rewards are unchanged in this pass. They remain part of total income and must be considered in future pacing work.

Damage coins pay out along the way: calculate the cumulative fraction of HP removed, multiply by the peg's damage-coin budget, round down to whole earned coins, and pay only the difference from the previous cumulative amount. Breaking the peg releases any remaining damage coins plus the break reward. A hit cannot earn overkill coins. Dividing the same damage into many small hits cannot increase the payout. Because the calculation uses saved current/max HP, interruption and resume need no new per-peg paid counter.

Impact remains an occasional equipped special. Its larger collision radius, drop odds, upgrade ownership and equipment behavior are unchanged. At ordinary maximum Power 4.55, its first hit is 18.2 damage against a normal peg or 27.3 against armor; a fresh Diamond peg therefore survives either hit. Weak or damaged pegs can still break immediately. Twin Launchers resets Power, so it now reduces Impact damage too. Owned Impact tiers are retained. The existing Twin price, later gate and Power rebuild rules remain.

Gelato entry still requires completing Bakery and collecting the result. Payment is one-time and transactional; excess coins and all upgrades stay in Bakery, Gelato starts with its own empty wallet/build, and revisiting costs nothing. Existing owners are not charged again. Historical entry ledger amounts remain valid.

## Feedback

- An unused Impact ball has a warm charge ring, sparkle and short trail. The charged effect disappears after its first damaging contact, which produces a short radial burst.
- Peg hits display actual HP removed, capped by remaining HP, rather than the nominal attack. Labels use whole numbers or one decimal, merge rapid hits at the same peg and expire. Damage labels use a minus sign; earned break coins keep their plus sign.
- The run coin number and Home wallet briefly grow, twist and glow gold when their displayed whole-coin amount increases, then return to their original size and angle. Actual totals update immediately. Rapid gains share a bounded animation; spending, area switches, initial load and resume do not masquerade as income.
- Reduced Motion removes the counter's growth/twist and the ball trail. Damage labels remain stationary. A subdued gold response preserves the feedback.
- All effects are presentation-only, use no gameplay RNG and have fixed live-item limits. Wallet values, collision rules, trajectories and save contents never depend on the animation.

## Measurement and selection

The comparison used the boards, graph prerequisites and prices from the v0.6.11 tuning pass, bounded automated aiming, no ads or paid benefits, three deterministic seeds, and isolated saves. It compares the original reward/Impact rules with that candidate. These are historical simulated active gameplay times, excluding player decision time, menus and real device input. Gelato's later [source-only antler map](GELATO_U_MAP.md) changes the route graph; the Gelato figures below do not validate its purchase cadence. Phone pacing remains open.

| Campaign / policy | Attempts to clear | Simulated active minutes |
| --- | --- | --- |
| Bakery, previous rewards and Impact | 47–53 | 12.2–14.0 |
| Bakery, independent rewards and Power-scaled Impact | 67–74 | 17.6–19.7 |
| Gelato, candidate without Twin purchase | 50–59 | 12.9–15.5 |
| Gelato, candidate saving for Twin purchase | 55–58 | 14.3–15.1 |

Candidate Bakery completion balances were 1,157–2,250 coins. A 1,000-coin entry fee was affordable at completion in all three runs, leaving 157–1,250 coins in Bakery without replaying a finished tray to fund entry. The previous 40,000 fee would not meet that transition goal. Every candidate could afford a first upgrade after one attempt. Keep upgrade prices unchanged for this scoped pass; a general price cut is not justified by these measurements.

Twin investment is not guaranteed to shorten the first playthrough: buying it costs 3,000 and resets Power. The measured candidate recovered and completed in all three seeds. Its value and the player's willingness to rebuild still need phone playtesting. The automated opening took several attempts to first clear before and after the change; onboarding and broader progression targets remain separate work.

Reproducible scripts, per-attempt traces, baseline inputs and production-parity checks are retained under `verification/economy-rebalance-20261102/measurements` inside the project. Integration and renderer evidence are retained under the parent workspace's `verification/economy-rebalance-20261102` and `verification/evgpu` folders. These measurements do not establish human session length, retention or monetization outcomes.

## Save compatibility and acceptance

Campaign wallets, upgrade counts, Twin ownership, area ownership and permanent purchases are preserved. Completed pending rewards retain their already-earned amount and exactly-once collection path. A checkpoint from the old combat/reward rules cannot resume under new rules; it returns safely to Home through the existing fingerprint rejection path. The prior shop-only hash exception remains pinned to its historical pair and cannot admit this gameplay change.

Both areas now version their combat Trial records. Old practice times clear because their Impact rules were different; current-revision times survive save/restart. Launcher revision remains separate. No player profile is used for tests.

Acceptance covers equal budgets across HP bands and damage segmentation; clock/prism/armor behavior; first and later Impact contacts; Power reset/rebuild; no duplicate coins after resume; entry boundaries/save failure/revisit; old profile preservation; and actual rendered feedback at 720×1280 and 450×800. Phone feel, purchase cadence and player savings at completion remain the next balance check.

Completed verification: **23 regression suites / 2,442 assertions**, **17 feedback checks**, and **129 GPU checks across 24 captures**, with no failures in the final runs. All 15 comparison campaigns completed; three additional full production campaigns matched their independent candidate traces exactly (182 attempts total). The final renderer and regression copy match all 36 runtime script/JSON files. The consolidated record is [validation.json](../../verification/economy-rebalance-20261102/validation.json).

The final review also checked idle redraw behavior and Trial wallet restoration: a paused or finished run's frozen coin pulse cannot keep idle screens repainting, and returning from a Trial does not celebrate preserved money as new income. Those cases are included in the 80 coin-feedback assertions.

Delivery now includes the updated launch tracker and Android v0.6.11 preview, replacing the existing Drive APK in place. See ANDROID_SUGARFALL_v0.6.11.json and ../BUILD_LINKS.txt for the verified artifact and download. Physical-phone balancing remains open.
