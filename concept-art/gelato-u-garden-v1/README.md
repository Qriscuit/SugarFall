# Gelato U-garden scenery

Generated November 2, 2026 with the built-in `image_gen` tool for Gelato's two-route upgrade map. The scene has a bottom-center entry plaza and two open lilac corridors rising outward in a U. Mint planting, copper cooling equipment and glass conservatories distinguish the left district; strawberry orchards and wafer-roof gelaterias distinguish the right. Buildings, gardens, paving, walls and lighting form one continuous painted scene. Live upgrades, links, currency and labels remain separate game layers.

## Final asset

[upgrade_u_garden_v1.png](../../PLINKO/data/art/gelato/environment/upgrade_u_garden_v1.png) is a 1254×1254 RGB PNG, 2,879,457 bytes. The exact generated pixels were copied into the project. The prompt requested 2048-square; the built-in tool returned 1254-square, so no larger source-detail claim is made. Godot's import settings retain native resolution and generate mipmaps; close map zoom magnifies the scenery while live upgrade portraits and text stay separately rendered.

The square world rectangle is `[-5200,-9650,10400,10400]`. The root at world `(0,0)` maps to image `(.5,.9278846)`, and the two tips remain inside the upper corners. [geometry.json](geometry.json) records this mapping. Suggested surrounding color is `#c9bddc`, with the existing 2.5% image-edge fade. The geometry was based on the graph agent's mirrored U/hyperbola landmarks and expanded horizontally to preserve the image's square proportions.

## Provenance and inspection

The exact generation prompt is in [prompt.txt](prompt.txt); [sources.json](sources.json) records the original generated path, hash, dimensions and copy verification. The current Gelato arc image and [art direction](../../PLINKO/docs/ART_DIRECTION.md) were inspected for materials, lighting, palette and rendering style. No source image was edited or supplied as a generation input.

Standalone visual inspection confirmed the U orientation, open bottom-center plaza, distinct districts, quiet live-node corridors and absence of baked text or interface. The integrated game must also be reviewed with every live upgrade and connection overlaid, because scenery alone cannot establish placement clearance.
