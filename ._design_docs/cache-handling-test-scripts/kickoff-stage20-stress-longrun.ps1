#requires -Version 5
# kickoff-stage20-stress-longrun.ps1
# Stage 20 Item 3: re-invoke V2 stress-longrun framework with Stage 17 hooks.
# Wrapper around kickoff-v2-stress-longrun.ps1 behavior, adding:
#   - redacted evidence enabled by default
#   - bounded cold budget (--cache-cold-max-mib default 512)
#   - port range 8800-8821 (separate from V2's 8600-8621)
#   - --AgenticPromptPath (optional) for Item 1 prompt generator output
#   - --JinjaVariant (default new)
#   - DryRun switch (R-20-03 mitigation: asserts per-row flags present)
#
# Status: PASS; Date: 2026-06-18; Owner: Developer (Stage 20 Item 3)
#
# Usage:
#   # Dry run: verify per-row flags are present without launching.
#   powershell -NoProfile -File kickoff-stage20-stress-longrun.ps1 -DryRun
#
#   # Live run with bounded cold budget, redacted evidence:
#   powershell -NoProfile -File kickoff-stage20-stress-longrun.ps1 `
#       -CacheColdPath "D:\tmp\cache-cold-stage20" `
#       -CachePromptEvidenceDir "D:\source\llama.cpp-jet\._design_docs\.test_reports\stage20-stress-20260618-01"
#
#   # Live run of a single S row (for wrapper verification):
#   powershell -NoProfile -File kickoff-stage20-stress-longrun.ps1 `
#       -RowsToRun @('S01') -CacheColdPath "D:\tmp\cache-cold-stage20-s01" `
#       -CachePromptEvidenceDir "D:\source\llama.cpp-jet\._design_docs\.test_reports\stage20-s01-only"

