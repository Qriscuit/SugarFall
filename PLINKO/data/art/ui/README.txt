BAKERY UI ASSETS / revision 4 / 2026-10-23

Fourteen individual transparent PNGs generated with the built-in image_gen tool:
panel.png        Parchment information card, mint frame, copper fittings
button_mint.png  Primary action plaque
button_cream.png Secondary action plaque
timer.png        Kitchen timer / remaining time
coin.png         Brass donut token / credits
node.png         Ceramic saucer / compact icon controls
upgrade_tile_green.png  Affordable Recipe Trails tile / blank enamel face
upgrade_tile_red.png    Unaffordable Recipe Trails tile / blank enamel face
upgrade_tile_cream.png  Owned Recipe Trails tile / blank ceramic face
upgrade_parchment.png   Blank map parchment / no text or baked paths
level_badge_cream.png   Blank unlocked/completed level medallion
level_badge_mint.png    Blank selected level medallion
level_badge_muted.png   Blank locked level medallion
level_selector.png     Blank Home area/level plaque

All images are used by scripts/ui_art.gd and loaded once. The original full-size
PNG is preserved; Godot imports limit panel to 1024px, buttons to 512px, icons to
256px, upgrade tiles and level medallions to 512px, map parchment and the level
selector to 1024px, all with mipmaps and alpha-edge correction.
regions.json contains normalized alpha >=128 bounds with
4px source padding. No offline pixel editing was applied to generated outputs.
Panels and wide buttons use nine slices; circular controls use the node sprite.
Food and icon images retain their natural aspect ratio. Labels, counters and
state/navigation marks are live Godot text/vector shapes, never baked into art.

Exact prompt set: ../../../../concept-art/ui-bakery-v1/prompts.txt (workspace)
Recipe Trails prompts: ../../../../concept-art/recipe-trails-assets-v1/prompts.txt
Home/journey prompts: ../../../../concept-art/bakery-world-assets-v1/prompts.txt
Final medallion edits: ../../../../concept-art/bakery-world-assets-v1/badge-variant-prompts.txt
Source provenance: sources.json in this folder.
Reusable style guide: ../../../docs/ART_DIRECTION.md
Bundled font details/licenses: ../../fonts/README.txt

Review at both 720x1280 and 450x800. Keep calm centers and preserve rounded
corners when adding skins. Do not stretch a wide pill into a square control.

Recipe Trails fills the viewport beneath floating controls. It now uses the
separate environment/upgrade_counter.png background; upgrade_parchment remains
a fallback whose plain interior is sampled without the decorative edge. The
original asset stays intact. Its labels, price plaques,
plus/minus/check state marks and copper paths are live rendering. Only the tile
surfaces and parchment are baked art. Tiles retain proportions. Three variants
share a silhouette; red and cream were generated as targeted green-tile edits.
No source PNG pixels were modified offline. The map contains no flavor text or
gesture hints. Reduced Motion suppresses bounce/stretch but retains state cues.

The level journey uses the three blank scalloped level medallions, with live
numbers, locks, completed checks, the selection rim and donut marker. Mint marks
selection, cream marks unlocked levels and muted oatmeal marks locked levels.
Completed levels carry a check unless currently selected; locked levels cannot
be selected. Red remains reserved for unaffordable upgrades. Cream is the source
asset for targeted mint/muted edits, keeping a shared silhouette and proportions.

The Home selector uses nine slices, with a live area/level label, path icon and
chevron. Play/Upgrades and the small menu reuse existing skins. Home uses only
the tray and actual cookie roles. On Play the board grows into gameplay while
cups rise and the hopper appears, using cached food sprites. Coin labels show
whole amounts; fractional gains accumulate internally. No concept screenshot
fragments are used as controls. Home/journey art introduces no currency, stars, energy
or area-reset behavior. Four cohesive page backgrounds and one bakery landmark
live in ../environment; see that folder's README.txt and sources.json.
