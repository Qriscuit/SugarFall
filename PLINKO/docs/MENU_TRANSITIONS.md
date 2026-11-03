# Shared cream-wave menu transitions

3 November 2026 · Built, integrated and verified in desktop/runtime checks. Physical-phone acceptance remains open. This design record does not itself announce an APK delivery.

The menu polish uses one upward-moving white-cream wave across Bakery, Gelato Garden and Crystal Candyworks. The shared motif connects the three dessert areas while keeping their individual background art intact after each change. No area-specific repaint is required.

## Artwork and source

The runtime asset is [`res://data/art/transitions/cream_wave.png`](../data/art/transitions/cream_wave.png): the native 1536×1024 RGBA output from the built-in ImageGen tool. [The provenance record](../../concept-art/cream-wave-v1/sources.json) contains the exact prompt, source path, generation method and project path. Its pixels are copied without editing. The decorative upper cream crest and the runtime's opaque white coverage are separate: the generated alpha alone is not the guarantee that the old page is hidden.

Use white cream with soft pearl-gray folds, broad curling shapes and no text, icons or area-color wash. The final UI labels, button states, prices and gameplay remain live. The asset is cached with the presentation resources rather than decoded during every navigation action.

## Page changes and transactions

[`page_transition.gd`](../scripts/page_transition.gd) presents a 0.62-second upward wave. The shared `mode` setter in [`main.gd`](../scripts/main.gd) begins the effect before assigning the new mode, so the user's navigation action and any legitimate transaction still take effect immediately through their existing logic. The effect does not defer a purchase, payout, save or area entry. The last rendered page image is retained for presentation while the logical destination is already active.

The first half retains that outgoing image under a rising crest and solid-white body. At the midpoint the body fully covers the actual viewport, including safe-area extensions. The outgoing image is then omitted. A vertically flipped crest and white body move upward during the second half, revealing the destination from below. The opaque body guarantees coverage; translucent artwork pixels are decorative rather than the mechanism hiding the old page. The native upper `1536×768` region is drawn at a width-derived uniform scale, with its body join at source y=520. The source PNG is unchanged. If the image is unavailable, the controller still draws an opaque procedural wipe.

The controller routes presentation by both the old and new modes. Home/Upgrades/Settings navigation, Pause/Resume, non-Home launches and ordinary commerce navigation retain the cream wave. Home → Play uses the tray morph described below. Play/Pause → Result and the Result/bonus-confirmation/test-ad chain are immediate modal changes without cream. Studio startup retains its cream reveal even when the saved destination is a pending result. Collecting a result returns to Home with the normal menu wave. Assigning the same mode starts nothing. Several synchronous menu mode changes keep the original outgoing image and elapsed animation time while updating the destination; they do not capture an intermediate page or restart the wave.

While the wave is active, page input is consumed and gesture state is canceled. Ball physics, run duration, spawn timing, RNG advancement, ad play time, checkpoint cadence, guide advancement, map movement and coin feedback do not advance behind it. The completion frame stays blocked, so an unusually long render delta cannot be charged to the newly revealed run. Ordinary UI debounce and short note timers are not gameplay clocks and may settle normally.

Reduced Motion changes pages immediately; enabling it during a wave finishes and releases the outgoing image. Focus loss, backgrounding and closing settle presentation, pause the initialized logical run when applicable, and use the existing save path without persisting animation progress. Loading/restoring a save bypasses the wipe and restores its paused run. No transition fields are added to the campaign or checkpoint schemas.

Home Play and tapping the Home tray use the restored 0.42-second [`run_transition.gd`](../scripts/run_transition.gd) entrance in production. The exact preview peg positions and tray bounds interpolate to the gameplay board; cups rise and the dispenser slides into position. One run is initialized and saved before the animation. Its physics, RNG, timer, spawn delay, guide and coin presentation remain held until the equipment settles. No cream wave covers this entrance and no second animation follows it. Back can interrupt the morph into Pause without restarting the run. Reduced Motion enters the settled board immediately.

## Result windows

Campaign and Trial results are centered cream windows over darkened, frozen gameplay. The dim layer covers the actual full viewport, including expanded aspect ratios and safe-area margins. The existing area panel skin, coin dish, timer and piece icons are reused. Payout comparison, reward availability, Collect/Back-to-trials hitboxes and existing input delay remain authoritative; outside taps and Back cannot silently discard a pending reward. Reward confirmations stay in their existing modal flow, and test-ad completion returns to the same result without a cream wipe. Run and visual elapsed time remain frozen beneath the window.

