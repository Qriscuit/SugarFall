param(
    [switch]$Preflight,
    [switch]$Offline,
    [string]$SeedGradleCache,
    [string]$CacheDirectory = (Join-Path $PSScriptRoot '../../tools/android-release-cache'),
    [string]$Python
)
. (Join-Path $PSScriptRoot 'AndroidRelease.Common.ps1')
$pythonExe = Resolve-ReleasePython $Python
Clear-ReleaseSigningEnvironment
$action = if ($Preflight) { 'preflight' } else { 'setup' }
$arguments = @((Join-Path $PSScriptRoot 'android_release.py'), $action, '--cache', [IO.Path]::GetFullPath($CacheDirectory))
if ($Offline) { $arguments += '--offline' }
if ($SeedGradleCache) { $arguments += @('--seed-gradle-cache', [IO.Path]::GetFullPath($SeedGradleCache)) }
& $pythonExe @arguments
if ($LASTEXITCODE -ne 0) { throw 'Android release setup failed.' }
