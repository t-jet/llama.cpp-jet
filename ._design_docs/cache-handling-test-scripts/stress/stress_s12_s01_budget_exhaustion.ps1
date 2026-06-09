#requires -Version 5
# stress_s12_s01_budget_exhaustion.ps1
# Stage 12 stress: S12-S01 budget exhaustion.
# Hybrid mode, tiny --cache-ram, cold path disabled and enabled variants.
# 30 minute run per variant. Stub data when fixture unavailable.
# Evidence dir: ._design_docs/.test_reports/stress-s12-s01-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $OutDir         = '',
    [int]    $Port           = 8201,
    [int]    $DurationMin    = 30,
    [int]    $HotBudgetMiB   = 2,
    [int]    $ParallelSlots  = 2,
    [int]    $Seed           = 42,
    [switch] $ColdEnabled,
    [int]    $MtpVariant    = 0,
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\stress-s12-s01-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)
$variant  = if ($ColdEnabled) { 'cold-on' } else { 'cold-off' }
$subDir   = Join-Path $OutDir $variant

Write-Host "S12-S01 budget exhaustion; variant=$variant; stub=$stubData"

$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--ctx-size','512',
                 '--temp','0','--seed',"$Seed",'--model',$ModelPath)
$serverFlags = Merge-MtpJinjaFlag -Flags $serverFlags -JinjaPath $jinjaPath

if ($DryRun) {
    Write-Host "DRY-RUN: would start server with: $serverExe $($serverFlags -join ' ')"
    Write-Host "DRY-RUN: would run for $DurationMin min and write evidence to $subDir"
    exit 0
}

if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }

if ($stubData) {
    $stubLines = @(
        "# S12-S01 stub evidence",
        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Stub data: model fixture not found at $ModelPath",
        "Variant: $variant",
        "Planned flags: $($serverFlags -join ' ')",
        "Planned duration: $DurationMin min",
        "Planned port: $Port"
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText((Join-Path $subDir 'server.out.log'),
        ($stubLines -join "`r`n") + "`r`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $subDir 'server.err.log'), "", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $subDir 'metrics-before.txt'), "# STUB`r`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $subDir 'metrics-during.txt'), "# STUB`r`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $subDir 'metrics-after.txt'),  "# STUB`r`n", $utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $subDir 'resource-samples.csv'),
        "elapsed_s,workingset_bytes,handle_count`r`n", $utf8NoBom)
    Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S01' -Variant $variant `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $serverFlags -RequestCount 0 -Seed $Seed `
        -DurationSeconds ($DurationMin * 60) `
        -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
        -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
        -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
        -ResourceSamplesPath (Join-Path $subDir 'resource-samples.csv') `
        -StubData -Verdict BLOCKED -Notes "Model fixture not found at $ModelPath"
    exit 0
}

# Live run path: start server, snapshot metrics, run load, snapshot, stop.
Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $serverExe -ArgumentList ($serverFlags + @('--host','127.0.0.1',"--port","$Port")) `
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
    Write-Error "Server did not become ready in 180 s"
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

$start = Get-Date
$end   = $start.AddMinutes($DurationMin)
$rowCount = 0
$csvPath  = Join-Path $subDir 'resource-samples.csv'
"elapsed_s,workingset_bytes,handle_count" | Out-File -FilePath $csvPath -Encoding utf8

while ((Get-Date) -lt $end) {
    $body = '{"prompt":"S12-S01 budget-exhaust probe","n_predict":4,"temperature":0,"seed":42,"cache_prompt":true}'
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
            -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
        $rowCount++
    } catch {}
    $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($p) {
        "{0},{1},{2}" -f ([int]((Get-Date) - $start).TotalSeconds), $p.WorkingSet64, $p.HandleCount |
            Out-File -FilePath $csvPath -Append -Encoding utf8
    }
    Start-Sleep -Seconds 1
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S01' -Variant $variant `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $serverFlags -RequestCount $rowCount -Seed $Seed `
    -DurationSeconds ($DurationMin * 60) `
    -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
    -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
    -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
    -ResourceSamplesPath $csvPath -Verdict PENDING -Notes "Live run; QA evaluates"
