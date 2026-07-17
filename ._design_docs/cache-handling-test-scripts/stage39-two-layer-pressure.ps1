#requires -Version 5
param(
    [Parameter(Mandatory)][string] $ModelPath,
    [string] $LlamaServerPath = 'build/bin/Release/llama-server.exe',
    [string] $RunRoot = '',
    [int] $Port = 8190,
    [int] $HotBudgetMiB = 1,
    [int] $ColdBudgetMiB = 2,
    [int] $Requests = 24,
    [int] $ContextSize = 2048,
    [Int64] $MeasuredResidentPairBytes = 0,
    [Int64] $MeasuredSerializedPairBytes = 0,
    [ValidateSet('standard', 'multi-victim', 'both-filled', 'oversized-both', 'cold-disabled', 'hot-zero', 'legacy')]
    [string] $Scenario = 'standard',
    [switch] $MetricValidationSelfTest,
    [switch] $MeasurementOnly
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
function Resolve-S39([string] $Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return [IO.Path]::GetFullPath((Join-Path $repo $Path))
}
function Metric-S39([string] $Text, [string] $Name) {
    return @($Text -split "`n" | Where-Object { $_ -match "^$([regex]::Escape($Name))" })
}
function Read-MetricsS39([string] $Text) {
    $samples = @{}
    foreach ($line in ($Text -split "`r?`n")) {
        if ($line -notmatch '^([^#\s][^\s]*)\s+([-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?)$') { continue }
        $samples[$Matches[1]] = [double]::Parse($Matches[2], [Globalization.CultureInfo]::InvariantCulture)
    }
    return $samples
}
function Sum-MetricS39([hashtable] $Samples, [string] $Family, [hashtable] $Labels = @{}) {
    $sum = 0.0
    foreach ($item in $Samples.GetEnumerator()) {
        if ($item.Key -ne $Family -and -not $item.Key.StartsWith($Family + '{')) { continue }
        $match = $true
        foreach ($label in $Labels.GetEnumerator()) {
            if ($item.Key -notmatch ("(?:\{|,)" + [regex]::Escape($label.Key) + '="' +
                    [regex]::Escape([string] $label.Value) + '"(?:,|})')) { $match = $false; break }
        }
        if ($match) { $sum += [double] $item.Value }
    }
    return $sum
}
function Get-PromptTokensS39([object] $Response) {
    if ($null -eq $Response.usage -or $null -eq $Response.usage.prompt_tokens) {
        throw 'SKIP-preflight-prompt-token-count'
    }
    return [int64] $Response.usage.prompt_tokens
}
function Assert-Tp3903TokenCapacityS39([int64[]] $SourceCounts, [int64[]] $IncomingCounts) {
    if ($SourceCounts.Count -ne 1 -or $SourceCounts[0] -ne 3631 -or
        $IncomingCounts.Count -ne 1 -or $IncomingCounts[0] -ne 3632) {
        throw 'SKIP-preflight-token-drift'
    }
    if ($SourceCounts[0] -gt [int64]::MaxValue - $IncomingCounts[0]) { throw 'SKIP-preflight-token-capacity' }
    $total = [int64] $SourceCounts[0] + [int64] $IncomingCounts[0]
    $margin = [int64] 8192 - $total
    if ($total -ne 7263 -or $margin -lt 929) { throw 'SKIP-preflight-token-capacity' }
    return [ordered]@{ source = 3631; incoming = 3632; total = $total; context = 8192; margin = $margin }
}
function Add-Tp3903CheckedS39([uint64] $Left, [uint64] $Right) {
    if ($Left -gt [uint64]::MaxValue - $Right) { throw 'SKIP-preflight-budget-overflow' }
    return [uint64] ($Left + $Right)
}
function Get-Tp3903LoweredBudgetsS39([object[]] $Rows) {
    if ($Rows.Count -ne 2) { throw 'SKIP-preflight-budget-shape' }
    $residentExact = [uint64] $Rows[0].resident_component_bytes
    $residentCheckpoint = [uint64] $Rows[1].resident_component_bytes
    $serializedExact = Add-Tp3903CheckedS39 $residentExact 64
    $serializedCheckpoint = Add-Tp3903CheckedS39 $residentCheckpoint 64
    $residentTotal = Add-Tp3903CheckedS39 $residentExact $residentCheckpoint
    $serializedTotal = Add-Tp3903CheckedS39 $serializedExact $serializedCheckpoint
    $hotBytes = $residentExact
    $coldBytes = if ($serializedExact -ge $serializedCheckpoint) { $serializedExact } else { $serializedCheckpoint }
    if ($hotBytes -eq 0 -or $coldBytes -eq 0 -or $hotBytes -ge $residentTotal -or
        $coldBytes -lt $serializedExact -or $coldBytes -lt $serializedCheckpoint -or
        $coldBytes -ge $serializedTotal) {
        throw 'SKIP-preflight-budget-inequalities'
    }
    return [ordered]@{
        hot_bytes = $hotBytes; cold_bytes = [uint64] $coldBytes
        resident_exact_bytes = $residentExact; resident_checkpoint_bytes = $residentCheckpoint
        serialized_exact_bytes = $serializedExact; serialized_checkpoint_bytes = $serializedCheckpoint
    }
}
function Get-Tp3903SourceRowS39([object] $Discover) {
    $hot = @($Discover.hot_candidates)
    $sets = @($Discover.cold_sets)
    if ($hot.Count -ne 1) { throw 'SKIP-preflight-tp39-03-eligible-source-count' }
    if ($sets.Count -ne 1 -or @($sets[0].candidates).Count -ne 0) { throw 'SKIP-preflight-tp39-03-cold-not-empty' }
    $source = $hot[0]
    if ($source.payload_kind -ne 'exact_blob' -or $source.residency -ne 'hot' -or
        -not [bool] $source.eligible -or [uint64] $source.payload_id -eq 0 -or
        [uint64] $source.owner_entry_id -eq 0 -or [uint64] $source.resident_bytes -eq 0 -or
        [uint64] $sets[0].incoming_payload_id -ne [uint64] $source.payload_id -or
        [uint64] $sets[0].incoming_owner_entry_id -ne [uint64] $source.owner_entry_id) {
        throw 'SKIP-preflight-tp39-03-source-row'
    }
    return $source
}
function Get-Tp3903ProofRowsS39([object] $Discover, [object] $Proof) {
    $source = Get-Tp3903SourceRowS39 $Discover
    $rows = @($Proof.rows)
    if ([uint64] $Proof.snapshot_generation -ne [uint64] $Discover.snapshot_generation -or
        [string]::IsNullOrWhiteSpace([string] $Proof.process_identity) -or
        ([string] $Proof.proof_token).Length -ne 64 -or $rows.Count -ne 2 -or
        ($rows.payload_kind -join ',') -ne 'exact_blob,checkpoint') {
        throw 'SKIP-preflight-tp39-03-proof-binding'
    }
    if ([uint64] $rows[0].payload_id -ne [uint64] $source.payload_id -or
        [uint64] $rows[0].payload_id -eq [uint64] $rows[1].payload_id -or
        [uint64] $rows[0].owner_entry_id -ne [uint64] $source.owner_entry_id -or
        [uint64] $rows[1].owner_entry_id -ne [uint64] $source.owner_entry_id -or
        [string] $rows[0].pair_state -ne [string] $rows[1].pair_state) {
        throw 'SKIP-preflight-tp39-03-proof-owner'
    }
    return $rows
}
function Get-Tp3903PreparedBindingsS39([object] $Discover, [object] $Proof) {
    $rows = @(Get-Tp3903ProofRowsS39 $Discover $Proof)
    foreach ($row in $rows) {
        $component = Add-Tp3903CheckedS39 ([uint64] $row.target_size_bytes) ([uint64] $row.draft_size_bytes)
        if ($row.residency -ne 'hot' -or -not [bool] $row.runtime_pair_matches -or
            -not [bool] $row.runtime_has_draft -or [uint64] $row.target_size_bytes -eq 0 -or
            [uint64] $row.draft_size_bytes -eq 0 -or $component -eq 0 -or
            $component -ne [uint64] $row.resident_component_bytes -or
            $component -ne [uint64] $row.resident_bytes) {
            throw 'SKIP-preflight-tp39-03-proof-component'
        }
    }
    return @($rows | ForEach-Object -Begin { $step = 0 } -Process {
        $step++
        [ordered]@{
            workload_role = 'canonical_same_owner'; request_number = 1; pressure_step = $step
            payload_id = [uint64] $_.payload_id; owner_entry_id = [uint64] $_.owner_entry_id
            payload_kind = [string] $_.payload_kind; pair_state = [string] $_.pair_state
            runtime_has_draft = [bool] $_.runtime_has_draft
            target_size_bytes = [uint64] $_.target_size_bytes; draft_size_bytes = [uint64] $_.draft_size_bytes
            target_checksum = [uint64] $_.target_checksum; draft_checksum = [uint64] $_.draft_checksum
        }
    })
}
function Assert-Tp3903RequestShapeS39([object] $Request) {
    $required = @('operation','scenario','hot_budget_bytes','cold_budget_bytes','snapshot_generation','snapshot_token',
        'incoming_payload_id','incoming_owner_entry_id','hot_candidates','cold_sets','desired_hot_orders','desired_cold_ranks',
        'tp39_03_setup','run_id','process_identity','proof_token','fault','prepared_bindings')
    $actual = @($Request.PSObject.Properties.Name)
    if ($actual.Count -ne $required.Count -or @($required | Where-Object { $actual -notcontains $_ }).Count -or
        $Request.operation -ne 'apply' -or $Request.scenario -ne 'tp39-03' -or
        $Request.tp39_03_setup -ne 'same_owner_kind_sequence' -or @($Request.desired_cold_ranks).Count -ne 0 -or
        @($Request.prepared_bindings).Count -ne 2) {
        throw 'TP-39-03 apply request schema mismatch'
    }
}
function Assert-Tp3903StableProofS39([object] $Discover, [object] $Proof,
        [object] $RepeatDiscover, [object] $RepeatProof) {
    if (($Discover | ConvertTo-Json -Depth 20 -Compress) -ne ($RepeatDiscover | ConvertTo-Json -Depth 20 -Compress) -or
        [uint64] $Proof.snapshot_generation -ne [uint64] $RepeatProof.snapshot_generation -or
        [string] $Proof.process_identity -ne [string] $RepeatProof.process_identity -or
        [string] $Proof.proof_token -ne [string] $RepeatProof.proof_token -or
        ($Proof.rows | ConvertTo-Json -Depth 20 -Compress) -ne ($RepeatProof.rows | ConvertTo-Json -Depth 20 -Compress)) {
        throw 'SKIP-preflight-tp39-03-generation-process-drift'
    }
}
function Get-Tp3903ExplicitProofRequestS39([object] $Discover, [object] $LinkedProof) {
    $rows = @(Get-Tp3903ProofRowsS39 $Discover $LinkedProof)
    return [ordered]@{
        operation = 'proof'; snapshot_generation = $Discover.snapshot_generation
        snapshot_token = $Discover.snapshot_token
        payload_ids = @([uint64] $rows[0].payload_id, [uint64] $rows[1].payload_id)
    }
}
function Protect-Tp3903ArtifactS39([object] $Value, [System.Collections.Generic.List[string]] $Secrets) {
    if ($null -eq $Value -or $Value -is [string] -or $Value.GetType().IsPrimitive) { return }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in @($Value.Keys)) {
            if ([string] $key -in @('snapshot_token', 'proof_token', 'terminal_hmac')) {
                if (-not [string]::IsNullOrEmpty([string] $Value[$key])) { $Secrets.Add([string] $Value[$key]) }
                $Value[$key] = '[redacted]'
            } else {
                Protect-Tp3903ArtifactS39 $Value[$key] $Secrets
            }
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) { Protect-Tp3903ArtifactS39 $item $Secrets }
        return
    }
    foreach ($property in @($Value.PSObject.Properties)) {
        if ($property.Name -in @('snapshot_token', 'proof_token', 'terminal_hmac')) {
            if (-not [string]::IsNullOrEmpty([string] $property.Value)) { $Secrets.Add([string] $property.Value) }
            $property.Value = '[redacted]'
        } else {
            Protect-Tp3903ArtifactS39 $property.Value $Secrets
        }
    }
}
function Write-Tp3903ProofArtifactS39([string] $Path, [object] $Value, [string[]] $AdditionalSecrets = @()) {
    $artifact = ($Value | ConvertTo-Json -Depth 20) | ConvertFrom-Json
    $secrets = [System.Collections.Generic.List[string]]::new()
    foreach ($secret in $AdditionalSecrets) {
        if (-not [string]::IsNullOrEmpty($secret)) { $secrets.Add($secret) }
    }
    Protect-Tp3903ArtifactS39 $artifact $secrets
    $json = ($artifact | ConvertTo-Json -Depth 20 -Compress) + "`n"
    foreach ($secret in $secrets) {
        if ($json.Contains($secret)) { throw 'TP-39-03 proof artifact leaked authenticated material' }
    }
    [IO.File]::WriteAllText($Path, $json, [Text.UTF8Encoding]::new($false))
}
function Get-Stage39SpecTypeBindingS39([string] $SelectedScenario) {
    if ($SelectedScenario -eq 'both-filled') { return @('--spec-type', 'draft-mtp') }
    return @()
}
function Assert-Stage39FinalSpecArgsS39([string] $SelectedScenario, [object[]] $Arguments) {
    $selectors = @($Arguments | Where-Object { [string] $_ -eq '--spec-type' })
    $aliases = @($Arguments | Where-Object {
        [string] $_ -in @('--mtp', '--spec-draft-model', '-md', '--model-draft') -or
        [string] $_ -like '--mtp=*' -or [string] $_ -like '--spec-draft-model=*' -or
        [string] $_ -like '-md=*' -or [string] $_ -like '--model-draft=*' -or
        [string] $_ -like '--spec-type=*'
    })
    if ($aliases.Count) { throw 'Stage 39 server argv contains a speculative selector alias' }
    if ($SelectedScenario -eq 'both-filled') {
        $index = [array]::IndexOf([object[]] $Arguments, '--spec-type')
        if ($selectors.Count -ne 1 -or $index -lt 0 -or $index + 1 -ge $Arguments.Count -or
            [string] $Arguments[$index + 1] -ne 'draft-mtp') {
            throw 'TP-39-03 server argv draft-mtp selector mismatch'
        }
        $templates = @($Arguments | Where-Object { [string] $_ -eq '--chat-template-file' })
        $templateIndex = [array]::IndexOf([object[]] $Arguments, '--chat-template-file')
        if ($templates.Count -ne 1 -or $templateIndex -lt 0 -or
            $templateIndex + 1 -ge $Arguments.Count -or
            [string]::IsNullOrWhiteSpace([string] $Arguments[$templateIndex + 1]) -or
            $index -ne $templateIndex + 2) {
            throw 'TP-39-03 server argv draft-mtp selector placement mismatch'
        }
    } elseif ($selectors.Count) {
        throw 'Non-TP-39-03 server argv contains draft-mtp selector'
    }
}
function Assert-Stage39SpecEnvironmentS39([string] $SelectedScenario) {
    if ($SelectedScenario -ne 'both-filled') { return }
    foreach ($name in @('LLAMA_ARG_SPEC_TYPE', 'LLAMA_ARG_SPEC_DRAFT_MODEL')) {
        if (Test-Path "Env:$name") {
            throw "TP-39-03 speculative environment override is not allowed: $name"
        }
    }
}
function Test-ByteEqualS39([byte[]] $Left, [byte[]] $Right) {
    if ($null -eq $Left -or $null -eq $Right -or $Left.Length -ne $Right.Length) { return $false }
    for ($i = 0; $i -lt $Left.Length; $i++) { if ($Left[$i] -ne $Right[$i]) { return $false } }
    return $true
}
function Test-PropertySetS39([object] $Object, [string[]] $Expected) {
    if ($null -eq $Object) { return $false }
    $actual = @($Object.PSObject.Properties.Name)
    return $actual.Count -eq $Expected.Count -and @($Expected | Where-Object { $actual -notcontains $_ }).Count -eq 0
}
function Get-WebBodyBytesS39([object] $Response) {
    $stream = $Response.RawContentStream
    if ($null -eq $stream -or -not $stream.CanSeek) { throw 'TP-39-03 raw HTTP body unavailable' }
    $position = $stream.Position
    $stream.Position = 0
    $copy = New-Object IO.MemoryStream
    try { $stream.CopyTo($copy); return $copy.ToArray() }
    finally { $stream.Position = $position; $copy.Dispose() }
}
function Get-JsonObjectPropertyBytesS39([byte[]] $JsonBytes, [string] $Property) {
    $needle = [Text.Encoding]::UTF8.GetBytes(('"' + $Property + '"'))
    $start = -1
    for ($i = 0; $i -le $JsonBytes.Length - $needle.Length; $i++) {
        $match = $true
        for ($j = 0; $j -lt $needle.Length; $j++) {
            if ($JsonBytes[$i + $j] -ne $needle[$j]) { $match = $false; break }
        }
        if ($match) { $start = $i + $needle.Length; break }
    }
    if ($start -lt 0) { throw "TP-39-03 raw property missing: $Property" }
    while ($start -lt $JsonBytes.Length -and [char] $JsonBytes[$start] -match '\s') { $start++ }
    if ($start -ge $JsonBytes.Length -or $JsonBytes[$start] -ne [byte][char] ':') { throw 'TP-39-03 raw property delimiter mismatch' }
    do { $start++ } while ($start -lt $JsonBytes.Length -and [char] $JsonBytes[$start] -match '\s')
    if ($start -ge $JsonBytes.Length -or $JsonBytes[$start] -ne [byte][char] '{') { throw 'TP-39-03 raw proof is not an object' }
    $depth = 0; $quoted = $false; $escaped = $false; $end = -1
    for ($i = $start; $i -lt $JsonBytes.Length; $i++) {
        $b = $JsonBytes[$i]
        if ($quoted) {
            if ($escaped) { $escaped = $false }
            elseif ($b -eq [byte][char] '\') { $escaped = $true }
            elseif ($b -eq [byte][char] '"') { $quoted = $false }
            continue
        }
        if ($b -eq [byte][char] '"') { $quoted = $true; continue }
        if ($b -eq [byte][char] '{') { $depth++ }
        elseif ($b -eq [byte][char] '}') { $depth--; if ($depth -eq 0) { $end = $i; break } }
    }
    if ($end -lt $start) { throw 'TP-39-03 raw proof object is incomplete' }
    $result = New-Object byte[] ($end - $start + 1)
    [Buffer]::BlockCopy($JsonBytes, $start, $result, 0, $result.Length)
    return $result
}
function Assert-Tp3903TerminalProofS39([object] $Apply, [object] $Request, [byte[]] $ApplyProofBytes,
        [object] $Retrieval, [string] $Log) {
    $proof = $Apply.prepared_proof
    $bindings = @($Request.prepared_bindings)
    $records = @($proof.records)
    if (-not [bool] $Apply.consumed -or $null -eq $proof -or $proof.status -ne 'success' -or
        $proof.process_identity -ne $Request.process_identity -or $proof.run_id -ne $Request.run_id -or
        [string]::IsNullOrWhiteSpace([string] $proof.test_session_id) -or
        ([string] $proof.terminal_hmac).Length -ne 64 -or $proof.fault -ne 'none' -or
        -not [string]::IsNullOrEmpty([string] $proof.error) -or @($proof.mismatch_flags).Count -ne 0 -or
        -not [bool] $proof.checkpoint_attempted -or -not [bool] $proof.checkpoint_prepared -or
        -not [bool] $proof.common_sync_observed -or $records.Count -ne 2 -or $bindings.Count -ne 2) {
        throw 'TP-39-03 terminal prepared proof shape mismatch'
    }
    if ([uint64] $proof.discovery_generation -ne [uint64] $Request.snapshot_generation -or
        [uint64] $proof.post_setup_generation -le [uint64] $proof.discovery_generation -or
        [uint64] $proof.exact_return_generation -lt [uint64] $proof.post_setup_generation -or
        [uint64] $proof.common_sync_generation -le [uint64] $proof.exact_return_generation -or
        [uint64] $proof.final_generation -lt [uint64] $proof.common_sync_generation) {
        throw 'TP-39-03 terminal generation chain mismatch'
    }
    for ($i = 0; $i -lt 2; $i++) {
        foreach ($field in @('workload_role','request_number','pressure_step','payload_id','owner_entry_id','payload_kind',
                'pair_state','runtime_has_draft','target_size_bytes','draft_size_bytes','target_checksum','draft_checksum')) {
            if ($records[$i].$field -ne $bindings[$i].$field) { throw 'TP-39-03 terminal ordered binding mismatch' }
        }
        if ([uint64] $records[$i].observed_generation -ne [uint64] $records[$i].expected_generation -or
            [uint64] $records[$i].serialized_bytes -ne
                (Add-Tp3903CheckedS39 (Add-Tp3903CheckedS39 ([uint64] $records[$i].target_size_bytes) ([uint64] $records[$i].draft_size_bytes)) 64) -or
            [uint64] $records[$i].staging_file_bytes -ne [uint64] $records[$i].serialized_bytes) {
            throw 'TP-39-03 terminal production observation mismatch'
        }
    }
    $state = $proof.terminal_state
    $exactId = [uint64] $bindings[0].payload_id; $checkpointId = [uint64] $bindings[1].payload_id
    $exactSerialized = [uint64] $records[0].serialized_bytes
    $exactDescriptor = Add-Tp3903CheckedS39 ([uint64] $records[0].target_size_bytes) ([uint64] $records[0].draft_size_bytes)
    $checkpointComponents = Add-Tp3903CheckedS39 ([uint64] $records[1].target_size_bytes) ([uint64] $records[1].draft_size_bytes)
    $residentAccounting = $state.resident_accounting
    $activeReferences = @($residentAccounting.active_reference_entries)
    if ([uint64] $state.entry.entry_id -ne [uint64] $bindings[0].owner_entry_id -or
        [uint64] $state.entry.exact_link -ne $exactId -or [uint64] $state.entry.checkpoint_link -ne 0 -or
        [uint64] $state.entry.resident_bytes -ne 0 -or [bool] $state.entry.has_target -or [bool] $state.entry.has_draft -or
        [uint64] $state.branch.branch_id -eq 0 -or
        [uint64] $state.branch.exact_link -ne $exactId -or [uint64] $state.branch.checkpoint_link -ne 0 -or
        [uint64] $state.branch.resident_bytes -ne 0 -or [bool] $state.branch.has_target -or
        [bool] $state.branch.has_draft -or [uint64] $state.branch.sync_count -ne 1 -or
        $state.exact_descriptor.residency -ne 'cold' -or [uint64] $state.exact_descriptor.payload_id -ne $exactId -or
        [uint64] $state.exact_descriptor.cold_file_bytes -ne $exactSerialized -or
        [uint64] $state.exact_descriptor.descriptor_bytes -ne $exactDescriptor -or
        [uint64] $state.exact_descriptor.byte_map_bytes -ne $exactSerialized -or
        $state.checkpoint_descriptor.residency -ne 'evicted' -or
        [uint64] $state.checkpoint_descriptor.payload_id -ne $checkpointId -or
        [uint64] $state.checkpoint_descriptor.resident_component_bytes -ne $checkpointComponents -or
        @($state.cold_inventory).Count -ne 1 -or $state.cold_inventory[0].name -ne ('{0:x}.cold' -f $exactId) -or
        [uint64] $state.cold_inventory[0].bytes -ne $exactSerialized -or
        $activeReferences.Count -ne 1 -or
        [uint64] $activeReferences[0].entry_id -eq [uint64] $state.entry.entry_id -or
        [uint64] $activeReferences[0].slot_reference_count -eq 0 -or
        [uint64] $activeReferences[0].resident_bytes -eq 0 -or
        [uint64] $activeReferences[0].resident_bytes -ne [uint64] $residentAccounting.total_resident_bytes -or
        [uint64] $residentAccounting.total_resident_bytes -le [uint64] $residentAccounting.hot_budget_bytes -or
        @($state.staging_inventory).Count -ne 0 -or [uint64] $state.topology.entry_count -eq 0 -or
        [uint64] $state.topology.node_count -eq 0 -or [uint64] $state.topology.lru_memberships -ne 0 -or
        [int64] $state.topology.entry_count_delta -ne 0 -or [int64] $state.topology.node_count_delta -ne 0 -or
        [int64] $state.topology.lru_membership_delta -ne -1 -or [int64] $state.topology.branch_prune_delta -ne 0 -or
        [uint64] $state.topology.later_victim_count -ne 0) {
        throw 'TP-39-03 authenticated terminal state mismatch'
    }
    $exactDecision = @($state.decision_deltas | Where-Object { $_.mode -eq 'hybrid' -and
        $_.result -eq 'retained_cold' -and $_.reason -eq 'cold_room' })
    $checkpointDecision = @($state.decision_deltas | Where-Object { $_.mode -eq 'hybrid' -and
        $_.result -eq 'evicted' -and $_.reason -eq 'both_filled' })
    if (@($state.decision_deltas).Count -ne 2 -or $exactDecision.Count -ne 1 -or
        [uint64] $exactDecision[0].value -ne 1 -or $checkpointDecision.Count -ne 1 -or
        [uint64] $checkpointDecision[0].value -ne 1 -or @($state.transaction_deltas).Count -ne 1 -or
        $state.transaction_deltas[0].mode -ne 'hybrid' -or $state.transaction_deltas[0].result -ne 'commit' -or
        $state.transaction_deltas[0].reason -ne 'none' -or [uint64] $state.transaction_deltas[0].value -ne 1 -or
        @($state.diagnostic_deltas.PSObject.Properties).Count -ne 0) {
        throw 'TP-39-03 terminal decision transaction or diagnostic mismatch'
    }
    $observed = $state.forbidden_observations
    $beforeFile = $observed.checkpoint_cold_file.before; $afterFile = $observed.checkpoint_cold_file.after
    $beforeDescriptor = $observed.checkpoint_descriptor.before; $afterDescriptor = $observed.checkpoint_descriptor.after
    $descriptorFields = @('payload_id','owner_entry_id','payload_kind','residency','store_ref','target_size_bytes',
        'draft_size_bytes','target_checksum','draft_checksum','resident_payload_bytes','pair_state')
    if (-not (Test-PropertySetS39 $observed @('checkpoint_cold_file','checkpoint_descriptor','checkpoint_link')) -or
        -not (Test-PropertySetS39 $observed.checkpoint_cold_file @('before','after','event_delta')) -or
        -not (Test-PropertySetS39 $observed.checkpoint_descriptor @('before','after','event_delta')) -or
        -not (Test-PropertySetS39 $observed.checkpoint_link @('before','after','event_delta')) -or
        -not (Test-PropertySetS39 $beforeFile @('exists','name','bytes')) -or
        -not (Test-PropertySetS39 $afterFile @('exists','name','bytes')) -or
        -not (Test-PropertySetS39 $beforeDescriptor $descriptorFields) -or
        -not (Test-PropertySetS39 $afterDescriptor $descriptorFields) -or
        [bool] $beforeFile.exists -or [bool] $afterFile.exists -or
        $beforeFile.name -ne ('{0:x}.cold' -f $checkpointId) -or $afterFile.name -ne $beforeFile.name -or
        [uint64] $beforeFile.bytes -ne 0 -or [uint64] $afterFile.bytes -ne 0 -or
        [uint64] $observed.checkpoint_cold_file.event_delta -ne 0 -or
        [uint64] $beforeDescriptor.payload_id -ne $checkpointId -or
        [uint64] $beforeDescriptor.owner_entry_id -ne [uint64] $bindings[1].owner_entry_id -or
        $beforeDescriptor.payload_kind -ne 'checkpoint' -or $beforeDescriptor.residency -ne 'hot' -or
        [uint64] $beforeDescriptor.store_ref -ne $checkpointId -or
        [uint64] $beforeDescriptor.target_size_bytes -ne [uint64] $records[1].target_size_bytes -or
        [uint64] $beforeDescriptor.draft_size_bytes -ne [uint64] $records[1].draft_size_bytes -or
        [uint64] $beforeDescriptor.target_checksum -ne [uint64] $records[1].target_checksum -or
        [uint64] $beforeDescriptor.draft_checksum -ne [uint64] $records[1].draft_checksum -or
        [uint64] $beforeDescriptor.resident_payload_bytes -ne $checkpointComponents -or
        $beforeDescriptor.pair_state -ne 'target_and_draft' -or
        [uint64] $afterDescriptor.payload_id -ne $checkpointId -or
        [uint64] $afterDescriptor.owner_entry_id -ne [uint64] $beforeDescriptor.owner_entry_id -or
        $afterDescriptor.payload_kind -ne 'checkpoint' -or $afterDescriptor.residency -ne 'evicted' -or
        [uint64] $afterDescriptor.store_ref -ne [uint64] $beforeDescriptor.store_ref -or
        [uint64] $afterDescriptor.target_size_bytes -ne [uint64] $beforeDescriptor.target_size_bytes -or
        [uint64] $afterDescriptor.draft_size_bytes -ne [uint64] $beforeDescriptor.draft_size_bytes -or
        [uint64] $afterDescriptor.target_checksum -ne [uint64] $beforeDescriptor.target_checksum -or
        [uint64] $afterDescriptor.draft_checksum -ne [uint64] $beforeDescriptor.draft_checksum -or
        [uint64] $afterDescriptor.resident_payload_bytes -ne 0 -or $afterDescriptor.pair_state -ne $beforeDescriptor.pair_state -or
        [uint64] $observed.checkpoint_descriptor.event_delta -ne 1 -or
        [uint64] $observed.checkpoint_link.before -ne $checkpointId -or [uint64] $observed.checkpoint_link.after -ne 0 -or
        [uint64] $observed.checkpoint_link.event_delta -ne 1) {
        throw 'TP-39-03 terminal forbidden observation mismatch'
    }
    $effects = $state.forbidden_effects
    $effectExpected = [ordered]@{
        checkpoint_classification_delta=1; checkpoint_admission_delta=0; checkpoint_publish_delta=0
        checkpoint_commit_delta=0; checkpoint_cold_file_delta=0; checkpoint_descriptor_mutation_delta=1
        checkpoint_link_mutation_delta=1; checkpoint_decision_delta=0; checkpoint_diagnostic_delta=0
        later_work_delta=0; later_victim_delta=0; explicit_generation_advance_delta=0
        later_kind_work_delta=0; post_abort_pressure_delta=0; post_abort_diagnostic_delta=0
        duplicate_sync_delta=0; success_snapshot_count=0; failed_apply_count=1
    }
    if (-not (Test-PropertySetS39 $effects @($effectExpected.Keys))) {
        throw 'TP-39-03 terminal forbidden effect mismatch'
    }
    foreach ($item in $effectExpected.GetEnumerator()) {
        if ($effects.PSObject.Properties.Name -notcontains $item.Key -or [uint64] $effects.($item.Key) -ne [uint64] $item.Value) {
            throw 'TP-39-03 terminal forbidden effect mismatch'
        }
    }
    if (-not [bool] $Retrieval.consumed -or -not [bool] $Retrieval.retry_rejected) {
        throw 'TP-39-03 terminal retrieval consumption mismatch'
    }
    if (-not (Test-ByteEqualS39 $ApplyProofBytes ([byte[]] $Retrieval.body_bytes))) {
        throw 'TP-39-03 retrieved terminal proof is not byte-equivalent'
    }
    foreach ($secret in @([string] $Request.snapshot_token, [string] $Request.proof_token,
            [string] $proof.terminal_hmac)) {
        if ($Log -match [regex]::Escape($secret)) { throw 'TP-39-03 authenticated material leaked into log' }
    }
}
function Get-ColdInventoryS39([string] $Root) {
    return ,@(Get-ChildItem $Root -File -Recurse | Sort-Object FullName | ForEach-Object {
        [pscustomobject]@{
            Path = $_.FullName.Substring($Root.Length).TrimStart('\', '/')
            Length = $_.Length
            LastWriteTimeUtc = $_.LastWriteTimeUtc.ToString('o')
        }
    })
}
function Normalize-ColdInventoryS39([object] $Rows) {
    if ($null -eq $Rows) { return ,@() }
    return ,@($Rows | Where-Object { $null -ne $_ })
}
function Assert-Tp3903FinalColdInventoryS39([object[]] $ColdAfter, [uint64] $ExactId, [uint64] $CheckpointId) {
    $payloadRows = @($ColdAfter | Where-Object Path -Match '^[0-9a-fA-F]+\.cold$')
    $exactName = ('{0:x}.cold' -f $ExactId)
    $checkpointName = ('{0:x}.cold' -f $CheckpointId)
    if (@($payloadRows | Where-Object Path -eq $exactName).Count -ne 1 -or
        @($payloadRows | Where-Object Path -eq $checkpointName).Count -or
        $payloadRows.Count -ne 1) {
        throw 'TP-39-03 exact-cold/checkpoint-evicted payload inventory mismatch'
    }
    foreach ($row in $ColdAfter) {
        $path = [string] $row.Path
        if ($path -match '^[0-9a-fA-F]+\.cold$' -or $path -eq 'ownership.claims') { continue }
        if ($path -match '(^|[\\/])staging([\\/]|$)|(^|[\\/])temp([\\/]|$)|\.tmp$|\.staging$') {
            throw "TP-39-03 cold-root staging/temp leftover: $path"
        }
        if ($path -match '(^|[\\/])quarantine([\\/]|$)|\.q\.\d+$') {
            throw "TP-39-03 cold-root quarantine leftover: $path"
        }
        if ($path -match '(^|[\\/])manifest([^\\/]*$|[\\/])|\.manifest$') {
            throw "TP-39-03 cold-root manifest leftover: $path"
        }
        throw "TP-39-03 unexpected cold-root file: $path"
    }
}
function Write-ColdInventoryS39([object[]] $Rows, [string] $Path) {
    $Rows = Normalize-ColdInventoryS39 $Rows
    if ($Rows.Count) {
        $Rows | Export-Csv $Path -NoTypeInformation
    } else {
        [IO.File]::WriteAllText($Path, '"Path","Length","LastWriteTimeUtc"' + "`n", [Text.UTF8Encoding]::new($false))
    }
}
function Invoke-Stage39DiscoverS39([string] $Uri, [hashtable] $Headers, [string] $Body) {
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    while ($true) {
        try {
            return Invoke-WebRequest $Uri -Method Post -Headers $Headers -Body $Body `
                -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
        } catch {
            $detail = [string] $_.ErrorDetails.Message
            if ($detail -notmatch 'Stage 39 control requires idle slots' -or [DateTime]::UtcNow -ge $deadline) {
                throw
            }
            Start-Sleep -Milliseconds 50
        }
    }
}
function Get-Stage39WorkloadS39([string] $SelectedScenario, [int] $RequestedCount) {
    if ($SelectedScenario -eq 'multi-victim') {
        return @(
            [ordered]@{ role = 'cold-victim-1'; admit = $true; fill_tokens = 40; prompt = "stage39 cold victim 1 " + ('x ' * 40); n_predict = 1; temperature = 0 }
            [ordered]@{ role = 'cold-victim-2'; admit = $true; fill_tokens = 41; prompt = "stage39 cold victim 2 " + ('x ' * 41); n_predict = 1; temperature = 0 }
            [ordered]@{ role = 'hot-incoming'; admit = $true; fill_tokens = 72; prompt = "stage39 hot incoming " + ('x ' * 72); n_predict = 1; temperature = 0 }
        )
    }
    if ($SelectedScenario -eq 'both-filled') {
        $base = @(
            [ordered]@{ role = 'system'; content = 'S|' + ('shared-system-0123456789abcdef|' * 8) }
            [ordered]@{ role = 'user'; content = 'U1|' + ('alpha-0001|' * 64) }
            [ordered]@{ role = 'assistant'; content = 'A1|' + ('bravo-0002|' * 32) }
            [ordered]@{ role = 'user'; content = 'U2|' + ('charlie-0003|' * 64) }
            [ordered]@{ role = 'assistant'; content = 'A2|' + ('delta-0004|' * 32) }
            [ordered]@{ role = 'user'; content = 'U3|' + ('echo-0005|' * 64) }
            [ordered]@{ role = 'assistant'; content = 'A3|' + ('foxtrot-0006|' * 32) }
            [ordered]@{ role = 'user'; content = 'U4|' + ('golf-0007|' * 64) }
            [ordered]@{ role = 'assistant'; content = 'A4|' + ('hotel-0008|' * 32) }
        )
        $expected = @(250, 707, 355, 835, 355, 643, 419, 643, 355)
        for ($i = 0; $i -lt $base.Count; $i++) {
            if ($base[$i].content.Length -ne $expected[$i]) { throw "TP-39-03 literal content length mismatch at $i" }
        }
        $make = {
            param([string] $Suffix, [int] $MaxTokens, [string] $Role)
            $messages = @($base | ForEach-Object { [ordered]@{ role = $_.role; content = $_.content } })
            $messages += [ordered]@{ role = 'user'; content = 'U5|' + ('india-0009|' * 64) + $Suffix }
            $want = if ($Suffix -eq 'suffix-source|') { 721 } else { 723 }
            if ($messages[9].content.Length -ne $want) { throw "TP-39-03 literal U5 length mismatch for $Role" }
            [ordered]@{
                role = $Role; admit = $true; chat = $true
                body = [ordered]@{ model = 'Qwen3.5-4B'; messages = $messages; max_tokens = $MaxTokens; temperature = 0; seed = 42; stream = $false }
            }
        }
        $source = & $make 'suffix-source|' 32 'source'
        $incoming = & $make 'suffix-incoming|' 1 'incoming'
        return @($source, $incoming)
    }
    $rows = @()
    for ($i = 0; $i -lt $RequestedCount; $i++) {
        $rows += [ordered]@{
            role = "pressure-$i"; admit = $true; fill_tokens = 64 + $i
            prompt = "stage39 pressure row $i " + ('x ' * (64 + $i)); n_predict = 1; temperature = 0
        }
    }
    return $rows
}
function Assert-Stage39MetricRowsS39([string] $Scenario, [object[]] $Decisions, [object[]] $Transactions) {
    if ($Scenario -in @('hot-zero', 'legacy')) {
        if ($Decisions -or $Transactions) { throw "Stage 39 rows emitted for $Scenario" }
        return
    }
    foreach ($line in @($Decisions + $Transactions | Where-Object { $null -ne $_ })) {
        if ($line -notmatch '^([^\{]+)\{([^}]*)\}') { throw "Malformed Stage 39 metric row: $line" }
        $labelNames = @($Matches[2] -split ',' | ForEach-Object {
            if ($_ -notmatch '^([^=]+)=') { throw "Malformed Stage 39 metric label: $_" }
            $Matches[1]
        })
        if (@($labelNames | Sort-Object -Unique).Count -ne $labelNames.Count) {
            throw "Duplicate Stage 39 metric label name: $line"
        }
    }
}
function Assert-Tp3903StartupProofS39([string] $Log) {
    foreach ($literal in @(
            'speculative decoding context initialized',
            'context checkpoints enabled, max = 32, min spacing = 0',
            'created context checkpoint')) {
        if ($Log.IndexOf($literal, [StringComparison]::Ordinal) -lt 0) {
            throw 'SKIP-preflight-checkpoint-startup-proof'
        }
    }
}
function Invoke-Stage39MetricValidationSelfTestS39 {
    $startupProof = @(
        'speculative decoding context initialized',
        'context checkpoints enabled, max = 32, min spacing = 0',
        'created context checkpoint') -join "`n"
    Assert-Tp3903StartupProofS39 $startupProof
    $startupProofNegativeCases = @(
        "speculative decoding will use checkpoints`ncontext checkpoints enabled, max = 32, min spacing = 0`ncreated context checkpoint",
        "speculative decoding arbitrary context initialized`ncontext checkpoints enabled, max = 32, min spacing = 0`ncreated context checkpoint",
        "speculative decoding will use checkpoints`nSpeculative decoding context initialized`ncontext checkpoints enabled, max = 32, min spacing = 0`ncreated context checkpoint",
        "server became ready after 10 ms`ncontext checkpoints enabled, max = 32, min spacing = 0`ncreated context checkpoint",
        "speculative decoding context initialized`ncreated context checkpoint",
        "speculative decoding context initialized`ncontext checkpoints enabled, max = 32, min spacing = 0")
    foreach ($case in $startupProofNegativeCases) {
        try {
            Assert-Tp3903StartupProofS39 $case
            throw 'TP-39-03 startup-proof negative self-test accepted invalid data'
        } catch {
            if ($_.Exception.Message -eq 'TP-39-03 startup-proof negative self-test accepted invalid data') { throw }
        }
    }
    $allScenarios = @('standard', 'multi-victim', 'both-filled', 'oversized-both', 'cold-disabled', 'hot-zero', 'legacy')
    foreach ($selected in $allScenarios) {
        $scenarioArgs = if ($selected -eq 'both-filled') {
            @('llama-server', '--chat-template-file', 'template') + @(Get-Stage39SpecTypeBindingS39 $selected)
        } else {
            @('llama-server') + @(Get-Stage39SpecTypeBindingS39 $selected)
        }
        Assert-Stage39FinalSpecArgsS39 $selected $scenarioArgs
        if ($selected -eq 'both-filled') {
            if (($scenarioArgs -join ' ') -ne 'llama-server --chat-template-file template --spec-type draft-mtp') {
                throw 'TP-39-03 exact argv binding self-test mismatch'
            }
        } elseif (@($scenarioArgs | Where-Object { $_ -eq '--spec-type' }).Count) {
            throw 'Non-TP-39-03 argv binding self-test mismatch'
        }
    }
    $argvNegativeCases = @(
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--spec-type', 'draft-mtp', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--mtp', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--spec-draft-model', 'draft.gguf', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--spec-draft-model=draft.gguf', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '-md', 'draft.gguf', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '-md=draft.gguf', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--model-draft', 'draft.gguf', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--model-draft=draft.gguf', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--spec-type=draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--spec-type', 'draft-mtp') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--chat-template-file', 'one', '--spec-type', 'draft-mtp', '--chat-template-file', 'two') },
        { Assert-Stage39FinalSpecArgsS39 'both-filled' @('llama-server', '--spec-type', 'draft-mtp', '--chat-template-file', 'template') },
        { Assert-Stage39FinalSpecArgsS39 'standard' @('llama-server', '--spec-type', 'draft-mtp') }
    )
    foreach ($case in $argvNegativeCases) {
        try { & $case; throw 'Stage 39 argv negative self-test accepted invalid data' }
        catch { if ($_.Exception.Message -eq 'Stage 39 argv negative self-test accepted invalid data') { throw } }
    }
    $specEnvironmentNames = @('LLAMA_ARG_SPEC_TYPE', 'LLAMA_ARG_SPEC_DRAFT_MODEL')
    $savedSpecEnvironment = @{}
    foreach ($name in $specEnvironmentNames) {
        $savedSpecEnvironment[$name] = [ordered]@{
            present = Test-Path "Env:$name"
            value = [Environment]::GetEnvironmentVariable($name, 'Process')
        }
        Remove-Item "Env:$name" -ErrorAction SilentlyContinue
    }
    try {
        foreach ($name in $specEnvironmentNames) {
            Set-Item "Env:$name" 'stage39-self-test-override'
            try {
                Assert-Stage39SpecEnvironmentS39 'both-filled'
                throw 'Stage 39 environment negative self-test accepted invalid data'
            } catch {
                if ($_.Exception.Message -eq 'Stage 39 environment negative self-test accepted invalid data') { throw }
            } finally {
                Remove-Item "Env:$name" -ErrorAction SilentlyContinue
            }
        }
        foreach ($name in $specEnvironmentNames) { Set-Item "Env:$name" 'stage39-non-tp39-03-allowed' }
        Assert-Stage39SpecEnvironmentS39 'standard'
    } finally {
        foreach ($name in $specEnvironmentNames) {
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
            if ($savedSpecEnvironment[$name].present) {
                Set-Item "Env:$name" $savedSpecEnvironment[$name].value
            }
        }
    }
    Assert-Stage39MetricRowsS39 'hot-zero' @() @()
    Assert-Stage39MetricRowsS39 'legacy' @() @()
    Assert-Stage39MetricRowsS39 'standard' @('decision{mode="hybrid",result="retained_cold"} 1') `
        @('transaction{mode="hybrid",result="commit"} 1')
    try {
        Assert-Stage39MetricRowsS39 'standard' @('malformed-row') @()
        throw 'Self-test accepted a malformed Stage 39 metric row'
    } catch {
        if ($_.Exception.Message -notlike 'Malformed Stage 39 metric row:*') { throw }
    }
    try {
        Assert-Stage39MetricRowsS39 'standard' @('decision{mode="hybrid",broken} 1') @()
        throw 'Self-test accepted a malformed Stage 39 metric label'
    } catch {
        if ($_.Exception.Message -notlike 'Malformed Stage 39 metric label:*') { throw }
    }
    $tp3902 = @(Get-Stage39WorkloadS39 'multi-victim' 99)
    $tp3902Admissions = @($tp3902 | Where-Object admit)
    if ($tp3902.Count -ne 3 -or $tp3902Admissions.Count -ne 3 -or
        ($tp3902Admissions.role -join ',') -ne 'cold-victim-1,cold-victim-2,hot-incoming' -or
        $tp3902Admissions[0].fill_tokens -ge $tp3902Admissions[2].fill_tokens -or
        $tp3902Admissions[1].fill_tokens -ge $tp3902Admissions[2].fill_tokens) {
        throw 'TP-39-02 workload shape is not two smaller victims followed by one larger incoming pair'
    }
    $tp3903 = @(Get-Stage39WorkloadS39 'both-filled' 99)
    if ($tp3903.Count -ne 2 -or ($tp3903.role -join ',') -ne 'source,incoming' -or
        $tp3903[0].body.messages.Count -ne 10 -or $tp3903[1].body.messages.Count -ne 10 -or
        $tp3903[0].body.messages[9].content.Length -ne 721 -or
        $tp3903[1].body.messages[9].content.Length -ne 723 -or
        $tp3903[0].body.max_tokens -ne 32 -or $tp3903[1].body.max_tokens -ne 1) {
        throw 'TP-39-03 literal MTP workload mismatch'
    }
    $capacity = Assert-Tp3903TokenCapacityS39 @(3631) @(3632)
    if ($capacity.total -ne 7263 -or $capacity.margin -ne 929) { throw 'TP-39-03 token capacity self-test mismatch' }
    $proofRows = @(
        [pscustomobject]@{ payload_id=101; owner_entry_id=11; payload_kind='exact_blob'; pair_state='target_draft'; residency='hot'; runtime_has_draft=$true; runtime_pair_matches=$true; target_size_bytes=40; draft_size_bytes=10; target_checksum=1; draft_checksum=2; resident_component_bytes=50; resident_bytes=50 }
        [pscustomobject]@{ payload_id=102; owner_entry_id=11; payload_kind='checkpoint'; pair_state='target_draft'; residency='hot'; runtime_has_draft=$true; runtime_pair_matches=$true; target_size_bytes=41; draft_size_bytes=10; target_checksum=3; draft_checksum=4; resident_component_bytes=51; resident_bytes=51 }
    )
    $discovery = [pscustomobject]@{ snapshot_generation=7; snapshot_token=('b' * 64); hot_candidates=@([pscustomobject]@{ payload_id=101; owner_entry_id=11; payload_kind='exact_blob'; residency='hot'; eligible=$true; resident_bytes=50 }); cold_sets=@([pscustomobject]@{ incoming_payload_id=101; incoming_owner_entry_id=11; candidates=@() }) }
    $proof = [pscustomobject]@{ snapshot_generation=7; process_identity='process'; proof_token=('a' * 64); rows=$proofRows }
    $bindings = @(Get-Tp3903PreparedBindingsS39 $discovery $proof)
    $lowered = Get-Tp3903LoweredBudgetsS39 $proofRows
    if ($bindings.Count -ne 2 -or $lowered.hot_bytes -ne 50 -or $lowered.cold_bytes -ne 115) { throw 'TP-39-03 proof/budget self-test mismatch' }
    $negativeCases = @(
        { $x = $discovery.PSObject.Copy(); $x.hot_candidates = @($discovery.hot_candidates[0], [pscustomobject]@{ payload_id=201; owner_entry_id=21; payload_kind='exact_blob'; residency='hot'; eligible=$true; resident_bytes=60 }); $x.cold_sets = @($discovery.cold_sets[0], [pscustomobject]@{ incoming_payload_id=201; incoming_owner_entry_id=21; candidates=@() }); Get-Tp3903SourceRowS39 $x },
        { $x = $discovery.PSObject.Copy(); $x.cold_sets = @([pscustomobject]@{ incoming_payload_id=101; incoming_owner_entry_id=11; candidates=@([pscustomobject]@{ payload_id=9 }) }); Get-Tp3903SourceRowS39 $x },
        { $x = $proof.PSObject.Copy(); $x.rows = @($proofRows[0]); Get-Tp3903PreparedBindingsS39 $discovery $x },
        { $x = $proof.PSObject.Copy(); $x.rows = @($proofRows[1], $proofRows[0]); Get-Tp3903PreparedBindingsS39 $discovery $x },
        { $x = $proof.PSObject.Copy(); $rows = @($proofRows[0].PSObject.Copy(), $proofRows[1].PSObject.Copy()); $rows[1].owner_entry_id=12; $x.rows=$rows; Get-Tp3903PreparedBindingsS39 $discovery $x },
        { $x = $proof.PSObject.Copy(); $rows = @($proofRows[0].PSObject.Copy(), $proofRows[1].PSObject.Copy()); $rows[1].draft_size_bytes=0; $x.rows=$rows; Get-Tp3903PreparedBindingsS39 $discovery $x },
        { $x = $proof.PSObject.Copy(); $x.snapshot_generation=8; Get-Tp3903PreparedBindingsS39 $discovery $x },
        { $x = $proof.PSObject.Copy(); $x.process_identity=''; Get-Tp3903PreparedBindingsS39 $discovery $x }
    )
    foreach ($case in $negativeCases) {
        try { & $case | Out-Null; throw 'TP-39-03 negative self-test accepted invalid data' }
        catch { if ($_.Exception.Message -eq 'TP-39-03 negative self-test accepted invalid data') { throw } }
    }
    Assert-Tp3903StableProofS39 $discovery $proof $discovery $proof
    $explicitProofRequest = Get-Tp3903ExplicitProofRequestS39 $discovery $proof
    if (($explicitProofRequest.payload_ids -join ',') -ne '101,102') { throw 'TP-39-03 explicit proof ID self-test mismatch' }
    $artifactRoot = Join-Path ([IO.Path]::GetTempPath()) ('stage39-proof-artifacts-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $artifactRoot | Out-Null
    try {
        $badRows = @($proofRows[0].PSObject.Copy(), $proofRows[1].PSObject.Copy())
        $badRows[1].draft_size_bytes = 0
        $badProof = $proof.PSObject.Copy()
        $badProof.proof_token = ('c' * 64)
        $badProof.rows = $badRows
        $badProof | Add-Member -NotePropertyName terminal_hmac -NotePropertyValue ('d' * 64)
        $linkedRequest = [ordered]@{
            operation='proof'; snapshot_generation=$discovery.snapshot_generation
            snapshot_token=('b' * 64); payload_ids=@(101)
        }
        $badExplicitRequest = Get-Tp3903ExplicitProofRequestS39 $discovery $badProof
        Write-Tp3903ProofArtifactS39 (Join-Path $artifactRoot 'control-linked-proof-request.json') $linkedRequest
        Write-Tp3903ProofArtifactS39 (Join-Path $artifactRoot 'control-linked-proof-response.json') $badProof
        Write-Tp3903ProofArtifactS39 (Join-Path $artifactRoot 'control-explicit-proof-request.json') $badExplicitRequest
        Write-Tp3903ProofArtifactS39 (Join-Path $artifactRoot 'control-explicit-proof-response.json') $badProof
        try {
            Get-Tp3903PreparedBindingsS39 $discovery $badProof | Out-Null
            throw 'TP-39-03 artifact self-test accepted invalid component'
        } catch {
            if ($_.Exception.Message -ne 'SKIP-preflight-tp39-03-proof-component') { throw }
        }
        $artifactFiles = @(Get-ChildItem $artifactRoot -File)
        $artifactText = [string]::Join("`n", @($artifactFiles | ForEach-Object { Get-Content $_.FullName -Raw }))
        if ($artifactFiles.Count -ne 4 -or $artifactText -match ('b' * 64) -or
            $artifactText -match ('c' * 64) -or $artifactText -match ('d' * 64) -or
            $artifactText -notmatch '"snapshot_token":"\[redacted\]"' -or
            $artifactText -notmatch '"proof_token":"\[redacted\]"' -or
            $artifactText -notmatch '"terminal_hmac":"\[redacted\]"') {
            throw 'TP-39-03 proof artifact preservation or redaction self-test mismatch'
        }
    } finally {
        Remove-Item -LiteralPath $artifactRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $staleProcess = $proof.PSObject.Copy(); $staleProcess.process_identity = 'other-process'
    try { Assert-Tp3903StableProofS39 $discovery $proof $discovery $staleProcess; throw 'TP-39-03 stale-process self-test accepted invalid proof' }
    catch { if ($_.Exception.Message -eq 'TP-39-03 stale-process self-test accepted invalid proof') { throw } }
    $requestShape = [pscustomobject][ordered]@{
        operation='apply'; scenario='tp39-03'; hot_budget_bytes=50; cold_budget_bytes=115
        snapshot_generation=7; snapshot_token=('b' * 64); incoming_payload_id=101; incoming_owner_entry_id=11
        hot_candidates=$discovery.hot_candidates; cold_sets=$discovery.cold_sets
        desired_hot_orders=@([pscustomobject]@{ owner_entry_id=11; desired_hot_order=1000 }); desired_cold_ranks=@()
        tp39_03_setup='same_owner_kind_sequence'; run_id='pure'; process_identity='process'; proof_token=('a' * 64)
        fault='none'; prepared_bindings=$bindings
    }
    Assert-Tp3903RequestShapeS39 $requestShape
    $tp3903MetricsBefore = @'
llamacpp:cache_entries{mode="hybrid"} 1
llamacpp:cache_namespace_nodes{mode="hybrid"} 1
llamacpp:cache_branch_pruning_total{mode="hybrid"} 0
llamacpp:cache_cold_bytes{mode="hybrid"} 0
llamacpp:cache_cold_payload_bytes{mode="hybrid"} 0
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="retained_cold",reason="cold_room"} 0
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="evicted",reason="both_filled"} 0
llamacpp:cache_evicted_payload_descriptors{mode="hybrid"} 0
llamacpp:cache_payload_evictions_total{mode="hybrid"} 0
llamacpp:cache_hot_payload_descriptors{mode="hybrid"} 2
llamacpp:cache_cold_payload_count{mode="hybrid"} 0
llamacpp:cache_cold_transactions_total{mode="hybrid",result="commit",reason="none"} 0
'@
    $tp3903MetricsAfter = @'
llamacpp:cache_entries{mode="hybrid"} 1
llamacpp:cache_namespace_nodes{mode="hybrid"} 1
llamacpp:cache_branch_pruning_total{mode="hybrid"} 0
llamacpp:cache_cold_bytes{mode="hybrid"} 114
llamacpp:cache_cold_payload_bytes{mode="hybrid"} 114
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="retained_cold",reason="cold_room"} 1
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="evicted",reason="both_filled"} 1
llamacpp:cache_evicted_payload_descriptors{mode="hybrid"} 1
llamacpp:cache_payload_evictions_total{mode="hybrid"} 1
llamacpp:cache_hot_payload_descriptors{mode="hybrid"} 0
llamacpp:cache_cold_payload_count{mode="hybrid"} 1
llamacpp:cache_cold_transactions_total{mode="hybrid",result="commit",reason="none"} 1
'@
    $tp3903Apply = [pscustomobject]@{
        scenario='tp39-03'; consumed=$true; pressure_completed=$true
        before_generation=7; after_generation=8
        before=[pscustomobject]@{ hot_candidates=$discovery.hot_candidates; cold_sets=$discovery.cold_sets }
        after=[pscustomobject]@{ hot_candidates=@(); cold_sets=$discovery.cold_sets }
    }
    $tp3903ColdAfterRow = [pscustomobject]@{ Path='65.cold'; Length=114; LastWriteTimeUtc='2026-07-17T00:00:00.0000000Z' }
    $tp3903OwnershipRow = [pscustomobject]@{ Path='ownership.claims'; Length=184; LastWriteTimeUtc='2026-07-17T00:00:01.0000000Z' }
    $tp3903Log = "event=cache_two_layer_decision result=retained_cold reason=cold_room payload_id=101`n" +
        "event=cache_cold_transaction result=commit reason=none tx_id=17`n" +
        'event=cache_two_layer_decision result=evicted reason=both_filled payload_id=102'
    $inventoryRoot = Join-Path ([IO.Path]::GetTempPath()) ('stage39-empty-inventory-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory $inventoryRoot | Out-Null
    try {
        $headerOnlyPath = Join-Path $inventoryRoot 'header-only.csv'
        Write-ColdInventoryS39 @() $headerOnlyPath
        $headerOnlyRows = Import-Csv $headerOnlyPath
        if ($null -ne $headerOnlyRows -or (Normalize-ColdInventoryS39 $headerOnlyRows).Count -ne 0) {
            throw 'TP-39-03 header-only cold inventory self-test mismatch'
        }
        Assert-Tp3903 $discovery $tp3903Apply $requestShape $tp3903MetricsBefore $tp3903MetricsAfter `
            $headerOnlyRows @($null, $tp3903ColdAfterRow) $tp3903Log
        Assert-Tp3903 $discovery $tp3903Apply $requestShape $tp3903MetricsBefore $tp3903MetricsAfter `
            $null @($null, $tp3903ColdAfterRow) $tp3903Log
        Assert-Tp3903 $discovery $tp3903Apply $requestShape $tp3903MetricsBefore $tp3903MetricsAfter `
            $headerOnlyRows @($tp3903ColdAfterRow, $tp3903OwnershipRow) $tp3903Log
        $tp3903BadInventoryCases = @(
            @($tp3903ColdAfterRow, [pscustomobject]@{ Path='66.cold'; Length=115; LastWriteTimeUtc='2026-07-17T00:00:02.0000000Z' }),
            @($tp3903ColdAfterRow, [pscustomobject]@{ Path='67.cold'; Length=116; LastWriteTimeUtc='2026-07-17T00:00:03.0000000Z' }),
            @($tp3903ColdAfterRow, [pscustomobject]@{ Path='staging/65.cold.tmp'; Length=114; LastWriteTimeUtc='2026-07-17T00:00:04.0000000Z' }),
            @($tp3903ColdAfterRow, [pscustomobject]@{ Path='temp/65.cold'; Length=114; LastWriteTimeUtc='2026-07-17T00:00:05.0000000Z' }),
            @($tp3903ColdAfterRow, [pscustomobject]@{ Path='quarantine/65.cold.q.1'; Length=114; LastWriteTimeUtc='2026-07-17T00:00:06.0000000Z' }),
            @($tp3903ColdAfterRow, [pscustomobject]@{ Path='manifest.json'; Length=8; LastWriteTimeUtc='2026-07-17T00:00:07.0000000Z' }),
            @($tp3903ColdAfterRow, [pscustomobject]@{ Path='notes.txt'; Length=8; LastWriteTimeUtc='2026-07-17T00:00:08.0000000Z' })
        )
        foreach ($case in $tp3903BadInventoryCases) {
            try {
                Assert-Tp3903 $discovery $tp3903Apply $requestShape $tp3903MetricsBefore $tp3903MetricsAfter `
                    $headerOnlyRows $case $tp3903Log
                throw 'TP-39-03 cold inventory self-test accepted invalid data'
            } catch {
                if ($_.Exception.Message -eq 'TP-39-03 cold inventory self-test accepted invalid data') { throw }
            }
        }
        $tp3903StaleMetricsAfter = $tp3903MetricsAfter.
            Replace('llamacpp:cache_hot_payload_descriptors{mode="hybrid"} 0',
                'llamacpp:cache_hot_payload_descriptors{mode="hybrid"} 1').
            Replace('llamacpp:cache_cold_payload_count{mode="hybrid"} 1',
                'llamacpp:cache_cold_payload_count{mode="hybrid"} 0')
        $tp3903MalformedDeltaCases = @(
            $tp3903StaleMetricsAfter,
            $tp3903MetricsAfter.Replace('llamacpp:cache_evicted_payload_descriptors{mode="hybrid"} 1',
                'llamacpp:cache_evicted_payload_descriptors{mode="hybrid"} 2'),
            $tp3903MetricsAfter.Replace('llamacpp:cache_payload_evictions_total{mode="hybrid"} 1',
                'llamacpp:cache_payload_evictions_total{mode="hybrid"} 0'),
            $tp3903MetricsAfter.Replace('llamacpp:cache_hot_payload_descriptors{mode="hybrid"} 0',
                'llamacpp:cache_hot_payload_descriptors{mode="hybrid"} -1'),
            $tp3903MetricsAfter.Replace('llamacpp:cache_cold_payload_count{mode="hybrid"} 1',
                'llamacpp:cache_cold_payload_count{mode="hybrid"} not-a-number')
        )
        foreach ($case in $tp3903MalformedDeltaCases) {
            try {
                Assert-Tp3903 $discovery $tp3903Apply $requestShape $tp3903MetricsBefore $case `
                    $headerOnlyRows @($null, $tp3903ColdAfterRow) $tp3903Log
                throw 'TP-39-03 descriptor delta self-test accepted invalid data'
            } catch {
                if ($_.Exception.Message -eq 'TP-39-03 descriptor delta self-test accepted invalid data') { throw }
            }
        }
        Assert-ControlCommonS39 $discovery ([pscustomobject]@{
            scenario='tp39-03'; consumed=$true; pressure_completed=$true
            before_generation=7; after_generation=8
            before=[pscustomobject]@{ hot_candidates=$discovery.hot_candidates; cold_sets=$discovery.cold_sets }
            after=[pscustomobject]@{ hot_candidates=$discovery.hot_candidates; cold_sets=$discovery.cold_sets }
        }) $requestShape $tp3903MetricsBefore $tp3903MetricsBefore $headerOnlyRows
    } finally {
        Remove-Item -LiteralPath $inventoryRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    $terminal = [pscustomobject]@{
        status='success'; process_identity='process'; test_session_id='session'; run_id='pure'
        discovery_generation=7; post_setup_generation=8; exact_return_generation=9; common_sync_generation=10; final_generation=10
        fault='none'; error=''; mismatch_flags=@(); checkpoint_attempted=$true; checkpoint_prepared=$true; common_sync_observed=$true
        records=@(
            [pscustomobject]@{ workload_role='canonical_same_owner'; request_number=1; pressure_step=1; payload_id=101; owner_entry_id=11; payload_kind='exact_blob'; pair_state='target_draft'; runtime_has_draft=$true; target_size_bytes=40; draft_size_bytes=10; target_checksum=1; draft_checksum=2; expected_generation=9; observed_generation=9; serialized_bytes=114; staging_file_bytes=114 }
            [pscustomobject]@{ workload_role='canonical_same_owner'; request_number=1; pressure_step=2; payload_id=102; owner_entry_id=11; payload_kind='checkpoint'; pair_state='target_draft'; runtime_has_draft=$true; target_size_bytes=41; draft_size_bytes=10; target_checksum=3; draft_checksum=4; expected_generation=10; observed_generation=10; serialized_bytes=115; staging_file_bytes=115 }
        )
        terminal_state=[pscustomobject]@{
            entry=[pscustomobject]@{ entry_id=11; exact_link=101; checkpoint_link=0; resident_bytes=0; has_target=$false; has_draft=$false }
            branch=[pscustomobject]@{ branch_id=12; exact_link=101; checkpoint_link=0; resident_bytes=0; has_target=$false; has_draft=$false; sync_count=1 }
            exact_descriptor=[pscustomobject]@{ payload_id=101; residency='cold'; cold_file_bytes=114; descriptor_bytes=50; byte_map_bytes=114 }
            checkpoint_descriptor=[pscustomobject]@{ payload_id=102; residency='evicted'; resident_component_bytes=51 }
            cold_inventory=@([pscustomobject]@{ name='65.cold'; bytes=114 }); staging_inventory=@()
            resident_accounting=[pscustomobject]@{
                total_resident_bytes=60; hot_budget_bytes=50
                active_reference_entries=@([pscustomobject]@{ entry_id=21; slot_reference_count=1; resident_bytes=60; exact_link=201; checkpoint_link=202 })
            }
            topology=[pscustomobject]@{ entry_count=1; node_count=1; lru_memberships=0; entry_count_delta=0; node_count_delta=0; lru_membership_delta=-1; branch_prune_delta=0; later_victim_count=0 }
            decision_deltas=@(
                [pscustomobject]@{ mode='hybrid'; result='retained_cold'; reason='cold_room'; value=1 }
                [pscustomobject]@{ mode='hybrid'; result='evicted'; reason='both_filled'; value=1 }
            )
            transaction_deltas=@([pscustomobject]@{ mode='hybrid'; result='commit'; reason='none'; value=1 })
            diagnostic_deltas=[pscustomobject]@{}
            forbidden_observations=[pscustomobject]@{
                checkpoint_cold_file=[pscustomobject]@{
                    before=[pscustomobject]@{ exists=$false; name='66.cold'; bytes=0 }
                    after=[pscustomobject]@{ exists=$false; name='66.cold'; bytes=0 }; event_delta=0
                }
                checkpoint_descriptor=[pscustomobject]@{
                    before=[pscustomobject]@{ payload_id=102; owner_entry_id=11; payload_kind='checkpoint'; residency='hot'; store_ref=102; target_size_bytes=41; draft_size_bytes=10; target_checksum=3; draft_checksum=4; resident_payload_bytes=51; pair_state='target_and_draft' }
                    after=[pscustomobject]@{ payload_id=102; owner_entry_id=11; payload_kind='checkpoint'; residency='evicted'; store_ref=102; target_size_bytes=41; draft_size_bytes=10; target_checksum=3; draft_checksum=4; resident_payload_bytes=0; pair_state='target_and_draft' }
                    event_delta=1
                }
                checkpoint_link=[pscustomobject]@{ before=102; after=0; event_delta=1 }
            }
            forbidden_effects=[pscustomobject]@{
                checkpoint_classification_delta=1; checkpoint_admission_delta=0; checkpoint_publish_delta=0
                checkpoint_commit_delta=0; checkpoint_cold_file_delta=0; checkpoint_descriptor_mutation_delta=1
                checkpoint_link_mutation_delta=1; checkpoint_decision_delta=0; checkpoint_diagnostic_delta=0
                later_work_delta=0; later_victim_delta=0; explicit_generation_advance_delta=0
                later_kind_work_delta=0; post_abort_pressure_delta=0; post_abort_diagnostic_delta=0
                duplicate_sync_delta=0; success_snapshot_count=0; failed_apply_count=1
            }
        }
        terminal_hmac=('c' * 64)
    }
    $terminalApply = [pscustomobject]@{ consumed=$true; prepared_proof=$terminal }
    $terminalBytes = [Text.Encoding]::UTF8.GetBytes(($terminal | ConvertTo-Json -Depth 20 -Compress))
    $wrappedBytes = [Text.Encoding]::UTF8.GetBytes('{"prepared_proof":' +
        [Text.Encoding]::UTF8.GetString($terminalBytes) + ',"tail":"}"}')
    if (-not (Test-ByteEqualS39 $terminalBytes (Get-JsonObjectPropertyBytesS39 $wrappedBytes 'prepared_proof'))) {
        throw 'TP-39-03 raw proof extraction self-test mismatch'
    }
    $retrieval = [pscustomobject]@{ consumed=$true; retry_rejected=$true; body_bytes=$terminalBytes }
    Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval ''
    $terminalCases = @(
        { $x=$retrieval.PSObject.Copy(); $x.consumed=$false; Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $x '' },
        { $x=$retrieval.PSObject.Copy(); $x.retry_rejected=$false; Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $x '' },
        { $x=$retrieval.PSObject.Copy(); $x.body_bytes=[Text.Encoding]::UTF8.GetBytes('{}'); Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $x '' },
        { $x=$terminal.status; $terminal.status='failed'; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.status=$x } },
        { $x=$terminal.process_identity; $terminal.process_identity='other-process'; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.process_identity=$x } },
        { $x=$terminal.final_generation; $terminal.final_generation=9; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.final_generation=$x } },
        { $x=$terminal.records[0].payload_id; $terminal.records[0].payload_id=999; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.records[0].payload_id=$x } },
        { $x=$terminal.terminal_state.entry.exact_link; $terminal.terminal_state.entry.exact_link=0; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.entry.exact_link=$x } },
        { $x=$terminal.terminal_state.branch.sync_count; $terminal.terminal_state.branch.sync_count=2; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.branch.sync_count=$x } },
        { $x=$terminal.terminal_state.cold_inventory[0].bytes; $terminal.terminal_state.cold_inventory[0].bytes=113; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.cold_inventory[0].bytes=$x } },
        { $x=$terminal.terminal_state.staging_inventory; $terminal.terminal_state.staging_inventory=@([pscustomobject]@{ name='leftover.stage' }); try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.staging_inventory=$x } },
        { $x=$terminal.terminal_state.topology.node_count_delta; $terminal.terminal_state.topology.node_count_delta=1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.topology.node_count_delta=$x } },
        { $x=$terminal.terminal_state.topology.lru_memberships; $terminal.terminal_state.topology.lru_memberships=1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.topology.lru_memberships=$x } },
        { $x=$terminal.terminal_state.topology.lru_membership_delta; $terminal.terminal_state.topology.lru_membership_delta=0; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.topology.lru_membership_delta=$x } },
        { $x=$terminal.terminal_state.topology.lru_membership_delta; $terminal.terminal_state.topology.lru_membership_delta=[uint64]::MaxValue; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.topology.lru_membership_delta=$x } },
        { $x=$terminal.terminal_state.resident_accounting.active_reference_entries[0].entry_id; $terminal.terminal_state.resident_accounting.active_reference_entries[0].entry_id=11; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.resident_accounting.active_reference_entries[0].entry_id=$x } },
        { $x=$terminal.terminal_state.resident_accounting.active_reference_entries[0].resident_bytes; $terminal.terminal_state.resident_accounting.active_reference_entries[0].resident_bytes=59; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.resident_accounting.active_reference_entries[0].resident_bytes=$x } },
        { $x=$terminal.terminal_state.forbidden_observations.checkpoint_link.after; $terminal.terminal_state.forbidden_observations.checkpoint_link.after=102; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.forbidden_observations.checkpoint_link.after=$x } },
        { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval ('prefix-' + [string] $requestShape.snapshot_token + '-suffix') },
        { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval ('prefix-' + [string] $requestShape.proof_token + '-suffix') },
        { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval ('prefix-' + [string] $terminal.terminal_hmac + '-suffix') },
        { $x=$terminal.terminal_state.decision_deltas[0].value; $terminal.terminal_state.decision_deltas[0].value=2; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.decision_deltas[0].value=$x } },
        { $x=$terminal.terminal_state.transaction_deltas[0].value; $terminal.terminal_state.transaction_deltas[0].value=2; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.transaction_deltas[0].value=$x } },
        { Add-Member $terminal.terminal_state.diagnostic_deltas bad 1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.diagnostic_deltas.PSObject.Properties.Remove('bad') } },
        { $x=$terminal.terminal_state.exact_descriptor.byte_map_bytes; $terminal.terminal_state.exact_descriptor.byte_map_bytes=113; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.exact_descriptor.byte_map_bytes=$x } },
        { $x=$terminal.terminal_state.forbidden_observations.checkpoint_cold_file.event_delta; $terminal.terminal_state.forbidden_observations.checkpoint_cold_file.event_delta=1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.forbidden_observations.checkpoint_cold_file.event_delta=$x } },
        { $x=$terminal.terminal_state.forbidden_effects.checkpoint_commit_delta; $terminal.terminal_state.forbidden_effects.checkpoint_commit_delta=1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.forbidden_effects.checkpoint_commit_delta=$x } },
        { $x=$terminal.terminal_state.forbidden_effects.later_kind_work_delta; $terminal.terminal_state.forbidden_effects.later_kind_work_delta=1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.forbidden_effects.later_kind_work_delta=$x } },
        { $x=$terminal.terminal_state.forbidden_effects.post_abort_pressure_delta; $terminal.terminal_state.forbidden_effects.post_abort_pressure_delta=1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.forbidden_effects.post_abort_pressure_delta=$x } },
        { $x=$terminal.terminal_state.forbidden_effects.post_abort_diagnostic_delta; $terminal.terminal_state.forbidden_effects.post_abort_diagnostic_delta=1; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.forbidden_effects.post_abort_diagnostic_delta=$x } },
        { $x=$terminal.terminal_state.forbidden_effects.later_kind_work_delta; $terminal.terminal_state.forbidden_effects.PSObject.Properties.Remove('later_kind_work_delta'); try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { Add-Member -InputObject $terminal.terminal_state.forbidden_effects -NotePropertyName later_kind_work_delta -NotePropertyValue $x } },
        { $x=$terminal.terminal_state.forbidden_effects.post_abort_pressure_delta; $terminal.terminal_state.forbidden_effects.PSObject.Properties.Remove('post_abort_pressure_delta'); try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { Add-Member -InputObject $terminal.terminal_state.forbidden_effects -NotePropertyName post_abort_pressure_delta -NotePropertyValue $x } },
        { $x=$terminal.terminal_state.forbidden_effects.post_abort_diagnostic_delta; $terminal.terminal_state.forbidden_effects.PSObject.Properties.Remove('post_abort_diagnostic_delta'); try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { Add-Member -InputObject $terminal.terminal_state.forbidden_effects -NotePropertyName post_abort_diagnostic_delta -NotePropertyValue $x } },
        { $a=$terminal.terminal_state.forbidden_effects.later_kind_work_delta; $b=$terminal.terminal_state.forbidden_effects.post_abort_pressure_delta; $c=$terminal.terminal_state.forbidden_effects.post_abort_diagnostic_delta; $terminal.terminal_state.forbidden_effects.PSObject.Properties.Remove('later_kind_work_delta'); $terminal.terminal_state.forbidden_effects.PSObject.Properties.Remove('post_abort_pressure_delta'); $terminal.terminal_state.forbidden_effects.PSObject.Properties.Remove('post_abort_diagnostic_delta'); try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { Add-Member -InputObject $terminal.terminal_state.forbidden_effects -NotePropertyName later_kind_work_delta -NotePropertyValue $a; Add-Member -InputObject $terminal.terminal_state.forbidden_effects -NotePropertyName post_abort_pressure_delta -NotePropertyValue $b; Add-Member -InputObject $terminal.terminal_state.forbidden_effects -NotePropertyName post_abort_diagnostic_delta -NotePropertyValue $c } },
        { Add-Member -InputObject $terminal.terminal_state.forbidden_effects -NotePropertyName unexpected_forbidden_effect_delta -NotePropertyValue 0; try { Assert-Tp3903TerminalProofS39 $terminalApply $requestShape $terminalBytes $retrieval '' } finally { $terminal.terminal_state.forbidden_effects.PSObject.Properties.Remove('unexpected_forbidden_effect_delta') } }
    )
    foreach ($case in $terminalCases) {
        try { & $case; throw 'TP-39-03 terminal negative self-test accepted invalid data' }
        catch { if ($_.Exception.Message -eq 'TP-39-03 terminal negative self-test accepted invalid data') { throw } }
    }
    foreach ($historical in @('tp39_03_cold_owner_setup','tp39_03_owner_reassignment','owner_moves','cold_rank_setup')) {
        $invalid = $requestShape.PSObject.Copy()
        Add-Member -InputObject $invalid -NotePropertyName $historical -NotePropertyValue 'forbidden'
        try { Assert-Tp3903RequestShapeS39 $invalid; throw 'TP-39-03 historical-field self-test accepted invalid request' }
        catch { if ($_.Exception.Message -eq 'TP-39-03 historical-field self-test accepted invalid request') { throw } }
    }
    $metricZero = @'
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="retained_cold",reason="cold_room_made"} 0
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="retained_cold",reason="cold_room"} 0
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="evicted",reason="both_filled"} 0
llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="evicted",reason="oversized_both"} 0
llamacpp:cache_cold_transactions_total{mode="hybrid",result="commit",reason="none"} 0
'@
    $tp3902Metrics = $metricZero -replace 'reason="cold_room_made"} 0', 'reason="cold_room_made"} 1' `
        -replace 'result="commit",reason="none"} 0', 'result="commit",reason="none"} 1'
    $tp3903Metrics = $metricZero -replace 'reason="cold_room"} 0', 'reason="cold_room"} 1' `
        -replace 'reason="both_filled"} 0', 'reason="both_filled"} 1' `
        -replace 'result="commit",reason="none"} 0', 'result="commit",reason="none"} 1'
    $tp3904Metrics = $metricZero -replace 'reason="oversized_both"} 0', 'reason="oversized_both"} 1'
    Assert-ExactOutcomeS39 $metricZero $tp3902Metrics 'retained_cold' 'cold_room_made' 1
    Assert-Tp3903OutcomeS39 $metricZero $tp3903Metrics
    Assert-ExactOutcomeS39 $metricZero $tp3904Metrics 'evicted' 'oversized_both' 0
    $tp3903OutcomeNegatives = @(
        ($tp3903Metrics -replace 'reason="cold_room"} 1', 'reason="cold_room"} 0'),
        ($tp3903Metrics -replace 'reason="both_filled"} 1', 'reason="both_filled"} 0'),
        ($tp3903Metrics -replace 'reason="both_filled"} 1', 'reason="both_filled"} 2'),
        ($tp3903Metrics + 'llamacpp:cache_two_layer_decisions_total{mode="hybrid",result="evicted",reason="oversized_both"} 1' + "`n"),
        ($tp3903Metrics -replace 'result="retained_cold",reason="cold_room"} 1', 'result="retained_cold",reason="cold_room_made"} 1'),
        ($tp3903Metrics -replace 'result="commit",reason="none"} 1', 'result="commit",reason="none"} 0'))
    foreach ($case in $tp3903OutcomeNegatives) {
        try { Assert-Tp3903OutcomeS39 $metricZero $case; throw 'TP-39-03 paired decision self-test accepted invalid metric tuples' }
        catch { if ($_.Exception.Message -eq 'TP-39-03 paired decision self-test accepted invalid metric tuples') { throw } }
    }
    $tp3902Log = "event=cache_two_layer_decision result=retained_cold reason=cold_room_made payload_id=3`n" +
        "event=cache_cold_transaction result=commit reason=none tx_id=7`n"
    Assert-ApplyLogS39 $tp3902Log 'retained_cold' 'cold_room_made' 3 1
    Assert-Tp3903ApplyLogS39 $tp3903Log 101 102
    Assert-ApplyLogS39 'event=cache_two_layer_decision result=evicted reason=both_filled payload_id=4' `
        'evicted' 'both_filled' 4 0
    Assert-ApplyLogS39 'event=cache_two_layer_decision result=evicted reason=oversized_both payload_id=5' `
        'evicted' 'oversized_both' 5 0
    [pscustomobject]@{
        Outcome = 'PASS'; Scenarios = @('hot-zero', 'legacy'); MalformedRowsRejected = $true
        Tp3902Roles = @($tp3902.role); Tp3902FillTokens = @($tp3902.fill_tokens)
        Tp3903Roles = @($tp3903.role); Tp3903Lengths = @($tp3903[0].body.messages[9].content.Length, $tp3903[1].body.messages[9].content.Length)
    }
}
function Assert-ControlResponseS39([object] $Discover, [object] $Apply, [string] $ExpectedScenario) {
    if (-not $Discover.snapshot_generation -or -not $Discover.snapshot_token) { throw 'Discover snapshot binding missing' }
    if (-not $Discover.hot_candidates -or $null -eq $Discover.cold_sets) { throw 'Discover inventories missing' }
    if ($Apply.scenario -ne $ExpectedScenario -or -not $Apply.consumed -or -not $Apply.pressure_completed) {
        throw "Guarded apply failed for $ExpectedScenario"
    }
    if ([uint64] $Apply.after_generation -le [uint64] $Apply.before_generation) { throw 'Apply generation did not advance' }
    foreach ($side in @('before', 'after')) {
        if ($null -eq $Apply.$side.hot_candidates -or $null -eq $Apply.$side.cold_sets) {
            throw "Apply $side inventories missing"
        }
    }
}
function Get-ControlDeltaS39([string] $Before, [string] $After, [string] $Family, [hashtable] $Labels = @{}) {
    $a = Read-MetricsS39 $Before; $b = Read-MetricsS39 $After
    return (Sum-MetricS39 $b $Family $Labels) - (Sum-MetricS39 $a $Family $Labels)
}
function Assert-ExactOutcomeS39([string] $MetricsBefore, [string] $MetricsAfter,
        [string] $Result, [string] $Reason, [int] $ExpectedTransactions) {
    $decisionFamily = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_two_layer_decisions_total'
    $decisionTuple = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_two_layer_decisions_total' `
        @{ mode='hybrid'; result=$Result; reason=$Reason }
    if ($decisionFamily -ne 1 -or $decisionTuple -ne 1) {
        throw "Stage 39 decision delta is not exactly one $Result/$Reason and zero other tuples"
    }
    $transactionFamily = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_cold_transactions_total'
    if ($transactionFamily -ne $ExpectedTransactions) {
        throw "Stage 39 cold transaction family delta is not exactly $ExpectedTransactions"
    }
    if ($ExpectedTransactions -eq 1) {
        $commit = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_cold_transactions_total' `
            @{ mode='hybrid'; result='commit'; reason='none' }
        if ($commit -ne 1) { throw 'Stage 39 transaction delta is not exactly one commit/none and zero other tuples' }
    }
}
function Assert-Tp3903OutcomeS39([string] $MetricsBefore, [string] $MetricsAfter) {
    $decisionFamily = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_two_layer_decisions_total'
    $retainedCold = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_two_layer_decisions_total' `
        @{ mode='hybrid'; result='retained_cold'; reason='cold_room' }
    $evictedCheckpoint = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_two_layer_decisions_total' `
        @{ mode='hybrid'; result='evicted'; reason='both_filled' }
    if ($decisionFamily -ne 2 -or $retainedCold -ne 1 -or $evictedCheckpoint -ne 1) {
        throw 'TP-39-03 decision delta is not exactly retained_cold/cold_room plus evicted/both_filled'
    }
    $transactionFamily = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_cold_transactions_total'
    $commit = Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_cold_transactions_total' `
        @{ mode='hybrid'; result='commit'; reason='none' }
    if ($transactionFamily -ne 1 -or $commit -ne 1) {
        throw 'TP-39-03 cold transaction delta is not exactly one commit/none and zero other tuples'
    }
}
function Assert-ApplyLogS39([string] $Log, [string] $Result, [string] $Reason,
        [uint64] $PayloadId, [int] $ExpectedTransactions) {
    $decisionLines = @($Log -split "`r?`n" | Where-Object { $_ -match 'event=cache_two_layer_decision' })
    $transactionLines = @($Log -split "`r?`n" | Where-Object { $_ -match 'event=cache_cold_transaction' })
    $decisionPattern = 'event=cache_two_layer_decision result=' + [regex]::Escape($Result) +
        ' reason=' + [regex]::Escape($Reason) + ' payload_id=' + $PayloadId + '(?:\s|$)'
    if ($decisionLines.Count -ne 1 -or $decisionLines[0] -notmatch $decisionPattern) {
        throw 'Stage 39 apply window lacks one exact incoming-payload decision log'
    }
    if ($transactionLines.Count -ne $ExpectedTransactions) {
        throw "Stage 39 apply window transaction log count is not $ExpectedTransactions"
    }
    if ($ExpectedTransactions -eq 1 -and
        $transactionLines[0] -notmatch 'event=cache_cold_transaction result=commit reason=none tx_id=([1-9][0-9]*)(?:\s|$)') {
        throw 'Stage 39 apply window lacks one identified commit/none transaction log'
    }
}
function Assert-Tp3903ApplyLogS39([string] $Log, [uint64] $ExactPayloadId, [uint64] $CheckpointPayloadId) {
    $decisionLines = @($Log -split "`r?`n" | Where-Object { $_ -match 'event=cache_two_layer_decision' })
    $transactionLines = @($Log -split "`r?`n" | Where-Object { $_ -match 'event=cache_cold_transaction' })
    $exactPattern = 'event=cache_two_layer_decision result=retained_cold reason=cold_room payload_id=' +
        $ExactPayloadId + '(?:\s|$)'
    $checkpointPattern = 'event=cache_two_layer_decision result=evicted reason=both_filled payload_id=' +
        $CheckpointPayloadId + '(?:\s|$)'
    if ($decisionLines.Count -ne 2 -or
        @($decisionLines | Where-Object { $_ -match $exactPattern }).Count -ne 1 -or
        @($decisionLines | Where-Object { $_ -match $checkpointPattern }).Count -ne 1) {
        throw 'TP-39-03 apply window lacks exact paired decision logs'
    }
    if ($transactionLines.Count -ne 1 -or
        $transactionLines[0] -notmatch 'event=cache_cold_transaction result=commit reason=none tx_id=([1-9][0-9]*)(?:\s|$)') {
        throw 'TP-39-03 apply window lacks one identified commit/none transaction log'
    }
}
function Assert-ControlCommonS39([object] $Discover, [object] $Apply, [object] $Request,
        [string] $MetricsBefore, [string] $MetricsAfter, [object[]] $ColdAfter) {
    $ColdAfter = Normalize-ColdInventoryS39 $ColdAfter
    Assert-ControlResponseS39 $Discover $Apply $Request.scenario
    if (($Apply.before.hot_candidates | ConvertTo-Json -Depth 20 -Compress) -ne
        ($Discover.hot_candidates | ConvertTo-Json -Depth 20 -Compress)) { throw 'Apply before hot inventory differs from discovery' }
    if (($Apply.before.cold_sets | ConvertTo-Json -Depth 20 -Compress) -ne
        ($Discover.cold_sets | ConvertTo-Json -Depth 20 -Compress)) { throw 'Apply before cold inventory differs from discovery' }
    if (($Apply | ConvertTo-Json -Depth 20 -Compress) -match [regex]::Escape([string] $Discover.snapshot_token)) {
        throw 'Apply response echoed snapshot token'
    }
    foreach ($metric in @('llamacpp:cache_entries', 'llamacpp:cache_namespace_nodes', 'llamacpp:cache_branch_pruning_total')) {
        if ((Get-ControlDeltaS39 $MetricsBefore $MetricsAfter $metric @{ mode = 'hybrid' }) -ne 0) {
            throw "Guarded pressure changed retained topology metric $metric"
        }
    }
    $coldDescriptor = Sum-MetricS39 (Read-MetricsS39 $MetricsAfter) 'llamacpp:cache_cold_bytes' @{ mode = 'hybrid' }
    $coldPayload = Sum-MetricS39 (Read-MetricsS39 $MetricsAfter) 'llamacpp:cache_cold_payload_bytes' @{ mode = 'hybrid' }
    $finalCold = @($ColdAfter | Where-Object Path -Match '^[0-9a-fA-F]+\.cold$')
    $fileBytes = [double] (($finalCold | Measure-Object Length -Sum).Sum)
    $quarantine = [double] (($ColdAfter | Where-Object Path -Match '\.q\.\d+$' | Measure-Object Length -Sum).Sum)
    if ($coldDescriptor -ne $coldPayload -or $coldDescriptor -ne $fileBytes -or $quarantine -ne 0) {
        throw 'Guarded pressure cold byte/file/quarantine accounting mismatch'
    }
}
function Assert-Tp3902([object] $Discover, [object] $Apply, [object] $Request,
        [string] $MetricsBefore, [string] $MetricsAfter, [object[]] $ColdBefore, [object[]] $ColdAfter, [string] $Log) {
    $ColdBefore = Normalize-ColdInventoryS39 $ColdBefore
    $ColdAfter = Normalize-ColdInventoryS39 $ColdAfter
    Assert-ControlCommonS39 $Discover $Apply $Request $MetricsBefore $MetricsAfter $ColdAfter
    $set = @($Discover.cold_sets | Where-Object incoming_payload_id -eq $Request.incoming_payload_id)[0]
    $victims = @($set.candidates)
    if (@($Discover.hot_candidates).Count -ne 1) { throw 'TP-39-02 discovery must contain exactly one hot incoming pair' }
    if ($victims.Count -ne 2) { throw 'TP-39-02 discovery must contain exactly two cold victims' }
    $incoming = @($Discover.hot_candidates | Where-Object payload_id -eq $Request.incoming_payload_id)[0]
    if (-not $incoming -or @($victims | Where-Object { [uint64] $_.resident_bytes -ge [uint64] $incoming.resident_bytes }).Count) {
        throw 'TP-39-02 incoming pair is not larger than both victims'
    }
    $victimResidentBytes = [uint64] (($victims | Measure-Object resident_bytes -Sum).Sum)
    $victimColdBytes = [uint64] (($victims | Measure-Object serialized_cold_bytes -Sum).Sum)
    if ([uint64] $Discover.hot_budget_bytes -le [uint64] $incoming.resident_bytes -or
        [uint64] $Discover.hot_budget_bytes -ge $victimResidentBytes + [uint64] $incoming.resident_bytes -or
        [uint64] $Discover.cold_budget_bytes -lt $victimColdBytes + [uint64] $incoming.resident_bytes) {
        throw 'TP-39-02 startup budgets do not retain incoming hot while cold can hold all three pairs'
    }
    if ([uint64] $Request.hot_budget_bytes -ge [uint64] $incoming.resident_bytes -or
        [uint64] $Request.cold_budget_bytes -lt [uint64] $incoming.resident_bytes -or
        [uint64] $Request.cold_budget_bytes -ge $victimColdBytes + [uint64] $incoming.resident_bytes) {
        throw 'TP-39-02 apply budgets do not pressure incoming into multi-victim cold room-making'
    }
    $ranks = @($Request.desired_cold_ranks.desired_cold_rank | Sort-Object -Unique)
    if ($ranks.Count -ne 1) { throw 'TP-39-02 victim ranks are not tied' }
    $ordered = @($victims | Sort-Object @{ Expression = 'cold_rank' }, @{ Expression = 'payload_id' })
    $ids = @($ordered.payload_id)
    if (($ids -join ',') -ne (@($ids | Sort-Object) -join ',')) { throw 'TP-39-02 tie order is not payload-id order' }
    if ((@($Request.desired_cold_ranks.payload_id) -join ',') -ne ($ids -join ',')) {
        throw 'TP-39-02 requested victim order does not match production tie order'
    }
    Assert-ExactOutcomeS39 $MetricsBefore $MetricsAfter 'retained_cold' 'cold_room_made' 1
    Assert-ApplyLogS39 $Log 'retained_cold' 'cold_room_made' ([uint64] $Request.incoming_payload_id) 1
    if ((Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_evicted_payload_descriptors' @{ mode='hybrid' }) -ne 2 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_payload_evictions_total' @{ mode='hybrid' }) -ne 2 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_hot_payload_descriptors' @{ mode='hybrid' }) -ne -1 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_cold_payload_count' @{ mode='hybrid' }) -ne -1) {
        throw 'TP-39-02 descriptor tombstone or residency deltas are not exact'
    }
    foreach ($id in $ids) {
        $name = ('{0:x}.cold' -f [uint64] $id)
        if (@($ColdAfter | Where-Object Path -eq $name).Count) { throw "TP-39-02 victim file retained: $name" }
    }
    $coldBeforeFiles = @($ColdBefore | Where-Object Path -Match '^[0-9a-fA-F]+\.cold$')
    $coldAfterFiles = @($ColdAfter | Where-Object Path -Match '^[0-9a-fA-F]+\.cold$')
    if ($coldAfterFiles.Count -ne $coldBeforeFiles.Count - $victims.Count + 1) { throw 'TP-39-02 tombstone/file count mismatch' }
    $incomingName = ('{0:x}.cold' -f [uint64] $Request.incoming_payload_id)
    if (@($Apply.after.hot_candidates | Where-Object payload_id -eq $Request.incoming_payload_id).Count -or
        @($ColdAfter | Where-Object Path -eq $incomingName).Count -ne 1) {
        throw 'TP-39-02 incoming pair was not atomically retained cold'
    }
}
function Assert-Tp3903([object] $Discover, [object] $Apply, [object] $Request,
        [string] $MetricsBefore, [string] $MetricsAfter, [object[]] $ColdBefore, [object[]] $ColdAfter, [string] $Log) {
    $ColdBefore = Normalize-ColdInventoryS39 $ColdBefore
    $ColdAfter = Normalize-ColdInventoryS39 $ColdAfter
    Assert-ControlCommonS39 $Discover $Apply $Request $MetricsBefore $MetricsAfter $ColdAfter
    $source = Get-Tp3903SourceRowS39 $Discover
    $bindings = @($Request.prepared_bindings)
    $forbidden = @('tp39_03_cold_owner_setup', 'tp39_03_owner_reassignment', 'owner_moves', 'cold_rank_setup')
    if ($Request.tp39_03_setup -ne 'same_owner_kind_sequence' -or @($Request.desired_cold_ranks).Count -ne 0 -or
        @($bindings).Count -ne 2 -or @($forbidden | Where-Object { $Request.PSObject.Properties.Name -contains $_ }).Count) {
        throw 'TP-39-03 natural setup request mismatch'
    }
    $exactId = [uint64] $bindings[0].payload_id
    $checkpointId = [uint64] $bindings[1].payload_id
    if ($exactId -ne [uint64] $source.payload_id -or
        [uint64] $Request.hot_budget_bytes -ne ([uint64] $bindings[0].target_size_bytes + [uint64] $bindings[0].draft_size_bytes) -or
        [uint64] $Request.hot_budget_bytes -eq 0 -or [uint64] $Request.cold_budget_bytes -eq 0 -or
        @($ColdBefore | Where-Object Path -Match '^[0-9a-fA-F]+\.cold$').Count -ne 0) { throw 'TP-39-03 checked budget or cold-empty setup mismatch' }
    if (($Apply | ConvertTo-Json -Depth 20 -Compress) -match [regex]::Escape([string] $Request.proof_token) -or
        $Log -match [regex]::Escape([string] $Request.proof_token) -or
        $Log -match [regex]::Escape([string] $Request.snapshot_token)) {
        throw 'TP-39-03 HMAC leaked into response or log'
    }
    Assert-Tp3903OutcomeS39 $MetricsBefore $MetricsAfter
    Assert-Tp3903ApplyLogS39 $Log $exactId $checkpointId
    if ((Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_evicted_payload_descriptors' @{ mode='hybrid' }) -ne 1 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_payload_evictions_total' @{ mode='hybrid' }) -ne 1 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_hot_payload_descriptors' @{ mode='hybrid' }) -ne -2 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_cold_payload_count' @{ mode='hybrid' }) -ne 1) {
        throw 'TP-39-03 descriptor tombstone or residency deltas are not exact'
    }
    if (@($Apply.after.hot_candidates | Where-Object owner_entry_id -eq $source.owner_entry_id).Count) {
        throw 'TP-39-03 exact-cold/checkpoint-evicted state mismatch'
    }
    Assert-Tp3903FinalColdInventoryS39 $ColdAfter $exactId $checkpointId
}
function Assert-Tp3904([object] $Discover, [object] $Apply, [object] $Request,
        [string] $MetricsBefore, [string] $MetricsAfter, [object[]] $ColdBefore, [object[]] $ColdAfter, [string] $Log) {
    $ColdBefore = Normalize-ColdInventoryS39 $ColdBefore
    $ColdAfter = Normalize-ColdInventoryS39 $ColdAfter
    Assert-ControlCommonS39 $Discover $Apply $Request $MetricsBefore $MetricsAfter $ColdAfter
    $incoming = @($Discover.hot_candidates | Where-Object payload_id -eq $Request.incoming_payload_id)[0]
    if ([uint64] $Discover.hot_budget_bytes -le [uint64] $MeasuredResidentPairBytes -or
        [uint64] $Discover.cold_budget_bytes -le [uint64] $MeasuredSerializedPairBytes) {
        throw 'TP-39-04 startup budgets did not exceed the measured admitted pair'
    }
    if ([uint64] $incoming.resident_bytes -le [uint64] $Request.hot_budget_bytes -or
        [uint64] $MeasuredSerializedPairBytes -le [uint64] $Request.cold_budget_bytes) {
        throw 'TP-39-04 measured pair does not exceed both budgets'
    }
    Assert-ExactOutcomeS39 $MetricsBefore $MetricsAfter 'evicted' 'oversized_both' 0
    Assert-ApplyLogS39 $Log 'evicted' 'oversized_both' ([uint64] $Request.incoming_payload_id) 0
    if ((Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_evicted_payload_descriptors' @{ mode='hybrid' }) -ne 1 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_payload_evictions_total' @{ mode='hybrid' }) -ne 1 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_hot_payload_descriptors' @{ mode='hybrid' }) -ne -1 -or
        (Get-ControlDeltaS39 $MetricsBefore $MetricsAfter 'llamacpp:cache_cold_payload_count' @{ mode='hybrid' }) -ne 0) {
        throw 'TP-39-04 descriptor tombstone or residency deltas are not exact'
    }
    if (@($Apply.after.hot_candidates | Where-Object payload_id -eq $Request.incoming_payload_id).Count -or
        @($ColdAfter | Where-Object Path -eq ('{0:x}.cold' -f [uint64] $Request.incoming_payload_id)).Count) {
        throw 'TP-39-04 pair was partially retained'
    }
}

