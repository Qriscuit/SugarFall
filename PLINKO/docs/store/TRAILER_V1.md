# Sugarfall — trailer V1 production record

Prepared 4 November 2026. The user changed Mabel’s presentation from a separate cut-paper scene to an **SVG cutout acting in front of recorded gameplay**. V1 implements that foreground treatment, with the game continuing behind her action and behind the dimmed final title composition.

The [local video review](../../../concept-art/trailer-v1/review.html) plays [Sugarfall-Trailer-V1-Review.mp4](../../../outputs/trailer-v1-20261104/Sugarfall-Trailer-V1-Review.mp4). The format is **30 seconds, portrait 1080 × 1920 at 60 fps, H.264/yuv420p video and AAC 48 kHz stereo**. The [private Drive copy](https://drive.google.com/file/d/1olcdBUARwr1_XZ5S-3P9O1_UPAUd02nn/view?usp=drivesdk) was verified by metadata readback. This is private review delivery, with public publication and phone acceptance still open.

Frozen file: **10,060,724 bytes**, local SHA-256 `4d655d21c88b6e9ce2a025a2bff084494c1f8746ce3ed0b90068a82c7fe7417b`. Technical decode/probe checks and targeted review of the final opening seam and falling paper props passed. Decoded AAC correlation with the source mix was **0.9994957**, with peak **0.7813** and no clipping. The Drive readback verifies metadata, not a remote byte checksum. [Delivery record](../../../concept-art/trailer-v1/delivery.json).

## Picture and character

The edit follows the music-linked storyboard’s sequence: readable Bakery play, material match cuts, Gelato aiming, a real Feed purchase and its result, a separate earned twin-launcher build, Prism duplication, Jam Burst, a real final peg and cup catches. Camera crops align recorded contact positions for the material cuts. Gameplay runs at normal speed.

Mabel starts entering at approximately **17.55 seconds**, catches and balances one → two → three doughnuts, then shuffles and settles before leaving at approximately **20.62**. Her poses change with stepped movement while the captured game stays smooth. She returns at approximately **27.23–30.00** beside the title over dimmed game footage. Falling paper doughnuts support the catch action. Those foreground props are visually distinct from the game’s balls.

The [Mabel SVG set](../../../concept-art/trailer-v1/mabel/README.md) includes an empty-tray pose, one- and two-catch poses, balance, alternate shuffle, settle, a master puppet and a separate doughnut prop. All essential art uses editable vector paths, shapes and gradients; no raster images are embedded. Named groups keep head, hair, face, eyes, freckles, arms, legs, dress, apron, tray and each doughnut separate. Checked transparent PNG derivatives are used for video compositing. [Asset validation](../../../concept-art/trailer-v1/mabel/asset-manifest.json).

## Fresh gameplay capture

Eight clips supply **2,292 frames / 38.2 seconds** of current-source footage at 1080 × 1920 and 60 fps. Capture uses an isolated, nondebug Windows export with the public feature. Production drawing and physics are inherited; the fixture controls inputs and stages progression and wallets. It does not add gameplay balls or draw replacement effects. Source-parity checks passed and profile IO remained zero.

Recorded evidence includes:

- A real Feed purchase, **Feed 0 → 1**, with wallet **150 → 112**, followed by its firing result.
- A natural Crystal Prism offer and real collection, with **4 → 8** live balls.
- An earned twin-launcher build with **10–33** live balls during its captured clip.
- Natural Jam Burst contacts and a legal upgraded Bakery tray clear, with the actual last peg, following cup catches and result state.

The separate twins shot does not imply the ordinary Feed purchase grants Dual Shot. The captured twin state retains the real earned unlock and Power-reset rules.

[Capture report](../../../outputs/trailer-v1-20261104/gameplay/capture-report.json) · [Source evidence](../../../outputs/trailer-v1-20261104/gameplay/source-evidence.json) · [Capture validation](../../../outputs/trailer-v1-20261104/gameplay/capture-validation.json) · [Recorded contact positions](../../../outputs/trailer-v1-20261104/gameplay/impact-trace.json).

## Music and effects

V1 uses the supplied `AudioContent/Symphony 6 - beethoven cut - Sugarfall.wav`, source **0–30 seconds at normal speed**. The filename identifies the supplied cut; no acoustically verified composition claim is added. Music is ducked modestly around Mabel’s action and faded during the final 0.3 seconds. The original source file remains unchanged.

The sound mix maps recorded game events through the actual edit decisions. Sparse selection keeps **105 game cues** plus **seven original Foley cues**, with collisions, catches and launches spaced to avoid a continuous noisy layer. Mabel’s food landings, shoe taps, paper movement and tray-settle effects are original deterministic synthesis. Her Foley pans toward the right foreground placement.

Captured-event synchronization places Feed purchase near **13.0167**, main Prism collection near **21.2833**, Jam Burst near **24.3667** and the final peg near **26.5667 seconds**. The mixed WAV is 30 seconds at 48 kHz stereo, with peak approximately 0.798 and no clipped samples. Final AAC/export verification remains tied to the frozen delivery file.

[Synced cues](../../../outputs/trailer-v1-20261104/audio/cues-synced.json) · [Mix report](../../../outputs/trailer-v1-20261104/audio/mix-report.json) · [Reproducible mixer](../../../concept-art/trailer-v1/audio/build_mix.py) · [Event resync tool](../../../concept-art/trailer-v1/audio/resync_cues.py).

## Review and publication status

| Item | State |
| --- | --- |
| V1 picture, SVG foreground and sound assembly | Built, exact-file checked and delivered to the private Drive folder. |
| Game footage | Fresh current public Windows renderer, with isolated staged state and normal gameplay APIs. |
| Physical-phone review | Open; renderer capture does not establish phone appearance, playback or audio acceptance. |
| Music recording | Metadata names HALIDONMUSIC / The Best of Beethoven / 2025. Permission for public use remains unverified; use this version as a private review. |
| YouTube / Google Play publication | Not performed. |

Review the opening’s clarity, material cuts, purchase-to-result sequence, Prism before/after, Mabel’s scale and animation, and the final title with sound both on and off. The copy avoids fixed content counts and unavailable-feature promises. Google Play supports portrait preview video and recommends showing the actual experience early; it may autoplay muted. [Google Play preview-video guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en).

The earlier [music-linked storyboard](TRAILER_STORYBOARD.md) remains the planning record. The new [production folder](../../../concept-art/trailer-v1/README.md) contains the capture, audio, SVG and edit sources. Runtime game files and player saves were not modified by this trailer work.
