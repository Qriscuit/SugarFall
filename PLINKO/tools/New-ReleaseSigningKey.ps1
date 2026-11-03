param(
    [string]$SigningDirectory = (Join-Path $PSScriptRoot '../../private/release-signing'),
    [string]$Keytool = 'C:/Program Files/Java/jdk-21.0.12/bin/keytool.exe'
)
$ErrorActionPreference = 'Stop'
$signingRoot = [IO.Path]::GetFullPath($SigningDirectory)
$keyPath = Join-Path $signingRoot 'sugarfall-release.keystore'
$credentialPath = Join-Path $signingRoot 'signing-credentials.xml'
if ((Test-Path -LiteralPath $keyPath) -or (Test-Path -LiteralPath $credentialPath)) {
    throw 'A signing key or credential record already exists; refusing to replace it.'
}
if (!(Test-Path -LiteralPath $Keytool)) { throw 'Set -Keytool to your installed JDK keytool.' }
# Fail before changing filesystem permissions when no Windows user profile is loaded.
$probe = ConvertTo-SecureString 'DPAPI availability probe' -AsPlainText -Force
$null = ConvertFrom-SecureString $probe
[void](New-Item -ItemType Directory -Force -Path $signingRoot)
$currentSid = [Security.Principal.WindowsIdentity]::GetCurrent().User
# icacls changes the DACL without requesting privileged system-audit access.
& icacls $signingRoot /inheritance:r /grant:r ('*' + $currentSid.Value + ':(OI)(CI)F') '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not protect the signing folder.' }
$randomBytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$rng.Dispose()
$password = ([BitConverter]::ToString($randomBytes)).Replace('-', '')
$credential = New-Object Management.Automation.PSCredential('sugarfall-release', (ConvertTo-SecureString $password -AsPlainText -Force))
# Windows DPAPI encrypts this record for the current Windows account/machine.
$credential | Export-Clixml -LiteralPath $credentialPath
$env:SUGARFALL_KEYTOOL_PASSWORD = $password
try {
    & $Keytool -genkeypair -noprompt -keystore $keyPath -storetype PKCS12 -alias 'sugarfall-release' -keyalg RSA -keysize 4096 -sigalg SHA256withRSA -validity 10000 -dname 'CN=Sugarfall, OU=Games' -storepass:env SUGARFALL_KEYTOOL_PASSWORD -keypass:env SUGARFALL_KEYTOOL_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Release key generation failed. Retain the credential record before investigating.' }
    & $Keytool -exportcert -rfc -keystore $keyPath -alias 'sugarfall-release' -storepass:env SUGARFALL_KEYTOOL_PASSWORD -file (Join-Path $signingRoot 'sugarfall-release-certificate.pem')
    if ($LASTEXITCODE -ne 0) { throw 'Public certificate export failed.' }
    & $Keytool -list -v -keystore $keyPath -alias 'sugarfall-release' -storepass:env SUGARFALL_KEYTOOL_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'New signing key verification failed.' }
} finally {
    Remove-Item Env:SUGARFALL_KEYTOOL_PASSWORD -ErrorAction SilentlyContinue
    $password = $null
    $credential = $null
    [Array]::Clear($randomBytes, 0, $randomBytes.Length)
}
Write-Output ('Release signing material created in ' + $signingRoot + '. No credentials were printed.')
