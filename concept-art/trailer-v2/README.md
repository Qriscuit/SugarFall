# Sugarfall — Mabel and ending revision review

Prepared 4 November 2026. Open [watch.html](watch.html) for the V2 motion review, or [review.html](review.html) to compare the six painted Mabel source poses, the three real catch positions and two ending studies. V2 uses the painted keys in a stop-motion composition with separate carried-food layers and ending A. All 23 clean handoff frames passed visual review. The exact 30-second MP4 passed full decode, audio comparison and desktop/mobile review-player checks. The user chose to keep the video local; no Drive upload occurred. V1 remains unchanged.

The master is [Sugarfall-Trailer-V2-Review.mp4](../../outputs/trailer-v2-20261104/Sugarfall-Trailer-V2-Review.mp4), 11,489,931 bytes, SHA-256 `43e39e4b5a4f6a2586eb3b59082d80b3bb3910415981e99b64c23dea38537195`. [Manifest](manifest.json) · [Local delivery decision](delivery.json) · [Production record](../../PLINKO/docs/store/TRAILER_V2.md).

Mabel notices treats leaving the board, runs to collect them, catches the second during her recovery from the first, handles the third with a small confident adjustment, and leaves with the plate. Her original painted identity replaces the vector puppet. The source PNG plates remain empty so the actual treats can move on separate layers in V2. This is a promotional foreground sequence, not a new player-controlled game mechanic.

## Review files

| File | Purpose |
| --- | --- |
| [watch.html](watch.html) | V2 motion review player |
| [review.html](review.html) | Main responsive revision review |
| [Pose contact sheet](mabel-painted/contact-sheet.png) | Three-by-two view of all six new painted keys over a pale mint/cream background |
| [Pose sheet source](mabel-painted/poses.html) | Native browser composition used for the contact sheet |
| [Painted source PNGs](mabel-painted/source/) | Run in, brake, first catch, moving catch, easy catch and run out |
| [Art prompts](mabel-painted/prompts.json) | Built-in imagegen prompts and character references |
| [Catch proof](planning/catch-layout.png) | Marked real gameplay frames |
| [Compact catch data](planning/selected-catches.json) | Recorded source/edit times, positions and proposed handoff constraints |
| [Static first-catch blocking](planning/blocking-1.png) | Initial actor scale and plate registration; historical empty-plate study |
| [Static second-catch blocking](planning/blocking-2.png) | Initial recovery pose placement; historical empty-plate study |
| [Static third-catch blocking](planning/blocking-3.png) | Initial effortless pose placement at scale 0.50; V2 uses 0.55 |
| [Ending A](end-concepts/ending-catch.png) | Real cup catch into a painted cup/title finish |
| [Ending B](end-concepts/ending-tray.png) | Serving-tray finish; food layers need continuity adjustment |
| [Ending font evidence](end-concepts/validation.json) | Actual bundled Fraunces file and axes verified by browser rendering |

## Motion timing and continuity

The twin-launcher edit slot remains 16.200–20.617 seconds, using source 2.583–7.000. Mabel starts entering at 16.55, brakes at 17.13, catches at 17.3667 / 18.5167 / 18.9667, starts her loaded exit at 19.42 and is offscreen before 20.35, leaving the Prism shot clear. The rendered entry initially remains beyond the left screen edge; alpha is visible by 16.867. The exit has no remaining alpha by 20.333.

The selected items are two scoops and a small red fruit. Their centers are approximately (458, 1507), (443, 1511) and (549, 1514) in the 1080 × 1920 frame. The motion plate surface is around y = 1526, below the ball centers by their radii. Catch two continues the first recovery near the same position; catch three adds a modest reach right.

V2 uses six painted keys with stepped movement, plate anchors, catch compression/recovery, and separate carried-food sprites cropped from the actual game art. Pose 05 is scaled 0.55; the other keys use 0.50. This corrects its head-height drop when registered to the same plate surface. The two run keys are individual poses, not an alternating-leg cycle.

The original balls must stop appearing after their foreground handoff. A presentation-only clean draw pass removes the three selected ball IDs after contact while retaining their physics, peg hits, cup resolution and economy. Before that pass, the red fruit reappeared below the plate at source 324 / overlay 169 / edit 19.016667. The corrected composite removes that duplicate, and all 23 clean replacement frames now pass visual review. Sampled pose changes keep the three carried items registered to the plate through the exit. The source audit independently verifies unchanged ball states, events and peg counts.

V2 uses ending A: it connects directly to the final cup catch and uses the game's Fraunces face. Ending B remains an alternative study; replace its current variety display with the same two scoops and red fruit if it represents Mabel's collected plate. Mabel stays gone after her exit.

The full-body PNGs preserve transparency. The contact sheet places the unmodified source artwork over pale mint/cream for edge and silhouette review. The historical static blocking images retain empty plates and the initial pose 05 scale; watch the motion composition to assess the registered poses and carried food. The source keys are not a separated puppet rig.

Motion QA evidence is under `outputs/trailer-v2-20261104/qa/`: contact handoffs, pose registration, carried-food continuity, entry and exit. Page layout/link validation is under `outputs/mabel-rethink-20261104/review/` and covers this artwork packet only.
