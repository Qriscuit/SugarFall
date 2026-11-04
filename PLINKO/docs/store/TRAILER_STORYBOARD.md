# Sugarfall — music-linked trailer storyboard

V1 follow-up, 4 November 2026: the user changed Mabel's insert to a foreground SVG cutout over continuing game footage. The recorded and delivered [Trailer V1](TRAILER_V1.md) implements that direction. The timed proposal below is retained as design history; its separate paper-set insert is superseded.

Prepared 4 November 2026. This is the production plan for a **30-second portrait Google Play trailer**. The [interactive review](../../../concept-art/trailer-storyboard-v1/preview.html) links the supplied music to reference frames, candidate cuts and sound cues. [storyboard.json](../../../concept-art/trailer-storyboard-v1/storyboard.json) is the timing source. No trailer footage or finished Mabel animation has been recorded by this planning work.

The opening shows an already-falling doughnut and a readable peg hit. Match cuts change the treats, pegs and board around the moving ball. Longer holds show aiming and an upgrade's result. Mabel enters once for a brief balancing joke, then returns beside the final title. Her presence in the store icon and banner already introduces the character; the opening can concentrate on play.

## Music and timing

The local reference is `AudioContent/Symphony 6 - beethoven cut - Sugarfall.wav`: stereo 44.1 kHz, 16-bit PCM, **34.412925 seconds**. The supplied filename identifies the cut; its composition has not been acoustically verified. The review uses source **0–30 seconds at normal speed** and offers the full source for comparison. The original WAV is unchanged, linked locally and excluded from source control and distribution.

Amplitude and spectral-attack analysis found useful candidate edits at 3.646, 7.221, 10.820, 14.396 and 17.972 seconds. These are measured transients, **not verified score bars, a confirmed tempo or listening evidence**. Keep them as starting points for the motion edit. There is a measured quieter passage around 13.05–13.45 and a steep existing fade after roughly 29 seconds. The final mix can taper the low remaining tail during the last 0.3 seconds of a 30-second export.

| Edit time | Picture and purpose | Music / sound cue |
| --- | --- | --- |
| 0.000–3.646 | One clear Bakery bounce; feeder, pegs and cup stay recognizable. Gentle 5% push. | First featured contact near 0.720; one clear cookie hit. |
| 3.646–7.221 | Match cookie/doughnut to wafer/ice cream, then crystal/candy. Keep ball position and direction consistent. | Selected attacks at 3.646 and 5.399; optional contact around 6.339. Distinct material sounds. |
| 7.221–10.820 | Hold the Gelato curve turning, target and actual first contact in one readable view. | Let the smaller attacks pass without a cut. Launch and wafer contact remain audible. |
| 10.820–14.396 | Select and buy a real Feed node. Keep the purchase readable. | Selection at 10.820; purchase sketch at 13.200, within the quieter passage. |
| 14.396–17.972 | Show faster firing first; optionally reveal a separate already-earned twin setup around 16.208. | Return to play at 14.396. A Feed purchase must not appear to grant Dual Shot. |
| 17.972–20.619 | Cut-paper Mabel catches one doughnut, receives two more and shuffles backward to balance the tray. | Proposed landings at 17.972, 18.843 and about 19.760; paper rustle and two small shoe taps. |
| 20.619–24.172 | Real Crystal board before and after collecting the Prism; hold its actual duplication. | Return at 20.619; proposed collection at 21.293. One distinct Prism cue. |
| 24.172–27.237 | Optional brief Jam Burst, then the chosen final board. Last peg and cup catch provide the payoff. | Capture targets near 26.587 for the peg and 27.028 for the cup. Clear space around the final clink. |
| 27.237–30.000 | Sugarfall title with Mabel steadying the same tray and giving a small nod. | Quiet settle tap; hold through the existing music fade. |

The plan allocates **24.590 seconds / 81.97%** to actual gameplay or game UI and **5.410 seconds** to the Mabel insert and end card. This is planned screen time, not a measured completed video. Mabel's main insert lasts **2.647 seconds**; her final appearance starts at **27.237**.

