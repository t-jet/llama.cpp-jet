param(
    [Parameter(Mandatory=$true)] [string] $EventsPath,
    [Parameter(Mandatory=$true)] [string] $OutputPath,
    [int] $HotBudgetMiB = 2048,
    [int] $ColdBudgetMiB = 8192,
    [double] $EstimatedPayloadMiBPerToken = 0.0
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\lib\stage34-replay-parser.ps1"
. "$PSScriptRoot\lib\stage34-request-renderer.ps1"
. "$PSScriptRoot\lib\stage34-result-analyzer.ps1"

$events = Read-Stage34JsonLines -Path $EventsPath
$seen = @{}
$branchTips = @{}
$hotWindow = [Math]::Max(2, [Math]::Floor($HotBudgetMiB / 512))
$hotBudgetBytes = [int64]$HotBudgetMiB * 1MB
$outputDir = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
}
Remove-Item -LiteralPath $OutputPath -Force -ErrorAction SilentlyContinue

foreach ($event in $events) {
    $hasTokenPlan = ([int]$event.token_count -gt 0) -and -not [string]::IsNullOrEmpty([string]$event.token_checksum)
    $key = "$($event.model_id_hash)|$($event.token_count)|$($event.token_checksum)"
    $predecessor = ""
    $expectedClass = "first_observation"
    $expectedResult = "miss"
    $requiredResidency = "none"
    $boundedReason = $event.blocked_reason
    $candidateSource = "none"
    $budgetWindowId = "hot-$hotWindow"
    $notes = ""
    $estimatedPayloadMiB = 0.0
    $eventPayloadProp = $event.PSObject.Properties["estimated_payload_mib"]
    if ($null -ne $eventPayloadProp) {
        $estimatedPayloadMiB = [double]$eventPayloadProp.Value
    } elseif ($EstimatedPayloadMiBPerToken -gt 0.0) {
        $estimatedPayloadMiB = [double]$event.token_count * $EstimatedPayloadMiBPerToken
    }
    $estimatedPayloadBytes = [int64]([Math]::Ceiling($estimatedPayloadMiB * 1MB))
    $saveRejectedByHotBudget = ($estimatedPayloadBytes -gt 0 -and $hotBudgetBytes -ge 0 -and $estimatedPayloadBytes -gt $hotBudgetBytes)

    if ($seen.ContainsKey($key) -and [string]::IsNullOrEmpty($event.blocked_reason)) {
        if (-not $hasTokenPlan) {
            throw "Stage 34 preflight exact hit $($event.request_id) lacks token_count/token_checksum from rendered replay plan."
        }
        $predecessor = $seen[$key].request_id
        $distance = [int]$event.turn_index - [int]$seen[$key].turn_index
        $expectedClass = "exact_duplicate_request_burst"
        $candidateSource = if ($event.branch_id_hash -eq $seen[$key].branch_id_hash) { "same_branch_exact_checksum" } else { "cross_branch_exact_checksum" }
        if ($saveRejectedByHotBudget) {
            $expectedResult = "miss"
            $requiredResidency = "none"
            $budgetWindowId = "hot-budget-rejected-estimated-$([Math]::Round($estimatedPayloadMiB, 3))-mib"
            $boundedReason = "EXPECTED-HOT-BUDGET-SAVE-REJECTED"
            $notes = "estimated_payload_mib=$([Math]::Round($estimatedPayloadMiB, 3)); hot_budget_mib=$HotBudgetMiB"
        } elseif ($distance -le $hotWindow) {
            $expectedResult = "hit"
            $requiredResidency = "hot"
            $budgetWindowId = "hot-$hotWindow-distance-$distance"
            $boundedReason = ""
        } elseif ($ColdBudgetMiB -gt 0) {
            $expectedResult = "hit"
            $requiredResidency = "cold"
            $budgetWindowId = "cold-distance-$distance"
            $boundedReason = ""
        } else {
            $expectedResult = "miss"
            $requiredResidency = "cold"
            $budgetWindowId = "cold-disabled-distance-$distance"
            $boundedReason = "EXPECTED-COLD-MISS"
        }
    } elseif (($event.event_kind -eq "continuation" -or $event.event_kind -eq "subagent_return") -and
              -not [string]::IsNullOrEmpty([string]$event.parent_branch_id_hash) -and
              $branchTips.ContainsKey($event.parent_branch_id_hash)) {
        $parentTip = $branchTips[$event.parent_branch_id_hash]
        $predecessor = $parentTip.request_id
        $expectedClass = "main_continuation_after_subagent_return"
        $candidateSource = "parent_branch_tip"
        $boundedReason = if ($event.blocked_reason) { $event.blocked_reason } else { "unsafe_prefix_rejected" }
    }

    if ($hasTokenPlan) { $seen[$key] = $event }
    $branchTips[$event.branch_id_hash] = $event
    Write-Stage34JsonLine -Path $OutputPath -Object ([pscustomobject]@{
        schema_version = 1
        replay_request_id = $event.request_id
        transcript_row = $event.transcript_row
        branch_id_hash = $event.branch_id_hash
        predecessor_request_id = $predecessor
        candidate_source = $candidateSource
        expected_class = $expectedClass
        expected_result = $expectedResult
        required_residency = $requiredResidency
        token_count = $event.token_count
        token_checksum = $event.token_checksum
        budget_window_id = $budgetWindowId
        bounded_miss_reason = $boundedReason
        notes = $notes
    })
}

$exactHits = @(Read-Stage34JsonLines -Path $OutputPath | Where-Object { $_.expected_result -eq "hit" }).Count
if ($exactHits -eq 0) {
    Write-Warning "Stage 34 expected-hit preflight found no exact resident hit rows."
}
Write-Host "Stage34 expected-hit rows written: $OutputPath"
Write-Host "Stage34 expected hit rows: $exactHits"
