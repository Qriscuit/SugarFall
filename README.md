# Sugarfall

CHG-055 corrects the public package to `com.sungati.sugarfall` for the owner-reported Play Console requirement. [Signed RC7](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc7.md) · [Preview 0.7.21](PLINKO/docs/ANDROID_SUGARFALL_v0.7.21.md).


CHG-054 restricts developer tools to the editor and fits the Watch Ad button text in the [Android preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.20.md) and [signed Play candidate](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc6.md).


CHG-053 updates the app icon to Mabel across [Android preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.19.md), [Play candidate](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc5.md) and [Windows](PLINKO/docs/WINDOWS_SUGARFALL_v0.7.19.md).


CHG-052 configures Sugarfall’s production rewarded and interstitial ads in the signed [v0.8.0-rc4 Play candidate](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc4.md). The verified [v0.7.18 preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.18.md) replaces the existing Drive APK and uses Google demo ads. Consent setup, AdMob review, phone playback and Play submission remain open.

CHG-051 delivers [v0.7.17-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.17.md) and [public v0.8.0-rc3 APK/AAB](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc3.md) with native permanent ability purchases, AdMob/UMP and paid-run recovery. The preview passes 624 exact-artifact checks; the public artifacts pass 652. All three existing Drive files pass eight metadata readbacks each, retaining their IDs, folder and sharing permissions. Account setup and phone acceptance remain OPEN; billing fails closed until configured and ads use demo IDs.

CHG-050 delivers [v0.7.16-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.16.md). Mabel explicitly teaches destroying every cookie to clear the tray before time runs out. The short introduction and larger text remain; the verified APK replaces the existing Drive preview. Phone acceptance remains open.

CHG-049 delivers [v0.7.15-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.15.md) with a smooth pulsing backdrop behind each area’s signature upgrade, gold plus-only peg earnings and no global bottom notifications. The verified APK replaces the existing Drive preview file. Phone acceptance remains open.

CHG-048 delivers [v0.7.14-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.14.md) with shorter, larger first-run instructions, immediate dialogue and gold peg coin earnings. The verified APK replaces the existing Drive preview file. Phone acceptance remains open.

CHG-047 delivers [v0.7.12-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.12.md) with Gelato label alignment, selected upgrade costs and compact two-column signature cards. The verified APK replaces the existing private Drive file. Phone acceptance remains open. [Layout and evidence](PLINKO/docs/UPGRADE_LAYOUT.md).

CHG-046 delivers [v0.7.11-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.11.md), with complete Gelato and Crystal interface art sets and subtly themed cream waves. The verified APK replaces the existing private Drive file. Phone acceptance remains open. [Art and evidence](PLINKO/docs/AREA_INTERFACE_ART.md).

