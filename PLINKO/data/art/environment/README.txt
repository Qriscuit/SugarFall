BAKERY ENVIRONMENT ASSETS / revision 1 / 2026-10-23

Five individual PNGs generated with the built-in image_gen tool:
home_counter.png       Opaque quiet ivory worktop for Home
play_counter.png       Opaque pale honey-wood worktop for active gameplay
upgrade_counter.png    Opaque quiet parchment/counter for Recipe Trails and menus
journey_backdrop.png    Opaque bakery worktop beneath the winding level route
bakery_landmark.png    Transparent small bakery building above level 12

The four backgrounds are full bleed, with broad pale low-contrast interiors and
clipped edge props. They share upper-left light, softly painted 2.5D materials,
warm cream, muted mint and fine copper accents. No background contains a baked
route, node, board, button, text, price or gameplay object. The route, medallions,
state marks, labels, tray and floating controls are drawn separately at runtime.

scripts/environment_art.gd caches textures and normalized source bounds once.
Backgrounds use an aspect-preserving cover crop across the physical viewport,
including space outside the logical safe area. The landmark preserves aspect
ratio and genuine alpha. Its bakery sign contains no lettering. This building
is scenery, not a next-area action; area transitions/resets are not implemented
by this art and navigation pass.

Original full-size generated PNGs are retained without offline pixel editing.
Godot import limits are 1536px for backgrounds and 512px for the landmark, with
mipmaps and alpha-edge correction. regions.json uses full bounds for opaque
backgrounds; the landmark uses alpha >=128 bounds plus 4px source padding.

Exact production prompts:
../../../../concept-art/bakery-world-assets-v1/prompts.txt
Per-asset generated sources, project paths and reference roles: sources.json
Approved composition references: ../../../../concept-art/home-journey-v1/
Related blank UI pieces: ../ui/README.txt
Material/layout rules: ../../../docs/ART_DIRECTION.md
Review evidence: ../../../../verification/bakery-world-v1/

Review both 720x1280 and 450x800 and a simulated phone safe area. Background
details must remain subordinate to food, live numbers and controls. Preserve
the quiet center, natural prop cropping and shared light direction when making
new backgrounds. Do not add flavor text or instructions to scenery.
