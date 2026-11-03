# Portrait screen layout

Current implementation · 3 November 2026 · desktop checks passed; phone acceptance open

The game paints themed scenery across the full portrait viewport. Its interactive 720×1280 composition stays uniformly scaled and centered inside the usable safe region, so extra screen height shows scenery instead of fixed-aspect black bars. Board positions, collision shapes, drop physics, catch lines and reward calculations stay in their existing coordinates.

## Viewport and safe area

[project.godot](../project.godot) keeps the 720×1280 design reference and `window/stretch/mode="canvas_items"`, with `window/stretch/aspect="expand"`. [main.gd](../scripts/main.gd) updates the content fit on viewport resize for every platform. On Android, the reported display safe rectangle is transformed into viewport coordinates and intersected with the actual viewport before fitting the interactive content.

Background drawing uses the actual viewport transformed into the game's local coordinates. Its coverage therefore includes the extra space around the centered composition. Fullscreen dimming layers follow the same bounds. Touch handling converts screen positions back into local coordinates before using the existing targets. Additional screen height does not extend the playable board or move the catch line.

Engine reference: Godot documents [Expand stretching](https://docs.godotengine.org/en/4.5/tutorials/rendering/multiple_resolutions.html#stretch-aspect) for accommodating different display shapes, and the [Android display-safe-area API](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area) supplies the usable display rectangle. The project's actual behavior is checked through the root-window renderer below.

## In-game tray status

The top status panel retains its existing size and Pause target. The tray/trial title, strength tier and remaining-peg count occupy a centered column at `Rect2(430,34,112,70)` inside the panel. Campaigns use three rows when a material tier is present; Trials use two. The column reserves the panel border and a gap from the coin value.

`game_hud_label_layout()` fits both measured text width and the complete font line height before centering its baseline. This replaces the fixed title baseline that could touch the panel's upper rim. The helper uses the actual Nunito fonts; it does not truncate tray names or count labels.

## Cup multipliers

Each of the six cup artworks has its own quiet front-face rectangle in [food_art.gd](../scripts/food_art.gd), normalized within its existing sprite/atlas crop:

| Area | Cup | Face center height | Face width |
| --- | --- | ---: | ---: |
| Bakery | Cream ceramic | 54% | 66% |
| Bakery | Gold | 55% | 66% |
| Gelato | Cream/lavender goblet | 51.5% | 56% |
| Gelato | Gold goblet | 43% | 56% |
| Crystal | Clear blue glass | 49.5% | 64% |
| Crystal | Gold glass | 51.5% | 64% |

All faces share the cup's horizontal center. Gelato gold's label sits on its bowl rather than the midpoint of the bowl and long stem. Width and full font-height fitting keep longer multipliers inside the selected face. The original one-decimal multiplier text remains unchanged.

`draw_buckets()` applies the same anchored catch-stretch transform to the sprite and its label. The face metadata changes presentation only. No artwork pixels, source crop bounds, cup spacing, catch geometry, hit count or payout values change. New cup artwork should provide a matching face rectangle and be inspected at rest and during the catch response.

## Related screen motion

Home Play again uses the existing short tray zoom/morph into gameplay, without a cream wipe. End-of-run results appear over a darkened frozen board, without a cream wipe. Ordinary navigation and studio startup retain their shared cream transitions where applicable. [MENU_TRANSITIONS.md](MENU_TRANSITIONS.md) owns the detailed transition/result behavior; [STUDIO_STARTUP.md](STUDIO_STARTUP.md) owns loading and profile restoration.

## Verification

The [focused HUD/cup suite](../../verification/screen-flow-20261103/hud-cup-qa-01/summary.json) passes **111 checks** using real font metrics: all twelve trays across all three areas in campaign/Trial modes, every cup face with short and long multipliers, and unchanged decimal rewards/catch coordinates. [The test](../tests/hud_cup_layout_qa.gd) runs without player-profile I/O in a copied project with a verified disposable user directory.

The accepted [combined validation](../../verification/screen-polish-20261103/validation.json) passes **1,877 checks**: 879 existing regressions, 163 page/entry/result checks, 58 startup-controller checks, 250 actual isolated-profile checks, 111 HUD/cup checks, and 416 renderer checks. The [final visual run](../../verification/screen-polish-20261103/visual-final/screens/preview-summary.json) contains **71 captures** at 450×800, 450×975, 450×1000, 450×1050 and 600×800, including simulated safe-area insets, campaign/Trial/result states, ordinary cream navigation, Home tray entry and caught-cup labels. Its recorded shared runtime and startup/configuration inputs match the accepted source. The 450×1000 Bakery/Gelato gameplay and Crystal catch frames were independently inspected for HUD padding and cup alignment.

The [startup-controller rerun](../../verification/screen-polish-20261103/startup-unit-01/summary.json) passes 58 checks. The [production startup/profile rerun](../../verification/screen-polish-20261103/startup-profile-01/integration-manifest.json) passes 250 checks across 13 disposable profiles, with 207 matching runtime/art/harness inputs. It verifies that the new viewport and result presentation preserve fresh onboarding, independent wallets/upgrades, paused snapshots and pending rewards through startup and injected lifecycle interruptions. The [focused layout parity record](../../verification/screen-flow-20261103/hud-cup-qa-01/layout-parity.json) pins the HUD/cup functions and actual fonts used by their 111 checks.

Desktop layout and injected lifecycle checks do not establish actual device cutout behavior, phone touch comfort or Android performance. Physical tall-screen testing remains open.
