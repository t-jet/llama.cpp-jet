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
#       -RunRoot "D:\source\llama.cpp-jet\._test_output\stage20-stress-20260618-01"
#
#   # Live run of a single S row (for wrapper verification):
#   powershell -NoProfile -File kickoff-stage20-stress-longrun.ps1 `
#       -RowsToRun @('S01') -CacheColdPath "D:\tmp\cache-cold-stage20-s01" `
#       -RunRoot "D:\source\llama.cpp-jet\._test_output\stage20-s01-only"

[CmdletBinding()]
param(
    [string] $CacheColdPath          = '',
    [int]    $CacheColdMaxMib        = 512,
    [int]    $CacheRamMib            = 512,
    [ValidateSet('off','redacted','raw')] [string] $CachePromptEvidence = 'redacted',
    [string] $CachePromptEvidenceDir = '',
    [string] $ModelPath              = '',
    [string] $S06PressureModelPath   = '',
    [string] $RunRoot                = '',
    [string] $BuildDir               = '',
    [string] $AgenticPromptPath      = '',
    [string] $NvidiaGpuLayers        = 'all',
    [ValidateSet('on','off')] [string] $FitMode = 'off',
    [ValidateSet('original','new')]  [string] $JinjaVariant         = 'new',
    [string[]] $RowsToRun            = @('S01','S02','S03','S04','S05','S06','S07','S08','L01','L02','L03'),
    [int]    $BasePort               = 8800,
    [int]    $BatchSize              = 2,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$src      = 'D:\source\llama.cpp-jet'
$buildDir = if ($BuildDir) { $BuildDir } else { Join-Path $src 'build-cov' }
$pwshCmd  = Get-Command pwsh -ErrorAction SilentlyContinue
$pwsh     = if ($pwshCmd) { $pwshCmd.Source } else { (Get-Command powershell -ErrorAction Stop).Source }
$dateTag  = Get-Date -Format 'yyyyMMdd-HHmmss'
$defaultModelPath = Join-Path $src '._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf'
if (-not $ModelPath) {
    $ModelPath = if ($env:LLAMA_CACHE_TEST_MODEL) { $env:LLAMA_CACHE_TEST_MODEL }
                 else { $defaultModelPath }
}
if (-not $S06PressureModelPath) {
    $S06PressureModelPath = Join-Path $src '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
}
if (-not $RunRoot) {
    $RunRoot = Join-Path $src "._test_output\stage20-stress-longrun-$dateTag"
}
$runRoot  = $RunRoot
$sideLog  = Join-Path $runRoot 'batch-summary.log.side'

if (-not $CachePromptEvidenceDir) {
    $CachePromptEvidenceDir = Join-Path $runRoot 'prompt-evidence'
}
if ($BatchSize -lt 1 -or $BatchSize -gt 2) {
    throw "kickoff-stage20-stress-longrun: BatchSize must be 1 or 2"
}

function Ensure-Stage20Directory {
    param(
        [string] $Path,
        [string] $Label
    )
    if (-not $Path) {
        return
    }
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
    if (-not (Test-Path $Path -PathType Container)) {
        throw "kickoff-stage20-stress-longrun: $Label is not a directory: $Path"
    }
}

function Write-SideLog {
    param([string] $Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts] $Message" | Out-File -Append -FilePath $sideLog -Encoding utf8
}

function Convert-ServerArgsToBase64 {
    param([string[]] $ServerArgs)
    $json = $ServerArgs | ConvertTo-Json -Compress
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($json))
}

function Write-BatchGate {
    param([int] $BatchNumber, [object[]] $Batch)
    $ports = @($Batch | ForEach-Object { $_.Port })
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object { $ports -contains $_.LocalPort } |
        Select-Object -ExpandProperty LocalPort)
    $drive = Get-PSDrive -Name ((Resolve-Path $src).Path.Substring(0,1))
    $coldItems = if ($CacheColdPath -and (Test-Path $CacheColdPath)) {
        @(Get-ChildItem -LiteralPath $CacheColdPath -Force -ErrorAction SilentlyContinue).Count
    } else { -1 }
    $probe = Join-Path $runRoot (".write-probe-batch-{0}.tmp" -f $BatchNumber)
    Set-Content -LiteralPath $probe -Value 'ok' -Encoding ascii
    Remove-Item -LiteralPath $probe -Force
    Write-SideLog ("batch_gate #{0} ports={1} listeners={2} diskFreeBytes={3} coldItems={4} runRootWritable=true" -f
        $BatchNumber, ($ports -join ','), ($listeners -join ','), $drive.Free, $coldItems)
}

