#requires -Version 5
# stress_s12_s02_concurrent_multi_slot.ps1
# Stage 12 stress: S12-S02 concurrent multi-slot access.
# Hybrid mode, --parallel 4 and 8. BLOCKED for 8 if host cannot start.
# 30 minute run per slot count. Stub data when fixture unavailable.
# Evidence dir: ._design_docs/.test_reports/stress-s12-s02-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $OutDir         = '',
    [int]    $Port           = 8210,
    [int]    $DurationMin    = 30,
    [int[]]  $SlotCounts     = @(4, 8),
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\stress-s12-s02-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

Write-Host "S12-S02 concurrent multi-slot; stub=$stubData"

if ($DryRun) {
    foreach ($n in $SlotCounts) {
        $plannedPort = $Port + $n
        Write-Host "DRY-RUN: would probe parallel=$n for $DurationMin min on port $plannedPort"
    }
    exit 0
}

foreach ($n in $SlotCounts) {
    $subDir = Join-Path $OutDir "parallel$n"
    if (-not (Test-Path $subDir)) { New-Item -ItemType Directory -Force -Path $subDir | Out-Null }

    $serverFlags = @('--cache-mode','hybrid','--parallel',"$n",'--metrics',
                     '--ctx-size','512','--temp','0','--seed',"$Seed",
                     '--cache-ram','100')
    $serverFlags = Merge-MtpJinjaFlag -Flags $serverFlags -JinjaPath $jinjaPath

    if ($stubData) {
        "# STUB: model not found at $ModelPath" |
            Out-File -FilePath (Join-Path $subDir 'server.out.log') -Encoding utf8
        "" | Out-File -FilePath (Join-Path $subDir 'server.err.log') -Encoding utf8
        "# STUB" | Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8
        "# STUB" | Out-File -FilePath (Join-Path $subDir 'metrics-during.txt') -Encoding utf8
        "# STUB" | Out-File -FilePath (Join-Path $subDir 'metrics-after.txt')  -Encoding utf8
        "elapsed_s,workingset_bytes,handle_count`r`n" |
            Out-File -FilePath (Join-Path $subDir 'resource-samples.csv') -Encoding utf8
        Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S02' -Variant "parallel$n" `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $serverFlags -Seed $Seed -DurationSeconds ($DurationMin * 60) `
            -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
            -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
            -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
            -ResourceSamplesPath (Join-Path $subDir 'resource-samples.csv') `
            -StubData -Verdict BLOCKED -Notes "Model fixture not found at $ModelPath"
        continue
    }

    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $portUse = $Port + $n
    $proc = Start-Process -FilePath $serverExe `
        -ArgumentList ($serverFlags + @('--model',$ModelPath,'--host','127.0.0.1',"--port","$portUse")) `
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
        Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S02' -Variant "parallel$n" `
            -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
            -ServerFlags $serverFlags -Seed $Seed -DurationSeconds ($DurationMin * 60) `
            -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
            -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
            -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
            -ResourceSamplesPath (Join-Path $subDir 'resource-samples.csv') `
            -StubData -Verdict BLOCKED -Notes "Server failed to start at parallel=$n (host limit)"
        continue
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-before.txt') -Encoding utf8

    $start = Get-Date
    $end   = $start.AddMinutes($DurationMin)
    $rowCount = 0
    $csvPath  = Join-Path $subDir 'resource-samples.csv'
    "elapsed_s,workingset_bytes,handle_count" | Out-File -FilePath $csvPath -Encoding utf8

    while ((Get-Date) -lt $end) {
        $jobs = @()
        for ($i = 0; $i -lt $n; $i++) {
            $jobs += Start-Job -ScriptBlock {
                param($p, $sd)
                $b = '{"prompt":"S12-S02 slot probe","n_predict":3,"temperature":0,"seed":42,"cache_prompt":true}'
                try {
                    Invoke-WebRequest -Uri "http://127.0.0.1:$p/completion" -Method POST `
                        -Body $b -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
                } catch {}
            } -ArgumentList $portUse, $Seed
        }
        Wait-Job -Job $jobs | Out-Null
        $rowCount += $jobs.Count
        $jobs | Remove-Job

        $p = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if ($p) {
            "{0},{1},{2}" -f ([int]((Get-Date) - $start).TotalSeconds), $p.WorkingSet64, $p.HandleCount |
                Out-File -FilePath $csvPath -Append -Encoding utf8
        }
        Start-Sleep -Seconds 1
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$portUse/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $subDir 'metrics-after.txt') -Encoding utf8
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

    Write-StressEvidence -OutDir $subDir -ScenarioId 'S12-S02' -Variant "parallel$n" `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $serverFlags -RequestCount $rowCount -Seed $Seed `
        -DurationSeconds ($DurationMin * 60) `
        -MetricsBeforePath (Join-Path $subDir 'metrics-before.txt') `
        -MetricsDuringPath (Join-Path $subDir 'metrics-during.txt') `
        -MetricsAfterPath  (Join-Path $subDir 'metrics-after.txt') `
        -ResourceSamplesPath $csvPath -Verdict PENDING -Notes "Live run; QA evaluates"
}
