#requires -Version 5

param(
    [string]   $RunId = '',
    [string[]] $RowsToRun = @('S02-chat', 'S03-chat'),
    [string]   $ModelPath = '',
    [string]   $RunRoot = '',
    [string]   $ReportPath = '',
    [string]   $CacheColdPath = 'D:\tmp\cache-cold-stage24',
    [int]      $BasePort = 8900,
    [int]      $LegDurationMin = 10,
    [int]      $ColdBudgetMiB = 512,
    [int]      $SmokeSeconds = 0,
    [string]   $CrashDumpDir = 'D:\tmp\crash-dumps',
    [string]   $LlamaServerPath = '',
    [int]      $ContextSize = 4096,
    [int]      $MaxTokens = 8,
    [int]      $Seed = 42,
    [int]      $DistinctPrefixes = 64,
    [int]      $ServerStartupTimeoutS = 300,
    [switch]   $DryRun
)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$SourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Route = '/v1/chat/completions'
$MetricNames = @(
    'llamacpp:cache_restore_misses_total',
    'llamacpp:cache_prefix_candidates_total',
    'llamacpp:cache_prompt_evidence_records_total',
    'llamacpp:cache_cold_bytes',
    'llamacpp:cache_cold_budget_bytes',
    'llamacpp:cache_cold_demotions_skipped_total',
    'llamacpp:cache_cold_evictions_total',
    'llamacpp:cache_checkpoint_admissions_by_shape_total',
    'llamacpp:cache_checkpoint_admissions_total',
    'llamacpp:cache_checkpoint_admission_failures_total'
)

function Get-NextRunSuffix {
    $date = Get-Date -Format 'yyyyMMdd'
    $reportDir = Join-Path $SourceRoot '._design_docs\.test_reports'
    $max = 0
    if (Test-Path $reportDir) {
        foreach ($file in Get-ChildItem -LiteralPath $reportDir -Filter "test-report-$date-*.md" -File -ErrorAction SilentlyContinue) {
            $match = [regex]::Match($file.Name, "^test-report-$date-(\d{2})\.md$")
            if ($match.Success) { $max = [Math]::Max($max, [int]$match.Groups[1].Value) }
        }
    }
    return [ordered]@{ date = $date; suffix = ('{0:d2}' -f ($max + 1)) }
}

function Resolve-Stage24Path {
    param([string] $PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return $PathValue }
    return [System.IO.Path]::GetFullPath((Join-Path $SourceRoot $PathValue))
}

function Assert-WhitelistedReportPath {
    param([string] $PathValue)
    $reportDir = [System.IO.Path]::GetFullPath((Join-Path $SourceRoot '._design_docs\.test_reports'))
    $parent = [System.IO.Path]::GetFullPath((Split-Path -Parent $PathValue))
    $name = [System.IO.Path]::GetFileName($PathValue)
    if ($parent.TrimEnd('\') -ne $reportDir.TrimEnd('\') -or $name -notmatch '^test-report-\d{8}-\d{2}\.md$') {
        throw "Invalid ReportPath '$PathValue'. Use ._design_docs\.test_reports\test-report-YYYYMMDD-NN.md with a two-digit suffix."
    }
}

function Write-JsonFile {
    param([string] $Path, [object] $Value, [int] $Depth = 12)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, ((ConvertTo-JsonSafeValue -Value $Value -Depth $Depth) | ConvertTo-Json -Depth $Depth), $Utf8NoBom)
}

function Write-TextFile {
    param([string] $Path, [string] $Text)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Add-Count {
    param([hashtable] $Map, [string] $Key)
    if (-not $Map.ContainsKey($Key)) { $Map[$Key] = 0 }
    $Map[$Key]++
}

function ConvertTo-JsonSafeValue {
    param([object] $Value, [int] $Depth = 12)
    if ($null -eq $Value) { return $null }
    if ($Depth -le 0) { return [string]$Value }
    if ($Value -is [string] -or $Value -is [char]) { return [string]$Value }
    if ($Value -is [bool]) { return [bool]$Value }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $copy[[string]$key] = ConvertTo-JsonSafeValue -Value $Value[$key] -Depth ($Depth - 1)
        }
        return $copy
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $Value) {
            [void]$items.Add((ConvertTo-JsonSafeValue -Value $item -Depth ($Depth - 1)))
        }
        return $items.ToArray()
    }
    $objectCopy = [ordered]@{}
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.MemberType -match 'Property' -and $property.IsGettable) {
            $objectCopy[$property.Name] = ConvertTo-JsonSafeValue -Value $property.Value -Depth ($Depth - 1)
        }
    }
    return $objectCopy
}

function Normalize-RowsToRun {
    param([string[]] $Rows)
    $normalized = New-Object System.Collections.Generic.List[string]
    foreach ($row in $Rows) {
        foreach ($part in ([string]$row -split ',')) {
            $trimmed = $part.Trim()
            if ($trimmed) { [void]$normalized.Add($trimmed) }
        }
    }
    if ($normalized.Count -eq 0) { throw 'RowsToRun must include at least one Stage 24 row.' }
    return $normalized.ToArray()
}

function Get-StableHash {
    param([string] $Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 16).ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-DirectoryBytes {
    param([string] $Path)
    if (-not $Path -or -not (Test-Path $Path)) { return 0L }
    $sum = 0L
    foreach ($file in Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue) {
        $sum += [int64]$file.Length
    }
    return $sum
}

function Test-PortFree {
    param([int] $Port)
    $listener = $null
    try {
        $listener = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Parse('127.0.0.1')), $Port
        $listener.Start()
        return $true
    } catch {
        return $false
    } finally {
        if ($listener) { $listener.Stop() }
    }
}

function Get-BuildRootFromServerPath {
    $serverFile = Get-Item -LiteralPath $LlamaServerPath -ErrorAction SilentlyContinue
    if (-not $serverFile) { return $null }
    $dir = $serverFile.Directory
    if ($dir -and $dir.Name -eq 'Release') { $dir = $dir.Parent }
    if ($dir -and $dir.Name -eq 'bin') { $dir = $dir.Parent }
    if ($dir) { return $dir.FullName }
    return $null
}

function Get-CudaBuildProof {
    $buildRoot = Get-BuildRootFromServerPath
    $cachePath = if ($buildRoot) { Join-Path $buildRoot 'CMakeCache.txt' } else { $null }
    $cacheValue = $null
    $state = 'BLOCKED-cuda-configure-missing'
    if ($cachePath -and (Test-Path $cachePath)) {
        $line = Get-Content -LiteralPath $cachePath -ErrorAction SilentlyContinue |
            Where-Object { $_ -match '^GGML_CUDA:BOOL=' } |
            Select-Object -First 1
        if ($line) {
            $cacheValue = $line
            if ($line -eq 'GGML_CUDA:BOOL=ON') { $state = 'PASS' }
        }
    }
    return [ordered]@{
        state = $state
        build_root = $buildRoot
        cmake_cache = $cachePath
        required = 'GGML_CUDA:BOOL=ON'
        observed = $cacheValue
    }
}

function Get-CudaRuntimeProof {
    param([string[]] $Paths)
    $proofMatches = New-Object System.Collections.Generic.List[object]
    foreach ($path in $Paths) {
        if (-not $path -or -not (Test-Path $path)) { continue }
        $lineNo = 0
        foreach ($line in Get-Content -LiteralPath $path -ErrorAction SilentlyContinue) {
            $lineNo++
            if ($line -match 'CUDA[0-9]\s+:\s+NVIDIA|NVIDIA .*CUDA|system_info:.*CUDA|ggml_cuda|CUDA backend|CUDA :') {
                $proofMatches.Add([ordered]@{ path = $path; line = $lineNo; text = $line }) | Out-Null
            }
        }
    }
    return [ordered]@{
        state = if ($proofMatches.Count -gt 0) { 'PASS' } else { 'BLOCKED-cuda-runtime-missing' }
        required = 'server startup log contains CUDA/NVIDIA GPU proof'
        matches = $proofMatches.ToArray()
    }
}

