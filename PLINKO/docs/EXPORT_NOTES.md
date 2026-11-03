# Export and rebuild notes

**Source after v0.7.5 — CHG-036:** Area frames, Jam Burst, shared earned/early signature access and Flow-2 rules are not in the already-delivered preview or public v0.8.0-rc1 artifacts. No new APK/Drive delivery is claimed. The next requested build must verify the new scripts/assets and revised save/ownership behavior. Real Play billing is unfinished; current preview/provider-contract tests do not establish a paid transaction.

## Current Android preview v0.7.5 (3 November 2026)

The existing private Drive APK is now **v0.7.5-preview, code 31**, with the existing preview package and development certificate. Pause has one Paused title and a compact control panel. Settings has one title and a centered, capability-driven layout with no gaps from hidden options. Help uses How to play and Trials uses Trials. Decorative slogans, repeated headings, time-card flavor text and the redundant restored-run toast are removed; mechanics and consequential reset/end-shift instructions remain. It also packages the previously source-only [pause fade/blur](MENU_TRANSITIONS.md) and the [warm studio spotlight, heartbeat and hum](STUDIO_STARTUP.md). Home morph, results and cream routes retain their intended behavior. Balance data and save formats are unchanged.

[Current source and desktop validation](MENU_CLEANUP_VALIDATION.json) passes 1,516 checks with zero failures: 712 functional/regression and 804 GPU assertions, with 81 captures across all three areas at 450×800 and 450×1000. Final runtime/art parity covers 211 inputs. [The APK record](ANDROID_SUGARFALL_v0.7.5.json) and [release note](ANDROID_SUGARFALL_v0.7.5.md) record 517 passing payload checks and 16 passing Android metadata/signing/alignment checks. The artifact is **89,281,899 bytes**, SHA-256 `ed46a5cede73f8574aa2a6234385807b54de100a8b11c65fd8eecc98fd236b0c`. [Drive readback](../../verification/android-upload-v075/verification.json) passes eight metadata checks after replacement in the same private file, with its ID, folder, owner permissions and 89,281,899-byte size verified. No remote checksum was returned. [BUILD_LINKS.txt](../BUILD_LINKS.txt) retains the same private download URL; Windows stays v0.6.1.

All physical installation, retained saves, menu readability/touch, startup audio and pause feel remain Pending. The separate public v0.8.0-rc1 APK/AAB were not rebuilt. Prior release sections below are historical.

## Previous Android preview v0.7.4 (3 November 2026)

The existing private Drive APK is now **v0.7.4-preview, code 29**, retaining the v0.7.3 preview package and signing identity. [Portrait layout](SCREEN_LAYOUT.md) now paints themed scenery across taller displays, fits the Tray status inside its HUD panel and centers all six cup labels on their painted faces. Home Play uses the restored short tray zoom/morph; results appear over a darkened frozen board. Neither action uses a cream wipe. [Ordinary menu navigation](MENU_TRANSITIONS.md) and the [studio heartbeat startup](STUDIO_STARTUP.md) retain their cream transitions, with Reduced Motion skipping movement. Board geometry, collision/reward rules, economy values and save formats are unchanged.

[The current APK record](ANDROID_SUGARFALL_v0.7.4.json) and [release note](ANDROID_SUGARFALL_v0.7.4.md) record **500 payload checks** and **16 Android metadata checks**. The file is **88,969,934 bytes**, SHA-256 `1a319430bd1ccc352ecee7af5635ce03a522c847086148ee31967242084e09d3`. [Upload readback](../../verification/android-upload-v074/verification.json) passed eight metadata checks after replacing the same private Drive file. This verifies file metadata and destination, without claiming a remote checksum comparison. [BUILD_LINKS.txt](../BUILD_LINKS.txt) retains the download URL and unchanged Windows v0.6.1 download.

[Software and desktop validation](../../verification/screen-polish-20261103/validation.json) passed **1,877 checks**: 879 regressions, 163 page/entry/result checks, 58 startup-controller checks, 250 actual isolated-profile checks, 111 HUD/cup checks and 416 renderer checks across 71 captures. The v0.7.3 startup evidence below retains its historical 1,371 software and six separate native-asset checks. Physical Android tall-screen/cutout behavior, installation, install-over-save retention, smoothness and touch comfort remain open. Prior release sections below are historical.

## Previous Android preview v0.7.3 (3 November 2026)

The existing private Drive APK is now **v0.7.3-preview, code 28**, retaining the v0.7.2 preview package and signing identity. The supplied studio stamp replaces the default Godot boot image, then shows a gentle double heartbeat while real resources load. After at least two short cycles and a settled frame, the shared cream wave reveals the restored Home, paused run or unclaimed Result. Saved Reduced Motion keeps the stamp static and skips the presentation delay and wipe once ready. [The startup record](STUDIO_STARTUP.md) documents original-image provenance, real loading, lifecycle/save guards and Android's separate system launch window. Ordinary menu motion and all balance values remain unchanged.

[The current APK record](ANDROID_SUGARFALL_v0.7.3.json) and [release note](ANDROID_SUGARFALL_v0.7.3.md) record **498 payload checks** and **16 Android metadata checks**. The file is **88,957,646 bytes**, SHA-256 `4381dd75f0ae7a44ff13fa05da7f4a91841217fc03ae2b5cc1130fa6bd9a1544`. [Upload readback](../../verification/android-upload-v073/verification.json) passed eight metadata checks after replacing the same private Drive file. This verifies file metadata and destination; it does not claim a remote checksum comparison. [BUILD_LINKS.txt](../BUILD_LINKS.txt) retains the download URL and unchanged Windows v0.6.1 download.

[Software and desktop startup validation](../../verification/studio-startup-20261103/validation.json) passed **1,371 checks**: 735 existing regressions, 90 shared page-transition checks, 58 startup-controller checks, 250 actual isolated-profile checks and 238 renderer checks across 48 captures. Six native-asset checks are separate. The earlier legal progression experiment remains a dated synthetic baseline. Physical Android launch appearance, installation, install-over-save retention, smoothness and touch comfort remain open. Prior release sections below are historical.

## Previous Android preview v0.7.2 (3 November 2026)

The existing private Drive APK is now **v0.7.2-preview, code 27**, retaining the v0.7.1 preview package and signing identity. One native [white-cream wave](MENU_TRANSITIONS.md) covers page changes across Bakery, Gelato and Crystal in 0.62 seconds, with immediate Reduced Motion navigation. This update also adds Home action symbols, a dedicated Settings heading plaque and outlined damage numbers without rectangular backing. Logical transactions remain immediate; gameplay and input wait for visual settlement. The former Home tray morph is superseded in normal presentation. Prices, HP, layouts and economy values are unchanged.

