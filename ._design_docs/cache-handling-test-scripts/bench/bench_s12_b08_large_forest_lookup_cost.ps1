#requires -Version 5
# bench_s12_b08_large_forest_lookup_cost.ps1
# Stage 12 benchmark: S12-B08 large-forest lookup cost.
# Hybrid row only; captures request latency as forest grows. Legacy
# row recorded as N/A. Tuning row 7 (bottlenecks).
# Evidence dir: ._design_docs/.test_reports/bench-s12-b08-<timestamp>/

param(
    [string] $BuildDir   = '',
    [string] $ModelPath  = '',
    [string] $OutDir     = '',
    [int]    $Port       = 8308,
    [int]    $ForestSize = 256,
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\bench-s12-b08-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$subDir = Join-Path $OutDir 'hybrid'
if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }
$basePath = Join-Path $subDir 'baseline.json'

$flags = @('--cache-mode','hybrid','--parallel','1','--cache-ram','50',
           '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
$flags = Merge-MtpJinjaFlag -Flags $flags -JinjaPath $jinjaPath

Write-Host "S12-B08 large-forest lookup cost; stub=$stubData forest=$ForestSize"

if ($DryRun) {
    Write-Host "DRY-RUN: would build forest of $ForestSize prefixes and measure lookup latency"
    exit 0
}

if ($stubData) {
    $obj = @{
        commit_sha = 'STUB'; build_type = 'STUB'
        model_fixture = (Split-Path $ModelPath -Leaf)
        slot_count = 1; ctx_size = 512; draft_mode = 'none'
        server_flags = $flags
        request_count = 0
        throughput_tps = 0; p50_latency_ms = 0; p95_latency_ms = 0; p99_latency_ms = 0
        exact_hit_rate = 0; checkpoint_hit_rate = 0
        restore_latency_by_kind = @{}
        demotion_count = 0; promotion_count = 0; eviction_count = 0
        workingset_samples = @(); handle_samples = @()
        correctness_verdict = 'BLOCKED'
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B08' -Variant 'hybrid' `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $flags -BaselinePath $basePath -LegacyBaselinePath '' `
        -TuningRow 7 -StubData -Verdict BLOCKED -Notes "Fixture missing; legacy N/A per design"
    exit 0
}

Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $serverExe `
    -ArgumentList ($flags + @('--model',$ModelPath,'--host','127.0.0.1',"--port","$Port")) `
    -RedirectStandardOutput (Join-Path $subDir 'server.out.log') `
    -RedirectStandardError  (Join-Path $subDir 'server.err.log') `
    -NoNewWindow -PassThru

$ready = $false
$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 4
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; Write-Error "Server did not start" }

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

$rng = New-Object System.Random $Seed
$prompts = 1..$ForestSize | ForEach-Object {
    $tag = -join ((1..16) | ForEach-Object { [char](65 + $rng.Next(0, 26)) })
    "Forest lookup $_ tag $tag"
}

$start = Get-Date
$end   = $start.AddSeconds($DurationSec)
$rowCount = 0
$latencyMs = @()
while ((Get-Date) -lt $end) {
    foreach ($p in $prompts) {
        $body = (@{ prompt = $p; n_predict = 3; temperature = 0; seed = $Seed; cache_prompt = $true } |
            ConvertTo-Json -Compress)
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
                -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30
            $rowCount++
            $j = $r.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($j.timings.prompt_ms) { $latencyMs += [double]$j.timings.prompt_ms }
        } catch {}
    }
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

function Get-Percentile {
    param([double[]] $Values, [double] $Pct)
    if ($Values.Count -eq 0) { return 0 }
    $sorted = $Values | Sort-Object
    $idx = [int][Math]::Floor(($Pct / 100.0) * $sorted.Count)
    if ($idx -ge $sorted.Count) { $idx = $sorted.Count - 1 }
    return $sorted[$idx]
}

$obj = @{
    commit_sha = 'PENDING'; build_type = 'Release'
    binary_timestamp = (Get-Item $serverExe).LastWriteTime.ToString('o')
    model_fixture = (Split-Path $ModelPath -Leaf)
    slot_count = 1; ctx_size = 512; draft_mode = 'none'
    server_flags = $flags
    prompt_seed = $Seed
    request_count = $rowCount
    throughput_tps = 'PENDING'
    p50_latency_ms = (Get-Percentile -Values $latencyMs -Pct 50)
    p95_latency_ms = (Get-Percentile -Values $latencyMs -Pct 95)
    p99_latency_ms = (Get-Percentile -Values $latencyMs -Pct 99)
    exact_hit_rate = 'PENDING'; checkpoint_hit_rate = 0
    restore_latency_by_kind = @{}
    demotion_count = 'PENDING'; promotion_count = 'PENDING'; eviction_count = 'PENDING'
    workingset_samples = @(); handle_samples = @()
    correctness_verdict = 'PENDING'
}
$obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B08' -Variant 'hybrid' `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $flags -BaselinePath $basePath -LegacyBaselinePath '' `
    -TuningRow 7 -Verdict PENDING -Notes "Live run; QA evaluates lookup latency as forest grows"
