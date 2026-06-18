<#
Stage 20 heavy tier kickoff wrapper.

Runs TP-20-HV1 (heavy agentic workload) and TP-20-HV2 (comparison to
Stage 16 baseline). Based on Stage 20 design part 3 stub.

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File kickoff-stage20-heavy.ps1
      -RowsToRun HV1,HV2
      -CacheColdPath 'D:\tmp\cache-cold-stage20-hv'
      -CacheColdMaxMib 4096
      -CacheRamMib 2048
      -TimeBudgetMin 30
      -BaselineLogPath 'd:\source\llama.cpp-jet\._analysis\model_log.txt'

Per-row cap defaults to 240 min (4 hours) per Stage 20 design part 3 stub.
Chat-feasible runs can override -TimeBudgetMin.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('HV1','HV2')]
    [string[]] $RowsToRun = @('HV1','HV2'),

    [Parameter(Mandatory=$true)]
    [string] $CacheColdPath,

    [Parameter(Mandatory=$false)]
    [int] $CacheColdMaxMib = 4096,

    [Parameter(Mandatory=$false)]
    [int] $CacheRamMib = 2048,
    # NOTE: actual flag is --cache-ram (not --cache-ram-mib); parameter name kept for backward compat

    [Parameter(Mandatory=$false)]
    [int] $CtxSize = 2048,

    [Parameter(Mandatory=$false)]
    [int] $NParallel = 1,

    [Parameter(Mandatory=$false)]
    [int] $BasePort = 8830,

    [Parameter(Mandatory=$false)]
    [int] $TimeBudgetMin = 240,

    [Parameter(Mandatory=$false)]
    [int] $RequestsPerRow = 30,

    [Parameter(Mandatory=$false)]
    [string] $BaselineLogPath = 'd:\source\llama.cpp-jet\._analysis\model_log.txt',

    [Parameter(Mandatory=$false)]
    [string] $EvidenceDir = 'd:\source\llama.cpp-jet\._test_output\stage20-heavy-rerun-artifacts',

    [Parameter(Mandatory=$false)]
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$script:RunId = (Get-Date -Format 'yyyyMMdd-HHmmss')
$script:EvidencePath = Join-Path $EvidenceDir $script:RunId
New-Item -ItemType Directory -Force -Path $script:EvidencePath | Out-Null

function Write-SideLog {
    param([string]$Message)
    $logLine = "$(Get-Date -Format 'HH:mm:ss') $Message"
    Write-Host $logLine
    Add-Content -Path (Join-Path $script:EvidencePath 'side.log') -Value $logLine
}

