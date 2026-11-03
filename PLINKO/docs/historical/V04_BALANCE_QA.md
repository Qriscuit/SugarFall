# v0.4 short-run balance investigation

Automated headless evidence, 23 October 2026. These controllers use exact game state, 0.4-second target decisions and a 250px/s aim speed, with pulse and aimed queued modules. They are not human playtests. Menu/shop time is excluded. All progression collects base rewards only.

## Functional candidate A checks

11 checks pass: ten-second start, six normal hits to destroy a fresh ordinary peg, nonlethal damage earnings, free retry retaining credits, two clock upgrades adding one second, three-second extra-time cap, and paused snapshot/RNG restoration with the new timer model. The one-seed oracle trial probe is not proof of impossibility.

## Candidate definitions

A:12→34pegs, all ordinary HP6, core increment0.75, clock increment0.5s, core40 and clock40 base costs, cost growth1.4. B is fixture-only: first counts8/12/16 then18→34, core increment0.5, core cost growth1.55, clock base15. All other settings unchanged. B uses the existing broadstagger geometry, so its first8pegs occupy a single row.

## Real-purchase no-bonus progression

Two policies,10paired seeds each: cheapest useful purchases; damage-first targets core7, then feeder5, clock10 and remaining core/feed upgrades. Neither is a human strategy or mathematical optimum. Every tested chapter completes within the300attempt safety bound.

| Candidate | Policy | Mean attempts | Mean failures | Mean gameplay seconds | First purchase |
|---|---|---:|---:|---:|---|
|A|cheapest_useful|18.5|6.5|174.6|Attempt1 in all10|
|A|damage_first|20.9|8.9|184.9|Attempt1 in all10|

### Candidate A per-board attempts and failure earnings

| Policy | Board | Mean attempts | Max attempts | Mean credits per failure | Mean purchases per attempt |
|---|---:|---:|---:|---:|---:|
|cheapest_useful|1|7.2|8|97.1|2.0|
|cheapest_useful|2|1.0|1|No failure|2.6|
|cheapest_useful|3|1.1|2|163|1.6|
|cheapest_useful|4|1.0|1|No failure|1.4|
|cheapest_useful|5|1.0|1|No failure|2.0|
|cheapest_useful|6|1.0|1|No failure|1.3|
|cheapest_useful|7|1.2|2|284|1.3|
|cheapest_useful|8|1.0|1|No failure|1.4|
|cheapest_useful|9|1.0|1|No failure|1.2|
|cheapest_useful|10|1.0|1|No failure|1.1|
|cheapest_useful|11|1.0|1|No failure|1.0|
|cheapest_useful|12|1.0|1|No failure|1.0|
|damage_first|1|8.7|12|93.3|0.9|
|damage_first|2|2.0|6|116.6|1.5|
|damage_first|3|1.2|3|122|2.5|
|damage_first|4|1.0|1|No failure|2.4|
|damage_first|5|1.0|1|No failure|1.3|
|damage_first|6|1.0|1|No failure|1.2|
|damage_first|7|1.0|1|No failure|0.8|
|damage_first|8|1.0|1|No failure|0.7|
|damage_first|9|1.0|1|No failure|0.8|
|damage_first|10|1.0|1|No failure|0.3|
|damage_first|11|1.0|1|No failure|0.7|
|damage_first|12|1.0|1|No failure|1.2|
|B|cheapest_useful|20.6|8.6|231.5|Attempt1 in all10|
|B|damage_first|28.0|16.0|289.8|Attempt1 in all10|

### Candidate B per-board attempts and failure earnings

| Policy | Board | Mean attempts | Max attempts | Mean credits per failure | Mean purchases per attempt |
|---|---:|---:|---:|---:|---:|
|cheapest_useful|1|7.8|11|66.2|1.8|
|cheapest_useful|2|1.7|3|126.7|2.2|
|cheapest_useful|3|1.3|2|168.7|1.8|
|cheapest_useful|4|1.4|3|191|1.5|
|cheapest_useful|5|1.0|1|No failure|2.0|
|cheapest_useful|6|1.0|1|No failure|1.3|
|cheapest_useful|7|1.3|3|314.3|1.1|
|cheapest_useful|8|1.0|1|No failure|1.4|
|cheapest_useful|9|1.1|2|389|1.2|
|cheapest_useful|10|1.0|1|No failure|0.8|
|cheapest_useful|11|1.0|1|No failure|0.9|
|cheapest_useful|12|1.0|1|No failure|0.9|
|damage_first|1|9.7|16|58.8|0.5|
|damage_first|2|3.6|9|101.9|0.3|
|damage_first|3|3.5|7|129.6|1.3|
|damage_first|4|3.1|7|150.3|2.6|
|damage_first|5|1.1|2|229|1.5|
|damage_first|6|1.0|1|No failure|1.2|
|damage_first|7|1.0|1|No failure|0.9|
|damage_first|8|1.0|1|No failure|0.0|
|damage_first|9|1.0|1|No failure|1.0|
|damage_first|10|1.0|1|No failure|0.0|
|damage_first|11|1.0|1|No failure|0.1|
|damage_first|12|1.0|1|No failure|0.9|

## Interpretation