if ($MetricValidationSelfTest) {
    Invoke-Stage39MetricValidationSelfTestS39
    return
}

$ModelPath = Resolve-S39 $ModelPath
$LlamaServerPath = Resolve-S39 $LlamaServerPath
if (-not (Test-Path $ModelPath)) { throw "Model not found: $ModelPath" }
if (-not (Test-Path $LlamaServerPath)) { throw "Server not found: $LlamaServerPath" }
if (-not $RunRoot) { $RunRoot = Join-Path $repo ("._test_output/stage39-" + (Get-Date -Format yyyyMMdd-HHmmss)) }
$RunRoot = Resolve-S39 $RunRoot
$guardedFreshRoot = $Scenario -eq 'both-filled'
if ($guardedFreshRoot -and (Test-Path $RunRoot)) { throw 'SKIP-preflight-fresh-root' }
$hotBudgetBytes = [int64] $HotBudgetMiB * 1MB
$coldBudgetBytes = [int64] $ColdBudgetMiB * 1MB
if (-not $MeasurementOnly -and $Scenario -eq 'oversized-both' -and
    ($MeasuredResidentPairBytes -le 0 -or $MeasuredSerializedPairBytes -le 0)) {
    throw "$Scenario requires measured resident and serialized pair bytes"
}
if ($Scenario -eq 'oversized-both' -and
    ($MeasuredResidentPairBytes -le $hotBudgetBytes -or $MeasuredSerializedPairBytes -le $coldBudgetBytes)) {
    throw 'oversized-both requires the measured pair to exceed both positive budgets'
}
$cold = Join-Path $RunRoot 'cold'
$slotSave = if ($Scenario -in @('multi-victim', 'both-filled', 'oversized-both')) {
    Join-Path $RunRoot 'slot-save'
} else { $null }
New-Item -ItemType Directory -Force $RunRoot, $cold | Out-Null
if ($slotSave) { New-Item -ItemType Directory -Force $slotSave | Out-Null }
$stdout = Join-Path $RunRoot 'server.log'
$stderr = Join-Path $RunRoot 'server.err.log'
$effectiveHotBudgetMiB = if ($Scenario -eq 'hot-zero') { 0 } else { $HotBudgetMiB }
$mode = if ($Scenario -eq 'legacy') { 'legacy' } else { 'hybrid' }
$guardedScenario = $Scenario -in @('multi-victim', 'both-filled', 'oversized-both')
$startupHotBudgetMiB = if ($Scenario -eq 'both-filled') {
    2048
} elseif ($Scenario -eq 'multi-victim') {
    [Math]::Max($HotBudgetMiB + 1, $HotBudgetMiB * 2 - 1)
} elseif ($guardedScenario) {
    [Math]::Max($HotBudgetMiB + 1, $HotBudgetMiB * 2)
} else {
    $effectiveHotBudgetMiB
}
$startupColdBudgetMiB = if ($Scenario -eq 'both-filled') { 2048 } elseif ($guardedScenario) { [Math]::Max($ColdBudgetMiB + 1, $ColdBudgetMiB * 2) } else { $ColdBudgetMiB }
$startupHotBudgetBytes = [int64] $startupHotBudgetMiB * 1MB
$startupColdBudgetBytes = [int64] $startupColdBudgetMiB * 1MB
if ($Scenario -eq 'oversized-both' -and
    ($startupHotBudgetBytes -le $MeasuredResidentPairBytes -or
        $startupColdBudgetBytes -le $MeasuredSerializedPairBytes)) {
    throw 'oversized-both requires positive startup budgets above the measured admitted pair'
}
$args = @('-m', $ModelPath, '--cache-mode', $mode, '--cache-ram', $startupHotBudgetMiB,
    '--metrics', '--port', $Port, '--ctx-size', $ContextSize, '--parallel', 1, '--seed', 42)
