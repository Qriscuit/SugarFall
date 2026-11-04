# Area menu artwork

**v0.7.6 delivery:** The [verified APK](ANDROID_SUGARFALL_v0.7.6.json) includes the three native frames and jam sprite. Earlier art-composition verification below remains separately scoped; phone contrast, touch comfort and memory acceptance stay open.

3 November 2026 · Native artwork and source integration; phone acceptance remains open.

Settings and Pause use distinct menu boards while keeping their concise titles, existing button skins, spacing and touch targets. Scenery stays on the perimeter, away from live controls.

| Area | Menu board | Native asset |
|---|---|---|
| Bakery | Copper baking tray and warm parchment, with sage gingham and small flour/wheat accents | [Bakery frame](../data/art/menus/bakery_frame.png) |
| Gelato Garden | Ivory ceramic and lilac/mint garden tiles, with corner vines and a small waffle fan | [Gelato frame](../data/art/menus/gelato_frame.png) |
| Crystal Candyworks | Pale aqua sugar glass with copper seams and peach crystal corners | [Crystal frame](../data/art/menus/crystal_frame.png) |

All three are native 1254×1254 RGBA images generated with the built-in ImageGen tool. The PNG bytes are preserved. Their outside pixels have genuine transparency; the quiet faces are almost opaque (alpha 252–254). There is no baked-in text, price or button. [Exact prompts and provenance](../../concept-art/area-menu-frames-v1/sources.json) and [native inspection](../../concept-art/area-menu-frames-v1/native-validation.json) are retained.

`ui_art.menu_frame(canvas, content_rect)` draws a frame 32 design pixels outside the existing panel rectangle. The authored corner slices retain a uniform 100-pixel scale. Only the plain middle spans and quiet face stretch. The controls retain their original rectangles, and the gameplay HUD, upgrade nodes, ordinary cards and shared button skins keep their existing appearance. `startup.warmup_paths()` includes all three frames so the menu does not decode an unfamiliar image on first opening. Godot supplies mipmaps, alpha-border handling and a 1024-pixel import cap; the native source images are not resized.

## Bakery Jam Burst image

[Jam doughnut](../data/art/bakery_ability/jam_donut.png) is a separate native 1254×1254 RGBA sprite with a large ruby jam center and golden baked ring. It can identify the active doughnut and the upgrade. Its alpha≥128 content rectangle is `(83, 99, 1078, 1079)`; runtime drawing can crop that transparent margin without changing the source. Godot imports it at 256 pixels with mipmaps, matching its small ball/icon use instead of retaining a large GPU texture. [Its exact prompt and provenance](../../concept-art/area-menu-frames-v1/jam-donut-source.json) are separate from the menu frames. Gameplay behavior and ownership are defined by the ability controller, not by this presentation asset.

## Acceptance

Native-byte, alpha and authored-bound inspection is complete. The [art composition validation](AREA_MENU_ART_VALIDATION.json) records 423 passing menu/render/touch assertions and 24 real-engine captures across all three areas at 450×800 and 450×1000. Sampled Pause and public/preview Settings images retain readable titles, comfortable control margins and unobscured themed corners. This is an art-only snapshot while the ability implementation evolves; full final-feature source parity is verified separately. Physical-phone contrast, edge comfort and memory behavior remain part of the user playtest.

## CHG-043 card integration

Signature purchase choices and no-charge preview confirmation now stay on the existing upgrade card. Home has no ability purchase offer and the separate options page is no longer used. Settings/Pause retain these native area frames; the earlier standalone-offer frame use is historical. No PNG or generated art is changed for this UI revision. See [purchase behavior](AREA_ABILITY_PURCHASES.md).