function Write-RowGate {
    param([pscustomobject] $Row, [string] $OutDir, [int] $ExitCode)
    $requiredNames = @('server.out.log','server.err.log','metrics-before.txt','metrics-after.txt')
    $present = @()
    $missing = @()
    foreach ($name in $requiredNames) {
        if (Get-ChildItem -LiteralPath $OutDir -Recurse -Filter $name -ErrorAction SilentlyContinue | Select-Object -First 1) {
            $present += $name
        } else {
            $missing += $name
        }
    }
    $evidenceFiles = @(Get-ChildItem -LiteralPath $OutDir -Recurse -File -ErrorAction SilentlyContinue).Count
    $ok = ($ExitCode -eq 0 -and $missing.Count -eq 0)
    Write-SideLog ("row_gate {0} exitCode={1} ok={2} evidenceFiles={3} present={4} missing={5} outDir={6}" -f
        $Row.Base, $ExitCode, $ok, $evidenceFiles, ($present -join ','), ($missing -join ','), $OutDir)
    return $ok
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
    if ($Row.Base -ne 'S06') {
        [void]$flags.Add('--cache-ram')
        [void]$flags.Add("$($CacheRamMib)")
    }
    [void]$flags.Add('--n-gpu-layers')
    [void]$flags.Add("$($NvidiaGpuLayers)")
    [void]$flags.Add('--fit')
    [void]$flags.Add($FitMode)
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
        "--cache-prompt-evidence $CachePromptEvidence",
        "--n-gpu-layers $NvidiaGpuLayers",
        "--fit $FitMode"
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

function Format-S05ProfileAllocation {
    param([int] $DurationMin)
    $rowSeconds = [Math]::Max(1, $DurationMin * 60)
    $profileCount = 3
    $baseSeconds = [Math]::Max(1, [int][Math]::Floor($rowSeconds / $profileCount))
    $lastSeconds = [Math]::Max(1, $rowSeconds - ($baseSeconds * ($profileCount - 1)))
    return "plain-transformer=$baseSeconds,target-plus-draft=$baseSeconds,checkpoint-dependent=$lastSeconds"
}

function Format-S06HotBudget {
    param([int] $HotBudgetMiB)
    return "effective_cache_ram_mib=$HotBudgetMiB source=S06-HotBudgetMiB wrapper_cache_ram_mib=$CacheRamMib stage17_cache_ram_appended=false"
}

function Format-S06PressureWorkload {
    $fixtureState = if (Test-Path $S06PressureModelPath) { 'available' } else { 'missing' }
    return "pressure_model=$S06PressureModelPath pressure_model_state=$fixtureState mtp_variant=2 unique_prompt_per_request=true expected_payload_fit=below_16MiB"
}

# --- DryRun path: assert flags present, log per-row, no launch ---
if ($DryRun) {
    if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Force -Path $runRoot | Out-Null }
    if (-not (Test-Path $sideLog))  { New-Item -ItemType File -Force -Path $sideLog | Out-Null }
    Ensure-Stage20Directory -Path $CacheColdPath -Label 'CacheColdPath'
    if ($CachePromptEvidence -ne 'off') {
        Ensure-Stage20Directory -Path $CachePromptEvidenceDir -Label 'CachePromptEvidenceDir'
    }
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    Write-SideLog "kickoff-stage20-stress-longrun DryRun; rows=$($rows.Count) basePort=$BasePort batchSize=$BatchSize model=$ModelPath runRoot=$runRoot cacheColdMaxMib=$CacheColdMaxMib cacheRamMib=$CacheRamMib evidence=$CachePromptEvidence jinja=$JinjaVariant"
    $allOk = $true
    foreach ($r in $rows) {
        $flags = Get-Stage20Flags -Row $r
        $missing = Test-RowFlags -Flags $flags
        $rowDir = "$($r.Base)-J$JinjaVariant"
        $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
        if ($missing.Count -gt 0) {
            $allOk = $false
            Write-SideLog "DryRun FAIL $($r.Base) port=$($r.Port) missing=$($missing -join '|')"
        } else {
            Write-SideLog "DryRun OK $($r.Base) port=$($r.Port) model=$ModelPath outDir=$(Join-Path $runRoot $rowDir) flags='$($flags -join ' ')'"
            if ($r.Base -eq 'S05') {
                Write-SideLog "DryRun S05 profile_allocation rowCapSeconds=$($r.Min * 60) allocations=$(Format-S05ProfileAllocation -DurationMin $r.Min)"
            }
            if ($r.Base -eq 'S06') {
                Write-SideLog "DryRun S06 hot_budget $(Format-S06HotBudget -HotBudgetMiB 16)"
                Write-SideLog "DryRun S06 pressure_workload $(Format-S06PressureWorkload)"
            }
        }
    }
    Write-SideLog "kickoff-stage20-stress-longrun DryRun end; ok=$allOk"
    if ($allOk) { Write-Host "DryRun OK; $($rows.Count) rows; per-row flags present" }
    else        { Write-Host "DryRun FAIL; see $sideLog"; exit 1 }
    exit 0
}