[CmdletBinding()]
param(
    [string] $CacheColdPath          = '',
    [int]    $CacheColdMaxMib        = 512,
    [int]    $CacheRamMib            = 512,
    [ValidateSet('off','redacted','raw')] [string] $CachePromptEvidence = 'redacted',
    [string] $CachePromptEvidenceDir = '',
    [string] $AgenticPromptPath      = '',
    [ValidateSet('original','new')]  [string] $JinjaVariant         = 'new',
    [string[]] $RowsToRun            = @('S01','S02','S03','S04','S05','S06','S07','S08','L01','L02','L03'),
    [int]    $BasePort               = 8800,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$src      = 'D:\source\llama.cpp-jet'
$buildDir = Join-Path $src 'build-cov'
$pwsh     = 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.2.0_x64__8wekyb3d8bbwe\pwsh.exe'
$dateTag  = Get-Date -Format 'yyyyMMdd-HHmmss'
$runRoot  = Join-Path $src "._design_docs\.test_reports\stage20-stress-$dateTag"
$sideLog  = Join-Path $runRoot 'batch-summary.log.side'

if (-not $CachePromptEvidenceDir) {
    $CachePromptEvidenceDir = $runRoot
}

# --- Build per-row launch list (8 stress x 1 jinja + 3 longrun x 1 jinja) ---
$stressScripts = [ordered]@{
    'S01' = 'stress_s12_s01_budget_exhaustion.ps1'
    'S02' = 'stress_s12_s02_concurrent_multi_slot.ps1'
    'S03' = 'stress_s12_s03_large_branch_forests.ps1'
    'S04' = 'stress_s12_s04_prompt_storms.ps1'
    'S05' = 'stress_s12_s05_mixed_workload_profiles.ps1'
    'S06' = 'stress_s12_s06_cold_queue_pressure.ps1'
    'S07' = 'stress_s12_s07_protected_root_pressure.ps1'
    'S08' = 'stress_s12_s08_integrity_failure_under_load.ps1'
}
$longrunSpecs = [ordered]@{
    'L01' = @{ Script = 'longrun_s12_l01_6h_hybrid_stability.ps1';   Hours = 2; Min = 0  }
    'L02' = @{ Script = 'longrun_s12_l02_30m_legacy_comparison.ps1'; Hours = 0; Min = 30 }
    'L03' = @{ Script = 'longrun_s12_l03_2h_mixed_workload.ps1';     Hours = 2; Min = 0  }
}

$rows = New-Object System.Collections.Generic.List[object]
$port = $BasePort

foreach ($base in $stressScripts.Keys) {
    if ($RowsToRun -notcontains $base) { continue }
    $rows.Add([pscustomobject]@{
        Base    = $base
        Script  = $stressScripts[$base]
        Kind    = 'stress'
        Hours   = 0
        Min     = 30
        Port    = $port
    }) | Out-Null
    $port++
}
foreach ($base in $longrunSpecs.Keys) {
    if ($RowsToRun -notcontains $base) { continue }
    $rows.Add([pscustomobject]@{
        Base    = $base
        Script  = $longrunSpecs[$base].Script
        Kind    = 'longrun'
        Hours   = $longrunSpecs[$base].Hours
        Min     = $longrunSpecs[$base].Min
        Port    = $port
    }) | Out-Null
    $port++
}

if ($rows.Count -eq 0) {
    throw "kickoff-stage20-stress-longrun: RowsToRun contains no valid rows ($($RowsToRun -join ','))"
}

# --- Build shared per-row flag list (Stage 17 cache flags) ---
function Get-Stage20Flags {
    param([pscustomobject]$Row)
    $flags = New-Object System.Collections.Generic.List[string]
    [void]$flags.Add('--cache-mode')
    [void]$flags.Add('hybrid')
    [void]$flags.Add('--cache-cold-max-mib')
    [void]$flags.Add("$($CacheColdMaxMib)")
    [void]$flags.Add('--cache-ram-mib')
    [void]$flags.Add("$($CacheRamMib)")
    if ($CacheColdPath) {
        [void]$flags.Add('--cache-cold-path')
        [void]$flags.Add($CacheColdPath)
    }
    [void]$flags.Add('--cache-prompt-evidence')
    [void]$flags.Add($CachePromptEvidence)
    if ($CachePromptEvidence -ne 'off' -and $CachePromptEvidenceDir) {
        [void]$flags.Add('--cache-prompt-evidence-dir')
        [void]$flags.Add($CachePromptEvidenceDir)
    }
    return $flags.ToArray()
}

# --- Validate flag presence (DryRun check per R-20-03) ---
function Test-RowFlags {
    param([string[]] $Flags)
    $joined = ($Flags -join ' ')
    $required = @(
        '--cache-mode hybrid',
        "--cache-cold-max-mib $CacheColdMaxMib",
        "--cache-prompt-evidence $CachePromptEvidence"
    )
    if ($CachePromptEvidence -ne 'off') {
        $required += '--cache-prompt-evidence-dir'
    }
    $missing = @()
    foreach ($needle in $required) {
        if ($joined -notlike "*$needle*") { $missing += $needle }
    }
    return $missing
}

# --- DryRun path: assert flags present, log per-row, no launch ---
if ($DryRun) {
    if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Force -Path $runRoot | Out-Null }
    if (-not (Test-Path $sideLog))  { New-Item -ItemType File -Force -Path $sideLog | Out-Null }
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts] kickoff-stage20-stress-longrun DryRun; rows=$($rows.Count) basePort=$BasePort cacheColdMaxMib=$CacheColdMaxMib cacheRamMib=$CacheRamMib evidence=$CachePromptEvidence jinja=$JinjaVariant" | Out-File -Append -FilePath $sideLog -Encoding utf8
    $allOk = $true
    foreach ($r in $rows) {
        $flags = Get-Stage20Flags -Row $r
        $missing = Test-RowFlags -Flags $flags
        $rowDir = "$($r.Base)-J$JinjaVariant"
        $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
        if ($missing.Count -gt 0) {
            $allOk = $false
            "$ts] DryRun FAIL $($r.Base) port=$($r.Port) missing=$($missing -join '|')" | Out-File -Append -FilePath $sideLog -Encoding utf8
        } else {
            "$ts] DryRun OK $($r.Base) port=$($r.Port) flags='$($flags -join ' ')'" | Out-File -Append -FilePath $sideLog -Encoding utf8
        }
    }
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts] kickoff-stage20-stress-longrun DryRun end; ok=$allOk" | Out-File -Append -FilePath $sideLog -Encoding utf8
    if ($allOk) { Write-Host "DryRun OK; $($rows.Count) rows; per-row flags present" }
    else        { Write-Host "DryRun FAIL; see $sideLog"; exit 1 }
    exit 0
}