CHG-045 prepares the [Google Play storefront review](concept-art/storefront-v1/preview.html): feature artwork, the existing icon, six actual game captures and direct listing copy. [Download the review package](https://drive.google.com/file/d/14SdcC4t36EbDhBYN0bOPlaDvlobTzO-p/view) · [Copy and claim evidence](PLINKO/docs/store/STORE_COPY.md) · [Screenshot plan](PLINKO/docs/store/SCREENSHOT_PLAN.md). Final Android comparison and Console entry remain open; the game builds are unchanged.

CHG-044 prepares the reusable signed-release environment and delivers separate public **v0.8.0-rc2/code 37** APK and AAB files for Internal testing preparation. The existing preview download is unchanged. The owner reports creating the Play app; Console enrollment, upload, production readiness and off-device key backup are unverified. [Candidate and downloads](PLINKO/docs/ANDROID_SUGARFALL_v0.8.0-rc2.md) · [Build commands](PLINKO/docs/ANDROID_RELEASE_BUILD.md).

CHG-043 delivers [v0.7.10-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.10.json) with direct coin/early-access actions on ability upgrade cards and no Home ability purchase offer. Phone acceptance, real billing and the Bakery tray-10 retest remain open.

CHG-040 delivers [v0.7.8-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.8.json) with [More Jam](PLINKO/docs/BAKERY_MORE_JAM.md), a free late Bakery upgrade addressing the reported tray-10 difficulty. The phone retest and [remaining Google Play work](PLINKO/docs/GOOGLE_PLAY_READINESS.md) stay open.

CHG-037 delivers [v0.7.6-preview](PLINKO/docs/ANDROID_SUGARFALL_v0.7.6.json), including the area frames, signature abilities and Flow-2 source work. Real billing, current legal progression and phone acceptance remain open.

A portrait arcade game built in Godot, with three themed areas: Bakery, Gelato Garden and Crystal Candyworks. Each area has its own twelve trays, upgrade map, economy, art and ball mechanics.

Open **`PLINKO/project.godot` in Godot 4.6.3**. The entry scene is `startup.tscn`; it loads the game behind the studio heartbeat and cream reveal. The [Windows v0.7.13 preview](PLINKO/docs/WINDOWS_SUGARFALL_v0.7.13.md) uses left-click hold to steer; its live mouse acceptance remains open. Android phone acceptance remains part of the release checklist.

The current test download is **v0.7.17-preview (code 44)**. See [the verified APK record](PLINKO/docs/ANDROID_SUGARFALL_v0.7.17.json) and [download links](PLINKO/BUILD_LINKS.txt). The separate current public candidate is **v0.8.0-rc3/code 43**, with a signed APK and AAB. Physical-phone acceptance, actual SDK playback and real purchase verification remain open.

## Production records

- [Google Play release queue](PLINKO/docs/GOOGLE_PLAY_READINESS.md): the dated requirements audit, 4 November signing/upload handoff and remaining work.
- [Area template](AREA_CHECKLIST.md): use this before building another area.
- [Area status](AREA_STATUS.md): built, integrated and verified are separate states.
- [Launch tracker](outputs/launch-tracker-01a18eec/Sugarfall%20Launch%20Tracker.xlsx): outstanding fixes and change history.
- [Game and design notes](PLINKO/README.md): mechanics and earlier preview deliveries.
- [Signing and recovery](PLINKO/docs/RELEASE_SIGNING.md): release identity and private local key handling.
- [Source backup verification](PLINKO/docs/SOURCE_CONTROL.md): GitHub tag and independently recovered checkout.
- [Third-party notices](PLINKO/THIRD_PARTY_NOTICES.md): engine and font attribution.

## Building and testing

Install the matching Godot 4.6.3 export templates. Configure your own Android SDK and JDK in Godot's editor settings; machine-specific tools are excluded from this repository. See [Godot's Android export instructions](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html).

The Android Preview preset retains the development package `org.pegfoundry.prototype.preview`. Current public release candidates use **`com.sungati.sugarfall`** and the `sugarfall_public` feature. They install separately from previews. The public build disables simulated commerce and developer controls. Native ad/billing source is integrated; external provider setup, exact SDK-equipped release verification, real-device acceptance and Play Console release steps remain open.

Tests live under `PLINKO/tests`. The Windows test runner accepts a Godot path and selected suites; use its isolated profile workflow instead of running save tests against a personal player profile. Test fixtures are synthetic. Release build helpers and their verification record are in `PLINKO/tools` and `PLINKO/docs`.

## Repository contents

This repository retains source, runtime assets, authored asset tools, concept art, provenance, tests, and the current production workbook. Build outputs, signing credentials, downloaded toolchains, editor caches, personal saves and raw local QA capture directories are excluded.

Historical documents may reference `verification/` evidence or absolute paths on the original workstation. Those raw logs, captures and old builds remain in the local archive; the references are provenance, not portable build dependencies. Runtime assets use repository paths. Summary verification records under `PLINKO/docs` travel with the source.

The studio stamp is user supplied. Generated artwork and original synthesized sounds retain their provenance records. This repository does not add a general license for the game or its artwork; the included third-party licenses continue to apply to their respective components.
