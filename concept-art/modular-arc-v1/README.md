# Sugarfall modular upgrade world

25 October 2026. Nine separately designed, transparent environment pieces are assembled into a native game scene. The new arc replaces the stretched full-scene raster with clean vector ground, individual sprites, authored contact shadows and quiet curved curbs.

## Art pieces

All nine were generated with the built-in `image_gen.imagegen` tool, one asset per call, on transparent backgrounds. The original 1254×1254 RGBA PNG pixels are preserved byte for byte. Godot imports them at 1024 px with mipmaps; all placements retain at least one imported source pixel per logical screen pixel at maximum zoom 1.55.

| Piece | Saved asset | Prompt |
|---|---|---|
| Bakery cottage | [PNG](../../PLINKO/data/art/arc_props/bakery_house.png) | [Exact prompt](bakery_house-prompt.txt) |
| Flour mill | [PNG](../../PLINKO/data/art/arc_props/bakery_mill.png) | [Exact prompt](bakery_mill-prompt.txt) |
| Greenhouse | [PNG](../../PLINKO/data/art/arc_props/greenhouse.png) | [Exact prompt](greenhouse-prompt.txt) |
| Gelato pavilion | [PNG](../../PLINKO/data/art/arc_props/gelato_pavilion.png) | [Exact prompt](gelato_pavilion-prompt.txt) |
| Gelato townhouse | [PNG](../../PLINKO/data/art/arc_props/gelato_house.png) | [Exact prompt](gelato_house-prompt.txt) |
| Oak tree | [PNG](../../PLINKO/data/art/arc_props/oak_tree.png) | [Exact prompt](oak_tree-prompt.txt) |
| Lilac tree | [PNG](../../PLINKO/data/art/arc_props/lilac_tree.png) | [Exact prompt](lilac_tree-prompt.txt) |
| Flower planter | [PNG](../../PLINKO/data/art/arc_props/flower_planter.png) | [Exact prompt](flower_planter-prompt.txt) |
| Bench and lamp | [PNG](../../PLINKO/data/art/arc_props/garden_bench.png) | [Exact prompt](garden_bench-prompt.txt) |

[sources.json](sources.json) records source output paths, project destinations, sizes, transparency and SHA-256 hashes. No raster resizing, recoloring, cropping or compositing script was used. [compose_scene.py](compose_scene.py) only inspects assets and writes import/placement metadata. The collage is drawn from the original separate sprites in the game, so every piece remains editable and reusable.

## Composition

The two scenes each contain 25 placements. Bakery uses mint buildings, oak trees and sage ground. Gelato uses lavender buildings, lilac trees and a lavender band with green surroundings. Both share the greenhouse, planters, and bench. A house beside the entrance makes the separate artwork visible at normal play zoom.

Each prop has its own map rectangle. Their rectangles preserve source proportions and stay clear of all current/future nodes and straight connections, including the largest node footprints created by semantic zoom. The placement search adjusts decoration only. Ground geometry, curb strokes, shadow ellipses and textures are cached. Offscreen props are culled; retired giant scene images are excluded from exports.

## Upgrade routes and zoom

All 62 original upgrades are visible on three mixed routes, with 61 straight connections. Every non-root node has one parent. Each family's tiers remain on one route in order, preserving count-based saves without hidden cross-route requirements.

Tiles are 224×224, with 160×148 food portraits. The scattered placements occupy the same 162-degree arc with more room between nodes. Geometry checks found 46 px minimum tile clearance, no crossings and no blocked paths. Costs, effects and existing ownership are preserved.

At normal zoom, a tile displays at 188.16 logical px. At overview zoom, icons target 36 logical px and are capped against neighboring tiles to avoid collisions. Tiny price/tier labels disappear, while selection still shows its full card. Connections remain 3–10 logical px thick with a contrasting outline. Rendering, hit targets, culling and camera bounds use the same node rectangles.

## Validation

- 944 regression checks passed across the built-in self-test, graph, geometry, layered art, independent gameplay, checkpoint/resume, v0.4, map gestures, both area navigation suites, transitions, coin display and area progression.
- 714 production-art checks passed across 48 captures.
- 22 additional layered-map captures cover both themes at phone sizes, full-map views, maximum-zoom props and maximum-zoom houses.
- All visual fixtures bypass real player profiles; regression suites use isolated project and save directories.
- Production imports succeeded. The older self-test's assumption that every first tier precedes every second tier was updated to follow the new mixed paths.

Evidence: [combined regression](../../verification/modular-arc-v1/regression-final/summary.json), [layered art checks](../../verification/arc-art-layered-v1/shadow-art-qa.log), [game screens](../../verification/modular-arc-v1/screens/), [map captures](../../verification/arc-art-layered-v1/renders/).

## In-game views

[Whole Bakery arc](../../verification/arc-art-layered-v1/renders/bakery-whole-arc.png) · [Whole Gelato arc](../../verification/arc-art-layered-v1/renders/gelato-whole-arc.png) · [Phone opening](../../verification/arc-art-layered-v1/renders/bakery-first-choices-450.png) · [Bakery house at maximum zoom](../../verification/arc-art-layered-v1/renders/bakery-house-closeup.png) · [Gelato house at maximum zoom](../../verification/arc-art-layered-v1/renders/gelato-house-closeup.png)