## Build in this order

1. **Capture the gameplay first.** Record sparse Bakery; matching real cookie, wafer and crystal contacts; Gelato aim-to-hit; an earned Feed purchase and its faster result; optional separate earned twins; natural Prism collection and duplication; a busy board and real final clear/cup catch. Keep 1–2 seconds of handles around each action. Choose contacts that fit the edit rather than changing physics or adding balls in compositing.
2. **Assemble a rough edit with this source music.** Match position, direction and ball size at the cuts. Start around the normalized impact anchor `x=50%, y=48%`, then adjust the crops to the captured shots. Check that aim → result, purchase → faster cadence and pickup → duplication remain understandable with sound muted.
3. **Build Mabel's short pose family.** Use the [approved identity and turnaround](MABEL_MASCOT.md) and the new [CATCH / BALANCE / SETTLE pose concept](../../../concept-art/trailer-storyboard-v1/source/mabel-insert-pose-board.png) as design references. Production still needs a neutral tray hold, first catch, surprised lean, two shuffle poses and balanced settle/nod. A layered puppet may reuse body parts. Add one serving tray, doughnut props and a simple handmade set. Preserve the face, bun, apron and front sash construction. This promotional insert stays visually distinct from the real game.
4. **Animate and add sound.** Gameplay output is 1080 × 1920 at 60 fps; Mabel uses 10–12 stepped pose updates per second. Keep music, game effects and Mabel Foley on separate editing tracks. Prepare the final mix at 48 kHz, while retaining the untouched 44.1 kHz reference. Use existing effects sparingly; add food landings, shoe taps, paper rustle and the tray-settle sound.
5. **Review the export and prepare publication.** Watch on a phone with sound on and off. Check readable crops, preview-to-contact continuity, truthful ball counts, no fixed content-count claims, and a stable final title. Keep the title free of install prompts and unavailable feature claims. Verify the music recording's publication permission before release.

## Production status

| Item | Current state | Required next work |
| --- | --- | --- |
| Timed storyboard and source analysis | Prepared for review | Listen through the review and refine candidate edits against motion. |
| Gameplay frames shown in review | Historical RC2 desktop stills | Fresh capture from the selected current build; later UI changes make the old stills unsuitable as final trailer shots. |
| Capture harness | Existing still-capture setup | Add frame sequences, scripted gestures and event timestamps. The existing harness disables audio/input; it does not already record trailer sound or video. |
| Game SFX | Existing launch, peg, cup, upgrade, Prism and ability WAVs | Optional timing sketch can audition them; final footage determines synchronization and mix levels. |
| Mabel, props and Foley | Character reference and a new CATCH / BALANCE / SETTLE pose-board concept | The concept sheet is not a transparent puppet, separated rig or animation. Build those production assets, serving tray/doughnut layers, handmade set and new Foley. |
| End card | Composition planned | Prepare the portrait wordmark/Mabel layout and settle/nod motion. |
| Music publication | Metadata names HALIDONMUSIC / The Best of Beethoven / 2025; permission unverified | Use as a private planning reference. Verify a licence for the recording or produce a fresh permitted recording before publication. |
| Play upload / physical-device review | Open | Complete final export checks and publication setup; this storyboard establishes neither. |

The [existing capture harness](../../../verification/storefront-20261104/store_capture.gd) supplies `prepare()`, `simulate()` and `capture()` with fixed-step simulation and an isolated public renderer. Its [launcher](../../../verification/storefront-20261104/run_capture.py) documents isolation and source-parity checks. Preserve those protections when extending it for motion capture.

Google Play supports portrait preview video, may autoplay it muted for up to 30 seconds, recommends actual experience early and suggests at least 80% representative content. The published preview uses a public or unlisted, embeddable YouTube video with ads disabled and no age restriction. [Google Play preview-video guidance](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en). The musical work and a particular sound recording have separate rights. [U.S. Copyright Office explanation](https://www.copyright.gov/engage/musicians/).
