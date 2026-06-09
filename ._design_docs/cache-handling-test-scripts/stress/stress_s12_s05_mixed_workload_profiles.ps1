#requires -Version 5
# stress_s12_s05_mixed_workload_profiles.ps1
# Stage 12 stress: S12-S05 mixed workload profiles.
# Plain-transformer Qwen3-0.6B (default); target-plus-draft Qwen3-8B
# plus Qwen3-0.6B if both fixtures load; checkpoint-dependent BLOCKED
# without fixture. 30 minute run per profile. Stub data otherwise.
# Evidence dir: ._design_docs/.test_reports/stress-s12-s05-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $DraftModelPath = '',
    [string] $OutDir         = '',
    [int]    $DurationMin    = 30,
    [int]    $Seed           = 42,
    [int]    $MtpVariant     = 0,
    [ValidateSet('original','marked')] [string] $JinjaVariant = 'original',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir  = $PSScriptRoot
$sourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$libDir     = Join-Path $sourceRoot '._design_docs\cache-handling-test-scripts\lib'

. (Join-Path $libDir 'Write-StressEvidence.ps1')
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\stress-s12-s05-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$profiles = @(
    @{ name = 'plain-transformer'; model = $ModelPath;      draft = $null;     args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','50') }
    @{ name = 'target-plus-draft'; model = $largerModel;    draft = $DraftModelPath; args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','200','--model-draft',$DraftModelPath) }
    @{ name = 'checkpoint-dependent'; model = $largerModel; draft = $null;     args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','200') }
)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

if ($DryRun) {
    foreach ($p in $profiles) {
        Write-Host "DRY-RUN: would run profile $($p.name) for $DurationMin min"
    }
    exit 0
}

foreach ($p in $profiles) {
    $subDir = Join-Path $OutDir $p.name
    if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }

    $stub = -not (Test-Path $p.model)
    if ($p.draft) { $stub = $stub -or (-not (Test-Path $p.draft)) }
    $serverFlags = $p.args
    $serverFlags = Merge-MtpJinjaFlag -Flags $serverFlags -JinjaPath $jinjaPath

    if ($stub) {
        "# STUB: profile $($p.name) fixture missing" |
            Out-File -FilePath (Join-Path $subDir 'server.out.log') -Encoding utf8
        "" | Out-File -FilePath (Join-Path $subDir 'server.err.log') -Encoding utf8
        "# STUB" | Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8
        "# STUB" | Out-File -FilePath (Join-Path $subDir 'metrics-during.txt') -Encoding utf8
        "# STUB" | Out-File -FilePath (Join-Path $subDir 'metrics-after.txt')  -Encoding utf8
        "elapsed_s,workingset_bytes,handle_count`r`n" |
            Out-File -FilePath (Join-Path $subDir 'resource-samples.csv') -Encoding utf8
        $note = if ($p.name -eq 'checkpoint-dependent') {
            "Checkpoint-dependent fixture absent; BLOCKED per plan"
        } else {
            "Model or draft fixture not found"
        }
        Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S05' -Variant $p.name `
            -ModelFixture (Split-Path $p.model -Leaf) -BuildType 'Release' `
            -ServerFlags $serverFlags -Seed $Seed -DurationSeconds ($DurationMin * 60) `
            -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
            -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
            -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
            -ResourceSamplesPath (Join-Path $subDir 'resource-samples.csv') `
            -StubData -Verdict BLOCKED -Notes $note
        continue
    }

    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $port = 8230 + ([int]([System.Text.Encoding]::UTF8.GetBytes($p.name)[0]))
    $modelArg = @('--model',$p.model)
    $startArgs = $serverFlags + $modelArg + @('--host','127.0.0.1',"--port","$port",
                        '--temp','0','--seed',"$Seed",'--ctx-size','512')

    $proc = Start-Process -FilePath $serverExe -ArgumentList $startArgs `
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
        Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S05' -Variant $p.name `
            -ModelFixture (Split-Path $p.model -Leaf) -BuildType 'Release' `
            -ServerFlags $serverFlags -Seed $Seed -DurationSeconds ($DurationMin * 60) `
            -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
            -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
            -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
            -ResourceSamplesPath (Join-Path $subDir 'resource-samples.csv') `
            -StubData -Verdict BLOCKED -Notes "Server failed to start for profile $($p.name)"
        continue
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

    $start = Get-Date
    $end   = $start.AddMinutes($DurationMin)
    $rowCount = 0
    $csvPath  = Join-Path $subDir 'resource-samples.csv'
    "elapsed_s,workingset_bytes,handle_count" | Out-File -FilePath $csvPath -Encoding utf8

    while ((Get-Date) -lt $end) {
        $body = '{"prompt":"S12-S05 mixed profile probe","n_predict":3,"temperature":0,"seed":42,"cache_prompt":true}'
        try {
            Invoke-WebRequest -Uri "http://127.0.0.1:$port/completion" -Method POST `
                -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
            $rowCount++
        } catch {}
        $pr = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if ($pr) {
            "{0},{1},{2}" -f ([int]((Get-Date) - $start).TotalSeconds), $pr.WorkingSet64, $pr.HandleCount |
                Out-File -FilePath $csvPath -Append -Encoding utf8
        }
        Start-Sleep -Seconds 1
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

    Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S05' -Variant $p.name `
        -ModelFixture (Split-Path $p.model -Leaf) -BuildType 'Release' `
        -ServerFlags $serverFlags -RequestCount $rowCount -Seed $Seed `
        -DurationSeconds ($DurationMin * 60) `
        -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
        -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
        -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
        -ResourceSamplesPath $csvPath -Verdict PENDING -Notes "Live run; QA evaluates"
}
