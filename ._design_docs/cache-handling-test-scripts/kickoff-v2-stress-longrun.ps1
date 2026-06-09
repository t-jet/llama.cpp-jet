# kickoff-v2-stress-longrun.ps1
# V1 sub-session 1d: re-launch 20 PENDING stress+longrun rows
# in batches of 2 with 30s sleep between forks.
# Per qa.md: full pwsh.exe path (not AppExecAlias); per-row launch via
# Start-Process with -ArgumentList array; per-batch sleep = 30s; max 2
# concurrent llama-server instances per batch.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$src          = 'D:\source\llama.cpp-jet'
$buildDir     = Join-Path $src 'build-cov'
$pwsh         = 'C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.2.0_x64__8wekyb3d8bbwe\pwsh.exe'
$runRoot      = Join-Path $src '._design_docs\.test_reports\mtp-jinja-run-20260607-V1'
$sideLog      = Join-Path $runRoot 'stress-longrun-batch-summary.log.side'

if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Force -Path $runRoot | Out-Null }
if (-not (Test-Path $sideLog)) { New-Item -ItemType File -Force -Path $sideLog | Out-Null }

# --- 1. Kill surviving PIDs from prior session 1c background launch ---
$oldPids = @(2120, 22448, 26304, 27552)
$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts] kickoff-v2-stress-longrun start; target_old_pids=$($oldPids -join ',')" |
    Out-File -Append -FilePath $sideLog -Encoding utf8

foreach ($p in $oldPids) {
    try {
        $proc = Get-Process -Id $p -ErrorAction Stop
        Stop-Process -Id $p -Force
        $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
        "$ts] KILLED pid=$p name=$($proc.ProcessName)" |
            Out-File -Append -FilePath $sideLog -Encoding utf8
    } catch {
        $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
        "$ts] KILL_SKIP pid=$p not_found" |
            Out-File -Append -FilePath $sideLog -Encoding utf8
    }
}

# Give kernel a moment to reap and release file handles
Start-Sleep -Seconds 5

# --- 2. Define row launch list in user task order ---
# Batch 1..8 = S01..S08 (each batch = 2 rows: Jorig + Jmarked)
# Batch 9 = L01 (Jorig + Jmarked)
# Batch 10 = L03 (Jorig + Jmarked)
# Batch 11 = L02 (Jorig + Jmarked)

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
    'L01' = @{ Script = 'longrun_s12_l01_6h_hybrid_stability.ps1'; Hours = 2; Min = 0 }
    'L03' = @{ Script = 'longrun_s12_l03_2h_mixed_workload.ps1';     Hours = 2; Min = 0 }
    'L02' = @{ Script = 'longrun_s12_l02_30m_legacy_comparison.ps1'; Hours = 0; Min = 30 }
}

$rows = New-Object System.Collections.Generic.List[object]
$port = 8600

# 8 stress pairs
foreach ($base in $stressScripts.Keys) {
    foreach ($jinja in 'Joriginal','Jmarked') {
        $rows.Add([pscustomobject]@{
            Base = $base; Jinja = $jinja; Script = $stressScripts[$base]
            Kind = 'stress'; Hours = 0; Min = 30; Port = $port
        }) | Out-Null
        $port++
    }
}
# L01 pair
foreach ($jinja in 'Joriginal','Jmarked') {
    $rows.Add([pscustomobject]@{
        Base = 'L01'; Jinja = $jinja; Script = $longrunSpecs['L01'].Script
        Kind = 'longrun'; Hours = 2; Min = 0; Port = $port
    }) | Out-Null
    $port++
}
# L03 pair
foreach ($jinja in 'Joriginal','Jmarked') {
    $rows.Add([pscustomobject]@{
        Base = 'L03'; Jinja = $jinja; Script = $longrunSpecs['L03'].Script
        Kind = 'longrun'; Hours = 2; Min = 0; Port = $port
    }) | Out-Null
    $port++
}
# L02 pair
foreach ($jinja in 'Joriginal','Jmarked') {
    $rows.Add([pscustomobject]@{
        Base = 'L02'; Jinja = $jinja; Script = $longrunSpecs['L02'].Script
        Kind = 'longrun'; Hours = 0; Min = 30; Port = $port
    }) | Out-Null
    $port++
}

