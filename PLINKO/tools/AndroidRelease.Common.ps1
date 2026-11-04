$ErrorActionPreference = 'Stop'

function Resolve-ReleasePython([string]$Requested) {
    if ($Requested) { return (Get-Command $Requested -ErrorAction Stop).Source }
    foreach ($name in @('python.exe', 'python3.exe')) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command -and $command.Source -notlike '*WindowsApps*') { return $command.Source }
    }
    $bundled = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
    if (Test-Path -LiteralPath $bundled) { return $bundled }
    throw 'Python 3.10+ is required. Pass -Python <python.exe>.'
}

function Clear-ReleaseSigningEnvironment {
    Get-ChildItem Env: | Where-Object {
        $_.Name -match '^(GODOT_ANDROID_KEYSTORE_RELEASE_|ORG_GRADLE_PROJECT_release_keystore_)'
    } | ForEach-Object { Remove-Item -LiteralPath ('Env:' + $_.Name) }
}

function Invoke-ReleaseTool([string]$Executable, [string[]]$Arguments, [string]$Log) {
    # All signing arguments are env references, never password values.
    $prior = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $Executable @Arguments 2>&1 | Out-File -LiteralPath $Log -Encoding utf8
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $prior }
    if ($code -ne 0) { throw "Tool failed with exit $code. Inspect $Log" }
}
