# Trailer ending composition studies

Prepared 4 November 2026. These two portrait stills replace the earlier dimmed-gameboard / Georgia idea for review. They do not modify the V1 video.

- [A — The last catch](ending-catch.png): choose a real cup catch from the footage, move into a close-up of the painted cup and doughnut, then let the correctly typeset title hold through the musical tail. This is the recommended direction because its final action comes directly from play.
- [B — The finished tray](ending-tray.png): a serving tray of doughnut, gelato and candy arrives below the title. This emphasizes the game's food variety and Mabel's serving task, with a slightly longer transition away from the recorded board.

Open [preview.html](preview.html) to compare both, or use the [contact sheet](contact-sheet.png). The clean PNGs are 1080 × 1920. The HTML is the editable composition source; [render.cjs](render.cjs) renders it with Edge and verifies the bundled font loads.

Both use `PLINKO/data/fonts/Fraunces-Variable.ttf`, with the same axes as `Fraunces-Display.tres`: `wght=650`, `SOFT=70`, `opsz=36`, `WONK=1`. The wordmark has normal proportions, no synthetic bold and no thick outline. [validation.json](validation.json) records the actual font file hash, loaded font face, variation settings and rendered image hashes.

All food, cup, tray and surface artwork comes from existing painted game assets. The aqua candy uses the upper-left region of Crystal's existing ball atlas. These are promotional end-composition studies rather than new gameplay screenshots. No Mabel re-entry, CTA, rating badge, fixed content count or additional copy is proposed.

For A, keep the cup catch as the final audible event, allow only a small food settle, and hold the title steady for roughly two seconds. For B, move the tray as one group and stop it before the last musical tail. The title should stay still in either version.

## Animated ending A

[motion.html](motion.html) implements the closing action with the same painted assets and Fraunces settings. [render_motion.cjs](render_motion.cjs) renders 174 native 1080 × 1920 PNG frames at 60 fps, lasting 2.9 seconds, into `outputs/trailer-v2-20261104/ending`.

The sequence is designed for edit time 27.1–30.0. The title remains hidden during the initial transition, the doughnut reaches the cup at relative 0.52 seconds / edit 27.62 seconds, then the title reveals over 0.26 seconds and stays still. A foreground copy of the cup masks the doughnut at the actual front lip, so its lower half settles inside the opening. There is one small food settle and no repeated pulse.

`window.renderEnding(seconds)` selects a deterministic render state. The completed output's `render-validation.json` records font loading, dimensions, frame count, contact timing and sampled motion positions. The original two concept PNGs above remain unchanged as the design comparison.
