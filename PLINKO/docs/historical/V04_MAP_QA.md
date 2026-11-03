# v0.4 upgrade-map input QA

Verified 2026-10-23 at 13:28 UTC using Godot 4.6.3 headless and isolated test data. The dedicated map suite passes **45/45 assertions**; the short-run/snapshot suite independently still passes **16/16** after map integration.

## Tested scope

- Primary touch selects a node without spending. Secondary touches are ignored.
- Drag pans without selection or purchase, including release over the purchase action.
- Locked future tiers and owned tiers cannot purchase. Successful purchase leaves the purchased node selected, so repeated taps cannot silently buy the next tier.
- Every one of eight branches: insufficient funds preserve balance, deliberate next-tier purchase deducts exactly the existing price, and maximum level cannot be exceeded.
- Zoom clamps at both limits; reset restores zoom, pan, and selection.
- Navigation delay and result-destination delay prevent unintended purchase.
- Safe-area position/scale transforms map touch input to logical node coordinates.
- Nodes clipped from rendering are not hit-testable.
- Leaving the map and application focus loss cancel an active drag gesture.

## Bugs reproduced and fixed

1. Purchase automatically selected the next tier, allowing an immediate second tap to purchase it. Fixed by retaining the owned node selection.
2. A node hidden by the drawing visibility region could still be selected. Hit testing now matches that region.
3. Leaving shop during a held gesture preserved the dragging flag. Navigation and focus loss now clear it.

All three failures were reproduced by the tests before fixes and passed afterward. Tests do not modify production scripts or economy data.

## Reproduction

Run `bash tests/v04_run_map_tests.sh`. It uses `tests/v04_map_runtime` for isolated XDG state. Run `bash tests/v04_run_tests.sh` for the separate sixteen-check short-run suite. Exclude runtime directories and generated logs from distribution.

Verified source hashes:

- scripts/main.gd: `8fb7bf9715ddd95e632c95d01977ac5766091c55a132a51c65f8d9b42a8bf367`
- scripts/upgrade_map.gd: `d713c8c3551ca4630086383f9cb53510f934a5bf4e63b6987432ffbceed1ea03`

This is synthetic event and state QA, not graphical approval, mouse-to-touch operating-system integration verification, physical Android device testing, or human usability evidence. Graphical review is separate.
