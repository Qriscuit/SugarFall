# Sugarfall — trailer V4

Prepared 4 November 2026. V4 adds a left-side gameplay close-up, a real cream transition into a nearly completed upgrade map, and a tighter closing composition with sequential fades. Mabel’s approved greeting, catches and loaded exit are preserved from V3. Open [watch.html](watch.html) for the local review. No video upload is part of this revision.

Verified master: [Sugarfall-Trailer-V4-Review.mp4](../../outputs/trailer-v4-20261104/Sugarfall-Trailer-V4-Review.mp4), **13,809,414 bytes**, SHA-256 `d52e6ab4e73674a84a138cdf6495995b687d50ecc6ec4659191167acabcd43ce`. Full decode, AAC-to-mix comparison, independent visual reviews and desktop/mobile player checks pass. The final card remains visible at 29.8 seconds and the last frame at 29.983 seconds.

## Picture changes

The original Gelato shot at 7.2167–10.8167 now zooms from 1.00 to 1.45 toward the left wafer contacts. Its camera anchor is [288,900]; the actual rendered wafer center is [288,800.4]. Crop samples at the real source contacts 184/194 show the left copper rim and wafer impacts without HUD or launcher fragments.

The old sparse Feed purchase shot at 10.8167–14.4 is replaced by a fresh isolated renderer capture. It shows the actual Home Upgrades-button click, production cream wave and Gelato’s populated map. The staged legal campaign owns 56 of 62 ordinary nodes and earned Dual Shot; six terminal branch leaves remain affordable. The recording uses normal purchase APIs and touch/drag input, with zero player-profile IO. This is a separately staged late-campaign build, not the consequence of the preceding gameplay shot.

V4 reuses all 373 V3 Mabel overlay frames directly. Her 0.85-second wave, the three recorded handoffs at 17.3667 / 18.5167 / 18.9667 and loaded exit are unchanged. Prism, Jam and the final real peg/cup sequence keep their established timing.

The final card brings the tray within about 11 pixels of the wordmark’s visible bounds. Existing painted countertop, marble and flower artwork adds background detail. The background, title, tray, Mabel and button fade and interpolate into place in sequence, then hold still from 28.25–30.0. All generated lettering and character PNGs remain the approved V3 artwork.

## Review and PNG exports

| File | Purpose |
| --- | --- |
| [Storyboard](storyboard.md) and [timing](timing.json) | Edit decisions and implemented timing |
| [Production record](../../PLINKO/docs/store/TRAILER_V4.md) | Source, preservation and verification scope |
| [Capture notes](capture/README.md) | Real upgrade-map ownership, cream navigation and isolated profile evidence |
| [Ending source](ending/layout.html) | Native composition of the approved PNG layers |
| [Portrait closing PNG](ending/exports/sugarfall-end-card.png) | Revised final image |
| [Transparent landscape logo](ending/exports/sugarfall-logo-lockup.png) | Compact title, food and Mabel arrangement |
| [Wide banner](ending/exports/sugarfall-banner.png) | Revised background and composition |
| [Portrait transparent arrangement](ending/exports/sugarfall-portrait-lockup.png) | Alternate transparent export |
| [Original Imagegen prompts](../trailer-v3/prompts.json) | Approved source artwork and references |

## Reproduction and verification

The root `assemble.py` creates a new picture base from the verified existing gameplay, the left-camera shot and 215 frames of the new upgrade recording. `build_audio.py` preserves V3 game cues outside the replaced slot and all ten Mabel Foley cues, removes obsolete purchase cues and adds the recorded map tap plus an editorial cream wash. Ending accents follow the new layer timing. The supplied music remains at normal speed over 0–30 seconds; its performance is still a private reference pending publication clearance.

Render the ending with `ending/render_motion.cjs`, build the picture/mix, then run `assemble.py`, `verify.py`, `render_watch.cjs` and `finalize.py`. The final review format is 30 seconds / 1,800 frames, 1080 × 1920 at 60 fps, H.264/yuv420p with AAC 48 kHz stereo. Exact master identity and completed checks are frozen in [manifest.json](manifest.json).

The review video and intermediate verification artifacts live under `outputs/trailer-v4-20261104`. V3, production game source and player saves stay unchanged. No APK was required. Local media verification does not establish physical-phone acceptance or public publication clearance.

The ending renderer uses native canvas PNG encoding to keep all frames consistently RGBA. This corrects the initial export’s format-change timing reset; the failed initial master’s visual evidence is retained in `qa/ending-format-failure`, while the manifest binds all accepted checks to the corrected master above.