function Wait-CudaRuntimeProof {
    param([string[]] $Paths, [int] $TimeoutSeconds = 20)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $proof = Get-CudaRuntimeProof -Paths $Paths
        if ($proof.state -eq 'PASS') { return $proof }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    return Get-CudaRuntimeProof -Paths $Paths
}

function Wait-PortFree {
    param([int] $Port, [int] $TimeoutSeconds = 30)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if (Test-PortFree -Port $Port) { return $true }
        Start-Sleep -Milliseconds 500
    }
    return $false
}

function Complete-LegCleanup {
    param([object] $Process, [int] $Port)
    $ownedProcessStopped = $true
    $processId = $null
    $exitCode = $null
    $exitCodeHex = 'alive_or_unknown'
    $exitWasForced = $false
    if ($Process) {
        $processId = $Process.Id
        try {
            if ($Process.HasExited) {
                $exitCode = $Process.ExitCode
                $exitCodeHex = '0x{0:X8}' -f [uint32]$exitCode
            } else {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
                Wait-Process -Id $Process.Id -Timeout 30 -ErrorAction SilentlyContinue
                if ($Process.HasExited) {
                    $exitCode = $Process.ExitCode
                    $exitCodeHex = '0x{0:X8} (forced)' -f [uint32]$exitCode
                    $exitWasForced = $true
                }
            }
            $ownedProcessStopped = $Process.HasExited
        } catch {
            $ownedProcessStopped = $false
        }
    }
    $portFree = Wait-PortFree -Port $Port -TimeoutSeconds 30
    $state = if ($ownedProcessStopped -and $portFree) { 'PASS' } else { 'BLOCKED-runner-cleanup' }
    return [ordered]@{
        state = $state
        owned_process_id = $processId
        owned_process_stopped = $ownedProcessStopped
        port_free = $portFree
        server_exit_code = $exitCode
        server_exit_code_hex = $exitCodeHex
        server_exit_was_forced = $exitWasForced
    }
}

function Get-ChatRequestBody {
    param([object] $Request)
    return [ordered]@{
        model = 'stage24-local'
        messages = $Request.messages
        temperature = 0
        seed = $Seed
        max_tokens = $MaxTokens
        cache_prompt = $true
    }
}

function Get-S02Requests {
    $requests = New-Object System.Collections.Generic.List[object]
    for ($worker = 0; $worker -lt 4; $worker++) {
        for ($i = 0; $i -lt 4; $i++) {
            $messages = @(
                [ordered]@{ role = 'system'; content = "stage24-s02-worker-$worker stable chat route" },
                [ordered]@{ role = 'user'; content = "S02 worker $worker request $i asks for a short deterministic token trace." }
            )
            $shapeHash = Get-StableHash -Text (($messages | ConvertTo-Json -Compress -Depth 4))
            $requests.Add([pscustomobject]@{
                request_id = "s02-w$worker-r$i"
                row_id = 'S02-chat'
                class = 'concurrent-worker'
                worker = $worker
                messages = $messages
                shape_hash = $shapeHash
            }) | Out-Null
        }
    }
    return $requests.ToArray()
}

function Get-S03Requests {
    $requests = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $DistinctPrefixes; $i++) {
        $branch = 'b{0:d2}-{1}' -f $i, (Get-StableHash -Text "stage24-s03-$Seed-$i")
        $base = "Stage 24 S03 branch $branch keeps a deterministic chat prefix for cache comparison."
        $exactMessages = @(
            [ordered]@{ role = 'system'; content = 'stage24-s03 exact branch metadata probe' },
            [ordered]@{ role = 'user'; content = $base }
        )
        foreach ($rep in 0..1) {
            $requests.Add([pscustomobject]@{
                request_id = "s03-exact-$i-$rep"
                row_id = 'S03-chat'
                class = 'exact-repeat'
                worker = ($i % 2)
                messages = $exactMessages
                shape_hash = Get-StableHash -Text (($exactMessages | ConvertTo-Json -Compress -Depth 4))
            }) | Out-Null
        }
        $nearMessages = @(
            [ordered]@{ role = 'system'; content = 'stage24-s03 near prefix metadata probe' },
            [ordered]@{ role = 'user'; content = "$base near-prefix suffix $i must remain a safe miss unless identity matches." }
        )
        $newMessages = @(
            [ordered]@{ role = 'system'; content = 'stage24-s03 new branch metadata probe' },
            [ordered]@{ role = 'user'; content = "Stage 24 S03 new branch $branch has independent user content $i." }
        )
        $requests.Add([pscustomobject]@{
            request_id = "s03-near-$i"
            row_id = 'S03-chat'
            class = 'near-prefix'
            worker = ($i % 2)
            messages = $nearMessages
            shape_hash = Get-StableHash -Text (($nearMessages | ConvertTo-Json -Compress -Depth 4))
        }) | Out-Null
        $requests.Add([pscustomobject]@{
            request_id = "s03-new-$i"
            row_id = 'S03-chat'
            class = 'new-branch'
            worker = ($i % 2)
            messages = $newMessages
            shape_hash = Get-StableHash -Text (($newMessages | ConvertTo-Json -Compress -Depth 4))
        }) | Out-Null
    }
    return $requests.ToArray()
}

function Get-RowSpec {
    param([string] $RowId)
    if ($RowId -eq 'S02-chat') {
        return [ordered]@{
            row_id = 'S02-chat'
            parallel = 4
            distinct_prefixes = $null
            requests = Get-S02Requests
        }
    }
    if ($RowId -eq 'S03-chat') {
        return [ordered]@{
            row_id = 'S03-chat'
            parallel = 2
            distinct_prefixes = $DistinctPrefixes
            requests = Get-S03Requests
        }
    }
    throw "Unsupported Stage 24 row '$RowId'"
}

function Get-ServerFlags {
    param([object] $RowSpec, [string] $Variant, [string] $LegColdPath, [string] $EvidenceDir)
    $flags = New-Object System.Collections.Generic.List[string]
    foreach ($flag in @('--parallel', [string]$RowSpec.parallel, '--metrics', '--n-gpu-layers', 'all', '--fit', 'off', '--ctx-size', [string]$ContextSize, '--temp', '0', '--seed', [string]$Seed)) {
        [void]$flags.Add($flag)
    }
    if ($Variant -eq 'hybrid-stage24') {
        foreach ($flag in @(
            '--cache-mode', 'hybrid',
            '--cache-ram', [string]$ColdBudgetMiB,
            '--cache-cold-path', $LegColdPath,
            '--cache-cold-max-mib', [string]$ColdBudgetMiB,
            '--cache-prompt-evidence', 'redacted',
            '--cache-prompt-evidence-dir', $EvidenceDir
        )) {
            [void]$flags.Add($flag)
        }
    }
    return $flags.ToArray()
}

