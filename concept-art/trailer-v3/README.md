# Sugarfall — trailer V3

Prepared 4 November 2026. V3 adds Mabel’s greeting and a painted closing card based on the supplied banner. Open [watch.html](watch.html) for the local video review. The video remains local, following the user’s explicit delivery choice; no Drive upload is part of this revision.

The verified master is [Sugarfall-Trailer-V3-Review.mp4](../../outputs/trailer-v3-20261104/Sugarfall-Trailer-V3-Review.mp4), **11,778,126 bytes**, SHA-256 `f52779cd17ee736f710527b64da852e425dd13ea98bedd232e0ee1ce3222af87`. [Manifest](manifest.json) · [Production record](../../PLINKO/docs/store/TRAILER_V3.md).

## Action and artwork

Mabel enters after the real Feed purchase, stops to acknowledge the viewer, then turns toward the falling treats. Her greeting holds at 15.10–15.95 seconds. The recorded catches at 17.3667, 18.5167 and 18.9667 remain unchanged, followed by her loaded exit. All 209 overlay frames from 17.1333–20.6 are byte-identical to V2.

The new ending begins at 27.1 seconds. It uses separate painted PNGs for the cream-and-copper Sugarfall wordmark, food collisions, a new Mabel pose and the boxed “Play now” label. The closing illustration includes a doughnut and ice cream on her plate; the captured Gelato sequence remains two scoops and a small fruit. The title and button use generated artwork matching the banner, rather than replacing its lettering with a plain font.

| File | Purpose |
| --- | --- |
| [Storyboard](storyboard.md) and [timing](timing.json) | Greeting, recorded catches and closing-card plan |
| [Imagegen prompts](prompts.json) | New bitmap assets and their reference roles |
| [Wordmark](source/sugarfall-wordmark.png) | Reusable transparent cream-and-copper title |
| [Greeting pose](source/mabel-hello.png) | New painted wave pose |
| [Closing pose](source/mabel-end.png) | New painted Mabel with a serving plate |
| [Collision artwork](source/food-collision-board.png) | Banner-style food impacts |
| [Play now box](source/play-now-button.png) | Separate painted call to action |
| [Ending layout](ending/layout.html) | Native composition of the unmodified PNG layers |
| [Portrait PNG](ending/exports/sugarfall-end-card.png) | Finished closing-card composition |
| [Transparent landscape logo](ending/exports/sugarfall-logo-lockup.png) | Title, collision art and Mabel without a backdrop or CTA |
| [Transparent portrait lockup](ending/exports/sugarfall-portrait-lockup.png) | Alternate tall arrangement |
| [Landscape banner](ending/exports/sugarfall-banner.png) | Complete wide composition with Play now |

The source PNGs are generated with the built-in Imagegen tool. Their existing alpha channels are preserved. Native browser composition scales, positions and animates these layers; it does not repaint the source artwork. The original V2 assets and master remain unchanged.

## Video and audio

The edit reuses `outputs/trailer-v2-20261104/picture-base-clean.mp4` exactly as its picture input. It contains the already-verified 23 drawing-only food handoff replacements; the original physics, damage, spawn timing and rewards remain unchanged. No new game capture or live game code changes are required.

The supplied music stays at normal speed, source 0–30 seconds. All 105 recorded game cues are retained from V2. Soft steps follow the earlier entrance and turn; the three catch cues keep their timing. The closing food impact and button settle follow the ending animation. The source music performance remains a private reference pending publication clearance.

## Reproduction and verification

Run `assemble.py --prepare`, then `build_audio.py` after the ending’s `audio-cues.json` is frozen. Render `mabel/render_motion.cjs` and `ending/render_motion.cjs`, then run `assemble.py`, `verify.py` and `render_watch.cjs`. The renderer uses the local portable FFmpeg, bundled Python environment and Edge/Playwright. The final format is 30 seconds, 1080 × 1920 at 60 fps, H.264/yuv420p and AAC 48 kHz stereo.

The final master and verification files are under `outputs/trailer-v3-20261104`. Full decode passes with 1,800 video frames and no errors. The decoded AAC matches the V3 mix with correlation 0.99945997 and no clipping. Desktop and narrow-layout player checks pass; all linked artwork loads. Greeting and catch-overlay parity checks confirm the 0.85-second hold and preservation of the approved catch animation. Exact file identity and final visual acceptance evidence are frozen in [manifest.json](manifest.json). A local review export does not establish physical-phone acceptance or public publication clearance. This revision changes trailer assets only and does not require an APK rebuild.
