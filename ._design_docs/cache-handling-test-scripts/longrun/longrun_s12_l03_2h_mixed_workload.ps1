#requires -Version 5
# longrun_s12_l03_2h_mixed_workload.ps1
# Stage 12/23 long-run: S12-L03 mixed workload.
# Duration is one row cap. The runner splits it across four prompt classes and
# writes a row-owned mixed-workload artifact.

param(
    [string] $BuildDir         = '',
    [string] $ModelPath        = '',
    [string] $OutDir           = '',
    [int]    $Port             = 8403,
    [int]    $DurationHours    = 2,
    [int]    $DurationMin      = 0,
    [int]    $SamplerIntervalS = 60,
    [int]    $SnapshotEveryMin = 30,
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
. (Join-Path $libDir 'Get-Stage17ServerArgs.ps1')

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
    $OutDir = Join-Path $sourceRoot "._design_docs\.test_reports\longrun-s12-l03-$ts"
}
$serverExe = Join-Path $BuildDir 'bin\Release\llama-server.exe'

$stubData = -not (Test-Path $ModelPath)
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$baseFlags = @('--cache-mode','hybrid','--parallel','1','--cache-ram','100',
               '--metrics','--ctx-size','512','--temp','0','--seed',"$Seed")
$baseFlags = Merge-MtpJinjaFlag -Flags $baseFlags -JinjaPath $jinjaPath
$stage17Flags = Get-Stage17ServerArgsFromBase64 -Encoded $Stage17ServerArgsBase64
$flags = $baseFlags + $stage17Flags

$totalSeconds = (($DurationHours * 60) + $DurationMin) * 60
if ($totalSeconds -le 0) { $totalSeconds = 2 * 3600 }

$profiles = @(
    [ordered]@{ name = 'exact-cache-prompt'; weight = 30; cache_prompt = $true;  prompt = 'S12-L03 exact cache prompt anchor'; unique = $false; n_predict = 2 },
    [ordered]@{ name = 'checkpoint-dependent'; weight = 30; cache_prompt = $true;  prompt = 'S12-L03 checkpoint dependent mixed workload anchor'; unique = $false; n_predict = 3 },
    [ordered]@{ name = 'near-non-exact'; weight = 20; cache_prompt = $true;  prompt = 'S12-L03 near non exact mixed workload anchor'; unique = $true;  n_predict = 2 },
    [ordered]@{ name = 'new-uncached'; weight = 20; cache_prompt = $false; prompt = 'S12-L03 new uncached mixed workload anchor'; unique = $true;  n_predict = 2 }
)

function Get-L03ProfileAllocations {
    param([int] $RowSeconds, [object[]] $ProfileList)
    $allocations = New-Object System.Collections.Generic.List[object]
    $used = 0
    for ($idx = 0; $idx -lt $ProfileList.Count; $idx++) {
        $profile = $ProfileList[$idx]
        if ($idx -eq ($ProfileList.Count - 1)) {
            $seconds = [Math]::Max(1, $RowSeconds - $used)
        } else {
            $seconds = [Math]::Max(1, [int][Math]::Floor($RowSeconds * ([int]$profile.weight) / 100))
            $used += $seconds
        }
        $allocations.Add([pscustomobject]@{
            name = $profile.name
            seconds = $seconds
            cache_prompt = [bool]$profile.cache_prompt
        }) | Out-Null
    }
    return $allocations.ToArray()
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

function Get-MetricsDelta {
    param([string] $BeforePath, [string] $AfterPath)
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
        $before = Get-MetricValue -Path $BeforePath -Name $name
        $after = Get-MetricValue -Path $AfterPath -Name $name
        $delta = if ($null -ne $before -and $null -ne $after) { $after - $before } else { $null }
        $result[$name] = [ordered]@{ before = $before; after = $after; delta = $delta }
    }
    return $result
}

