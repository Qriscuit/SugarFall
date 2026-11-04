# Mabel — Sugarfall mascot

Decision recorded 4 November 2026. The user chose Mabel as Sugarfall's mascot and requested her in the store icon and banner, together with a character turnaround. The user also requested listing descriptions without fixed numbers of areas, levels or trays.

## Existing character and current role

The character identity reference is [mabel_welcome.png](../../data/art/host/mabel_welcome.png). [first_run_guide.gd](../../scripts/first_run_guide.gd) loads this portrait and presents Mabel's welcome, aiming instruction, coin collection and first upgrade guidance. [NEW_PLAYER_EXPERIENCE_GDD.md](../NEW_PLAYER_EXPERIENCE_GDD.md) records that implemented introduction.

Mabel's mascot status is approved. Her current gameplay presence remains the Bakery introduction and its guidance replay. A continuing companion role across areas is a proposed extension, not an implemented feature. The listing therefore says she helps the player get started.

## Character identity

- Brown eyes, warm skin, visible freckles and a friendly adult face.
- Chestnut hair swept into a loose curled bun, with face-framing curls.
- Mint-green collared dress with short puff sleeves.
- Ivory apron with copper fastenings, large lower pockets, a tied sash and small strawberry embroidery.
- Softly painted 2.5D forms, broad warm light and readable materials matching Sugarfall's food and interface art.

Preserve her age, facial proportions, hair silhouette and outfit when making a new pose. Do not add a chef hat or substitute a generic baker character. Make expressions and gestures readable at their actual display size.

The original portrait ends before the feet. The new turnaround proposes a below-knee mint skirt, apron hem and simple brown low shoes. These details complete the design for reference; they were not visible in the existing game portrait. Full-body production should use the selected turnaround consistently once accepted rather than inventing a new hem or shoe design in each asset.

## Store composition

The new [storefront-v2 review](../../../concept-art/storefront-v2/preview.html) contains the mascot icon, feature graphic, turnaround and revised copy. Exact generation prompts and technical export evidence belong in that folder's `prompts.json` and `manifest.json`.

For the icon, make Mabel's face the strongest element, preserve a readable bun silhouette, and use a recognizable treat to connect the character to the actual game. Essential details should survive a small display and adaptive icon masking. Export the full square without a decorative outer frame or pre-cut rounded corners.

For the feature graphic, keep Mabel recognizable while showing Sugarfall's bouncing-treat and peg theme. Keep the title readable and unobstructed. Treat the result as promotional illustration, not an in-game screenshot. Do not add ratings, awards, store badges, fixed content counts or unavailable feature claims.

The turnaround is a design reference. Keep all views at one scale with consistent facial identity, hair volume, proportions, garment lengths, pockets, straps and shoes. Any asymmetric detail, especially the strawberry embroidery and sash construction, must stay on the same anatomical side across views.

## Delivery scope

This mascot artwork task prepares store drafts and a character reference. It does not replace the original tutorial portrait, change runtime character behavior, replace the Android launcher, or establish phone acceptance. Review the final launcher and listing together when the new icon is integrated into a release build.

Daily challenges and expanded Mabel appearances remain separate proposed paragraphs in [planned-copy.md](../../../concept-art/storefront-v2/planned-copy.md). Keep them outside the main listing until their gameplay is built, integrated and verified. Existing RC2 desktop screenshots remain historical evidence and must be compared with the final Android release after later interface changes.
