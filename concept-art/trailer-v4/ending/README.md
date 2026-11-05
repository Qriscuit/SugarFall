# V4 closing composition

The food tray now sits directly below the approved Sugarfall wordmark. Its visible top is about y446, close to the title's visible bottom at y435. V3 left about139 pixels between those bounds. Mabel is larger in the lower left, and the boxed Play now is larger in its own space to the right.

The background reuses painted game assets: a mint baking countertop with window shadows, a flour jar, flour dust and linen; a faint marble layer; and restrained garden flowers at the lower edge. The title, face, plate and button remain clear. The source wordmark, collision vignette, Mabel and CTA PNGs are the approved V3 Imagegen assets and remain unchanged.

## Exports

`render.cjs` renders the editable native `layout.html`/`card.js` composition to four PNGs in `exports/`:

- `sugarfall-end-card.png`: portrait1080 ×1920 closing image.
- `sugarfall-banner.png`: landscape1920 ×1080 with the same tighter composition and backdrop.
- `sugarfall-logo-lockup.png`: transparent landscape arrangement, without backdrop or CTA.
- `sugarfall-portrait-lockup.png`: transparent portrait arrangement, without backdrop or CTA.

## Motion

`render_motion.cjs` produces174 frames at1080 ×1920/60fps, covering edit time27.1–30.0. Every layer has one eased translation and fade; no repeated bounce or scale pulse is added.

| Layer | Relative arrival | Edit arrival |
| --- | --- | --- |
| Background | 0.00–0.24 | 27.10–27.34 |
| Wordmark | 0.12–0.42 | 27.22–27.52 |
| Food tray | 0.35–0.68 | 27.45–27.78 |
| Mabel | 0.62–0.95 | 27.72–28.05 |
| Play now | 0.90–1.15 | 28.00–28.25 |

The complete image holds still from28.25 through30.0. `audio-cues.json` locates quiet settling accents at27.72 and28.20. Render validation records the actual layer states and checks final-hold pixel stability. The ending is an illustrated marketing composition; the gameplay and Mabel's earlier greeting/catch/exit section are outside this source's scope.

All motion and export PNGs use native canvas PNG encoding with consistent RGBA storage, including opaque frames. This prevents a mid-sequence pixel-format change from resetting FFmpeg's timing. The pixel content is unchanged from the approved composition. `verify_motion.py` checks all174 formats, the transparent first frame, all105 static hold frames, and parity between the last frame and closing PNG.
