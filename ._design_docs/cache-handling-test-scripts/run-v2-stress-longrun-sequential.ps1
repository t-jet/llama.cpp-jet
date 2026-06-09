#requires -Version 5
# Stage 12 V2 stress + long-run follow-up runner.
# Runs one row at a time so the host does not carry multiple Qwen3-8B servers.

[CmdletBinding()]
param(
    [string] $SourceRoot = 'D:\source\llama.cpp-jet',
    [string] $BuildDir = 'D:\source\llama.cpp-jet\build-cov',
    [string] $RunRoot = 'D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260609-V2',
    [string] $ModelPath = 'D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf',
    [int] $StressDurationMin = 30,
    [int] $LongRunDurationMin = 1
)

$ErrorActionPreference = 'Continue'
$ps5 = 'C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe'
$sideLog = Join-Path $RunRoot 'stress-longrun-v2-sequential.log'

if (-not (Test-Path $RunRoot)) { New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null }

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
$longrunScripts = [ordered]@{
    'L01' = 'longrun_s12_l01_6h_hybrid_stability.ps1'
    'L02' = 'longrun_s12_l02_30m_legacy_comparison.ps1'
    'L03' = 'longrun_s12_l03_2h_mixed_workload.ps1'
}

$rows = New-Object System.Collections.Generic.List[object]
$port = 8600
foreach ($base in $stressScripts.Keys) {
    foreach ($jinja in 'original','marked') {
        $rows.Add([pscustomobject]@{ Base=$base; Kind='stress'; Script=$stressScripts[$base]; Jinja=$jinja; Port=$port; Min=$StressDurationMin }) | Out-Null
        $port++
    }
}
foreach ($base in $longrunScripts.Keys) {
    foreach ($jinja in 'original','marked') {
        $rows.Add([pscustomobject]@{ Base=$base; Kind='longrun'; Script=$longrunScripts[$base]; Jinja=$jinja; Port=$port; Min=$LongRunDurationMin }) | Out-Null
        $port++
    }
}

"$(Get-Date -Format o) V2 stress-longrun start rows=$($rows.Count) stress_min=$StressDurationMin longrun_min=$LongRunDurationMin model=$ModelPath" |
    Out-File -FilePath $sideLog -Encoding utf8

foreach ($r in $rows) {
    $rowId = "S12-MTP-$($r.Base)-V2-J$($r.Jinja)"
    $outDir = Join-Path $RunRoot $rowId
    $scriptPath = Join-Path $SourceRoot "._design_docs\cache-handling-test-scripts\$($r.Kind)\$($r.Script)"
    if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

    if (-not (Test-Path $scriptPath)) {
        "$(Get-Date -Format o) SCRIPT_MISSING $rowId $scriptPath" | Out-File -FilePath $sideLog -Append -Encoding utf8
        continue
    }

    Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2

    $args = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath,
        '-BuildDir', $BuildDir,
        '-ModelPath', $ModelPath,
        '-OutDir', $outDir,
        '-Port', "$($r.Port)",
        '-MtpVariant', '2',
        '-JinjaVariant', $r.Jinja,
        '-DurationMin', "$($r.Min)"
    )

    $capSeconds = ($r.Min * 60) + 600
    "$(Get-Date -Format o) start $rowId port=$($r.Port) cap=${capSeconds}s" |
        Out-File -FilePath $sideLog -Append -Encoding utf8
    $start = Get-Date
    $proc = Start-Process -FilePath $ps5 -ArgumentList $args -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $outDir 'launch.log') `
        -RedirectStandardError (Join-Path $outDir 'launch.err')
    $exited = $proc.WaitForExit($capSeconds * 1000)
    if (-not $exited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $verdict = 'BLOCKED-infra-timeout'
    } else {
        $verdict = 'NO-EVIDENCE'
        $summary = Get-ChildItem -Path $outDir -Recurse -Filter evidence-summary.md -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($summary) {
            $line = Select-String -Path $summary.FullName -Pattern '^Result:\s*(\S+)' | Select-Object -First 1
            if ($line) { $verdict = ($line.Line -split ':')[-1].Trim() }
        }
    }
    $elapsed = [int]((Get-Date) - $start).TotalSeconds
    "$(Get-Date -Format o) end $rowId elapsed=${elapsed}s verdict=$verdict" |
        Out-File -FilePath $sideLog -Append -Encoding utf8

    Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 10
}

"$(Get-Date -Format o) V2 stress-longrun end" | Out-File -FilePath $sideLog -Append -Encoding utf8