function Get-FlagValue {
    param([string[]] $ServerFlags, [string] $Name)
    for ($idx = 0; $idx -lt $ServerFlags.Count; $idx++) {
        if ($ServerFlags[$idx] -eq $Name -and ($idx + 1) -lt $ServerFlags.Count) {
            return $ServerFlags[$idx + 1]
        }
    }
    return ''
}

function Get-PromptEvidenceStats {
    param([string[]] $ServerFlags)
    $evidenceDir = Get-FlagValue -ServerFlags $ServerFlags -Name '--cache-prompt-evidence-dir'
    $stats = [ordered]@{
        evidence_dir = $evidenceDir
        records = 0
        profiles = [ordered]@{}
        lookup_outcomes = [ordered]@{}
        token_span_checksums = [ordered]@{}
        lookup_paths = [ordered]@{}
        distinct_token_span_checksum_count = 0
        distinct_lookup_path_count = 0
    }
    if (-not $evidenceDir -or -not (Test-Path $evidenceDir)) { return $stats }
    $files = @(Get-ChildItem -LiteralPath $evidenceDir -Recurse -Filter 'cache-prompt-evidence.jsonl' -ErrorAction SilentlyContinue)
    foreach ($file in $files) {
        foreach ($line in Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue) {
            if (-not $line) { continue }
            try {
                $record = $line | ConvertFrom-Json
                $stats.records++
                $profile = if ($record.profile) { [string]$record.profile } else { '(missing)' }
                $outcome = if ($record.lookup_outcome) { [string]$record.lookup_outcome } else { '(missing)' }
                $checksum = if ($record.token_span_checksum) { [string]$record.token_span_checksum } else { '(missing)' }
                if (-not $stats.profiles.Contains($profile)) { $stats.profiles[$profile] = 0 }
                if (-not $stats.lookup_outcomes.Contains($outcome)) { $stats.lookup_outcomes[$outcome] = 0 }
                if (-not $stats.token_span_checksums.Contains($checksum)) { $stats.token_span_checksums[$checksum] = 0 }
                $lookupPath = "$outcome/$checksum"
                if (-not $stats.lookup_paths.Contains($lookupPath)) { $stats.lookup_paths[$lookupPath] = 0 }
                $stats.profiles[$profile]++
                $stats.lookup_outcomes[$outcome]++
                $stats.token_span_checksums[$checksum]++
                $stats.lookup_paths[$lookupPath]++
            } catch {}
        }
    }
    $stats.distinct_token_span_checksum_count = $stats.token_span_checksums.Count
    $stats.distinct_lookup_path_count = $stats.lookup_paths.Count
    return $stats
}

$allocations = Get-L03ProfileAllocations -RowSeconds $totalSeconds -ProfileList $profiles
$allocationText = ($allocations | ForEach-Object { "$($_.name)=$($_.seconds)s" }) -join ','

Write-Host "S12-L03 mixed workload longrun; stub=$stubData"
Write-Host "Plan: rowCapSeconds=$totalSeconds profiles=$allocationText"

if ($DryRun) {
    foreach ($allocation in $allocations) {
        Write-Host "DRY-RUN: would run profile $($allocation.name) for $($allocation.seconds) sec cache_prompt=$($allocation.cache_prompt)"
    }
    Write-Host "DRY-RUN: artifact l03-mixed-workload.json; evidence-summary result PASS when all profiles make requests"
    exit 0
}

$snapshotEvery = $SnapshotEveryMin * 60

