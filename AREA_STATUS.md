# Sugarfall — current area status

Updated 4 November 2026 · v0.7.10-preview/code 36 retained · public v0.8.0-rc2/code 37 delivered · CHG-044

The existing preview APK retains the direct ability-card actions, single-pulse intro, action sounds and More Jam. CHG-044 prepares the reusable signed-release environment and delivers separate public **v0.8.0-rc2/code 37** APK and AAB files for Internal testing preparation. The existing preview download is unchanged. The owner reports creating the Play app; Console enrollment, upload, production readiness and off-device key backup are unverified.

344 exact-artifact checks pass: 41 compiled scripts, 10 game-data JSON files and 418 indexed project payloads are verified. APK/AAB payloads agree, with sparse-directory order checked semantically. 186 policy checks pass (85 preview and 101 actual nondebug); 11 verifier tests and five build-helper tests are separate. Drive readbacks verify separate APK, AAB and public-certificate files in the existing owner-only folder; the v0.7.10 preview is unchanged. No remote checksum was returned. All 255 area requirements and nine AF records retain their existing values. Real billing, physical acceptance, the reported Bakery tray-10 difficulty and current legal progression remain open. [Candidate record](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc2.md) · [Release queue](PLINKO/docs/GOOGLE_PLAY_READINESS.md).

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

## Public release candidate — v0.8.0-rc1 milestone

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

## v0.7.6 preview delivery — historical package milestone

CHG-037 records packaging and delivery of the previously source-only CHG-036 revision. 629 payload checks and 16 Android metadata/signature/alignment checks pass. The APK is 92,630,017 bytes; SHA-256 `3512e4078db8cadabb134705794f9f7a1d9f7524670161b7f3467436eb6133fe`. All 8 Drive metadata checks pass after replacement in the same private file; file ID, folder, owner permissions and download URL are retained. No remote checksum comparison is claimed. The preview package/certificate match the existing install path. Physical installation and save retention remain Pending.

I09 is now verified in all three areas; 85 requirements per area/255 total remain. All SF/AF statuses and phone outcomes are unchanged. U08 stays unfinished for real billing, and B04/B06/Q04 remain unverified for current legal progression. CHG-036 and earlier evidence remain historical. See [the build record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.6.json) and [download](PLINKO/BUILD_LINKS.txt).

## CHG-038 source milestone — action audio and Play audit

CHG-038 is source-only after v0.7.6. 33 original WAVs cover 25 events across menus, purchases, gameplay, pickups, signature abilities and results, with area-specific launch/hit/break/catch textures. A six-voice cached mixer caps ordinary gameplay at three voices, bounds repeated cues, honors mute/background silence and never queues stale playback. No gameplay music or ambience is added. The warm bottom-center studio pulse/hum now uses a 1.30-second cycle and 2.60-second minimum, with a legible half-strength second beat and 0.26-second quiet tail; Reduced Motion bypasses the presentation minimum. Audio: 82 integration, 91 mixer, 11 Prism and 85 cache checks; separate regressions 125/364/98/284. All 33 WAVs regenerate byte-exact. Studio: 447 final-source checks (78 controller/7 mixer/362 GPU), 72 captures; 12 native-asset checks separate. Earlier 295 profile checks precede the final pulse-amplitude adjustment and are not combined. All accepted scopes pass. Separate v0.7.6 static ELF audit passes both libraries/all six load segments; no Android 16KB runtime claim. The Drive APK and earlier public v0.8.0-rc1 artifacts are unchanged. New audio/pulse needs a later requested export; phone listening, real billing and current legal progression remain open.

SF-032 is Done for the dated official-requirements audit; the launch tracker now has 12 Done and 53 open tasks. No other SF or AF status is closed. F09 stays unverified for phone listening, I09 awaits the new export, and all 17 phone checks remain Pending. Template v7 keeps 85 requirements per area/255 total. See [audio coverage](PLINKO/docs/AUDIO_FEEDBACK.md), [studio startup](PLINKO/docs/STUDIO_STARTUP.md) and [the ordered Google Play queue](PLINKO/docs/GOOGLE_PLAY_READINESS.md).

## v0.7.7 preview delivery — historical milestone

CHG-039 delivers v0.7.7-preview/code 33, including action sounds, the slower studio pulse/hum and the final area-picker cue correction. 823 payload checks and 16 Android metadata/signature/alignment checks pass. The APK is 93,047,202 bytes; SHA-256 `dd1eaa5982985a6e180a91ba214b1da0500f90f541d7b9104396faeb8c12adc9`. All 8 Drive readback checks pass; the existing private file ID, folder, owner permissions and URL are retained. No remote checksum comparison is claimed. Physical installation, retained saves, listening/feel, legal progression and real billing remain open. Public v0.8.0-rc1 artifacts are unchanged.

