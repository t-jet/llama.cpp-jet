#requires -Version 5
# stress_s12_s06_cold_queue_pressure.ps1
# Stage 12 stress: S12-S06 cold queue pressure.
# Hybrid mode, cold path on, small hot budget, 30 min run.
# Stub data when fixture unavailable.
# Evidence dir: ._design_docs/.test_reports/stress-s12-s06-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $OutDir         = '',
    [int]    $Port           = 8206,
    [int]    $DurationMin    = 30,
    [int]    $HotBudgetMiB   = 16,
    [int]    $ParallelSlots  = 2,
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
if (-not $OutDir) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\stress-s12-s06-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)
$tempRoot = Join-Path $env:TEMP "s12-s06-cold-$([guid]::NewGuid().Guid.Substring(0,8))"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--cache-cold-path',$tempRoot,
                 '--ctx-size','512','--temp','0','--seed',"$Seed")
$serverFlags = Merge-MtpJinjaFlag -Flags $serverFlags -JinjaPath $jinjaPath

Write-Host "S12-S06 cold queue pressure; cold-path=$tempRoot; stub=$stubData"

if ($DryRun) {
    Write-Host "DRY-RUN: would create $tempRoot and run for $DurationMin min"
    exit 0
}

if ($stubData) {
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'server.out.log') -Encoding utf8
    "" | Out-File -FilePath (Join-Path $OutDir 'server.err.log') -Encoding utf8
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'metrics-during.txt') -Encoding utf8
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt')  -Encoding utf8
    "elapsed_s,workingset_bytes,handle_count`r`n" |
        Out-File -FilePath (Join-Path $OutDir 'resource-samples.csv') -Encoding utf8
    Write-StressEvidence -OutDir $OutDir -ScenarioId 'S12-S06' -Variant 'cold-queue-16MiB' `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $serverFlags -Seed $Seed -DurationSeconds ($DurationMin * 60) `
        -MetricsBeforePath (Join-Path $OutDir 'metrics-before.txt') `
        -MetricsDuringPath (Join-Path $OutDir 'metrics-during.txt') `
        -MetricsAfterPath  (Join-Path $OutDir 'metrics-after.txt') `
        -ResourceSamplesPath (Join-Path $OutDir 'resource-samples.csv') `
        -StubData -Verdict BLOCKED -Notes "Model fixture not found at $ModelPath"
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
    -ArgumentList ($serverFlags + @('--model',$ModelPath,'--host','127.0.0.1',"--port","$Port")) `
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

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8

$start = Get-Date
$end   = $start.AddMinutes($DurationMin)
$rowCount = 0
$csvPath  = Join-Path $OutDir 'resource-samples.csv'
"elapsed_s,workingset_bytes,handle_count,cold_files" | Out-File -FilePath $csvPath -Encoding utf8

while ((Get-Date) -lt $end) {
    $body = '{"prompt":"S12-S06 cold queue probe","n_predict":3,"temperature":0,"seed":42,"cache_prompt":true}'
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
            -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
        $rowCount++
    } catch {}
    $pr = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    $coldCount = 0
    if (Test-Path $tempRoot) { $coldCount = (Get-ChildItem -Path $tempRoot -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count }
    if ($pr) {
        "{0},{1},{2},{3}" -f ([int]((Get-Date) - $start).TotalSeconds), $pr.WorkingSet64, $pr.HandleCount, $coldCount |
            Out-File -FilePath $csvPath -Append -Encoding utf8
    }
    Start-Sleep -Seconds 1
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt') -Encoding utf8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

Write-StressEvidence -OutDir $OutDir -ScenarioId 'S12-S06' -Variant 'cold-queue-16MiB' `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $serverFlags -RequestCount $rowCount -Seed $Seed `
    -DurationSeconds ($DurationMin * 60) `
    -MetricsBeforePath (Join-Path $OutDir 'metrics-before.txt') `
    -MetricsDuringPath (Join-Path $OutDir 'metrics-during.txt') `
    -MetricsAfterPath  (Join-Path $OutDir 'metrics-after.txt') `
    -ResourceSamplesPath $csvPath -Verdict PENDING -Notes "Live run; QA evaluates"