if ($stubData) {
    "elapsed_s,workingset_bytes,handle_count,server_live" |
        Out-File -FilePath (Join-Path $OutDir 'resource-samples.csv') -Encoding utf8
    $artifact = [ordered]@{
        scenario = 'S12-L03'
        contract = 'Stage 23 mixed workload longrun'
        total_duration_seconds = $totalSeconds
        plan = $allocations
        status = 'BLOCKED'
        notes = "Model fixture not found at $ModelPath"
    }
    $artifact | ConvertTo-Json -Depth 8 | Out-File -FilePath (Join-Path $OutDir 'l03-mixed-workload.json') -Encoding utf8
    Write-LongrunEvidence -OutDir $OutDir -ScenarioId 'S12-L03' -Variant 'mixed-workload' `
        -DurationSeconds $totalSeconds -SamplerIntervalSeconds $SamplerIntervalS `
        -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
        -ServerFlags $flags `
        -WorkingsetThresholdPct $WorkingsetThresholdPct `
        -HandleThresholdPct $HandleThresholdPct `
        -LatencyDriftThresholdPct $LatencyDriftThresholdPct `
        -ResourceSamplesPath (Join-Path $OutDir 'resource-samples.csv') `
        -PartialSnapshotPaths @((Join-Path $OutDir 'l03-mixed-workload.json')) -StubData -Verdict BLOCKED `
        -Notes "Model fixture not found at $ModelPath"
    exit 0
}

($stage17Flags -join ' ') | Out-File -FilePath (Join-Path $OutDir 'stage17-flags.txt') -Encoding utf8
($flags -join ' ') | Out-File -FilePath (Join-Path $OutDir 'server-flags.txt') -Encoding utf8

Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$proc = Start-Process -FilePath $serverExe `
    -ArgumentList ($flags + @('--model',$ModelPath,'--host','127.0.0.1',"--port","$Port")) `
    -RedirectStandardOutput (Join-Path $OutDir 'server.out.log') `
    -RedirectStandardError  (Join-Path $OutDir 'server.err.log') `
    -NoNewWindow -PassThru

$ready = $false
$deadline = (Get-Date).AddSeconds($ServerStartupTimeoutS)
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 4
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    [Console]::Error.WriteLine("Server did not start")
    exit 1
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8

$csvPath = Join-Path $OutDir 'resource-samples.csv'
$samplesPath = Join-Path $OutDir 'request-samples.jsonl'
"elapsed_s,workingset_bytes,handle_count,server_live,profile" | Out-File -FilePath $csvPath -Encoding utf8

$runStart = Get-Date
$lastSnapshot = $runStart
$snapshotPaths = @()
$requestCount = 0
$cacheNSum = 0
$liveCount = 0
$profileCounts = [ordered]@{}
foreach ($profile in $profiles) { $profileCounts[$profile.name] = 0 }
$statusCounts = [ordered]@{}