function Get-Plan {
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($rowId in $RowsToRun) {
        $spec = Get-RowSpec -RowId $rowId
        $rowIndex = $rows.Count
        $variants = New-Object System.Collections.Generic.List[object]
        foreach ($variant in @('native-legacy', 'hybrid-stage24')) {
            $port = $BasePort + ($rowIndex * 10)
            $legDir = Join-Path $RunRoot (Join-Path $rowId $variant)
            $coldPath = Join-Path $CacheColdPath (Join-Path $RunId (Join-Path $rowId $variant))
            $evidenceDir = Join-Path $RunRoot (Join-Path 'prompt-evidence' (Join-Path $rowId $variant))
            $flags = Get-ServerFlags -RowSpec $spec -Variant $variant -LegColdPath $coldPath -EvidenceDir $evidenceDir
            $variants.Add([ordered]@{
                variant = $variant
                route = $Route
                port = $port
                leg_dir = $legDir
                cold_path = if ($variant -eq 'hybrid-stage24') { $coldPath } else { $null }
                prompt_evidence_dir = if ($variant -eq 'hybrid-stage24') { $evidenceDir } else { $null }
                server_flags = $flags
                request_count = @($spec.requests).Count
                request_classes = @($spec.requests | Group-Object class | ForEach-Object { [ordered]@{ name = $_.Name; count = $_.Count } })
            }) | Out-Null
        }
        $rows.Add([ordered]@{
            row_id = $rowId
            parallel = $spec.parallel
            distinct_prefixes = $spec.distinct_prefixes
            seed = $Seed
            variants = $variants.ToArray()
        }) | Out-Null
    }
    return [ordered]@{
        run_id = $RunId
        rows_to_run = $RowsToRun
        route = $Route
        model_path = $ModelPath
        llama_server_path = $LlamaServerPath
        run_root = $RunRoot
        report_path = $ReportPath
        cache_cold_path = $CacheColdPath
        base_port = $BasePort
        leg_duration_min = $LegDurationMin
        smoke_seconds = $SmokeSeconds
        cold_budget_mib = $ColdBudgetMiB
        cuda_build_proof = Get-CudaBuildProof
        rows = $rows.ToArray()
    }
}

function Read-MetricSamples {
    param([string] $Path)
    $families = @{}
    if (-not (Test-Path $Path)) { return $families }
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        $match = [regex]::Match($line, '^([a-zA-Z_:][a-zA-Z0-9_:]*)(?:\{([^}]*)\})?\s+([-+]?(?:[0-9]+(?:\.[0-9]+)?|\.[0-9]+)(?:[eE][-+]?[0-9]+)?)$')
        if (-not $match.Success) { continue }
        $name = $match.Groups[1].Value
        if (-not $families.ContainsKey($name)) { $families[$name] = New-Object System.Collections.Generic.List[double] }
        $families[$name].Add([double]$match.Groups[3].Value) | Out-Null
    }
    return $families
}

function Get-MetricSum {
    param([hashtable] $Samples, [string] $Name)
    if (-not $Samples.ContainsKey($Name)) { return $null }
    $sum = 0.0
    foreach ($value in $Samples[$Name]) { $sum += $value }
    return $sum
}

function Get-MetricDeltas {
    param([string] $BeforePath, [string] $AfterPath)
    $before = Read-MetricSamples -Path $BeforePath
    $after = Read-MetricSamples -Path $AfterPath
    $result = [ordered]@{}
    foreach ($name in $MetricNames) {
        $b = Get-MetricSum -Samples $before -Name $name
        $a = Get-MetricSum -Samples $after -Name $name
        $state = if ($null -eq $b -or $null -eq $a) { 'BLOCKED-metric-unavailable' } else { 'available' }
        $delta = if ($state -eq 'available') { $a - $b } else { $null }
        $result[$name] = [ordered]@{ before = $b; after = $a; delta = $delta; state = $state }
    }
    return $result
}

function Get-NumberStats {
    param([double[]] $Values)
    if (-not $Values -or $Values.Count -eq 0) {
        return [ordered]@{ count = 0; min = $null; median = $null; p95 = $null; max = $null; sum = 0.0 }
    }
    $sorted = @($Values | Sort-Object)
    $count = $sorted.Count
    $median = $sorted[[Math]::Floor(($count - 1) / 2)]
    $p95Index = [Math]::Min($count - 1, [Math]::Ceiling($count * 0.95) - 1)
    $sum = 0.0
    foreach ($value in $sorted) { $sum += $value }
    return [ordered]@{
        count = $count
        min = $sorted[0]
        median = $median
        p95 = $sorted[$p95Index]
        max = $sorted[$count - 1]
        sum = $sum
    }
}

function Get-RequestsFromJsonl {
    param([string] $Path)
    $items = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path $Path)) { return $items.ToArray() }
    foreach ($line in Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue) {
        if (-not $line) { continue }
        try { $items.Add(($line | ConvertFrom-Json)) | Out-Null } catch {}
    }
    return $items.ToArray()
}

function Test-TransportLossMessage {
    param([string] $Message)
    if (-not $Message) { return $false }
    return ($Message -match 'actively refused|connection refused|An error occurred while sending the request')
}

function Get-NearPrefixRestoreCheck {
    param([string] $RowId, [object] $NativeSummary, [object] $HybridSummary)
    $policy = 'hybrid nonzero near-prefix cache_n is unsafe unless exact chat-boundary proof exists; native default-cache cache_n is diagnostic only'
    if ($RowId -ne 'S03-chat') {
        return [ordered]@{
            state = 'not-applicable'
            near_prefix_requests = 0
            near_prefix_cache_n_nonzero = 0
            near_prefix_restore_policy = $policy
        }
    }
    $nativeRecords = @(Get-RequestsFromJsonl -Path $NativeSummary.evidence_paths.requests_jsonl | Where-Object { $_.class -eq 'near-prefix' })
    $hybridRecords = @(Get-RequestsFromJsonl -Path $HybridSummary.evidence_paths.requests_jsonl | Where-Object { $_.class -eq 'near-prefix' })
    $nativeNonzero = @($nativeRecords | Where-Object { [double]$_.cache_n -gt 0 }).Count
    $hybridNonzero = @($hybridRecords | Where-Object { [double]$_.cache_n -gt 0 }).Count
    $state = if ($hybridNonzero -gt 0) { 'FAIL-unsafe-prefix-restore' } else { 'no-unsafe-prefix-restore-detected' }
    return [ordered]@{
        state = $state
        near_prefix_requests = $nativeRecords.Count + $hybridRecords.Count
        near_prefix_cache_n_nonzero = $hybridNonzero
        near_prefix_restore_policy = $policy
        exact_boundary_proof_implemented = $false
        native = [ordered]@{ near_prefix_requests = $nativeRecords.Count; near_prefix_cache_n_nonzero = $nativeNonzero }
        hybrid = [ordered]@{ near_prefix_requests = $hybridRecords.Count; near_prefix_cache_n_nonzero = $hybridNonzero }
    }
}

function Get-PromptEvidenceStats {
    param([string] $EvidenceDir)
    $stats = [ordered]@{
        evidence_dir = $EvidenceDir
        files = @()
        records = 0
        field_presence = [ordered]@{}
        profiles = [ordered]@{}
        lookup_outcomes = [ordered]@{}
        state = 'BLOCKED-evidence-missing'
    }
    foreach ($field in @('namespace_hash', 'profile', 'pair_state', 'token_count', 'boundary_count', 'lookup_outcome', 'prefix_candidate')) {
        $stats.field_presence[$field] = $false
    }
    if (-not $EvidenceDir -or -not (Test-Path $EvidenceDir)) { return $stats }
    $files = @(Get-ChildItem -LiteralPath $EvidenceDir -Recurse -Filter 'cache-prompt-evidence.jsonl' -File -ErrorAction SilentlyContinue)
    $stats.files = @($files | ForEach-Object { $_.FullName })
    foreach ($file in $files) {
        foreach ($line in Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue) {
            if (-not $line) { continue }
            try {
                $record = $line | ConvertFrom-Json
                $stats.records++
                foreach ($field in @($stats.field_presence.Keys)) {
                    if ($record.PSObject.Properties.Name -contains $field) { $stats.field_presence[$field] = $true }
                }
                $profile = if ($record.profile) { [string]$record.profile } else { '(missing)' }
                $outcome = if ($record.lookup_outcome) { [string]$record.lookup_outcome } else { '(missing)' }
                if (-not $stats.profiles.Contains($profile)) { $stats.profiles[$profile] = 0 }
                if (-not $stats.lookup_outcomes.Contains($outcome)) { $stats.lookup_outcomes[$outcome] = 0 }
                $stats.profiles[$profile]++
                $stats.lookup_outcomes[$outcome]++
            } catch {}
        }
    }
    if ($stats.records -gt 0) { $stats.state = 'available' }
    return $stats
}

