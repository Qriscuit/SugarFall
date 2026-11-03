# Sugarfall: shorter arc with directional planting

25 October 2026. The upgrade routes now span 120 degrees, from 210° to 330°, rather than the previous 162°. The quiet ground extends four degrees past each end so the first and last tiles sit fully on the courtyard. Ground, continuous curbs, upgrades and decorative anchors use the same center read from `upgrade_layout.json`.

## Correcting the scenery

The previous composition reused a horizontal crescent planter around the perimeter. Its baked stone arc crossed or ran alongside the real boundary. That asset, `garden_border.png`, is retained as an earlier source but is absent from the current runtime composition.

Four new transparent planting sections were generated separately for the local directions at 225°, 255°, 285° and 315°. Each is placed once per theme at its matching angle. They contain foliage and flowers only; the shared continuous curb supplies the stone boundary. Placement adjustments are radial, so clearance adjustments cannot move an image to a different tangent. Alpha samples also verify that opaque planting stays outside the curb. No raster rotation, repainting or flattening is used during assembly.

- [225° left section](../../PLINKO/data/art/arc_sections/v3/planting_225.png)
- [255° upper-left section](../../PLINKO/data/art/arc_sections/v3/planting_255.png)
- [285° upper-right section](../../PLINKO/data/art/arc_sections/v3/planting_285.png)
- [315° right section](../../PLINKO/data/art/arc_sections/v3/planting_315.png)

[generation-prompts.json](generation-prompts.json) contains the exact prompts used with the built-in image-generation tool. [sources.json](sources.json) records source files and original PNG dimensions. [orientation-report.json](orientation-report.json) records the measured planting directions, all within 6.1 degrees of their intended tangent. The silhouettes remain organic rather than exact geometric outlines.

## Editable composition

There are 15 source images and 35 placements in each theme. Upright buildings sit behind the outer curb, with their own forecourts. Separate round herb beds and a conservatory form the inner garden. The reduced number of placements removes repetitive crosswise wall fragments and gives each group a clear role.

[assemble_scene.py](assemble_scene.py) edits position, size and layer order, preserving the source PNG bytes. It writes both [runtime metadata](../../PLINKO/data/upgrade_arc_art.json) and the [Bakery](bakery-editable-canvas.svg) and [Gelato](gelato-editable-canvas.svg) editable canvases. [composition-sources.json](composition-sources.json) records every image hash. Keep each SVG in this folder so its relative PNG links resolve. The original concept and upgrade clearance guides remain hidden layers.

The assembly script is the canonical composition source. Manual SVG changes do not automatically update game metadata; accepted placement changes should also be made in the script before regenerating both outputs.

Every decorative image remains proportionate and has enough source resolution for the closest supported zoom. Decoration frames clear the semantic upgrade markers and the thick straight route lines. The existing 62 upgrades and their single-parent dependencies are preserved.

## Verification and previews

474 focused graph, layout, art, map-interaction and navigation checks passed. After adding the quiet end margins, all 36 art checks passed again. Twenty-four graphics captures cover both themes at phone sizes, full maps, artwork-only canvases and close-up detail. The isolated fixtures recorded zero player-profile access. Production asset import completed successfully.

[Regression summary](../../verification/modular-arc-v3/regression/summary.json) · [Final art checks](../../verification/modular-arc-v3/art-final.log) · [Render log](../../verification/modular-arc-v3/render.log)

[Bakery upgrade map](../../verification/modular-arc-v3/renders/bakery-whole-arc.png) · [Gelato upgrade map](../../verification/modular-arc-v3/renders/gelato-whole-arc.png) · [Artwork canvas](../../verification/modular-arc-v3/renders/bakery-art-canvas.png) · [House close-up](../../verification/modular-arc-v3/renders/bakery-house-closeup.png)
