# Sugarfall trailer V4 — composition, left close-up and upgrade reveal

Prepared 4 November 2026. V4 keeps the approved 30-second V3 timing and Mabel sequence. It adds a left-side gameplay close-up, replaces the sparse Feed purchase shot with a fuller real upgrade map and the game's cream transition, and brings the closing tray closer to the Sugarfall wordmark. The video remains local.

The new upgrade capture and revised card are integrated. Exact-file verification, including the corrected ending's final frame, is recorded separately in [manifest.json](manifest.json).

## Edit decisions

| Edit time | Picture | Change |
| --- | --- | --- |
| 0.000–3.650 | Bakery opening | Keep V3's opening and its camera. |
| 3.650–5.400 | Gelato material cut | Keep the existing right-side crop. |
| 5.400–7.2167 | Crystal material cut | Keep the existing crop. |
| 7.2167–10.8167 | Gelato aim and left wafer contacts | Start wide and zoom to 1.45 toward the left side. Preserve source0.600–4.200 and normal playback speed. |
| 10.8167–14.400 | Real cream transition into a near-complete upgrade map | Replace the old sparse Feed purchase sequence. Capture Home → Upgrades, then hold or gently scroll the populated map. |
| 14.400–20.6167 | Firing result, Mabel's greeting, three catches and loaded exit | Preserve V3's picture timing and every Mabel overlay frame. |
| 20.6167–24.1667 | Real Prism duplication | Preserve V3. |
| 24.1667–25.0833 | Jam impact | Preserve V3. |
| 25.0833–27.100 | Real last peg and cup catches | Preserve V3. |
| 27.100–30.000 | Revised illustrated closing card | Tighten the title/tray grouping, add background artwork, fade and settle the layers in sequence, then hold. |

The new upgrade shot replaces one existing shot rather than extending the trailer. Mabel remains at 14.4–20.6167; the music, Prism, Jam and final clear keep their established times.

## Left-side close-up

Use the existing Gelato source shot, frames 36–251. The camera rises from zoom 1.00 to 1.45 over 216 frames, anchored at output coordinates [288,900]. With the existing zoompan convention, the target is placed around output y=675 and crop x is clamped to 0. The lower camera anchor clears the launcher at the actual left-side contacts.

The left wafer lies at board coordinates [200,540]. The frozen renderer's board transform is `BOARD_CENTER + (p - BOARD_CENTER) * 1.05`, with center [360,668], followed by the capture's 1.5 scale. Its actual full-frame center is [288,800.4]. The older impact trace's `pixel_position` omits the 1.05 transform, so the board coordinates supply the corrected location.

Two real contacts occur at source frames 184/194, times 3.0667/3.2333, corresponding to edit 9.6833/9.8500. At those frames, the proposed zoom is 1.309767/1.330698. The left copper rim, wafer contact and crumbs are visible; the HUD and launcher are outside the crop. Agent visual checks passed for [frame 184](../../outputs/trailer-v4-20261104/qa/left-zoom/contact-184.png) and [frame 194](../../outputs/trailer-v4-20261104/qa/left-zoom/contact-194.png). Final encoded crop review remains separate.

## Upgrade reveal

The new isolated public renderer capture stages a legal late-area build with 56 of 62 ordinary nodes owned and Dual Shot earned through its production purchase API. Six terminal leaves remain affordable. It shows actual map art, connections, ownership and normal interface drawing. The separately staged upgrade build is not presented as the result of an earlier ordinary Feed purchase.

The real Home Upgrades-button click occurs at source 0.10 seconds. The production cream transition lasts 0.62 seconds and is permitted for that page change; the internal destination mode is Shop. Home → Play deliberately uses the tray/board movement instead. The wave fully covers and reveals the new map, leaving about 2.8 seconds of the 215-frame slot for the map. A 72-pixel touch/drag pan demonstrates the native map camera.

The old Feed purchase at edit 13.0167 and its tap/purchase cues are removed. The recorded map tap is placed at edit 10.9167 alongside an editorial cream-wash sound. All 103 gameplay cues outside the replaced slot and all ten Mabel Foley cues are preserved.

## Closing image

The approved wordmark, biscuit-collision vignette, serving Mabel and Play now artwork remain. The tray's upper visible edge is about 11 pixels below the wordmark's lower visible edge in the 1080 × 1920 composition. The title and tray form a compact upper grouping, while Mabel's face, plate and the button remain clear.

Existing painted countertop, marble and flower artwork supplies the richer background. Its contrast stays quieter than the lettering and food. Strong motifs stay away from the title counters, Mabel's face and button text, supporting the existing mint, lilac and copper materials.

The layer arrivals use smooth opacity and position interpolation. Actual relative timing within the 2.9-second card is background 0.00–0.24, wordmark 0.12–0.42, collision tray 0.35–0.68, Mabel 0.62–0.95 and button 0.90–1.15. Everything settles by 28.25, leaving 1.75 seconds / 105 frames of a still, readable final composition.

## Verification

- Keep 30 seconds / 1,800 frames at 60 fps and unchanged Mabel timing.
- Verify the new left crop at the actual contacts and in the encoded master.
- Verify real cream coverage/reveal and the near-complete upgrade state from the capture report.
- Remove obsolete Feed purchase cues; sync the new UI cues to the captured transition.
- Review the final name-to-tray gap, background contrast, face/food/button spacing and sequential fades in the encoded master, including 29.8 and 29.983 seconds.
- Preserve V3 and the gameplay/runtime source; no APK or Drive upload is part of this trailer revision.
