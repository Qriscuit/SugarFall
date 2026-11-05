# Sugarfall — trailer V4

Prepared 4 November 2026. V4 keeps Mabel’s approved greeting, food handoffs and exit. It adds a left-side gameplay close-up, a real cream transition and populated upgrade map, and a tighter ending whose layers fade and move into place one by one. The video remains local.

Open the [video review](../../../concept-art/trailer-v4/watch.html). The [storyboard](../../../concept-art/trailer-v4/storyboard.md), [timing](../../../concept-art/trailer-v4/timing.json) and [manifest](../../../concept-art/trailer-v4/manifest.json) record the edit and verification evidence.

## Gameplay and upgrade reveal

The Gelato shot at 7.2167–10.8167 seconds now moves from a wide view to a left-side close-up. Zoom rises from 1.00 to 1.45 around camera anchor [288,900]. The real wafer contacts at edit 9.6833 and 9.85 stay in frame, with the left copper rim visible and the HUD and launcher clear of the close-up. Corrected board-transform coordinates locate that wafer at [288,800.4].

The old sparse Feed purchase shot at 10.8167–14.4 is replaced by a fresh isolated public renderer capture of Home’s Upgrades button, the cream wave and Gelato’s upgrade map. The staged tray-12 campaign owns 56 of 62 ordinary nodes and has earned Dual Shot through the production purchase API. Six terminal branch leaves remain affordable. This demonstrates a late-campaign upgrade build; it does not imply the preceding gameplay caused those purchases.

The recorded click occurs at source 0.10 seconds / edit 10.9167. The production wave takes 0.62 seconds and fully covers the screen before revealing the map. An actual touch/drag gives the map a short 72-pixel pan. The first 215 of the 270 captured frames fill the existing slot at normal speed. The internal navigation is Home → Shop, whose player-facing page is Upgrades; it is not a Play transition.

Capture checks preserve 491 frozen script/data resource hashes, source parity, legal ownership, normal drawing and zero profile IO. Relevant map, layout and transition resources match the current workspace. No developer controls are shown; production saves and gameplay mechanics are unchanged. [Capture fixture and evidence](../../../concept-art/trailer-v4/capture/README.md).

## Mabel and established gameplay

V4 directly reuses all 373 V3 overlay PNGs at the same 14.4–20.6167-second interval. Her greeting holds for 51 identical frames / 0.85 seconds. The two scoops, small fruit, carried layers and loaded exit retain their timing and presentation. All ten Mabel Foley cues also remain unchanged.

The opening, material cuts, Prism duplication, Jam impact, final peg and cup catches retain their established timing. The new close-up and map shot occupy existing intervals, so the trailer stays 30 seconds / 1,800 frames.

## Closing composition

The tray now sits about 11 pixels below the wordmark’s visible bounds. The approved V3 title, collision art, Mabel serving pose and boxed Play now remain separate PNG layers. Existing painted countertop, marble and flower art gives the background more detail while keeping the title, face and call to action readable.

| Layer | Arrival relative to 27.1 seconds |
| --- | --- |
| Background | 0.00–0.24 |
| Wordmark | 0.12–0.42 |
| Tray and food collisions | 0.35–0.68 |
| Mabel | 0.62–0.95 |
| Play now | 0.90–1.15 |

Opacity and position interpolate smoothly. The first card frame is transparent, allowing the recorded game to remain visible before the background appears. The complete card holds still from 28.25–30.0, or 105 frames / 1.75 seconds. Its final rendered frame exactly matches the exported portrait PNG. The final MP4 is checked separately after encoding.

[Portrait closing PNG](../../../concept-art/trailer-v4/ending/exports/sugarfall-end-card.png) · [Transparent logo](../../../concept-art/trailer-v4/ending/exports/sugarfall-logo-lockup.png) · [Wide banner](../../../concept-art/trailer-v4/ending/exports/sugarfall-banner.png) · [Portrait transparent arrangement](../../../concept-art/trailer-v4/ending/exports/sugarfall-portrait-lockup.png).

## Audio, delivery and limits

V4 preserves all 103 game cues outside the replaced upgrade slot. It removes the old purchase cues and adds the actual recorded UI tap plus an editorial cream-wash sound. The final mix contains 104 game cues and 13 Foley cues; ending accents follow the revised layer arrivals. The music remains at normal speed over source 0–30 seconds.

Exact-file verification covers the 30-second, 1080 × 1920 / 60-fps H.264/yuv420p master, AAC 48-kHz stereo, full decode, clipping and mix comparison. Independent visual checks inspect the left crop, cream reveal, upgrade map and staged ending in the encoded video. Desktop and narrow-layout player checks cover playback and local links.

Visual review caught an initial encoding defect: the ending PNG sequence changed from RGBA to RGB, which reset the overlay timing and briefly exposed the game again at the end. The native canvas encoder now saves all ending frames and PNG exports consistently as RGBA. The corrected exact master was rechecked at 29.8 seconds and its final frame at 29.983 seconds; the complete card remains visible. The initial failure evidence is preserved separately from the accepted master.

The [manifest](../../../concept-art/trailer-v4/manifest.json) records the exact MP4 size and SHA-256. V3 and game source remain intact. No Drive upload or APK rebuild is part of this marketing revision. Physical-phone review, subjective listening and public publication clearance for the supplied music performance remain open.

Accepted local master: **13,809,414 bytes**, SHA-256 `d52e6ab4e73674a84a138cdf6495995b687d50ecc6ec4659191167acabcd43ce`. Full decode reports zero errors. The decoded AAC correlation with the final mix is **0.99948488**, with peak **0.78133** and no clipped samples. These measurements and agent visual checks do not claim user or phone acceptance.