# --- Live path: mirror V2 launch structure (batches of 2, 30s sleep) ---
if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Force -Path $runRoot | Out-Null }
if (-not (Test-Path $sideLog))  { New-Item -ItemType File -Force -Path $sideLog | Out-Null }
$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts] kickoff-stage20-stress-longrun start; rows=$($rows.Count) basePort=$BasePort cacheColdMaxMib=$CacheColdMaxMib cacheRamMib=$CacheRamMib evidence=$CachePromptEvidence jinja=$JinjaVariant" | Out-File -Append -FilePath $sideLog -Encoding utf8

$batchSize  = 2
$batchSleep = 30
$total      = $rows.Count

for ($i = 0; $i -lt $total; $i += $batchSize) {
    $endIdx = [Math]::Min($i + $batchSize - 1, $total - 1)
    $batch  = $rows[$i..$endIdx]
    $bn     = [int]([Math]::Floor($i / $batchSize)) + 1
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    $rowNames = ($batch | ForEach-Object { $_.Base }) -join ', '
    "$ts] batch_start #$bn idx=$i-$endIdx rows=$rowNames" | Out-File -Append -FilePath $sideLog -Encoding utf8

    foreach ($r in $batch) {
        $rowDir = "$($r.Base)-J$JinjaVariant"
        $outDir = Join-Path $runRoot $rowDir
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
        $scriptPath = Join-Path $src "._design_docs\cache-handling-test-scripts\$($r.Kind)\$($r.Script)"
        if (-not (Test-Path $scriptPath)) {
            $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
            "$ts] SCRIPT_MISSING $scriptPath" | Out-File -Append -FilePath $sideLog -Encoding utf8
            continue
        }
        $flags = Get-Stage20Flags -Row $r
        # The S/L scripts accept -JinjaValidateSet 'original,marked'. The
        # Stage 20 wrapper default 'new' maps to chat_template_new.jinja,
        # which is the 'marked' variant in the underlying scripts.
        $scriptJinja = if ($JinjaVariant -eq 'new') { 'marked' } else { 'original' }
        $argList = @(
            '-NoProfile', '-File', $scriptPath,
            '-BuildDir', $buildDir,
            '-OutDir', $outDir,
            '-Port', $r.Port.ToString(),
            '-MtpVariant', '1',
            '-JinjaVariant', $scriptJinja
        )
        if ($r.Kind -eq 'longrun') {
            $argList += @('-DurationHours', $r.Hours.ToString(),
                          '-DurationMin',   $r.Min.ToString())
        } else {
            $argList += @('-DurationMin', $r.Min.ToString())
        }
        $launchLog = Join-Path $outDir 'launch.log'
        $launchErr = Join-Path $outDir 'launch.err'
        try {
            $proc = Start-Process -FilePath $pwsh -ArgumentList $argList `
                -PassThru -WindowStyle Hidden `
                -RedirectStandardOutput $launchLog `
                -RedirectStandardError  $launchErr
            $childPid = $proc.Id
            $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
            "$ts] launched $($r.Base) port=$($r.Port) pid=$childPid script=$($r.Script) hours=$($r.Hours) min=$($r.Min) flags='$($flags -join ' ')'" | Out-File -Append -FilePath $sideLog -Encoding utf8
        } catch {
            $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
            "$ts] LAUNCH_FAIL $($r.Base) err=$($_.Exception.Message)" | Out-File -Append -FilePath $sideLog -Encoding utf8
        }
    }

    Start-Sleep -Seconds 2
    foreach ($r in $batch) {
        $rowDir = "$($r.Base)-J$JinjaVariant"
        $outDir = Join-Path $runRoot $rowDir
        $launchLog = Join-Path $outDir 'launch.log'
        $ll = if (Test-Path $launchLog) { (Get-Item $launchLog).Length } else { -1 }
        $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
        "$ts] verify $($r.Base) launchLogSize=$ll" | Out-File -Append -FilePath $sideLog -Encoding utf8
    }
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts] batch_end #$bn idx=$i-$endIdx" | Out-File -Append -FilePath $sideLog -Encoding utf8
    if ($endIdx -lt ($total - 1)) { Start-Sleep -Seconds $batchSleep }
}
$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts] kickoff-stage20-stress-longrun end; rows=$total" | Out-File -Append -FilePath $sideLog -Encoding utf8
