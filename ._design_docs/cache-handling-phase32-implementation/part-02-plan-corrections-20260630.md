# Stage 32 implementation-plan corrections 2026-06-30

Status: ready for implementation-plan re-review
Owner: Developer
Scope: F32-PLAN-01 and F32-PLAN-02 only

## Findings addressed

This part corrects the blocking findings from
`part-01-implementation-plan-review-20260630.md`.

- F32-PLAN-01: stale-binary proof compares binaries against concrete Stage 31
  source timestamps.
- F32-PLAN-02: post-processing has fixed paths, accepted regex/schema rules,
  and an evidence-only extractor that runs from the Stage 32 run root.

No product code, test script, or comparison-run behavior changes are part of
this correction.

## F32-PLAN-01 stale-binary proof

Stage 31 implementation evidence names these source surfaces:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-context.cpp`
- `tools/server/server-context.h`
- `tests/test-cache-controller.cpp`

Run after the clean Release build. It writes JSON and text proof under
`D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01\stage32-proof`
and exits non-zero on stale binaries.

```powershell
$repo = 'D:\source\llama.cpp-jet'
$runRoot = 'D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01'
$proofDir = Join-Path $runRoot 'stage32-proof'
New-Item -ItemType Directory -Force -Path $proofDir | Out-Null

$serverBin = Join-Path $repo 'build-cuda\bin\Release\llama-server.exe'
$controllerBin = Join-Path $repo 'build-cuda\bin\Release\test-cache-controller.exe'
$sources = @(
    'tools/server/server-cache-hybrid.cpp',
    'tools/server/server-cache-hybrid.h',
    'tools/server/server-context.cpp',
    'tools/server/server-context.h',
    'tests/test-cache-controller.cpp'
) | ForEach-Object { Join-Path $repo $_ }

$sourceRows = $sources | ForEach-Object {
    $item = Get-Item -LiteralPath $_
    [pscustomobject]@{
        path = $item.FullName
        kind = if ($item.FullName -like '*\tests\test-cache-controller.cpp') { 'controller-test' } else { 'server-production' }
        last_write_time_utc = $item.LastWriteTimeUtc.ToString('o')
        length = $item.Length
    }
}

$server = Get-Item -LiteralPath $serverBin
$controller = Get-Item -LiteralPath $controllerBin
$newestProduction = $sourceRows | Where-Object kind -eq 'server-production' | Sort-Object last_write_time_utc -Descending | Select-Object -First 1
$controllerSource = $sourceRows | Where-Object kind -eq 'controller-test' | Select-Object -First 1
$serverPass = $server.LastWriteTimeUtc -gt ([datetime]$newestProduction.last_write_time_utc)
$controllerPass = $controller.LastWriteTimeUtc -gt ([datetime]$controllerSource.last_write_time_utc)
$status = if ($serverPass -and $controllerPass) { 'PASS' } else { 'BLOCKED-stale-binary' }

$proof = [pscustomobject]@{
    status = $status
    git_head = (& git -C $repo rev-parse HEAD).Trim()
    git_status_short = @(& git -C $repo status --short)
    server_binary = [pscustomobject]@{
        path = $server.FullName
        last_write_time_utc = $server.LastWriteTimeUtc.ToString('o')
        length = $server.Length
        newer_than_newest_stage31_production_source = $serverPass
    }
    controller_binary = [pscustomobject]@{
        path = $controller.FullName
        last_write_time_utc = $controller.LastWriteTimeUtc.ToString('o')
        length = $controller.Length
        newer_than_stage31_controller_test_source = $controllerPass
    }
    newest_stage31_production_source = $newestProduction
    stage31_sources = $sourceRows
}