# --- Live path: mirror V2 launch structure (batches of 2, 30s sleep) ---
if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Force -Path $runRoot | Out-Null }
if (-not (Test-Path $sideLog))  { New-Item -ItemType File -Force -Path $sideLog | Out-Null }
Ensure-Stage20Directory -Path $CacheColdPath -Label 'CacheColdPath'
if ($CachePromptEvidence -ne 'off') {
    Ensure-Stage20Directory -Path $CachePromptEvidenceDir -Label 'CachePromptEvidenceDir'
}
$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
Write-SideLog "kickoff-stage20-stress-longrun start; rows=$($rows.Count) basePort=$BasePort batchSize=$BatchSize model=$ModelPath runRoot=$runRoot cacheColdMaxMib=$CacheColdMaxMib cacheRamMib=$CacheRamMib evidence=$CachePromptEvidence jinja=$JinjaVariant"

$batchSize  = $BatchSize
$batchSleep = 30
$total      = $rows.Count
$hadFailure = $false

for ($i = 0; $i -lt $total; $i += $batchSize) {
    $endIdx = [Math]::Min($i + $batchSize - 1, $total - 1)
    $batch  = $rows[$i..$endIdx]
    $bn     = [int]([Math]::Floor($i / $batchSize)) + 1
    $rowNames = ($batch | ForEach-Object { $_.Base }) -join ', '
    Write-SideLog "batch_start #$bn idx=$i-$endIdx rows=$rowNames"
    Write-BatchGate -BatchNumber $bn -Batch $batch

    $launched = New-Object System.Collections.Generic.List[object]

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
        $rowMtpVariant = if ($r.Base -eq 'S06' -and (Test-Path $S06PressureModelPath)) { '2' } else { '1' }
        $argList = @(
            '-NoProfile', '-File', $scriptPath,
            '-BuildDir', $buildDir,
            '-ModelPath', $ModelPath,
            '-OutDir', $outDir,
            '-Port', $r.Port.ToString(),
            '-MtpVariant', $rowMtpVariant,
            '-JinjaVariant', $scriptJinja,
            '-Stage17ServerArgsBase64', (Convert-ServerArgsToBase64 -ServerArgs $flags)
        )
        if ($r.Kind -eq 'longrun') {
            $argList += @('-DurationHours', $r.Hours.ToString(),
                          '-DurationMin',   $r.Min.ToString())
        } else {
            $argList += @('-DurationMin', $r.Min.ToString())
            if ($r.Base -eq 'S06') {
                $argList += @('-HotBudgetMiB', '16')
                $argList += @('-PressureModelPath', $S06PressureModelPath)
            }
        }
        $launchLog = Join-Path $outDir 'launch.log'
        $launchErr = Join-Path $outDir 'launch.err'
        try {
            $proc = Start-Process -FilePath $pwsh -ArgumentList $argList `
                -PassThru -WindowStyle Hidden `
                -RedirectStandardOutput $launchLog `
                -RedirectStandardError  $launchErr
            $childPid = $proc.Id
            $launched.Add([pscustomobject]@{ Row = $r; Process = $proc; OutDir = $outDir }) | Out-Null
            Write-SideLog "launched $($r.Base) port=$($r.Port) pid=$childPid script=$($r.Script) hours=$($r.Hours) min=$($r.Min) flags='$($flags -join ' ')'"
            if ($r.Base -eq 'S05') {
                Write-SideLog "S05 profile_allocation rowCapSeconds=$($r.Min * 60) allocations=$(Format-S05ProfileAllocation -DurationMin $r.Min)"
            }
            if ($r.Base -eq 'S06') {
                Write-SideLog "S06 hot_budget $(Format-S06HotBudget -HotBudgetMiB 16)"
                Write-SideLog "S06 pressure_workload $(Format-S06PressureWorkload)"
            }
        } catch {
            Write-SideLog "LAUNCH_FAIL $($r.Base) err=$($_.Exception.Message)"
        }
    }

    Start-Sleep -Seconds 2
    foreach ($r in $batch) {
        $rowDir = "$($r.Base)-J$JinjaVariant"
        $outDir = Join-Path $runRoot $rowDir
        $launchLog = Join-Path $outDir 'launch.log'
        $ll = if (Test-Path $launchLog) { (Get-Item $launchLog).Length } else { -1 }
        Write-SideLog "verify $($r.Base) launchLogSize=$ll"
    }
    foreach ($item in $launched) {
        $item.Process.WaitForExit()
        $rowOk = Write-RowGate -Row $item.Row -OutDir $item.OutDir -ExitCode $item.Process.ExitCode
        if (-not $rowOk) { $hadFailure = $true }
    }
    Write-SideLog "batch_end #$bn idx=$i-$endIdx"
    if ($endIdx -lt ($total - 1)) { Start-Sleep -Seconds $batchSleep }
}
Write-SideLog "kickoff-stage20-stress-longrun end; rows=$total ok=$(-not $hadFailure)"
if ($hadFailure) { exit 1 }
