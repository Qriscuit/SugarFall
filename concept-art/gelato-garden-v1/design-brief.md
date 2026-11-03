# Gelato Garden — area 2 concept

23 October 2026. Proposed direction for Sugarfall, not yet implemented or approved as production art.

A lavender gelato parlor gives the second area a visibly different setting while retaining Sugarfall's sculpted food, warm upper-left lighting, cream ceramics, thin copper fittings and readable phone layout. Gameplay, the winding journey and the entry confirmation are separate concept images; none is a sprite sheet.

## Images

- [Gameplay](01-gelato-gameplay.png): wafer pegs, frozen scoops, fruit specials and sundae cups.
- [Level journey](02-gelato-journey.png): a full-screen waffle path and gelato kiosk landmark.
- [First entry](03-gelato-entry.png): the coin fee and meaningful reset consequences, with no flavor text or offers.

Generated with the built-in image-generation tool. Exact prompts are in [prompts.txt](prompts.txt); provenance is in [sources.json](sources.json). The live Bakery gameplay and journey screenshots were inspected to inform the written brief. Generated labels, object counts, spacing and level states are illustrative; production must draw live UI separately.

## Visual specification

| Element | Direction |
|---|---|
| Structure | Dusty lavender enamel replaces Bakery's structural mint; cream ceramic and copper retain the shared material family. |
| Palette targets | Vanilla #FFF7E8, lavender #B8A2CF, lilac shadow #8A729F, copper #B8753D, cocoa ink #443B32. Strawberry #D87388 and lemon #EDC553 belong mainly to food. |
| Functional color | Keep mint/green for available actions and affordable upgrades, red for unaffordable upgrades, cream for owned upgrades. Lavender is scenery, not a replacement for state colors. |
| Backgrounds | Quiet pale cream marble or lightly textured cream worktop. Lavender linen, waffle cones, berries and a serving spoon may be cropped at the edges. Clear central field; no decorative food mistaken for targets. |
| Normal drop | A small round strawberry gelato scoop with a shallow scalloped underside. Strong pink silhouette and enough side shading to separate it from cream. |
| Ricochet | A round yellow hard candy; readable circular highlight/swirl. |
| Splitter | Strawberry that releases three small red fruit pieces on its first qualifying impact. Keep this automatic. |
| Heavy | Dark chocolate bonbon, approximately 25% wider than a standard drop. Preserve the existing collision proportions. |
| Pegs | Circular waffle bites with broad waffle cells. Intact, chipped, cracked and crumbling PNGs; missing chunks remain legible at phone size. Chocolate coating identifies armor. Clock and bonus roles need distinct simple surface marks. |
| Collector | Five open sundae cups, cream front faces, lavender bases, restrained waffle sides; one gold cup. Mouths overlap the board and bodies sit below it. Live multiplier labels stay on plain faces. |
| Dispenser | Deep lavender/copper gelato feeder with a clear downward outlet. Preserve depth and aspect ratio; no flattened hopper. |
| Typography | Retain Fraunces and Nunito. Numbers and labels are runtime text, never part of production PNGs. |

Keep the current peg squash, cup bounce/tint, damage silhouettes, tap feedback, drag aiming and automatic specials. Home previews only the current pegs; cups and feeder appear during the established Play entrance. The final wafer stops spawning and existing food finishes landing before results.

## New content, not only a palette change

Author twelve area-local layouts. Early trays introduce wide wafer arcs and open lanes, middle trays combine offset rows and paired clusters, and later trays mix diagonals with a few chocolate-coated pegs. First-level damage and payouts must suit zero upgrades. Preserve a reachable first Feed purchase after roughly one ordinary attempt as a tuning target, not a guarantee before testing.

Use the existing eight upgrade roles and expanding Recipe Trails layout. New portraits follow the food mapping above. The first Feed tile appears alone; buying it reveals the immediate choices. No new manual power-up buttons, energy system, health rings or gesture instructions.

The previous Bakery simulation cleared its twelve trays quickly and spent most of the 2–3-hour target saving the exit fee. Gelato Garden needs its own playtests for first-clear time and later savings; a new background cannot solve that pacing issue. Do not claim a measured duration for this unbuilt area.

## Entering and returning

Recommended entry: clear Bakery's twelve trays, hold at least 400,000 Bakery coins, and have Gelato Garden content available. Show one confirmation with the title, fee on Enter, and these consequences:

- Upgrades restart
- Purchases stay
- Leftover coins stay in Bakery

Entry creates Gelato Garden at level 1, eight upgrade levels at zero, no equipped specials and zero Gelato coins. It preserves the completed Bakery, its old upgrades and any coins remaining after the fee. Example: 450,000 Bakery coins becomes 50,000 Bakery coins and 0 Gelato coins. Returning to an already opened area restores its local progress without another fee or another reset.

Remove Automatic Ads and Baker Toolkit stay owned and work in either area. Settings, trial history, lifetime run/reward IDs and the existing ad cooldown also survive. The current purchases are local test-service entitlements; this design does not imply cloud accounts or cross-device syncing.

The detailed reset/keep table, save migration, pending-purchase handling and acceptance tests are in [the progression proposal](../../PLINKO/docs/NEXT_AREA_PROGRESSION_DRAFT.md).

## Production handoff

After choosing the direction, generate separate transparent sprites, four damage states per peg family, non-distorted cups and feeder, blank UI skins, one isolated kiosk and four opaque backgrounds for Home/play/upgrades/journey. Keep one shared frame per damage family and put changing numbers, locks and selection marks in code. Review at 720×1280 and 450×800 before integration.

Area entry must be one atomic save operation: validate content, prepare the fee deduction and new area's state, save successfully, then present the new Home. Cancel, missing content or failed writes must not spend coins. Do not call the existing full-profile reset because it wipes permanent test purchases. Keep the released gate locked until content and these behaviors pass their tests.