Frequent useful purchases are achieved, but first-board completion remains heavily frontloaded: A7.2/8.7 attempts, B7.8/9.7 attempts for cheapest/damage-first. B is not an improvement to that first wall. A plausible geometry explanation is that eight pegs in one row provide fewer repeat contacts and damage earnings than12pegs over two rows; this is an inference, not a controlled geometry experiment. Later boards often clear first try after earned upgrades. Short total duration is not itself a defect given the requested ten-second rounds.

## Clock and trial probes

Matched available budgets retain unspent credit, so actual expenditure is unequal. Fresh budget40: core spends40, feeder30, proposed cheaper clock36 for two levels. On20seeds, none clears; mean destroyed/HP removed: no upgrade6.2/44.8, core7.6/53.2, feeder7.45/52.35, clock6.75/48.1. Near-clear fixture[2,2,1,0,0,0,0,2], budget120: core spends78 and clears10/20; feeder58 clears5/20; proposed clock70 clears4/20; unchanged fixture0/20. This demonstrates deadline value but not balanced human choices.

Bounded trial candidate[4,4,2,1,1,1,0,2] clears boards4/8/12 in9/10,3/10,5/10 seeds. Stronger[6,6,2,1,1,1,0,4] clears10/10,10/10,9/10. These used candidateA core increment0.75 and original trial geometry.

## Evidence

tests/v04_qa.gd and v04_qa.log; v04_candidate_a_results.json; v04_candidate_b_results.json; v04_trial_clock_results.json. Tests and fixture overrides only; no implementation/data files edited by this QA worker. Snapshot compatibility requires revalidation after final authored data/geometry decisions.

## Selected candidate C, 13:21 UTC

C retains B's core increment0.5, core growth1.55 and clock base15, but puts the first three boards in compact four-column layouts with8/12/16pegs. It is now authored on disk. Baseline ordinary pegs remain6HP and rounds remain10seconds; earned one-hit upgrades are allowed.

Bounded aim, ten seeds per policy:
- Cheapest useful:17.8attempts,196.6seconds per chapter; board1mean5.1attempts(max8).
- Damage-first:22.6attempts,233.3seconds; board1mean3.4attempts(max6).
- Every chapter completes; first purchase after attempt1 in all runs.
- Fresh first board:0/20clears,4.5of8pegs destroyed,60.5credits earned on average.

Sweep aim sensitivity check also completes every chapter, but is slower:28/37.9attempts for cheapest/damage-first and first-board6.4/4.3attempts. Thus the improvement is not confined to the topmost-target controller. Sweep uses a compact220–505range on the first three boards and75–645later, fixed pulse aim, with the same shopping policies. This remains a narrow automated strategy comparison, not a model of player ability.

Worst single-board count is8attempts in both bounded-policy samples: cheapest on board1, damage-first on board4. Cheapest is deliberately nonoptimal: one seed buys three clock levels first, then feed/bounce, then gold-bin/core, then clock/feed before its first clear. Damage-first can stall on board4 while saving for core7 before buying feed/clock. All boards6–12clear on the first attempt in these runs, but purchases continue between boards; these observations alone do not prove that later upgrades are unnecessary.

Final-config trial candidates: fixed[6,6,2,1,1,1,0,4] clears10/10seeds at each board4/8/12, mean8.1/11.2/10.4seconds. Stronger[8,8,2,1,1,1,0,4] also clears10/10each, mean8.3/9.6/10.2. The weaker tested candidate is sufficient for automated playability; neither establishes optimal human challenge.

13 dedicated v0.4 assertions pass, including the post-pickup100second scheduling sentinel in snapshot validation and rejection of the actual archived v0.3 content fingerprint while preserving banked progress. This is separate from older test suites whose authored counts/timing expectations require explicit version updates, not silent weakening.

Source reviewed at13:21:
- main.gd: d252e5a95b68c200deaf1af2a979ad96e23e3ff05a5b0130eea42645f99e6dbe
- run_snapshot.gd: e3f5fb6ef1a7ce453b7058f81344325f119e8692d09fca2e8b8a8bb8e6088e0c
- board_design.json: a89779e2b1dfb509b1696b4f412ca0b3d7035a302885c2d4b5a7af5068198599
- economy.json: f6fced78912829fca18508b4cd2ec39599971a66f655098c125380d44685e391

Added evidence: tests/v04_candidate_c_results.json, v04_candidate_c_sweep_results.json, v04_final_trial_results.json. Final UI or physics changes require a subsequent regression pass. No physical Android playtest, retention or monetization inference is made.

## Final purchase-freeze ablation and trial saves, 13:24 UTC

A more useful-threshold-oriented policy purchases core levels1/2/4, then prioritizes feed/clock, avoiding core5–9. Ten paired seeds with normal continued purchases complete all chapters in mean16.6attempts/177.7seconds. Freezing cash purchases after clearing board5 also completes10/10chapters, mean17.3attempts/194.7seconds. The frozen inherited build is feeder5–6/core4/clock7–8; free milestone module unlocks remain allowed. Later purchases therefore improve this bot's pace modestly but are not necessary for completion once this inherited power is reached. This is distinct from fresh, zero-upgrade later boards, which fail. No new balance change is warranted solely to increase bot duration.

Final fixed trial levels[6,6,2,1,1,1,0,4] now pass interrupted-run snapshot restoration on all three trial boards. Dedicated v0.4 suite is16/16passing; source hashes above remain unchanged. Added evidence: tests/v04_freeze_ablation_results.json. Final source/UI changes still require regression checks, and no physical Android or human pacing validation is claimed.
