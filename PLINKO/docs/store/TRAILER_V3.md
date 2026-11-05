# Sugarfall — trailer V3

Prepared 4 November 2026. The user approved V2’s painted Mabel and gameplay, then requested a held greeting before her catches and a new illustrated closing image based on the supplied banner. V3 implements both changes. The video remains local, following the user’s delivery preference.

Open the [video review](../../../concept-art/trailer-v3/watch.html). The [storyboard](../../../concept-art/trailer-v3/storyboard.md) and [timing data](../../../concept-art/trailer-v3/timing.json) record the sequence.

## Greeting and preserved catches

Mabel enters after the real Feed purchase has finished, so she does not cover the buy action. She holds a friendly wave toward the viewer for 0.85 seconds, lowers her hand and turns toward the falling treats. There is no speech bubble or extra copy.

| Action | Edit time |
| --- | --- |
| Enter | 14.55–15.10 |
| Hold greeting | 15.10–15.95 |
| Turn and step toward the landing point | 15.95–16.45 |
| Prepare for the catch | 16.45–17.37 |
| Existing scoop, scoop and fruit catches | 17.3667 / 18.5167 / 18.9667 |
| Leave carrying the food | 19.42–20.35 |

The held greeting contains 51 identical overlay frames. All 209 aligned overlay frames from 17.1333–20.6 are byte-identical to V2. V3 also reuses V2’s verified clean gameplay base, including its brief drawing-only food handoffs. Physics, rewards and game source remain unchanged.

## Painted logo and closing card

Five new PNG assets were made with the built-in Imagegen tool: the cream-and-copper Sugarfall wordmark, Mabel’s greeting pose, a new serving pose, a biscuit-collision vignette and the boxed Play now button. The user’s banner supplies the lettering and material direction; the established portrait and turnaround preserve Mabel’s identity. [Exact prompts and references](../../../concept-art/trailer-v3/prompts.json) are retained.

The closing Mabel holds a doughnut and ice cream and gestures toward the call to action. The illustrated board shows a doughnut striking a fluted biscuit and a scoop striking a waffle biscuit. This is an illustrated closing card; the recorded Gelato catches remain the two scoops and fruit from V2.

The generated lettering is used directly as PNG artwork. Native browser composition arranges the independent layers without replacing the title or button with browser text. The title is the largest element, the collision scene occupies the middle, and Mabel and Play now have separate space below it. A short layered arrival settles into a stable final hold.

| Export | Format |
| --- | --- |
| [Closing card](../../../concept-art/trailer-v3/ending/exports/sugarfall-end-card.png) | 1080 × 1920 PNG |
| [Compact logo with Mabel and food](../../../concept-art/trailer-v3/ending/exports/sugarfall-logo-lockup.png) | 1920 × 1080 transparent PNG |
| [Wide banner](../../../concept-art/trailer-v3/ending/exports/sugarfall-banner.png) | 1920 × 1080 PNG |
| [Portrait transparent arrangement](../../../concept-art/trailer-v3/ending/exports/sugarfall-portrait-lockup.png) | 1080 × 1920 transparent PNG |

The single-word logo, button and character PNGs are also available separately in [source](../../../concept-art/trailer-v3/source/). These are new marketing assets; existing store exports and runtime artwork are preserved.

## Sound and verification

V3 preserves all 105 game sound cues from V2. Entry and turning footsteps follow the greeting timing; the three existing catch sounds remain at their verified contact times. The closing image has quiet impact and button-settle accents. The supplied music stays at normal speed over source 0–30 seconds, with no clipping in the new mix.

The exact review master is checked for 30 seconds / 1,800 frames, 1080 × 1920 at 60 fps, H.264/yuv420p and AAC 48 kHz stereo. Full decode, final AAC-to-mix comparison, sampled visual review and desktop/mobile player checks are recorded in [the production manifest](../../../concept-art/trailer-v3/manifest.json). Phone review and subjective audio acceptance remain the user’s review.

No game runtime or player save changes were made, so no APK was rebuilt. No video upload or public publication is part of this revision. Publication clearance for the supplied music performance remains unresolved.