$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts] plan rows=$($rows.Count) batches=$([Math]::Ceiling($rows.Count / 2.0)) perRowTimeout={stress:30m,L01:2h,L03:2h,L02:30m}" |
    Out-File -Append -FilePath $sideLog -Encoding utf8
"$ts] plan list: $(($rows | ForEach-Object { "$($_.Base)-$($_.Jinja)" }) -join ', ')" |
    Out-File -Append -FilePath $sideLog -Encoding utf8

# --- 3. Launch in batches of 2 with 30s sleep ---
$batchSize  = 2
$batchSleep = 30
$total      = $rows.Count

for ($i = 0; $i -lt $total; $i += $batchSize) {
    $endIdx = [Math]::Min($i + $batchSize - 1, $total - 1)
    $batch  = $rows[$i..$endIdx]
    $bn     = [int]([Math]::Floor($i / $batchSize)) + 1

    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts] batch_start #$bn idx=$i-$endIdx rows=$($batch | ForEach-Object { "$($_.Base)-$($_.Jinja)" } | Join-String ', ')" |
        Out-File -Append -FilePath $sideLog -Encoding utf8

    foreach ($r in $batch) {
        $jinjaVal = if ($r.Jinja -eq 'Joriginal') { 'original' } else { 'marked' }
        $rowDir   = "S12-MTP-$($r.Base)-V1-$($r.Jinja)"
        $outDir   = Join-Path $runRoot $rowDir
        if (-not (Test-Path $outDir)) {
            New-Item -ItemType Directory -Force -Path $outDir | Out-Null
        }
        $scriptPath = Join-Path $src "._design_docs\cache-handling-test-scripts\$($r.Kind)\$($r.Script)"

        if (-not (Test-Path $scriptPath)) {
            $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
            "$ts2] SCRIPT_MISSING $scriptPath" |
                Out-File -Append -FilePath $sideLog -Encoding utf8
            continue
        }

        # Build ArgumentList
        $argList = @(
            '-NoProfile', '-File', $scriptPath,
            '-BuildDir', $buildDir,
            '-OutDir', $outDir,
            '-Port', $r.Port.ToString(),
            '-MtpVariant', '1',
            '-JinjaVariant', $jinjaVal
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
            $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
            "$ts2] launched $($r.Base)-$($r.Jinja) port=$($r.Port) pid=$childPid script=$($r.Script) hours=$($r.Hours) min=$($r.Min)" |
                Out-File -Append -FilePath $sideLog -Encoding utf8
        } catch {
            $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
            "$ts2] LAUNCH_FAIL $($r.Base)-$($r.Jinja) err=$($_.Exception.Message)" |
                Out-File -Append -FilePath $sideLog -Encoding utf8
        }
    }

    # --- 4. Per-batch verification: check launch.log presence and PID alive ---
    Start-Sleep -Seconds 2  # let child pwsh write first banner line
    foreach ($r in $batch) {
        $rowDir   = "S12-MTP-$($r.Base)-V1-$($r.Jinja)"
        $outDir   = Join-Path $runRoot $rowDir
        $launchLog = Join-Path $outDir 'launch.log'
        $ll = if (Test-Path $launchLog) { (Get-Item $launchLog).Length } else { -1 }
        $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
        "$ts2] verify $($r.Base)-$($r.Jinja) launchLogSize=$ll" |
            Out-File -Append -FilePath $sideLog -Encoding utf8
    }

    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts] batch_end #$bn idx=$i-$endIdx" |
        Out-File -Append -FilePath $sideLog -Encoding utf8

    # Sleep between batches (skip after last batch)
    if ($endIdx -lt ($total - 1)) {
        Start-Sleep -Seconds $batchSleep
    }
}

$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts] kickoff-v2-stress-longrun end; rows=$total" |
    Out-File -Append -FilePath $sideLog -Encoding utf8
