# Sugarfall v0.7.10 Android preview

Delivered 3 November 2026 · `0.7.10-preview` · version code `36`.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Local APK](../builds/Sugarfall-v0.7.10-Android-Preview-2026-11-03.apk) · [Build manifest](ANDROID_SUGARFALL_v0.7.10.json)

Special-ability upgrade cards now offer the coin route and optional early unlock directly. The extra Unlock options step and the main-menu purchase offer are removed, keeping purchase choices beside the ability node.

Earned gates, transaction handling and existing ownership remain supported. Preview purchases still use explicit no-charge simulation; real Play billing remains unconnected. More Jam, all ten gameplay JSON files, the single-pulse studio startup and 33 action sounds are retained.

The APK passed **1048 payload checks** and **16 Android metadata, signature and alignment checks**. All 41 runtime scripts and imported resources match the frozen inputs. See [source validation](DIRECT_ABILITY_PURCHASE_VALIDATION.json) for the current UI, transaction and renderer evidence; earlier gameplay and studio checks retain their recorded scopes. These checks do not establish physical-phone acceptance.

| Artifact | Value |
| --- | --- |
| Filename | `Sugarfall-v0.7.10-Android-Preview-2026-11-03.apk` |
| Size | 93,043,106 bytes |
| SHA-256 | `8673036be460e691f5c2bf6108c171f9a1e904cb9c729e10fde522ca6ef0105c` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

The preview retains the same package and signing identity as v079 for an install-over update. Phone card layout/touch acceptance, save retention, Bakery tray 10, audio/startup feel and normal-wallet pacing remain open. v079 and the separate public v0.8.0-rc1 APK/AAB are preserved.

The existing private Drive file and permissions were retained, and all eight uploaded-metadata checks passed. Drive returned no remote checksum; the APK hash is verified locally.