foreach ($allocation in $allocations) {
    $profile = $profiles | Where-Object { $_.name -eq $allocation.name } | Select-Object -First 1
    $profileEnd = (Get-Date).AddSeconds($allocation.seconds)
    $profileRequest = 0
    while ((Get-Date) -lt $profileEnd) {
        $prompt = $profile.prompt
        if ([bool]$profile.unique) {
            $prompt = "$prompt request-$profileRequest elapsed-$([int]((Get-Date) - $runStart).TotalSeconds)"
        }
        $bodyObject = [ordered]@{
            prompt = $prompt
            n_predict = [int]$profile.n_predict
            temperature = 0
            seed = $Seed
            cache_prompt = [bool]$profile.cache_prompt
        }
        $body = $bodyObject | ConvertTo-Json -Compress
        $live = 'true'
        try {
            $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
                -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 30
            $json = $resp.Content | ConvertFrom-Json
            $cacheN = if ($json.timings) { [int]$json.timings.cache_n } else { 0 }
            $cacheNSum += $cacheN
            $requestCount++
            $profileRequest++
            $profileCounts[$profile.name]++
            $liveCount++
            $status = [string]$resp.StatusCode
            if (-not $statusCounts.Contains($status)) { $statusCounts[$status] = 0 }
            $statusCounts[$status]++
            ([ordered]@{
                elapsed_s = [int]((Get-Date) - $runStart).TotalSeconds
                status = [int]$resp.StatusCode
                cache_n = $cacheN
                profile = $profile.name
                cache_prompt = [bool]$profile.cache_prompt
            } | ConvertTo-Json -Compress) | Out-File -FilePath $samplesPath -Append -Encoding utf8
        } catch {
            $live = 'false'
            $status = 'request-error'
            if (-not $statusCounts.Contains($status)) { $statusCounts[$status] = 0 }
            $statusCounts[$status]++
            ([ordered]@{
                elapsed_s = [int]((Get-Date) - $runStart).TotalSeconds
                status = $status
                error = $_.Exception.Message
                profile = $profile.name
                cache_prompt = [bool]$profile.cache_prompt
            } | ConvertTo-Json -Compress) | Out-File -FilePath $samplesPath -Append -Encoding utf8
        }
        $pr = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
        if (-not $pr) { $live = 'crashed' }
        if ($pr) {
            "{0},{1},{2},{3},{4}" -f ([int]((Get-Date) - $runStart).TotalSeconds), $pr.WorkingSet64, $pr.HandleCount, $live, $profile.name |
                Out-File -FilePath $csvPath -Append -Encoding utf8
        }
        if (((Get-Date) - $lastSnapshot).TotalSeconds -ge $snapshotEvery) {
            $snapPath = Join-Path $OutDir ("snapshot-{0}m.csv" -f ([int]((Get-Date) - $runStart).TotalMinutes))
            Copy-Item $csvPath $snapPath -Force
            $snapshotPaths += $snapPath
            $lastSnapshot = Get-Date
        }
        Start-Sleep -Seconds $SamplerIntervalS
    }
}

(Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content |
    Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt') -Encoding utf8
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue

$metrics = Get-MetricsDelta -BeforePath (Join-Path $OutDir 'metrics-before.txt') -AfterPath (Join-Path $OutDir 'metrics-after.txt')
$promptEvidence = Get-PromptEvidenceStats -ServerFlags $flags
$profilesWithRequests = @($profileCounts.Keys | Where-Object { $profileCounts[$_] -gt 0 }).Count
$status = if ($requestCount -gt 0 -and $profilesWithRequests -eq $profiles.Count) { 'PASS' } else { 'BLOCKED-runner-contract' }

$artifact = [ordered]@{
    scenario = 'S12-L03'
    contract = 'Stage 23 mixed workload longrun'
    total_duration_seconds = $totalSeconds
    sampler_interval_seconds = $SamplerIntervalS
    plan = $allocations
    request_count = $requestCount
    live_samples = $liveCount
    cache_n_sum = $cacheNSum
    profile_counts = $profileCounts
    http_status_counts = $statusCounts
    flags = $flags
    metrics = $metrics
    prompt_evidence = $promptEvidence
    status = $status
}
$artifact | ConvertTo-Json -Depth 12 | Out-File -FilePath (Join-Path $OutDir 'l03-mixed-workload.json') -Encoding utf8

$summaryNotes = "Mixed workload complete; rowCapSeconds=$totalSeconds; allocations=$allocationText; requests=$requestCount; profilesWithRequests=$profilesWithRequests"
Write-LongrunEvidence -OutDir $OutDir -ScenarioId 'S12-L03' -Variant 'mixed-workload' `
    -DurationSeconds $totalSeconds -SamplerIntervalSeconds $SamplerIntervalS `
    -ModelFixture (Split-Path $ModelPath -Leaf) -BuildType 'Release' `
    -ServerFlags $flags `
    -WorkingsetThresholdPct $WorkingsetThresholdPct `
    -HandleThresholdPct $HandleThresholdPct `
    -LatencyDriftThresholdPct $LatencyDriftThresholdPct `
    -ResourceSamplesPath $csvPath `
    -PartialSnapshotPaths @((Join-Path $OutDir 'l03-mixed-workload.json')) `
    -Verdict $status -Notes $summaryNotes

if ($status -ne 'PASS') { exit 1 }