if ($Scenario -eq 'both-filled') {
    $fixture = Resolve-S39 '._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf'
    if ($ModelPath -ne $fixture) { throw 'SKIP-preflight-fixture' }
    $template = Resolve-S39 '._test_models/Qwen3.5-4B-MTP-GGUF/chat_template_new.jinja'
    if (-not (Test-Path $template) -or $ContextSize -ne 8192 -or $startupHotBudgetMiB -ne 2048 -or $startupColdBudgetMiB -ne 2048) {
        throw 'SKIP-preflight-server-contract'
    }
    $args += @('--jinja', '--chat-template-file', $template, '--batch-size', 512, '--ubatch-size', 512,
        '--ctx-checkpoints', 32, '--checkpoint-min-step', 0, '--temp', 0)
    $templateIndex = [array]::IndexOf([object[]] $args, '--chat-template-file')
    $args = @($args[0..($templateIndex + 1)] + @(Get-Stage39SpecTypeBindingS39 $Scenario) +
        $args[($templateIndex + 2)..($args.Count - 1)])
}
if ($slotSave) { $args += @('--slot-save-path', $slotSave) }
if ($Scenario -notin @('cold-disabled', 'legacy')) {
    $args += @('--cache-cold-path', $cold, '--cache-cold-max-mib', $startupColdBudgetMiB)
}
$stage39Token = $null
if ($guardedScenario) {
    $stage39Token = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
    $env:LLAMA_STAGE39_LIVE_TEST_SEAM = '1'
    $env:LLAMA_STAGE39_LIVE_TEST_TOKEN = $stage39Token
}
Assert-Stage39FinalSpecArgsS39 $Scenario $args
Assert-Stage39SpecEnvironmentS39 $Scenario
$server = Start-Process $LlamaServerPath -ArgumentList $args -PassThru `
    -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden
$passStarted = [DateTime]::UtcNow
try {
    $deadline = (Get-Date).AddSeconds(60)
    do {
        try { $ready = (Invoke-WebRequest "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 2).StatusCode -eq 200 } catch { $ready = $false }
        if (-not $ready) { Start-Sleep -Milliseconds 500 }
    } until ($ready -or (Get-Date) -ge $deadline)
    if (-not $ready) { throw 'Server health timeout' }

    $before = (Invoke-WebRequest "http://127.0.0.1:$Port/metrics" -UseBasicParsing).Content
    $coldBefore = Normalize-ColdInventoryS39 (Get-ColdInventoryS39 $cold)
    Write-ColdInventoryS39 $coldBefore (Join-Path $RunRoot 'cold-files-before.csv')
    $requestPath = Join-Path $RunRoot 'requests.jsonl'
    $responsePath = Join-Path $RunRoot 'responses.jsonl'
    $requestHashes = @()
    $promptTokenRows = @()
    $resourceRows = @()
    $restoreBody = $null
    $workload = @(Get-Stage39WorkloadS39 $Scenario $Requests)
    [IO.File]::WriteAllText((Join-Path $RunRoot 'workload-profile.json'),
        ($workload | ConvertTo-Json -Depth 5) + "`n", [Text.UTF8Encoding]::new($false))
    $workloadIndex = 0
    foreach ($workloadRow in $workload) {
        $bodyFields = if ($workloadRow.chat) { $workloadRow.body } else {
            [ordered]@{ prompt = $workloadRow.prompt; n_predict = $workloadRow.n_predict; temperature = $workloadRow.temperature }
        }
        if (-not $workloadRow.chat -and $null -ne $workloadRow.cache_prompt) { $bodyFields.cache_prompt = [bool] $workloadRow.cache_prompt }
        $body = $bodyFields | ConvertTo-Json -Compress
        $bodyBytes = [Text.Encoding]::UTF8.GetBytes($body)
        $bodyHash = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create().ComputeHash($bodyBytes))).Replace('-', '').ToLowerInvariant()
        $requestHashes += [ordered]@{ index = $workloadIndex; role = $workloadRow.role; utf8_bytes = $bodyBytes.Length; sha256 = $bodyHash }
        if ($workloadIndex -eq 0) { $restoreBody = $body }
        [IO.File]::AppendAllText($requestPath, $body + "`n", [Text.UTF8Encoding]::new($false))
        $requestUri = if ($workloadRow.chat) { "http://127.0.0.1:$Port/v1/chat/completions" } else { "http://127.0.0.1:$Port/completion" }
        $response = Invoke-WebRequest $requestUri -Method Post -Body $body `
            -ContentType 'application/json' -UseBasicParsing -TimeoutSec 300
        [IO.File]::AppendAllText($responsePath, $response.Content + "`n", [Text.UTF8Encoding]::new($false))
        if ($Scenario -eq 'both-filled') {
            $responseJson = $response.Content | ConvertFrom-Json
            $promptTokenRows += [ordered]@{ index = $workloadIndex; role = $workloadRow.role; prompt_tokens = Get-PromptTokensS39 $responseJson }
        }
        $workloadIndex++
        $server.Refresh()
        $coldRootBytes = [int64] ((Get-ChildItem $cold -File -Recurse -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)
        $resourceRows += [ordered]@{ request_count = $workloadIndex; elapsed_seconds = [Math]::Round(([DateTime]::UtcNow - $passStarted).TotalSeconds, 3); rss_bytes = [int64] $server.WorkingSet64; cold_root_bytes = $coldRootBytes }
        if (([DateTime]::UtcNow - $passStarted).TotalMinutes -gt 20 -or
            [int64] $server.WorkingSet64 -gt 16GB -or $coldRootBytes -gt 4GB -or $workloadIndex -gt 6) {
            throw 'SKIP-preflight-cap'
        }
    }
    [IO.File]::WriteAllText((Join-Path $RunRoot 'request-hashes.json'), ($requestHashes | ConvertTo-Json -Depth 4) + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $RunRoot 'resource-capture.json'), ($resourceRows | ConvertTo-Json -Depth 4) + "`n", [Text.UTF8Encoding]::new($false))
    if ($Scenario -eq 'both-filled') {
        $sourceCounts = @($promptTokenRows | Where-Object role -eq 'source' | ForEach-Object { [int64] $_.prompt_tokens })
        $incomingCounts = @($promptTokenRows | Where-Object role -eq 'incoming' | ForEach-Object { [int64] $_.prompt_tokens })
        $tokenCapacity = Assert-Tp3903TokenCapacityS39 $sourceCounts $incomingCounts
        [IO.File]::WriteAllText((Join-Path $RunRoot 'token-counts.json'), ([ordered]@{ requests = $promptTokenRows; capacity = $tokenCapacity } | ConvertTo-Json -Depth 5) + "`n", [Text.UTF8Encoding]::new($false))
        $startupLog = [string] (Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
        if ($startupLog -notmatch "loading model '.*Qwen3\.5-4B-Q4_K_M\.gguf'") {
            throw 'SKIP-preflight-checkpoint-startup-proof'
        }
        Assert-Tp3903StartupProofS39 $startupLog
        $kvLines = @($startupLog -split "`r?`n" | Where-Object { $_ -match 'KV|kv|n_ctx = 8192' })
        [IO.File]::WriteAllText((Join-Path $RunRoot 'kv-allocation.log'), ($kvLines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    }
    if ($guardedScenario -and $Scenario -ne 'both-filled') {
        $slotEraseUri = "http://127.0.0.1:$Port/slots/0?action=erase"
        [IO.File]::WriteAllText((Join-Path $RunRoot 'slot-erase-request.txt'), $slotEraseUri + "`n", [Text.UTF8Encoding]::new($false))
        $slotErase = Invoke-WebRequest $slotEraseUri -Method Post -UseBasicParsing -TimeoutSec 120
        [IO.File]::WriteAllText((Join-Path $RunRoot 'slot-erase-response.json'), $slotErase.Content + "`n", [Text.UTF8Encoding]::new($false))
    }
    $controlDiscover = $null
    $controlApply = $null
    $controlMetricsBefore = $null; $controlMetricsAfter = $null
    $controlColdBefore = @(); $controlColdAfter = @(); $applyRequest = $null
    if ($guardedScenario) {
        $controlUri = "http://127.0.0.1:$Port/debug/cache/stage39-live-pressure"
        $controlHeaders = @{ 'x-llama-stage39-test-token' = $stage39Token }
        $discoverRequest = [ordered]@{ operation = 'discover' }
        $discoverJson = $discoverRequest | ConvertTo-Json -Compress
        [IO.File]::WriteAllText((Join-Path $RunRoot 'control-discover-request.json'), $discoverJson + "`n", [Text.UTF8Encoding]::new($false))
        $discoverResponse = Invoke-Stage39DiscoverS39 $controlUri $controlHeaders $discoverJson
        $controlDiscover = $discoverResponse.Content | ConvertFrom-Json
        $discoverArtifact = $controlDiscover | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $discoverArtifact.snapshot_token = '[redacted]'
        [IO.File]::WriteAllText((Join-Path $RunRoot 'control-discover-response.json'), ($discoverArtifact | ConvertTo-Json -Depth 20 -Compress) + "`n", [Text.UTF8Encoding]::new($false))
        if (-not $controlDiscover.hot_candidates) { throw 'Guarded discovery returned no hot candidate' }
        $incoming = if ($Scenario -eq 'multi-victim') {
            if (@($controlDiscover.hot_candidates).Count -ne 1) {
                throw 'TP-39-02 setup did not leave exactly one hot incoming pair'
            }
            @($controlDiscover.hot_candidates)[0]
        } elseif ($Scenario -eq 'both-filled') {
            Get-Tp3903SourceRowS39 $controlDiscover
        } else {
            @($controlDiscover.hot_candidates)[0]
        }
        if (-not $incoming) { throw 'SKIP-preflight-incoming-owner' }
        $desiredHotOrders = @()
        $nextHotOrder = [uint64] 1000
        foreach ($candidate in @($controlDiscover.hot_candidates)) {
            $order = $nextHotOrder
            $desiredHotOrders += [ordered]@{ owner_entry_id = $candidate.owner_entry_id; desired_hot_order = $order }
            $nextHotOrder++
        }
        $selectedColdSet = @($controlDiscover.cold_sets | Where-Object {
            $_.incoming_payload_id -eq $incoming.payload_id -and $_.incoming_owner_entry_id -eq $incoming.owner_entry_id
        })
        if ($selectedColdSet.Count -ne 1) { throw 'Guarded discovery incoming cold set missing or duplicated' }
        if ($Scenario -eq 'multi-victim') {
            $setupVictims = @($selectedColdSet[0].candidates)
            if ($setupVictims.Count -ne 2) { throw 'TP-39-02 setup did not leave exactly two cold victims' }
            if (@($setupVictims | Where-Object { [uint64] $_.resident_bytes -ge [uint64] $incoming.resident_bytes }).Count) {
                throw 'TP-39-02 setup victims are not both smaller than incoming'
            }
        }
        $desiredColdRanks = @()
        foreach ($candidate in @($selectedColdSet[0].candidates)) {
            $desiredColdRanks += [ordered]@{ payload_id = $candidate.payload_id; desired_cold_rank = [uint64] 77 }
        }
        if ($Scenario -eq 'both-filled') { $desiredColdRanks = @() }
        $tp3903Proof = $null; $tp3903Bindings = @()
        if ($Scenario -eq 'both-filled') {
            $linkedProofRequest = [ordered]@{ operation='proof'; snapshot_generation=$controlDiscover.snapshot_generation; snapshot_token=$controlDiscover.snapshot_token; payload_ids=@($incoming.payload_id) }
            Write-Tp3903ProofArtifactS39 (Join-Path $RunRoot 'control-linked-proof-request.json') $linkedProofRequest
            $linkedProofResponse = Invoke-WebRequest $controlUri -Method Post -Headers $controlHeaders -Body ($linkedProofRequest | ConvertTo-Json -Compress) -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
            $linkedProof = $linkedProofResponse.Content | ConvertFrom-Json
            Write-Tp3903ProofArtifactS39 (Join-Path $RunRoot 'control-linked-proof-response.json') $linkedProof
            $proofRequest = Get-Tp3903ExplicitProofRequestS39 $controlDiscover $linkedProof
            Write-Tp3903ProofArtifactS39 (Join-Path $RunRoot 'control-explicit-proof-request.json') $proofRequest
            $proofResponse = Invoke-WebRequest $controlUri -Method Post -Headers $controlHeaders -Body ($proofRequest | ConvertTo-Json -Compress) -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
            $tp3903Proof = $proofResponse.Content | ConvertFrom-Json
            Write-Tp3903ProofArtifactS39 (Join-Path $RunRoot 'control-explicit-proof-response.json') $tp3903Proof
            $tp3903Bindings = @(Get-Tp3903PreparedBindingsS39 $controlDiscover $tp3903Proof)
            $repeatDiscover = (Invoke-Stage39DiscoverS39 $controlUri $controlHeaders $discoverJson).Content | ConvertFrom-Json
            $repeatProof = (Invoke-WebRequest $controlUri -Method Post -Headers $controlHeaders -Body ($proofRequest | ConvertTo-Json -Compress) -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120).Content | ConvertFrom-Json
            Assert-Tp3903StableProofS39 $controlDiscover $tp3903Proof $repeatDiscover $repeatProof
            $loweredBudgets = Get-Tp3903LoweredBudgetsS39 @($tp3903Proof.rows)
            $MeasuredResidentPairBytes = [int64] (Add-Tp3903CheckedS39 $loweredBudgets.resident_exact_bytes $loweredBudgets.resident_checkpoint_bytes)
            $MeasuredSerializedPairBytes = [int64] (Add-Tp3903CheckedS39 $loweredBudgets.serialized_exact_bytes $loweredBudgets.serialized_checkpoint_bytes)
            $hotBudgetBytes = [int64] $loweredBudgets.hot_bytes; $coldBudgetBytes = [int64] $loweredBudgets.cold_bytes
            [IO.File]::WriteAllText((Join-Path $RunRoot 'canonical-budgets.json'), ($loweredBudgets | ConvertTo-Json -Compress) + "`n", [Text.UTF8Encoding]::new($false))
            [IO.File]::WriteAllText((Join-Path $RunRoot 'control-proof-summary.json'), ([ordered]@{ snapshot_generation=$tp3903Proof.snapshot_generation; process_bound=$true; payload_ids=@($tp3903Proof.rows.payload_id); kinds=@($tp3903Proof.rows.payload_kind) } | ConvertTo-Json -Compress) + "`n", [Text.UTF8Encoding]::new($false))
        }
        $controlScenario = switch ($Scenario) { 'multi-victim' { 'tp39-02' } 'both-filled' { 'tp39-03' } default { 'tp39-04' } }
        $applyRequest = [ordered]@{
            operation = 'apply'; scenario = $controlScenario
            hot_budget_bytes = $hotBudgetBytes; cold_budget_bytes = $coldBudgetBytes
            snapshot_generation = $controlDiscover.snapshot_generation; snapshot_token = $controlDiscover.snapshot_token
            incoming_payload_id = $incoming.payload_id; incoming_owner_entry_id = $incoming.owner_entry_id
            hot_candidates = $controlDiscover.hot_candidates; cold_sets = $controlDiscover.cold_sets
            desired_hot_orders = $desiredHotOrders; desired_cold_ranks = $desiredColdRanks
        }
        if ($Scenario -eq 'both-filled') {
            $applyRequest.tp39_03_setup = 'same_owner_kind_sequence'
            $applyRequest.run_id = 'tp39-03-canonical'
            $applyRequest.process_identity = $tp3903Proof.process_identity
            $applyRequest.proof_token = $tp3903Proof.proof_token
            $applyRequest.fault = 'none'
            $applyRequest.prepared_bindings = $tp3903Bindings
            Assert-Tp3903RequestShapeS39 ([pscustomobject] $applyRequest)
        }
        $applyJson = $applyRequest | ConvertTo-Json -Depth 20 -Compress
        $controlMetricsBefore = (Invoke-WebRequest "http://127.0.0.1:$Port/metrics" -UseBasicParsing).Content
        $controlColdBefore = Normalize-ColdInventoryS39 (Get-ColdInventoryS39 $cold)
        $controlLogBeforeOut = [string] (Get-Content $stdout -Raw -ErrorAction SilentlyContinue)
        $controlLogBeforeErr = [string] (Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
        if ($null -eq $controlLogBeforeOut) { $controlLogBeforeOut = '' }
        if ($null -eq $controlLogBeforeErr) { $controlLogBeforeErr = '' }
        $artifactRequest = $applyRequest | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        if ($artifactRequest.PSObject.Properties.Name -contains 'snapshot_token') { $artifactRequest.snapshot_token = '[redacted]' }
        if ($artifactRequest.PSObject.Properties.Name -contains 'proof_token') { $artifactRequest.proof_token = '[redacted]' }
        [IO.File]::WriteAllText((Join-Path $RunRoot 'control-apply-request.json'), ($artifactRequest | ConvertTo-Json -Depth 20 -Compress) + "`n", [Text.UTF8Encoding]::new($false))
        $applyResponse = Invoke-WebRequest $controlUri -Method Post -Headers $controlHeaders -Body $applyJson `
            -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
        $applyResponseBytes = Get-WebBodyBytesS39 $applyResponse
        $tp3903ApplyProofBytes = $null
        $controlApply = $applyResponse.Content | ConvertFrom-Json
        $tp3903Retrieved = $null
        if ($Scenario -eq 'both-filled') {
            $tp3903ApplyProofBytes = Get-JsonObjectPropertyBytesS39 $applyResponseBytes 'prepared_proof'
            $terminal = $controlApply.prepared_proof
            $retrievalRequest = [ordered]@{
                operation='prepared_proof'; process_identity=$applyRequest.process_identity
                test_session_id=$terminal.test_session_id; run_id=$applyRequest.run_id
                terminal_hmac=$terminal.terminal_hmac
            }
            $retrievalResponse = Invoke-WebRequest $controlUri -Method Post -Headers $controlHeaders `
                -Body ($retrievalRequest | ConvertTo-Json -Compress) -ContentType 'application/json' `
                -UseBasicParsing -TimeoutSec 120
            $retrievalBytes = Get-WebBodyBytesS39 $retrievalResponse
            $retryRejected = $false
            try {
                Invoke-WebRequest $controlUri -Method Post -Headers $controlHeaders -Body $applyJson `
                    -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120 | Out-Null
                throw 'TP-39-03 consumed apply retry succeeded'
            } catch {
                if ($_.Exception.Message -eq 'TP-39-03 consumed apply retry succeeded') { throw }
                $retryDetail = [string] $_.ErrorDetails.Message + [string] $_.Exception.Message
                if ($retryDetail -notmatch 'consumed') { throw 'TP-39-03 apply retry did not prove consumption' }
                $retryRejected = $true
            }
            $tp3903Retrieved = [pscustomobject]@{
                consumed=$retryRejected; retry_rejected=$retryRejected; body_bytes=$retrievalBytes
                terminal_body=($retrievalResponse.Content | ConvertFrom-Json)
            }
            $retrievalArtifact = $tp3903Retrieved.terminal_body | ConvertTo-Json -Depth 20 | ConvertFrom-Json
            $retrievalArtifact.terminal_hmac = '[redacted]'
            [IO.File]::WriteAllText((Join-Path $RunRoot 'control-prepared-proof-retrieval.json'),
                ($retrievalArtifact | ConvertTo-Json -Depth 20 -Compress) + "`n", [Text.UTF8Encoding]::new($false))
        }
        $applyArtifact = $controlApply | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        if ($null -ne $applyArtifact.prepared_proof) { $applyArtifact.prepared_proof.terminal_hmac = '[redacted]' }
        [IO.File]::WriteAllText((Join-Path $RunRoot 'control-apply-response.json'),
            ($applyArtifact | ConvertTo-Json -Depth 20 -Compress) + "`n", [Text.UTF8Encoding]::new($false))
        $controlMetricsAfter = (Invoke-WebRequest "http://127.0.0.1:$Port/metrics" -UseBasicParsing).Content
        $controlColdAfter = Normalize-ColdInventoryS39 (Get-ColdInventoryS39 $cold)
        [IO.File]::WriteAllText((Join-Path $RunRoot 'control-metrics-before.txt'), $controlMetricsBefore, [Text.UTF8Encoding]::new($false))
        [IO.File]::WriteAllText((Join-Path $RunRoot 'control-metrics-after.txt'), $controlMetricsAfter, [Text.UTF8Encoding]::new($false))
        Write-ColdInventoryS39 $controlColdBefore (Join-Path $RunRoot 'control-cold-files-before.csv')
        Write-ColdInventoryS39 $controlColdAfter (Join-Path $RunRoot 'control-cold-files-after.csv')
        $controlLogAfterOut = [string] (Get-Content $stdout -Raw -ErrorAction SilentlyContinue)
        $controlLogAfterErr = [string] (Get-Content $stderr -Raw -ErrorAction SilentlyContinue)
        if ($null -eq $controlLogAfterOut) { $controlLogAfterOut = '' }
        if ($null -eq $controlLogAfterErr) { $controlLogAfterErr = '' }
        if ($controlLogAfterOut.Length -lt $controlLogBeforeOut.Length -or
            $controlLogAfterErr.Length -lt $controlLogBeforeErr.Length) {
            throw 'Stage 39 server log shrank during guarded apply'
        }
        $controlLog = $controlLogAfterOut.Substring($controlLogBeforeOut.Length) + "`n" +
            $controlLogAfterErr.Substring($controlLogBeforeErr.Length)
        [IO.File]::WriteAllText((Join-Path $RunRoot 'control-apply-window.log'), $controlLog, [Text.UTF8Encoding]::new($false))
        if ($Scenario -eq 'both-filled') {
            Assert-Tp3903TerminalProofS39 $controlApply ([pscustomobject] $applyRequest) `
                $tp3903ApplyProofBytes $tp3903Retrieved $controlLog
        }
        switch ($controlScenario) {
            'tp39-02' { Assert-Tp3902 $controlDiscover $controlApply $applyRequest $controlMetricsBefore $controlMetricsAfter $controlColdBefore $controlColdAfter $controlLog }
            'tp39-03' { Assert-Tp3903 $controlDiscover $controlApply $applyRequest $controlMetricsBefore $controlMetricsAfter $controlColdBefore $controlColdAfter $controlLog }
            'tp39-04' { Assert-Tp3904 $controlDiscover $controlApply $applyRequest $controlMetricsBefore $controlMetricsAfter $controlColdBefore $controlColdAfter $controlLog }
        }
    }
    $restoreCacheTokens = $null
    if ($Scenario -eq 'standard') {
        [IO.File]::AppendAllText($requestPath, $restoreBody + "`n", [Text.UTF8Encoding]::new($false))
        $restore = Invoke-WebRequest "http://127.0.0.1:$Port/completion" -Method Post -Body $restoreBody `
            -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
        [IO.File]::AppendAllText($responsePath, $restore.Content + "`n", [Text.UTF8Encoding]::new($false))
        $restoreJson = $restore.Content | ConvertFrom-Json
        $restoreCacheTokens = [int64] $restoreJson.timings.cache_n
        if ($restoreCacheTokens -le 0) { throw 'Standard scenario did not restore the cold payload' }
    }
    $after = (Invoke-WebRequest "http://127.0.0.1:$Port/metrics" -UseBasicParsing).Content
    [IO.File]::WriteAllText((Join-Path $RunRoot 'metrics-before.txt'), $before, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $RunRoot 'metrics-after.txt'), $after, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllLines((Join-Path $RunRoot 'server-args.txt'), [string[]] $args, [Text.UTF8Encoding]::new($false))
    $coldAfter = Normalize-ColdInventoryS39 (Get-ColdInventoryS39 $cold)
    Write-ColdInventoryS39 $coldAfter (Join-Path $RunRoot 'cold-files-after.csv')
    $beforeSamples = Read-MetricsS39 $before
    $afterSamples = Read-MetricsS39 $after
    $metricKeys = @($beforeSamples.Keys + $afterSamples.Keys | Sort-Object -Unique)
    $deltaLines = @('metric before after delta')
    foreach ($key in $metricKeys) {
        $beforeValue = if ($beforeSamples.ContainsKey($key)) { $beforeSamples[$key] } else { 0.0 }
        $afterValue = if ($afterSamples.ContainsKey($key)) { $afterSamples[$key] } else { 0.0 }
        $delta = $afterValue - $beforeValue
        $deltaLines += ('{0} {1:R} {2:R} {3:R}' -f $key, $beforeValue, $afterValue, $delta)
    }
    [IO.File]::WriteAllLines((Join-Path $RunRoot 'metric-delta.txt'), $deltaLines, [Text.UTF8Encoding]::new($false))

    $metricNames = [ordered]@{
        HotBytes = 'llamacpp:cache_bytes'
        ColdDescriptorBytes = 'llamacpp:cache_cold_bytes'
        ColdPayloadBytes = 'llamacpp:cache_cold_payload_bytes'
        Promotions = 'llamacpp:cache_payload_promotions_total'
        PayloadEvictions = 'llamacpp:cache_payload_evictions_total'
        Entries = 'llamacpp:cache_entries'
        Branches = 'llamacpp:cache_namespace_nodes'
        Pruning = 'llamacpp:cache_branch_pruning_total'
    }
    $beforeState = [ordered]@{}
    $afterState = [ordered]@{}
    $deltaState = [ordered]@{}
    foreach ($metric in $metricNames.GetEnumerator()) {
        $beforeState[$metric.Key] = Sum-MetricS39 $beforeSamples $metric.Value @{ mode = 'hybrid' }
        $afterState[$metric.Key] = Sum-MetricS39 $afterSamples $metric.Value @{ mode = 'hybrid' }
        $deltaState[$metric.Key] = $afterState[$metric.Key] - $beforeState[$metric.Key]
    }
    $beforeFileBytes = [double] (($coldBefore | Measure-Object Length -Sum).Sum)
    $afterFileBytes = [double] (($coldAfter | Measure-Object Length -Sum).Sum)
    $beforeQuarantineBytes = [double] (($coldBefore | Where-Object Path -Match '\.q\.\d+$' | Measure-Object Length -Sum).Sum)
    $afterQuarantineBytes = [double] (($coldAfter | Where-Object Path -Match '\.q\.\d+$' | Measure-Object Length -Sum).Sum)
    $state = [ordered]@{
        Scenario = $Scenario
        MeasuredResidentPairBytes = $MeasuredResidentPairBytes
        MeasuredSerializedPairBytes = $MeasuredSerializedPairBytes
        HotBudgetBytes = $hotBudgetBytes
        ColdBudgetBytes = if ($Scenario -in @('cold-disabled', 'legacy')) { 0 } else { $coldBudgetBytes }
        Before = [ordered]@{ Metrics = $beforeState; ColdFiles = $coldBefore.Count; ColdFileBytes = $beforeFileBytes; QuarantineBytes = $beforeQuarantineBytes }
        After = [ordered]@{ Metrics = $afterState; ColdFiles = $coldAfter.Count; ColdFileBytes = $afterFileBytes; QuarantineBytes = $afterQuarantineBytes }
        Delta = [ordered]@{ Metrics = $deltaState; ColdFiles = $coldAfter.Count - $coldBefore.Count; ColdFileBytes = $afterFileBytes - $beforeFileBytes; QuarantineBytes = $afterQuarantineBytes - $beforeQuarantineBytes }
        Restore = [ordered]@{ Attempted = $Scenario -eq 'standard'; CacheTokens = $restoreCacheTokens }
        Reconciliation = [ordered]@{
            ColdDescriptorBytesMatchPayloadBytes = $afterState.ColdDescriptorBytes -eq $afterState.ColdPayloadBytes
            ColdDescriptorBytesDoNotExceedFiles = $afterState.ColdDescriptorBytes -le $afterFileBytes
            PayloadEvictionDeltaZero = $deltaState.PayloadEvictions -eq 0
            PruningDeltaZero = $deltaState.Pruning -eq 0
        }
    }
    [IO.File]::WriteAllText((Join-Path $RunRoot 'state.json'), ($state | ConvertTo-Json -Depth 8) + "`n", [Text.UTF8Encoding]::new($false))
    $decisions = Metric-S39 $after 'llamacpp:cache_two_layer_decisions_total'
    $transactions = Metric-S39 $after 'llamacpp:cache_cold_transactions_total'
    Assert-Stage39MetricRowsS39 $Scenario $decisions $transactions
    if ($Scenario -notin @('hot-zero', 'legacy')) {
        if (-not $decisions) { throw 'No Stage 39 decision series emitted' }
        if ($Scenario -eq 'standard') {
            $retained = (Sum-MetricS39 $afterSamples 'llamacpp:cache_two_layer_decisions_total' `
                @{ mode = 'hybrid'; result = 'retained_cold'; reason = 'cold_room' }) -
                (Sum-MetricS39 $beforeSamples 'llamacpp:cache_two_layer_decisions_total' `
                @{ mode = 'hybrid'; result = 'retained_cold'; reason = 'cold_room' })
            $retained += (Sum-MetricS39 $afterSamples 'llamacpp:cache_two_layer_decisions_total' `
                @{ mode = 'hybrid'; result = 'retained_cold'; reason = 'cold_room_made' }) -
                (Sum-MetricS39 $beforeSamples 'llamacpp:cache_two_layer_decisions_total' `
                @{ mode = 'hybrid'; result = 'retained_cold'; reason = 'cold_room_made' })
            $commits = (Sum-MetricS39 $afterSamples 'llamacpp:cache_cold_transactions_total' `
                @{ mode = 'hybrid'; result = 'commit'; reason = 'none' }) -
                (Sum-MetricS39 $beforeSamples 'llamacpp:cache_cold_transactions_total' `
                @{ mode = 'hybrid'; result = 'commit'; reason = 'none' })
            if ($retained -le 0) { throw 'No retained_cold/cold_room or retained_cold/cold_room_made delta' }
            if ($commits -le 0) { throw 'No committed cold transaction with reason=none delta' }
            if ($deltaState.Promotions -le 0) { throw 'Standard scenario did not record a cold promotion' }
            if ($deltaState.PayloadEvictions -ne 0) { throw 'Standard scenario changed payload eviction total' }
            if ($deltaState.Pruning -ne 0) { throw 'Standard scenario changed branch pruning total' }
        }
        if ($Scenario -eq 'oversized-both' -and
            -not ($decisions -match 'result="evicted".*reason="oversized_both"')) {
            throw 'No evicted/oversized_both production series emitted'
        }
        if ($Scenario -eq 'both-filled' -and
            -not ($decisions -match 'result="evicted".*reason="both_filled"')) {
            throw 'No evicted/both_filled production series emitted'
        }
        if ($Scenario -eq 'cold-disabled' -and
            -not ($decisions -match 'result="bypassed".*reason="cold_disabled"')) {
            throw 'No bypassed/cold_disabled production series emitted'
        }
    }
    $bad = Select-String -Path $stdout, $stderr -Pattern 'ASSERT|access violation|corrupt|exception' -CaseSensitive:$false
    if ($bad) { throw 'Fatal or integrity signature found in server logs' }
    [pscustomobject]@{
        Outcome = 'PASS'; Scenario = $Scenario; Requests = $workload.Count; DecisionSeries = $decisions.Count
        TransactionSeries = $transactions.Count; ColdFiles = $coldAfter.Count; RestoreCacheTokens = $restoreCacheTokens
        RunRoot = $RunRoot
    } | ConvertTo-Json | Set-Content (Join-Path $RunRoot 'summary.json') -Encoding utf8
} finally {
    if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
    if ($guardedScenario) {
        Remove-Item Env:LLAMA_STAGE39_LIVE_TEST_SEAM -ErrorAction SilentlyContinue
        Remove-Item Env:LLAMA_STAGE39_LIVE_TEST_TOKEN -ErrorAction SilentlyContinue
    }
    if ($slotSave -and (Test-Path $slotSave) -and -not (Get-ChildItem $slotSave -Force)) {
        Remove-Item $slotSave -Force
    }
}
