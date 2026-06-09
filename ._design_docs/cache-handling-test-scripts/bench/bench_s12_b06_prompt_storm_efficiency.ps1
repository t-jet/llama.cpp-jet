#requires -Version 5
# bench_s12_b06_prompt_storm_efficiency.ps1
# Stage 12 benchmark: S12-B06 prompt-storm efficiency.
# Hybrid and legacy rows under high repeat pressure. Uses k6 path.
# Tuning rows 1 (hot budget) and 2 (cold store).
# Evidence dir: ._design_docs/.test_reports/bench-s12-b06-<timestamp>/

param(
    [string] $BuildDir   = '',
    [string] $ModelPath  = '',
    [string] $K6Path     = 'D:\app\k6\k6.exe',
    [string] $OutDir     = '',
    [int]    $Port       = 8306,
    [int]    $Iterations = 24,
    [int]    $Seed       = 42,    [int]    $MtpVariant     = 0,
    [ValidateSet('original','marked')] [string] $JinjaVariant = 'original',    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir  = $PSScriptRoot
$sourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$libDir     = Join-Path $sourceRoot '._design_docs\cache-handling-test-scripts\lib'

. (Join-Path $libDir 'Write-BenchEvidence.ps1')
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\bench-s12-b06-$ts"
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

Write-Host "S12-B06 prompt-storm efficiency; stub=$stubData"

function New-StubBaseline {
    param([string] $Path, [string[]] $Flags)
    $obj = @{
        commit_sha = 'STUB'; build_type = 'STUB'
        model_fixture = (Split-Path $ModelPath -Leaf)
        slot_count = 1; ctx_size = 512; draft_mode = 'none'
        server_flags = $Flags
        request_count = 0
        throughput_tps = 0; p50_latency_ms = 0; p95_latency_ms = 0; p99_latency_ms = 0
        exact_hit_rate = 0; checkpoint_hit_rate = 0
        restore_latency_by_kind = @{}
        demotion_count = 0; promotion_count = 0; eviction_count = 0
        workingset_samples = @(); handle_samples = @()
        correctness_verdict = 'BLOCKED'
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $Path -Encoding utf8
}

function Run-StormRow {
    param([string] $Mode, [string[]] $Flags, [string] $SubName)
    $subDir = Join-Path $OutDir $SubName
    if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }
    $basePath = Join-Path $subDir 'baseline.json'

    if ($stubData) {
        New-StubBaseline -Path $basePath -Flags $Flags
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B06' -Variant $SubName `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $Flags -BaselinePath $basePath -TuningRow 1 `
            -StubData -Verdict BLOCKED -Notes "Fixture or k6 missing"
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
        New-StubBaseline -Path $basePath -Flags $Flags
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B06' -Variant $SubName `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $Flags -BaselinePath $basePath -TuningRow 1 `
            -StubData -Verdict BLOCKED -Notes "Server did not start"
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
        commit_sha = 'PENDING'; build_type = 'Release'
        binary_timestamp = (Get-Item $serverExe).LastWriteTime.ToString('o')
        model_fixture = (Split-Path $ModelPath -Leaf)
        slot_count = 1; ctx_size = 512; draft_mode = 'none'
        server_flags = $Flags
        prompt_seed = $Seed
        request_count = $Iterations
        throughput_tps = 'PENDING'
        p50_latency_ms = 'PENDING'; p95_latency_ms = 'PENDING'; p99_latency_ms = 'PENDING'
        exact_hit_rate = 'PENDING'; checkpoint_hit_rate = 0
        restore_latency_by_kind = @{}
        demotion_count = 'PENDING'; promotion_count = 'PENDING'; eviction_count = 'PENDING'
        workingset_samples = @(); handle_samples = @()
        correctness_verdict = if ($k6Proc.ExitCode -eq 0) { 'PENDING' } else { 'FAIL' }
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B06' -Variant $SubName `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $Flags -BaselinePath $basePath -TuningRow 1 `
        -K6ResultsPath (Join-Path $subDir 'k6-results.json') `
        -Verdict PENDING -Notes "Live run; QA evaluates storm counters"
}

if ($DryRun) {
    Write-Host "DRY-RUN: would run k6 hybrid then legacy rows for $Iterations iters"
    exit 0
}

Run-StormRow -Mode 'hybrid' -Flags $hybridFlags -SubName 'hybrid'
Run-StormRow -Mode 'legacy' -Flags $legacyFlags -SubName 'legacy'
