# Rebuilding an Android release candidate

These commands are tracked with the game source. They do not depend on the author's ignored `verification/` folder. Run them in PowerShell from the repository root, after the relevant game tests and visual review pass. They build locally; nothing is uploaded to Google Play, GitHub Releases or Drive.

## Toolchain and private identity

Use Godot **4.6.3 standard**, its matching export templates (including `android_release.apk` and `android_source.zip`), JDK **21**, Android SDK platform **36**, build tools **36.1.0**, and NDK **29.0.14206865**. Godot's matching Android source pins Gradle **8.11.1** and Android Gradle Plugin **8.6.1**. Its first Gradle build may download dependencies; respect any SDK license prompt rather than accepting licenses automatically.

In Godot's Editor Settings → Export → Android, set **Java SDK Path** and **Android SDK Path** to the same directories used below. Install the matching export templates using Godot's export-template manager or the official template archive. See [Godot Android export](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html) and [Gradle builds](https://docs.godotengine.org/en/4.6/tutorials/export/android_gradle_build.html).

Restore the existing release identity according to [RELEASE_SIGNING.md](RELEASE_SIGNING.md). Do not generate a replacement key. The import helper expects the existing `sugarfall-release.keystore` and Windows-account-bound `signing-credentials.xml` in the selected private directory. An off-machine recovery requires the separately backed-up password; copying a DPAPI XML alone does not restore it.

The two tracked presets are `Android Release Candidate APK` and `Android Release Candidate AAB`. Both use `com.qriscuit.sugarfall`, `sugarfall_public`, version `0.8.0-rc1` / code `30`, ARM64 and no Android permissions. Both deliberately export **unsigned**. The APK inherits SDK 24/36 from the official non-Gradle release template; the AAB sets these explicitly. Update both presets together before a new release and increase the version code. Never add `developer` to a public preset.

## Export unsigned artifacts

Set these paths for the current machine. Use a new output directory to avoid overwriting an existing candidate. The SDK/JDK environment variables also configure Gradle; they do not replace the Godot Editor Settings above.

```powershell
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path './PLINKO').Path
$godot = 'C:\Tools\Godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe'
$javaHome = 'C:\Program Files\Java\jdk-21'
$androidSdk = 'C:\Users\YourName\AppData\Local\Android\Sdk'
$signingDirectory = Join-Path (Get-Location) 'private/release-signing'
$output = Join-Path $project 'builds/release-rebuild-v0.8.0-rc1'
if (Test-Path -LiteralPath $output) { throw 'Choose a new output directory.' }
New-Item -ItemType Directory -Path $output | Out-Null
$unsignedApk = Join-Path $output 'Sugarfall-unsigned.apk'
$unsignedAab = Join-Path $output 'Sugarfall-unsigned.aab'
$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $androidSdk
$env:ANDROID_USER_HOME = Join-Path $output 'android-user-home'
$env:GRADLE_USER_HOME = Join-Path $output 'gradle-user-home'
$env:GRADLE_OPTS = '-Dorg.gradle.daemon=false -Dorg.gradle.workers.max=2'
New-Item -ItemType Directory -Path $env:ANDROID_USER_HOME,$env:GRADLE_USER_HOME | Out-Null
# Do not allow Godot to forward a signing password into Gradle process arguments.
Get-ChildItem Env: | Where-Object {
    $_.Name -match '^(GODOT_ANDROID_KEYSTORE_RELEASE_|ORG_GRADLE_PROJECT_release_keystore_)'
} | ForEach-Object { Remove-Item -LiteralPath ('Env:' + $_.Name) }
& $godot --headless --path $project --export-release 'Android Release Candidate APK' $unsignedApk
if ($LASTEXITCODE -ne 0) { throw 'Unsigned APK export failed.' }
$gradleWrapper = Join-Path $project 'android/build/gradlew.bat'
if (Test-Path -LiteralPath $gradleWrapper) {
    & $godot --headless --path $project --export-release 'Android Release Candidate AAB' $unsignedAab
} else {
    & $godot --headless --path $project --install-android-build-template --export-release 'Android Release Candidate AAB' $unsignedAab
}
if ($LASTEXITCODE -ne 0) { throw 'Unsigned AAB export failed.' }
```

Keep the export logs and inspect errors before signing. The current pinned Godot Gradle template warns that its Android Gradle Plugin was tested through API 35 while targeting API 36; the recorded RC export passed. Do not silently change the template/toolchain to remove that warning. If a console remains open after a successful bundle because a Gradle daemon inherited its handles, `& $gradleWrapper --stop` stops only the Gradle user home selected above. The commands disable that daemon for subsequent builds.

## Align and sign without password arguments

Run under the Windows account that can decrypt the restored credential record. The secret is referenced through an environment-variable name, never expanded into a command argument or export preset. The helper is dot-sourced only after both unsigned exports finish.

```powershell
$buildTools = Join-Path $androidSdk 'build-tools/36.1.0'
$java = Join-Path $javaHome 'bin/java.exe'
$jarsigner = Join-Path $javaHome 'bin/jarsigner.exe'
$keytool = Join-Path $javaHome 'bin/keytool.exe'
$apksigner = Join-Path $buildTools 'lib/apksigner.jar'
$zipalign = Join-Path $buildTools 'zipalign.exe'
$aligned = Join-Path $output 'Sugarfall-aligned.apk'
$apk = Join-Path $output 'Sugarfall-v0.8.0-rc1.apk'
$aab = Join-Path $output 'Sugarfall-v0.8.0-rc1.aab'
foreach ($path in @($aligned,$apk,$aab)) {
    if (Test-Path -LiteralPath $path) { throw 'Refusing to overwrite an artifact.' }
}
try {
    . (Join-Path $project 'tools/Import-ReleaseSigningEnvironment.ps1') -SigningDirectory $signingDirectory
    & $zipalign -P 16 4 $unsignedApk $aligned
    if ($LASTEXITCODE -ne 0) { throw 'Alignment failed.' }
    & $java -jar $apksigner sign --ks $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH --ks-key-alias $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER --ks-pass env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD --key-pass env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD --out $apk $aligned
    if ($LASTEXITCODE -ne 0) { throw 'APK signing failed.' }
    & $jarsigner -keystore $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -storetype PKCS12 -storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -keypass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -sigalg SHA256withRSA -digestalg SHA-256 -signedjar $aab $unsignedAab $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER
    if ($LASTEXITCODE -ne 0) { throw 'AAB signing failed.' }
} finally {
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
}
```

## Verify and record the build

```powershell
& $java -jar $apksigner verify --verbose --print-certs $apk
if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
& $zipalign -c -P 16 -v 4 $apk
if ($LASTEXITCODE -ne 0) { throw 'APK alignment verification failed.' }
& (Join-Path $buildTools 'aapt.exe') dump badging $apk
if ($LASTEXITCODE -ne 0) { throw 'APK metadata inspection failed.' }
& $jarsigner -verify -verbose -certs $aab
if ($LASTEXITCODE -ne 0) { throw 'AAB signature verification failed.' }
& $keytool -printcert -jarfile $aab
if ($LASTEXITCODE -ne 0) { throw 'AAB certificate inspection failed.' }
Get-FileHash -LiteralPath $apk,$aab -Algorithm SHA256
```

Require package/version matching both presets, min SDK 24, target SDK 36, ARM64, no `application-debuggable` marker, no unexpected permissions, valid APK v2/v3 signatures and certificate SHA-256 `e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29` on both artifacts. The Android application certificate is intentionally self-signed; JAR verification reports that fact and the absence of a timestamp.

Use the official [bundletool](https://developer.android.com/tools/bundletool) to validate the AAB and inspect its manifests. With a downloaded official `bundletool-all` JAR, the commands are:

```powershell
$bundletool = 'C:\Tools\bundletool-all.jar'
& $java -jar $bundletool validate --bundle=$aab
if ($LASTEXITCODE -ne 0) { throw 'AAB validation failed.' }
& $java -jar $bundletool dump manifest --bundle=$aab --module=base
& $java -jar $bundletool dump manifest --bundle=$aab --module=assetPackInstallTime
```

The Godot bundle delivers the game through an **install-time** asset pack. Before distribution, compare its game assets against the APK, retain all third-party notices, and confirm that tests, private keys, credentials and profiles are absent. The recorded RC verified all 335 game payloads and 24 launcher bitmaps against its APK, plus source/art hashes and the public feature. Save the new artifact hashes, source commit, export-preset hash, signing certificate and validation results in a new release record. This procedure does not by itself establish a repeatable clean-machine build, physical Android acceptance or Play readiness; those remain separate checks.
