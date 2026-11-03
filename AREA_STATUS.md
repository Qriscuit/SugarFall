# Sugarfall — current area status

Updated 3 November 2026 · v0.7.6-preview/code 32 delivered · CHG-037

The same private Drive file now holds v0.7.6-preview, including CHG-036 area frames, signature abilities, early-access test flow, Flow-2 rules and ownership-aware checkpoint restoration. The three I09 export checks are now verified. Real public billing, current legal-campaign/human pacing and physical-phone acceptance remain open. The separate local public v0.8.0-rc1 artifacts are unchanged.

Counts include test activities as well as production content. Verified means the recorded scope passed; it does not imply a phone playtest. Intentional omissions remain N/A.

| Area | Built Yes | Integrated Yes | Verified Yes | N/A | Detailed record |
|---|---:|---:|---:|---:|---|
| Bakery | 80 | 80 | 76 | 2 | [Checklist](PLINKO/docs/areas/bakery_checklist.md) |
| Gelato Garden | 80 | 80 | 73 | 2 | [Checklist](PLINKO/docs/areas/gelato_checklist.md) |
| Crystal Candyworks | 80 | 80 | 73 | 2 | [Checklist](PLINKO/docs/areas/crystal_checklist.md) |

## Menu polish — v0.7.2 milestone

Centered menu symbols, a fitted Settings heading plaque, outlined damage numbers without beige backing, and a shared illustrated white-cream page wave now pass source/desktop verification in all three areas. One native wave is deliberately shared without area accents. CHG-028/AF-007 remains the historical backing decision; CHG-029 records the user-requested reversal.

The final evidence records 1,143 passing checks: 715 regression, 90 production-enabled page-transition, 331 GPU and 7 native-asset checks, plus 62 captures at 450x800 and 720x1280. All 42 runtime inputs match the final page suite and renderer. Full coverage before the single page swap, outgoing snapshot, repeated-input gate and Reduced Motion are exercised. Physical-phone/human acceptance remains open.

Template version 2 adds A28 (transition art/provenance) and F11 (transition behavior), for 83 requirements per area / 249 total. All six new entries are Built/Integrated/Verified for their software/art scope.

v0.7.2 delivery is verified in the established private Drive file. Phone installation and playtesting are not yet claimed.

## Shared studio startup

The supplied studio image now replaces Godot boot branding, starts dim/muted, pulses gently while real resources load, then reuses the cream wave into Home or the restored paused/result destination. The original image is unchanged; its runtime shader and matching Godot-rendered engine frame have separate provenance. Stored Reduced Motion uses a static presentation and immediate handoff once ready.

The final source evidence records 1,371 passing assertions: 735 regression, 90 shared page-transition, 58 startup-controller, 250 isolated-profile assertions across 13 cases and 238 GPU checks/48 captures. Six native-asset checks are separate. All current source inputs match the checked copies. No physical-phone result is claimed.

v0.7.3 packaging and replacement of the same private Drive file are verified. The checklist stays at 83 requirements per area / 249 total. All area and SF statuses remain; D14 adds physical cold/warm/hot launch, smoothness, stored Reduced Motion and retained-state acceptance.

See [Startup design and provenance](PLINKO/docs/STUDIO_STARTUP.md) and [Phone protocol D14](PLINKO/docs/AREA_PLAYTEST.md).

## Screen and run flow — v0.7.4 milestone

Tall-screen backgrounds fill the physical viewport while the logical board fits uniformly inside the safe area. Tray HUD and six cup-face multipliers fit in all areas. Home Play restores the tray/peg morph and equipment entrances; just-finished results are modal over the darkened frozen board. Final evidence passes 1,877 assertions: 879 regressions, 163 page/result, 58 startup, 250 isolated-profile, 111 HUD/cup and 416 GPU checks across 71 captures/five aspect ratios plus synthetic notch insets. Reopened pending results retain earnings/history but use an empty themed tray because peg/ball poses are not saved.

The current route rules deliberately differ from the earlier universal cream navigation: Home Play uses a continuous tray/peg morph with equipment entrances; end-run results appear over a darkened frozen board. Neither route uses the cream wipe. Studio startup and ordinary menu navigation retain their existing transitions. The blank template’s F11 now records these route-specific exceptions without adding an ID.