function Invoke-LeakScan {
    param([string[]] $ArtifactPaths, [string[]] $ForbiddenStrings)
    $hits = New-Object System.Collections.Generic.List[object]
    foreach ($path in $ArtifactPaths) {
        if (-not $path -or -not (Test-Path $path)) { continue }
        $files = if ((Get-Item -LiteralPath $path).PSIsContainer) {
            @(Get-ChildItem -LiteralPath $path -Recurse -File -ErrorAction SilentlyContinue)
        } else {
            @((Get-Item -LiteralPath $path))
        }
        foreach ($file in $files) {
            $text = ''
            try { $text = [System.IO.File]::ReadAllText($file.FullName) } catch { continue }
            foreach ($needle in $ForbiddenStrings) {
                if ($needle -and $text.Contains($needle)) {
                    $hits.Add([ordered]@{ file = $file.FullName; pattern_hash = (Get-StableHash -Text $needle) }) | Out-Null
                }
            }
            foreach ($name in @('"messages"', '"content"', '"raw_prompt"', '"namespace_id"', '"descriptor_id"', '"raw_prompt_file"')) {
                if ($text.Contains($name)) {
                    $hits.Add([ordered]@{ file = $file.FullName; pattern = $name }) | Out-Null
                }
            }
        }
    }
    $status = if ($hits.Count -eq 0) { 'PASS' } else { 'FAIL-runner-contract' }
    return [ordered]@{ status = $status; hit_count = $hits.Count; hits = $hits.ToArray() }
}

function Test-LogPattern {
    param([string[]] $Paths, [string] $Pattern)
    foreach ($path in $Paths) {
        if ($path -and (Test-Path $path)) {
            if (Select-String -LiteralPath $path -Pattern $Pattern -Quiet -ErrorAction SilentlyContinue) {
                return $true
            }
        }
    }
    return $false
}

function Invoke-ChatRequest {
    param([int] $Port, [object] $Request, [string] $Variant, [string] $JsonlPath)
    $bodyObject = Get-ChatRequestBody -Request $Request
    $body = $bodyObject | ConvertTo-Json -Depth 6 -Compress
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $record = [ordered]@{
        request_id = $Request.request_id
        row_id = $Request.row_id
        variant = $Variant
        route = $Route
        class = $Request.class
        worker = $Request.worker
        shape_hash = $Request.shape_hash
        status = $null
        error = $null
        cache_n = 0
        prompt_tokens = 0
        generated_tokens = 0
        total_tokens = 0
        prompt_ms = $null
        total_ms = $null
        elapsed_ms = $null
    }
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$Port$Route" -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
        $sw.Stop()
        $json = $resp.Content | ConvertFrom-Json
        $record.status = [int]$resp.StatusCode
        if ($json.timings) {
            if ($null -ne $json.timings.cache_n) { $record.cache_n = [int]$json.timings.cache_n }
            if ($null -ne $json.timings.prompt_ms) { $record.prompt_ms = [double]$json.timings.prompt_ms }
            if ($null -ne $json.timings.predicted_ms) { $record.total_ms = [double]$json.timings.predicted_ms + [double]($json.timings.prompt_ms) }
        }
        if ($json.usage) {
            if ($null -ne $json.usage.prompt_tokens) { $record.prompt_tokens = [int]$json.usage.prompt_tokens }
            if ($null -ne $json.usage.completion_tokens) { $record.generated_tokens = [int]$json.usage.completion_tokens }
            if ($null -ne $json.usage.total_tokens) { $record.total_tokens = [int]$json.usage.total_tokens }
        }
        $record.elapsed_ms = [double]$sw.Elapsed.TotalMilliseconds
        if ($null -eq $record.total_ms) { $record.total_ms = $record.elapsed_ms }
    } catch {
        $sw.Stop()
        $record.status = 'request-error'
        $record.error = $_.Exception.Message
        $record.elapsed_ms = [double]$sw.Elapsed.TotalMilliseconds
        $record.total_ms = $record.elapsed_ms
    }
    ($record | ConvertTo-Json -Compress -Depth 6) | Out-File -FilePath $JsonlPath -Append -Encoding utf8
}

function Invoke-RequestSet {
    param([object] $RowSpec, [string] $Variant, [int] $Port, [string] $JsonlPath, [int] $DurationSeconds)
    $start = Get-Date
    $end = $start.AddSeconds($DurationSeconds)
    $round = 0
    $abortReason = $null
    do {
        if ($RowSpec.row_id -eq 'S02-chat') {
            $jobs = New-Object System.Collections.Generic.List[object]
            $selected = New-Object System.Collections.Generic.List[object]
            for ($worker = 0; $worker -lt $RowSpec.parallel; $worker++) {
                $workerRequests = @($RowSpec.requests | Where-Object { $_.worker -eq $worker })
                if ($workerRequests.Count -gt 0) {
                    $selected.Add($workerRequests[$round % $workerRequests.Count]) | Out-Null
                }
            }
            foreach ($request in $selected) {
                $jobs.Add((Start-Job -ScriptBlock {
                    param($SourceRootArg, $RouteArg, $SeedArg, $MaxTokensArg, $PortArg, $RequestJson, $VariantArg, $JsonlArg)
                    $request = $RequestJson | ConvertFrom-Json
                    $bodyObject = [ordered]@{
                        model = 'stage24-local'
                        messages = $request.messages
                        temperature = 0
                        seed = $SeedArg
                        max_tokens = $MaxTokensArg
                        cache_prompt = $true
                    }
                    $body = $bodyObject | ConvertTo-Json -Depth 6 -Compress
                    $sw = [System.Diagnostics.Stopwatch]::StartNew()
                    $record = [ordered]@{
                        request_id = $request.request_id
                        row_id = $request.row_id
                        variant = $VariantArg
                        route = $RouteArg
                        class = $request.class
                        worker = $request.worker
                        shape_hash = $request.shape_hash
                        status = $null
                        error = $null
                        cache_n = 0
                        prompt_tokens = 0
                        generated_tokens = 0
                        total_tokens = 0
                        prompt_ms = $null
                        total_ms = $null
                        elapsed_ms = $null
                    }
                    try {
                        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$PortArg$RouteArg" -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
                        $sw.Stop()
                        $json = $resp.Content | ConvertFrom-Json
                        $record.status = [int]$resp.StatusCode
                        if ($json.timings) {
                            if ($null -ne $json.timings.cache_n) { $record.cache_n = [int]$json.timings.cache_n }
                            if ($null -ne $json.timings.prompt_ms) { $record.prompt_ms = [double]$json.timings.prompt_ms }
                            if ($null -ne $json.timings.predicted_ms) { $record.total_ms = [double]$json.timings.predicted_ms + [double]($json.timings.prompt_ms) }
                        }
                        if ($json.usage) {
                            if ($null -ne $json.usage.prompt_tokens) { $record.prompt_tokens = [int]$json.usage.prompt_tokens }
                            if ($null -ne $json.usage.completion_tokens) { $record.generated_tokens = [int]$json.usage.completion_tokens }
                            if ($null -ne $json.usage.total_tokens) { $record.total_tokens = [int]$json.usage.total_tokens }
                        }
                        $record.elapsed_ms = [double]$sw.Elapsed.TotalMilliseconds
                        if ($null -eq $record.total_ms) { $record.total_ms = $record.elapsed_ms }
                    } catch {
                        $sw.Stop()
                        $record.status = 'request-error'
                        $record.error = $_.Exception.Message
                        $record.elapsed_ms = [double]$sw.Elapsed.TotalMilliseconds
                        $record.total_ms = $record.elapsed_ms
                    }
                    return ($record | ConvertTo-Json -Compress -Depth 6)
                } -ArgumentList $SourceRoot, $Route, $Seed, $MaxTokens, $Port, ($request | ConvertTo-Json -Depth 6 -Compress), $Variant, $JsonlPath)) | Out-Null
            }
            Wait-Job -Job $jobs.ToArray() | Out-Null
            $transportLoss = 0
            foreach ($job in $jobs) {
                foreach ($line in Receive-Job -Job $job) {
                    if ($line) {
                        $line | Out-File -FilePath $JsonlPath -Append -Encoding utf8
                        try {
                            $record = $line | ConvertFrom-Json
                            if ($record.status -eq 'request-error' -and (Test-TransportLossMessage -Message ([string]$record.error))) {
                                $transportLoss++
                            }
                        } catch {}
                    }
                }
            }
            $jobs | Remove-Job
            if ($transportLoss -gt 0 -and (Test-PortFree -Port $Port)) {
                $abortReason = 'aborted-server-unreachable-after-health'
                break
            }
        } else {
            foreach ($request in $RowSpec.requests) {
                Invoke-ChatRequest -Port $Port -Request $request -Variant $Variant -JsonlPath $JsonlPath
                $lastRecord = @(Get-RequestsFromJsonl -Path $JsonlPath | Select-Object -Last 1)
                if ($lastRecord.Count -gt 0 -and $lastRecord[0].status -eq 'request-error' -and (Test-TransportLossMessage -Message ([string]$lastRecord[0].error)) -and (Test-PortFree -Port $Port)) {
                    $abortReason = 'aborted-server-unreachable-after-health'
                    break
                }
                if ((Get-Date) -ge $end) { break }
            }
        }
        $round++
    } while ((Get-Date) -lt $end -and $round -lt 100000 -and -not $abortReason)
    return [ordered]@{
        state = if ($abortReason) { $abortReason } else { 'completed-until-cap' }
        rounds = $round
        started_at = $start.ToString('o')
        ended_at = (Get-Date).ToString('o')
    }
}

