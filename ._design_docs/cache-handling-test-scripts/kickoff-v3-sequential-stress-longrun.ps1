# kickoff-v3-sequential-stress-longrun.ps1
# V1 sub-session 1e: re-launch 22 PENDING stress+longrun rows
# SEQUENTIALLY (one driver at a time, no concurrent llama-server).
# Per-row wall-clock caps lowered to fit host RAM (--parallel=1
# already 512 ctx-size, so mem savings come from single instance
# per launch + reduced parallel slots). Each driver runs
# Start-Process of llama-server; the kickoff waits for the driver
# to exit, then advances to the next row. On per-row timeout the
# kickoff kills the driver and its llama-server, marks
# BLOCKED-infrastructure-limited, and continues.

[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'
$src      = 'D:\source\llama.cpp-jet'
$buildDir = Join-Path $src 'build-cov'
$runRoot  = Join-Path $src '._design_docs\.test_reports\mtp-jinja-run-20260607-V1'
$sideLog  = Join-Path $runRoot 'stress-longrun-batch-summary.log.side'

if (-not (Test-Path $runRoot)) { New-Item -ItemType Directory -Force -Path $runRoot | Out-Null }
if (-not (Test-Path $sideLog))  { New-Item -ItemType File -Force -Path $sideLog | Out-Null }

$ts0 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts0] kickoff-v3-sequential-stress-longrun start" |
    Out-File -Append -FilePath $sideLog -Encoding utf8

# --- 1. Kill any surviving llama-server / stale pwshs ---
Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process -Name 'pwsh' -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match 'cache-handling-test-scripts|stress_s12_|longrun_s12_|bench_s12_|kickoff-v2|run-v1-bench|run-v2-bench' } |
    ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
Start-Sleep -Seconds 5

# --- 2. Row plan in user task order ---
# 16 stress: S01..S08 x 2 jinja, 30m cap each
# 6 longrun: L01 (2h), L02 (30m), L03 (2h) x 2 jinja
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

foreach ($base in $stressScripts.Keys) {
    foreach ($jinja in 'Joriginal','Jmarked') {
        $rows.Add([pscustomobject]@{
            Base = $base; Jinja = $jinja; Script = $stressScripts[$base]
            Kind = 'stress'; Hours = 0; Min = 30; Port = $port
        }) | Out-Null
        $port++
    }
}
foreach ($base in 'L01','L03','L02') {
    foreach ($jinja in 'Joriginal','Jmarked') {
        $rows.Add([pscustomobject]@{
            Base = $base; Jinja = $jinja; Script = $longrunSpecs[$base].Script
            Kind = 'longrun'; Hours = $longrunSpecs[$base].Hours; Min = $longrunSpecs[$base].Min; Port = $port
        }) | Out-Null
        $port++
    }
}

$totalBudgetSec = 0
foreach ($r in $rows) {
    $totalBudgetSec += ($r.Hours * 3600) + ($r.Min * 60)
}
$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts] plan rows=$($rows.Count) total_budget_sec=$totalBudgetSec ($([Math]::Round($totalBudgetSec/3600.0,2))h)" |
    Out-File -Append -FilePath $sideLog -Encoding utf8
"$ts] plan list: $(($rows | ForEach-Object { "$($_.Base)-$($_.Jinja)" }) -join ', ')" |
    Out-File -Append -FilePath $sideLog -Encoding utf8

# --- 3. Sequential launch: one driver at a time ---
foreach ($r in $rows) {
    $jinjaVal = if ($r.Jinja -eq 'Joriginal') { 'original' } else { 'marked' }
    $rowDir = "S12-MTP-$($r.Base)-V1-$($r.Jinja)"
    $outDir = Join-Path $runRoot $rowDir
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

    $scriptPath = Join-Path $src "._design_docs\cache-handling-test-scripts\$($r.Kind)\$($r.Script)"
    if (-not (Test-Path $scriptPath)) {
        $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
        "$ts2] SCRIPT_MISSING $rowDir script=$scriptPath" |
            Out-File -Append -FilePath $sideLog -Encoding utf8
        continue
    }

    $capSeconds = ($r.Hours * 3600) + ($r.Min * 60) + 300  # +5 min startup/flush grace
    $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts2] start $rowDir port=$($r.Port) cap=${capSeconds}s" |
        Out-File -Append -FilePath $sideLog -Encoding utf8

    $driverStart = Get-Date
    $ps5 = 'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe'
    $argList = @('-NoProfile','-File',$scriptPath,
        '-BuildDir',$buildDir,
        '-OutDir',$outDir,
        '-Port',$r.Port.ToString(),
        '-MtpVariant','1',
        '-JinjaVariant',$jinjaVal,
        '-ParallelSlots','1')
    if ($r.Hours -gt 0) { $argList += @('-DurationHours',$r.Hours.ToString()) }
    if ($r.Min   -gt 0) { $argList += @('-DurationMin',  $r.Min.ToString())   }

    $proc = Start-Process -FilePath $ps5 -ArgumentList $argList `
        -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $outDir 'launch.log') `
        -RedirectStandardError  (Join-Path $outDir 'launch.err')
    $driverPid = $proc.Id
    $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts2]   driver pid=$driverPid args=$($argList -join ' ')" |
        Out-File -Append -FilePath $sideLog -Encoding utf8

    $exited = $proc.WaitForExit($capSeconds * 1000)
    if (-not $exited) {
        try { Stop-Process -Id $driverPid -Force -ErrorAction Stop } catch {}
        Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Stop-Process -Force
        $verdict = 'BLOCKED-infrastructure-limited'
        $note = "row wall-clock cap ${capSeconds}s exceeded; driver still running"
    } else {
        $verdict = 'UNKNOWN'
        $esPath = Join-Path $outDir 'evidence-summary.md'
        if (Test-Path $esPath) {
            $es = Get-Content $esPath -Raw
            if ($es -match '(?im)^Result:\s*(PASS|FAIL|BLOCKED|PENDING)\b') {
                $verdict = $Matches[1]
            }
        } else {
            $verdict = 'NO-EVIDENCE'
        }
    }
    $elapsed = [int]((Get-Date) - $driverStart).TotalSeconds
    $ts2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
    "$ts2] end $rowDir elapsed=${elapsed}s verdict=$verdict" |
        Out-File -Append -FilePath $sideLog -Encoding utf8

    # Always kill any leftover llama-server before next row
    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 30  # 30s settle between rows for kernel reaping
}

$ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'
"$ts] kickoff-v3-sequential-stress-longrun end" |
    Out-File -Append -FilePath $sideLog -Encoding utf8
