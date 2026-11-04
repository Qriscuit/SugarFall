# Sugarfall 0.8.0-rc2 — signed Internal testing candidate

Built and privately delivered on 4 November 2026 · CHG-044 · version code **37**.

Use the **AAB** for the Play Console Internal testing release. The signed APK is for direct installation. Both use `com.qriscuit.sugarfall` and the existing release certificate; they install separately from the private preview and do not automatically import its progress.

| Download | Bytes | File SHA-256 |
| --- | ---: | --- |
| [Signed AAB](https://drive.google.com/file/d/1ZFWvhGOnHPLn1qIYkcuRpBhcP3KG846D/view?usp=drivesdk) | 90,575,945 | `29c32d25400ce42168ced55eac0909a15e2dc4433e3f94b48d7c388e425f6831` |
| [Signed APK](https://drive.google.com/file/d/1AU5B4wDwQT4RcKqrs_KG_u02B3X4NRDt/view?usp=drivesdk) | 91,340,723 | `afee2a0e1687a7051d9925bf636e06903b24f4250771ce2627fa643a31505a37` |

The [public signing certificate](https://drive.google.com/file/d/1F5oMiwFqKW_bKoJwew-4HyH_ryLSF7PM/view?usp=drivesdk) is also available (1,798 bytes). Its certificate SHA-256 is **`e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29`**. This fingerprint identifies the key; it is different from the two file hashes above. The private key and password were not uploaded.

Drive metadata confirms the three separate files in the existing owner-only folder. The v0.7.10 preview's file ID, name, size, modified time, folder and permissions remain unchanged. No remote checksum was returned. The exact local hashes and readbacks are recorded in [the release manifest](ANDROID_SUGARFALL_v0.8.0-rc2.json).

## What is in this candidate

This is the current three-area game, including direct coin/early-access actions on signature cards, the single-pulse intro/hum, action sounds and More Jam. This task changes release tooling and packaging, without new gameplay changes. Public builds hide and reject developer controls and simulated commerce. All three signature abilities remain earnable through their ordinary tray, Power and coin requirements. Real billing is not connected; unavailable store actions cannot create fake paid access.

The reusable [build procedure](ANDROID_RELEASE_BUILD.md) checks the installed toolchain, prepares its dependency cache, exports unsigned artifacts, signs with the existing protected key and verifies both outputs. It retains Godot 4.6.3, JDK 21, target API 36, minimum SDK 24 and ARM64. Public exports exclude authoring provenance/inventory JSON, tests, tools and documents.

## Verification scope

- **344/344 exact-artifact checks:** signatures/certificate, manifests, public feature, source/import parity, package exclusions, bundle structure, native compatibility and APK/AAB content. The payload includes **41 compiled scripts**, **10 top-level game-data JSON files**, **148 checked import descriptors** and **418 indexed project payloads**. All **486 frozen export inputs** match. [Artifact proof](PUBLIC_RELEASE_RC2_ARTIFACT_VALIDATION.json).
- **186/186 policy checks:** 85 preview and 101 actual nondebug Windows checks, covering public guard behavior, simulated ownership rejection, earned ability routes and saved-profile handling. This is separate from Android device execution. [Policy proof](PUBLIC_RELEASE_RC2_POLICY_VALIDATION.json).
- **11 verifier regression tests** and **five build-helper tests** pass separately. Previous UI/GPU evidence remains in its dated records and is not added to these counts.

The APK and AAB have the same actual game payload bytes. Their sparse index records are logically equal; directory order differs, so raw index-byte equality is not claimed. Both ARM64 libraries pass static 16 KB ELF alignment checks. The APK uses compressed native libraries with extraction enabled; its ZIP/extraction contract and the AAB's requested 16 KB alignment pass. A real 16 KB device/emulator run remains open.

Build source: `ca8472c8070044641b6ac710428e726a42fe6ece`. Runtime is unchanged since `a4f578da9bf76abf3f0708059be2600a6130530e`. Local output: `PLINKO/builds/android-release/0.8.0-rc2-code37-attempt03`. The two earlier preparation attempts were not delivered.

## Next Console action

The owner reports creating the Play app. Open its Internal testing track, create a release, configure Play App Signing when prompted and add the signed AAB. Follow the actual Dashboard tasks before starting the test. No Play upload, enrollment, review or production publication is claimed here. [Play release instructions](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en).

The exact SHA-256 request screen has not been observed. See [signing and package-registration guidance](RELEASE_SIGNING.md#which-sha-256-belongs-in-console) if Console asks for a certificate or a signed ownership-challenge APK.

Phone install/update/listening acceptance, the Bakery tray-10 finding, current legal progression, real billing, store/privacy declarations and off-device signing backup remain open. This is a signed test candidate, not a completed production release. A clean-machine or byte-identical rebuild has not been demonstrated. See [the release queue](GOOGLE_PLAY_READINESS.md).
