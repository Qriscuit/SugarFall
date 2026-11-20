# Sugarfall feature graphic and seven screenshots

5 November 2026. The user requested seven game screenshots and a faithful recreation of their Mabel banner at exactly **1024 × 500**, preferably below 15 MB.

The banner was adapted with the built-in `image_gen.imagegen` tool using `source/banner-reference.png` as the edit target. The exact prompt is saved in `prompt.txt`. The original generated image is retained as `source/banner-generated.png`. `export_banner.cjs` performs only final Lanczos sizing and lossless RGB PNG encoding; it does not change the artwork.

Final banner: `exports/sugarfall-feature-1024x500.png`, **828,221 bytes**, 24-bit RGB PNG. SHA-256: `146af74e24da0ca6a3d629ca332deb209228316834b240ed93faf2e304db4b3d`.

The seven screenshots are new, uncomposited captures from the current production renderer, through an isolated public, nondebug Windows export. Gameplay and earned ability APIs run normally with staged campaign progress and wallets. No player saves are accessed. The seventh capture shows a real Crystal ×2 pickup duplicating five live balls to ten. These are not physical Android screenshots.

Local delivery lives at the repository root in `outputs/storefront-20261105/`: the banner, `screenshots/`, `review.html`, evidence, a manifest and a ZIP containing the eight images. Open `review.html` for individual downloads and the full set. No Drive or Play Console upload is part of this task.

The screenshot fixture and reproduction instructions are in `verification/storefront-20261105/`. Screenshot production evidence is beside the PNGs. The prior six-image capture set from 4 November remains historical evidence.

Run `export_banner.cjs` followed by `package.cjs` with the bundled Node runtime to recreate the banner export and local review. The browser review requires no network access or external dependencies. Generating a new banner requires the built-in image tool and the saved prompt/reference.

This is a marketing asset task. It does not change production game content or create a new APK. Compare the exact intended Android release with these current-workspace captures before store submission.