[The current APK record](ANDROID_SUGARFALL_v0.7.2.json) and [release note](ANDROID_SUGARFALL_v0.7.2.md) record package verification. The file is **88,575,758 bytes**, SHA-256 `75ad508806f07ccafbb5bf5700012e6e49a508e4b9e70bbfaa9eba68dc962220`. [Upload readback](../../verification/android-upload-v072/verification.json) passed eight metadata checks after replacing the same private Drive file. [BUILD_LINKS.txt](../BUILD_LINKS.txt) retains the download URL; Windows remains v0.6.1.

[Source and desktop validation](../../verification/menu-polish-20261103/validation.json) passed **1,143 checks**: 715 related regressions, 90 page-transition checks, 331 renderer assertions across 62 captures and seven native-art checks. Final source hashes match the renderer and transition suite. The earlier legal-progression baseline remains separate evidence; no new human pacing claim is made. Physical Android installation, install-over-save behavior, smoothness and touch comfort remain open. Prior release sections below are historical.

## Previous Android preview v0.7.1 (3 November 2026)

The existing private Drive APK is now **v0.7.1-preview, code 26**, with the same package and signing identity as v0.7.0. It fixes Crystal's Prism sound, corrects Gelato Dual Shot Help, adds a cream backing to damage numbers and gives Bakery distinct tray lessons while preserving the exact compatible prior Bakery checkpoints. No prices, HP, board layouts, cadence or economy values changed. [The current APK record](ANDROID_SUGARFALL_v0.7.1.json) records packaging and delivery; [BUILD_LINKS.txt](../BUILD_LINKS.txt) has the unchanged download link. The file is **87,125,393 bytes**, SHA-256 `d1e4f1defc01523479cbdc8f0a859810230ee28b0dcd133f4d6336b089905485`.

Current-source [legal progression measurements](AREA_PROGRESSION_BALANCE.md) completed six linked three-area campaigns, including paid entries, exact mixed-tree purchases, Dual Shot rebuilding and Second Prism, with 9,044 passing legality assertions. Desktop tests and package checks remain separate from physical-phone and human pacing acceptance. Windows remains v0.6.1. Earlier build records below are historical.

## Previous Android preview v0.7.0 (3 November 2026)

This build adds [Crystal Candyworks](CRYSTAL_CANDYWORKS.md): twelve authored straight-shot trays, an independent wallet and upgrade map, a rotating top-center spout with no gravity, and a floating ×2 Prism collected by one tap during its four-second window. Second Prism costs 900 Crystal coins and requires tray 6 plus Power 4. Normal entry follows Gelato tray 12 and costs 1,500 Gelato coins. Developer settings offers all three areas and area-local Infinite money. Seven native ImageGen assets supply the distinct aqua-and-copper theme; [prompts and provenance](../../concept-art/crystal-candyworks-v1/sources.json) preserve their generated bytes. Bakery and Gelato board/economy files remain unchanged.

The APK is `Sugarfall-v0.7.0-Android-Preview-2026-11-03.apk`, version `0.7.0-preview`, code **25**. Package `org.pegfoundry.prototype.preview` and the development signing identity match v0.6.14. Install over the existing preview to retain app data. Profiles write version 5 and accept version 3/4 area records; Bakery and Gelato checkpoints keep schema 4, while Crystal uses schema 5 for Prism state. This is an ARM64 debug preview for Android 7 or newer, target SDK 36, with no requested Android permissions. Ads and purchases remain simulated.

[Source validation](../../verification/crystal-area-20261103/validation.json) passed **2,494 checks across 21 suites**, including 253 art, actual-disk persistence and renderer checks and 40 captures at 720×1280 and 450×800. An additional 216 synthetic pacing runs exercised fixed builds and aiming policies; they do not establish human completion time or economy balance. Disposable test saves and intercepted renderer IO left player profiles untouched. [Package verification](ANDROID_SUGARFALL_v0.7.0.json) records 462 payload checks and 16 Android metadata, signing and alignment checks, with compiled source parity, the seven native Crystal assets, unchanged old-area content fingerprints, official debug libraries and 16 KiB alignment verified. Physical Android installation, touch comfort, contrast and performance remain untested by static export verification.

The existing private Drive APK was replaced in place. Fresh metadata readback verified its ID, folder, filename and **87,121,297-byte** size, with unchanged permissions. The connector supplies no remote checksum. Local SHA-256: `869a1497d4cd3f3a79c7373e4400880b4e26e5aa1282d5dae95ac9ef25363159`. Evidence is under `verification/android-upload-v070`. The current download is in [BUILD_LINKS.txt](../BUILD_LINKS.txt). The Windows preview remains v0.6.1; previous local APKs and manifests are preserved.

## Previous Android preview v0.6.14 (2 November 2026)

This art-only revision replaces Gelato's purple upgrade-map ground with a [pale ceramic garden courtyard](../../concept-art/gelato-ceramic-v1/README.md). The complete native 1024×1536 illustration keeps the existing scenery composition; its outer fade blends into matching ivory. The winding routes, upgrade types, purchase behavior, prices, gameplay and saves are unchanged from v0.6.13. Bakery and other Gelato screens retain their existing art.

The file is Sugarfall-v0.6.14-Android-Preview-2026-11-02.apk, version 0.6.14-preview, code 24. The package and development signing identity match v0.6.13; install over the preview to preserve app data. Profile version 4 and checkpoint schema 4 remain unchanged. It is an ARM64 debug preview for Android 7 or newer, target SDK 36, with no requested Android permissions.

[Focused GPU validation](../../verification/gelato-ceramic-20261102/validation.json) passed 177 checks across 20 captures at 720×1280 and 450×800 with no real player-profile access. Review covered opening, overview, forks, purchase cards, zoom, edge fade and Bakery control. All runtime scripts and layouts match v0.6.13. The earlier full gameplay regression remains historical evidence; it was not rerun for a ground-art change. The prior purple-art color-mask audit does not apply to the ceramic floor. [Package verification](ANDROID_SUGARFALL_v0.6.14.json) records final asset bytes, compiled source parity, obsolete-art exclusions, Android metadata, signing and alignment. Physical Android testing remains open.