Just-finished results retain the exact in-memory board and equipment state. Pending-result saves contain reward/history metadata but no board pose, so reopening one after a restart shows the area's empty tray, cups and dispenser beneath the window. It does not invent surviving pegs, change a payout or extend the save schema. Claim-once behavior and Trial campaign restoration remain unchanged.

## Related interface preferences

- Home **Play** and **Upgrades** use the existing runtime play triangle and three-node upgrade mark beside their centered labels. Button bounds and touch targets stay unchanged.
- Settings places its two-line heading on a readable cream plaque above its existing controls.
- Floating damage numbers use their existing light outline, color, lifetime and motion, without the beige rectangular backing. The earlier v0.7.1 backing is historical and superseded by the user's preference.

These choices are part of [the current art direction](ART_DIRECTION.md). They reuse existing icon/panel materials and add no balance rules.

## Verification and remaining acceptance

The current routing and result-window revision passes [163 focused assertions](../../verification/screen-polish-20261103/page-qa-final/page-transition.log), covering all three areas, the restored Home morph, timeout/clear/early results, frozen board/RNG/visual time, claim-once, reward/automatic-ad modal chains, Trial wallet restoration and startup revealing a pending result. [Nine related regression suites](../../verification/screen-polish-20261103/regression-final/summary.json) add 879 passing assertions across mobile/safe-area input, resume, navigation, entrance, onboarding, final-ball settlement, result history and monetization. These fixtures use in-memory or verified isolated profiles. Multi-aspect renderer review is recorded separately under `verification/screen-polish-20261103`; these results do not claim physical Android execution.

The evidence below records the earlier v0.7.2 menu implementation. Its cream geometry and native-art provenance remain relevant; its all-routes-cream launch/result behavior has been superseded by the revision above.

[Renderer review `visual-final`](../../verification/menu-polish-20261103/visual-final/screens/preview-summary.json) passed **331 assertions with zero failures**, producing **62 desktop captures** at 720×1280 and 450×800 across Bakery, Gelato and Crystal. It includes Home, Settings, damage feedback with/without Reduced Motion, wave phases, the revealed upgrade map and extended safe-area coverage. The renderer fixtures reported zero player-profile IO. [Rendered source hashes](../../verification/menu-polish-20261103/visual-final/screens/rendered-source-hashes.json) identify that historical capture set and its v0.7.2 runtime source.

Manual review inspected Gelato's 450×800 Home, Settings, damage and 25%/75% wave frames, plus an independent review of the same ten Bakery/Crystal frames. The button symbols and labels have clear internal padding, both heading lines fit the Settings plaque above Sound, and damage labels use outlines with no rectangular backing. At 25% the old Home remains only above the rising cream; at 75% the destination appears beneath the departing cream. No clipped labels or uncovered mixed-page leak was seen in those sampled frames. The ten independently reviewed Bakery/Crystal images are byte-identical in the final source-matched rerender; final Gelato wave and Bakery Settings were also rechecked. Representative images: [Bakery Home](../../verification/menu-polish-20261103/visual-final/screens/bakery-home-450x800.png), [Bakery Settings](../../verification/menu-polish-20261103/visual-final/screens/bakery-support-450x800.png), [Crystal damage](../../verification/menu-polish-20261103/visual-final/screens/crystal-damage-450x800.png), [Crystal 25%](../../verification/menu-polish-20261103/visual-final/screens/crystal-wave-25-450x800.png), [Crystal 75%](../../verification/menu-polish-20261103/visual-final/screens/crystal-wave-75-450x800.png).

[Historical v0.7.2 validation](../../verification/menu-polish-20261103/validation.json) passed **1,143 checks with zero failures**: 715 related regressions, 90 focused page-transition checks, 331 renderer assertions and 7 native-art checks. The [90-check page suite](../../verification/menu-polish-20261103/page-qa-03/page-transition.log) covers immediate mode writes, chained transactions, coverage geometry, canceled input, all-area run/clock/RNG preservation, the completion-frame guard, Reduced Motion, save/load and background/close behavior. The v0.7.2 runtime hashes match that page suite and renderer capture set. These fixtures use isolated or in-memory saves; they are not human sessions.

Physical-phone smoothness, readability and touch comfort remain a user playtest. On the phone, move between Home, Upgrades and Settings; launch, pause and resume a run; try a rapid extra tap during the wave; background and return; and repeat with Reduced Motion. Verify that the displayed timer and wallet do not jump because of the animation, and that the destination becomes usable after it settles.
