# Sugarfall: separate pieces, then an edited composition

25 October 2026. The original [Bakery arc concept](../../PLINKO/data/art/environment/upgrade_arc_v2.png) supplies the composition: a planted town boundary, a street of small buildings, a quiet open courtyard for upgrades, and an inner garden. Its flattened pixels are retained as a hidden reference layer, not enlarged behind the playable map.

## Phase 1 — individual image generation

The existing nine houses, trees and props remain separate transparent images. Three additional pieces complete the environment: a [planted garden wall](../../PLINKO/data/art/arc_sections/garden_border.png), a [kitchen herb garden](../../PLINKO/data/art/arc_sections/herb_garden.png), and a [stone entrance forecourt](../../PLINKO/data/art/arc_sections/courtyard_steps.png). Each was produced in its own built-in image-generation call, using the original composition and the finished bakery house as references.

[generation-prompts.json](generation-prompts.json) contains the exact prompts and reference roles. [sources.json](sources.json) records generated source files and saved project assets. The earlier nine assets and their prompts are documented in [modular-arc-v1](../modular-arc-v1/README.md).

## Phase 2 — editing the canvas

[assemble_scene.py](assemble_scene.py) positions, sizes, groups and orders the existing images. It does not generate or repaint the scene, change PNG pixels, or flatten the separate assets. [composition-sources.json](composition-sources.json) records the SHA-256 hash and dimensions of every image used.

The editable masters are [Bakery](bakery-editable-canvas.svg) and [Gelato](gelato-editable-canvas.svg). Open either in an SVG editor: every image has a named layer and links to its original PNG in the project. Hidden layers contain the initial concept and the upgrade clearance guides. Keep the SVG in this folder to preserve its relative image links.

The assembly script is the canonical composition source and writes both SVG and game metadata. Manual SVG edits are useful for art direction but do not automatically update game placement metadata; reproduce accepted changes in the script and rerun it to keep both outputs aligned.

The same composition is saved to [upgrade_arc_art.json](../../PLINKO/data/upgrade_arc_art.json) and drawn by the game from the original PNG resources. Images use full-resolution, mipmapped imports. Layer order matches the SVG: foundations first, then buildings and planting ordered by their ground position. Each composition has 66 image placements from 12 assets, arranged into an entrance garden, seven outer street sections, six connecting garden groups, an inner conservatory and smaller planting pockets. Smooth native ground, garden beds and continuous stone curbs connect these groups without introducing a repeated raster ground texture.

Decorative layers deliberately overlap within garden and building groups. Their complete frames remain clear of all upgrade tiles and straight route segments, including the largest footprints reached during semantic zoom. The 62 upgrades, three routes, prices, save state and gameplay effects are unchanged.

The SVG masters contain artwork only. The game adds live upgrades, routes, ownership and interface above that artwork.

## Validation and previews

276 checks passed: 32 layered-art checks, 32 map-layout checks and 212 map interaction checks. Twenty-four graphics captures cover both themes, phone sizes, full maps, art-only canvases and maximum-zoom details. Fixtures used isolated projects and save directories; no player profile was accessed. See [test summary](../../verification/modular-arc-v2/regression/summary.json) and [render log](../../verification/modular-arc-v2/render.log).

[Bakery art canvas](../../verification/modular-arc-v2/renders/bakery-art-canvas.png) · [Gelato art canvas](../../verification/modular-arc-v2/renders/gelato-art-canvas.png) · [Live upgrade map](../../verification/modular-arc-v2/renders/bakery-whole-arc.png) · [House detail](../../verification/modular-arc-v2/renders/bakery-house-closeup.png)
