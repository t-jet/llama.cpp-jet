#requires -Version 5
# stress_s12_s08_integrity_failure_under_load.ps1
# Stage 12 stress: S12-S08 integrity failure under load.
# Hybrid mode with fault-injection precondition via
# test-step11-test-hooks-fault-injection.exe (focused), then live load
# continues. 30 min run. Stub data when fixture or focused binary
# unavailable.
# Evidence dir: ._design_docs/.test_reports/stress-s12-s08-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $OutDir         = '',
    [int]    $Port           = 8208,
    [int]    $DurationMin    = 30,
    [int]    $HotBudgetMiB   = 50,
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\stress-s12-s08-$ts"
}
$serverExe    = Join-Path $BuildDir 'bin\Release\llama-server.exe'
$faultBin     = Join-Path $BuildDir 'bin\Release\test-step11-test-hooks-fault-injection.exe'

$stubData   = -not (Test-Path $ModelPath)
$faultStub  = -not (Test-Path $faultBin)
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--ctx-size','512',
                 '--temp','0','--seed',"$Seed")
$serverFlags = Merge-MtpJinjaFlag -Flags $serverFlags -JinjaPath $jinjaPath

Write-Host "S12-S08 integrity failure under load; stub=$stubData faultStub=$faultStub"

if ($DryRun) {
    Write-Host "DRY-RUN: would seed fault precondition via $faultBin, then run $DurationMin min"
    exit 0
}

if ($stubData) {
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'server.out.log') -Encoding utf8
    "" | Out-File -FilePath (Join-Path $OutDir 'server.err.log') -Encoding utf8
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'metrics-during.txt') -Encoding utf8
    "# STUB" | Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt')  -Encoding utf8
    "elapsed_s,workingset_bytes,handle_count`r`n" |
        Out-File -Join-Path $OutDir 'resource-samples.csv' -ErrorAction SilentlyContinue
    Out-File -FilePath (Join-Path $OutDir 'resource-samples.csv') -InputObject "elapsed_s,workingset_bytes,handle_count" -Encoding utf8
    Write-StressEvidence -OutDir $OutDir -ScenarioId 'S12-S08' -Variant 'fault-load-50MiB' `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $serverFlags -Seed $Seed -DurationSeconds ($DurationMin * 60) `
        -MetricsBeforePath (Join-Path $OutDir 'metrics-before.txt') `
        -MetricsDuringPath (Join-Path $OutDir 'metrics-during.txt') `
        -MetricsAfterPath  (Join-Path $OutDir 'metrics-after.txt') `
        -ResourceSamplesPath (Join-Path $OutDir 'resource-samples.csv') `
        -StubData -Verdict BLOCKED -Notes "Model fixture not found at $ModelPath"
    exit 0
}

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

$precondPath = Join-Path $OutDir 'precondition.log'
"Focus binary: $faultBin`r`nStub: $faultStub`r`n" | Out-File -FilePath $precondPath -Encoding utf8
if (-not $faultStub) {
    $args = @('--fault','descriptor-mismatch','--port',"$Port",'--seed',"$Seed")
    $p = Start-Process -FilePath $faultBin -ArgumentList $args `
        -RedirectStandardOutput ($precondPath + '.out') -RedirectStandardError ($precondPath + '.err') `
        -NoNewWindow -PassThru -Wait
    "fault exit code: $($p.ExitCode)`r`n" | Out-File -FilePath $precondPath -Append -Encoding utf8
} else {
    "STUB: focused fault-injection binary missing; precondition not set" |
        Out-File -FilePath $precondPath -Append -Encoding utf8
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8

$start = Get-Date
$end   = $start.AddMinutes($DurationMin)
$rowCount = 0
$csvPath  = Join-Path $OutDir 'resource-samples.csv'
"elapsed_s,workingset_bytes,handle_count" | Out-File -FilePath $csvPath -Encoding utf8

while ((Get-Date) -lt $end) {
    $body = '{"prompt":"S12-S08 integrity under load","n_predict":3,"temperature":0,"seed":42,"cache_prompt":true}'
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
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

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt') -Encoding utf8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

Write-StressEvidence -OutDir $OutDir -ScenarioId 'S12-S08' -Variant 'fault-load-50MiB' `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $serverFlags -RequestCount $rowCount -Seed $Seed `
    -DurationSeconds ($DurationMin * 60) `
    -MetricsBeforePath (Join-Path $OutDir 'metrics-before.txt') `
    -MetricsDuringPath (Join-Path $OutDir 'metrics-during.txt') `
    -MetricsAfterPath  (Join-Path $OutDir 'metrics-after.txt') `
    -ResourceSamplesPath $csvPath -PreconditionLogPath $precondPath `
    -Verdict PENDING -Notes "Live run with fault precondition; QA evaluates"
