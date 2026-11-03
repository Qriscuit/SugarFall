# Crystal Candyworks — Area 3

Crystal Candyworks uses pale aqua sugar glass, peach candy and warm copper. It follows Bakery's softer food shapes and Gelato's polished equipment while giving straight ricocheting shots and the timed multiplier their own visual identity.

The individual assets are native transparent sprite atlases, consumed as separate source regions at runtime:

- [Candy shots and multiplier](../../PLINKO/data/art/crystal/food/balls_atlas.png): normal aqua candy, lemon ricochet, raspberry splitter, blueberry Impact, a shard and the twin-candy pickup.
- [Crystal targets](../../PLINKO/data/art/crystal/food/pegs_atlas.png): normal, armored, prism and clock roles, each with intact and three damaged states. Neutral candy bodies support Bronze, Silver, Gold and Diamond tinting.
- [Equipment](../../PLINKO/data/art/crystal/food/equipment_atlas.png): rotating spout, ordinary and gold collector cups, and the candyworks landmark.
- [Tray](../../PLINKO/data/art/crystal/food/tray.png): pale blue play surface with aqua rails and copper joints.

Three complete background paintings provide the [workshop](../../PLINKO/data/art/crystal/environment/candyworks_room.png), [level journey](../../PLINKO/data/art/crystal/environment/journey_backdrop.png) and [upgrade courtyard](../../PLINKO/data/art/crystal/environment/upgrade_courtyard.png). Shared game controls retain the established buttons, typography and functional state colors. Text, timers, prices, connecting routes and upgrade nodes are live UI.

[Exact prompts, source paths and native dimensions](sources.json) record use of the built-in ImageGen tool. Original generated files are preserved. Project files are byte-identical copies with no programmatic image edits. Runtime atlas metadata measures visible bounds without altering the image; each role's damaged target frames keep a common frame so broken pieces do not grow.

The [layout guide](layout-guide.png) and [geometry record](geometry.json) describe three ascending faceted upgrade routes with Second Prism below their entry. World bounds are `[-3300,-9000,6600,9900]`. Courtyard artwork fills the outer sides, leaving the live central routes quiet. Its outside color is `#dbf0f4`, the measured mean native edge color.

Gameplay and save behavior are documented in [the Area 3 design](../../PLINKO/docs/CRYSTAL_CANDYWORKS.md). The production assets are included in the **Android v0.7.0 preview**, delivered on 3 November 2026 through the existing private Drive file. See [the verified package record](../../PLINKO/docs/ANDROID_SUGARFALL_v0.7.0.json) and [download links](../../PLINKO/BUILD_LINKS.txt). Windows remains v0.6.1.
[Consolidated source validation](../../verification/crystal-area-20261103/validation.json) passed 2,494 checks across 21 suites. The [art and persistence record](../../verification/crystal-20261103/art-persistence-manifest.json) contributes 253 checks, including 175 renderer checks over 40 captures at 720×1280 and 450×800. Native atlas roles, common damage frames, quiet map composition and the paired-candy multiplier were reviewed in the actual Windows renderer. Physical Android contrast, performance and touch feel remain open. The 216 synthetic pacing runs inform initial tuning but are not human playtesting.