v0.7.4 packaging and replacement of the same private Drive file are verified. All 83-per-area/249 requirements and prior SF/AF status distinctions remain. Physical tall-screen layout, all six cup faces and run-flow feel are pending under AREA_PLAYTEST.md D15/D16.

## Warm studio revision

The shared startup now uses a soft amber spotlight and gradient. Its dark plum logo brightens to warm gold on each heartbeat and scales from the lower center. An original quiet hum follows the beat before the existing cream reveal. The supplied logo bytes are unchanged. Saved Sound off applies before the first sample; backgrounding silences playback, resume uses one voice, and handoff fades to silence. Reduced Motion keeps the presentation static.

This revision passes 738 focused checks: 74 controller, 295 actual disk-profile checks across 13 cases, 7 actual audio-mixer checks and 362 GPU checks across 72 captures. Six native-asset checks pass separately. The earlier startup and v0.7.4 evidence above remain historical records. Physical brightness, sound level, headphones and interruption feel remain D14/AF-009.

See [current startup design and provenance](PLINKO/docs/STUDIO_STARTUP.md). The area counts and all 249 requirement states remain unchanged.

## Public release candidate

Signed local APK and Google Play AAB artifacts are prepared as **v0.8.0-rc1 (code 30)** for `com.qriscuit.sugarfall`. This package installs separately from the preview and does not automatically import its save. At this candidate milestone, the private Drive download was v0.7.4-preview. The candidate has not been published to Play; the newer preview delivery is recorded below.

Public builds hide and reject simulated commerce, fake entitlements, developer controls and diagnostics. Preview builds retain their test tools. That release-candidate source passed 1,520 focused assertions: 738 warm-startup, 656 preview regressions and 126 public-policy checks, including an actual nondebug Windows export. Native-asset and toolchain checks are recorded separately. The signed APK passes 508 payload plus 16 Android metadata checks; the signed AAB passes 30 checks. Phone acceptance, real ads/billing, Play setup, an off-device signing backup and clean-machine rebuild verification remain open.

See [the candidate record](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc1.md) and [signing and recovery](PLINKO/docs/RELEASE_SIGNING.md). AF-008/009 remain Ready to test, and no physical result has been added to the area checklists.

