# v0.4 actual UI QA • 23 October 2026

Executed the actual game through the authorized cloud Linux Godot GUI, using a separately named QA copy and save. This is not physical Android or Windows testing.

- Original toy-machine home, active tray, results and branching map rendered without visible clipping at 450×800; initial map also inspected at 415×738.
- Fresh 10-second center-idle attempt failed with 0 pegs broken but earned 22 credits from useful damage/catches. Normal collection banked all 22.
- Clock tier 1 cost 15, leaving 7 coins and adding 0.5 seconds. Retry with one aim drag earned 56 and broke 3 pegs. Normal collection produced 63.
- Core tier 1 showed damage 1→1.5 and ordinary peg hits 6→4, cost 40 and left 23. Repeated click did not purchase another tier.
- Map drag, node selection, locked future node, recenter and separate purchase action worked. Dragging did not spend coins. Existing sequential upgrade prerequisites remain; no new cross-branch prerequisite was added.
- Warm panels, dark labels, shaded colorful pegs/balls and persistent peg boundaries were readable. Final branch contrast correction inspected. Screenshots show actual runtime, not concept art.
- Setup→Fresh Test Profile opened a separate 0-credit profile with 10.0 seconds and 6 hits/peg. Labels appeared on home, map and result. Actual test attempt earned and collected 22 independently.
- Return to Main restored exactly 23 credits, Core1 and Clock1 (10.5 seconds, 4 hits/peg). No reset/uninstall was used. Synthetic tests separately cover restart, pending results, active checkpoints and failed selector writes.

Final automated suites: 16 smoke, 112 independent, 99 resume, 16 v0.4 balance, 45 map and 61 profile assertions, all passing. Resume suite includes 96 deterministic cross-board checkpoint cases. These are engineering assertions, not human playtests.

Limits: no physical phone, Windows runtime, touchscreen gesture-bar/cutout or external player study. No claim of final narrow-device accessibility or human completion-time validation. The earlier v0.3 all-board GUI playthrough does not substitute for replaying every newly balanced v0.4 board manually; twelve-board v0.4 coverage is automated.
