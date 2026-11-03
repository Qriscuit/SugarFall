<#
.SYNOPSIS
Runs Sugarfall's regression suites with isolated Windows saves.
.EXAMPLE
powershell -NoProfile -File .\tests\run_windows_tests.ps1 -Godot "C:\Tools\Godot_v4.6.3-stable_win64_console.exe" -IncludeAudio
.EXAMPLE
powershell -NoProfile -File .\tests\run_windows_tests.ps1 -Godot "C:\Tools\Godot_v4.6.3-stable_win64_console.exe" -AudioOnly
.NOTES
Uses a disposable project copy and child-process APPDATA/LOCALAPPDATA directories.
Checks Godot's actual user:// directory before any save fixtures run. XDG variables
alone do not isolate Windows saves. Source files and normal player saves are untouched.
Logs, summary.json, and the isolated copy remain in OutputDirectory for diagnosis.
The default is a uniquely named directory under the Windows temporary directory.
Requires the standard (GDScript) Godot 4.6.3 Windows editor, preferably console.exe.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Godot,
    [string]$OutputDirectory,
    # Optional cache from a prior successful run with the same Godot version.
    # Godot still validates/imports changed resources in the isolated copy.
    [string]$ImportedCacheDirectory,
    [switch]$IncludeAudio,
    [switch]$AudioOnly,
    [ValidateSet('crystal-physics','crystal-save','crystal-pacing','crystal-area-ui','crystal-art','combat-balance','coin-feedback','damage-feedback','self-test','upgrade-graph','upgrade-layout','upgrade-arc-art','gelato-upgrade-graph','gelato-upgrade-map','gelato-twin-node','gelato-node-ownership','organic-boards','bakery-durability','peg-tier-visual','independent','resume','v04','map','navigation','run-transition','first-run-guide','countdown-feedback','final-ball-drain','whole-coins','run-comparison','reset-progress','monetization','area-progression','gelato-navigation','gelato-launcher-save','gelato-launcher','gelato-launcher-layout','gelato-launcher-shop','gelato-trajectory','gelato-shop-migration','developer-area','developer-area-ui','developer-money','audio-cache')]
    [string[]]$Suites = @(),
    [ValidateRange(10, 3600)][int]$TimeoutSeconds = 240
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$enginePath = (Resolve-Path -LiteralPath $Godot).Path
$runId = 'peg-foundry-tests-' + [Guid]::NewGuid().ToString('N')
if (-not $OutputDirectory) { $OutputDirectory = Join-Path ([IO.Path]::GetTempPath()) $runId }
$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outputRoot) { throw "OutputDirectory must be new: $outputRoot" }
$copyRoot = Join-Path $outputRoot 'project'
$appData = Join-Path $outputRoot 'appdata'
$localData = Join-Path $outputRoot 'localappdata'
$tempData = Join-Path $outputRoot 'temp'
foreach ($directory in @($outputRoot, $copyRoot, $appData, $localData, $tempData)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
[IO.File]::WriteAllText((Join-Path $outputRoot '.gdignore'), '')
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($item in @('project.godot', 'main.tscn', 'startup.tscn', 'scripts', 'data')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $item) -Destination $copyRoot -Recurse
}
$copyTests = Join-Path $copyRoot 'tests'
New-Item -ItemType Directory -Path $copyTests | Out-Null
Get-ChildItem -LiteralPath $PSScriptRoot -File | Where-Object { $_.Extension -in @('.gd', '.uid', '.txt') } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $copyTests }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'performance') -Destination $copyTests -Recurse
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures') -Destination $copyTests -Recurse
if ($ImportedCacheDirectory) {
    $cacheSource = (Resolve-Path -LiteralPath $ImportedCacheDirectory).Path
    if (-not (Test-Path -LiteralPath $cacheSource -PathType Container)) { throw 'Imported cache must be a directory.' }
    $cacheDestination = Join-Path $copyRoot '.godot\imported'
    New-Item -ItemType Directory -Path $cacheDestination -Force | Out-Null
    Get-ChildItem -LiteralPath $cacheSource -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $cacheDestination }
}

