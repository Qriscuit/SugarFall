# Sugarfall — trailer V1

Prepared 4 November 2026. This V1 puts Mabel’s editable SVG paper cutout **in front of fresh recorded gameplay**, replacing the earlier proposed separate cut-paper set. The game continues behind her catches and shuffle. She returns beside the title over dimmed gameplay at the end.

Open [review.html](review.html) to watch the local MP4, or use the [verified private Drive copy](https://drive.google.com/file/d/1olcdBUARwr1_XZ5S-3P9O1_UPAUd02nn/view?usp=drivesdk). The final review export is [Sugarfall-Trailer-V1-Review.mp4](../../outputs/trailer-v1-20261104/Sugarfall-Trailer-V1-Review.mp4): **30 seconds, 1080 × 1920, 60 fps, H.264/yuv420p video and AAC 48 kHz stereo audio**. Exact file size: **10,060,724 bytes**. Local SHA-256: `4d655d21c88b6e9ce2a025a2bff084494c1f8746ce3ed0b90068a82c7fe7417b`. Drive metadata was read back; no remote checksum claim is made.

## Source files

| Folder / file | Purpose |
| --- | --- |
| [mabel/README.md](mabel/README.md) | True-vector SVG puppet, poses, props, editable groups and transparent PNG derivatives |
| [mabel/mabel-puppet.svg](mabel/mabel-puppet.svg) | Editable master with named head, hair, face, arms, legs, apron, tray and doughnut groups |
| [mabel/preview.html](mabel/preview.html) | Pose contact sheet |
| [capture/run_capture.py](capture/run_capture.py) | Isolated current-source public renderer capture setup |
| [capture/trailer_capture.gd](capture/trailer_capture.gd) | Fixed-step motion capture using inherited production drawing and physics |
| [audio/build_mix.py](audio/build_mix.py) | Rebuild the music/SFX/Foley mix |
| [audio/resync_cues.py](audio/resync_cues.py) | Map game effects to captured events and edit decisions |
| [audio/README.md](audio/README.md) | Original Foley and audio-production notes |
| [edit/assemble_v1.py](edit/assemble_v1.py) | Match cuts, camera crops, stepped Mabel overlays, falling paper props and title composition |
| [edit/review_video.py](edit/review_video.py) | Probe, full decode and review-frame extraction |
| [delivery.json](delivery.json) | Frozen final file and verified Drive metadata |
| [Production record](../../PLINKO/docs/store/TRAILER_V1.md) | Scope, evidence, source provenance and remaining publication checks |

The SVGs contain genuine vector paths, shapes and gradients, with no embedded raster images. PNG derivatives preserve transparency and are used by the video compositor. Mabel’s overlay uses stepped movement independently of the smooth game footage. The paper props and character are promotional foreground layers; the game’s balls and effects remain those recorded from its renderer.

## Evidence and review media

The capture generated eight clips and 2,292 frames at 60 fps: 38.2 seconds of raw footage. The edited trailer selects from those clips at normal speed. Captured states use isolated staged progression and wallets, real earned purchase APIs and a natural tray clear. No player profile was read or written.

- [Capture report](../../outputs/trailer-v1-20261104/gameplay/capture-report.json), [source hashes](../../outputs/trailer-v1-20261104/gameplay/source-evidence.json), [capture validation](../../outputs/trailer-v1-20261104/gameplay/capture-validation.json) and [contact coordinates](../../outputs/trailer-v1-20261104/gameplay/impact-trace.json).
- [Edit decisions](../../outputs/trailer-v1-20261104/edit-decision-list.json), [synced sound cues](../../outputs/trailer-v1-20261104/audio/cues-synced.json) and [mix report](../../outputs/trailer-v1-20261104/audio/mix-report.json).
- [Technical export checks](../../outputs/trailer-v1-20261104/qa/technical-validation.json) and [visual review](../../outputs/trailer-v1-20261104/qa/video-visual-validation.json). Re-run these checks when the exported file changes; earlier checks are evidence for their recorded export only.
- [Review-page media check](../../outputs/trailer-v1-20261104/qa/review-page-validation.json): the local page loaded the final 30-second 1080 × 1920 MP4 in Edge without page or media errors.

The existing Foley is original deterministic synthesis. The music is the user-supplied `AudioContent/Symphony 6 - beethoven cut - Sugarfall.wav`, source 0–30 seconds at normal speed, with a short duck around Mabel’s action and a final fade. The original music file remains unchanged and is excluded from source control. Its metadata identifies HALIDONMUSIC / The Best of Beethoven / 2025; permission for public use is unverified. V1 is a private review, with no YouTube or Play publication.

This task changes trailer-production assets and tools. It does not alter the game’s runtime, build an APK, or establish physical-phone acceptance. Review pacing, Mabel’s scale and audio balance on a phone before the public trailer is finalized.
