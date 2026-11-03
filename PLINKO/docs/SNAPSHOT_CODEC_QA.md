# Snapshot codec stress QA

Verified 23 October 2026 UTC using Godot 4.6.3 stable (7d41c59c4), headless Linux.
This is automated game-state evidence, not Android physical-device, operating-system process-death, or human usability validation.

## Reproduce

From the v0.3 project directory:

```sh
bash tests/run_codec_stress.sh
```

The wrapper resolves this project relative to its own location, creates fresh temporary XDG data/config/cache directories, runs `tests/codec_stress.gd`, and removes only those temporary directories on exit. Set `GODOT` to an alternate Godot executable if required. No original-project or Lab paths are used. Test game instances have `testing=true` and never enter the scene tree, so normal save/audio/lifecycle setup is not invoked.

## Verified output

```text
CODEC_STRESS campaign_runs=36 trial_runs=3 samples=8460 malformed_checks=175 rng_boundary_checks=11 float_tolerance=0.000000001
CODEC_STRESS flags={ "negative_hp": true, "negative_spawn": false, "negative_combo": true, "negative_pickup": true, "shards": true, "time_cap": true, "last_half_second": true, "zero_life_pickup": true }
CODEC_STRESS failures=[]
```

The 8,460 checkpoints comprise:

- 36 campaign simulations: all 12 boards with baseline, mid-level, and maximum upgrade/loadout configurations. Checkpoints are sampled every 10 fixed 1/60-second steps; games run to their result or the 5,500-step safety bound.
- Trial boards 4, 8, and 12 using fixed trial upgrades, sampled every 30 steps for up to 1,500 steps each.
- One live checkpoint while the End Shift confirmation is open.

Each checkpoint follows capture → full-precision JSON stringify → JSON parse → strict validation/decode. Every persisted runtime field is compared recursively. Numeric scalar differences must be strictly below 1e-9; Vector2 values, strings, flags, and integer values must match. RNG seed/state strings are exact, and four subsequent integer draws from detached original/restored generators must match at every checkpoint. This tolerates Godot's observed approximately one-ULP JSON float conversion without accepting altered gameplay counters or vector positions.

The fixture observed overkill negative peg HP, expired negative combo/pickup clocks, splitter shards, the 10-second bonus cap, the final half-second before timeout, and a tapped pickup with zero life awaiting removal. It did not naturally reach a negative spawn clock, so that path is not claimed as stress-tested here.

The 175 malformed-input checks replace every root field with null, a boolean, an empty object, NaN, and infinity; all are rejected. Eleven RNG boundary cases cover valid signed 64-bit endpoints and zero, plus overflow/noncanonical strings; all produce the expected acceptance or rejection without integer-overflow engine errors.

## Scope and identity

This harness validates serialization, decoded state fidelity, schema checks, and RNG continuation. It does not replace the separate save/load, result-collection, campaign/trial restoration, reduced-motion, or UI integration suites. It does not simulate an Android process being killed.

- Snapshot schema: 1.
- Codec SHA-256: `1b17a693402bbf0f1ed48384051badd1518150614d56598fd3901dd8dff21c71`.
- Board/economy content fingerprint: `a88a3da9476285561653461a75683f1b03e846d59e0cf88657dcb42cb7eccb19`.
- Fingerprint input: exact bytes of `data/board_design.json`, immediately followed by exact bytes of `data/economy.json`.

Changing game logic, authored content, or engine behavior can change the reported checkpoint count. A nonempty failures list or nonzero runner exit code is a failure, not a new baseline to accept silently.
