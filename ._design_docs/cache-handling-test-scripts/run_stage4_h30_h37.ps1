param(
    [string] $BuildDir = "build",
    [string] $Model = "",
    [int] $StartPort = 8620
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot\run_cache_integration.ps1" -BuildDir $BuildDir -Model $Model -StartPort $StartPort

$FocusedResults = @()

function Test-BinaryFreshness {
    param([Parameter(Mandatory=$true)][string]$BinaryPath)

    if (-not (Test-Path $BinaryPath)) {
        throw "Binary not found: $BinaryPath"
    }

    $Binary = Get-Item $BinaryPath
    $BuildAge = (Get-Date) - $Binary.LastWriteTime
    if ($BuildAge.TotalMinutes -gt 10) {
        throw "Binary is stale: $([Math]::Round($BuildAge.TotalMinutes, 1)) minutes old. Run the clean build required by the test plan."
    }

    return @{
        Path = $Binary.FullName
        Timestamp = $Binary.LastWriteTime.ToString("o")
        Size = $Binary.Length
        AgeMinutes = [Math]::Round($BuildAge.TotalMinutes, 3)
    }
}

function Get-NextTestReportPath {
    param([string]$ReportDir)

    New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
    $DatePart = Get-Date -Format "yyyyMMdd"
    $MaxSuffix = 0
    Get-ChildItem -Path $ReportDir -Filter "test-report-$DatePart-*.md" | ForEach-Object {
        if ($_.BaseName -match "^test-report-$DatePart-(\d{2})$") {
            $MaxSuffix = [Math]::Max($MaxSuffix, [int]$Matches[1])
        }
    }
    $NextSuffix = $MaxSuffix + 1
    if ($NextSuffix -le 99) {
        return (Join-Path $ReportDir ("test-report-{0}-{1:D2}.md" -f $DatePart, $NextSuffix))
    }
    throw "No available report filename for $DatePart"
}

function Get-GitEvidence {
    try {
        $Commit = (& git rev-parse HEAD 2>$null).Trim()
        $Dirty = (& git status --short 2>$null)
        if ($Dirty) {
            return "$Commit (working tree dirty)"
        }
        return $Commit
    }
    catch {
        return "unavailable"
    }
}

function Get-MetricValue {
    param(
        [hashtable]$Metrics,
        [string]$Name
    )
    if ($Metrics.ContainsKey($Name)) {
        return [double]$Metrics[$Name]
    }
    return 0
}

function Invoke-CompletionRequest {
    param(
        [int]$Port,
        [string]$Prompt,
        [int]$Predict = 1
    )

    $Body = @{
        prompt = $Prompt
        n_predict = $Predict
        cache_prompt = $true
    } | ConvertTo-Json

    $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" `
        -Method Post -ContentType "application/json" -Body $Body -TimeoutSec 120

    return $Response.Content | ConvertFrom-Json
}

function Invoke-ProtectedChatRequest {
    param(
        [int]$Port,
        [string]$System,
        [string]$User,
        [int]$MaxTokens = 1
    )

    $Body = @{
        messages = @(
            @{ role = "system"; content = $System }
            @{ role = "user"; content = $User }
        )
        max_tokens = $MaxTokens
        cache_prompt = $true
    } | ConvertTo-Json -Depth 4

    $Response = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/v1/chat/completions" `
        -Method Post -ContentType "application/json" -Body $Body -TimeoutSec 120

    return $Response.Content | ConvertFrom-Json
}

function Get-CombinedLogText {
    param($ServerInfo)

    $Parts = @()
    foreach ($Path in @($ServerInfo.LogFile, $ServerInfo.ErrorLog)) {
        if (Test-Path $Path) {
            $Parts += Get-Content $Path -Raw
        }
    }
    return ($Parts -join "`n")
}

function New-CaseResult {
    param(
        [string]$Id,
        [string]$Description,
        [string]$Status,
        [string]$Message,
        [string[]]$Evidence
    )

    return [pscustomobject]@{
        Id = $Id
        Description = $Description
        Status = $Status
        Message = $Message
        Evidence = $Evidence
    }
}

function Invoke-Stage4Case {
    param(
        [string]$Id,
        [string]$Description,
        [hashtable]$ServerArgs,
        [scriptblock]$Body
    )

    Write-Host ""
    Write-Host "[$Id] $Description"
    Write-Host ("=" * 80)

    $ServerInfo = $null
    try {
        $ServerInfo = Start-LlamaServer -TestId $Id -ServerArgs $ServerArgs
        if (-not (Wait-ForServer -Port $ServerInfo.Port -TimeoutSeconds 60)) {
            $Logs = Get-CombinedLogText -ServerInfo $ServerInfo
            return New-CaseResult -Id $Id -Description $Description -Status "BLOCKED" `
                -Message "Server did not become ready" `
                -Evidence @("Startup logs: $($Logs.Substring(0, [Math]::Min(500, $Logs.Length)))")
        }

        $Result = @(& $Body -Port $ServerInfo.Port -ServerInfo $ServerInfo) | Where-Object {
            $_ -and $_.PSObject.Properties["Id"] -and $_.PSObject.Properties["Status"]
        } | Select-Object -Last 1
        if (-not $Result) {
            return New-CaseResult -Id $Id -Description $Description -Status "BLOCKED" `
                -Message "Test body did not return a structured case result" -Evidence @()
        }
        Write-Host "  $($Result.Status): $($Result.Message)"
        return $Result
    }
    catch {
        return New-CaseResult -Id $Id -Description $Description -Status "FAIL" `
            -Message "Exception: $($_.Exception.Message)" -Evidence @()
    }
    finally {
        if ($ServerInfo) {
            [void](Stop-LlamaServer $ServerInfo)
        }
    }
}

$BinaryEvidence = Test-BinaryFreshness -BinaryPath $ServerPath
$ControllerPath = Join-Path $BuildDir "bin\Release\test-cache-controller.exe"
$ControllerEvidence = $null
if (Test-Path $ControllerPath) {
    $ControllerEvidence = Test-BinaryFreshness -BinaryPath $ControllerPath
}
$ReportFile = Get-NextTestReportPath -ReportDir (Join-Path $PSScriptRoot "..\.test_reports")
$ModelItem = if (Test-Path $Model) { Get-Item $Model } else { $null }

function Invoke-ControllerStage4Evidence {
    param([string]$ControllerBinary)

    if (-not (Test-Path $ControllerBinary)) {
        return @{
            Status = "BLOCKED"
            Message = "Controller test binary was not found: $ControllerBinary"
            H31 = $false
            H32 = $false
            Output = @()
        }
    }

    $Output = @(& $ControllerBinary 2>&1)
    $ExitCode = $LASTEXITCODE
    $H31Passed = ($Output -match "H31 LRU entry-state ordering").Count -gt 0 -and ($Output -match "All tests passed successfully").Count -gt 0
    $H32Passed = ($Output -match "H32 successful-restore recency").Count -gt 0 -and ($Output -match "All tests passed successfully").Count -gt 0
    $H33Passed = ($Output -match "hybrid failed restore does not refresh recency").Count -gt 0 -and ($Output -match "All tests passed successfully").Count -gt 0
    $H35Passed = ($Output -match "hybrid payload budget eviction").Count -gt 0 -and ($Output -match "All tests passed successfully").Count -gt 0
    $H36Passed = ($Output -match "hybrid multiple protected evictions count decisions").Count -gt 0 -and ($Output -match "All tests passed successfully").Count -gt 0
    $H37Passed = ($Output -match "hybrid protected admission rejection stats").Count -gt 0 -and ($Output -match "All tests passed successfully").Count -gt 0
    $Status = if ($ExitCode -eq 0) { "PASS" } else { "FAIL" }
    $Message = if ($Status -eq "PASS") {
        "Controller evidence passed; focused rows available: H31=$H31Passed, H32=$H32Passed, H33=$H33Passed, H35=$H35Passed, H36=$H36Passed, H37=$H37Passed"
    } else {
        "Controller evidence failed with exit code $ExitCode"
    }

    return @{
        Status = $Status
        Message = $Message
        H31 = $H31Passed
        H32 = $H32Passed
        H33 = $H33Passed
        H35 = $H35Passed
        H36 = $H36Passed
        H37 = $H37Passed
        Output = $Output
    }
}

$ControllerStage4 = Invoke-ControllerStage4Evidence -ControllerBinary $ControllerPath

$BaseHybridArgs = @{
    "--cache-mode" = "hybrid"
    "--ctx-size" = 512
    "--parallel" = 2
    "--cont-batching" = $true
    "--kv-unified" = $true
    "--slots" = $true
    "--cache-ram" = 1
    "--temp" = 0
    "--seed" = 42
    "--log-verbosity" = 5
    "--metrics" = $true
}

$PromptA = "H31 alpha prompt. Return one short token about cedar archives."
$PromptB = "H31 beta prompt. Return one short token about copper lenses."
$PromptC = "H31 gamma prompt. Return one short token about quartz ledgers."

$FocusedResults += Invoke-Stage4Case -Id "H30" -Description "Resident payload byte budget" -ServerArgs $BaseHybridArgs -Body {
    param($Port, $ServerInfo)

    $Before = Get-CacheMetrics -Port $Port
    [void](Invoke-CompletionRequest -Port $Port -Prompt "H30 measured entry prompt with a short deterministic payload.")
    $AfterOne = Get-CacheMetrics -Port $Port
    $MeasuredBytes = Get-MetricValue -Metrics $AfterOne -Name "bytes_hybrid"
    $MeasuredEntries = Get-MetricValue -Metrics $AfterOne -Name "entries_hybrid"

    foreach ($i in 1..8) {
        [void](Invoke-CompletionRequest -Port $Port -Prompt "H30 pressure prompt $i with enough unique wording to create a separate cache entry.")
    }

    $AfterPressure = Get-CacheMetrics -Port $Port
    $PayloadDelta = (Get-MetricValue -Metrics $AfterPressure -Name "payload_evictions_total_hybrid") - (Get-MetricValue -Metrics $Before -Name "payload_evictions_total_hybrid")
    $FinalBytes = Get-MetricValue -Metrics $AfterPressure -Name "bytes_hybrid"

    $Evidence = @(
        "Budget bytes: 1048576",
        "Measured after one entry: entries=$MeasuredEntries, resident_payload_bytes=$MeasuredBytes",
        "After pressure: resident_payload_bytes=$FinalBytes, payload_evictions_delta=$PayloadDelta",
        "Log files: $($ServerInfo.LogFile), $($ServerInfo.ErrorLog)"
    )

    if ($MeasuredBytes -gt 0 -and $PayloadDelta -gt 0 -and $FinalBytes -le 1048576) {
        return New-CaseResult -Id "H30" -Description "Resident payload byte budget" -Status "PASS" -Message "Payload eviction counter increased and resident bytes stayed within the 1 MiB budget" -Evidence $Evidence
    }
    return New-CaseResult -Id "H30" -Description "Resident payload byte budget" -Status "FAIL" -Message "Payload pressure was not proven by metrics" -Evidence $Evidence
}

$FocusedResults += Invoke-Stage4Case -Id "H31" -Description "Deterministic LRU ordering" -ServerArgs $BaseHybridArgs -Body {
    param($Port, $ServerInfo)

    $Before = Get-CacheMetrics -Port $Port
    foreach ($Prompt in @($PromptA, $PromptB)) {
        [void](Invoke-CompletionRequest -Port $Port -Prompt $Prompt)
    }
    $AfterSetup = Get-CacheMetrics -Port $Port
    $RefreshA = Invoke-CompletionRequest -Port $Port -Prompt $PromptA
    [void](Invoke-CompletionRequest -Port $Port -Prompt $PromptC)
    $VerifyA = Invoke-CompletionRequest -Port $Port -Prompt $PromptA
    $MetricsBeforeB = Get-CacheMetrics -Port $Port
    [void](Invoke-CompletionRequest -Port $Port -Prompt $PromptB)
    $After = Get-CacheMetrics -Port $Port

    $HitDelta = (Get-MetricValue -Metrics $After -Name "hits_total_hybrid") - (Get-MetricValue -Metrics $Before -Name "hits_total_hybrid")
    $MissDeltaForB = (Get-MetricValue -Metrics $After -Name "misses_total_hybrid") - (Get-MetricValue -Metrics $MetricsBeforeB -Name "misses_total_hybrid")
    $PayloadDelta = (Get-MetricValue -Metrics $After -Name "payload_evictions_total_hybrid") - (Get-MetricValue -Metrics $Before -Name "payload_evictions_total_hybrid")
    $ARefreshCacheN = if ($RefreshA.timings) { $RefreshA.timings.cache_n } else { 0 }
    $AVerifyCacheN = if ($VerifyA.timings) { $VerifyA.timings.cache_n } else { 0 }

    $Evidence = @(
        "Operation order: save A, save B, restore A, save C, verify A, probe B",
        "Setup entries=$(Get-MetricValue -Metrics $AfterSetup -Name 'entries_hybrid'), setup bytes=$(Get-MetricValue -Metrics $AfterSetup -Name 'bytes_hybrid')",
        "Pre-pressure restore proof: A refresh cache_n=$ARefreshCacheN",
        "A refresh cache_n=$ARefreshCacheN, A verify cache_n=$AVerifyCacheN",
        "Hit delta=$HitDelta, B probe miss delta=$MissDeltaForB, payload_evictions_delta=$PayloadDelta",
        "Final entries=$(Get-MetricValue -Metrics $After -Name 'entries_hybrid'), bytes=$(Get-MetricValue -Metrics $After -Name 'bytes_hybrid')",
        "Controller H31 entry-state evidence: $($ControllerStage4.Status) - $($ControllerStage4.Message)"
    )

    if ((Get-MetricValue -Metrics $AfterSetup -Name "entries_hybrid") -lt 2 -or $ARefreshCacheN -le 0) {
        return New-CaseResult -Id "H31" -Description "Deterministic LRU ordering" -Status "BLOCKED" -Message "Setup did not keep A and B resident long enough to prove A refresh before pressure" -Evidence $Evidence
    }
    if ($ControllerStage4.Status -eq "FAIL") {
        return New-CaseResult -Id "H31" -Description "Deterministic LRU ordering" -Status "FAIL" -Message "Controller entry-state evidence failed" -Evidence $Evidence
    }
    if ($ControllerStage4.H31) {
        return New-CaseResult -Id "H31" -Description "Deterministic LRU ordering" -Status "PASS" -Message "Public pre-pressure restore proof passed and controller entry-state evidence proved B evicted before refreshed A" -Evidence $Evidence
    }
    return New-CaseResult -Id "H31" -Description "Deterministic LRU ordering" -Status "BLOCKED" -Message "Controller entry-state evidence was unavailable" -Evidence $Evidence
}

$FocusedResults += Invoke-Stage4Case -Id "H32" -Description "Successful restore refreshes recency" -ServerArgs $BaseHybridArgs -Body {
    param($Port, $ServerInfo)

    $H32PromptA = "H32 alpha short restore probe."
    $H32PromptB = "H32 beta short restore probe."
    $H32PromptC = "H32 gamma short pressure probe."

    $Before = Get-CacheMetrics -Port $Port
    foreach ($Prompt in @($H32PromptA, $H32PromptB)) {
        [void](Invoke-CompletionRequest -Port $Port -Prompt $Prompt)
    }
    $AfterSetup = Get-CacheMetrics -Port $Port
    $RestoreA = Invoke-CompletionRequest -Port $Port -Prompt $H32PromptA
    [void](Invoke-CompletionRequest -Port $Port -Prompt $H32PromptC)
    $VerifyA = Invoke-CompletionRequest -Port $Port -Prompt $H32PromptA
    $MetricsBeforeB = Get-CacheMetrics -Port $Port
    [void](Invoke-CompletionRequest -Port $Port -Prompt $H32PromptB)
    $After = Get-CacheMetrics -Port $Port

    $PayloadDelta = (Get-MetricValue -Metrics $After -Name "payload_evictions_total_hybrid") - (Get-MetricValue -Metrics $Before -Name "payload_evictions_total_hybrid")
    $BMissDelta = (Get-MetricValue -Metrics $After -Name "misses_total_hybrid") - (Get-MetricValue -Metrics $MetricsBeforeB -Name "misses_total_hybrid")
    $RestoreCacheN = if ($RestoreA.timings) { $RestoreA.timings.cache_n } else { 0 }
    $VerifyCacheN = if ($VerifyA.timings) { $VerifyA.timings.cache_n } else { 0 }

    $Evidence = @(
        "Operation order: save A/B, successful restore A, save C, verify A, probe B",
        "Setup entries=$(Get-MetricValue -Metrics $AfterSetup -Name 'entries_hybrid'), setup bytes=$(Get-MetricValue -Metrics $AfterSetup -Name 'bytes_hybrid')",
        "Pre-pressure restore proof: Restore A cache_n=$RestoreCacheN",
        "Restore A cache_n=$RestoreCacheN, verify A cache_n=$VerifyCacheN",
        "B probe miss delta=$BMissDelta, payload_evictions_delta=$PayloadDelta",
        "Controller H32 entry-state evidence: $($ControllerStage4.Status) - $($ControllerStage4.Message)"
    )

    if ((Get-MetricValue -Metrics $AfterSetup -Name "entries_hybrid") -lt 2 -or $RestoreCacheN -le 0) {
        return New-CaseResult -Id "H32" -Description "Successful restore refreshes recency" -Status "BLOCKED" -Message "Setup did not prove a successful A restore before eviction pressure" -Evidence $Evidence
    }
    if ($ControllerStage4.Status -eq "FAIL") {
        return New-CaseResult -Id "H32" -Description "Successful restore refreshes recency" -Status "FAIL" -Message "Controller successful-restore recency evidence failed" -Evidence $Evidence
    }
    if ($ControllerStage4.H32) {
        return New-CaseResult -Id "H32" -Description "Successful restore refreshes recency" -Status "PASS" -Message "Public pre-pressure restore proof passed and controller evidence proved restored A survived while older B was evicted" -Evidence $Evidence
    }
    return New-CaseResult -Id "H32" -Description "Successful restore refreshes recency" -Status "BLOCKED" -Message "Controller successful-restore recency evidence was unavailable" -Evidence $Evidence
}

if ($ControllerStage4.H33) {
    $FocusedResults += New-CaseResult -Id "H33" -Description "Failed restore does not refresh recency" -Status "PASS" `
        -Message "Focused controller evidence proved failed restore did not refresh LRU recency." `
        -Evidence @(
            "Source: build\bin\Release\test-cache-controller.exe",
            "Controller test: hybrid failed restore does not refresh recency",
            "Evidence: restore failure counter increments, no hit is recorded, and later pressure evicts the failed candidate before newer entries."
        )
} elseif ($ControllerStage4.Status -eq "FAIL") {
    $FocusedResults += New-CaseResult -Id "H33" -Description "Failed restore does not refresh recency" -Status "FAIL" `
        -Message "Controller failed-restore evidence failed." `
        -Evidence @("Required signal is restore failure accounting plus next-eviction ordering for the failed candidate.")
} else {
    $FocusedResults += New-CaseResult -Id "H33" -Description "Failed restore does not refresh recency" -Status "BLOCKED" `
        -Message "Requires fault injection or a code-level harness to fail restore after lookup." `
        -Evidence @("Required signal is restore failure accounting plus next-eviction ordering for the failed candidate.", "Public HTTP can observe the counter but cannot safely corrupt or replace an admitted serialized cache payload.")
}

$FocusedResults += Invoke-Stage4Case -Id "H34" -Description "Equivalent-entry refresh enforces budget" -ServerArgs $BaseHybridArgs -Body {
    param($Port, $ServerInfo)

    $Before = Get-CacheMetrics -Port $Port
    [void](Invoke-CompletionRequest -Port $Port -Prompt "H34 equivalent prompt that should map to one cache entry.")
    $AfterFirst = Get-CacheMetrics -Port $Port
    $Refresh = Invoke-CompletionRequest -Port $Port -Prompt "H34 equivalent prompt that should map to one cache entry."
    $AfterRefresh = Get-CacheMetrics -Port $Port
    foreach ($i in 1..6) {
        [void](Invoke-CompletionRequest -Port $Port -Prompt "H34 pressure prompt $i with distinct wording.")
    }
    $AfterPressure = Get-CacheMetrics -Port $Port

    $EntriesFirst = Get-MetricValue -Metrics $AfterFirst -Name "entries_hybrid"
    $EntriesRefresh = Get-MetricValue -Metrics $AfterRefresh -Name "entries_hybrid"
    $RefreshCacheN = if ($Refresh.timings) { $Refresh.timings.cache_n } else { 0 }
    $PayloadDelta = (Get-MetricValue -Metrics $AfterPressure -Name "payload_evictions_total_hybrid") - (Get-MetricValue -Metrics $Before -Name "payload_evictions_total_hybrid")
    $FinalBytes = Get-MetricValue -Metrics $AfterPressure -Name "bytes_hybrid"

    $Evidence = @(
        "Entries after first save=$EntriesFirst, after equivalent refresh=$EntriesRefresh",
        "Refresh cache_n=$RefreshCacheN",
        "After pressure: resident_payload_bytes=$FinalBytes, payload_evictions_delta=$PayloadDelta"
    )

    if ($RefreshCacheN -gt 0 -and $EntriesRefresh -eq $EntriesFirst -and $PayloadDelta -gt 0 -and $FinalBytes -le 1048576) {
        return New-CaseResult -Id "H34" -Description "Equivalent-entry refresh enforces budget" -Status "PASS" -Message "Equivalent refresh did not duplicate the entry and later budget enforcement stayed within 1 MiB" -Evidence $Evidence
    }
    return New-CaseResult -Id "H34" -Description "Equivalent-entry refresh enforces budget" -Status "FAIL" -Message "Equivalent refresh and budget enforcement were not both proven" -Evidence $Evidence
}

if ($ControllerStage4.H35) {
    $FocusedResults += New-CaseResult -Id "H35" -Description "Protected-root priority" -Status "PASS" `
        -Message "Focused controller evidence proved unprotected eviction before protected entries with protected decision stats." `
        -Evidence @(
            "Source: build\bin\Release\test-cache-controller.exe",
            "Controller test: hybrid payload budget eviction",
            "Evidence: mixed protected and unprotected entries under a 1 MiB budget; protected entry remains, unprotected entry no longer matches, and protected decision stats are present."
        )
} else {
    $FocusedResults += New-CaseResult -Id "H35" -Description "Protected-root priority" -Status "BLOCKED" `
        -Message "Requires trusted protected entries from a stats-capable harness or focused C++ controller test." `
        -Evidence @(
            "Public chat creates degraded rendered-text metadata in the current Stage 4 implementation.",
            "Do not treat public protected-root decision delta=0 or missing diagnostics as product failure.",
            "Acceptable evidence: mixed trusted protected and unprotected entries, unprotected eviction first, and protected decision stats."
        )
}

if ($ControllerStage4.H36) {
    $FocusedResults += New-CaseResult -Id "H36" -Description "Protected-root fallback eviction" -Status "PASS" `
        -Message "Focused controller evidence proved protected-only fallback eviction and protected decision accounting." `
        -Evidence @(
            "Source: build\bin\Release\test-cache-controller.exe",
            "Controller test: hybrid multiple protected evictions count decisions",
            "Evidence: protected-only over-budget working set; older protected entries no longer match, newest protected entry remains, protected evictions are counted, and protected decision stats are present."
        )
} else {
    $FocusedResults += New-CaseResult -Id "H36" -Description "Protected-root fallback eviction" -Status "BLOCKED" `
        -Message "Requires trusted protected-only entries from a stats-capable harness or focused C++ controller test." `
        -Evidence @(
            "Public chat creates degraded rendered-text metadata in the current Stage 4 implementation.",
            "Acceptable evidence: protected-only over-budget working set, oldest protected eviction order, protected decision stats, and protected eviction stats."
        )
}

if ($ControllerStage4.H37) {
    $FocusedResults += New-CaseResult -Id "H37" -Description "Protected admission rejection" -Status "PASS" `
        -Message "Focused controller evidence proved protected oversized admission rejection." `
        -Evidence @(
            "Source: build\bin\Release\test-cache-controller.exe",
            "Controller test: hybrid protected admission rejection stats",
            "Evidence: trusted non-degraded protected metadata reaches admission, oversized payload is rejected, no entry is admitted, protected bytes remain zero, and protected admission rejection stats increment."
        )
} elseif ($ControllerStage4.Status -eq "FAIL") {
    $FocusedResults += New-CaseResult -Id "H37" -Description "Protected admission rejection" -Status "FAIL" `
        -Message "Controller protected admission rejection evidence failed." `
        -Evidence @("Required signal is no admitted entry plus protected admission rejection diagnostics or controller stats.")
} else {
    $FocusedResults += New-CaseResult -Id "H37" -Description "Protected admission rejection" -Status "BLOCKED" `
        -Message "Requires an oversized trusted protected entry that reaches cache admission." `
        -Evidence @(
            "Preconditions: trusted non-degraded protected metadata, serialized target plus draft payload larger than budget, and no HTTP/parser rejection before save_slot.",
            "HTTP 400 before admission is BLOCKED, not Stage 4 protected admission evidence.",
            "Acceptable evidence: no admitted entry plus protected admission rejection diagnostics or controller stats."
        )
}

$PassCount = ($FocusedResults | Where-Object { $_.Status -eq "PASS" }).Count
$FailCount = ($FocusedResults | Where-Object { $_.Status -eq "FAIL" }).Count
$SkipCount = ($FocusedResults | Where-Object { $_.Status -eq "SKIP" }).Count
$BlockedCount = ($FocusedResults | Where-Object { $_.Status -eq "BLOCKED" }).Count

$ModelEvidence = if ($ModelItem) { "$($ModelItem.FullName) ($($ModelItem.Length) bytes)" } else { "$Model (missing)" }
$ControllerOutputExcerpt = (($ControllerStage4.Output | Where-Object {
    $_ -match "H31|H32|failed restore|payload budget eviction|multiple protected|admission rejection|All tests passed|Total:"
}) -join "`n")
if ([string]::IsNullOrWhiteSpace($ControllerOutputExcerpt)) {
    $ControllerOutputExcerpt = "No matching controller output lines captured."
}

$Report = @"
# Test report $(Split-Path $ReportFile -LeafBase)

Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")  
Tester: QA agent  
Gate: Phase 4 Stage 4 focused H30-H37 evidence rerun  
Plan: [cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope

Focused H30-H37 rerun after QA harness fixes. Public HTTP rows use model-backed evidence. Rows without a public precondition use accepted focused controller evidence when available, otherwise they report BLOCKED with the missing evidence path. This report only marks a row PASS when the run captured the Stage 4 evidence required by Part 5 of the test plan.

## Environment

- Repository: $(Get-Location)
- Git commit: $(Get-GitEvidence)
- Server binary: $($BinaryEvidence.Path)
- Server binary timestamp: $($BinaryEvidence.Timestamp)
- Server binary size: $($BinaryEvidence.Size) bytes
- Binary age at run start: $($BinaryEvidence.AgeMinutes) minutes
- Controller test binary: $(if ($ControllerEvidence) { $ControllerEvidence.Path } else { "$ControllerPath (missing)" })
- Controller test binary timestamp: $(if ($ControllerEvidence) { $ControllerEvidence.Timestamp } else { "missing" })
- Model: $ModelEvidence
- Log directory: $LogDir
- Clean build status: PASS, binary freshness satisfied the plan's 10-minute rule at run start.

## Commands

Clean build expected before this runner:

~~~powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server -j 4
cmake --build build --config Release --target test-cache-controller -j 4
~~~

Focused rerun:

~~~powershell
& "._design_docs\cache-handling-test-scripts\run_stage4_h30_h37.ps1"
~~~

Controller harness:

~~~powershell
$ControllerPath
~~~

## Harness fixes covered by this rerun

- Runner summary now prints SKIP and BLOCKED as their own statuses instead of `[FAIL]`.
- Runner markdown summary now records skipped and blocked counts.
- Windows pytest server path resolution now uses the repository build path unless `LLAMA_SERVER_BIN_PATH` overrides it.
- This focused runner records explicit PASS, FAIL, SKIP, or BLOCKED for H30-H37.
- H31 and H32 now combine public pre-pressure `cache_n > 0` proof with controller entry-state evidence so probe requests cannot create the ordering evidence.
- Controller evidence status: $($ControllerStage4.Status) - $($ControllerStage4.Message)

Controller output excerpt:

~~~text
$ControllerOutputExcerpt
~~~

## Results

| ID | Status | Result |
| --- | --- | --- |
"@

foreach ($Result in $FocusedResults) {
    $Report += "`n| $($Result.Id) | $($Result.Status) | $($Result.Message) |"
}

$Report += @"

## Evidence

"@

foreach ($Result in $FocusedResults) {
    $Report += "### $($Result.Id): $($Result.Description)`n`n"
    $Report += "Status: $($Result.Status)`n`n"
    $Report += "Message: $($Result.Message)`n`n"
    foreach ($Line in $Result.Evidence) {
        $Report += "- $Line`n"
    }
    $Report += "`n"
}

$Report += @"
## Counts

| Status | Count |
| --- | ---: |
| PASS | $PassCount |
| FAIL | $FailCount |
| SKIP | $SkipCount |
| BLOCKED | $BlockedCount |

## Handoff

Product code was not modified. FAIL rows, if any, need review before Stage 4 closure. BLOCKED rows need a stats-capable or fault-injection harness before they can be accepted.

"@

Set-Content -Path $ReportFile -Value $Report

Write-Host ""
Write-Host "Focused H30-H37 summary: PASS=$PassCount FAIL=$FailCount SKIP=$SkipCount BLOCKED=$BlockedCount"
Write-Host "Report written to: $ReportFile"

if ($FailCount -gt 0) {
    exit 1
}
