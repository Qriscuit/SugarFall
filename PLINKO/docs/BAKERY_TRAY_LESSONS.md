# Bakery tray lessons and expected builds

AF-004 · 3 November 2026 · design implemented and checked; human learning remains to be playtested.

Each tray now has a distinct `trait_brief` in the production board data. The intended skill is grounded in the existing authored positions and actual `build_wave` role assignment. These briefs are author-facing metadata, not new on-screen tutorial popups. The board geometry, counts, strength bands, rewards, timers and prices remain unchanged.

The compact start grows into a broad irregular scatter; the old family names do not imply invisible rails, compartments or obstacles. The four material bands remain Bronze 6 HP, Silver 12 HP, Gold 18 HP and Diamond 24 HP. Late armored pegs have 48 HP.

Arrival builds below are observed ranges from six legal synthetic campaigns (three seeds under two shopping policies), expressed as **Feed / Power / Clock tiers**. They are useful starting points for phone testing, not required builds or player guarantees. Full eight-family vectors, earnings and attempts are in the pacing summary.

| Tray | Existing layout and intended lesson | Expected arrival: Feed / Power / Clock | Observed attempts |
|---|---|---|---|
| 1 · First Pour | Move the gravity dropper across eight separated targets; there is no exact-flight preview. | 0 / 0 / 0 | 4–6 |
| 2 · Clockwork Rows | The two clocks sit at (233,628) and (313,641), below the opening targets. Move away from an already cleared column. | 1–2 / 1 / 2 | 1–4 |
| 3 · Open Assembly | The field widens to x=110–600. Its first prism is at index 7; switch columns to reach remaining side targets. | 2 / 2 / 2–3 | 3–5 |
| 4 · Outer Rails | The first silver wall doubles ordinary HP to 12; targets now span x=91–620 and y=349–792. Alternate sides and build repeat-hit capacity. | 3 / 2–3 / 4 | 16–23 |
| 5 · Twin Silos | The 20-target silver spread has a sparse left edge and a larger middle/right group; balance pressure instead of camping one column. | 5 / 4–5 / 6–7 | 2–9 |
| 6 · Wide Return | Twenty-two silver targets culminate in clocks at (94,777) and (258,781). Return left once upper routes open. | 5 / 5 / 7 | 1–2 |
| 7 · Packed Crates | The first gold wall raises ordinary HP to 18 and packs 24 targets across the board. Compare spread from Splitter with focused damage. | 5–6 / 5 / 7 | 2–7 |
| 8 · Split Production | Twenty-six gold targets end in a low central clock pair at (370,801) and (254,803). Open a route before late cleanup. | 6 / 5 / 7 | 1–2 |
| 9 · Fragment Yard | Twenty-eight gold targets leave scattered survivors after the opening. Use their newly cleared columns rather than a fixed sweep. | 6 / 5 / 7–8 | 3–9 |
| 10 · Heavy Gate | The diamond wall raises ordinary HP to 24; the first two targets are 48-HP armor at (364,351) and (457,360). Equip Impact before focused hits. | 6–7 / 5 / 8 | 8–15 |
| 11 · Mixed Machinery | Three front armored targets at (363,353), (282,361), (434,362) protect a 32-target spread. Mix focused hits with cleanup on both sides. | 7 / 6 / 8–9 | 2–4 |
| 12 · Foundry Finale | Four front armored targets and 34 total targets combine the earlier lessons; the clocks finish low-left at (135,796), (212,801). | 7–8 / 6 / 8–9 | 4–7 |

Trays 4, 7 and 10 are the authored durability walls. The provisional engineering review thresholds are over 20 attempts at a wall or over 10 at an intervening tray; they identify playtest priorities rather than automatically justifying easier pegs. See [the complete progression report](AREA_PROGRESSION_BALANCE.md) for current flags, economy measurements and targets.

The shared module recommendations remain Ricochet on trays 4–6, Splitter on 7–9 and Impact on 10–12. These are suggestions, not required equipment. Two slots unlock at tray 4; milestone vouchers on clearing trays 2, 5 and 8 still obey the actual upgrade graph. Nothing in this design grants a module for free before a real voucher is earned.

Evidence and compatibility:

- [Actual coordinates and role contact sheet](../../verification/area-fixes-20261103/pacing/bakery_layout_reference.png). This is an engineering drawing, not replacement game art.
- [Semantic diff and exact old/new content hashes](../../verification/area-fixes-20261103/pacing/bakery_metadata_change.json): only the eleven tray 2–12 briefs changed.
- [Focused metadata regression](../../verification/area-fixes-20261103/pacing/final-02/bakery_lesson_metadata_qa.log): 34 checks, including old active states restored with identical geometry, damage, balls, RNG and timer on trays 1, 4, 7, 10 and 12.
- [Isolated validation](../../verification/area-fixes-20261103/pacing/final-02/validation.json) also repeats organic-board, durability and full resume checks.
- [Per-tray legal traces and build ranges](../../verification/area-fixes-20261103/pacing/summary.json).

The metadata-only snapshot exception pins one previous and one current Bakery hash. Unrelated older durability builds, future data changes and other areas receive no new compatibility exception. Human verification still needs a player to describe the lesson, pick an upgrade or loadout, and demonstrate it in play.
