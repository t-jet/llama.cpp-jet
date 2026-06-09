#requires -Version 5
# bench_s12_b02_checkpoint_hit_rate.ps1
# Stage 12 benchmark: S12-B02 checkpoint hit rate.
# Qwen3-8B plus draft Qwen3-0.6B if both fixtures load. BLOCKED if
# checkpoint fixture missing. Tuning report row 6 (workload profile).
# Evidence dir: ._design_docs/.test_reports/bench-s12-b02-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $LargerModel    = '',
    [string] $DraftModel     = '',
    [string] $OutDir         = '',
    [int]    $Port           = 8302,
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
. (Join-Path $libDir 'Read-GgufChatTemplate.ps1')

if (-not $BuildDir) { $BuildDir = Join-Path $sourceRoot 'build' }

# part-21a sec 4: per-driver variant logic is not permitted. Drivers must
# accept -MtpVariant and switch fixtures accordingly. MtpVariant 0/2 keep
# the original Qwen3-8B + Qwen3-0.6B + --model-draft path; MtpVariant 1/3
# use the MTP model and --spec-type draft-mtp without --model-draft.
$isMtpModel = $MtpVariant -eq 1 -or $MtpVariant -eq 3
if (-not $LargerModel) {
    if ($MtpVariant -eq 1) {
        $LargerModel = Join-Path $sourceRoot '._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf'
    } elseif ($MtpVariant -eq 3) {
        $LargerModel = Join-Path $sourceRoot '._test_models\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf'
    } else {
        $LargerModel = Join-Path $sourceRoot '._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf'
    }
}
if (-not $DraftModel -and -not $isMtpModel) {
    $DraftModel = Join-Path $sourceRoot '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
}

# Resolve after fixture defaults are known. V2 must use the target
# Qwen3-8B template, not the draft-model directory fallback.
$jinjaPath = Resolve-MtpJinjaPath -MtpVariant $MtpVariant -JinjaVariant $JinjaVariant -ModelPath $LargerModel -SourceRoot $sourceRoot
if ($MtpVariant -gt 0 -and $MtpVariant -ne 2 -and $jinjaPath -and -not (Test-Path $jinjaPath)) {
    Write-Host "BLOCKED: jinja file missing at $jinjaPath (MtpVariant=$MtpVariant JinjaVariant=$JinjaVariant)"
}

if (-not $OutDir) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\bench-s12-b02-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubFixture = -not (Test-Path $LargerModel)
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
$subDir = Join-Path $OutDir 'hybrid'
if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }

