# Mabel food handoff clean pass

This fixture supplies 23 supplemental frames for the trailer. It uses an isolated copy of the frozen V1 capture project, not the current game workspace. It preserves the original 120 Hz simulation, exact input, warmup, upgrade purchase, events, ball paths and cup collection. The three food sprites become carried foreground layers at their recorded contact positions.

Only drawing changes: after each selected ball reaches the plate, its sprite is hidden until its natural cup collection. The full original ball array is restored before every simulation step. This is trailer compositing; these are not untouched gameplay recordings.

| Ball ID | First hidden source frame | Last source frame | Frames |
| --- | --- | --- | --- |
| 1 | 225 | 233 | 9 |
| 7 | 294 | 301 | 8 |
| 15 | 321 | 326 | 6 |

The first hidden frame is contact-inclusive because the separate carried-food layer starts on that frame. Use the replacement JPEG where present and the original source JPEG otherwise. Do not replace any original source files.

Run `run_clean_pass.py` with the bundled Python environment. It copies the frozen project into `verification/mabel-rethink-20261104/clean-pass/project`, changes only that copy's entry scene, exports with the same nondebug public preset, and captures through the original renderer. All profile paths are isolated. `audit_clean_pass.py` verifies copied frozen resources and confines significant image differences to the selected sprites.

Output is `outputs/trailer-v2-20261104/gameplay/06-twin-clean`. `validation.json` records simulation/event checks; `source-hashes.json` records input/output hashes and per-frame image checks. `visual-comparison.png` shows source, clean and amplified pixel differences for seven representative frames, including the third food sprite at source frame 324.
