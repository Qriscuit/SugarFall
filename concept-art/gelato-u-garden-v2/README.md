# Gelato scenery for the branching U map

`PLINKO/data/art/gelato/environment/upgrade_u_garden_v2.png` is a new sibling asset made with the built-in image generation tool. The v1 source remains unchanged. The final native image is 1254 × 1254 pixels (RGB), copied into the project without pixel editing or resampling.

The new layout has two rising trunks, six short optional tails and a later Twin launcher node. A continuous painted road could reveal which route continues, so v2 uses quiet lilac ground beneath all upgrades and links. The mint workshop, berry gelateria, glass conservatory and fountain form separate central landmarks. The live map supplies the route lines and nodes.

`prompt.txt` records the first edit request, using v1 as the style/edit target and `layout-guide.png` as a placement guide. The guide is a newly drawn geometric diagram, not edited game artwork. The first generation preserved the desired style but spread the objects too far. `correction-prompt.txt` records the targeted second built-in edit that reduced the cluster. The final scene is preserved exactly as returned.

The requested central rectangle was a generation guide. The final pixels are checked using the three conservative actual landmark rectangles in `landmark-regions.json`, including visible foliage, low walls and shadows. `check-landmarks.ps1` compares those regions with every tile/selection footprint and every link in the graph author's `geometry.json`. `landmark-validation.json` records **375 passing clearance checks**: 63 node footprints and 62 padded link bounds against each of the three regions. Node footprints include a 28-world-pixel margin around each 224-pixel tile; links reserve 30 pixels. Actual map previews are under `verification/gelato-branches-20261102/preview` at the workspace root.

The square world bounds remain `[-5200,-9650,10400,10400]`. Artwork and upgrades use the same pan/zoom transform, so the measured clearance remains constant in world space. The surrounding Gelato surface color is `d9c1e7`, the average of 24 native-image edge samples; this removes the contrast between the new ground and the old outer color at overview zoom. Native illustration pixels are magnified at close zoom; node artwork and text remain separate UI. No baked UI, route marks or endpoint decorations appear in the painting.

Final GPU review passed **161 checks across 44 captures**, covering both 720×1280 and 450×800. The full 63-node overview shows every landmark unobscured. Each of six forks presents both immediate choices with equal styling and no future route clue. Tail endpoints, late Twin purchase/ownership and green/locked/red/infinite-money rebuild states were reviewed at both sizes. The final full-map edge color was rerendered and rechecked.

The exact native output locations, hashes and prompts are recorded in `sources.json`.
