#requires -Version 5
# stress_s12_s06_cold_queue_pressure.ps1
# Stage 12 stress: S12-S06 cold queue pressure.
# Hybrid mode, cold path on, small hot budget, 30 min run.
# Stub data when fixture unavailable.
# Evidence dir: ._design_docs/.test_reports/stress-s12-s06-<timestamp>/

param(
    [string] $BuildDir       = '',
    [string] $ModelPath      = '',
    [string] $PressureModelPath = '',
    [string] $OutDir         = '',
    [int]    $Port           = 8206,
    [int]    $DurationMin    = 30,
    [int]    $HotBudgetMiB   = 16,
    [int]    $ParallelSlots  = 2,
    [int]    $Seed           = 42,
    [int]    $MtpVariant     = 0,
    [ValidateSet('original','marked')] [string] $JinjaVariant = 'original',
    [string] $Stage17ServerArgsBase64 = '',
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir  = $PSScriptRoot
$sourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..\..')).Path
$libDir     = Join-Path $sourceRoot '._design_docs\cache-handling-test-scripts\lib'

. (Join-Path $libDir 'Write-StressEvidence.ps1')
. (Join-Path $libDir 'Read-GgufChatTemplate.ps1')
. (Join-Path $libDir 'Get-Stage17ServerArgs.ps1')

if (-not $BuildDir)  { $BuildDir  = Join-Path $sourceRoot 'build' }
if (-not $ModelPath) {
    $ModelPath = if ($env:LLAMA_CACHE_TEST_MODEL) { $env:LLAMA_CACHE_TEST_MODEL }
                 else { Join-Path $sourceRoot '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf' }
}
if (-not $PressureModelPath) {
    $PressureModelPath = Join-Path $sourceRoot '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
}
$pressureModelAvailable = $PressureModelPath -and (Test-Path $PressureModelPath)
$serverModelPath = if ($pressureModelAvailable) { $PressureModelPath } else { $ModelPath }

# MTP + jinja variant params (post-closure follow-up, part-19 sec 7.1).
$jinjaPath = Resolve-MtpJinjaPath -MtpVariant $MtpVariant -JinjaVariant $JinjaVariant -ModelPath $serverModelPath -SourceRoot $sourceRoot
if ($MtpVariant -gt 0 -and $jinjaPath -and -not (Test-Path $jinjaPath)) {
    Write-Host "BLOCKED: jinja file missing at $jinjaPath (MtpVariant=$MtpVariant JinjaVariant=$JinjaVariant)"
}
if (-not $OutDir) {
    $ts = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\stress-s12-s06-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $serverModelPath)
$tempRoot = Join-Path $env:TEMP "s12-s06-cold-$([guid]::NewGuid().Guid.Substring(0,8))"

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

function Get-LastFlagValue {
    param(
        [string[]] $Flags,
        [string] $Name
    )
    $value = ''
    for ($i = 0; $i -lt $Flags.Count - 1; $i++) {
        if ($Flags[$i] -eq $Name) {
            $value = $Flags[$i + 1]
        }
    }
    return $value
}

$stage17Args = Get-Stage17ServerArgsFromBase64 -Encoded $Stage17ServerArgsBase64
$stage17ColdPath = Get-LastFlagValue -Flags $stage17Args -Name '--cache-cold-path'
$effectiveColdPath = if ($stage17ColdPath) { $stage17ColdPath } else { $tempRoot }

$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics',
                 '--ctx-size','512','--temp','0','--seed',"$Seed")
if (-not $stage17ColdPath) {
    $serverFlags += @('--cache-cold-path', $tempRoot)
}
$serverFlags = Merge-MtpJinjaFlag -Flags $serverFlags -JinjaPath $jinjaPath
$serverFlags += $stage17Args

Write-Host "S12-S06 cold queue pressure; cold-path=$effectiveColdPath; model=$serverModelPath; pressure-model=$pressureModelAvailable; unique-prompts=true; stub=$stubData"

if ($DryRun) {
    Write-Host "DRY-RUN: would create $effectiveColdPath and run for $DurationMin min; hot-budget=$HotBudgetMiB MiB; pressure-model=$serverModelPath; unique-prompts=true"
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
        -ModelFixture (Split-Path $serverModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $serverFlags -Seed $Seed -DurationSeconds ($DurationMin * 60) `
        -MetricsBeforePath (Join-Path $OutDir 'metrics-before.txt') `
        -MetricsDuringPath (Join-Path $OutDir 'metrics-during.txt') `
        -MetricsAfterPath  (Join-Path $OutDir 'metrics-after.txt') `
        -ResourceSamplesPath (Join-Path $OutDir 'resource-samples.csv') `
        -StubData -Verdict BLOCKED -Notes "Model fixture not found at $serverModelPath"
    exit 0
}

if (-not (Test-Path $effectiveColdPath)) { New-Item -ItemType Directory -Force -Path $effectiveColdPath | Out-Null }
$probe = Join-Path $effectiveColdPath 'probe.tmp'
"probe" | Out-File -FilePath $probe -Encoding utf8
if (-not (Test-Path $probe)) { [Console]::Error.WriteLine("Cold path not writable at $effectiveColdPath"); exit 1 }
Remove-Item $probe -Force

Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $serverExe `
    -ArgumentList ($serverFlags + @('--model',$serverModelPath,'--host','127.0.0.1',"--port","$Port")) `
    -RedirectStandardOutput (Join-Path $OutDir 'server.out.log') `
    -RedirectStandardError  (Join-Path $OutDir 'server.err.log') `
    -NoNewWindow -PassThru

$ready = $false
$deadline = (Get-Date).AddSeconds(300)
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 4
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue; [Console]::Error.WriteLine("Server did not start"); exit 1 }

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8

$start = Get-Date
$end   = $start.AddMinutes($DurationMin)
$rowCount = 0
$csvPath  = Join-Path $OutDir 'resource-samples.csv'
"elapsed_s,workingset_bytes,handle_count,cold_files" | Out-File -FilePath $csvPath -Encoding utf8

while ((Get-Date) -lt $end) {
    $prompt = "S12-S06 cold queue probe unique $rowCount seed $Seed alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu"
    $body = @{
        prompt = $prompt
        n_predict = 3
        temperature = 0
        seed = $Seed
        cache_prompt = $true
    } | ConvertTo-Json -Compress
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
            -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30 | Out-Null
        $rowCount++
    } catch {}
    $pr = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    $coldCount = 0
    if (Test-Path $effectiveColdPath) { $coldCount = (Get-ChildItem -Path $effectiveColdPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count }
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
    -ModelFixture (Split-Path $serverModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $serverFlags -RequestCount $rowCount -Seed $Seed `
    -DurationSeconds ($DurationMin * 60) `
    -MetricsBeforePath (Join-Path $OutDir 'metrics-before.txt') `
    -MetricsDuringPath (Join-Path $OutDir 'metrics-during.txt') `
    -MetricsAfterPath  (Join-Path $OutDir 'metrics-after.txt') `
    -ResourceSamplesPath $csvPath -Verdict PENDING -Notes "Live run; QA evaluates; primary model $(Split-Path $ModelPath -Leaf); pressure model $(Split-Path $serverModelPath -Leaf)"