$proof | ConvertTo-Json -Depth 6 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'stale-binary-proof.json')
$proof | Format-List * | Out-String | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'stale-binary-proof.txt')
$proof.status
if ($proof.status -ne 'PASS') { exit 2 }
```

Accepted output: `status=PASS`,
`server_binary.newer_than_newest_stage31_production_source=true`, and
`controller_binary.newer_than_stage31_controller_test_source=true`.

## F32-PLAN-02 fixed evidence paths

Capture setup and focused-test logs here:

```powershell
$repo = 'D:\source\llama.cpp-jet'
$runRoot = 'D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01'
$proofDir = Join-Path $runRoot 'stage32-proof'
New-Item -ItemType Directory -Force -Path $proofDir | Out-Null

cmake -B "$repo\build-cuda" -S $repo -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON 2>&1 |
    Tee-Object -FilePath (Join-Path $proofDir 'build-configure.log')
cmake --build "$repo\build-cuda" --config Release --target llama-server test-cache-controller -j 4 2>&1 |
    Tee-Object -FilePath (Join-Path $proofDir 'build-llama-server-test-cache-controller.log')
& "$repo\build-cuda\bin\Release\test-cache-controller.exe" 2>&1 |
    Tee-Object -FilePath (Join-Path $proofDir 'test-cache-controller.stdout.log')
ctest --test-dir "$repo\build-cuda" -C Release -R cache -V 2>&1 |
    Tee-Object -FilePath (Join-Path $proofDir 'ctest-cache.stdout.log')
Select-String -Path "$repo\build-cuda\CMakeCache.txt" -Pattern '^GGML_CUDA:BOOL=ON$' |
    Tee-Object -FilePath (Join-Path $proofDir 'cuda-proof.txt')
```

Run this evidence-only extractor after the comparison exits or is stopped at the
approved wall-clock limit. It reads driver artifacts and writes derived JSON
only under `stage32-proof`.

```powershell
$runRoot = 'D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01'
$coldPath = 'D:\tmp\cache-cold-stage32-20260630-01'
$proofDir = Join-Path $runRoot 'stage32-proof'
New-Item -ItemType Directory -Force -Path $proofDir | Out-Null

$reqFiles = Get-ChildItem -LiteralPath $runRoot -Recurse -Filter requests.jsonl
$metricFiles = Get-ChildItem -LiteralPath $runRoot -Recurse -Filter metrics-after.txt
$hybridReqFiles = $reqFiles | Where-Object FullName -match '\\hybrid\\requests\.jsonl$'
$legacyMetricFiles = $metricFiles | Where-Object FullName -match '\\legacy\\metrics-after\.txt$'
$hybridMetricFiles = $metricFiles | Where-Object FullName -match '\\hybrid\\metrics-after\.txt$'
$requests = foreach ($file in $hybridReqFiles) {
    Get-Content -LiteralPath $file.FullName | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json }
}

$requests | Group-Object cache_class | ForEach-Object {
    $rows = @($_.Group)
    [pscustomobject]@{
        cache_class = $_.Name
        count = $rows.Count
        cache_hit_true = @($rows | Where-Object cache_hit -eq $true).Count
        cache_n_gt_zero = @($rows | Where-Object { [double]$_.cache_n -gt 0 }).Count
        cache_n_max = if ($rows.Count) { ($rows | Measure-Object cache_n -Maximum).Maximum } else { $null }
    }
} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'cache-reuse-by-class.json')

$latencies = @($requests | Where-Object { $_.prompt_ms -ne $null } | ForEach-Object { [double]$_.prompt_ms } | Sort-Object)
function Get-Pct([double[]]$Values, [double]$Pct) {
    if (-not $Values -or $Values.Count -eq 0) { return $null }
    $i = [math]::Ceiling(($Pct / 100.0) * $Values.Count) - 1
    if ($i -lt 0) { $i = 0 }
    if ($i -ge $Values.Count) { $i = $Values.Count - 1 }
    return $Values[$i]
}
[pscustomobject]@{
    source_field = 'prompt_ms'
    sample_count = $latencies.Count
    p50_ms = Get-Pct $latencies 50
    p99_ms = Get-Pct $latencies 99
} | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'request-latency-p50-p99.json')

