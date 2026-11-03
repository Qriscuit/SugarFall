# Sugarfall: complete illustrated upgrade backgrounds

25 October 2026. The upgrade map now uses one complete illustration per area. Buildings, gardens, curved stone boundaries, courtyard and shadows are painted together into a cohesive scene. The 120-degree upgrade layout, all 62 upgrades, 61 straight connections and existing progression remain unchanged.

## Finished backgrounds

- [Bakery illustration](../../PLINKO/data/art/environment/upgrade_arc_illustrated_v4.png): mint roofs, copper details, connected flowering gardens and a pale sage courtyard.
- [Gelato illustration](../../PLINKO/data/art/gelato/environment/upgrade_arc_illustrated_v4.png): the same composition with lavender roofs, lilac planting and a cool lilac courtyard.

The final Bakery PNG is 1659×948 RGB and Gelato is 1660×948 RGB. The game imports the full source resolution with mipmaps and preserves the selected generated files byte for byte. Each background occupies world rectangle `[-2450, -4650, 10800, 6171.428571428572]`, following the same pan and zoom as the upgrade map. A 2.5-percent edge fade blends the illustration into the surrounding area color.

The renderer uses schema 3 in [upgrade_arc_art.json](../../PLINKO/data/upgrade_arc_art.json). It draws one image for the active area. The modular scenery sprites, native curb geometry and flat ground bands from earlier passes are no longer drawn. Live upgrade portraits, prices, state marks, routes and fixed interface remain independent layers above the illustration.

## Generation and edits

All image work used the built-in `image_gen` tool. The [original arc concept](../../PLINKO/data/art/environment/upgrade_arc_v2.png) supplied the illustrated visual style, while [composition-guide.png](composition-guide.png) supplied the shortened arc and quiet courtyard shape. [make_guide.py](make_guide.py) draws this original geometry guide; it does not edit generated artwork. [guide.json](guide.json) records its world mapping.

The exact prompt sequence is:

1. [Complete Bakery scene](bakery-prompt.txt): a connected garden town, with architecture requested approximately 30 percent larger than the original concept and a quiet courtyard for upgrades.
2. [Inner-garden clearance edit](inner-clearance-prompt.txt): reduce and lower the inner garden opening so the inner upgrade route remains over open ground, preserving the outer village.
3. [Gelato theme edit](gelato-prompt.txt): preserve the accepted composition and geometry while changing its palette and shop details.
4. [Bakery sage courtyard edit](sage-courtyard-prompt.txt): change only the Bakery floor to pale sage, reducing the beige cast while preserving the architecture, gardens and clear space.

[sources.json](sources.json) records source outputs, chosen project paths, prompts and reference roles. The first Bakery candidate remains as [bakery-initial.png](bakery-initial.png), and the accepted courtyard composition before its final color edit remains as [bakery-before-sage.png](bakery-before-sage.png). Gelato was derived from that latter composition. The earlier modular pieces and SVG canvases are retained in their original folders as historical sources.

The single illustration is deliberately magnified at close map zoom. Full-resolution imports preserve its native detail but do not create additional source detail. The separate food icons, routes and interface retain their own sharp rendering. Visual review therefore checks both the coherent full scene and the readability of live elements at normal and maximum zoom.

## Validation and previews

382 focused checks passed: 24 complete-image art checks, 212 map interaction checks, 89 Bakery navigation checks and 57 Gelato navigation checks. Twenty-four graphics captures cover both themes, both phone sizes, map overviews, art-only views and scenery closeups. Fixtures used isolated projects and save directories, with zero player-profile access. Evidence: [test summary](../../verification/illustrated-arc-v4/regression/summary.json) and [render log](../../verification/illustrated-arc-v4/render.log).

[Bakery map](../../verification/illustrated-arc-v4/renders/bakery-whole-arc.png) · [Gelato map](../../verification/illustrated-arc-v4/renders/gelato-whole-arc.png) · [Bakery art](../../verification/illustrated-arc-v4/renders/bakery-art-canvas.png) · [Phone opening](../../verification/illustrated-arc-v4/renders/bakery-first-choices-450.png) · [Scenery detail](../../verification/illustrated-arc-v4/renders/bakery-scenery-detail.png)
