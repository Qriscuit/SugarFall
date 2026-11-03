param([string]$SigningDirectory = (Join-Path $PSScriptRoot '../../private/release-signing'))
$ErrorActionPreference = 'Stop'
$signingRoot = [IO.Path]::GetFullPath($SigningDirectory)
$keyPath = Join-Path $signingRoot 'sugarfall-release.keystore'
if (!(Test-Path -LiteralPath $keyPath)) { throw 'Release signing key not found. Restore the existing key; do not replace a published app identity.' }
$credential = Import-Clixml -LiteralPath (Join-Path $signingRoot 'signing-credentials.xml')
if ($credential -isnot [Management.Automation.PSCredential]) { throw 'Invalid signing credential record.' }
# Dot-source in the build process. Clear all three variables in the caller's finally block.
# Godot 4.6 supports these environment overrides; no secret is saved in export_presets.cfg.
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keyPath
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $credential.UserName
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $credential.GetNetworkCredential().Password
$credential = $null
