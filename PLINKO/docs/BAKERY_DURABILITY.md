# Bakery durability progression

Revised 2 November 2026 to use four material bands at the user's request. This replaces the gradual per-tray curve from the first balance pass. Those historical base HP values jump at trays 4, 7 and 10. Current Flow-2 runs also scale HP from tray 8, within the existing material bands.

3 November 2026 follow-up: [twelve tray-specific lessons](BAKERY_TRAY_LESSONS.md) now describe the existing authored geometry and observed arrival builds. Only tray 2–12 brief text changed; geometry and balance are unchanged. [The historical Flow-1 legal progression report](AREA_PROGRESSION_BALANCE.md) records that earlier wallet/shop pacing: Bakery clears in 63–73 attempts across three sampled seeds. Human pacing remains open.

| Trays | Material | Ordinary, clock and prism HP | Armored HP | Ordinary hits at maximum Power |
| --- | --- | ---: | ---: | ---: |
| 1–3 | Bronze | 6 | — | 2 |
| 4–6 | Silver | 12 | — | 3 |
| 7 | Gold | 18 | — | 4 |
| 8–9 | Gold | 20.7 | — | 5 |
| 10–12 | Diamond | 27.6 | 55.2 | 7 |

Hits use maximum Bakery Power (4.55 damage) without special-ball effects. Bakery layouts, peg counts, armor counts, upgrade prices, Power growth and timers are unchanged. These are three authored difficulty jumps between four strength bands; retries at each jump depend on aiming, upgrades and loadout. Gelato now has its own [launcher and economy revision](GELATO_LAUNCHER.md).

The same material tint appears in Home previews, the entry transition and gameplay. Material names appear on Home and in the gameplay HUD; Home also shows normal-peg HP. Existing special-peg decorations and transparent damage chunks remain visible. Damage states use each peg's remaining HP fraction. Bakery Help explains the four materials and the three jump points. The live Power card and older Power preview use the selected tray's actual normal-peg HP.

Current source adds [Jam Burst](AREA_SIGNATURE_ABILITIES.md): tray 8, Power 4 and 1,200 coins, or the separately tracked early-access route. [Flow rules 2](AREA_FLOW_RULES.md) scales late coin budgets independently of HP and keeps legacy active-run values pinned. The new revision does not change the gameplay JSON/fingerprint. Current legal progression and phone pacing need revalidation.

## Trials and compatibility

Bakery Trials 4, 8 and 12 retain six HP for normal pegs and their existing armor multipliers through `trial_base_hp`. Campaign construction and checkpoint validation resolve that override only for Trials. Trials keep their original peg colors, fixed equipment, timers and records.

The revised Bakery data produces a new interrupted-run fingerprint. Unfinished runs from the old flat curve or first gradual curve return safely to Home while preserving campaign progress. Completed pending results retain the existing independent payout path. The subsequent Gelato revision does not change Bakery's fingerprint. Do not extend the historical price-only checkpoint exception to a durability or launcher rebalance.

The 3 November tray-brief revision adds a separate, exact metadata-only old/new hash pair. It preserves interrupted runs from the immediately preceding Bakery content, since only explanatory strings changed. A 34-check regression verifies identical decoded and restored active state; the broad 122-check resume suite also passes. This does not accept the old flat/gradual durability builds or any future content hash.

## Historical measurements and follow-up

All eight sampled campaigns completed with the selected bands in 64–87 attempts: balanced purchasing 64–66, Power-biased 66–87, cheapest-first 70–72, and slower aiming with balanced purchasing 66–69. Earlier paired balanced runs took 33–35 attempts with flat six-HP pegs and 55–58 with the gradual curve. These are automated engineering measurements, not human session-length or enjoyment targets.

The selected bands also passed a 360-run frozen maximum-upgrade matrix. Every tray could be cleared by every equipment pair with targeted aim. At least one pair cleared each tray with sweep aiming. Diamond tray 12 could be cleared by all three equipment pairs under targeted, slower and sweep aiming in the endpoint probe. This establishes sampled attainability, not a guarantee that every attempt succeeds. Diamond endpoints of 36 and 32 HP were rejected after campaign policies stalled despite maximum upgrades.

Final production-data verification repeated both balanced campaigns and 90 Trial attempts. Campaign results matched the selected candidate, Trial win counts matched baseline, and no player-profile IO was attempted.

Implementation verification passed 2,120 assertions across 22 isolated Windows suites, including 266 durability checks and 216 material-rendering checks. The final Home-label refinement passed another three relevant suites with 203 assertions. Actual-renderer review passed 164 checks across 51 captures at 720×1280 and 450×800, including all four materials, damage states, Home-to-play pixel continuity and Reduced Motion. The verification manifest records final source hashes.

Damage rewards now use fixed coin budgets independent of HP. Impact scales with Power, and Gelato entry costs 1,000 coins. See `ECONOMY_REBALANCE.md` for the implemented SF-011/SF-012/SF-015 pass and measurements. Real-phone readability, human pacing and final economy tuning remain open.

The final pacing matrices, rejected candidates, per-tray traces and source verification are retained in [the four-band measurements](../../verification/bakery-walls-v2/). The [earlier gradual-curve measurements](../../verification/bakery-durability-v1/) remain historical evidence. Isolated regression results and actual-renderer captures for the four-band revision are retained in [implementation verification](../../verification/bakery-walls-implementation-20261102/).

## CHG-040 follow-up — Bakery tray 10 and More Jam

On 3 November 2026, the user reported being unable to clear Bakery tray 10 despite having all upgrades. The exact installed build, phone/OS, node ownership/loadout, attempts, aim pattern, remaining pegs and time are unconfirmed. This is an open difficulty finding, not a completed phone or campaign acceptance pass. More Jam adds a free late-campaign cadence upgrade without changing HP, rewards, board geometry or base upgrade values. 78 fixed-build comparisons plus one deterministic replay have no invariant/profile/termination failures. Tray-10 tracking clears 8/9 at both cadences; broad sweeps clear 0/9 at both. Tracking trays 11/12 change 8/9 to 9/9 and 8/9 to 6/9. Jam damage rises, but this does not establish resolution of the phone difficulty or natural-wallet/human progression. Earlier Flow-1/campaign measurements remain historical and do not verify current human progression. See [More Jam](BAKERY_MORE_JAM.md) and [bounded comparison](BAKERY_MORE_JAM_BALANCE.md).
