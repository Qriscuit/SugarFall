# Trailer V1 audio

`build_mix.py` renders a local, private 30-second review mix at 48 kHz stereo, 16-bit PCM. The provided Beethoven performance is linked from `AudioContent/Symphony 6 - beethoven cut - Sugarfall.wav`; it is not included in this source folder. Its metadata names HALIDONMUSIC / The Best of Beethoven / 2025. Public-use permission for that particular performance remains unverified.

The source plays from 0–30 seconds at its original speed. Music gain is 0.90, with a smooth 3.35 dB reduction during Mabel's main overlay and a short final taper from 29.7 to 30.0 seconds. Selected existing game effects and new Foley occupy separate cue events before summing. The final mix retains headroom; the build verifies duration, peak, clipping and the unchanged original music hash.

## Rebuild

From the repository root, run the workspace Python interpreter with:

```text
concept-art/trailer-v1/audio/build_mix.py
```

The default portable FFmpeg path is `tools/ffmpeg-9.0.2/ffmpeg-9.0.2-essentials_build/bin/ffmpeg.exe`. Use `--ffmpeg <absolute-path>` for a different installation. FFmpeg's official download page links the Gyan Windows builds; the downloaded portable archive was checked against the publisher's SHA-256 before use. The tool is not installed system-wide or included in the game.

Use `--cues <file.json>` to replace the event list after the captured footage is edited. The file can be an array or an object containing `events`. Each event has `time`, repository-relative `file`, `gain`, `pan`, `label` and `type` (`game_sfx` or `original_foley`). The mix writes its actual cue list and source hashes beside the output so the final edit can be reproduced.

The V1 mix uses actual capture-event timing rather than the initial storyboard placeholders. Run `resync_cues.py` first; it maps `clip.json` events through `outputs/trailer-v1-20261104/edit-decision-list.json`, then creates `outputs/trailer-v1-20261104/audio/cues-synced.json`. Pass that file to `build_mix.py --cues`. Peg hits and breaks are spaced by at least 0.25 seconds, cup catches by 0.5 seconds and launches by 0.8 seconds. One game sound is retained per frame, with breaks preferred over hits and Prism/upgrade/Jam cues preserved. Runtime pitch options are retained. Game events stop before the branded ending; Mabel's right-side Foley remains independent.

## Original Foley

The four WAVs in `foley/` are authored for Sugarfall with deterministic synthesis and no external samples:

- `food_landing.wav`: a soft low impact for each doughnut arriving on Mabel's tray.
- `shoe_step.wav`: a small scuff and body tap for her balancing steps.
- `paper_rustle.wav`: filtered noise with several short creases for the cutout movement.
- `tray_settle.wav`: a damped, light ceramic/metal tap for her final steadying gesture.

The random seed, oscillators, envelopes and filters are defined in `build_mix.py`. Rebuilding reproduces the Foley files. These sounds are trailer assets; this task does not replace the game's runtime audio.

## Local outputs

The private review mix is written to `outputs/trailer-v1-20261104/trailer-v1-mix.wav`. Its report and editable cues are in `outputs/trailer-v1-20261104/audio/`. The original performance, resampled reference and mix stay outside source control. Root's final video mux uses the mixed WAV after checking capture-event timing.
