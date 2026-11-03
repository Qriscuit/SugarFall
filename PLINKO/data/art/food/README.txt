FOOD ART ASSETS — gameplay pass, 23 October 2026

Fourteen individual PNGs generated with the built-in image_gen tool using the
approved kitchen gameplay concept as the style reference. Source PNG resolution
is preserved. All objects have transparency; countertop.png is opaque.

Projectiles: donut (normal), pomegranate (splitter), pumpkin (impact),
seed (split fragment), ricochet (orange slice).
Targets: cookie_normal, cookie_armored, cookie_prism, cookie_clock.
Environment: cup_cream, cup_gold, tray, hopper, countertop.

scripts/food_art.gd loads these as separate textures. regions.json contains
normalized visible source rectangles, measured from alpha >=128 with a 4px
margin, to exclude faint alpha specks outside each object's silhouette.
Update that rectangle when replacing an asset with different framing.

Godot import limits: 256px objects, 1024px tray, 1536px countertop; mipmaps on.
The .png.import files preserve these settings. No sprite atlas is required.
Cups are stretched to the existing board's layout. The tray uses three horizontal
slices to keep its side rails outside the playable area. Food hitboxes remain
circles: 9px normal, 6px seeds, and 11.25px pumpkins in 720x1280 game coordinates.

Exact generation prompts: concept-art/food-assets-v1/prompts.txt
(At the workspace root, outside the PLINKO project folder.)
Source reference: concept-art/food-theme-v1/01-gameplay-kitchen.png

Hopper revision 2 replaces hopper.png with a taller funnel and clearer copper
outlet, generated with built-in image_gen. Prompt and original backup are in
concept-art/food-assets-v2/ at the workspace root. Its updated visible bounds are
in regions.json. The game draws it inside a 112x112 box with aspect ratio preserved.