function Get-ServerHealth {
    param([int]$Port, [int]$MaxWaitSec = 120)
    for ($i = 0; $i -lt $MaxWaitSec; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
            return $r.StatusCode
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    return 0
}

function Stop-ServerCleanly {
    param([int]$Port)
    $proc = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
        $p = Get-Process -Id $proc.OwningProcess -ErrorAction SilentlyContinue
        if ($p) {
            Write-SideLog "Stopping PID $($p.Id) on port $Port"
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function Start-HV1Row {
    param([int]$Port, [int]$TimeBudgetSec, [string]$OutDir)
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $serverOut = Join-Path $OutDir 'server.out.log'
    $serverErr = Join-Path $OutDir 'server.err.log'
    $metricsBefore = Join-Path $OutDir 'metrics-before.txt'
    $metricsAfter = Join-Path $OutDir 'metrics-after.txt'

    Remove-Item $serverOut, $serverErr -ErrorAction SilentlyContinue

    Write-SideLog "HV1: launching llama-server on port $Port with Qwen3.6-27B-MTP fixture"
    Write-SideLog "HV1: cache-cold-path=$CacheColdPath cache-cold-max-mib=$CacheColdMaxMib cache-ram-mib=$CacheRamMib"

    $serverArgs = @(
        '--port', $Port,
        '--model', 'd:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf',
        '--cache-mode', 'hybrid',
        '--cache-cold-path', $CacheColdPath,
        '--cache-cold-max-mib', $CacheColdMaxMib,
        '--cache-ram', $CacheRamMib,
        '--cache-prompt-evidence', 'redacted',
        '--cache-prompt-evidence-dir', $OutDir,
        '-c', $CtxSize,
        '-np', $NParallel,
        '--jinja',
        '--chat-template-file', 'd:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF\chat_template_new.jinja',
        '--metrics',
        '--temp', '0',
        '--seed', '42'
    )

    if ($DryRun) {
        Write-SideLog "DRYRUN: would launch llama-server with: $($serverArgs -join ' ')"
        return @{status='DRYRUN'; requests=0; cache_n_total=0; duration_sec=0}
    }

    $proc = Start-Process -FilePath 'd:\source\llama.cpp-jet\build-cov\bin\Release\llama-server.exe' `
        -ArgumentList $serverArgs `
        -RedirectStandardOutput $serverOut `
        -RedirectStandardError $serverErr `
        -PassThru -NoNewWindow

    Write-SideLog "HV1: launched PID $($proc.Id)"

    $health = Get-ServerHealth -Port $Port -MaxWaitSec 240
    if ($health -ne 200) {
        Write-SideLog "HV1: FAILED to reach /health within 240s (got $health)"
        Stop-ServerCleanly -Port $Port
        return @{status='FAIL_HEALTH'; requests=0; cache_n_total=0; duration_sec=0; health=$health}
    }
    Write-SideLog "HV1: /health HTTP 200 OK"

    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -ErrorAction Stop -TimeoutSec 10 `
            | Select-Object -ExpandProperty Content | Out-File -FilePath $metricsBefore -Encoding utf8
    } catch { Write-SideLog "HV1: metrics before failed: $($_.Exception.Message)" }

    $startTime = Get-Date
    $deadline = $startTime.AddSeconds($TimeBudgetSec)
    Write-SideLog "HV1: running up to $RequestsPerRow requests until $(($deadline).ToString('HH:mm:ss'))"

    $prompts = @(
        'Summarize the geological history of the Moon in three short paragraphs.',
        'List five famous physicists and their main contributions.',
        'Explain how a transformer language model works in plain English.',
        'Write a short Python function that computes Fibonacci numbers.',
        'Describe the lifecycle of a star like our Sun.',
        'Compare RAG-based systems with long-context LLMs.',
        'Write a haiku about the autumn season.',
        'Explain the difference between TCP and UDP.'
    )
    $cacheNTotal = 0
    $cacheNHits = 0
    $requestNum = 0

    while ((Get-Date) -lt $deadline -and $requestNum -lt $RequestsPerRow) {
        $requestNum++
        $prompt = $prompts[($requestNum - 1) % $prompts.Length]
        $payload = @{
            model = 'any'
            messages = @(@{role='user'; content=$prompt})
            max_tokens = 60
            temperature = 0
        } | ConvertTo-Json -Compress

        $reqStart = Get-Date
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/v1/chat/completions" `
                -Method POST -ContentType 'application/json' -Body $payload `
                -UseBasicParsing -ErrorAction Stop -TimeoutSec 60
            $reqEnd = Get-Date
            $resp = $r.Content | ConvertFrom-Json
            $cacheN = $resp.timings.cache_n
            $cacheNTotal += $cacheN
            if ($cacheN -gt 0) { $cacheNHits++ }
            $reqDur = ($reqEnd - $reqStart).TotalMilliseconds
            Write-SideLog "HV1: req $requestNum HTTP $($r.StatusCode) cache_n=$cacheN duration=${reqDur}ms"
            $resp | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutDir ("req-{0:D3}-response.json" -f $requestNum)) -Encoding utf8
        } catch {
            Write-SideLog "HV1: req $requestNum FAILED: $($_.Exception.Message)"
        }
        Start-Sleep -Seconds 2
    }

    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds

    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -ErrorAction Stop -TimeoutSec 10 `
            | Select-Object -ExpandProperty Content | Out-File -FilePath $metricsAfter -Encoding utf8
    } catch { Write-SideLog "HV1: metrics after failed: $($_.Exception.Message)" }

    Stop-ServerCleanly -Port $Port

    return @{
        status = 'OK'
        requests = $requestNum
        cache_n_total = $cacheNTotal
        cache_n_hits = $cacheNHits
        duration_sec = [int]$duration
        requests_per_sec = if ($duration -gt 0) { [math]::Round($requestNum / $duration, 3) } else { 0 }
    }
}

function Start-HV2Row {
    param([int]$Port, [int]$TimeBudgetSec, [string]$OutDir, [string]$BaselineLogPath)
    if (-not (Test-Path $BaselineLogPath)) {
        Write-SideLog "HV2: BLOCKED - baseline log not found at $BaselineLogPath"
        return @{status='BLOCKED_BASELINE_MISSING'; comparison='none'}
    }
    $baselineSize = (Get-Item $BaselineLogPath).Length
    Write-SideLog "HV2: baseline log size $baselineSize bytes at $BaselineLogPath"

    $hv1Dir = Join-Path (Split-Path $OutDir -Parent) 'hv1'
    $hv1Metrics = Join-Path $hv1Dir 'metrics-after.txt'
    $hv2Dir = $OutDir
    $hv2Metrics = Join-Path $hv2Dir 'metrics-after.txt'

    $comparison = @{
        baseline_size_bytes = $baselineSize
        baseline_path = $BaselineLogPath
        hv1_metrics_path = $hv1Metrics
        hv2_metrics_path = $hv2Metrics
        comparison_rows = @()
    }

    if ((Test-Path $hv1Metrics) -and (Test-Path $hv2Metrics)) {
        $hv1Lines = (Get-Content $hv1Metrics | Measure-Object -Line).Lines
        $hv2Lines = (Get-Content $hv2Metrics | Measure-Object -Line).Lines
        $comparison.comparison_rows += @{
            metric = 'metrics_after line count'
            hv1 = $hv1Lines
            hv2 = $hv2Lines
        }
        $comparison.comparison_rows += @{
            metric = 'cache_restore_misses_total rows in hv1'
            hv1 = (Select-String -Path $hv1Metrics -Pattern 'cache_restore_misses_total').Count
        }
        $comparison.comparison_rows += @{
            metric = 'cache_restore_misses_total rows in hv2'
            hv2 = (Select-String -Path $hv2Metrics -Pattern 'cache_restore_misses_total').Count
        }
        $comparison.comparison_rows += @{
            metric = 'cache_checkpoint_admissions_total rows in hv1'
            hv1 = (Select-String -Path $hv1Metrics -Pattern 'cache_checkpoint_admissions_total').Count
        }
        $comparison.comparison_rows += @{
            metric = 'cache_checkpoint_admissions_total rows in hv2'
            hv2 = (Select-String -Path $hv2Metrics -Pattern 'cache_checkpoint_admissions_total').Count
        }
    }

    $comparison | ConvertTo-Json -Depth 5 | Out-File (Join-Path $OutDir 'comparison.json') -Encoding utf8
    return @{status='OK'; comparison=$comparison}
}

Write-SideLog "Stage 20 heavy tier kickoff starting"
Write-SideLog "RunId: $script:RunId"
Write-SideLog "Evidence path: $script:EvidencePath"
Write-SideLog "Rows to run: $($RowsToRun -join ', ')"
Write-SideLog "Time budget per row: $TimeBudgetMin min"
Write-SideLog "Requests per row: $RequestsPerRow"

if ($DryRun) {
    Write-SideLog "DRYRUN: would run rows $($RowsToRun -join ', ')"
    if ('HV1' -in $RowsToRun) {
        $port = $BasePort
        $hv1Dir = Join-Path $script:EvidencePath 'hv1'
        $r = Start-HV1Row -Port $port -TimeBudgetSec 1 -OutDir $hv1Dir
    }
    if ('HV2' -in $RowsToRun) {
        $port = $BasePort + 1
        $hv2Dir = Join-Path $script:EvidencePath 'hv2'
        $r = Start-HV2Row -Port $port -TimeBudgetSec 1 -OutDir $hv2Dir -BaselineLogPath $BaselineLogPath
    }
    Write-SideLog "DRYRUN complete"
    return
}

$summary = @{ run_id = $script:RunId; rows = @{} }

if ('HV1' -in $RowsToRun) {
    $port = $BasePort
    $hv1Dir = Join-Path $script:EvidencePath 'hv1'
    $r1 = Start-HV1Row -Port $port -TimeBudgetSec ($TimeBudgetMin * 60) -OutDir $hv1Dir
    $summary.rows.HV1 = $r1
}

if ('HV2' -in $RowsToRun) {
    $port = $BasePort + 1
    $hv2Dir = Join-Path $script:EvidencePath 'hv2'
    $r2 = Start-HV2Row -Port $port -TimeBudgetSec 60 -OutDir $hv2Dir -BaselineLogPath $BaselineLogPath
    $summary.rows.HV2 = $r2
}

$summary | ConvertTo-Json -Depth 5 | Out-File (Join-Path $script:EvidencePath 'summary.json') -Encoding utf8

Write-SideLog "Heavy tier kickoff complete"
Write-SideLog "Summary written to $(Join-Path $script:EvidencePath 'summary.json')"

return $summary
