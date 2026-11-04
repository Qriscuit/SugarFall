param(
    [switch]$Preflight,
    [switch]$UnsignedOnly,
    [string]$OutputDirectory,
    [string]$CacheDirectory = (Join-Path $PSScriptRoot '../../tools/android-release-cache'),
    [string]$SigningDirectory = (Join-Path $PSScriptRoot '../../private/release-signing'),
    [string]$Python
)
. (Join-Path $PSScriptRoot 'AndroidRelease.Common.ps1')
$pythonExe = Resolve-ReleasePython $Python
$cache = [IO.Path]::GetFullPath($CacheDirectory)
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Clear-ReleaseSigningEnvironment
if ($Preflight) {
    & $pythonExe (Join-Path $PSScriptRoot 'android_release.py') preflight --cache $cache
    if ($LASTEXITCODE -ne 0) { throw 'Release preflight failed.' }
    return
}
if (-not (Test-Path -LiteralPath (Join-Path $cache 'setup.json'))) {
    Write-Host 'Preparing the persistent release dependency cache...'
    & $pythonExe (Join-Path $PSScriptRoot 'android_release.py') setup --cache $cache
    if ($LASTEXITCODE -ne 0) { throw 'Release dependency setup failed; no signing credential was read.' }
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $project ('builds/android-release/' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
}
$output = [IO.Path]::GetFullPath($OutputDirectory)
& $pythonExe (Join-Path $PSScriptRoot 'android_release.py') export --cache $cache --output $output
if ($LASTEXITCODE -ne 0) { throw 'Unsigned export failed; signing was not attempted.' }
$plan = Get-Content -LiteralPath (Join-Path $output 'build-plan.json') -Raw | ConvertFrom-Json
if ($UnsignedOnly) { Write-Host "Unsigned artifacts: $output"; return }
$java = Join-Path $plan.java_home 'bin/java.exe'
$keytool = Join-Path $plan.java_home 'bin/keytool.exe'
$jarsigner = Join-Path $plan.java_home 'bin/jarsigner.exe'
$der = Join-Path $output 'sugarfall-release-certificate.der'
$pem = Join-Path $output 'sugarfall-release-certificate.pem'
try {
    # Godot and Gradle have already exited. Only the standalone signer processes
    # receive this owner's DPAPI-decrypted credential, via env references.
    . (Join-Path $PSScriptRoot 'Import-ReleaseSigningEnvironment.ps1') -SigningDirectory $SigningDirectory
    if ($env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ne 'sugarfall-release') { throw 'Unexpected existing signing alias.' }
    $certificateArgs = @('-exportcert', '-keystore', $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH,
        '-storetype', 'PKCS12', '-storepass:env', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD',
        '-alias', $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER)
    Invoke-ReleaseTool $keytool ($certificateArgs + @('-file', $der)) (Join-Path $output 'certificate-export.log')
    $fingerprint = (Get-FileHash -LiteralPath $der -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($fingerprint -ne $plan.expected_certificate_sha256) { throw 'Existing signing certificate differs from the pinned Sugarfall identity; no artifacts signed.' }
    Invoke-ReleaseTool $keytool ($certificateArgs + @('-rfc', '-file', $pem)) (Join-Path $output 'certificate-pem-export.log')
    Invoke-ReleaseTool (Join-Path $plan.build_tools 'zipalign.exe') @('-P', '16', '4', $plan.unsigned_apk, $plan.aligned_apk) (Join-Path $output 'align.log')
    Invoke-ReleaseTool $java @('-jar', (Join-Path $plan.build_tools 'lib/apksigner.jar'), 'sign',
        '--ks', $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH, '--ks-key-alias', $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER,
        '--ks-pass', 'env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', '--key-pass', 'env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD',
        '--out', $plan.apk, $plan.aligned_apk) (Join-Path $output 'sign-apk.log')
    Invoke-ReleaseTool $jarsigner @('-keystore', $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH,
        '-storetype', 'PKCS12', '-storepass:env', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD',
        '-keypass:env', 'GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD', '-sigalg', 'SHA256withRSA', '-digestalg', 'SHA-256',
        '-signedjar', $plan.aab, $plan.unsigned_aab, $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER) (Join-Path $output 'sign-aab.log')
} finally {
    Clear-ReleaseSigningEnvironment
}
# Public-only outputs: a certificate is safe to share; the keystore stays protected.
$colonFingerprint = (($fingerprint -split '([a-f0-9]{2})' | Where-Object { $_ }) -join ':').ToUpperInvariant()
[IO.File]::WriteAllText((Join-Path $output 'certificate-sha256.txt'), $colonFingerprint + [Environment]::NewLine)
@{ sha256 = $fingerprint; sha256_colon = $colonFingerprint; alias = 'sugarfall-release';
   public_certificate_der = $der; public_certificate_pem = $pem; private_key_copied = $false } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $output 'certificate.json') -Encoding utf8
& $pythonExe (Join-Path $PSScriptRoot 'verify_android_release.py') --project $project `
    --apk $plan.apk --aab $plan.aab --output (Join-Path $output 'verification') `
    --build-tools $plan.build_tools --java-home $plan.java_home `
    --bundletool-classpath-file $plan.bundletool_classpath_file --source-manifest $plan.source_manifest `
    --release-template $plan.release_template --version-name $plan.version_name --version-code $plan.version_code
if ($LASTEXITCODE -ne 0) { throw 'Signed artifacts exist but verification failed; do not upload.' }
Write-Host "Verified signed release: $output"
Write-Host "Public certificate SHA-256: $colonFingerprint"
