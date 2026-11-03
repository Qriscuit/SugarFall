# Spiral progression pass — unreleased, 24 October 2026

The map topology and geometry below are superseded by [the clean upgrade map pass](CLEAN_UPGRADE_MAP.md). The damage, peg-layout and entry-fee changes remain current.

This pass addresses the advantage of repeatedly buying Power, single-stat trails that leave other choices far away, visibly geometric peg placement, and the long savings tail before Gelato.

## Upgrade web

The same 62 upgrade IDs and family caps now have shared prerequisites in `scripts/upgrade_graph.gd`. Feed 1 starts the map. It opens Bounce 1, Time 1 and Gold 1. Power 1 needs Bounce 1 **and** Time 1. Later routes alternate between families, with joins for stronger recipes. Reaching Power 3 requires ownership in all eight families. Purchases and free module vouchers enforce the same prerequisites.

The fullscreen map winds around itself in a compact, gently irregular spiral. Coordinates remain fixed as upgrades are discovered. Owned connections recede; active and selected connections stand out. A partly discovered join is muted and shows its ingredients. Ready recipes retain green/red affordability surfaces, price labels, selection bounce, affordability bounce, pinch/wheel zoom and touch panning. No instructional or decorative copy was added to the game.

## Balance

Power adds 0.50 damage per tier for tiers 1–3, 0.35 for 4–6, and 0.25 for 7–10. Damage tops out at 4.55, versus 6.00 previously. This pass kept upgrade prices unchanged and lowered Gelato entry from 400,000 to 40,000. The subsequent [coin-budget and Impact rebalance](ECONOMY_REBALANCE.md) lowers the current entry fee to 1,000 after measuring completion savings.

Paired automated simulations increased a Power-biased Bakery strategy from 20–24 to 41–43 attempts; a balanced strategy moved from 32–34 to 36–38. This is evidence of a reduced shortcut, not a human playtime guarantee. The earlier 2–3 hour target still needs player testing; this pass deliberately tests mixed progression before further price or HP increases. Method and traces: `verification/spiral-design-v1/pacing/` at the workspace root.

## Peg layout

All 24 trays have authored irregular positions. Generation happens offline with fixed seeds. Runtime attempts, Home previews and retries use exactly the same points, without consuming gameplay RNG. Counts, HP and peg types are unchanged. Positions stay within the board with at least 70 px between peg centers. The authoring script and contact sheet are in `verification/design-spiral-v1/board-layouts/`.

## Save compatibility

Existing coins, tier ownership, area progress, vouchers and permanent purchases are retained. Owned tiers are grandfathered even when their new prerequisites were not previously bought. New purchases follow the new graph. An unfinished checkpoint made under the old board/balance fingerprint is safely rejected and returns Home; it does not resume changed physics mid-run. Already-earned pending results and campaign state retain their existing save handling.

## Validation

Focused checks cover the acyclic, fully reachable graph, AND gates, voucher enforcement, legacy ownership, exact damage values, all 24 layouts, minimum spacing, shared preview/live geometry, deterministic retries, gestures, hit targets and feedback. Native OpenGL captures cover both themes at 450×800, with zero player-profile reads or writes. The Windows regression runner uses its own disposable save directory.

This source pass is not a new exported Windows or Android release. The previously uploaded v0.6.0 builds remain historical artifacts.

Final result: 1,141 checks passed across 15 regression suites, plus 18 paired pacing scenarios and 12 native renderer captures. See `verification/spiral-design-v1/validation.json` for the final passing logs. An isolated fresh playtest was opened on the desktop; its save is separate from the existing player profile.