$flags = @('--cache-mode','hybrid','--parallel','1','--cache-ram','200',
           '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
# MtpVariant 1/3: built-in MTP path via --spec-type draft-mtp; no draft
# model is loaded because the MTP weights are inside the larger model.
# MtpVariant 0/2: separate draft model via --model-draft.
if ($isMtpModel) {
    $flags += @('--spec-type','draft-mtp')
} elseif (Test-Path $DraftModel) {
    $flags += @('--model-draft',$DraftModel,'--spec-type','draft-simple')
}
$flags = Merge-MtpJinjaFlag -Flags $flags -JinjaPath $jinjaPath

Write-Host "S12-B02 checkpoint hit rate; stub=$stubFixture"

if ($DryRun) {
    if ($isMtpModel) {
        Write-Host "DRY-RUN: would probe $LargerModel with --spec-type draft-mtp for checkpoint hits"
    } else {
        Write-Host "DRY-RUN: would probe $LargerModel + draft $DraftModel for checkpoint hits"
    }
    exit 0
}

if ($stubFixture) {
    $basePath = Join-Path $subDir 'baseline.json'
    $stubFixtureName = Split-Path $LargerModel -Leaf
    $obj = @{
        commit_sha = 'STUB'; build_type = 'STUB'; model_fixture = $stubFixtureName
        slot_count = 1; ctx_size = 512; draft_mode = 'none'
        server_flags = $flags; request_count = 0
        correctness_verdict = 'BLOCKED'
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B02' -Variant 'hybrid' `
        -ModelFixture $stubFixtureName -BuildType 'Release' `
        -ServerFlags $flags -BaselinePath $basePath -TuningRow 6 `
        -StubData -Verdict BLOCKED -Notes "Checkpoint-capable fixture not present: $stubFixtureName"
    exit 0
}

Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $serverExe `
    -ArgumentList ($flags + @('--model',$LargerModel,'--host','127.0.0.1',"--port","$Port")) `
    -RedirectStandardOutput (Join-Path $subDir 'server.out.log') `
    -RedirectStandardError  (Join-Path $subDir 'server.err.log') `
    -NoNewWindow -PassThru

$ready = $false
$deadline = (Get-Date).AddSeconds(240)
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 4
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    $basePath = Join-Path $subDir 'baseline.json'
    $fixtureName = Split-Path $LargerModel -Leaf
    $draftName = if ($isMtpModel) { 'none' } elseif (Test-Path $DraftModel) { 'qwen3-0.6b' } else { 'none' }
    $obj = @{
        commit_sha = 'PENDING'; build_type = 'Release'
        model_fixture = $fixtureName
        slot_count = 1; ctx_size = 512; draft_mode = $draftName
        server_flags = $flags; request_count = 0
        correctness_verdict = 'BLOCKED'
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B02' -Variant 'hybrid' `
        -ModelFixture $fixtureName -BuildType 'Release' `
        -ServerFlags $flags -BaselinePath $basePath -TuningRow 6 `
        -StubData -Verdict BLOCKED -Notes "Server did not start with $fixtureName (MtpVariant=$MtpVariant)"
    exit 0
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

$start = Get-Date
$end   = $start.AddMinutes(1)
$rowCount = 0
while ((Get-Date) -lt $end) {
    $request = @{
        messages = @(
            @{ role = 'system'; content = 'S12-B02 checkpoint probe shared system prefix.' },
            @{ role = 'user'; content = 'Return four short checkpoint probe words.' }
        )
        max_tokens = 4
        temperature = 0
        seed = $Seed
        cache_prompt = $true
    }
    if ($JinjaVariant -eq 'marked') {
        $request.chat_template_kwargs = @{ emit_cache_boundaries = $true }
    }
    $body = $request | ConvertTo-Json -Depth 6
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/v1/chat/completions" -Method POST `
            -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 60 | Out-Null
        $rowCount++
    } catch {}
    Start-Sleep -Milliseconds 250
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

$basePath = Join-Path $subDir 'baseline.json'
$fixtureName = Split-Path $LargerModel -Leaf
$draftName = if ($isMtpModel) { 'draft-mtp' } elseif (Test-Path $DraftModel) { 'qwen3-0.6b' } else { 'none' }
$obj = @{
    commit_sha = 'PENDING'; build_type = 'Release'
    binary_timestamp = (Get-Item $serverExe).LastWriteTime.ToString('o')
    model_fixture = $fixtureName
    slot_count = 1; ctx_size = 512
    draft_mode = $draftName
    server_flags = $flags
    prompt_seed = $Seed
    request_count = $rowCount
    throughput_tps = 'PENDING'
    p50_latency_ms = 'PENDING'
    p95_latency_ms = 'PENDING'
    p99_latency_ms = 'PENDING'
    exact_hit_rate = 'PENDING'
    checkpoint_hit_rate = 'PENDING'
    restore_latency_by_kind = @{}
    demotion_count = 'PENDING'
    promotion_count = 'PENDING'
    eviction_count = 'PENDING'
    workingset_samples = @()
    handle_samples = @()
    correctness_verdict = 'PENDING'
}
$obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B02' -Variant 'hybrid' `
    -ModelFixture $fixtureName -BuildType 'Release' `
    -ServerFlags $flags -BaselinePath $basePath -TuningRow 6 `
    -Verdict PENDING -Notes "Live run; QA evaluates checkpoint counters (MtpVariant=$MtpVariant)"
