#requires -Version 5
# bench_s12_b01_exact_blob_hit_rate.ps1
# Stage 12 benchmark: S12-B01 exact-blob hit rate.
# Hybrid row mandatory; legacy row mandatory for ratio. Uses k6 path
# modelled on run_benchmark_k6.ps1. Stub data when k6 or fixture
# unavailable. Tuning report row 1 (hot budget guidance).
# Evidence dir: ._design_docs/.test_reports/bench-s12-b01-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $K6Path         = 'D:\app\k6\k6.exe',
    [string] $OutDir         = '',
    [int]    $Port           = 8301,
    [int]    $Iterations     = 12,
    [int]    $WarmupIters    = 2,
    [int]    $MeasurementSec = 60,
    [int]    $Seed           = 42,
    [int]    $MtpVariant     = 0,
    [ValidateSet('original','marked')] [string] $JinjaVariant = 'original',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir  = $PSScriptRoot
$sourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$libDir     = Join-Path $sourceRoot '._design_docs\cache-handling-test-scripts\lib'

. (Join-Path $libDir 'Write-BenchEvidence.ps1')
. (Join-Path $libDir 'Read-BaselineJson.ps1')
. (Join-Path $libDir 'Read-GgufChatTemplate.ps1')

# MTP + jinja variant params (post-closure follow-up, part-19 sec 7.1).
$jinjaPath = Resolve-MtpJinjaPath -MtpVariant $MtpVariant -JinjaVariant $JinjaVariant -ModelPath $ModelPath -SourceRoot $sourceRoot
if ($MtpVariant -gt 0 -and $MtpVariant -ne 2 -and $jinjaPath -and -not (Test-Path $jinjaPath)) {
    Write-Host "BLOCKED: jinja file missing at $jinjaPath (MtpVariant=$MtpVariant JinjaVariant=$JinjaVariant)"
}

if (-not $BuildDir)  { $BuildDir  = Join-Path $sourceRoot 'build' }
if (-not $ModelPath) {
    $ModelPath = if ($env:LLAMA_CACHE_TEST_MODEL) { $env:LLAMA_CACHE_TEST_MODEL }
                 else { Join-Path $sourceRoot '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf' }
}
if (-not $OutDir) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\bench-s12-b01-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'
$k6Script  = Join-Path $sourceRoot 'tools\server\tests\bench-cache-correctness.js'