function Get-LegSummary {
    param([object] $LegPlan, [object] $RowSpec, [string] $Verdict, [string] $Failure, [string] $Notes, [object] $CleanupStatus, [object] $RequestRun)
    $legDir = $LegPlan.leg_dir
    $requestsPath = Join-Path $legDir 'requests.jsonl'
    $records = Get-RequestsFromJsonl -Path $requestsPath
    $statusCounts = @{}
    $errorCounts = @{}
    $cacheValues = New-Object System.Collections.Generic.List[double]
    $promptTimes = New-Object System.Collections.Generic.List[double]
    $totalTimes = New-Object System.Collections.Generic.List[double]
    $promptTokens = 0
    $generatedTokens = 0
    $totalTokens = 0
    foreach ($record in $records) {
        Add-Count -Map $statusCounts -Key ([string]$record.status)
        if ($record.error) { Add-Count -Map $errorCounts -Key ([string](Get-StableHash -Text $record.error)) }
        $cacheValues.Add([double]$record.cache_n) | Out-Null
        if ($null -ne $record.prompt_ms) { $promptTimes.Add([double]$record.prompt_ms) | Out-Null }
        if ($null -ne $record.total_ms) { $totalTimes.Add([double]$record.total_ms) | Out-Null }
        $promptTokens += [int]$record.prompt_tokens
        $generatedTokens += [int]$record.generated_tokens
        $totalTokens += [int]$record.total_tokens
    }
    $nonzero = @($cacheValues | Where-Object { $_ -gt 0 }).Count
    $metricDeltas = Get-MetricDeltas -BeforePath (Join-Path $legDir 'metrics-before.txt') -AfterPath (Join-Path $legDir 'metrics-after.txt')
    $coldBytesMetric = $metricDeltas['cache_cold_bytes'].after
    $coldBudgetMetric = $metricDeltas['cache_cold_budget_bytes'].after
    $coldPathBytes = if ($LegPlan.cold_path) { Get-DirectoryBytes -Path $LegPlan.cold_path } else { 0L }
    $coldState = if ($LegPlan.variant -ne 'hybrid-stage24') {
        'not-applicable'
    } elseif ($null -ne $coldBytesMetric -and $null -ne $coldBudgetMetric) {
        if ($coldBytesMetric -le $coldBudgetMetric) { 'PASS' } else { 'FAIL-cold-budget' }
    } elseif ($coldPathBytes -le ([int64]$ColdBudgetMiB * 1MB)) {
        'PASS-filesystem-fallback'
    } else {
        'FAIL-cold-budget'
    }
    $promptEvidence = if ($LegPlan.variant -eq 'hybrid-stage24') {
        Get-PromptEvidenceStats -EvidenceDir $LegPlan.prompt_evidence_dir
    } else {
        [ordered]@{ state = 'not-applicable'; records = 0 }
    }
    return [ordered]@{
        run_id = $RunId
        row_id = $RowSpec.row_id
        variant = $LegPlan.variant
        route = $Route
        port = $LegPlan.port
        model_path_hash = Get-StableHash -Text $ModelPath
        server_flags = $LegPlan.server_flags
        request_counts = [ordered]@{
            planned = @($RowSpec.requests).Count
            observed = @($records).Count
            rounds_or_until_cap = $true
            request_run = if ($RequestRun) { $RequestRun } else { [ordered]@{ state = 'not-run' } }
        }
        request_shape_hashes = @($RowSpec.requests | ForEach-Object { $_.shape_hash })
        status_counts = $statusCounts
        error_counts = $errorCounts
        token_totals = [ordered]@{ prompt = $promptTokens; generated = $generatedTokens; total = $totalTokens }
        cache_n = [ordered]@{
            count = $cacheValues.Count
            sum = (($cacheValues | Measure-Object -Sum).Sum + 0)
            max = if ($cacheValues.Count -gt 0) { (($cacheValues | Measure-Object -Maximum).Maximum + 0) } else { 0 }
            nonzero_count = $nonzero
            nonzero_rate = if ($cacheValues.Count -gt 0) { $nonzero / $cacheValues.Count } else { 0 }
        }
        timing = [ordered]@{ prompt_ms = Get-NumberStats -Values $promptTimes.ToArray(); total_ms = Get-NumberStats -Values $totalTimes.ToArray() }
        metric_deltas = $metricDeltas
        cuda_runtime_proof = Get-CudaRuntimeProof -Paths @((Join-Path $legDir 'server.out.log'), (Join-Path $legDir 'server.err.log'))
        cold_budget = [ordered]@{
            metric_bytes_after = $coldBytesMetric
            metric_budget_after = $coldBudgetMetric
            filesystem_bytes_after = $coldPathBytes
            budget_mib = $ColdBudgetMiB
            state = $coldState
        }
        prompt_evidence = $promptEvidence
        leak_scan = [ordered]@{ status = 'PENDING' }
        cleanup = if ($CleanupStatus) { $CleanupStatus } else { [ordered]@{ state = 'PENDING'; owned_process_id = $null; owned_process_stopped = $null; port_free = $null } }
        verdict = $Verdict
        failure_classification = $Failure
        notes = $Notes
        evidence_paths = [ordered]@{
            leg_dir = $legDir
            launch_log = (Join-Path $legDir 'launch.log')
            server_out = (Join-Path $legDir 'server.out.log')
            server_err = (Join-Path $legDir 'server.err.log')
            metrics_before = (Join-Path $legDir 'metrics-before.txt')
            metrics_after = (Join-Path $legDir 'metrics-after.txt')
            requests_jsonl = $requestsPath
            summary_json = (Join-Path $legDir 'summary.json')
        }
    }
}

