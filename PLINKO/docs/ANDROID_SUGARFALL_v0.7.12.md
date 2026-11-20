# Sugarfall v0.7.12 Android preview

Delivered 4 November 2026 · `0.7.12-preview` · version code `39` · CHG-047 / AF-011.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Build manifest](ANDROID_SUGARFALL_v0.7.12.json) · [Layout record](UPGRADE_LAYOUT.md)

Gelato's button labels, Home action symbols and tray-selector labels now sit lower within their painted reading faces. Primary buttons move 2 logical pixels, secondary buttons 4, and the selector 4. Touch rectangles and native artwork remain unchanged.

On all three upgrade maps, selecting an available ordinary node replaces its icon with the required coin amount. This includes unaffordable nodes. The lower card retains the upgrade's name, effect and purchase price. Unowned signature nodes show the earned coin amount while the card explains its gate and paid alternative; available More Jam shows Free. Owned artwork/checks remain, and icons return when selection changes.

Signature cards are 224 logical pixels tall. The title and description sit together on the left, with coin and early-unlock actions stacked on the right. Body text stays at least 19 px and price labels at least 24 px in the checked layouts. Confirmation, cancellation, pending, restore, owned, unavailable and localized prices are covered. Gelato's existing tradeoff is stated as “Two slower launchers. Power resets.” Prices and ability effects are unchanged.

The source/desktop pass records **1,750 passing checks and 156 captures**, with 270 matching source inputs and zero normal-profile access. The exact APK passed **1,318 payload checks and 16 Android metadata, signature and alignment checks**. A separate 17-check comparison confirms that the four changed UI scripts are present in the APK. Eight Drive readback checks preserve the existing file ID, folder, URL and permissions. The connector returned no remote checksum.

| Artifact | Value |
|---|---|
| Filename | `Sugarfall-v0.7.12-Android-Preview-2026-11-04.apk` |
| Size | 98,872,682 bytes |
| SHA-256 | `8047891e85e9098eee6a5309b235e7bd26165827172092c6e19545d451762951` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

The APK retains the preview package/signing identity and updates code 38 to 39. Four native interface/wave PNGs and their imported payloads, ten gameplay JSONs, save formats, audio and the single-pulse startup remain supported. Earlier preview and public release artifacts are preserved.

Phone readability, touch comfort, performance and install-over save retention remain open. The Bakery tray-10/More Jam retest, current natural-wallet progression and real Play billing are separate pending work. This delivery does not establish phone acceptance or area completion. See [layout validation](UPGRADE_LAYOUT_VALIDATION.json) and the manifest for exact audit links.
