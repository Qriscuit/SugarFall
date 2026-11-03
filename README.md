# Sugarfall

CHG-039 delivers [v0.7.7-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.7.json), including the new action sounds and slower studio pulse/hum. Phone acceptance and the [remaining Google Play work](PLINKO/docs/GOOGLE_PLAY_READINESS.md) stay open.

CHG-037 delivers [v0.7.6-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.6.json), including the area frames, signature abilities and Flow-2 source work. Real billing, current legal progression and phone acceptance remain open.

A portrait arcade game built in Godot, with three themed areas: Bakery, Gelato Garden and Crystal Candyworks. Each area has its own twelve trays, upgrade map, economy, art and ball mechanics.

Open **`PLINKO/project.godot` in Godot 4.6.3**. The entry scene is `startup.tscn`; it loads the game behind the studio heartbeat and cream reveal. Keyboard/mouse desktop controls support development; Android phone acceptance remains part of the release checklist.

The current private test download is **v0.7.7-preview (code 33)**, with new action audio and slower startup plus the existing area/menu work. See [the verified APK record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.7.json) and [download links](PLINKO/BUILD_LINKS.txt). The separate public v0.8.0-rc1 APK/AAB remain unchanged; phone acceptance is still open.

## Production records

- [Google Play release queue](PLINKO/docs/GOOGLE_PLAY_READINESS.md): official requirements checked 3 November 2026 and the remaining work.
- [Area template](AREA_CHECKLIST.md): use this before building another area.
- [Area status](AREA_STATUS.md): built, integrated and verified are separate states.
- [Launch tracker](outputs/launch-tracker-01a18eec/Sugarfall%20Launch%20Tracker.xlsx): outstanding fixes and change history.
- [Game and design notes](PLINKO/README.md): mechanics and earlier preview deliveries.
- [Signing and recovery](PLINKO/docs/RELEASE_SIGNING.md): release identity and private local key handling.
- [Source backup verification](PLINKO/docs/SOURCE_CONTROL.md): GitHub tag and independently recovered checkout.
- [Third-party notices](PLINKO/THIRD_PARTY_NOTICES.md): engine and font attribution.

## Building and testing

Install the matching Godot 4.6.3 export templates. Configure your own Android SDK and JDK in Godot's editor settings; machine-specific tools are excluded from this repository. See [Godot's Android export instructions](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html).

The Android Preview preset retains the development package `org.pegfoundry.prototype.preview`. Public release candidates use **`com.qriscuit.sugarfall`** and the `sugarfall_public` feature. They install separately from previews. The public build disables simulated commerce and developer controls. Real ads, billing and Play Console release steps still need implementation or completion before a monetized public launch.

Tests live under `PLINKO/tests`. The Windows test runner accepts a Godot path and selected suites; use its isolated profile workflow instead of running save tests against a personal player profile. Test fixtures are synthetic. Release build helpers and their verification record are in `PLINKO/tools` and `PLINKO/docs`.

## Repository contents

This repository retains source, runtime assets, authored asset tools, concept art, provenance, tests, and the current production workbook. Build outputs, signing credentials, downloaded toolchains, editor caches, personal saves and raw local QA capture directories are excluded.

Historical documents may reference `verification/` evidence or absolute paths on the original workstation. Those raw logs, captures and old builds remain in the local archive; the references are provenance, not portable build dependencies. Runtime assets use repository paths. Summary verification records under `PLINKO/docs` travel with the source.

The studio stamp is user supplied. Generated artwork and original synthesized sounds retain their provenance records. This repository does not add a general license for the game or its artwork; the included third-party licenses continue to apply to their respective components.
