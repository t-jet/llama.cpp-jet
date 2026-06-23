#requires -Version 5
# longrun_s12_l02_30m_legacy_comparison.ps1
# Stage 12/23 long-run: S12-L02 legacy comparison.
# Runs a bounded paired legacy-control leg and Stage 23 hybrid leg, then writes
# a row-owned comparison artifact.
# Evidence dir: ._design_docs/.test_reports/longrun-s12-l02-<timestamp>/

param(
    [string] $BuildDir         = '',
    [string] $ModelPath        = '',
    [string] $OutDir           = '',
    [int]    $Port             = 8402,
    [int]    $DurationHours    = 0,
    [int]    $DurationMin      = 30,
    [int]    $SamplerIntervalS = 30,
    [int]    $SnapshotEveryMin = 10,
    [int]    $Seed             = 42,
    [int]    $WorkingsetThresholdPct  = 10,
    [int]    $HandleThresholdPct      = 5,
    [int]    $LatencyDriftThresholdPct = 20,
    [int]    $ServerStartupTimeoutS = 300,
    [int]    $MtpVariant     = 0,
    [ValidateSet('original','marked')] [string] $JinjaVariant = 'original',
    [string] $Stage17ServerArgsBase64 = '',
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
if ($Stage17ServerArgsBase64) {
    $stage17Json = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Stage17ServerArgsBase64))
    $stage17Decoded = $stage17Json | ConvertFrom-Json
    $stage17FlagList = New-Object System.Collections.Generic.List[string]
    foreach ($arg in $stage17Decoded) { [void]$stage17FlagList.Add([string]$arg) }
    $stage17Flags = $stage17FlagList.ToArray()
} else {
    $stage17Flags = @()
}
$flags += $stage17Flags

$totalSeconds = (($DurationHours * 60) + $DurationMin) * 60
if ($totalSeconds -le 0) { $totalSeconds = 30 * 60 }
$legacySeconds = [Math]::Max($SamplerIntervalS, [int][Math]::Floor($totalSeconds / 2))
$hybridSeconds = [Math]::Max($SamplerIntervalS, $totalSeconds - $legacySeconds)
$legPlan = "legacy-control=${legacySeconds}s,hybrid-stage23=${hybridSeconds}s,total=${totalSeconds}s"

Write-Host "S12-L02 legacy comparison; stub=$stubData"

if ($DryRun) {
    Write-Host "DRY-RUN: paired legacy comparison plan $legPlan"
    Write-Host "DRY-RUN: legacy-control mode=legacy filters hybrid-only cold/evidence args; hybrid-stage23 mode=hybrid keeps Stage 23 cold/evidence args"
    exit 0
}

$snapshotEvery = $SnapshotEveryMin * 60

