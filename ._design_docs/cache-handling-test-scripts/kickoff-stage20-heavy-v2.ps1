<#
Stage 20 heavy tier kickoff v2 - with cache-restore test workload.

Workload includes:
- Exact-repeat prompts (to trigger cache_n > 0 on second occurrence)
- Near-prefix variants (to trigger partial restore)
- New prompts (to test cache_n = 0)
- Long prompts (to test cold store behavior)

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File kickoff-stage20-heavy-v2.ps1
      -RowsToRun HV1,HV2
      -CacheColdPath 'D:\tmp\cache-cold-stage20-hv-v2'
      -TimeBudgetMin 60
      -RequestsPerRow 30
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

    [Parameter(Mandatory=$false)]
    [int] $CtxSize = 2048,

    [Parameter(Mandatory=$false)]
    [int] $NParallel = 1,

    [Parameter(Mandatory=$false)]
    [int] $BasePort = 8830,

    [Parameter(Mandatory=$false)]
    [int] $TimeBudgetMin = 60,

    [Parameter(Mandatory=$false)]
    [int] $RequestsPerRow = 30,

    [Parameter(Mandatory=$false)]
    [string] $BaselineLogPath = 'd:\source\llama.cpp-jet\._analysis\model_log.txt',

    [Parameter(Mandatory=$false)]
    [string] $EvidenceDir = 'd:\source\llama.cpp-jet\._test_output\stage20-heavy-real3',

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

    Write-SideLog "HV1: launching llama-server on port $Port with Qwen3.6-27B-MTP fixture (v2 with cache-restore test workload)"
    Write-SideLog "HV1: cache-cold-path=$CacheColdPath cache-cold-max-mib=$CacheColdMaxMib cache-ram=$CacheRamMib"

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
        return @{status='DRYRUN'; requests=0; cache_n_total=0; cache_n_hits=0; duration_sec=0}
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
        return @{status='FAIL_HEALTH'; requests=0; cache_n_total=0; cache_n_hits=0; duration_sec=0; health=$health}
    }
    Write-SideLog "HV1: /health HTTP 200 OK"

    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -ErrorAction Stop -TimeoutSec 10 `
            | Select-Object -ExpandProperty Content | Out-File -FilePath $metricsBefore -Encoding utf8
    } catch { Write-SideLog "HV1: metrics before failed: $($_.Exception.Message)" }

    # Cache-restore test workload:
    # 1. Three exact repeats (prompts A, B, C sent twice each)
    # 2. Two near-prefix variants (prompts A' and B' close to A and B)
    # 3. Two new prompts (D, E)
    # 4. Three exact repeats again (prompts A, B, C should restore from cache)
    $prompts = @(
        'What is the capital of France?',
        'What is the capital of Germany?',
        'What is the capital of Italy?',
        'What is the capital city of France?',
        'What is the capital city of Germany?',
        'What is the capital of Spain?',
        'What is the capital of Japan?',
        'What is the capital of France?',
        'What is the capital of Germany?',
        'What is the capital of Italy?'
    )
    $promptTypes = @(
        'A-original', 'B-original', 'C-original',
        'A-near-prefix', 'B-near-prefix',
        'D-new', 'E-new',
        'A-repeat', 'B-repeat', 'C-repeat'
    )

    $startTime = Get-Date
    $deadline = $startTime.AddSeconds($TimeBudgetSec)
    Write-SideLog "HV1: running up to $RequestsPerRow requests until $(($deadline).ToString('HH:mm:ss'))"
    Write-SideLog "HV1: workload = 10 prompts (3 originals, 2 near-prefix, 2 new, 3 repeats)"

    $cacheNTotal = 0
    $cacheNHits = 0
    $cacheNByType = @{}
    $requestNum = 0

    while ((Get-Date) -lt $deadline -and $requestNum -lt $RequestsPerRow) {
        $requestNum++
        $promptIdx = ($requestNum - 1) % $prompts.Length
        $prompt = $prompts[$promptIdx]
        $promptType = $promptTypes[$promptIdx]
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
                -UseBasicParsing -ErrorAction Stop -TimeoutSec 90
            $reqEnd = Get-Date
            $resp = $r.Content | ConvertFrom-Json
            $cacheN = $resp.timings.cache_n
            $promptN = $resp.timings.prompt_n
            $cacheNTotal += $cacheN
            if ($cacheN -gt 0) {
                $cacheNHits++
                if (-not $cacheNByType.ContainsKey($promptType)) { $cacheNByType[$promptType] = 0 }
                $cacheNByType[$promptType]++
            }
            $reqDur = ($reqEnd - $reqStart).TotalMilliseconds
            Write-SideLog "HV1: req $requestNum [$promptType] HTTP $($r.StatusCode) cache_n=$cacheN prompt_n=$promptN duration=${reqDur}ms"
            $resp | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutDir ("req-{0:D3}-{1}-response.json" -f $requestNum, $promptType)) -Encoding utf8
        } catch {
            Write-SideLog "HV1: req $requestNum [$promptType] FAILED: $($_.Exception.Message)"
        }
        Start-Sleep -Seconds 1
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
        cache_n_hits_by_type = $cacheNByType
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
    $hv1Side = Join-Path $hv1Dir 'side.log'

    $comparison = @{
        baseline_size_bytes = $baselineSize
        baseline_path = $BaselineLogPath
        hv1_metrics_path = $hv1Metrics
        comparison_rows = @()
    }

    if (Test-Path $hv1Metrics) {
        $hv1Misses = (Select-String -Path $hv1Metrics -Pattern 'cache_restore_misses_total' | Select-Object -First 1).Line
        $comparison.comparison_rows += @{metric='cache_restore_misses_total line'; hv1=$hv1Misses}
        $hv1Adm = (Select-String -Path $hv1Metrics -Pattern 'cache_checkpoint_admissions_total' | Select-Object -First 1).Line
        $comparison.comparison_rows += @{metric='cache_checkpoint_admissions_total line'; hv1=$hv1Adm}
    }

    if (Test-Path $hv1Side) {
        $hv1Results = Select-String -Path $hv1Side -Pattern 'cache_n=' | ForEach-Object { ($_.Line -split 'cache_n=')[1] -split ' ' | Select-Object -First 1 }
        $hv1Restores = ($hv1Results | Where-Object { $_ -gt 0 } | Measure-Object).Count
        $comparison.comparison_rows += @{metric='cache_restore_hits_count'; hv1=$hv1Restores}
        $comparison.comparison_rows += @{metric='cache_n_zero_count'; hv1=($hv1Results.Count - $hv1Restores)}
    }

    $baselineMisses = (Select-String -Path $BaselineLogPath -Pattern '"cache_n":0' -SimpleMatch | Measure-Object).Count
    $baselineEntries = (Select-String -Path $BaselineLogPath -Pattern '"cache_n":' -SimpleMatch | Measure-Object).Count
    $comparison.comparison_rows += @{metric='baseline_cache_n_zero_count'; baseline=$baselineMisses; total=$baselineEntries}

    $comparison | ConvertTo-Json -Depth 5 | Out-File (Join-Path $OutDir 'comparison.json') -Encoding utf8
    return @{status='OK'; comparison=$comparison}
}

Write-SideLog "Stage 20 heavy tier kickoff v2 starting"
Write-SideLog "RunId: $script:RunId"
Write-SideLog "Evidence path: $script:EvidencePath"
Write-SideLog "Rows to run: $($RowsToRun -join ', ')"
Write-SideLog "Time budget per row: $TimeBudgetMin min"
Write-SideLog "Requests per row: $RequestsPerRow"
Write-SideLog "Workload: 10 prompts (3 originals, 2 near-prefix, 2 new, 3 repeats)"

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

Write-SideLog "Heavy tier kickoff v2 complete"
Write-SideLog "Summary written to $(Join-Path $script:EvidencePath 'summary.json')"

return $summary