Only the three I09 verification flags close. F09 phone listening, all 17 device checks, current legal progression and real payments remain open. All 65 SF and 9 AF statuses are unchanged; 12 SF tasks are Done and 53 remain open. See [the exact build record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.7.json) and [download](PLINKO/BUILD_LINKS.txt).

## Current More Jam preview — CHG-040

More Jam is a free, once-only Bakery claim requiring tray 10 unlocked, effective Jam Burst access and all 62 ordinary upgrade nodes, including the shared root and all three routes. It affects newly started campaign runs and introduces no paid product. Base Jam Burst can be earned or accessed through its existing early route; More Jam itself cannot be bought early. On 3 November 2026, the user reported being unable to clear Bakery tray 10 despite having all upgrades. The exact installed build, phone/OS, node ownership/loadout, attempts, aim pattern, remaining pegs and time are unconfirmed. This is an open difficulty finding, not a completed phone or campaign acceptance pass.

1,060 software checks pass across 12 focused backend, save and map suites. Separately, 79 GPU checks pass across 14 captures at 450x800 and 450x1000; 253 final renderer inputs match. No phone result is implied. The far-end More Jam node connects all three routes, reveals at tray 10 or any completed lane, and focuses eligible players on entry. Final map/GPU checks cover locked, green free-claim, owned, card and four-drop feedback states.

78 fixed-build comparisons plus one deterministic replay have no invariant/profile/termination failures. Tray-10 tracking clears 8/9 at both cadences; broad sweeps clear 0/9 at both. Tracking trays 11/12 change 8/9 to 9/9 and 8/9 to 6/9. Jam damage rises, but this does not establish resolution of the phone difficulty or natural-wallet/human progression.

CHG-040 delivers v0.7.8-preview/code 34 with More Jam, a free late Bakery upgrade that charges a Jam doughnut every fourth normal drop instead of every fifth. 786 payload checks and 16 Android metadata/signature/alignment checks pass. The APK is 93,051,298 bytes; SHA-256 `9bb0f427a1bb47ac916ec01b5ea73b50d590026f8cfa51f0c37905f602035998`. All 8 Drive readback checks pass; the existing private file ID, folder, owner permissions and URL are retained. No remote checksum comparison is claimed. The specific Bakery tray-10 phone finding awaits retest; full device/audio acceptance, normal-wallet progression and real billing remain open. Public v0.8.0-rc1 artifacts are unchanged.

SF-054 is In progress for the reported issue and retest. All other SF statuses, nine AF statuses and 255 requirement states remain unchanged; 12 SF tasks are Done and 53 remain open. F09, current legal progression, real billing and D01–D17 remain open. See [More Jam](PLINKO/docs/BAKERY_MORE_JAM.md), [the exact build](PLINKO/docs/ANDROID_SUGARFALL_v0.7.8.json) and [download](PLINKO/BUILD_LINKS.txt).

## CHG-041 local single-pulse candidate — historical preview

CHG-041 is a local GIF candidate awaiting user review. It removes the smaller second beat, leaving one grow/brighten/shrink pulse per 1.30-second cycle with a matching single hum. The 2.60-second presentation minimum, warm artwork, lower-center anchor, real loading and Reduced Motion behavior remain. No APK export, Drive replacement or GitHub push is authorized for this preview step. The delivered v0.7.8-preview/code 34 remains unchanged and still has the double pulse.

90 controller/mixer checks pass; 13 native PCM/art checks pass separately. The actual Godot capture/GIF passes 69 checks with zero profile IO and matching source hashes. The 450x800 GIF shows 110 captured frames over 4.4 seconds at 25 FPS (47 encoded frames after repeated rests are coalesced). Root visual review passes; user review and phone acceptance are pending. See [startup validation](PLINKO/docs/SINGLE_PULSE_VALIDATION.json), [startup design](PLINKO/docs/STUDIO_STARTUP.md) and [the local GIF](outputs/studio-single-pulse-20261103/Sugarfall-single-pulse-intro.gif).

Only three I09 verification flags reopen for current source. All 65 SF and nine AF statuses, 40 earlier change entries and physical-phone findings remain unchanged. The GIF awaits user review and does not establish phone acceptance.

## v0.7.9 preview delivery — CHG-042 historical milestone

CHG-042 delivers v0.7.9-preview/code 35 after the user approved the single-pulse GIF. Each 1.30-second cycle now has one grow/brighten/shrink and one matching hum swell; the smaller second beat is removed. The 2.60-second minimum and existing warm art/loader behavior remain. 874 payload checks and 16 Android metadata/signature/alignment checks pass. The APK is 93,039,010 bytes; SHA-256 `f55cfcf37c3512cc2566b3e4dd3f956db07973a69d89790c52c60cc47138236d`. All 8 Drive readback checks pass; the existing private file ID, folder, owner permissions and URL are retained. No remote checksum comparison is claimed. Phone installation, audio/feel and the Bakery tray-10/More Jam retest remain open. Current legal progression and real billing are unfinished; public v0.8.0-rc1 artifacts are unchanged.