$summaryPath = Join-Path $runRoot 'summary.json'
if (Test-Path $summaryPath) {
    (Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json).rows |
        Where-Object mode -eq 'hybrid' |
        Select-Object cycle,phase,mode,hit_delta,miss_delta,status,cache_class_counts |
        ConvertTo-Json -Depth 8 |
        Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'hybrid-hit-deltas.json')
}

$metricLines = foreach ($file in $hybridMetricFiles) {
    Get-Content -LiteralPath $file.FullName | ForEach-Object { [pscustomobject]@{ source_file = $file.FullName; line = $_ } }
}
$namespaceRows = foreach ($m in $metricLines) {
    if ($m.line -match '^llamacpp:cache_namespace_count\{mode="hybrid"\}\s+([0-9.]+)') {
        [pscustomobject]@{ metric = 'llamacpp:cache_namespace_count'; accepted_form = 'count'; value = [double]$Matches[1]; source_file = $m.source_file }
    }
    if ($m.line -match '^llamacpp:cache_namespace_(nodes|roots|metadata_bytes)\{mode="hybrid",scope="all"\}\s+([0-9.]+)') {
        [pscustomobject]@{ metric = "llamacpp:cache_namespace_$($Matches[1])"; accepted_form = 'aggregate-scope-all'; value = [double]$Matches[2]; source_file = $m.source_file }
    }
}
$namespaceRows | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'namespace-metric-forms.json')

$labelFindings = foreach ($m in $metricLines) {
    if ($m.line -match '^#' -or $m.line -notmatch '^llamacpp:cache') { continue }
    if ($m.line -match '\{([^}]*)\}') {
        $labels = $Matches[1]
        $badName = $labels -match '(^|,)\s*(namespace|namespace_id|prompt_hash|request_id|prompt|path|file|cache_key)\s*='
        $badValue = $labels -match '([A-Fa-f0-9]{32,}|[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}|[A-Za-z]:\\|/[^",]+|messages|content|role|user|assistant|system)'
        if ($badName -or $badValue) { [pscustomobject]@{ source_file = $m.source_file; line = $m.line; bad_label_name = $badName; bad_label_value = $badValue } }
    }
}
@($labelFindings) | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'bounded-label-scan.json')

$metricLines | Where-Object { $_.line -match '^#\s+(HELP|TYPE)\s+(llamacpp:cache[^\s]+)\s+' } |
    ForEach-Object { [pscustomobject]@{ kind = $Matches[1]; metric = $Matches[2] } } |
    Group-Object kind,metric | ForEach-Object { [pscustomobject]@{ kind = $_.Group[0].kind; metric = $_.Group[0].metric; count = $_.Count; duplicate = ($_.Count -gt 1) } } |
    ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'help-type-counts.json')

function Get-MaxCacheBytes($Files) {
    $values = foreach ($file in $Files) {
        Get-Content -LiteralPath $file.FullName | ForEach-Object {
            if ($_ -match '^llamacpp:cache_bytes(?:\{[^}]*\})?\s+([0-9.]+)') { [double]$Matches[1] }
        }
    }
    if (@($values).Count -eq 0) { return $null }
    return ($values | Measure-Object -Maximum).Maximum
}
$legacyBytes = Get-MaxCacheBytes $legacyMetricFiles
$hybridBytes = Get-MaxCacheBytes $hybridMetricFiles
[pscustomobject]@{
    metric = 'llamacpp:cache_bytes'
    legacy_max = $legacyBytes
    hybrid_max = $hybridBytes
    reduction_percent = if ($legacyBytes -and $hybridBytes -ne $null) { [math]::Round((($legacyBytes - $hybridBytes) / $legacyBytes) * 100, 2) } else { $null }
} | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'hot-ram-cache-bytes.json')

