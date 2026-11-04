# Build a signed Android release candidate

The tracked Windows entrypoints prepare the existing toolchain, export unsigned APK/AAB files, sign them with Sugarfall's existing key, and verify the resulting artifacts. They preserve `com.qriscuit.sugarfall`; the private preview uses a separate package and download. The current public presets are `0.8.0-rc2`, version code `37`.

This procedure produces an Internal testing candidate. It does not enroll Play App Signing, upload to Play Console, prove a clean-machine or byte-identical rebuild, or complete phone and production acceptance. See [the candidate record](ANDROID_SUGARFALL_v0.8.0-rc2.md) and [the remaining release queue](GOOGLE_PLAY_READINESS.md).

## Prerequisites

Run from the repository root under the Windows account that owns the existing DPAPI signing record. Use PowerShell with `-NoProfile` when invoking the scripts from another shell.

- Python 3.10 or newer. The wrappers accept `-Python <exe>`, then search PATH and the existing Codex bundled runtime.
- Godot 4.6.3 standard and its matching official Android release/source templates. The default portable editor is under `tools/Godot-4.6.3`; its editor settings must specify the installed Java SDK and Android SDK paths.
- JDK 21, Android platform 36, build-tools 36.1.0, platform-tools and NDK 29.0.14206865, with the required SDK licenses already accepted by the owner.
- The existing protected signing directory described in [signing and recovery](RELEASE_SIGNING.md). No replacement key is created by these commands.

The official template pins Gradle 8.11.1, Android Gradle Plugin 8.6.1 and Kotlin 2.1.21. Setup verifies the template hash and installed versions; it does not install an SDK or accept license agreements. A first setup may download the pinned Gradle dependencies.

## Commands

Check the installed tools and public presets without reading signing credentials:

```powershell
.\PLINKO\tools\Setup-AndroidRelease.ps1 -Preflight
```

Optional: prepare the persistent, Git-ignored cache and resolve the build dependencies separately:

```powershell
.\PLINKO\tools\Setup-AndroidRelease.ps1
```

Use `-Offline` only with an already populated dependency cache. `-SeedGradleCache <path>` can copy a known warmed Gradle cache without importing its user properties, init scripts, daemon state or credentials. Both entrypoints accept `-CacheDirectory <path>`; the default is `tools/android-release-cache`.

Build, sign and verify into a **new** output directory. This command prepares the dependency cache automatically when its setup record is absent:

```powershell
.\PLINKO\tools\Build-AndroidRelease.ps1 `
  -OutputDirectory .\PLINKO\builds\android-release\rc2-rebuild-01
```

The helper refuses to overwrite an existing directory. Omitting `-OutputDirectory` creates a timestamped directory. `-Preflight` performs only the checks; `-UnsignedOnly` stops after unsigned exports and must not be treated as a publishable result. `-SigningDirectory <path>` selects an existing protected key record; it does not create or rotate an identity.

## What the build verifies

The public APK/AAB presets must agree on version and package, enable only ARM64, use `sugarfall_public`, and contain no signing secrets. The builder freezes runtime/import inputs, exports both artifacts without credentials, and rejects source drift. It then loads the owner's DPAPI credential only for standalone signing, pins the exported certificate to Sugarfall's recorded SHA-256, aligns the APK for 16 KB pages, signs the APK and AAB, and clears the credential environment in `finally`.

The independent verifier checks the exact signed artifacts, including package/version/SDK/public configuration, certificate and signatures, payload/source parity, bundled data/assets, ZIP and ELF alignment, and AAB structure. Consult the resulting verification report for its actual check counts and limits. A successful local signature is not a Play Console acceptance result.

Each output directory contains the signed APK and AAB, `build-plan.json`, `source-sha256.json`, `preflight.json`, `unsigned-export.json`, build/signing logs and a `verification` directory. It also contains **public** DER/PEM certificate copies, `certificate.json` and `certificate-sha256.txt`. The private keystore and password are not copied into the output. The local cache's `latest-build-plan.json` is only a convenience pointer; the per-build record is the evidence.

## Hand off to Play Console

Use the signed **AAB** for the app's Internal testing release. In Play Console, open Testing → Internal testing → Create new release, configure Play App Signing when prompted, then add the AAB and review the Console's remaining tasks. The APK is for direct installation or a specifically requested signed-APK check. These actions do not publish a production release. [Play release instructions](https://support.google.com/googleplay/android-developer/answer/9859348?hl=en).

The local certificate is the key used to sign this candidate. Play's distribution signing certificate may differ after enrollment; record the upload and app-signing roles separately. AAB files need an upload-key signature before submission. [Android signing guide](https://developer.android.com/studio/publish/app-signing).

For package-name registration, a new-package form can ask for this certificate's SHA-256. If the Console instead requests proof with an account-specific `adi-registration.properties` file, that exact supplied challenge must be added to a dedicated signed APK; the ordinary release APK is not evidence that such a challenge has been satisfied. No challenge file or completed registration is recorded here. [Package registration guide](https://support.google.com/googleplay/android-developer/answer/16761053?hl=en).

New phone apps and updates must target API 36 or later under the requirement effective 31 August 2026; these presets target 36. Requirements were checked narrowly for this release handoff on 4 November 2026. [Target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en).

Retain the build evidence and confirm an off-device signing backup before relying on this workstation as the only recovery path. Real billing, physical install/update/listening checks, current progression acceptance, account requirements and Play review remain in the release queue.