function Wait-ServerHealthy {
    param([int] $Port, [int] $TimeoutSeconds)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 4
            if ($response.StatusCode -eq 200) { return $true }
        } catch {}
        Start-Sleep -Seconds 2
    }
    return $false
}

function Invoke-Leg {
    param([object] $LegPlan, [object] $RowSpec)
    $legDir = $LegPlan.leg_dir
    $summary = $null
    $proc = $null
    $requestRun = $null
    if (Test-Path $legDir) { Remove-Item -LiteralPath $legDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $legDir | Out-Null
    if ($CrashDumpDir) { New-Item -ItemType Directory -Force -Path $CrashDumpDir | Out-Null }
    if ($LegPlan.cold_path -and (Test-Path $LegPlan.cold_path)) { Remove-Item -LiteralPath $LegPlan.cold_path -Recurse -Force }
    if ($LegPlan.cold_path) { New-Item -ItemType Directory -Force -Path $LegPlan.cold_path | Out-Null }
    if ($LegPlan.prompt_evidence_dir) { New-Item -ItemType Directory -Force -Path $LegPlan.prompt_evidence_dir | Out-Null }

    $launchLog = Join-Path $legDir 'launch.log'
    Write-TextFile -Path $launchLog -Text ("RunId=$RunId`nRow=$($RowSpec.row_id)`nVariant=$($LegPlan.variant)`nRoute=$Route`nPort=$($LegPlan.port)`nFlags=$($LegPlan.server_flags -join ' ')`n")
    Write-TextFile -Path (Join-Path $legDir 'server-flags.txt') -Text ($LegPlan.server_flags -join ' ')

    if (-not (Test-Path $LlamaServerPath)) {
        $cleanup = Complete-LegCleanup -Process $null -Port $LegPlan.port
        $summary = Get-LegSummary -LegPlan $LegPlan -RowSpec $RowSpec -Verdict 'BLOCKED' -Failure 'BLOCKED-missing-binary' -Notes "llama-server not found" -CleanupStatus $cleanup
        Write-JsonFile -Path (Join-Path $legDir 'summary.json') -Value $summary
        return $summary
    }
    if (-not (Test-Path $ModelPath)) {
        $cleanup = Complete-LegCleanup -Process $null -Port $LegPlan.port
        $summary = Get-LegSummary -LegPlan $LegPlan -RowSpec $RowSpec -Verdict 'BLOCKED' -Failure 'BLOCKED-missing-fixture' -Notes "model fixture not found" -CleanupStatus $cleanup
        Write-JsonFile -Path (Join-Path $legDir 'summary.json') -Value $summary
        return $summary
    }
    if (-not (Test-PortFree -Port $LegPlan.port)) {
        $cleanup = [ordered]@{ state = 'BLOCKED-runner-cleanup'; owned_process_id = $null; owned_process_stopped = $null; port_free = $false }
        $summary = Get-LegSummary -LegPlan $LegPlan -RowSpec $RowSpec -Verdict 'BLOCKED' -Failure 'BLOCKED-port-collision' -Notes "port already in use" -CleanupStatus $cleanup
        Write-JsonFile -Path (Join-Path $legDir 'summary.json') -Value $summary
        return $summary
    }

    try {
        $args = $LegPlan.server_flags + @('--model', $ModelPath, '--host', '127.0.0.1', '--port', [string]$LegPlan.port) + $(if ($CrashDumpDir) { @('--crash-dump-dir', $CrashDumpDir) } else { @() })
        $proc = Start-Process -FilePath $LlamaServerPath -ArgumentList $args -RedirectStandardOutput (Join-Path $legDir 'server.out.log') -RedirectStandardError (Join-Path $legDir 'server.err.log') -NoNewWindow -PassThru
        if (-not (Wait-ServerHealthy -Port $LegPlan.port -TimeoutSeconds $ServerStartupTimeoutS)) {
            $summary = Get-LegSummary -LegPlan $LegPlan -RowSpec $RowSpec -Verdict 'BLOCKED' -Failure 'BLOCKED-server-not-healthy' -Notes "health endpoint did not return ready"
        } else {
            $cudaProof = Wait-CudaRuntimeProof -Paths @((Join-Path $legDir 'server.out.log'), (Join-Path $legDir 'server.err.log'))
            if ($cudaProof.state -ne 'PASS') {
                $summary = Get-LegSummary -LegPlan $LegPlan -RowSpec $RowSpec -Verdict 'BLOCKED' -Failure $cudaProof.state -Notes "CUDA runtime proof missing after startup"
                $summary['cuda_runtime_proof'] = $cudaProof
                return $summary
            }
            try {
                (Invoke-WebRequest -Uri "http://127.0.0.1:$($LegPlan.port)/metrics" -UseBasicParsing -TimeoutSec 20).Content |
                    Out-File -FilePath (Join-Path $legDir 'metrics-before.txt') -Encoding utf8
            } catch {
                Write-TextFile -Path (Join-Path $legDir 'metrics-before.txt') -Text "# metrics unavailable before: $($_.Exception.Message)`n"
            }
            $durationSeconds = if ($SmokeSeconds -gt 0) { $SmokeSeconds } else { $LegDurationMin * 60 }
            $requestRun = Invoke-RequestSet -RowSpec $RowSpec -Variant $LegPlan.variant -Port $LegPlan.port -JsonlPath (Join-Path $legDir 'requests.jsonl') -DurationSeconds $durationSeconds
            try {
                (Invoke-WebRequest -Uri "http://127.0.0.1:$($LegPlan.port)/metrics" -UseBasicParsing -TimeoutSec 20).Content |
                    Out-File -FilePath (Join-Path $legDir 'metrics-after.txt') -Encoding utf8
            } catch {
                Write-TextFile -Path (Join-Path $legDir 'metrics-after.txt') -Text "# metrics unavailable after: $($_.Exception.Message)`n"
            }
            $records = Get-RequestsFromJsonl -Path (Join-Path $legDir 'requests.jsonl')
            $errors = @($records | Where-Object { $_.status -ne 200 }).Count
            $verdict = if (@($records).Count -eq 0) { 'BLOCKED' } elseif ($errors -gt 0) { 'FAIL' } else { 'PASS' }
            $failure = if ($verdict -eq 'PASS') { 'none' } elseif (@($records).Count -eq 0) { 'BLOCKED-no-requests' } else { 'FAIL-http-request' }
            $notes = if ($requestRun -and $requestRun.state -eq 'aborted-server-unreachable-after-health') { 'request loop stopped after server became unreachable' } else { 'leg completed' }
            $summary = Get-LegSummary -LegPlan $LegPlan -RowSpec $RowSpec -Verdict $verdict -Failure $failure -Notes $notes -RequestRun $requestRun
            if ($LegPlan.variant -eq 'hybrid-stage24') {
                if ($summary.prompt_evidence.state -ne 'available' -and $summary.verdict -eq 'PASS') {
                    $summary.verdict = 'BLOCKED'
                    $summary.failure_classification = 'BLOCKED-evidence-missing'
                }
                if ($summary.cold_budget.state -like 'FAIL*') {
                    $summary.verdict = 'FAIL'
                    $summary.failure_classification = $summary.cold_budget.state
                }
            }
        }
    } catch {
        $summary = Get-LegSummary -LegPlan $LegPlan -RowSpec $RowSpec -Verdict 'FAIL' -Failure 'FAIL-runner-exception' -Notes $_.Exception.Message
    } finally {
        $cleanup = Complete-LegCleanup -Process $proc -Port $LegPlan.port
        # D-EXEC-26-03: persist server exit code for mid-leg death diagnosis
        $exitLogPath = Join-Path $legDir 'server-exit-code.txt'
        $exitLogBody = "pid=$($cleanup.owned_process_id)`nexit_code_hex=$($cleanup.server_exit_code_hex)`nexit_was_forced=$($cleanup.server_exit_was_forced)`n"
        Write-TextFile -Path $exitLogPath -Text $exitLogBody
        Write-Output ("runner-leg-exit: row={0} variant={1} pid={2} {3}" -f $RowSpec.row_id, $LegPlan.variant, $cleanup.owned_process_id, $cleanup.server_exit_code_hex)
        if ($summary) {
            $summary['cleanup'] = $cleanup
            if ($cleanup.state -eq 'BLOCKED-runner-cleanup' -and $summary.verdict -ne 'FAIL') {
                $summary['verdict'] = 'BLOCKED'
                $summary['failure_classification'] = 'BLOCKED-runner-cleanup'
            }
            Write-JsonFile -Path (Join-Path $legDir 'summary.json') -Value $summary
        }
    }
    return $summary
}

function New-Comparison {
    param([string] $RowId, [object] $NativeSummary, [object] $HybridSummary)
    $nativeShapes = @($NativeSummary.request_shape_hashes)
    $hybridShapes = @($HybridSummary.request_shape_hashes)
    $shapeMatch = (($nativeShapes -join ',') -eq ($hybridShapes -join ','))
    $unsafePrefix = Get-NearPrefixRestoreCheck -RowId $RowId -NativeSummary $NativeSummary -HybridSummary $HybridSummary
    $timingDelta = [ordered]@{
        total_ms_median = $HybridSummary.timing.total_ms.median - $NativeSummary.timing.total_ms.median
        total_ms_p95 = $HybridSummary.timing.total_ms.p95 - $NativeSummary.timing.total_ms.p95
        prompt_ms_median = $HybridSummary.timing.prompt_ms.median - $NativeSummary.timing.prompt_ms.median
        classification = 'neutral'
    }
    if ($timingDelta.total_ms_median -lt 0) { $timingDelta.classification = 'faster' }
    if ($timingDelta.total_ms_median -gt 0) { $timingDelta.classification = 'slower' }
    $verdict = if (-not $shapeMatch) {
        'BLOCKED'
    } elseif ($unsafePrefix.state -eq 'FAIL-unsafe-prefix-restore') {
        'FAIL'
    } elseif ($NativeSummary.verdict -eq 'FAIL' -or $HybridSummary.verdict -eq 'FAIL') {
        'FAIL'
    } elseif ($NativeSummary.verdict -eq 'BLOCKED' -or $HybridSummary.verdict -eq 'BLOCKED') {
        'BLOCKED'
    } else {
        'PASS'
    }
    $failure = if (-not $shapeMatch) { 'BLOCKED-runner-contract' } elseif ($unsafePrefix.state -eq 'FAIL-unsafe-prefix-restore') { 'FAIL-unsafe-prefix-restore' } elseif ($NativeSummary.verdict -ne 'PASS') { $NativeSummary.failure_classification } elseif ($HybridSummary.verdict -ne 'PASS') { $HybridSummary.failure_classification } else { 'none' }
    return [ordered]@{
        run_id = $RunId
        row_id = $RowId
        variants = @('native-legacy', 'hybrid-stage24')
        request_shape_hash_match = $shapeMatch
        native_summary = $NativeSummary.evidence_paths.summary_json
        hybrid_summary = $HybridSummary.evidence_paths.summary_json
        timing_delta = $timingDelta
        cache_n_delta = [ordered]@{ sum = $HybridSummary.cache_n.sum - $NativeSummary.cache_n.sum; nonzero_rate = $HybridSummary.cache_n.nonzero_rate - $NativeSummary.cache_n.nonzero_rate }
        metric_delta_comparison = [ordered]@{
            restore_misses = $HybridSummary.metric_deltas.'llamacpp:cache_restore_misses_total'.delta
            prompt_evidence_records = $HybridSummary.metric_deltas.'llamacpp:cache_prompt_evidence_records_total'.delta
            checkpoint_admissions = $HybridSummary.metric_deltas.'llamacpp:cache_checkpoint_admissions_total'.delta
        }
        chat_metadata_evidence = [ordered]@{
            server_log_source_openai_chat = (Test-LogPattern -Paths @($HybridSummary.evidence_paths.server_out, $HybridSummary.evidence_paths.server_err) -Pattern 'source=openai-chat')
            server_log_rendered_boundary = (Test-LogPattern -Paths @($HybridSummary.evidence_paths.server_out, $HybridSummary.evidence_paths.server_err) -Pattern 'method=rendered-text-boundary-inference')
        }
        cuda_runtime_evidence = [ordered]@{
            native = $NativeSummary.cuda_runtime_proof
            hybrid = $HybridSummary.cuda_runtime_proof
        }
        unsafe_prefix_restore_check = $unsafePrefix
        cold_budget_check = $HybridSummary.cold_budget
        verdict = $verdict
        failure_classification = $failure
        interpretation = 'Stage 24 comparison data only; timing deltas are not a product performance claim.'
    }
}

function Write-Report {
    param([object[]] $Comparisons)
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Stage 24 chat S02/S03 comparison") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add(('RunId: `{0}`' -f $RunId)) | Out-Null
    $lines.Add(('RunRoot: `{0}`' -f $RunRoot)) | Out-Null
    $lines.Add(('Route: `{0}`' -f $Route)) | Out-Null
    $lines.Add(('ModelPath hash: `{0}`' -f (Get-StableHash -Text $ModelPath))) | Out-Null
    $lines.Add(('CUDA build proof: `{0}`' -f (Get-CudaBuildProof).state)) | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Row | Verdict | Failure | CUDA native | CUDA hybrid | Leak scan | Near-prefix requests | Near-prefix nonzero cache_n | Hybrid cold state | Evidence |') | Out-Null
    $lines.Add('| --- | --- | --- | --- | --- | --- | ---: | ---: | --- | --- |') | Out-Null
    foreach ($comparison in $Comparisons) {
        $native = Get-Content -LiteralPath $comparison.native_summary -Raw | ConvertFrom-Json
        $hybrid = Get-Content -LiteralPath $comparison.hybrid_summary -Raw | ConvertFrom-Json
        $rel = $comparison.row_id + '/comparison.json'
        $leakStatus = if ($comparison.Contains('leak_scan')) { $comparison.leak_scan.status } else { 'PENDING' }
        $nearRequests = $comparison.unsafe_prefix_restore_check.near_prefix_requests
        $nearNonzero = $comparison.unsafe_prefix_restore_check.near_prefix_cache_n_nonzero
        $lines.Add("| $($comparison.row_id) | $($comparison.verdict) | $($comparison.failure_classification) | $($native.cuda_runtime_proof.state) | $($hybrid.cuda_runtime_proof.state) | $leakStatus | $nearRequests | $nearNonzero | $($hybrid.cold_budget.state) | ``$rel`` |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('Durable report omits raw prompt text, raw message content, full request bodies, raw namespace ids, and raw descriptor ids. Raw logs and JSONL artifacts stay under the run root.') | Out-Null
    Write-TextFile -Path $ReportPath -Text (($lines.ToArray() -join "`n") + "`n")
}

$stamp = Get-NextRunSuffix
if (-not $RunId) { $RunId = "stage24-chat-s02-s03-$($stamp.date)-$($stamp.suffix)" }
if (-not $ModelPath) { $ModelPath = Join-Path $SourceRoot '._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' }
if (-not $RunRoot) { $RunRoot = Join-Path $SourceRoot "._test_output\$RunId" }
if (-not $ReportPath) { $ReportPath = Join-Path $SourceRoot "._design_docs\.test_reports\test-report-$($stamp.date)-$($stamp.suffix).md" }
if (-not $LlamaServerPath) {
    $candidate = Join-Path $SourceRoot 'build-cov\bin\Release\llama-server.exe'
    if (Test-Path $candidate) { $LlamaServerPath = $candidate } else { $LlamaServerPath = Join-Path $SourceRoot 'build\bin\Release\llama-server.exe' }
}
$RowsToRun = Normalize-RowsToRun -Rows $RowsToRun
$ModelPath = Resolve-Stage24Path -PathValue $ModelPath
$RunRoot = Resolve-Stage24Path -PathValue $RunRoot
$ReportPath = Resolve-Stage24Path -PathValue $ReportPath
$LlamaServerPath = Resolve-Stage24Path -PathValue $LlamaServerPath
Assert-WhitelistedReportPath -PathValue $ReportPath

$plan = Get-Plan
if ($DryRun) {
    New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
    $dryRunPlanPath = Join-Path $RunRoot 'dry-run-plan.json'
    Write-JsonFile -Path $dryRunPlanPath -Value $plan
    Write-Host ("Stage 24 dry-run plan written: {0}; rows={1}; route={2}; cuda_build={3}" -f $dryRunPlanPath, ($RowsToRun -join ','), $Route, $plan.cuda_build_proof.state)
    exit 0
}

New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
$cudaBuildProof = Get-CudaBuildProof
if ($cudaBuildProof.state -ne 'PASS') {
    $lines = @(
        '# Stage 24 chat S02/S03 comparison',
        '',
        ('RunId: `{0}`' -f $RunId),
        ('RunRoot: `{0}`' -f $RunRoot),
        ('Route: `{0}`' -f $Route),
        '',
        'Status: BLOCKED',
        ('Failure: `{0}`' -f $cudaBuildProof.state),
        ('Required CMake cache proof: `{0}`' -f $cudaBuildProof.required),
        ('Observed CMake cache proof: `{0}`' -f $cudaBuildProof.observed),
        '',
        'Stage 24 requires an Nvidia CUDA build before any row classification. Reconfigure with `-DGGML_CUDA=ON`; this runner did not start final live legs.'
    )
    Write-TextFile -Path $ReportPath -Text (($lines -join "`n") + "`n")
    Write-JsonFile -Path (Join-Path $RunRoot 'cuda-build-proof.json') -Value $cudaBuildProof
    throw "BLOCKED-cuda-configure-missing: GGML_CUDA:BOOL=ON is required for Stage 24"
}
$comparisons = New-Object System.Collections.Generic.List[object]
$leakContexts = New-Object System.Collections.Generic.List[object]
foreach ($rowPlan in $plan.rows) {
    $rowSpec = Get-RowSpec -RowId $rowPlan.row_id
    $nativePlan = $rowPlan.variants | Where-Object { $_.variant -eq 'native-legacy' } | Select-Object -First 1
    $hybridPlan = $rowPlan.variants | Where-Object { $_.variant -eq 'hybrid-stage24' } | Select-Object -First 1
    $nativeSummary = Invoke-Leg -LegPlan $nativePlan -RowSpec $rowSpec
    $hybridSummary = Invoke-Leg -LegPlan $hybridPlan -RowSpec $rowSpec
    $comparison = New-Comparison -RowId $rowPlan.row_id -NativeSummary $nativeSummary -HybridSummary $hybridSummary
    $comparisonPath = Join-Path $RunRoot (Join-Path $rowPlan.row_id 'comparison.json')
    Write-JsonFile -Path $comparisonPath -Value $comparison
    $forbidden = @()
    foreach ($request in $rowSpec.requests) {
        foreach ($message in $request.messages) { $forbidden += [string]$message.content }
    }
    $artifactPaths = @($ReportPath, $nativeSummary.evidence_paths.requests_jsonl, $hybridSummary.evidence_paths.requests_jsonl, $nativeSummary.evidence_paths.summary_json, $hybridSummary.evidence_paths.summary_json, $comparisonPath, $nativeSummary.evidence_paths.server_out, $nativeSummary.evidence_paths.server_err, $hybridSummary.evidence_paths.server_out, $hybridSummary.evidence_paths.server_err, $hybridPlan.prompt_evidence_dir)
    $comparisons.Add($comparison) | Out-Null
    $leakContexts.Add([ordered]@{
        row_id = $rowPlan.row_id
        comparison = $comparison
        comparison_path = $comparisonPath
        native_summary = $nativeSummary
        hybrid_summary = $hybridSummary
        artifact_paths = $artifactPaths
        forbidden_strings = $forbidden
    }) | Out-Null
}

Write-Report -Comparisons $comparisons.ToArray()

foreach ($context in $leakContexts) {
    $nativeSummary = $context.native_summary
    $hybridSummary = $context.hybrid_summary
    $comparison = $context.comparison
    $comparisonPath = $context.comparison_path
    $leak = Invoke-LeakScan -ArtifactPaths $context.artifact_paths -ForbiddenStrings $context.forbidden_strings
    $comparison.leak_scan = $leak
    $nativeSummary.leak_scan = $leak
    $hybridSummary.leak_scan = $leak
    if ($leak.status -ne 'PASS') {
        $comparison.verdict = 'FAIL'
        $comparison.failure_classification = $leak.status
        $nativeSummary.verdict = if ($nativeSummary.verdict -eq 'PASS') { 'FAIL' } else { $nativeSummary.verdict }
        $hybridSummary.verdict = if ($hybridSummary.verdict -eq 'PASS') { 'FAIL' } else { $hybridSummary.verdict }
    }
    Write-JsonFile -Path $nativeSummary.evidence_paths.summary_json -Value $nativeSummary
    Write-JsonFile -Path $hybridSummary.evidence_paths.summary_json -Value $hybridSummary
    Write-JsonFile -Path $comparisonPath -Value $comparison
}
Write-Report -Comparisons $comparisons.ToArray()

$allForbidden = New-Object System.Collections.Generic.List[string]
$allArtifacts = New-Object System.Collections.Generic.List[string]
foreach ($context in $leakContexts) {
    foreach ($item in $context.forbidden_strings) { [void]$allForbidden.Add($item) }
    foreach ($item in $context.artifact_paths) { [void]$allArtifacts.Add($item) }
}
$finalLeak = Invoke-LeakScan -ArtifactPaths ($allArtifacts.ToArray() | Select-Object -Unique) -ForbiddenStrings ($allForbidden.ToArray() | Select-Object -Unique)
Write-JsonFile -Path (Join-Path $RunRoot 'final-leak-scan.json') -Value $finalLeak
if ($finalLeak.status -ne 'PASS') {
    foreach ($context in $leakContexts) {
        $nativeSummary = $context.native_summary
        $hybridSummary = $context.hybrid_summary
        $comparison = $context.comparison
        $comparisonPath = $context.comparison_path
        $comparison.leak_scan = $finalLeak
        $comparison.verdict = 'FAIL'
        $comparison.failure_classification = $finalLeak.status
        $nativeSummary.leak_scan = $finalLeak
        $hybridSummary.leak_scan = $finalLeak
        $nativeSummary.verdict = if ($nativeSummary.verdict -eq 'PASS') { 'FAIL' } else { $nativeSummary.verdict }
        $hybridSummary.verdict = if ($hybridSummary.verdict -eq 'PASS') { 'FAIL' } else { $hybridSummary.verdict }
        Write-JsonFile -Path $nativeSummary.evidence_paths.summary_json -Value $nativeSummary
        Write-JsonFile -Path $hybridSummary.evidence_paths.summary_json -Value $hybridSummary
        Write-JsonFile -Path $comparisonPath -Value $comparison
    }
    Write-Report -Comparisons $comparisons.ToArray()
}
Write-Host "Stage 24 runner complete: report=$ReportPath runRoot=$RunRoot"
