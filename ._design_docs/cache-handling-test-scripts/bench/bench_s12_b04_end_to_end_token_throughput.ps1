#requires -Version 5
# bench_s12_b04_end_to_end_token_throughput.ps1
# Stage 12 benchmark: S12-B04 end-to-end token throughput.
# Hybrid and legacy rows at matched slot, ctx, prompt mix. Gain form
# is throughput or latency. Tuning report rows 3 (slot count) and 4
# (context length).
# Evidence dir: ._design_docs/.test_reports/bench-s12-b04-<timestamp>/

param(
    [string] $BuildDir   = '',
    [string] $ModelPath  = '',
    [string] $OutDir     = '',
    [int]    $Port       = 8304,
    [int]    $SlotCount  = 1,
    [int]    $CtxSize    = 512,
    [int]    $DurationSec = 300,
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\bench-s12-b04-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$hybridFlags = @('--cache-mode','hybrid','--parallel',"$SlotCount",
                 '--cache-ram','100','--metrics','--ctx-size',"$CtxSize",
                 '--temp','0','--seed',"$Seed")
$legacyFlags = @('--cache-mode','legacy','--parallel',"$SlotCount",
                 '--cache-ram','100','--metrics','--ctx-size',"$CtxSize",
                 '--temp','0','--seed',"$Seed")
$hybridFlags = Merge-MtpJinjaFlag -Flags $hybridFlags -JinjaPath $jinjaPath
$legacyFlags = Merge-MtpJinjaFlag -Flags $legacyFlags -JinjaPath $jinjaPath

Write-Host "S12-B04 end-to-end token throughput; stub=$stubData slot=$SlotCount ctx=$CtxSize"

function New-StubBaseline {
    param([string] $Path, [string[]] $Flags)
    $obj = @{
        commit_sha = 'STUB'; build_type = 'STUB'
        model_fixture = (Split-Path $ModelPath -Leaf)
        slot_count = $SlotCount; ctx_size = $CtxSize; draft_mode = 'none'
        server_flags = $Flags
        request_count = 0
        throughput_tps = 0; p50_latency_ms = 0; p95_latency_ms = 0; p99_latency_ms = 0
        correctness_verdict = 'BLOCKED'
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $Path -Encoding utf8
}

function Run-ThroughputRow {
    param([string] $Mode, [string[]] $Flags, [string] $SubName)
    $subDir = Join-Path $OutDir $SubName
    if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }
    $basePath = Join-Path $subDir 'baseline.json'

    if ($stubData) {
        New-StubBaseline -Path $basePath -Flags $Flags
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B04' -Variant $SubName `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $Flags -BaselinePath $basePath -TuningRow 3 `
            -StubData -Verdict BLOCKED -Notes "Fixture missing"
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
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B04' -Variant $SubName `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $Flags -BaselinePath $basePath -TuningRow 3 `
            -StubData -Verdict BLOCKED -Notes "Server did not start"
        return
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

    $start = Get-Date
    $end   = $start.AddSeconds($DurationSec)
    $rowCount = 0
    while ((Get-Date) -lt $end) {
        $body = '{"prompt":"S12-B04 throughput probe","n_predict":32,"temperature":0,"seed":42,"cache_prompt":true}'
        try {
            Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/completion" -Method POST `
                -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 60 | Out-Null
            $rowCount++
        } catch {}
        Start-Sleep -Milliseconds 200
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

    $obj = @{
        commit_sha = 'PENDING'; build_type = 'Release'
        binary_timestamp = (Get-Item $serverExe).LastWriteTime.ToString('o')
        model_fixture = (Split-Path $ModelPath -Leaf)
        slot_count = $SlotCount; ctx_size = $CtxSize; draft_mode = 'none'
        server_flags = $Flags
        prompt_seed = $Seed
        request_count = $rowCount
        throughput_tps = 'PENDING'
        p50_latency_ms = 'PENDING'; p95_latency_ms = 'PENDING'; p99_latency_ms = 'PENDING'
        exact_hit_rate = 'PENDING'; checkpoint_hit_rate = 0
        restore_latency_by_kind = @{}
        demotion_count = 'PENDING'; promotion_count = 'PENDING'; eviction_count = 'PENDING'
        workingset_samples = @(); handle_samples = @()
        correctness_verdict = 'PENDING'
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B04' -Variant $SubName `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $Flags -BaselinePath $basePath -TuningRow 3 `
        -Verdict PENDING -Notes "Live run; QA evaluates throughput and latency"
}

if ($DryRun) {
    Write-Host "DRY-RUN: would run hybrid and legacy at slot=$SlotCount ctx=$CtxSize for $DurationSec seconds"
    exit 0
}

Run-ThroughputRow -Mode 'hybrid' -Flags $hybridFlags -SubName 'hybrid'
Run-ThroughputRow -Mode 'legacy' -Flags $legacyFlags -SubName 'legacy'
