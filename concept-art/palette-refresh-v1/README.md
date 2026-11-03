# Sugarfall palette and map scale refresh

25 October 2026. The user requested bigger upgrade icons, less empty space, and less beige throughout the game.

Bakery now uses sage/celadon counters and tray lining, with grass throughout the upgrade garden. Gelato uses cool lavender stone, blue-lavender tray lining, and green planting around its upgrade arc. Cream stays on small readable UI panels, food and architectural accents. Original prop composition, transparent tray silhouettes and live UI rendering remain intact.

## Production assets

Both `PLINKO/data/art/environment/` and `PLINKO/data/art/gelato/environment/` contain the replacement `home_counter.png`, `play_counter.png`, `upgrade_counter.png`, `journey_backdrop.png`, and the new `upgrade_arc_v3.png`. Both `PLINKO/data/art/food/tray.png` and `PLINKO/data/art/gelato/food/tray.png` have new colored centers. The legacy `countertop.png` in each food folder is an identical copy of that area's new play background.

The 12 final assets were edited with the built-in `image_gen.imagegen` tool. Each `*-prompt.txt` contains its exact final prompt. [sources.json](sources.json) records generated paths, production paths, original reference backups, dimensions, transparency, SHA-256 checksums and source bounds. `references/<asset-id>/input.png` preserves each original input. No generated pixels were altered: `register_assets.py` only inspected images, updated source bounds/import metadata and recorded provenance.

## Map density

Tiles grew from 142×142 to 176×176 px; portraits grew from 92×84 to 124×114. The 62 individually scattered positions now occupy 5,544×3,109 px instead of 7,497×4,194, about 45% less area. Mean connector length fell from 626 to 428 px, and the maximum from 1,042 to 648. Minimum tile gap is 27.06 px, with no crossings or unrelated tile obstructions. The 162-degree arc, original graph, prices and saves are preserved. Background world rect is `[-1520,-4240,8680,4960]` after uniform 0.8 scaling.

## Verification

- 502 checks passed across graph, layout, map-art transform, input/map, both area navigation suites, launch transition and area progression.
- 714 production-art checks passed, including text fitting, texture readiness and preserved physics/wallet/RNG state.
- 66 native captures: 18 arc views plus 48 game screens across both themes at 450×800 and 720×1280, including two full-arc overviews.
- All fixtures bypassed real player profile reads/writes. Tests ran in an isolated project/save directory.
- The first isolated font import crashed; retry succeeded. Production asset import also succeeded.

Evidence: [palette-refresh-v1](../../verification/palette-refresh-v1/), [density metrics](../../verification/arc-density-v1/). Source art remains 1659×948 for the arcs, so decorative scenery is softer at close zoom than live UI and food icons.

## In-game previews

![Bakery opening upgrades](../../verification/palette-refresh-v1/arc/bakery-first-choices-450.png)

![Bakery gameplay](../../verification/palette-refresh-v1/screens/bakery-play-450x800.png)

![Gelato gameplay](../../verification/palette-refresh-v1/screens/gelato-play-450x800.png)
