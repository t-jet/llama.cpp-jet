#requires -Version 5
# bench_s12_b07_mixed_profile_comparison.ps1
# Stage 12 benchmark: S12-B07 mixed-profile comparison.
# Plain-transformer Qwen3-0.6B; checkpoint-dependent fixture if present;
# target-plus-draft Qwen3-8B + Qwen3-0.6B if both fixtures load.
# Profile-by-profile legacy row where fixture supports the profile.
# Tuning row 6 (workload profile).
# Evidence dir: ._design_docs/.test_reports/bench-s12-b07-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $DraftModelPath = '',
    [string] $OutDir         = '',
    [int]    $DurationSec    = 180,
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
if (-not $DraftModelPath) {
    $DraftModelPath = Join-Path $sourceRoot '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
}
$largerModel = Join-Path $sourceRoot '._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf'

if (-not $OutDir) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\bench-s12-b07-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$profiles = @(
    @{ name='plain-transformer'; model=$ModelPath; draft=$null }
    @{ name='target-plus-draft'; model=$largerModel; draft=$DraftModelPath }
    @{ name='checkpoint-dependent'; model=$largerModel; draft=$null }
)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

Write-Host "S12-B07 mixed-profile comparison"

if ($DryRun) {
    foreach ($p in $profiles) { Write-Host "DRY-RUN: would run profile $($p.name) for $DurationSec sec" }
    exit 0
}

foreach ($p in $profiles) {
    $subDir = Join-Path $OutDir $p.name
    if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }
    $basePath = Join-Path $subDir 'baseline.json'
    $legacyPath = Join-Path $subDir 'legacy-baseline.json'
    $stub = -not (Test-Path $p.model)
    if ($p.draft) { $stub = $stub -or (-not (Test-Path $p.draft)) }

    $flags = @('--cache-mode','hybrid','--parallel','1','--cache-ram','100',
               '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
    if ($p.draft) { $flags += @('--model-draft',$p.draft,'--spec-type','draft-simple') }
    $flags = Merge-MtpJinjaFlag -Flags $flags -JinjaPath $jinjaPath
    $legacyFlags = $flags | Where-Object { $_ -ne 'hybrid' -and $_ -ne '100' -and $_ -ne $p.draft }
    $legacyFlags = $legacyFlags | Where-Object { $_ -ne '--cache-ram' -and $_ -ne '100' }
    $legacyFlags = $legacyFlags + @('--cache-ram','100')

    if ($stub) {
        $obj = @{
            commit_sha = 'STUB'; build_type = 'STUB'
            model_fixture = (Split-Path $p.model -Leaf)
            slot_count = 1; ctx_size = 512; draft_mode = 'none'
            server_flags = $flags
            request_count = 0
            correctness_verdict = 'BLOCKED'
        }
        $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B07' -Variant $p.name `
            -ModelFixture (Split-Path $p.model -Leaf) -BuildType 'Release' `
            -ServerFlags $flags -BaselinePath $basePath -TuningRow 6 `
            -StubData -Verdict BLOCKED -Notes "Profile fixture missing"
        continue
    }

    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    $port = 8370 + ([int]([System.Text.Encoding]::UTF8.GetBytes($p.name)[0]))
    $proc = Start-Process -FilePath $serverExe `
        -ArgumentList ($flags + @('--model',$p.model,'--host','127.0.0.1',"--port","$port")) `
        -RedirectStandardOutput (Join-Path $subDir 'server.out.log') `
        -RedirectStandardError  (Join-Path $subDir 'server.err.log') `
        -NoNewWindow -PassThru

    $ready = $false
    $deadline = (Get-Date).AddSeconds(240)
    while ((Get-Date) -lt $deadline) {
        try {
            $h = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 4
            if ($h.StatusCode -eq 200) { $ready = $true; break }
        } catch {}
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        $obj = @{
            commit_sha = 'PENDING'; build_type = 'Release'
            model_fixture = (Split-Path $p.model -Leaf)
            slot_count = 1; ctx_size = 512
            draft_mode = if ($p.draft) { 'qwen3-0.6b' } else { 'none' }
            server_flags = $flags
            request_count = 0
            correctness_verdict = 'BLOCKED'
        }
        $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
        Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B07' -Variant $p.name `
            -ModelFixture (Split-Path $p.model -Leaf) -BuildType 'Release' `
            -ServerFlags $flags -BaselinePath $basePath -TuningRow 6 `
            -StubData -Verdict BLOCKED -Notes "Server did not start for profile $($p.name)"
        continue
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

    $start = Get-Date
    $end   = $start.AddSeconds($DurationSec)
    $rowCount = 0
    while ((Get-Date) -lt $end) {
        $body = '{"prompt":"S12-B07 mixed profile","n_predict":3,"temperature":0,"seed":42,"cache_prompt":true}'
        try {
            Invoke-WebRequest -Uri "http://127.0.0.1:$port/completion" -Method POST `
                -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
            $rowCount++
        } catch {}
        Start-Sleep -Milliseconds 200
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

    $obj = @{
        commit_sha = 'PENDING'; build_type = 'Release'
        binary_timestamp = (Get-Item $serverExe).LastWriteTime.ToString('o')
        model_fixture = (Split-Path $p.model -Leaf)
        slot_count = 1; ctx_size = 512
        draft_mode = if ($p.draft) { 'qwen3-0.6b' } else { 'none' }
        server_flags = $flags
        prompt_seed = $Seed
        request_count = $rowCount
        throughput_tps = 'PENDING'
        p50_latency_ms = 'PENDING'; p95_latency_ms = 'PENDING'; p99_latency_ms = 'PENDING'
        exact_hit_rate = 'PENDING'; checkpoint_hit_rate = 'PENDING'
        restore_latency_by_kind = @{}
        demotion_count = 'PENDING'; promotion_count = 'PENDING'; eviction_count = 'PENDING'
        workingset_samples = @(); handle_samples = @()
        correctness_verdict = 'PENDING'
    }
    $obj | ConvertTo-Json -Depth 6 | Out-File -FilePath $basePath -Encoding utf8
    Write-BenchEvidence -OutDir $subDir -ScenarioId 'S12-B07' -Variant $p.name `
        -ModelFixture (Split-Path $p.model -Leaf) -BuildType 'Release' `
        -ServerFlags $flags -BaselinePath $basePath -TuningRow 6 `
        -Verdict PENDING -Notes "Live run; QA evaluates per-profile throughput"
}
