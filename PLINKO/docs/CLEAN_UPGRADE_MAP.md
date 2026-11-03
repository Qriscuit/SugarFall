# Bakery's single-parent upgrade arc — 25 October 2026

This record describes Bakery's retained three-route map. Gelato now has a separate [two-path U garden](GELATO_U_MAP.md), preserving its existing upgrade ownership.

The current map keeps the open donut-band idea from the user's Noklateo reference and shortens it to 120 degrees, one third of a circle. Feed 1 starts at the left tip. Three independent, mixed upgrade routes travel around the band toward the opposite end. Each node has its own fixed, irregular placement; the earlier stamped clusters and two-parent joins are retired.

## Current progression

All 62 tier IDs, family caps, prices, effects and saved ownership remain. `scripts/upgrade_graph.gd` is authoritative: Feed 1 has no parent, and each of the other 61 nodes has exactly one. Feed 1 opens Bounce 1, Time 1 and Gold 1, the heads of these routes:

| Route | Families and tier counts | Nodes after Feed 1 |
| --- | --- | --- |
| A, beginning at Bounce 1 | Bounce 1–6, Power 1–10, Impact 1–6 | 22 |
| B, beginning at Time 1 | Time 1–10, Ricochet 1–6, Split 1–6 | 22 |
| C, beginning at Gold 1 | Gold 1–8, Feed 2–10 | 17 |

Each route mixes its families in a fixed, varied sequence. For example, A begins Bounce 1 → Power 1 → Impact 1 → Power 2, B begins Time 1 → Ricochet 1 → Time 2 → Split 1, and C begins Gold 1 → Feed 2 → Gold 2. `ROUTE_FAMILIES` holds the full sequences; `Graph.routes()` returns the corresponding tier identities. A player can complete any one route without purchasing upgrades on another route after the shared Feed 1.

Saves store a count for each family rather than a separate ownership flag for every tile. A purchase must therefore be that family's next tier. Keeping all successive tiers of each family in one chain makes the preceding tier an ancestor of every later tier. Splitting one family between routes would silently require progress on a second route even when a tile appeared to have only one parent. The current structure prevents that implicit AND requirement.

Previously owned tiers stay owned, including irregular legacy builds that lack some new ancestors. Players can fill missing tiers and complete the map without losing ownership. New purchases and module vouchers follow the current single-parent prerequisites. No save schema, peg positions, damage values, prices or area-entry fee changed in this pass; current active checkpoints remain compatible.

Only Feed 1 is visible on a fresh map. Buying it reveals the three route heads and their incoming connections. From then on, the map shows every owned upgrade plus the next eligible purchase on each route. Buying that upgrade reveals its successor; deeper upgrades and their connections remain hidden and cannot be selected. Eligibility follows prerequisites and family-tier order, so insufficient coins never hide an otherwise available upgrade. Previously owned legacy tiers remain visible even if their current route ancestors are missing.

If a purchase reveals exactly one eligible direct successor, selection advances to it immediately and the purchase panel refreshes with a small bounce. Its name, tier, effect and price describe the new selection. The Buy button always shows the full current price, including for an unaffordable successor, while its styling indicates affordability. Another distinct Buy tap can purchase the successor while the camera or panel animation is running. Selection itself never spends, and holding a touch never repeats purchases. Feed 1 retains its owned selection because the player must choose among three routes. Failed purchases and route completion keep the current selection, without choosing an unrelated route or skipping through legacy owned segments. Reduced Motion refreshes the panel without displacement.

## Placement and rendering

`data/upgrade_layout.json` contains the 62 positions, three route lists and 61 straight two-point connections. The annulus is centered at `(2944.4863728670916, 1700)`, has inner/outer radii of 2200/4600 world pixels, and runs from 210 to 330 degrees through a 120-degree sweep. Its center is open. Nodes occupy three independently varied radial lanes, with no repeated local cluster motif. Feed 1 remains at `(0, 0)` and the three first-choice positions remain unchanged.

Tiles are 224×224 world pixels and detailed food portraits are 160×148. The authored node-center bounds are 6,995.44×3,251.89 world pixels. The closest tile faces retain 41.6 pixels of axis clearance. Connections average 498.77 pixels and range from 273.24 to 781.54 pixels. Authoring checks find no crossed connections, self-crossings or paths through unrelated tiles.

The default zoom is 0.84 and frames Feed 1 and the positions of its three choices as they are revealed. Zoom ranges from 0.075 to 1.55. At overview scales, semantic zoom retains food icons and state marks while hiding tiny tier and price labels. Tiles aim for a 36-logical-pixel marker size, capped by each node's nearest neighbor in the complete authored layout so revealing another upgrade does not change existing marker sizes. Detail appears at a rendered tile width of 112 logical pixels. Drawing, pointer hits, culling and camera bounds use the same rendered rectangle. Compact markers retain color feedback without displacement; detailed tiles keep selection and affordability motion. Reduced Motion keeps state cues without motion.

A successful map purchase that reveals new upgrades starts a 0.55-second camera glide with an eased start and finish. It centers the newly revealed tile, or Feed 1's three route heads together, within the usable focus area above the selected card and below the header. It preserves zoom unless the newly revealed group needs a smaller scale to fit with a margin; it never zooms in automatically. A single direct successor is already selected during the glide, and the next Buy action is available immediately when affordable. A manual map touch or zoom immediately interrupts the glide, and leaving the map, focus loss or a view reset cancels it. Reduced Motion applies the final framing immediately, including when enabled during a glide. Entry, wallet changes, failed purchases and purchases with no newly visible nodes never trigger this movement. Camera interpolation is temporary view state and does not alter authored coordinates or saves.