The same private Drive file was replaced in place. Fresh metadata readback verified its ID, folder, filename and 73,675,878-byte size, with unchanged permissions. No remote checksum is supplied by the connector. Local SHA-256: `3e2c84bb36092366f0718f66299ea762c1489a7f2144fa10fb251cd96b7c08be`. Evidence is under `verification/android-upload-v0614`. The download is in `../BUILD_LINKS.txt`; Windows remains v0.6.1 and previous local APKs/manifests are preserved.

## Previous Android preview v0.6.13 (2 November 2026)

This APK includes [Gelato's winding mixed upgrade tree](GELATO_U_MAP.md), with node spread 31.5% narrower and 46.6% taller than v0.6.12. Curved routes keep the central Feed entry, lower Dual Shot and long branching topology. New central landmarks and outer garden scenery clear the live tiles and paths. Upgrade families use a fixed authored shuffle; buying a node grants the next aggregate family tier while recording that exact chosen node. Dual requires tray 8 AND six active Power upgrades and costs 3,000 coins.

The file is Sugarfall-v0.6.13-Android-Preview-2026-11-02.apk, version 0.6.13-preview, code 23. Package and development signing identity match v0.6.12. Install over the existing preview to retain app data. [Profile version 4](GELATO_NODE_OWNERSHIP.md) stores exact node ownership and reset Power identities. Legacy profiles migrate without changing wallets, upgrade totals or owned Dual Shot. Older preview builds refuse the new profile format. Gameplay fingerprints, checkpoint schema 4 and Trial rules are unchanged; active runs remain compatible. The previous coin-budget/Impact rebalance, damage numbers, money feedback, ballistic previews and developer controls remain included.

Source validation passed 1,830 checks across 14 headless suites plus 427 GPU checks across 42 captures at phone resolutions. Tests exercised legacy migration, exact same-family choice, save-failure rollback, Twin reset/rebuild, vouchers, independent areas and checkpoint resumption. Tests accessed no real player profile. The package validation in [ANDROID_SUGARFALL_v0.6.13.json](ANDROID_SUGARFALL_v0.6.13.json) checks final runtime sources, map data, native winding artwork, retired-art exclusions, Android metadata, signing identity and 16 KiB alignment. This is an ARM64 debug preview for Android 7 or newer, target SDK 36, with no requested Android permissions. Physical Android installation, touch behavior and new-route purchase pacing remain device tests.

The same private Drive file was replaced in place. Fresh metadata readback verified its ID, folder, name and 73,139,302-byte size, with unchanged permissions. The connector supplies no remote checksum. Local SHA-256: `2aafec44e371260df0c4fb19ac6a416be1a4f04c4d85c37df054bdbd27b2cc32`. Evidence is in `verification/android-upload-v0613` at the workspace root. The existing download link is in `../BUILD_LINKS.txt`; Windows remains v0.6.1. Earlier local APKs and manifests remain preserved.

## Previous Android preview v0.6.12 (2 November 2026)

This APK includes [Gelato's antler upgrade map](GELATO_U_MAP.md): central Feed entry, visible Dual Shot below it, two 14-node routes with forks after steps 3/6/9, six 4–6-node terminal tines, and two tall snaking scenery trees. Apparent side branches become the continuing route. Dual still requires tray 8 AND Power 6 and costs 3,000 coins. The previous coin-budget/Impact rebalance, damage numbers, money feedback, ballistic previews and developer controls remain included.

The file is Sugarfall-v0.6.12-Android-Preview-2026-11-02.apk, version 0.6.12-preview, code 22. The Android preview package and development signing certificate match v0.6.11. Install over the existing preview to retain app data. All 62 saved upgrade identities remain; save fields, gameplay fingerprints and Trial revisions are unchanged from v0.6.11. This map change introduces no additional checkpoint rejection or Trial-score reset. Purchase pacing may change with the route graph and still needs phone testing.

Source validation passed 1,133 checks across six headless suites plus 239 GPU checks across 38 captures at phone resolutions. The package validation in [ANDROID_SUGARFALL_v0.6.12.json](ANDROID_SUGARFALL_v0.6.12.json) checks the final runtime sources, authored map and native antler artwork, retired-art exclusions, Android metadata, signing identity and 16 KiB alignment. This is an ARM64 debug preview for Android 7 or newer, target SDK 36, with no requested Android permissions. No physical phone installation or Android emulator test is claimed.

The same private Drive file was replaced in place. Fresh metadata readback verified its ID, folder, name and 73,331,812-byte size, with unchanged permissions. The connector supplies no remote checksum. Local SHA-256: `1bb0a4a6030d0b645689a2d8e5a91dc6bc225c1935170f893ed7d3bffb90da0d`. Evidence is in `verification/android-upload-v0612` at the workspace root. The existing download link is in `../BUILD_LINKS.txt`; Windows remains v0.6.1. Earlier local APKs and manifests remain preserved.

## Previous Android preview v0.6.11 (2 November 2026)

This APK packages the [coin-budget and Impact rebalance](ECONOMY_REBALANCE.md): six damage coins per ordinary/clock/prism peg, nine per armored peg, existing break rewards, and a first Impact hit at four times Power or six times against armor. It includes the charged Impact aura/trail and burst, actual damage numbers, the gold earned-money grow/twist animation, Reduced Motion support, and the 1,000-coin Gelato entry fee. Existing U-map branches, Twin purchase rules, scenery and ballistic previews remain included.

The file is Sugarfall-v0.6.11-Android-Preview-2026-11-02.apk, version 0.6.11-preview, code 21. The preview package and development signing certificate match v0.6.10, allowing installation over it while retaining app data. Wallets, upgrades, existing Twin/area ownership and completed pending rewards remain. Old unfinished checkpoints return Home under the content-fingerprint guard; old Trial times clear in both areas because combat rules changed. Checkpoint schema 4 and Gelato launcher revision 2 remain; common combat Trial revision is now 1.

Source verification passed 2,442 assertions across 23 regression suites, 17 feedback checks, and 129 GPU checks across 24 captures. Fifteen comparison campaigns completed, with three full production campaigns exactly matching the candidate traces. The APK's payload, Android metadata, signing and alignment results are recorded in ANDROID_SUGARFALL_v0.6.11.json. All current runtime scripts/JSON and required art are checked inside the package; test fixtures, measurement baselines and retired art are excluded. This is an ARM64 debug preview for Android 7 or newer, target SDK 36, with no requested Android permissions. No physical phone installation is claimed.

The same private Drive file was replaced in place. Fresh metadata readback verified its ID, folder, name and 7,35,81,658-byte size while preserving permissions. The connector supplies no remote checksum. Local SHA-256: 91d1948160c50740ca0c8d91aa2e4c731f4c3d150a0e2ef3ea86ec3ff04b0cc1. Upload evidence is in the workspace's verification/android-upload-v0611 folder. The existing download link is in ../BUILD_LINKS.txt. Windows remains the previous v0.6.1 build.

## Previous Android preview v0.6.10 (2 November 2026)

Gelato now has two U-shaped upgrade trunks with six optional three-upgrade branches. All 62 saved family/tier identities remain intact. Branches end without gating continuation along either trunk. Twin launchers move to a Power 6 connection, require tray 8 and Power 6, and cost 3,000 coins. Existing Twin owners keep their ownership and build. Every eligible affordable purchase is green, including Power rebuilds; locked and unaffordable states remain distinct.

The new U-garden v2 illustration places landmarks in reserved scenery space clear of tiles and routes. Its surrounding ground uses the final edge-matched color `d9c1e7`, preventing a visible square boundary when zoomed out. Superseded Gelato arc and U-garden v1 textures are excluded from all export presets while their source files remain. Bakery retains its existing artwork and upgrade arc.

The APK is `Sugarfall-v0.6.10-Android-Preview-2026-11-02.apk`, version `0.6.10-preview`, code 20. Its package `org.pegfoundry.prototype.preview` and development signing certificate match v0.6.9. Install over the previous preview to retain app data. Campaign money, upgrades, existing Twin ownership and area progress remain.

The Gelato content fingerprint changes because three shop fields changed: Twin cost 600→3,000, tray requirement 5→8 and Power requirement 3→6. Flight, rewards and existing builds are unchanged. A narrowly pinned old/new fingerprint pair preserves compatible interrupted runs; later unrelated content changes do not receive that exception. Forty-five migration checks use real v0.6.9 single-launcher, Twin and Trial runtime fixtures. Checkpoint schema 4 and Gelato Trial rules revision 2 remain unchanged.

The final source pass completed 2,407 assertions across nineteen regression suites, 161 renderer checks across 44 reviewed captures, and 375 landmark-clearance checks. All 34 runtime script/JSON hashes and the artwork match the final tested/rendered source. The final ground-color adjustment was retested in two affected suites and rendered again. The APK passed 341 payload checks and 16 Android metadata/signature/alignment checks, including all 27 runtime scripts/seven JSON files, branch graph, later Twin requirements, exact final artwork/color, retired-art exclusions and the exact checkpoint fingerprint pair computed from the previous/new APK bytes. It remains a debug ARM64 build for Android 7 or newer, target SDK 36, with the same signing identity and no requested Android permissions. Static verification does not claim phone installation or emulator execution.

The existing Drive APK was replaced in place. Fresh metadata readback verified the new name and 73,573,142-byte size while preserving its file ID, folder and private permissions. The connector does not expose a remote checksum. The final local SHA-256 is `11163b5cd828b4fbd63f3585895112df6ff364fa027b10c044d9506ce611fb74`; complete evidence is recorded in `ANDROID_SUGARFALL_v0.6.10.json`. Earlier local attempts are archived under `verification/android-preview-v0610` at the workspace root and were never uploaded. The download link is in `../BUILD_LINKS.txt`. Only Android was rebuilt; the published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.10-Android-Preview-2026-11-02.apk"

## Previous Android preview v0.6.9 (2 November 2026)

Twin launchers are now a selectable tile on Gelato's upgrade map, connected to Power 3. The tile follows map selection, panning, zooming and ownership feedback. Its purchase still requires tray 5 and Power 3, costs 600 coins, and performs the same one-time Power reset. Existing Twin owners keep their ownership. The tile reuses the existing saved flag; the original 62 family/tier identities remain intact.

Upgrade cards now use short descriptions of what each upgrade does. Normal and Twin cards have explicit padded text/button regions, and the normal Buy button is taller so its label stays comfortably readable. Twin shot guides use separate teal and plum curves so each launcher's path is easier to follow. Flight physics and timing are unchanged. The Gelato U garden, independent area progress and **Developer settings → Infinite money** remain available.

The APK is `Sugarfall-v0.6.9-Android-Preview-2026-11-02.apk`, version `0.6.9-preview`, code 19. Its package `org.pegfoundry.prototype.preview` and development signing certificate match v0.6.8. Install over the existing preview to retain app data. Campaign money, upgrades, Twin ownership and area progress remain. Gameplay fingerprint inputs and checkpoint/Trial schemas are unchanged from v0.6.8; no new saved upgrade family is introduced.

The final source pass completed 2,222 assertions across seventeen regression suites. Renderer verification passed 258 checks across sixty reviewed captures: 139 checks/46 map captures and 119 checks/14 flight captures. The final Buy-button adjustment was rerun in five affected suites and rendered again. All 34 runtime script/JSON hashes match final source. The APK passed 330 payload checks and 16 Android metadata/signature/alignment checks, covering all 27 runtime scripts and seven JSON files, current resources, exclusions, unchanged signing identity and the official debug runtime. It remains ARM64-only, Android 7 or newer, target SDK 36, with no requested Android permissions. Static verification does not claim phone installation or emulator execution.

The existing Drive APK was replaced in place. Fresh readback verified the new name and 74,801,942-byte size while preserving its file ID, folder and private permissions. The connector does not expose a remote checksum. Local hashes and upload evidence are recorded in `ANDROID_SUGARFALL_v0.6.9.json`; the download link is in `../BUILD_LINKS.txt`. The earlier export from before the final button adjustment is archived under `verification/android-preview-v069/first-attempt` at the workspace root and was never uploaded. Only Android was rebuilt; the published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.9-Android-Preview-2026-11-02.apk"

## Previous Android preview v0.6.8 (2 November 2026)

Gelato's upgrade map now starts at bottom-center Feed 1 and rises along two independent mixed upgrade routes on the arms of a U-shaped hyperbola. All 62 family/tier identities and existing ownership are retained. A new square U-garden illustration and per-area world bounds support the layout. Bakery keeps its 120-degree arc and existing artwork. The retired Gelato arc artwork is excluded from the APK without deleting its source file.

**Home menu → Settings → Developer settings** now includes **Infinite money** for the current area. Eligible normal upgrades and Twin launchers can be purchased without spending that area's real wallet. Upgrade prerequisites and Twin unlock requirements still apply. Purchased upgrades remain saved; the area-specific testing toggle resets on restart. The same screen retains the area switcher, with fresh first visits and saved progress on return. Developer controls are enabled in this debug APK and remain hidden in normal releases unless deliberately tagged `developer`.

The APK is `Sugarfall-v0.6.8-Android-Preview-2026-11-02.apk`, version `0.6.8-preview`, code 18. Its package `org.pegfoundry.prototype.preview` and development signing certificate match v0.6.7, allowing installation over the previous preview while retaining app data. Campaign money, upgrades, area progress and existing upgrade identities remain. Gameplay fingerprint inputs, checkpoint schema and Trial schema are unchanged from v0.6.7. The previously verified gravity-solved Gelato aim and curved trajectory guide are retained.

The final source pass completed 1,961 assertions across eighteen regression suites and 266 renderer checks across 38 visually reviewed captures. All 34 runtime script/JSON hashes match the tested source. Package verification passed 330 payload checks and 16 Android metadata/signature/alignment checks, including all 27 runtime scripts and seven top-level JSON files, the two-route U graph/layout, new garden art/bounds and retired-art exclusion. Captured source inputs remained unchanged through export. The official debug runtime, unchanged signing identity, ARM64-only architecture, Android 7 minimum, target SDK 36 and absence of requested Android permissions were verified. Static verification does not claim phone installation or emulator execution.

The existing Drive APK was replaced in place. Fresh metadata readback verified the new name and 74,806,038-byte size while preserving its file ID, parent folder and private permissions. The connector does not expose a remote checksum; local hashes and upload evidence are recorded in `ANDROID_SUGARFALL_v0.6.8.json`. The download link is in `../BUILD_LINKS.txt`. Only Android was rebuilt; the published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.8-Android-Preview-2026-11-02.apk"

## Previous Android preview v0.6.7 (2 November 2026)

Gelato aiming now solves the downward, gravity-affected flight to the reachable finger position. The launcher keeps its normal speed while the aim adjusts for the falling arc. A curved dotted guide shows the same trajectory used by actual shots and stops at the reachable target or first peg contact. Both Twin launchers use a shared reachable target. Initial launcher jitter is removed and Gelato free flight uses exact gravity integration. Bakery retains its existing dispenser behavior.

The APK is `Sugarfall-v0.6.7-Android-Preview-2026-11-02.apk`, version `0.6.7-preview`, code 17. It retains package `org.pegfoundry.prototype.preview` and the same development signing certificate as v0.6.6. Install over the previous preview to retain app data. Campaign money, upgrades, Twin ownership and area progress remain. Old Gelato Trial times are cleared for trajectory rules revision 2; Bakery Trial records remain. This debug APK retains **Settings → Developer areas** for directly testing Gelato.

The source passed 1,180 assertions across twelve isolated regression suites, including actual free-flight checks at 60 and 120 Hz against independent ballistic equations. Seventy-five renderer checks and sixteen visually reviewed captures cover single/twin trajectories, reachable limits, peg contact, Reduced Motion and the Bakery baseline. The APK passed 315 payload checks and 16 Android metadata/signature/alignment checks. All 26 runtime scripts, current JSON and imported resources are packaged; captured source inputs remained unchanged across export. The official debug runtime, unchanged signing identity, ARM64-only architecture, Android 7 minimum, target SDK 36 and absence of requested Android permissions were verified. Phone installation and emulator execution remain outside static build verification.

The existing Drive APK was replaced in place. Fresh metadata readback verified the updated name and 74,240,545-byte size while preserving the same file ID, folder and private permissions. The connector does not return a remote checksum. Local hashes and upload evidence are recorded in `ANDROID_SUGARFALL_v0.6.7.json`; the download link is in `../BUILD_LINKS.txt`. Only Android was rebuilt; the Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.7-Android-Preview-2026-11-02.apk"

## Previous Android preview v0.6.6 (2 November 2026)

This APK includes **Home menu → Settings → Developer areas**. Choose **Start fresh** to open an unvisited area at tray 1 with zero coins and no upgrades, or **Continue** to restore its own saved wallet, upgrades and progress. Developer entry skips Bakery completion and the Gelato entry fee; later visits and restarts retain each area's build. This debug APK enables the control, while normal release builds hide it unless deliberately tagged `developer`.

Both campaigns now use Bronze, Silver, Gold and Diamond peg strength bands across trays 1–12. Gelato has a top-center launcher aiming down toward the finger, gravity-based trajectories, twelve fan layouts and separate economy tuning. Its Twin launchers upgrade resets Power, keeps other upgrades, and offers stronger, more expensive red Power rebuild nodes. The export explicitly includes `data/gelato_economy.json`. The build also includes the current single canonical save, confirmed Reset progress, Mabel introduction, countdown feedback and result comparison screens.

The APK is `Sugarfall-v0.6.6-Android-Preview-2026-11-02.apk`, version `0.6.6-preview`, code 16. It retains package `org.pegfoundry.prototype.preview` and the same development signing certificate as v0.6.5. Install over the previous Sugarfall preview to retain app data. It targets ARM64 phones on Android 7 or newer, target SDK 36, and requests no Android permissions. Ads and purchases remain simulated.

The latest source verification passed 936 assertions across eleven isolated suites, plus 65 renderer checks across sixteen visually reviewed desktop/phone-size captures. The APK passed 314 payload checks and 16 Android metadata/signature/alignment checks. All 26 current runtime scripts, JSON data, Mabel/result art and current imported resources are packaged; captured source inputs remained unchanged during export. Packaged ARM64 libraries exactly match the official debug template, confirming that this build enables developer tools. Physical Android installation and emulator execution remain untested by build verification.

The existing Drive APK was replaced in place. Fresh metadata readback verified its file ID, folder, private permissions, updated name and 74,236,449-byte size. The connector does not return a remote checksum. Exact local hashes, package verification and upload evidence are in `ANDROID_SUGARFALL_v0.6.6.json`; the download link is in `../BUILD_LINKS.txt`. Only Android was rebuilt; the published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.6-Android-Preview-2026-11-02.apk"

## Historical source milestone: single save and Reset progress (26 October 2026)

This source milestone replaced Main/Fresh Test selection with **Settings → Reset progress**, followed by a destructive confirmation. A successful reset starts Bakery tray 1 with Mabel, clears gameplay and simulated purchase/ad state, and retains Sound and Reduced Motion. The canonical file is `user://sugarfall_save.json` with the existing version 3 area schema. First launch migrates the previously selected older campaign without resetting it; later launches use the canonical save. See [README](../README.md#start-over-or-replay-the-introduction) and [the reset design](NEW_PLAYER_EXPERIENCE_GDD.md#reset-progress).

The v0.6.6 Android preview above now includes this behavior. Older artifacts below retain their historical Main/Fresh Test filenames and tests.

## Previous Android preview v0.6.5 (25 October 2026)

After buying an upgrade, the map automatically selects its newly revealed direct successor when exactly one is available. The purchase panel immediately shows that upgrade's icon, tier, effect and Buy price or remaining shortfall, with a brief bounce. Another deliberate Buy tap can purchase it immediately, even during the camera glide or panel animation. Feed 1's three new routes still require the player to choose one; final and failed purchases never jump to another route. Reduced Motion updates the panel without displacement. Camera framing, discovery, prices and saved progress are preserved.

The APK is `Sugarfall-v0.6.5-Android-Preview-2026-10-25.apk`, version `0.6.5-preview`, code 15. It retains package `org.pegfoundry.prototype.preview` and the same development signing certificate as v0.6.4. Install over the existing preview to preserve app data. It targets ARM64 phones on Android 7 or newer, target SDK 36, and requests no Android permissions. Ads and purchases remain simulated.

The change passed 482 source assertions across graph, map and Bakery/Gelato navigation checks, plus 16 production-rendered phone captures with zero player-profile accesses. The build passed 279 payload checks and 16 Android metadata/signature/alignment checks. Both scene backgrounds and current runtime resources were verified inside the APK, and source inputs stayed unchanged during export. Physical Android installation and emulator execution remain untested by build verification. Artifact hashes and upload details are recorded in `ANDROID_SUGARFALL_v0.6.5.json`; the download link is in `../BUILD_LINKS.txt`.

Only Android was rebuilt in this pass. The latest published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.5-Android-Preview-2026-10-25.apk"

## Previous Android preview v0.6.4 (25 October 2026)

A successful upgrade purchase now eases the camera toward newly revealed upgrades over 0.55 seconds, framing them clear of fixed controls. The first three choices are framed together, with a zoom-out only if needed. Manual map input interrupts the move, leaving the map or losing focus cancels it, and Reduced Motion frames the reveal immediately. The purchased tile remains selected. Discovery rules, background art, authored positions, costs and saved progress are preserved.

The APK is `Sugarfall-v0.6.4-Android-Preview-2026-10-25.apk`, version `0.6.4-preview`, code 14. It retains package `org.pegfoundry.prototype.preview` and the same development signing certificate as v0.6.3. Install over the existing preview to preserve app data. It targets ARM64 phones on Android 7 or newer, target SDK 36, and requests no Android permissions. Ads and purchases remain simulated.

The change passed 455 source assertions across graph, map and Bakery/Gelato navigation checks, plus 24 production-rendered phone captures with zero player-profile accesses. The build passed 279 payload checks and 16 Android metadata/signature/alignment checks. Both scene backgrounds and current runtime resources were verified inside the APK, and source inputs stayed unchanged during export. Physical Android installation and emulator execution remain untested by build verification. Artifact hashes and upload details are recorded in `ANDROID_SUGARFALL_v0.6.4.json`; the download link is in `../BUILD_LINKS.txt`.

Only Android was rebuilt in this pass. The latest published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.4-Android-Preview-2026-10-25.apk"

## Previous Android preview v0.6.3 (25 October 2026)

The upgrade map now shows purchased upgrades and only the next eligible upgrade on each route. Buying an upgrade reveals its successor and connecting line; deeper upgrades and connections stay hidden. The next upgrade remains visible even when unaffordable. The approved illustration, 120-degree layout, three single-parent routes and existing owned progress remain intact.

The APK is `Sugarfall-v0.6.3-Android-Preview-2026-10-25.apk`, version `0.6.3-preview`, code 13. It retains package `org.pegfoundry.prototype.preview` and the same development signing certificate as v0.6.2. Install over the existing preview to preserve app data. It targets ARM64 phones on Android 7 or newer, target SDK 36, and requests no Android permissions. Ads and purchases remain simulated.

The change passed 472 source assertions across self-test, graph, map, Bakery/Gelato navigation and layout checks, plus eight production-rendered phone captures with zero player-profile accesses. The build passed 279 payload checks and 16 Android metadata/signature/alignment checks. Both scene backgrounds and current runtime resources were verified inside the APK, and source inputs stayed unchanged during export. Physical Android installation and emulator execution remain untested by build verification. Artifact hashes and upload details are recorded in `ANDROID_SUGARFALL_v0.6.3.json`; the download link is in `../BUILD_LINKS.txt`.

Only Android was rebuilt in this pass. The latest published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.3-Android-Preview-2026-10-25.apk"

## Previous Android preview v0.6.2 (25 October 2026)

Android Preview now contains the compact 120-degree upgrade arc: 62 preserved upgrade tiers on three independent mixed routes, 61 straight connections and one prerequisite per later upgrade. The map uses one complete illustrated background for each area, with larger buildings and sage/lavender courtyards. Live upgrade tiles and route lines stay separate. Retired modular scenery is excluded from the APK while its source files remain in the project.

The APK is `Sugarfall-v0.6.2-Android-Preview-2026-10-25.apk`, version `0.6.2-preview`, code 12. It retains package `org.pegfoundry.prototype.preview` and the same development signing certificate as v0.6.1. Install over the existing preview to preserve app data. It targets ARM64 phones on Android 7 or newer, target SDK 36, and requests no Android permissions. Ads and purchases remain simulated.

The build passed 279 payload checks and 16 Android metadata/signature/alignment checks. Current JSON, both imported scene backgrounds and runtime resources were verified in the APK, and source inputs stayed unchanged during export. The latest source pass had 382 focused checks and 24 graphics captures; the final Bakery palette received another 24 art checks. Physical Android installation and emulator execution remain untested. Artifact hashes and upload details are recorded in `ANDROID_SUGARFALL_v0.6.2.json`; the download link is in `../BUILD_LINKS.txt`.

Only Android was rebuilt in this pass. The latest published Windows preview remains v0.6.1.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.2-Android-Preview-2026-10-25.apk"

## Windows v0.6.1 and previous Android v0.6.1 (24 October 2026)

Both previews include the clean winding upgrade map: 62 preserved upgrade tiers and 81 local fork-and-join connections, with no crossings, overlaps or routes through unrelated tiles. The first recipe is framed for a phone, selected ingredients share a mint outline, and red/green affordability, bounce feedback and pinch/wheel zoom remain. Twenty-four fixed irregular peg layouts cover Bakery and Gelato Garden. Power gains taper to a 4.55 damage cap, and Gelato entry costs 40,000 Bakery coins. See `CLEAN_UPGRADE_MAP.md`.

Windows is a portable x86_64 release with an embedded PCK, file version 0.6.1.0 and product version 0.6.1. Extract the ZIP and open `Sugarfall.exe`; no Godot installation is needed. The EXE is unsigned. The archive includes the README and complete engine/font notices.

Android Preview exports `0.6.1-preview`, version code 11, package `org.pegfoundry.prototype.preview`, using the same development signing identity as v0.6.0. Install over the previous preview to retain app data. ARM64, Android 7 or newer, target SDK 36, with no requested Android permissions. Ads and purchases remain a local simulator.

Existing owned upgrades, coins, vouchers, area progress and permanent purchases are retained. New purchases use the revised local prerequisites. An unfinished v0.6.0 checkpoint safely returns Home because its board/balance fingerprint differs; start a fresh attempt with the new layout. Version 3 area saves and the legacy desktop save directory remain unchanged. Old local builds and their manifests are retained.

The current design passed 600 relevant regression checks across eight isolated suites, 14 native renderer captures and nine bounded pacing scenarios. These do not establish human hours-to-clear. Export validation passed 199 Windows PCK checks, two native EXE smoke cases (including 16 self-tests and actual OpenGL startup), 5 PE metadata checks, 14 ZIP checks, 259 Android payload checks and 16 Android metadata/signature/alignment checks. All 17 compiled runtime scripts match between Windows and Android. Physical Android installation remains untested.

The existing Drive ZIP and APK were replaced in place and read back with matching names, sizes, original IDs, folder and private permissions. Current links are in `../BUILD_LINKS.txt`; exact hashes and evidence are in `WINDOWS_SUGARFALL_v0.6.1.json` and `ANDROID_SUGARFALL_v0.6.1.json`.

From the workspace root, after creating the Windows output directory:

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-release Windows "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.1-Windows-Preview-2026-10-24/Sugarfall.exe"
    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.1-Android-Preview-2026-10-24.apk"

## Previous Sugarfall previews v0.6.0 (24 October 2026)

The Windows and Android previews include Gelato Garden's 33 new art assets, twelve authored boards, lavender menus and backgrounds, wafer damage sprites, and area-specific food names. Clear Bakery tray 12 and collect the result, then enter Gelato through the journey gate for 400,000 Bakery coins. Gelato starts with its own wallet and upgrade build; Bakery progress and permanent test purchases remain. Owned areas can be revisited without another fee or reset. See `GELATO_GARDEN.md`.

The Windows preset exports a portable x86_64 release with an embedded PCK, version 0.6.0.0. Extract the ZIP and open `Sugarfall.exe`; no Godot installation is needed. The executable is unsigned. The archive includes the README and full engine/font notices.

Android Preview exports `0.6.0-preview`, version code 10, package `org.pegfoundry.prototype.preview`, using the existing development signing identity. Install over the previous preview to keep its package-private app data. ARM64, Android 7 or newer. Ads and purchases still use the local simulator; no production accounts or SDKs were added.

In the historical v0.6.0 package, version 3 profiles separate area records and preserve permanent purchases, settings and lifetime run/ad identities. Existing version 1/2 files migrate as Bakery and are retained. That package uses `sugarfall_areas_v3.json` and `sugarfall_fresh_test_areas_v3.json`; the desktop save directory stays unchanged. Current source uses the canonical single save described above. Earlier versions cannot read newer area progress.

The source passed 965 regression checks and 714 art/UI checks with 48 rendered captures. Exported-package validation is recorded in `WINDOWS_SUGARFALL_v0.6.0.json` and `ANDROID_SUGARFALL_v0.6.0.json`. Physical Android installation and a full human Gelato pacing playthrough remain untested.

From the workspace root, after creating the Windows output directory:

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-release Windows "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.0-Windows-Preview-2026-10-24/Sugarfall.exe"
    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.6.0-Android-Preview-2026-10-24.apk"

## Previous Sugarfall Windows preview v0.5.4 (23 October 2026)

The `Windows` preset exports a portable x86_64 release with the Sugarfall icon and version metadata, an embedded PCK, and the current food/UI/environment artwork. The ZIP contains `Sugarfall.exe`, a short README and engine/font notices. Extract the full ZIP before launching the executable; no Godot installation is required.

This build raises upgrade prices, adds the visible 400,000-coin next-area goal, and stops the feeder when the last cookie breaks. Remaining food and final-hit pomegranate seeds reach cups before results; the last catch gets its full 320 ms response. Collect returns Home. The next area stays unavailable and cannot charge coins or reset upgrades. Pacing assumptions and simulation limits are documented in `PACING_v0.5.4.md`.

Desktop saves remain in `%APPDATA%/Godot/app_userdata/Peg Foundry`. Active-run schema 2 persists the drain and catch-settle state; schema 1 checkpoints migrate. A pinned previous/current content-fingerprint pair permits only this release's exact price-only economy update to resume old active runs. Unrecognized content remains rejected. Ads and purchases still use the local test service.

From the workspace root, after creating the output directory:

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-release Windows "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.5.4-Windows-Preview-2026-10-23/Sugarfall.exe"

Matching official Godot 4.6.3 Windows templates are installed in the portable editor data directory. Resource metadata and the icon are written by Godot's built-in resource editor. The EXE is unsigned. `WINDOWS_SUGARFALL_v0.5.4.json` records exact artifact hashes, completed verification and the Drive destination.

## Previous Sugarfall Android preview v0.5.4 (23 October 2026)

The `Android Preview` preset exports `0.5.4-preview` (code 9), retaining package `org.pegfoundry.prototype.preview`, the Sugarfall icon and the existing development signing key. It updates the prior Sugarfall previews in place. The game code and economy match the tested Windows v0.5.4 source: higher upgrade costs, a visible locked next-area requirement, final-food draining and the full last-catch response before results.

This is an ARM64 APK for Android 7 or newer, with no requested Android permissions. Ads and purchases remain simulated. Package verification and update compatibility are recorded in `ANDROID_SUGARFALL_v0.5.4.json`; physical phone installation is not tested. The existing Drive APK is replaced in place, retaining its file ID, folder, download link and private access.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.5.4-Android-Preview-2026-10-23.apk"

## Previous Sugarfall Android preview v0.5.3 (23 October 2026)

The `Android Preview` preset now exports version `0.5.3-preview` (code 8), retaining the Sugarfall name, package, icon and signing identity. This update adds 12 cookie damage PNGs, removes peg health rings, returns Home after Collect, and lets completed taps on the Home tray start the normal entrance. Gameplay remains frozen until the entrance has settled; donuts retain their initial 0.25-second delay afterward.

The final APK passed 163 package checks and signature/alignment verification. Focused behavior suites passed 427 checks, and renderer checks passed 196, including small cookie sprites and Home-to-play captures at 720x1280 and 450x800. Phone installation remains untested. The Drive file was replaced in place; current hashes and destination are in `ANDROID_SUGARFALL_v0.5.3.json`.

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.5.3-Android-Preview-2026-10-23.apk"

## Previous Sugarfall Android preview v0.5.2 (23 October 2026)

The `Android Preview` preset now exports **Sugarfall**, version `0.5.2-preview` (code 7), with a generated donut-and-cookie app icon and explicit legacy, adaptive and themed launcher resources. It retains package `org.pegfoundry.prototype.preview` and the previous preview's signing certificate, allowing an update over v0.5.1. The old Peg Foundry prototype package remains separate. Desktop user data stays in the legacy Peg Foundry directory; Android continues using the same package-private data directory.

From the workspace root:

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/Sugarfall-v0.5.2-Android-Preview-2026-10-23.apk"

The APK replaces the previous preview's bytes in Drive while retaining its file ID, folder, and private sharing. Current details are in `ANDROID_SUGARFALL_v0.5.2.json`; verification evidence is in the workspace's `verification/sugarfall-branding/`. Icon prompts and provenance are in `data/art/branding/sources.json`. Phone installation and gameplay remain untested; ads and purchases remain simulated.

## Previous Android preview v0.5.1 (23 October 2026)

The `Android Preview` preset produces the current food-art build as `Peg Foundry Preview`, version `0.5.1-preview` (code 6), package `org.pegfoundry.prototype.preview`. This separate identity preserves the older installed app and its saves because the older APK's signing key is not available locally. The preview begins with separate progress. Ads and purchases use the test service.

The preview uses the workspace Godot 4.6.3 portable installation, matching official Android templates, installed Java 21.0.12, and Android SDK build-tools 36.1.0. It targets SDK 36 with minimum SDK 24 and ARM64 only. The final manifest requests no Android permissions. The development keystore stays in the local Godot editor data; it is not included in the APK or uploaded to Drive.

From the workspace root, rebuild with:

    ./tools/Godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path PLINKO --export-debug "Android Preview" "C:/Users/Hursh/Documents/Plinko/PLINKO/builds/PegFoundry-v0.5.1-Android-Preview-2026-10-23.apk"

The final APK passed signature v2/v3 verification, 16 KiB ZIP alignment checks, and all 72 payload checks. Current artwork, runtime scripts, JSON data, fonts and license files were checked; development materials and keys are excluded. This is packaging validation; installation and gameplay on an Android phone have not been tested. Exact artifact hashes and the verified Drive destination are recorded in `ANDROID_PREVIEW_v0.5.1.json`. Evidence is in the workspace's `verification/android-preview-v051/` directory.

The sections below describe the historical v0.5 exports.

## Version and verification

Peg Foundry 0.5.0 was exported with Godot 4.6.3. Android is ARM64-only and development-signed, package `org.pegfoundry.prototype`, minimum SDK 24 (Android 7), target SDK 36. The final binary manifest requests no Android permissions. APK ZIP integrity and v2/v3 signatures passed. The authored board/economy JSON and both full engine-notice files were confirmed byte-identical inside the APK.

Historical v0.2 Linux export passed a headless startup smoke test; v0.5 exports here are Android and Windows. The project also received actual desktop GUI gameplay testing. The v0.5 Windows export was not run on Windows. No physical Android device or emulator was available. Export success is not proof of device installation, touch feel, cutout behavior, GPU frame rate, battery performance or store acceptance.

The export manifest accompanying the builds contains exact sizes, SHA-256 hashes and test coverage. Source and export-configuration hashes were unchanged during the final build.

## Rebuild from source

1. Install [Godot 4.6.3](https://github.com/godotengine/godot-builds/releases/tag/4.6.3-stable) and its matching official export templates.
2. Import `project.godot`; run the main scene with F6/F5.
3. The delivered source presets use standard installed-template lookup. Choose Project → Export, then Android, Windows, Linux or Web.
4. Configure platform tooling in Godot Editor Settings. Android needs Java and a supported Android toolchain plus a development keystore. Review vendor terms before installing tooling that requires acceptance.
5. Export Android in debug mode for private testing. Never use the prototype development identity for a store release. Export Windows, Linux and Web in release mode.
6. Keep Android ETC2/ASTC texture import enabled. Preserve the explicit export include filters for `data/*.json` and `data/licenses/*.txt`.
7. Serve Web files through HTTP; opening the HTML directly using `file://` is not a supported launch method.

Example after local tools/templates are configured:

    godot --headless --path . --export-debug Android builds/PegFoundry-Android-debug.apk
    godot --headless --path . --export-release Windows builds/PegFoundry-Windows.exe
    godot --headless --path . --export-release Linux builds/PegFoundry-Linux.x86_64
    godot --headless --path . --export-release Web builds/web/index.html

Create output directories first. The source archive contains no toolchain, downloaded templates, signing key, user save or generated binary.

## Tooling used for these exports

The build used official Godot templates and Java 21. Android's prebuilt-template flow used actual Apache-licensed AOSP adb 34.0.5 and apksigner/apksig 35.0.2 packaged by Debian, extracted into a local tooling directory. No proprietary Google SDK installer agreement was accepted. This limited path does not provide Gradle, NDK compilation, custom Android plugins or an emulator.

Primary sources:
- [Official Godot templates](https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz)
- [Godot Android export documentation](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html)
- [Debian Android platform tools](https://deb.debian.org/debian/pool/main/a/android-platform-tools/)
- [Debian apksigner/apksig](https://deb.debian.org/debian/pool/main/a/android-platform-tools-apksig/)
- [Debian Android BoringSSL dependency](https://deb.debian.org/debian/pool/main/a/android-platform-external-boringssl/)

## Notices and source packaging

Full Godot MIT and bundled-component copyright notices are included in both `docs/licenses/` and packaged `data/licenses/`. The in-game Model screen identifies the engine and its licensing page. Preserve applicable notices when redistributing builds.

The source archive uses an explicit allowlist: project configuration, scenes, original scripts, data, notices, reproducible tests and user-facing documentation. It excludes `.godot`, QA saves/screenshots, generated test telemetry/logs, downloaded tools/templates, signing keys, report-render intermediates and binaries. The original game's source is not included, and no ownership/license claim is made over another game's work.
