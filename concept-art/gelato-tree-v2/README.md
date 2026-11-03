# Gelato winding mixed-tree composition

This winding mixed-tree geometry and its purple-ground artwork were delivered in Android v0.6.13. The current v0.6.14 keeps the geometry and replaces the ground with the [ceramic courtyard](../gelato-ceramic-v1/README.md). See [the verified delivery record](../../PLINKO/docs/ANDROID_SUGARFALL_v0.6.13.json) and [download notes](../../PLINKO/BUILD_LINKS.txt).

This revision keeps the central Feed entry, Dual Shot below it and the branching topology, while making the map taller, narrower and more winding. Two 14-node main paths fork after steps 3, 6 and 9; terminal branches contain 6/6/5 nodes on the left and 6/6/4 on the right. Each fork hands the continuing route to the apparent side branch while the straighter continuation becomes a terminal branch. All 61 progression connections are curved and sampled at 25 points each; Dual retains its separate entry link.

Upgrade types use a fixed authored shuffle across all routes and branches. They stay in the same positions between visits. All 62 original `[family,ordinal]` IDs remain, but ownership now records exact chosen nodes and effects/prices use aggregate family counts. Each terminal branch contains 4–6 distinct families. Six Power purchases are available by the left main path's twelfth step without buying optional branches. Dual Shot still requires tray 8 and Power 6 and costs 3,000 coins.

The world rectangle is `[-4600,-12250,9200,13800]`, a 2:3 portrait composition. Node centers span x=`−2774.5481…2840.473` and y=`−10800…440`; this node spread is **31.5% narrower and 46.6% taller** than the preceding antler map. Feed is `(0,0)` and Dual is `(0,440)`. Minimum authored center spacing is 342 world pixels against a 340-pixel requirement.

Twelve scenery authoring targets distribute art through the center, outer sides and entry: four central landmark/flower islands, four outer garden islands, two lower flower regions and two entry topiary regions. These rectangles guide composition; they are not a claim about the final painting's exact silhouette. Final artwork must be audited separately against every detailed tile, enlarged overview marker and sampled curve, including future hidden nodes. Nodes, routes, labels, prices and ownership marks remain live game UI and must not be baked into runtime art.

- [layout-guide.png](layout-guide.png): exact placement schematic with authoring labels and scenery targets.
- [geometry.json](geometry.json): node footprints, sampled paths, targets and fork handoffs.
- [geometry-stats.json](geometry-stats.json): measured extents, counts, spacing and authoring checks.
- [author_gelato_u_map.py](../../PLINKO/tools/author_gelato_u_map.py): reproduces the geometry artifacts and [runtime layout](../../PLINKO/data/gelato_upgrade_layout.json).

Authoring checks cover all 62 IDs, spacing, noncrossing curves including shared-endpoint and self-crossing cases, fork tangents and scenery-target clearance for detailed and compact markers. Current behavior and save migration are documented in [GELATO_U_MAP.md](../../PLINKO/docs/GELATO_U_MAP.md) and [GELATO_NODE_OWNERSHIP.md](../../PLINKO/docs/GELATO_NODE_OWNERSHIP.md). The [preceding antler art record](../gelato-antler-v1/README.md) remains historical. Earlier economy simulations do not establish this map's human purchase pacing.

The final native illustration is [candidate-02.png](candidate-02.png), copied unchanged to [upgrade_winding_garden_v2.png](../../PLINKO/data/art/gelato/environment/upgrade_winding_garden_v2.png). It is 1024×1536 pixels with SHA-256 `2db540e960051b479fd78d90ae604508bc5a570e013ccd45c5c2abd49a6079b5`. Central landmarks include a sundae fountain, kiosk, pavilion and slender flower planter; outer winding trees, a bench, trolley and entry flower urns frame the routes. The lavender paper ground leaves the upgrade tiles and their connections clear.

[Sources and exact prompts](sources.json), [initial generation prompt](runtime-art-prompt.txt) and [refinement prompt](runtime-art-edit-02.txt) record the image-generation provenance. The first candidate's foreground was too large. The second candidate reduced and repositioned the painted groups. No programmatic resizing or repainting was applied to either generated image. After painting, two continuing curves at the depth-9 forks received a local bend correction; node positions, scenery targets and world bounds stayed unchanged. The current guide includes that correction.

[Final validation](../../verification/gelato-tree-20261102/validation.json) records 1,830 checks across 14 headless suites and 427 GPU checks across 42 captures at 720×1280 and 450×800. All passed with zero real player-profile access. The [actual artwork audit](../../verification/gelato-tree-20261102/art-clearance.json) found zero collisions with detailed selection footprints, compact markers or sampled paths, each with an additional 30-world-unit margin. Foreground color measurement is supplemented by [visual inspection](../../verification/gelato-tree-20261102/qa-inspection.json); it is not semantic segmentation. Phone installation and purchase pacing remain device tests.

- [Full portrait map](../../verification/gelato-tree-20261102/screens/full-antlers-720x1280.png)
- [Opening view](../../verification/gelato-tree-20261102/screens/central-start-450x800.png)
- [Mixed-family purchase](../../verification/gelato-tree-20261102/screens/same-family-bought-450x800.png)