$coldFiles = if (Test-Path $coldPath) { @(Get-ChildItem -LiteralPath $coldPath -Recurse -File) } else { @() }
[pscustomobject]@{
    cold_path = $coldPath
    file_count = $coldFiles.Count
    total_bytes = ($coldFiles | Measure-Object Length -Sum).Sum
    payload_like_file_count = @($coldFiles | Where-Object { $_.Length -gt 0 }).Count
} | ConvertTo-Json -Depth 4 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'cold-store-size-count.json')

$failureCounters = foreach ($m in $metricLines) {
    if ($m.line -match '^(llamacpp:cache_[^\s{]*(fail|error)[^\s{]*)(?:\{[^}]*\})?\s+([0-9.]+)') {
        [pscustomobject]@{ metric = $Matches[1]; value = [double]$Matches[3]; source_file = $m.source_file; line = $m.line }
    }
}
@($failureCounters) | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'cold-failure-counters.json')

$serverErrors = foreach ($log in Get-ChildItem -LiteralPath $runRoot -Recurse -Include server.err.log,main.stdout.log -File) {
    Select-String -LiteralPath $log.FullName -Pattern 'crash|seh|exception|fatal|error|failed|traceback' -CaseSensitive:$false |
        ForEach-Object { [pscustomobject]@{ source_file = $log.FullName; line_number = $_.LineNumber; line = $_.Line } }
}
@($serverErrors) | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'server-error-scan.json')

$listener = $null
$portFree = $false
try {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse('127.0.0.1'), 8900)
    $listener.Start()
    $portFree = $true
} catch {
    $portFree = $false
} finally {
    if ($listener) { $listener.Stop() }
}
$serverProcesses = @(Get-Process | Where-Object { $_.ProcessName -eq 'llama-server' })
$nvidiaSmi = & nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null
[pscustomobject]@{
    port = 8900
    port_free = $portFree
    llama_server_process_count = $serverProcesses.Count
    llama_server_process_ids = @($serverProcesses | Select-Object -ExpandProperty Id)
    nvidia_smi_memory_used_mib = @($nvidiaSmi)
    cold_path_file_count = $coldFiles.Count
    cold_path_total_bytes = ($coldFiles | Measure-Object Length -Sum).Sum
} | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $proofDir 'cleanup-proof.json')
```

Accepted schema and regex rules:

- `cache-reuse-by-class.json`: grouped by `cache_class`; PASS needs non-zero
  `cache_hit_true` or `cache_n_gt_zero` on exact-repeat hybrid rows.
- `hybrid-hit-deltas.json`: PASS needs at least one completed hybrid row with
  `hit_delta > 0`.
- `namespace-metric-forms.json`: count form is exactly
  `llamacpp:cache_namespace_count{mode="hybrid"}`. Aggregate node/root/metadata
  byte metrics may use `scope="all"`. PASS needs count `<= 4` or a documented
  compatibility split.
- `bounded-label-scan.json`: empty array means PASS. Label-name regex is
  `namespace|namespace_id|prompt_hash|request_id|prompt|path|file|cache_key`;
  value regex flags 32+ hex strings, UUIDs, Windows or POSIX paths, and prompt
  or message words.
- `help-type-counts.json`: grouped by `kind,metric`; PASS needs every
  `duplicate=false`.
- `request-latency-p50-p99.json`: uses `prompt_ms`; `sample_count=0` means
  p50/p99 unavailable, not inferred.
- `cold-store-size-count.json`: PASS needs non-zero bytes and file count when
  demotion occurs.
- `cold-failure-counters.json`: PASS needs no counter value above zero.
- `hot-ram-cache-bytes.json`: PASS target is `reduction_percent >= 40`.
- `server-error-scan.json`: empty array means no crash/error evidence found.
- `cleanup-proof.json`: PASS needs `port_free=true`,
  `llama_server_process_count=0`, and final cold-path size/count recorded.