$stubFixture = -not (Test-Path $ModelPath)
$stubK6      = -not (Test-Path $K6Path)
$stubData    = $stubFixture -or $stubK6

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$hybridFlags = @('--cache-mode','hybrid','--parallel','1','--cache-ram','100',
                 '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
$legacyFlags = @('--cache-mode','legacy','--parallel','1','--cache-ram','100',
                 '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
$hybridFlags = Merge-MtpJinjaFlag -Flags $hybridFlags -JinjaPath $jinjaPath
$legacyFlags = Merge-MtpJinjaFlag -Flags $legacyFlags -JinjaPath $jinjaPath

Write-Host "S12-B01 exact-blob hit rate; stub=$stubData"

function New-StubBaseline {
    param([string] $Path, [string[]] $Flags, [string] $Mode)
    $obj = @{
        commit_sha         = 'STUB'
        dirty_worktree     = 'STUB'
        build_type         = 'STUB'
        binary_timestamp   = 'STUB'
        host_hardware      = 'STUB'
        model_fixture      = (Split-Path $ModelPath -Leaf)
        slot_count         = 1
        ctx_size           = 512
        draft_mode         = 'none'
        server_flags       = $Flags
        prompt_seed        = $Seed
        warmup_window      = 'STUB'
        measurement_window = 'STUB'
        request_count      = 0
        throughput_tps     = 0
        p50_latency_ms     = 0
        p95_latency_ms     = 0
        p99_latency_ms     = 0
        exact_hit_rate     = 0
        checkpoint_hit_rate= 0
        restore_latency_by_kind = @{}
        demotion_count     = 0
        promotion_count    = 0
        eviction_count     = 0
        workingset_samples = @()
        handle_samples     = @()
        correctness_verdict = if ($stubFixture) { 'BLOCKED' } else { 'PENDING' }
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $Path -Encoding utf8
    return $Path
}

function Write-BenchRow {
    param([string] $Mode, [string[]] $Flags, [string] $SubName)
    $subDir = Join-Path $OutDir $SubName
    if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }
    $basePath = Join-Path $subDir 'baseline.json'
    $legacyPath = Join-Path $subDir 'legacy-baseline.json'

    if ($stubData) {
        New-StubBaseline -Path $basePath -Flags $Flags -Mode $Mode
        if ($SubName -eq 'hybrid') { New-StubBaseline -Path $legacyPath -Flags $legacyFlags -Mode 'legacy' }
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B01' -Variant $SubName `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $Flags -BaselinePath $basePath -LegacyBaselinePath $legacyPath `
            -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
            -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
            -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
            -TuningRow 1 -StubData -Verdict BLOCKED -Notes "Fixture or k6 missing"
        return
    }

    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $portUse = if ($SubName -eq 'hybrid') { $Port } else { $Port + 1 }
    $proc = Start-Process -FilePath $serverExe `
        -ArgumentList ($Flags + @('--model',$ModelPath,'--host','127.0.0.1',"--port","$portUse")) `
        -RedirectStandardOutput (Join-Path $subDir 'server.out.log') `
        -RedirectStandardError  (Join-Path $subDir 'server.err.log') `
        -NoNewWindow -PassThru

    $ready = $false
    $deadline = (Get-Date).AddSeconds(180)
    while ((Get-Date) -lt $deadline) {
        try {
            $h = Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/health" -UseBasicParsing -TimeoutSec 4
            if ($h.StatusCode -eq 200) { $ready = $true; break }
        } catch {}
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        New-StubBaseline -Path $basePath -Flags $Flags -Mode $Mode
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B01' -Variant $SubName `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $Flags -BaselinePath $basePath `
            -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
            -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
            -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
            -TuningRow 1 -StubData -Verdict BLOCKED -Notes "Server did not start"
        return
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

    $env:BENCH_URL       = "http://127.0.0.1:$portUse"
    $env:BENCH_ITERS     = "$Iterations"
    $env:BENCH_N_PREDICT = '8'
    $k6Args = @('run','--out',"json=$($subDir)\k6-results.json",
                '--summary-trend-stats','avg,min,med,p(95),max', $k6Script)
    $k6Proc = Start-Process -FilePath $K6Path -ArgumentList $k6Args `
        -NoNewWindow -PassThru -Wait `
        -RedirectStandardOutput (Join-Path $subDir 'k6-stdout.txt') `
        -RedirectStandardError  (Join-Path $subDir 'k6-stderr.txt')

    (Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8

    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

    $obj = @{
        commit_sha         = 'PENDING'
        dirty_worktree     = 'PENDING'
        build_type         = 'Release'
        binary_timestamp   = (Get-Item $serverExe).LastWriteTime.ToString('o')
        host_hardware      = 'PENDING'
        model_fixture      = (Split-Path $ModelPath -Leaf)
        slot_count         = 1
        ctx_size           = 512
        draft_mode         = 'none'
        server_flags       = $Flags
        prompt_seed        = $Seed
        warmup_window      = "warmup_iters=$WarmupIters"
        measurement_window = "iters=$Iterations"
        request_count      = $Iterations
        throughput_tps     = 'PENDING'
        p50_latency_ms     = 'PENDING'
        p95_latency_ms     = 'PENDING'
        p99_latency_ms     = 'PENDING'
        exact_hit_rate     = 'PENDING'
        checkpoint_hit_rate= 0
        restore_latency_by_kind = @{}
        demotion_count     = 'PENDING'
        promotion_count    = 'PENDING'
        eviction_count     = 'PENDING'
        workingset_samples = @()
        handle_samples     = @()
        correctness_verdict = if ($k6Proc.ExitCode -eq 0) { 'PENDING' } else { 'FAIL' }
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
    if ($SubName -eq 'hybrid') { New-StubBaseline -Path $legacyPath -Flags $legacyFlags -Mode 'legacy' }
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B01' -Variant $SubName `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $Flags -BaselinePath $basePath -LegacyBaselinePath $legacyPath `
        -K6ResultsPath (Join-Path $subDir 'k6-results.json') `
        -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
        -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
        -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
        -TuningRow 1 -Verdict PENDING -Notes "Live run; QA evaluates k6 exit"
}

if ($DryRun) {
    Write-Host "DRY-RUN: would run k6 hybrid then legacy rows for $Iterations iters"
    exit 0
}

Write-BenchRow -Mode 'hybrid' -Flags $hybridFlags -SubName 'hybrid'
Write-BenchRow -Mode 'legacy' -Flags $legacyFlags -SubName 'legacy'

$hybridBase = Read-BaselineJson -Path (Join-Path (Join-Path $OutDir 'hybrid') 'baseline.json')
$legacyBase = Read-BaselineJson -Path (Join-Path (Join-Path $OutDir 'legacy') 'legacy-baseline.json')
Write-Host "hybrid baseline read: $($null -ne $hybridBase); legacy baseline read: $($null -ne $legacyBase)"