Source, art, tests and production records are backed up in [Qriscuit/SugarFall](https://github.com/Qriscuit/SugarFall). Tag `v0.8.0-rc1` records the 881-file baseline at commit `1bf3632`; a fresh remote recovery clone passed 13 integrity/completeness checks. See [source-control evidence](PLINKO/docs/SOURCE_CONTROL.md). CHG-032/033 record this revision; SF-007 and SF-042 are Done. Signing-key recovery, Play setup and physical acceptance remain separate open work.

## Pause presentation — CHG-034 source milestone

CHG-034 replaces cream on play/pause/abandon routes with a sharp menu fading over a gently blurred and shaded frozen board. Resume fades the menu out first, then clears the background treatment before gameplay continues. The blur fills normal and tall viewports. Reduced Motion settles immediately. Ordinary menu and studio-to-restored-pause cream routes, Home tray morph and result windows retain their intended behavior.

Source verification at this milestone passed 1,184 checks: 161 page routes, 98 pause behavior, 58 Home entrance, 489 related regressions and 378 GPU assertions across 57 captures in all three areas at 450×800 and 450×1000. Functional/regression copies matched 48 runtime inputs each; GPU parity covered 214 inputs. All ten gameplay JSON files remained unchanged. See [transition behavior](PLINKO/docs/MENU_TRANSITIONS.md) and [verification](PLINKO/docs/PAUSE_FADE_VALIDATION.json).

Template version 4 refines F11 without adding requirements; all 83-per-area/249 states and SF/AF statuses remain. Phone D17 is Pending. At this source-only milestone, no new APK, AAB or Drive replacement was requested or produced. The then-existing v0.8.0-rc1 artifacts and v0.7.4 Drive preview did not include it. CHG-035 below records the subsequent v0.7.5 preview delivery; the public candidate artifacts remain unchanged.

## Concise-menu preview — v0.7.5 delivery

Pause has one Paused title and a compact control panel. Settings has one title and a centered, capability-driven layout with no gaps from hidden options. Help uses How to play and Trials uses Trials. Decorative slogans, repeated headings, time-card flavor text and the redundant restored-run toast are removed; mechanics and consequential reset/end-shift instructions remain. The shared pause fade/blur and warm spotlight/heartbeat/hum are included in v0.7.5-preview (code 31).

1,516 checks pass with zero failures: 712 functional/regression and 804 GPU assertions, with 81 captures across all three areas at 450×800 and 450×1000. Final runtime/art parity covers 211 inputs. 517 APK payload checks and 16 Android metadata/signing/alignment checks pass. Eight Drive metadata checks pass after replacement in the same private file, with its ID, folder, owner permissions and 89,281,899-byte size verified; no remote checksum was returned. The preview keeps its existing package and development certificate; intended install-over compatibility is verified in metadata, while physical save retention remains Pending.

Template version 5 refines T04 without new requirement IDs. All 83-per-area/249 requirement states, 65 SF statuses and nine AF statuses remain unchanged. D07/D13 cover menu readability and composition, D14 covers warm startup/audio and D17 covers pause feel; all 17 physical checks remain Pending. CHG-034 history stays intact, and the public v0.8.0-rc1 APK/AAB were not rebuilt.

See [current menu validation](PLINKO/docs/MENU_CLEANUP_VALIDATION.json), [v0.7.5 delivery record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.5.json) and [download](PLINKO/BUILD_LINKS.txt).

## CHG-036 source milestone — signature abilities and area frames

Each area has a required earned tray-8 signature ability and an optional permanent early route from tray 1, at a US$2.99 design price per area. Bakery adds Jam Burst; Gelato retains Dual Shot and its Power reset; Crystal Second Prism moves to tray 8 while preserving existing owners. Three native menu frames distinguish Settings/Pause and the ability offer.

Final source passes 214 behavior/save checks and 155 GPU assertions across 30 captures at 450×800/450×1000, with zero failures and exact source parity. Access (74), Flow (131 unit/128 disk), combat (364), durability (266) and menu-art (423/24 captures) evidence is separately scoped; no historical totals are combined. [Validation](PLINKO/docs/AREA_SIGNATURE_VALIDATION.json) covers source behavior and desktop rendering. Flow 2 changes late HP/reward budgets independently and pins existing runs to legacy rules; bounded fixed-build probes do not establish fresh-wallet or human pacing. Real Play products/plugin/backend, live purchases and restore remain unfinished. SF-039/040/041 are In progress.

Template v6 adds U07/U08: **85 requirements per area / 255 total**. U07 is source-verified; U08 stays No/No/No for the complete real-payment path. Bakery A06/F06/U02 supersede their earlier intentional omissions. B04/B06/Q04 current verification is reopened for Flow-2 legal progression, and I09 remains unverified for a new Android package. Prior evidence and all 35 earlier change entries are retained. AF-008/009 remain Ready to test; all phone results stay Pending. No new APK or Drive replacement is claimed.

See [signature design](PLINKO/docs/AREA_SIGNATURE_ABILITIES.md), [purchase scope](PLINKO/docs/AREA_ABILITY_PURCHASES.md), [flow rules](PLINKO/docs/AREA_FLOW_RULES.md) and [menu art](PLINKO/docs/AREA_MENU_ART.md).

## Current v0.7.6 preview delivery

CHG-037 records packaging and delivery of the previously source-only CHG-036 revision. 629 payload checks and 16 Android metadata/signature/alignment checks pass. The APK is 92,630,017 bytes; SHA-256 `3512e4078db8cadabb134705794f9f7a1d9f7524670161b7f3467436eb6133fe`. All 8 Drive metadata checks pass after replacement in the same private file; file ID, folder, owner permissions and download URL are retained. No remote checksum comparison is claimed. The preview package/certificate match the existing install path. Physical installation and save retention remain Pending.

I09 is now verified in all three areas; 85 requirements per area/255 total remain. All SF/AF statuses and phone outcomes are unchanged. U08 stays unfinished for real billing, and B04/B06/Q04 remain unverified for current legal progression. CHG-036 and earlier evidence remain historical. See [the build record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.6.json) and [download](PLINKO/BUILD_LINKS.txt).

## Fix queue

| ID | Work | Status | Result / remaining work |
|---|---|---|---|
| AF-001 | Connect Crystal Prism collection sound | Done | Prism now reuses the registered 950 Hz / 0.08 s pickup cue. Eleven checks cover the real testing=false playback path, mute and cached stream/PCM reuse; physical listening remains AF-009. |
| AF-002 | Correct Gelato Dual Shot Help | Done | Help now says Dual Shot is below Feed 1, costs 3,000 coins and requires tray 8 AND Power 6; reset/rebuild copy remains short. Rendered fit checked at 450x800 and 720x1280. |
| AF-003 | Refresh current Gelato design pages | Done | Refreshed four current Gelato design pages: delivered version, profile/checkpoint schemas, all twelve trays, exact ownership, Twin gates and Crystal successor. Historical evidence retained; 12-row/link checks pass. |
| AF-004 | Give each Bakery tray a specific lesson | Done | Authored distinct Bakery tray 2–12 lessons and compared real layouts. Only trait_brief strings changed. Pinned old/new fingerprint compatibility preserves interrupted Bakery runs; 34 targeted checks pass. Legal build ranges are recorded for all trays. |
| AF-005 | Complete targeted Crystal lifecycle checks | Done | Sixty-eight Crystal lifecycle checks pass: legal 63-position traversal, failed writes, actual disk entry/Trial/result restoration, reward conservation, histories, milestones and actual touch/menu guards. No lifecycle runtime defect found. |
| AF-006 | Check crowded Bakery and Gelato physics | Done | 108 fixed-60Hz stress checks pass: 610 px/s contacts, cooldowns, population limits, expiry, clumped rendering schedules and an 83-ball final-split drain. No production physics defect found; no physics change needed. |
| AF-007 | Finish current Gelato and Crystal visual coverage | Done | Completed 58 current GPU captures with 287 passing assertions at both sizes. Reviewed missing menus, live effects, Reduced Motion, result states and deep Crystal cards/edges. Added a cream backing so rebounding balls cannot obscure damage numbers. |
| AF-008 | Measure legal progression through all three areas | Ready to test | Six linked campaigns across two legal shopping policies and three seeds passed 9,044 assertions and cleared all 18 sampled area campaigns. Wall builds, earnings, purchases, fees, Twin rebuild and Second Prism are measured. Five unique tray/seed pacing flags remain historical. CHG-036 Flow-2 rules and signature gates now require fresh legal-campaign/human revalidation; bounded probes do not replace it. |
| AF-009 | Run the physical-phone acceptance pass | Ready to test | Verified v0.7.6 is delivered for the user's phone test. No phone installation, retained-save, touch, sound or performance result is claimed; all device checks remain Pending. |

## Continue one finding at a time

Use the workbook’s **Area checklist** and **Area fixes** tabs. Keep Built, Integrated and Verified separate; a Done fix needs its note, completion date and repair evidence. Preserve the original finding evidence and CHG history.

- [Phone and human playtest protocol](PLINKO/docs/AREA_PLAYTEST.md)
- [Measured legal progression and flagged trays](PLINKO/docs/AREA_PROGRESSION_BALANCE.md)
- [Verified APK record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.6.json)
- [Download details](PLINKO/BUILD_LINKS.txt)
- [Editable launch workbook](outputs/launch-tracker-01a18eec/Sugarfall%20Launch%20Tracker.xlsx)

The six legal simulations used two shopping policies and three seeds. All three areas cleared in every campaign, with no free money or granted nodes. The sample is not a human pacing verdict; review the five unique stall cases before deciding on price/HP changes. No new tuning was justified solely by the sampled cursor policy.

The future-area template remains blank with the two new requirements. Original audit and implementation evidence remain in `verification/area-audit-20261103/` and `verification/area-fixes-20261103/`. Menu-polish evidence remains in `verification/menu-polish-20261103/`; startup records remain in `verification/studio-startup-20261103/`; current screen/flow records are in `verification/screen-polish-20261103/`.
