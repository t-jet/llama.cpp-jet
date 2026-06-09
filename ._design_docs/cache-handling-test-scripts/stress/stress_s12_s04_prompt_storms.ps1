#requires -Version 5
# stress_s12_s04_prompt_storms.ps1
# Stage 12 stress: S12-S04 prompt storms.
# Hybrid mode, near-duplicate and exact-repeat prompt mix.
# 30 minute run. Stub data when fixture unavailable.
# Evidence dir: ._design_docs/.test_reports/stress-s12-s04-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $OutDir         = '',
    [int]    $Port           = 8204,
    [int]    $DurationMin    = 30,
    [int]    $HotBudgetMiB   = 100,
    [int]    $ParallelSlots  = 4,
    [int]    $Seed           = 42,
    [int]    $RepeatCount    = 8,
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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\stress-s12-s04-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

Write-Host "S12-S04 prompt storms; stub=$stubData"

$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--ctx-size','512',
                 '--temp','0','--seed',"$Seed")
$serverFlags = Merge-MtpJinjaFlag -Flags $serverFlags -JinjaPath $jinjaPath

if ($DryRun) {
    Write-Host "DRY-RUN: would loop $RepeatCount repeats of near-dup and exact prompts for $DurationMin min"
    exit 0
}

if ($stubData) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    "# STUB" | Out-File (Join-Path $OutDir 'server.out.log') $utf8NoBom
    "" | Out-File (Join-Path $OutDir 'server.err.log') $utf8NoBom
    "# STUB" | Out-File (Join-Path $OutDir 'metrics-before.txt') $utf8NoBom
    "# STUB" | Out-File (Join-Path $OutDir 'metrics-during.txt') $utf8NoBom
    "# STUB" | Out-File (Join-Path $OutDir 'metrics-after.txt')  $utf8NoBom
    "elapsed_s,workingset_bytes,handle_count`r`n" | Out-File (Join-Path $OutDir 'resource-samples.csv') $utf8NoBom
    Write-StressEvidence -OutDir $OutDir -ScenarioId 'S12-S04' -Variant 'storm-100MiB' `
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

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8

$basePrompts = 1..16 | ForEach-Object {
    $tag = [guid]::NewGuid().Guid.Substring(0,8)
    "Prompt storm base $_ tag $tag"
}

$start = Get-Date
$end   = $start.AddMinutes($DurationMin)
$rowCount = 0
$csvPath  = Join-Path $OutDir 'resource-samples.csv'
"elapsed_s,workingset_bytes,handle_count" | Out-File -FilePath $csvPath -Encoding utf8

while ((Get-Date) -lt $end) {
    foreach ($bp in $basePrompts) {
        for ($r = 0; $r -lt $RepeatCount; $r++) {
            $variant = if (($r % 4) -eq 0) { $bp } else { "$bp v$r" }
            $body = (@{ prompt = $variant; n_predict = 3; temperature = 0; seed = $Seed; cache_prompt = $true } |
                ConvertTo-Json -Compress)
            try {
                Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
                    -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
                $rowCount++
            } catch {}
        }
    }
    $pr = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($pr) {
        "{0},{1},{2}" -f ([int]((Get-Date) - $start).TotalSeconds), $pr.WorkingSet64, $pr.HandleCount |
            Out-File -FilePath $csvPath -Append -Encoding utf8
    }
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt') -Encoding utf8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

Write-StressEvidence -OutDir $OutDir -ScenarioId 'S12-S04' -Variant 'storm-100MiB' `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $serverFlags -RequestCount $rowCount -Seed $Seed `
    -DurationSeconds ($DurationMin * 60) `
    -MetricsBeforePath (Join-Path $OutDir 'metrics-before.txt') `
    -MetricsDuringPath (Join-Path $OutDir 'metrics-during.txt') `
    -MetricsAfterPath  (Join-Path $OutDir 'metrics-after.txt') `
    -ResourceSamplesPath $csvPath -Verdict PENDING -Notes "Live run; QA evaluates"