CHG-041 remains the exact local-preview history; the user subsequently approved it and requested this delivery. Only the three I09 verification flags close. All 65 SF and nine AF statuses remain unchanged, along with the Bakery difficulty finding and all 17 pending phone checks. See [the exact build](PLINKO/docs/ANDROID_SUGARFALL_v0.7.9.json) and [download](PLINKO/BUILD_LINKS.txt).

## Current ability-card preview — CHG-043

Each selected signature upgrade card has two stacked actions: Buy with the coin cost above Buy with the localized store price (preview $2.99). Two short effect lines and the tray/Power gate remain on the card. Home has no ability purchase artwork or touch target, and there is no separate options page. Coin purchases use the existing earned gates and costs. In preview, the early-access action stays on the card and changes to Confirm test and Cancel under explicit Test purchase / No charge labels. Back, leaving the map or selecting away cancels confirmation. Available public purchases request the provider directly; missing or unverified providers cannot grant access. Owned abilities cannot be bought again, pending requests are guarded, and Restore uses the lower action when receipt restoration is needed. No real billing integration is completed by this UI change.

844 source/desktop assertions pass with zero failures: 192 integration, 431 GPU, 35 Crystal UI, 105 Gelato shop and 81 Twin-node checks. The renderer covers 38 captures at 450x800 and 450x1000; 259 relevant source/art/data/fixture hashes match. Direct actions, gates, inline confirmation, provider-fixture pending/restore/rollback and Home cleanup are exercised. No real Play transaction or phone acceptance is claimed.

CHG-043 delivers v0.7.10-preview/code 36 with direct stacked coin and early-access purchase actions on signature upgrade cards. Home no longer promotes an ability purchase. 1048 payload checks and 16 Android metadata/signature/alignment checks pass. The APK is 93,043,106 bytes; SHA-256 `8673036be460e691f5c2bf6108c171f9a1e904cb9c729e10fde522ca6ef0105c`. All 8 Drive readback checks pass; the existing private file ID, folder, owner permissions and URL are retained. No remote checksum comparison is claimed. Phone touch/readability, the Bakery tray-10 retest, current legal progression and real billing remain open. The earlier public v0.8.0-rc1 artifacts are unchanged.

All 255 requirement states, 65 SF statuses, nine AF statuses and 42 prior change entries remain. U08 stays No/No/No; all 17 phone checks remain Pending. See [purchase design](PLINKO/docs/AREA_ABILITY_PURCHASES.md), [UI validation](PLINKO/docs/DIRECT_ABILITY_PURCHASE_VALIDATION.json) and [the exact build](PLINKO/docs/ANDROID_SUGARFALL_v0.7.10.json).

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
| AF-008 | Measure legal progression through all three areas | Ready to test | Six linked campaigns across two legal shopping policies and three seeds passed 9,044 assertions and cleared all 18 sampled area campaigns. Wall builds, earnings, purchases, fees, Twin rebuild and Second Prism are measured. Five unique tray/seed pacing flags remain historical. CHG-036 Flow-2 rules and signature gates now require fresh legal-campaign/human revalidation; bounded probes do not replace it. CHG-040 records the user’s Bakery tray-10 difficulty finding and bounded More Jam probes; the specific phone retry and natural-wallet pacing remain open. |
| AF-009 | Run the physical-phone acceptance pass | Ready to test | Verified v0.7.10 is delivered for stacked ability-card action and Home-cleanup testing. All physical input, readability, save, audio and performance checks remain open, as does the Bakery tray-10 finding. D01–D17 stay Pending; real billing is not tested. |

## Continue one finding at a time

Use the workbook’s **Area checklist** and **Area fixes** tabs. Keep Built, Integrated and Verified separate; a Done fix needs its note, completion date and repair evidence. Preserve the original finding evidence and CHG history.

- [Phone and human playtest protocol](PLINKO/docs/AREA_PLAYTEST.md)
- [Measured legal progression and flagged trays](PLINKO/docs/AREA_PROGRESSION_BALANCE.md)
- [Verified APK record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.10.json)
- [Download details](PLINKO/BUILD_LINKS.txt)
- [Editable launch workbook](outputs/launch-tracker-01a18eec/Sugarfall%20Launch%20Tracker.xlsx)

The six legal simulations used two shopping policies and three seeds. All three areas cleared in every campaign, with no free money or granted nodes. The sample is not a human pacing verdict; review the five unique stall cases before deciding on price/HP changes. No new tuning was justified solely by the sampled cursor policy.

The future-area template remains blank with the two new requirements. Original audit and implementation evidence remain in `verification/area-audit-20261103/` and `verification/area-fixes-20261103/`. Menu-polish evidence remains in `verification/menu-polish-20261103/`; startup records remain in `verification/studio-startup-20261103/`; current screen/flow records are in `verification/screen-polish-20261103/`.
