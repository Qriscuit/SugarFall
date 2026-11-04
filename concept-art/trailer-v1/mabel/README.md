# Mabel SVG trailer cutout

Prepared 4 November 2026. These are original editable vector drawings based on Mabel's existing game portrait and approved turnaround. All essential character and prop art uses SVG paths, shapes, gradients and internal vector references. There are no embedded raster images, external assets, fonts or scripts in the SVGs.

Mabel keeps her warm adult face, brown eyes, freckles, swept chestnut bun, mint puff-sleeve collared dress, ivory strawberry apron, copper fastenings, front sash and brown shoes. The drawing simplifies the existing painted character into a paper-cut style for a promotional foreground layer.

## Assets

| SVG / matching PNG | Use |
| --- | --- |
| `mabel-present` | Empty tray before the first landing |
| `mabel-catch` | One doughnut |
| `mabel-catch-two` | Two doughnuts after the second landing |
| `mabel-balance` | Three doughnuts, surprised lean and first backward shuffle |
| `mabel-balance-step` | Same upper body and stack, alternate leg positions for the second shuffle |
| `mabel-settle` | Three doughnuts, stable tray and relaxed smile |
| `mabel-puppet` | Editable master with named component groups |
| `doughnut-prop` | Separate pink doughnut for a brief foreground landing animation |

Every Mabel pose has a `0 0 600 1000` viewBox. Its corresponding PNG is a transparent 600 × 1000 render. The standalone doughnut is 140 × 110. The ivory cut edge and soft shadow are part of the transparent silhouette; no rectangular background is included.

The `puppet.json` file records pivots, the feet anchor and logical group IDs. The master separates head, hair, facial expression, eyes, freckles, arms, legs, dress, apron, waist tie, tray, hands and individual doughnuts. Pose files share the same coordinates and SVG definitions so the cutout can be swapped without changing its canvas alignment.

## Trailer use

Overlay Mabel on real gameplay, keeping the game visible behind her. A starting placement for 1080 × 1920 is `x=580`, `y=1090`, height `800`; adjust the lower-right placement against the chosen gameplay crop. Her complete 600 × 1000 canvas then occupies 480 × 800 pixels. Use stepped movement at 12 updates per second, independently of the 60 fps gameplay.

Proposed catch progression is one → two → three at edit times 17.972, 18.843 and 19.760. Alternate the two balance poses for the shuffle, then use `settle`. The same family can return beside the final title from 27.237 seconds. These are promotional actions and do not alter game physics or present Mabel as an in-game character mechanic.

`build_svg.py` regenerates the authored vectors. `render.cjs` uses local Microsoft Edge through Playwright to export transparent PNGs and the contact sheet. The SVG filter supplies the paper edge and shadow; use the checked PNG exports for the video compositor if a different SVG renderer does not support that filter. `preview.html` is the local pose contact sheet.

Browser rendering and XML/alpha checks are recorded in `render-verification.json` and `asset-manifest.json`. The art was visually inspected at full-body and overlay scale. The original game portrait and runtime assets were not changed.
