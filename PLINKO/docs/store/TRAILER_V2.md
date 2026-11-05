# Sugarfall — trailer V2

Prepared 4 November 2026. V2 replaces the rejected vector Mabel and Georgia title from V1. The approved game-led sequence remains, with the twins shot trimmed to a later part of the same recording so Mabel can catch three visible items.

The [video review](../../../concept-art/trailer-v2/watch.html) plays the new private review master. The [artwork review](../../../concept-art/trailer-v2/review.html) preserves the six painted keys, real trajectory evidence, initial placement studies and two ending concepts. V1 remains intact as an earlier revision.

## Mabel’s action

Mabel notices treats leaving the board, runs to collect them, catches the second during recovery from the first, makes a small adjustment for the third, and leaves with the plate. She does not return at the end.

The six PNG key poses match her original painted character design and have clean transparent edges. The built-in imagegen tool used the established welcome portrait and turnaround as references. [Prompts and references](../../../concept-art/trailer-v2/mabel-painted/prompts.json) are retained. The source plates are empty; the food travels on separate foreground layers.

| Action | Edit time |
| --- | --- |
| Run in, then brake | Approximately 16.55–17.37 |
| First pink scoop | 17.3667 |
| Second scoop during recovery | 18.5167 |
| Small red fruit, slight reach | 18.9667 |
| Leave with all three items | Approximately 19.42–20.35 |

Movement uses deliberately stepped cutout poses. Entry and exit use a held running silhouette with stepped position and a small vertical response. These six keys do not form an alternating-leg animation cycle. The third pose uses adjusted scale to keep her head registered while its plate meets the target.

## Real food handoffs

The twin clip retains output time 16.200–20.6167, with source frames 155–419 (2.5833–7.000 seconds). The three selected source contacts are frames 225, 294 and 321. Their recorded centers, velocities, texture crops, rotations and subsequent paths are saved in [food-handoffs.json](../../../concept-art/trailer-v2/planning/food-handoffs.json).

The foreground food starts at the recorded center, rotation and apparent diameter, then settles with the plate. A temporary hole in the actor overlay keeps an approaching recorded item in front of the plate until contact. Original game textures and their authored crop regions reproduce the pink scoops and small fruit.

The first composite revealed the original fruit below the plate after its handoff. A separate isolated presentation pass removes the selected item from drawing after contact while keeping the complete ball array for every simulation step. This is a documented trailer compositing pass. It changes no production game code, positions, collisions, damage, rewards, spawn timing or player saves. Replay parity and final visual checks are recorded beside the exported master.

## Ending and sound

Ending A begins at 27.1 seconds, dissolving from the recorded game catches into a painted cup close-up. A doughnut settles inside the cup at 27.62; the front lip occludes its lower half. The title appears at contact and holds still through the music tail.

The title uses the actual bundled Fraunces variable font with the game’s settings: weight 650, SOFT 70, optical size 36 and WONK 1. The native browser render verifies that this font loads. The [ending source](../../../concept-art/trailer-v2/end-concepts/motion.html) and font evidence are retained.

The supplied music remains at normal speed, source 0–30 seconds. Game sounds are remapped from recorded events to the revised edit; three food contacts, entry/exit steps and the closing cup have matching Foley. The new mix is checked for clipping, and the final decoded AAC is compared with that mix. Subjective phone listening remains a user review.

## Delivery and limits

The review master is 30 seconds, portrait 1080 × 1920 at 60 fps, H.264/yuv420p with AAC 48 kHz stereo. Exact file size, SHA-256, decode results and visual evidence are in [manifest.json](../../../concept-art/trailer-v2/manifest.json). The user explicitly chose to keep this video local; [delivery.json](../../../concept-art/trailer-v2/delivery.json) records that decision. No Drive upload or sharing change occurred.

This revision changes trailer production assets only; it does not require a new APK. The gameplay source is a nondebug Windows renderer, not a physical phone recording. Public publication is still pending clearance for the supplied music performance and final trailer acceptance.
