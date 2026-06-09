#requires -Version 5
# longrun_s12_l02_30m_legacy_comparison.ps1
# Stage 12 long-run: S12-L02 reproducibility 30 minute.
# Sampler interval 30 s. Same seed and fixture as a benchmark row;
# confirms metric and latency shape repeat within recorded tolerance.
# Evidence dir: ._design_docs/.test_reports/longrun-s12-l02-<timestamp>/

param(
    [string] $BuildDir         = '',
    [string] $ModelPath        = '',
    [string] $OutDir           = '',
    [int]    $Port             = 8402,
    [int]    $DurationMin      = 30,
    [int]    $SamplerIntervalS = 30,
    [int]    $SnapshotEveryMin = 10,
    [int]    $Seed             = 42,
    [int]    $WorkingsetThresholdPct  = 10,
    [int]    $HandleThresholdPct      = 5,
    [int]    $LatencyDriftThresholdPct = 20,
    [int]    $MtpVariant     = 0,
    [ValidateSet('original','marked')] [string] $JinjaVariant = 'original',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir  = $PSScriptRoot
$sourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$libDir     = Join-Path $sourceRoot '._design_docs\cache-handling-test-scripts\lib'

. (Join-Path $libDir 'Write-LongrunEvidence.ps1')
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\longrun-s12-l02-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$flags = @('--cache-mode','hybrid','--parallel','1','--cache-ram','100',
           '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
$flags = Merge-MtpJinjaFlag -Flags $flags -JinjaPath $jinjaPath

Write-Host "S12-L02 30m reproducibility; stub=$stubData"

if ($DryRun) {
    Write-Host "DRY-RUN: would run 30 min hybrid with 30 s sampler and compare shape to benchmark row"
    exit 0
}

$totalSeconds  = $DurationMin * 60
$snapshotEvery = $SnapshotEveryMin * 60
$endTime       = (Get-Date).AddSeconds($totalSeconds)
$snapshotPaths = @()

if ($stubData) {
    "elapsed_s,workingset_bytes,handle_count,server_live" |
        Out-File -FilePath (Join-Path $OutDir 'resource-samples.csv') -Encoding utf8
    Write-LongrunEvidence -OutDir $OutDir -ScenarioId 'S12-L02' -Variant 'reproducibility-30m' `
        -DurationSeconds $totalSeconds -SamplerIntervalSeconds $SamplerIntervalS `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $flags `
        -WorkingsetThresholdPct $WorkingsetThresholdPct `
        -HandleThresholdPct $HandleThresholdPct `
        -LatencyDriftThresholdPct $LatencyDriftThresholdPct `
        -ResourceSamplesPath (Join-Path $OutDir 'resource-samples.csv') `
        -PartialSnapshotPaths @() -StubData -Verdict BLOCKED `
        -Notes "Model fixture not found at $ModelPath"
    exit 0
}

Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $serverExe `
    -ArgumentList ($flags + @('--model',$ModelPath,'--host','127.0.0.1',"--port","$Port")) `
    -RedirectStandardOutput (Join-Path $OutDir 'server.out.log') `
    -RedirectStandardError  (Join-Path $OutDir 'server.err.log') `
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

$csvPath = Join-Path $OutDir 'resource-samples.csv'
"elapsed_s,workingset_bytes,handle_count,server_live" | Out-File -FilePath $csvPath -Encoding utf8

$start = Get-Date
$lastSnapshot = $start
$rowCount = 0
$live = 'true'
while ((Get-Date) -lt $endTime) {
    $body = '{"prompt":"S12-L02 reproducibility probe","n_predict":2,"temperature":0,"seed":42,"cache_prompt":true}'
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
            -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
        $rowCount++; $live = 'true'
    } catch { $live = 'false' }
    $pr = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if (-not $pr) { $live = 'crashed' }
    if ($pr) {
        "{0},{1},{2},{3}" -f ([int]((Get-Date) - $start).TotalSeconds), $pr.WorkingSet64, $pr.HandleCount, $live |
            Out-File -FilePath $csvPath -Append -Encoding utf8
    }
    if (((Get-Date) - $lastSnapshot).TotalSeconds -ge $snapshotEvery) {
        $snapPath = Join-Path $OutDir ("snapshot-{0}m.csv" -f ([int]((Get-Date) - $start).TotalMinutes))
        Copy-Item $csvPath $snapPath -Force
        $snapshotPaths += $snapPath
        $lastSnapshot = Get-Date
    }
    Start-Sleep -Seconds $SamplerIntervalS
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt') -Encoding utf8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

Write-LongrunEvidence -OutDir $OutDir -ScenarioId 'S12-L02' -Variant 'reproducibility-30m' `
    -DurationSeconds $totalSeconds -SamplerIntervalSeconds $SamplerIntervalS `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $flags `
    -WorkingsetThresholdPct $WorkingsetThresholdPct `
    -HandleThresholdPct $HandleThresholdPct `
    -LatencyDriftThresholdPct $LatencyDriftThresholdPct `
    -ResourceSamplesPath $csvPath -PartialSnapshotPaths $snapshotPaths `
    -Verdict PENDING -Notes "Live run; QA compares shape to paired benchmark row"
