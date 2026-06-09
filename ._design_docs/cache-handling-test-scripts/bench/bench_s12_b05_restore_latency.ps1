#requires -Version 5
# bench_s12_b05_restore_latency.ps1
# Stage 12 benchmark: S12-B05 restore latency.
# Hybrid only; captures p50, p95, p99 by payload kind and residency.
# Legacy row recorded as N/A (no hybrid restore path). Tuning rows 1
# (hot budget) and 2 (cold store).
# Evidence dir: ._design_docs/.test_reports/bench-s12-b05-<timestamp>/

param(
    [string] $BuildDir   = '',
    [string] $ModelPath  = '',
    [string] $OutDir     = '',
    [int]    $Port       = 8305,
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\bench-s12-b05-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)
$tempRoot = Join-Path $env:TEMP "s12-b05-cold-$([guid]::NewGuid().Guid.Substring(0,8))"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$subDir = Join-Path $OutDir 'hybrid'
if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }
$basePath = Join-Path $subDir 'baseline.json'

$flags = @('--cache-mode','hybrid','--parallel','1','--cache-ram','50',
           '--cache-cold-path',$tempRoot,'--metrics','--ctx-size','512',
           '--temp','0','--seed',"$Seed")
$flags = Merge-MtpJinjaFlag -Flags $flags -JinjaPath $jinjaPath

Write-Host "S12-B05 restore latency; stub=$stubData"

if ($DryRun) {
    Write-Host "DRY-RUN: would run hybrid-only with cold-path and capture restore p50/p95/p99"
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
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B05' -Variant 'hybrid' `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $flags -BaselinePath $basePath -LegacyBaselinePath '' `
        -TuningRow 1 -StubData -Verdict BLOCKED -Notes "Fixture missing; legacy N/A per design"
    exit 0
}

if (-not (Test-Path $tempRoot)) { New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null }
$probe = Join-Path $tempRoot 'probe.tmp'
"probe" | Out-File -FilePath $probe -Encoding utf8
if (-not (Test-Path $probe)) { Write-Error "Cold path not writable at $tempRoot" }
Remove-Item $probe -Force

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
if (-not $ready) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    Write-Error "Server did not start"
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

$start = Get-Date
$end   = $start.AddSeconds($DurationSec)
$rowCount = 0
$restoreMs = @()
while ((Get-Date) -lt $end) {
    $body = '{"prompt":"S12-B05 restore latency probe with long shared prefix","n_predict":4,"temperature":0,"seed":42,"cache_prompt":true}'
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
            -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 60
        $rowCount++
        $j = $r.Content | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($j.timings.cache_n -gt 0 -and $j.timings.prompt_ms) {
            $restoreMs += [double]$j.timings.prompt_ms
        }
    } catch {}
    Start-Sleep -Milliseconds 200
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
    p50_latency_ms = (Get-Percentile -Values $restoreMs -Pct 50)
    p95_latency_ms = (Get-Percentile -Values $restoreMs -Pct 95)
    p99_latency_ms = (Get-Percentile -Values $restoreMs -Pct 99)
    exact_hit_rate = 'PENDING'; checkpoint_hit_rate = 0
    restore_latency_by_kind = @{
        hot_prompt_p50 = (Get-Percentile -Values $restoreMs -Pct 50)
        hot_prompt_p95 = (Get-Percentile -Values $restoreMs -Pct 95)
        hot_prompt_p99 = (Get-Percentile -Values $restoreMs -Pct 99)
    }
    demotion_count = 'PENDING'; promotion_count = 'PENDING'; eviction_count = 'PENDING'
    workingset_samples = @(); handle_samples = @()
    correctness_verdict = 'PENDING'
}
$obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B05' -Variant 'hybrid' `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $flags -BaselinePath $basePath -LegacyBaselinePath '' `
    -TuningRow 1 -Verdict PENDING -Notes "Live run; QA classifies payload kind and residency"