if ($stubData) {
    "elapsed_s,workingset_bytes,handle_count,server_live" |
        Out-File -FilePath (Join-Path $OutDir 'resource-samples.csv') -Encoding utf8
    Write-LongrunEvidence -OutDir $OutDir -ScenarioId 'S12-L02' -Variant 'legacy-comparison' `
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

function Get-MetricValue {
    param([string] $Path, [string] $Name)
    if (-not (Test-Path $Path)) { return $null }
    $pattern = '^' + [regex]::Escape($Name) + '(?:\{[^}]*\})?\s+([-+]?[0-9]+(?:\.[0-9]+)?)'
    $sum = 0.0
    $found = $false
    foreach ($line in Get-Content -LiteralPath $Path) {
        $m = [regex]::Match($line, $pattern)
        if ($m.Success) {
            $sum += [double]$m.Groups[1].Value
            $found = $true
        }
    }
    if ($found) { return $sum }
    return $null
}

function Get-LegMetrics {
    param([string] $LegDir)
    $before = Join-Path $LegDir 'metrics-before.txt'
    $after = Join-Path $LegDir 'metrics-after.txt'
    $names = @(
        'llamacpp_cache_hits_total',
        'llamacpp_cache_misses_total',
        'llamacpp_cache_entries',
        'llamacpp_cache_bytes',
        'cache_restore_misses_total',
        'cache_prompt_evidence_records_total',
        'cache_cold_bytes',
        'cache_cold_budget_bytes',
        'cache_checkpoint_admissions_by_shape_total'
    )
    $result = [ordered]@{}
    foreach ($name in $names) {
        $b = Get-MetricValue -Path $before -Name $name
        $a = Get-MetricValue -Path $after -Name $name
        $d = if ($null -ne $b -and $null -ne $a) { $a - $b } else { $null }
        $result[$name] = [ordered]@{ before = $b; after = $a; delta = $d }
    }
    return $result
}

function Invoke-L02Leg {
    param(
        [string] $Name,
        [string] $Mode,
        [string[]] $ServerFlags,
        [int] $LegPort,
        [int] $LegSeconds
    )

    $legDir = Join-Path $OutDir $Name
    if (-not (Test-Path $legDir)) { New-Item -ItemType Directory -Force -Path $legDir | Out-Null }
    ($ServerFlags -join ' ') | Out-File -FilePath (Join-Path $legDir 'server-flags.txt') -Encoding utf8

    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1

    $proc = Start-Process -FilePath $serverExe `
        -ArgumentList ($ServerFlags + @('--model',$ModelPath,'--host','127.0.0.1',"--port","$LegPort")) `
        -RedirectStandardOutput (Join-Path $legDir 'server.out.log') `
        -RedirectStandardError  (Join-Path $legDir 'server.err.log') `
        -NoNewWindow -PassThru

    $ready = $false
    $deadline = (Get-Date).AddSeconds($ServerStartupTimeoutS)
    while ((Get-Date) -lt $deadline) {
        try {
            $h = Invoke-WebRequest -Uri "http://127.0.0.1:$LegPort/health" -UseBasicParsing -TimeoutSec 4
            if ($h.StatusCode -eq 200) { $ready = $true; break }
        } catch {}
        Start-Sleep -Seconds 2
    }
    if (-not $ready) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        throw "L02 $Name server did not start"
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$LegPort/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $legDir 'metrics-before.txt') -Encoding utf8

    $csvPath = Join-Path $legDir 'resource-samples.csv'
    "elapsed_s,workingset_bytes,handle_count,server_live" | Out-File -FilePath $csvPath -Encoding utf8
    $samplesPath = Join-Path $legDir 'request-samples.jsonl'

    $start = Get-Date
    $endTime = $start.AddSeconds($LegSeconds)
    $lastSnapshot = $start
    $snapshotPaths = @()
    $rowCount = 0
    $cacheNSum = 0
    $liveCount = 0
    $live = 'true'

    while ((Get-Date) -lt $endTime) {
        $body = '{"prompt":"S12-L02 legacy comparison probe","n_predict":2,"temperature":0,"seed":42,"cache_prompt":true}'
        try {
            $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$LegPort/completion" -Method POST `
                -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30
            $json = $resp.Content | ConvertFrom-Json
            $cacheN = if ($json.timings) { [int]$json.timings.cache_n } else { 0 }
            $cacheNSum += $cacheN
            $rowCount++
            $liveCount++
            $live = 'true'
            ([ordered]@{
                elapsed_s = [int]((Get-Date) - $start).TotalSeconds
                status = [int]$resp.StatusCode
                cache_n = $cacheN
                mode = $Mode
            } | ConvertTo-Json -Compress) | Out-File -FilePath $samplesPath -Append -Encoding utf8
        } catch {
            $live = 'false'
            ([ordered]@{
                elapsed_s = [int]((Get-Date) - $start).TotalSeconds
                status = 'request-error'
                error = $_.Exception.Message
                mode = $Mode
            } | ConvertTo-Json -Compress) | Out-File -FilePath $samplesPath -Append -Encoding utf8
        }
        $pr = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if (-not $pr) { $live = 'crashed' }
        if ($pr) {
            "{0},{1},{2},{3}" -f ([int]((Get-Date) - $start).TotalSeconds), $pr.WorkingSet64, $pr.HandleCount, $live |
                Out-File -FilePath $csvPath -Append -Encoding utf8
        }
        if (((Get-Date) - $lastSnapshot).TotalSeconds -ge $snapshotEvery) {
            $snapPath = Join-Path $legDir ("snapshot-{0}m.csv" -f ([int]((Get-Date) - $start).TotalMinutes))
            Copy-Item $csvPath $snapPath -Force
            $snapshotPaths += $snapPath
            $lastSnapshot = Get-Date
        }
        Start-Sleep -Seconds $SamplerIntervalS
    }

    (Invoke-WebRequest -Uri "http://127.0.0.1:$LegPort/metrics" -UseBasicParsing -TimeoutSec 10).Content |
        Out-File -FilePath (Join-Path $legDir 'metrics-after.txt') -Encoding utf8
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

    [void](Write-LongrunEvidence -OutDir $legDir -ScenarioId 'S12-L02' -Variant $Name `
        -DurationSeconds $LegSeconds -SamplerIntervalSeconds $SamplerIntervalS `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $ServerFlags `
        -WorkingsetThresholdPct $WorkingsetThresholdPct `
        -HandleThresholdPct $HandleThresholdPct `
        -LatencyDriftThresholdPct $LatencyDriftThresholdPct `
        -ResourceSamplesPath $csvPath -PartialSnapshotPaths $snapshotPaths `
        -Verdict PASS -Notes "L02 paired comparison leg mode=$Mode requests=$rowCount live_samples=$liveCount")

    return [ordered]@{
        name = $Name
        mode = $Mode
        port = $LegPort
        duration_seconds = $LegSeconds
        request_count = $rowCount
        live_samples = $liveCount
        cache_n_sum = $cacheNSum
        flags = $ServerFlags
        out_dir = $legDir
        metrics = Get-LegMetrics -LegDir $legDir
    }
}

$legacyBase = @('--cache-mode','legacy','--parallel','1','--cache-ram','100',
                '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
$legacyBase = Merge-MtpJinjaFlag -Flags $legacyBase -JinjaPath $jinjaPath
$legacyFilterNames = @('--cache-mode','--cache-cold-max-mib','--cache-cold-path','--cache-prompt-evidence','--cache-prompt-evidence-dir')
$legacyStage17Flags = New-Object System.Collections.Generic.List[string]
$legacyRemovedFlags = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $stage17Flags.Count; $i++) {
    $flag = $stage17Flags[$i]
    if ($legacyFilterNames -contains $flag) {
        [void]$legacyRemovedFlags.Add($flag)
        if (($i + 1) -lt $stage17Flags.Count -and $stage17Flags[$i + 1] -notlike '--*') {
            [void]$legacyRemovedFlags.Add($stage17Flags[$i + 1])
            $i++
        }
    } else {
        [void]$legacyStage17Flags.Add($flag)
    }
}
$legacyFlagsList = New-Object System.Collections.Generic.List[string]
foreach ($flag in $legacyBase) { [void]$legacyFlagsList.Add($flag) }
foreach ($flag in $legacyStage17Flags) { [void]$legacyFlagsList.Add($flag) }
$legacyFlags = $legacyFlagsList.ToArray()
($stage17Flags -join ' ') | Out-File -FilePath (Join-Path $OutDir 'stage17-flags.txt') -Encoding utf8
($legacyStage17Flags.ToArray() -join ' ') | Out-File -FilePath (Join-Path $OutDir 'legacy-stage17-kept.txt') -Encoding utf8
($legacyRemovedFlags.ToArray() -join ' ') | Out-File -FilePath (Join-Path $OutDir 'legacy-stage17-removed.txt') -Encoding utf8

$comparison = [ordered]@{
    scenario = 'S12-L02'
    contract = 'Stage 23 legacy comparison'
    total_duration_seconds = $totalSeconds
    plan = [ordered]@{
        legacy_control_seconds = $legacySeconds
        hybrid_stage23_seconds = $hybridSeconds
        sampler_interval_seconds = $SamplerIntervalS
    }
    legacy_filtered_stage23_args = $legacyRemovedFlags.ToArray()
    legacy_filter_reason = 'legacy mode cannot use hybrid cold path, cold max, or prompt-evidence flags; hybrid leg keeps those Stage 23 flags'
    legs = @()
    status = 'PENDING'
}

$comparison.legs += Invoke-L02Leg -Name 'legacy-control' -Mode 'legacy' -ServerFlags $legacyFlags -LegPort $Port -LegSeconds $legacySeconds
$comparison.legs += Invoke-L02Leg -Name 'hybrid-stage23' -Mode 'hybrid' -ServerFlags $flags -LegPort ($Port + 1) -LegSeconds $hybridSeconds

$legacy = $comparison.legs[0]
$hybrid = $comparison.legs[1]

function Get-ComparedMetricValue {
    param([object] $Leg, [string] $MetricName, [string] $Field)
    $metrics = $Leg['metrics']
    if ($null -eq $metrics -or -not $metrics.Contains($MetricName)) { return $null }
    return $metrics[$MetricName][$Field]
}

$comparison.delta = [ordered]@{
    request_count = $hybrid['request_count'] - $legacy['request_count']
    cache_n_sum = $hybrid['cache_n_sum'] - $legacy['cache_n_sum']
    cache_hit_delta = (Get-ComparedMetricValue -Leg $hybrid -MetricName 'llamacpp_cache_hits_total' -Field 'delta') - (Get-ComparedMetricValue -Leg $legacy -MetricName 'llamacpp_cache_hits_total' -Field 'delta')
    cache_miss_delta = (Get-ComparedMetricValue -Leg $hybrid -MetricName 'llamacpp_cache_misses_total' -Field 'delta') - (Get-ComparedMetricValue -Leg $legacy -MetricName 'llamacpp_cache_misses_total' -Field 'delta')
    prompt_evidence_record_delta = (Get-ComparedMetricValue -Leg $hybrid -MetricName 'cache_prompt_evidence_records_total' -Field 'delta') - (Get-ComparedMetricValue -Leg $legacy -MetricName 'cache_prompt_evidence_records_total' -Field 'delta')
    cold_bytes_after_delta = (Get-ComparedMetricValue -Leg $hybrid -MetricName 'cache_cold_bytes' -Field 'after') - (Get-ComparedMetricValue -Leg $legacy -MetricName 'cache_cold_bytes' -Field 'after')
}
$comparison.status = if ($legacy['request_count'] -gt 0 -and $hybrid['request_count'] -gt 0) { 'PASS' } else { 'BLOCKED-runner-contract' }
$comparison | ConvertTo-Json -Depth 8 | Out-File -FilePath (Join-Path $OutDir 'l02-comparison.json') -Encoding utf8

Copy-Item -LiteralPath (Join-Path $hybrid['out_dir'] 'server.out.log') -Destination (Join-Path $OutDir 'server.out.log') -Force
Copy-Item -LiteralPath (Join-Path $hybrid['out_dir'] 'server.err.log') -Destination (Join-Path $OutDir 'server.err.log') -Force
Copy-Item -LiteralPath (Join-Path $hybrid['out_dir'] 'metrics-before.txt') -Destination (Join-Path $OutDir 'metrics-before.txt') -Force
Copy-Item -LiteralPath (Join-Path $hybrid['out_dir'] 'metrics-after.txt') -Destination (Join-Path $OutDir 'metrics-after.txt') -Force
Copy-Item -LiteralPath (Join-Path $hybrid['out_dir'] 'resource-samples.csv') -Destination (Join-Path $OutDir 'resource-samples.csv') -Force

$summaryNotes = "Paired comparison complete; $legPlan; legacy filtered Stage 23 hybrid-only args: $($legacyRemovedFlags.ToArray() -join ' ')"
Write-LongrunEvidence -OutDir $OutDir -ScenarioId 'S12-L02' -Variant 'legacy-comparison' `
    -DurationSeconds $totalSeconds -SamplerIntervalSeconds $SamplerIntervalS `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $flags `
    -WorkingsetThresholdPct $WorkingsetThresholdPct `
    -HandleThresholdPct $HandleThresholdPct `
    -LatencyDriftThresholdPct $LatencyDriftThresholdPct `
    -ResourceSamplesPath (Join-Path $OutDir 'resource-samples.csv') `
    -PartialSnapshotPaths @((Join-Path $OutDir 'l02-comparison.json')) `
    -Verdict $comparison.status -Notes $summaryNotes

if ($comparison.status -ne 'PASS') { exit 1 }
