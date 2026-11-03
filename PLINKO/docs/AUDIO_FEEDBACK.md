# Action sounds

3 November 2026 · delivered in v0.7.7-preview under CHG-039; phone-listening acceptance remains open.

Sugarfall now has short feedback for navigation, purchases, gameplay, abilities and results. Bakery uses soft wooden taps and crumb pops, Gelato uses rounded ceramic plinks, and Crystal uses clear candy chimes. The pack contains **33 original WAVs for 25 event types**. Launch, peg hit, peg break and cup catch each have three area versions; the other 21 cues are shared. No continuous gameplay music or ambience is introduced. The studio heartbeat remains a separate startup sound.

| Actions | Events |
|---|---|
| Navigation and decisions | `ui_tap`, `ui_back`, `ui_confirm`, `ui_error` |
| Purchases and run flow | `upgrade`, `ability_purchase`, `run_start`, `pause`, `resume` |
| Area materials | `launch`, `peg_hit`, `peg_break`, `cup_catch` |
| Pickups and signature abilities | `pickup_appear`, `time_pickup`, `prism`, `jam_splash`, `twin_transform` |
| Specials and results | `special_split`, `special_impact`, `special_ricochet`, `countdown`, `tray_win`, `tray_loss`, `collect` |

The game requests a cue when the associated action actually happens. Purchase success follows the committed purchase; failed purchases use an error cue. A pickup notice plays once when the offer appears, and collection has a distinct sound. Dragging, redrawing and restoring a save do not replay those actions. Main retains the existing combat RNG calls while translating the old `tone()` call sites to the cached material cues; sound selection consumes no gameplay RNG.

## Bank and lifecycle

[`game_audio.gd`](../scripts/game_audio.gd) is a reusable Node with `play_event(event, area, options)`, `set_enabled`, `set_suspended`, `advance`, `stop_all` and `stop_gameplay`. `prepare()` runs once and creates six persistent `AudioStreamPlayer` voices. The optional `intensity` is clamped to 0–1 and `pitch` to 0.9–1.1; nonfinite inputs use safe defaults. Unknown events remain silent and unknown material areas fall back to Bakery.

The 33 cached, mono, 24 kHz PCM16 streams contain **441,600 PCM bytes** (431.25 KiB), excluding Godot resource/playback overhead. Streams and player nodes are never constructed per hit. Godot manages its internal playback objects. There is no playback queue, so muted or background events cannot accumulate and play later.

At most three voices are occupied by ordinary gameplay, leaving room for decisions and rewards. High-priority ability/pickup/result cues can replace a weaker sound; a peg hit cannot steal an important cue. Shared event cooldowns bound contact storms: launch 140 ms, peg hit 55 ms, break 80 ms, cup catch 120 ms and pickup appearance 600 ms. The host advances this presentation clock independently of gameplay. Main stops old tails before pause/result cues and updates suspension for application backgrounding and focus loss. Sound off stops active voices and blocks future events.

Every source peaks near 0.28 full scale. Controller gains range from −17 to −7 dB at default intensity, preserving headroom when voices overlap. These choices are conservative starting values; phone speakers and listening comfort still need human assessment.

[`audio_catalog.gd`](../scripts/audio_catalog.gd) contains paths only and creates no streams. Startup uses its 33 paths for bounded asynchronous warmup. Loading the gameplay bank waits for actual resource readiness without making the loading scene synchronously preload the complete sound pack.

## Original generation and reproducibility

[`generate_feedback_audio.py`](../tools/generate_feedback_audio.py) composes each clip offline using damped harmonic/inharmonic resonances, short filtered noise and quiet reflections. All oscillators start with a short onset and end in a tapered, zero-valued tail. Noise uses a local deterministic seed derived from the filename. It uses no external recording, game sample or borrowed melody, and never runs during gameplay.

[`GAME_AUDIO_ASSETS.json`](GAME_AUDIO_ASSETS.json) records the generator hash and every native WAV's hash, format, duration, peak and RMS. Godot imports retain lossless PCM, mono playback and disabled looping. Native sources live in `data/audio/feedback/`; editing a sound means changing the generator specification and regenerating its recorded source, not synthesizing during an action.

## Verification and listening limits

The isolated controller suite passed **91 checks** using the actual Godot mixer and Dummy output. All 33 clips produced measurable audio; the exercised six-voice overlap peaked at **0.541** full scale. Sound off/background stop reached mixer silence, foreground produced no stale replay, and playback retained the fixed stream/player bank. This is mixer verification, not proof that a person has listened on a phone.

Updated production-path fixtures passed **11 Prism checks** and **85 cache checks**. Prism collection plays the dedicated cached chime once, preserves its gameplay grant, and remains silent when muted/testing. Cache checks cover 2,000 resource lookups and 40 paced playback requests, fixed identities, voice bounds and unchanged gameplay RNG. The fixture never attaches the game's `_ready()` path or reads a player profile.

The exact reports are `verification/game-audio-20261103/controller-02/mixer/audio-results.json`, `verification/game-audio-20261103/integration-01/audio-cache.json` and the sibling logs. The root integration/flow/regression evidence is recorded separately in `AUDIO_FEEDBACK_VALIDATION.json`; test scopes should not be added into one historical total.

The six-second [audition](../../verification/game-audio-20261103/controller-02/mixer/feedback-demo.wav) is captured from the actual controller mixer: tap, back, upgrade; Bakery/Gelato/Crystal hits and breaks; time, jam, Prism, Twin; win and collect. A [complete cue reel](../../verification/game-audio-20261103/controller-02/mixer/feedback-mixer.wav) is also available. Neither file establishes physical listening acceptance. Phone loudness, masking during busy play, comfort and background behavior remain open checks. The [v0.7.7 package](ANDROID_SUGARFALL_v0.7.7.json) verifies the exported audio assets/scripts and is delivered through the existing private Drive file.
