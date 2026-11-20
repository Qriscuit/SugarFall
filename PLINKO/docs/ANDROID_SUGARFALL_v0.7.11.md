# Sugarfall v0.7.11 Android preview

Delivered 4 November 2026 · `0.7.11-preview` · version code `38` · CHG-046 / AF-010.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Build manifest](ANDROID_SUGARFALL_v0.7.11.json) · [Art integration](AREA_INTERFACE_ART.md)

Gelato Garden and Crystal Candyworks now use their own complete interface sets: buttons, panels, timers, coins, upgrade tiles, tray medallions and selectors. Gelato uses lavender and mint ceramic; Crystal uses pale aqua sugar glass with peach and copper details. Each also has a slightly themed cream-wave painting. Bakery retains its existing artwork.

The panel slices keep live HUD, card and result text inside clear faces. Crystal's selector crest has extra painting space while its text positions and touch target stay fixed. Transition timing, route choices, opaque coverage and Reduced Motion remain supported. Gameplay data, save formats, purchases, audio and the single-pulse startup are unchanged.

The source/desktop pass recorded **1,654 passing checks and 116 captures**, with **48 native/metadata checks** recorded separately. The exact APK passed **1,314 payload checks and 16 Android metadata, signature and alignment checks**. All eight Drive readback checks passed, preserving the existing file ID, folder, URL and owner-only permissions. The connector returned no remote checksum.

| Artifact | Value |
|---|---|
| Filename | `Sugarfall-v0.7.11-Android-Preview-2026-11-04.apk` |
| Size | 98,872,682 bytes |
| SHA-256 | `8d7428cc816ecda81c0a765698f4ccb73750689f1e4f4ca816ad219442715383` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

The preview retains the previous package and signing identity. Install-over save retention, phone readability, touch comfort, motion and performance still require physical testing. The Bakery tray-10/More Jam retest, current legal progression and real Play billing remain open. This delivery does not complete any area or establish phone acceptance.

Earlier preview and public v0.8.0-rc1/rc2 artifacts remain preserved. The storefront review captures predate this interface pass and require current Android comparison before publication. See [source/art validation](AREA_INTERFACE_ART_VALIDATION.json), [native prompts and paths](../../concept-art/area-interface-v1/sources.json), and the exact release manifest for linked audit evidence.