Connections remain straight through every camera transform. Their strokes stay between 3 and 10 logical pixels, with a light outline for separation from scenery. A connection is drawn only when both endpoint upgrades are visible; revealed connections remain solid and readable. Selection highlights the selected node's incoming connection and its visible parent. Wallet, navigation, the selected upgrade card, Treats and Play stay anchored to the screen over the map; only the purchase card's brief selection bounce moves its overlay. Its pointer bounds follow that rendered movement. Revealing upgrades never changes their authored positions or the background illustration.

## Illustrated scenery

`scripts/upgrade_arc_art.gd` draws one complete background illustration before the live routes and tiles. `data/upgrade_arc_art.json` schema 3 defines a shared world rectangle, one texture and surrounding base color per area, and a gentle image-edge fade. The image follows the same pan and zoom transform as the upgrade map. Bakery uses mint roofs and a pale sage courtyard; Gelato uses lavender roofs and a cool lilac courtyard.

The backgrounds are RGB PNGs, 1659×948 for Bakery and 1660×948 for Gelato, with full-resolution mipmapped imports. Each image covers world rectangle `[-2450, -4650, 10800, 6171.428571428572]`. Buildings, gardens, curbs and ground are all painted into that image; the renderer adds no separate scenery props or native wall shapes. It caches textures and does not load files or scan pixels during drawing. Close zoom magnifies the illustration, while live food icons, route strokes and UI remain independent. If the image is unavailable, the map retains its counter/surface fallback.

Current assets, generation/edit prompts and source provenance are recorded in [concept-art/illustrated-arc-v4](../../concept-art/illustrated-arc-v4/README.md) at the workspace root. The original arc concept supplied the visual style, and a guide made from the shortened layout supplied the composition. Architecture was requested at a larger scale; a targeted inner-garden edit preserved quiet ground beneath the routes. Earlier illustrated and modular compositions remain historical records.

## Authoring and verification

`tools/author_upgrade_arc.py` reads the authoritative family sequences and bakes the layout reproducibly with seed 251027. It seeds each lane by cumulative axis distance so square tiles retain space along diagonal parts of the shorter arc, then applies independent position changes while enforcing at least 40 pixels of tile clearance, unobstructed straight links, noncrossing edges and an 820-pixel maximum connection length. It checks the rounded output again before writing. Randomness runs only during authoring; purchases, reopening the map and switching areas never move nodes or links.

The generator requires Python, NumPy and Pillow. From the project directory, run `python tools/author_upgrade_arc.py --preview-dir ../verification/compact-arc-v1`, then run the `upgrade-graph` and `upgrade-layout` suites against the generated JSON. The runtime needs no Python dependencies.

The compact layout's numerical metrics and authored preview are in `verification/compact-arc-v1/` at the workspace root. The `map` suite checks gestures and the shared rendered rectangles; `upgrade-arc-art` checks the complete-image renderer and its camera alignment. `tests/arc_art_visual_qa.gd` captures both themes at phone sizes and as map overviews without accessing player profiles. The earlier single-parent progression change passed 346 isolated assertions in `verification/single-parent-routes-v1/`; those results describe that earlier layout and are retained as historical progression evidence.

The 25 October v0.6.3 discovery pass is recorded in `verification/upgrade-discovery/` at the workspace root: 472 checks cover the game self-test, graph, complete layout, map interactions and both areas' navigation. `tests/upgrade_discovery_visual_qa.gd` captured fresh, starter-purchased, Bounce-purchased and empty-wallet states in both areas (eight phone captures with no player-profile access). The checks covered every route's successive reveal, preservation of legacy owned tiers, hidden-node hit testing, unaffordable next choices and fixed authored positions.

The 25 October v0.6.4 camera pass is recorded in `verification/purchase-camera/`: 455 checks cover map interactions, graph progression and both areas' navigation. Camera cases included later reveals on all three routes, starter-group fitting, preserved zoom and the then-current purchased selection, interruption by touch/zoom/focus loss/navigation, Reduced Motion and purchases with no successor. `tests/purchase_camera_visual_qa.gd` recorded 24 phone captures before, during and after the glide in both areas, without accessing player profiles. Those captures predate automatic successor selection.

The immediate next-selection update is verified in `verification/next-selection/` at the workspace root: 482 checks cover map input, graph progression and both areas' navigation. The map suite buys each route through distinct consecutive Buy taps, checks exact debits and successor prices, and verifies the moving purchase panel's hit areas, unaffordable successors and Reduced Motion. `tests/next_selection_visual_qa.gd` captures 16 phone states across both areas with no player-profile access.

## Historical designs, superseded

The earlier spiral used a dependency web whose crossings could not all be removed by moving nodes alone. The 24 October local-recipe design then kept 62 nodes with 81 routed edges, including two-parent joins such as Ricochet + Time → Power and Power + Split → Impact. Its later 25 October arc revision used 176×176 tiles and a single painted background per area. The subsequent 162-degree, 45%-of-a-ring layout and 170-degree scenery were also superseded by the compact 120-degree shape. Those earlier prerequisites, polylines, sizes and scenery are no longer the current implementation.

Historical geometry, simulations and captures remain in `verification/clean-map-v2/`, `verification/arc-density-v1/` and `verification/palette-refresh-v1/`. Their counts and observations describe those previous versions rather than the current three independent routes.
