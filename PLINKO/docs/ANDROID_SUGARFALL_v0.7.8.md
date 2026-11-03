# Sugarfall v0.7.8 Android preview

Delivered 3 November 2026 · `0.7.8-preview` · version code `34`.

[Download APK](https://drive.google.com/file/d/1GF1zo3lt0VR5voajNPGjoP1FYuPe0FYz/view?usp=drivesdk) · [Local APK](../builds/Sugarfall-v0.7.8-Android-Preview-2026-11-03.apk) · [Build manifest](ANDROID_SUGARFALL_v0.7.8.json)

More Jam is a free Bakery upgrade at the far end of the map. Reach tray 10, own Jam Burst and finish all three ordinary routes, then claim it to fill every fourth normal doughnut with jam instead of every fifth. You can claim it before beating tray 10. Specials and shards do not advance the charge, and the splash itself is unchanged.

The milestone is saved separately for Bakery, survives area revisits and stays disabled in Trials. Campaign reset removes it; a failed save rolls the claim back. Existing interrupted Jam runs keep their fifth-drop cadence, while upgraded new runs save the fourth-drop cadence explicitly. More Jam has no paid purchase.

The APK passed **786 payload checks** and **16 Android metadata, signature and alignment checks**. All 41 runtime scripts, 33 feedback sounds and the slower studio hum are retained. Frozen export inputs and current imported resource bytes match; nine JSON files are byte-identical to v077, and Bakery's ordinary map nodes/routes/edges are unchanged. These are package checks, not phone execution or pacing acceptance. See [More Jam validation](MORE_JAM_VALIDATION.json) for scoped backend, save, map, render and synthetic probe evidence.

| Artifact | Value |
| --- | --- |
| Filename | `Sugarfall-v0.7.8-Android-Preview-2026-11-03.apk` |
| Size | 93,051,298 bytes |
| SHA-256 | `9bb0f427a1bb47ac916ec01b5ea73b50d590026f8cfa51f0c37905f602035998` |
| Package | `org.pegfoundry.prototype.preview` |
| Platform | ARM64, Android 7 or newer |

The preview retains the same package and signing identity as v077 for an install-over update. Physical save retention, Bakery tray 10 acceptance, phone audio balance, startup feel and normal-wallet pacing remain open. Real Play billing is still unconnected. v077 and the separate public v0.8.0-rc1 APK/AAB are preserved.

The existing private Drive file and permissions were retained, and all eight uploaded-metadata checks passed. Drive returned no remote checksum; the APK hash is verified locally.