# Force a distinct save namespace in the copy as a second isolation measure.
$configPath = Join-Path $copyRoot 'project.godot'
$config = [IO.File]::ReadAllText($configPath)
$config = [regex]::Replace($config, '(?m)^config/(use_custom_user_dir|custom_user_dir_name)=.*\r?\n?', '')
$config = $config.Replace('[application]', "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$runId`"")
[IO.File]::WriteAllText($configPath, $config, $utf8)
$probePath = Join-Path $copyTests 'windows_isolation_probe.gd'
[IO.File]::WriteAllText($probePath, @'
extends SceneTree
func _initialize():
    print("WINDOWS_QA_USER_DIR=", OS.get_user_data_dir())
    quit()
'@, $utf8)

function Quote-NativeArgument([string]$Argument) {
    '"' + [regex]::Replace([regex]::Replace($Argument, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

$results = New-Object System.Collections.Generic.List[object]
function Invoke-GodotCheck([string]$Name, [string[]]$Arguments, [string]$Expected) {
    # A focused rerun still performs the same isolation probe and asset import.
    if ($Suites.Count -gt 0 -and $Name -notin @('isolation','import') -and $Name -notin $Suites) { return '' }
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $enginePath
    $info.Arguments = (@('--headless', '--audio-driver', 'Dummy', '--path', $copyRoot) + $Arguments | ForEach-Object { Quote-NativeArgument $_ }) -join ' '
    $info.WorkingDirectory = $copyRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['APPDATA'] = $appData
    $info.EnvironmentVariables['LOCALAPPDATA'] = $localData
    $info.EnvironmentVariables['TEMP'] = $tempData
    $info.EnvironmentVariables['TMP'] = $tempData
    $info.EnvironmentVariables['PEG_AUDIO_BANK_SCRIPT'] = 'res://scripts/tone_bank.gd'
    $info.EnvironmentVariables['PEG_AUDIO_BANK_OUTPUT'] = Join-Path $outputRoot 'audio-cache.json'
    $info.EnvironmentVariables['SUGARFALL_DRAIN_QA_SAVE'] = Join-Path (Join-Path $appData $runId) 'final-ball-drain-qa.json'
    $info.EnvironmentVariables['SUGARFALL_AREA_QA_SAVE'] = Join-Path (Join-Path $appData $runId) 'area-progression-qa.json'
    $info.EnvironmentVariables['SUGARFALL_CRYSTAL_SAVE_QA_SAVE'] = Join-Path (Join-Path $appData $runId) 'crystal-save-qa.json'
    $info.EnvironmentVariables['SUGARFALL_GELATO_SAVE_QA_SAVE'] = Join-Path (Join-Path $appData $runId) 'gelato-launcher-save-qa.json'
    $info.EnvironmentVariables['SUGARFALL_GELATO_SHOP_QA_SAVE'] = Join-Path (Join-Path $appData $runId) 'gelato-shop-migration-qa.json'
    $info.EnvironmentVariables['SUGARFALL_NODE_OWNERSHIP_QA_SAVE'] = Join-Path (Join-Path $appData $runId) 'gelato-node-ownership-qa.json'
    $info.EnvironmentVariables['SUGARFALL_DEVELOPER_AREA_QA_SAVE'] = Join-Path (Join-Path $appData $runId) 'developer-area-qa.json'
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Write-Host "Running $Name..."
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $finished = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) { $process.Kill(); $process.WaitForExit() }
    $output = $stdout.Result + $stderr.Result
    $timer.Stop()
    $exitCode = $process.ExitCode
    $process.Dispose()
    $logPath = Join-Path $outputRoot ($Name + '.log')
    [IO.File]::WriteAllText($logPath, $output, $utf8)
    $passed = $finished -and $exitCode -eq 0 -and $output -notmatch '(?m)SCRIPT ERROR:|^ERROR:|^FAIL:' -and $output -match $Expected
    $results.Add([pscustomobject]@{ name = $Name; passed = $passed; exitCode = $exitCode; seconds = [Math]::Round($timer.Elapsed.TotalSeconds, 2); log = $logPath })
    [IO.File]::WriteAllText((Join-Path $outputRoot 'summary.json'), (ConvertTo-Json -InputObject @($results.ToArray()) -Depth 4), $utf8)
    if (-not $passed) {
        Write-Host (($output -split "`r?`n" | Select-Object -Last 25) -join "`n")
        throw "$Name failed or timed out. See $logPath"
    }
    $summary = @($output -split "`r?`n" | Where-Object { $_ -match 'SELF_TEST_PASS|QA_RESULT|MAP_QA |WINDOWS_QA_USER_DIR=' })
    if ($summary.Count) { Write-Host ($summary -join "`n") }
    return $output
}

Write-Host "Logs and isolated project: $outputRoot"
$probeOutput = Invoke-GodotCheck 'isolation' @('--script', 'res://tests/windows_isolation_probe.gd') 'WINDOWS_QA_USER_DIR='
$reported = [regex]::Match($probeOutput, '(?m)^WINDOWS_QA_USER_DIR=(.+)\r?$').Groups[1].Value.Trim()
$actualSaveRoot = [IO.Path]::GetFullPath($reported)
$expectedSaveRoot = [IO.Path]::GetFullPath((Join-Path $appData $runId))
if (-not $actualSaveRoot.Equals($expectedSaveRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Save isolation failed. Expected $expectedSaveRoot but Godot reported $actualSaveRoot. No test fixtures were run."
}
[void](Invoke-GodotCheck 'import' @('--editor', '--import') 'Godot Engine')
if (-not $AudioOnly) {
    if ('crystal-pacing' -in $Suites) { [void](Invoke-GodotCheck 'crystal-pacing' @('--script', 'res://tests/crystal_pacing_probe.gd') 'CRYSTAL_PACING_RESULT runs=216 terminated=216') }
    [void](Invoke-GodotCheck 'crystal-physics' @('--script', 'res://tests/crystal_physics_qa.gd') 'CRYSTAL PHYSICS QA: \d+ passed, 0 failed')
    [void](Invoke-GodotCheck 'crystal-area-ui' @('--script', 'res://tests/crystal_area_ui_qa.gd') 'CRYSTAL_AREA_UI_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'crystal-save' @('--script', 'res://tests/crystal_save_qa.gd', '--', '--crystal-save-qa-isolated') 'CRYSTAL_SAVE_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'crystal-art' @('--script', 'res://tests/crystal_art_qa.gd') 'CRYSTAL_ART_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'combat-balance' @('--script', 'res://tests/combat_balance_qa.gd') 'COMBAT_BALANCE_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'coin-feedback' @('--script', 'res://tests/coin_feedback_qa.gd') 'COIN_FEEDBACK_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'damage-feedback' @('--script', 'res://tests/damage_feedback_qa.gd') 'DAMAGE_FEEDBACK_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'self-test' @('--', '--self-test') 'SELF_TEST_PASS checks=\d+')
    [void](Invoke-GodotCheck 'upgrade-graph' @('--script', 'res://tests/upgrade_graph_qa.gd') 'UPGRADE_GRAPH_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'upgrade-layout' @('--script', 'res://tests/upgrade_layout_qa.gd') 'UPGRADE_LAYOUT_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'upgrade-arc-art' @('--script', 'res://tests/upgrade_arc_art_qa.gd') 'UPGRADE_ARC_ART_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-upgrade-graph' @('--script', 'res://tests/gelato_upgrade_graph_qa.gd') 'GELATO_UPGRADE_GRAPH_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-upgrade-map' @('--script', 'res://tests/gelato_upgrade_map_qa.gd') 'GELATO_UPGRADE_MAP_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-twin-node' @('--script', 'res://tests/gelato_twin_node_qa.gd') 'GELATO_TWIN_NODE_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-node-ownership' @('--script', 'res://tests/gelato_node_ownership_qa.gd', '--', '--node-ownership-qa-isolated') 'GELATO_NODE_OWNERSHIP_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'organic-boards' @('--script', 'res://tests/organic_boards_qa.gd') 'ORGANIC_BOARDS_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'bakery-durability' @('--script', 'res://tests/bakery_durability_qa.gd') 'BAKERY_DURABILITY_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'peg-tier-visual' @('--script', 'res://tests/peg_tier_visual_qa.gd') 'PEG_TIER_VISUAL_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'independent' @('--script', 'res://tests/independent_qa.gd') 'QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'resume' @('--script', 'res://tests/resume_qa.gd') 'RESUME_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'v04' @('--script', 'res://tests/v04_qa.gd') 'V04_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'map' @('--script', 'res://tests/v04_map_qa.gd') 'MAP_QA \d+ passed; 0 failed:')
    [void](Invoke-GodotCheck 'navigation' @('--script', 'res://tests/bakery_navigation_qa.gd') 'BAKERY_NAV_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'run-transition' @('--script', 'res://tests/run_transition_qa.gd') 'RUN_TRANSITION_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'first-run-guide' @('--script', 'res://tests/first_run_guide_qa.gd') 'FIRST_RUN_GUIDE_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'countdown-feedback' @('--script', 'res://tests/countdown_feedback_qa.gd') 'COUNTDOWN_FEEDBACK_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'final-ball-drain' @('--script', 'res://tests/final_ball_drain_qa.gd', '--', '--drain-qa-isolated') 'FINAL_BALL_DRAIN_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'whole-coins' @('--script', 'res://tests/whole_coin_qa.gd') 'WHOLE_COIN_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'run-comparison' @('--script', 'res://tests/run_comparison_qa.gd', '--', '--comparison-qa-isolated') 'RUN_COMPARISON_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'reset-progress' @('--script', 'res://tests/reset_progress_qa.gd', '--', '--reset-qa-isolated') 'RESET_PROGRESS_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'monetization' @('--script', 'res://tests/monetization_qa.gd', '--', '--monetization-qa-isolated') 'MONETIZATION_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'area-progression' @('--script', 'res://tests/area_progression_qa.gd', '--', '--area-qa-isolated') 'AREA_PROGRESSION_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-navigation' @('--script', 'res://tests/gelato_navigation_qa.gd') 'GELATO_NAV_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-launcher' @('--script', 'res://tests/gelato_launcher_qa.gd') 'GELATO_LAUNCHER_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-launcher-layout' @('--script', 'res://tests/gelato_launcher_layout_qa.gd') 'GELATO_LAUNCHER_LAYOUT_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-trajectory' @('--script', 'res://tests/gelato_trajectory_qa.gd') 'GELATO_TRAJECTORY_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-launcher-shop' @('--script', 'res://tests/gelato_launcher_shop_qa.gd') 'GELATO_LAUNCHER_SHOP_QA_RESULT: \d+ passed, 0 failed:')
    [void](Invoke-GodotCheck 'gelato-launcher-save' @('--script', 'res://tests/gelato_launcher_save_qa.gd', '--', '--gelato-save-qa-isolated') 'GELATO_LAUNCHER_SAVE_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'gelato-shop-migration' @('--script', 'res://tests/gelato_shop_migration_qa.gd', '--', '--gelato-shop-qa-isolated') 'GELATO_SHOP_MIGRATION_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'developer-area' @('--script', 'res://tests/developer_area_qa.gd', '--', '--developer-area-qa-isolated') 'DEVELOPER_AREA_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'developer-area-ui' @('--script', 'res://tests/developer_area_ui_qa.gd') 'DEVELOPER_AREA_UI_QA_RESULT passed=\d+ failed=0')
    [void](Invoke-GodotCheck 'developer-money' @('--script', 'res://tests/developer_money_qa.gd') 'DEVELOPER_MONEY_QA_RESULT passed=\d+ failed=0')
}
if ($IncludeAudio -or $AudioOnly) {
    [void](Invoke-GodotCheck 'audio-cache' @('--script', 'res://tests/performance/audio_cache_qa.gd') 'AUDIO_CACHE_QA_RESULT passed=\d+ failed=0')
}
Write-Host "All requested regression suites passed. Logs: $outputRoot"
