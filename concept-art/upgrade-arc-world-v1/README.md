# Upgrade arc world art — 25 October 2026

The two final scenes are integrated behind the live upgrade graph. Bakery uses mint roofs, copper ovens and cream courtyards; Gelato uses lavender roofs and flowering planting. The open entrance and low inner curb leave every upgrade position on quiet ground. The geometry and progression of the 62 upgrades remain unchanged.

Final saved assets:

- [Bakery](../../PLINKO/data/art/environment/upgrade_arc_v2.png)
- [Gelato](../../PLINKO/data/art/gelato/environment/upgrade_arc_v2.png)

Generated with the built-in `image_gen` tool. Source PNG pixels are unchanged. Both assets are 1659 × 948, with full-resolution mipmapped Godot imports. The renderer places each scene over world rectangle `[-1900,-5300,10850,6200]` and applies the same pan and zoom as the tiles. A short edge alpha fade blends into the surrounding quiet surface. Artwork has no baked nodes, routes, state indicators or text. The large map magnifies scenery at close zoom; food tiles and all functional UI remain separate, sharp runtime layers.

The exact prompt set is [initial Bakery](prompts.txt), [entrance revision](clearance-revision-prompt.txt), [inner-courtyard correction](inner-courtyard-prompt.txt), and [final Gelato edit](gelato-final-prompt.txt). [sources.json](sources.json) records original generated files, reference roles and the revision chain. The first candidates remain as `upgrade_arc_v1.png` for recovery; the runtime uses only v2.

Verification: 337 assertions passed across layout, background alignment, map gestures, Bakery navigation and Gelato navigation. Eighteen final graphics-renderer captures cover both themes at 450 × 800 and 720 × 1280 plus full-scene landscape views, with zero player-profile access. Evidence is in [verification/arc-art-v1](../../verification/arc-art-v1/). Review the [integrated Bakery overview](../../verification/arc-art-v1/renders-final/bakery-whole-arc.png) and [Gelato overview](../../verification/arc-art-v1/renders-final/gelato-whole-arc.png).
