# Painted closing card

This version uses separate Imagegen PNG layers for the cream-and-copper Sugarfall wordmark, food striking biscuits, Mabel's new closing pose, and the boxed **Play now** call to action. The composition follows the banner supplied by the user. Native browser composition positions the artwork without substituting browser text for generated lettering.

`layout.html` renders the final portrait card. `#lockup` arranges the title, collision art and Mabel as a compact landscape logo without a backdrop or CTA, preserving transparent space around the illustrated logo. `#portrait-lockup` supplies the alternate portrait arrangement. `#wide` arranges the layers as a landscape banner with backdrop and CTA. `render.cjs` saves the four export PNGs in `exports/` and records dimensions, image crop bounds and output hashes.

Exports: `sugarfall-end-card.png` (1080 × 1920), `sugarfall-logo-lockup.png` (1920 × 1080, transparent), `sugarfall-portrait-lockup.png` (1080 × 1920, transparent), and `sugarfall-banner.png` (1920 × 1080). The title and CTA remain separate source PNGs and can also be reused individually. The wide CTA sits below Mabel's apron and beside her shoes, without covering the character painting.

`motion.html` shares the same composition. `render_motion.cjs` generates 174 frames at 1080 × 1920 and 60 fps, covering edit time 27.1–30.0 seconds. The food vignette and title settle first, Mabel follows, and Play now appears by relative0.83 seconds. Everything then holds still for readability. The renderer checks that the final hold is pixel-stable.

The original source PNGs stay unchanged. Alpha bounds are used only to fit artwork into its composition boxes. The background combines the game's existing marble texture with a mint/lavender color wash; the generated collision vignette supplies the themed food and tray artwork. No runtime game files are changed.
