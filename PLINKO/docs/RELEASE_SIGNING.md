# Release signing and recovery

The key was created on 3 November 2026 after the owner confirmed there was no existing Play app or release key. On 4 November the owner reported that the Play app had been created. The existing key was rechecked successfully; the exact Console page, package registration, account completion and Play App Signing enrollment have not been verified.

| Field | Value |
| --- | --- |
| Android application ID | `com.qriscuit.sugarfall` |
| Initial candidate | `0.8.0-rc1`, version code `30` |
| Current candidate | `0.8.0-rc2`, version code `37` |
| Key alias | `sugarfall-release` |
| Keystore | PKCS12, RSA 4096, SHA256withRSA |
| Certificate SHA-256 | `e31ab7654afed05f9acd5fb6b59846d990198b8005d8fafd01e070c1dbc4dc29` |
| Certificate validity | 3 November 2026 through 21 March 2054 |

The working keystore is `private/release-signing/sugarfall-release.keystore` at the workspace root, outside the Godot project and excluded from Git. Its password is randomly generated and stored as Windows DPAPI-encrypted `signing-credentials.xml` in the same protected directory. A public certificate copy is there too. No password is committed to export presets or printed by the authoring tools.

`tools/Import-ReleaseSigningEnvironment.ps1` must run under the Windows account that created the encrypted credential record. Dot-source it only in a trusted build process. It sets Godot's three release-keystore environment variables; clear them in a `finally` block after signing. A sandbox account cannot decrypt the owner's record. Godot documents these environment overrides in [Android export settings](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_android.html#environment-variables).

The build workflow exports unsigned Android artifacts, then signs using `apksigner`/`jarsigner` with environment-variable password references. This keeps the password out of command arguments and Gradle logs. Do not add passwords to `export_presets.cfg`, shell history or GitHub workflows.

## Required owner backup

The GitHub source backup deliberately does **not** back up the private key. Keep an encrypted offline copy of the keystore and store the actual password in a password manager or another secure recovery store. The DPAPI XML is tied to this Windows account/machine and is **not a portable password backup**. Restore and verify both key and password before retiring this computer. The owner's off-device signing backup has not yet been confirmed.

`tools/New-ReleaseSigningKey.ps1` refuses to overwrite an existing key or credential file. Do not generate a replacement identity for an app that has already shipped. After setting up Play App Signing, record the Play-managed app-signing certificate and upload-key role separately. App creation is owner-reported; this task has not verified enrollment or submitted a release to Play Console.

## Preview compatibility

The release package installs separately from `org.pegfoundry.prototype.preview`. It does not overwrite the preview or automatically import its progress. Simulated preview purchases are not real paid entitlements. Public candidates disable simulated commerce and developer controls while retaining ordinary game progression.

## Checked build commands

From the repository root, run `PLINKO/tools/Setup-AndroidRelease.ps1 -Preflight`, then `PLINKO/tools/Build-AndroidRelease.ps1` with a new output directory. The build prepares its cache automatically if needed; `Setup-AndroidRelease.ps1` can also prepare or check it separately. Setup reads no signing credential. Build exports unsigned artifacts before importing the existing key, verifies the public certificate fingerprint before signing, and clears the credential environment afterward. The public DER/PEM certificate and `certificate-sha256.txt` are exported beside the build; the private key is not copied. See [the complete command sequence](ANDROID_RELEASE_BUILD.md).

## Which SHA-256 belongs in Console

The fingerprint in the table identifies the **signing certificate**. It is different from the SHA-256 of an APK or AAB file, which changes with each build. This existing key signs the candidate submitted to Play; the distribution certificate may differ after Play App Signing is configured. [Android signing guide](https://developer.android.com/studio/publish/app-signing).

For a new package-name registration, Console may request this certificate fingerprint. An existing-package ownership challenge can instead require an account-specific `adi-registration.properties` file in a signed APK. No challenge snippet or completed registration is recorded; the ordinary candidate APK does not establish that such a challenge has been met. [Package registration guide](https://support.google.com/googleplay/android-developer/answer/16761053?hl=en).
