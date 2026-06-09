#requires -Version 5
# Write-LongrunEvidence.ps1
# Stage 12 long-run evidence helper.
# Writes a per-scenario evidence-summary.md for long-run checks. Adds
# resource sampler interval, threshold table, and partial-snapshot
# marker sections required by design part-02 and part-04.
#
# Usage:
#   . $PSScriptRoot\Write-LongrunEvidence.ps1
#   Write-LongrunEvidence `
#       -OutDir <path> `
#       -ScenarioId 'S12-L01' `
#       -Variant 'hybrid-6h' `
#       -DurationSeconds 21600 `
#       -SamplerIntervalSeconds 60 `
#       -WorkingsetThresholdPct 10 `
#       -HandleThresholdPct 5 `
#       -LatencyDriftThresholdPct 20 `
#       -ResourceSamplesPath <path> `
#       -PartialSnapshotPaths @('snapshot-30m.csv','snapshot-60m.csv') `
#       -StubData:$false
#
# Output:
#   <OutDir>/evidence-summary.md

param()

function Write-LongrunEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $OutDir,
        [Parameter(Mandatory = $true)] [string] $ScenarioId,
        [Parameter(Mandatory = $true)] [string] $Variant,
        [Parameter(Mandatory = $true)] [int]    $DurationSeconds,
        [Parameter(Mandatory = $true)] [int]    $SamplerIntervalSeconds,
        [Parameter(Mandatory = $true)] [string] $ModelFixture,
        [Parameter(Mandatory = $true)] [string] $BuildType,
        [Parameter(Mandatory = $true)] [string[]] $ServerFlags,
        [int]    $WorkingsetThresholdPct  = 10,
        [int]    $HandleThresholdPct      = 5,
        [int]    $LatencyDriftThresholdPct = 20,
        [string] $ResourceSamplesPath = '',
        [string[]] $PartialSnapshotPaths = @(),
        [switch] $StubData,
        [string] $Verdict = 'PENDING',
        [string] $Notes = ''
    )

    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    }

    $timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $flagsLine  = ($ServerFlags -join ' ')
    $stubMarker = if ($StubData) { 'STUB' } else { 'MEASURED' }

    $partialLines = if ($PartialSnapshotPaths.Count -gt 0) {
        ($PartialSnapshotPaths | ForEach-Object { "| snapshot | $_ |" })
    } else {
        @('| snapshot | (none captured) |')
    }

    $lines = @(
        "# Long-run evidence summary: $ScenarioId ($Variant)",
        "",
        "Date: $timestamp",
        "Stub data flag: $stubMarker",
        "",
        "## Scenario identity",
        "",
        "| Field | Value |",
        "| --- | --- |",
        "| Scenario ID | $ScenarioId |",
        "| Variant | $Variant |",
        "| Model fixture | $ModelFixture |",
        "| Build type | $BuildType |",
        "| Server flags | ``$flagsLine`` |",
        "| Duration seconds | $DurationSeconds |",
        "| Sampler interval seconds | $SamplerIntervalSeconds |",
        "",
        "## Resource stability thresholds",
        "",
        "| Threshold | Value |",
        "| --- | --- |",
        "| Working set growth after warmup | $WorkingsetThresholdPct % |",
        "| Handle or FD growth after warmup | $HandleThresholdPct % |",
        "| Latency drift p95 | $LatencyDriftThresholdPct % |",
        "",
        "## Sampler and monitor list",
        "",
        "| Monitor | Source |",
        "| --- | --- |",
        "| Process working set | harness-only |",
        "| Windows handle count | harness-only |",
        "| Server liveness ping | public HTTP |",
        "| /metrics sample | public Prometheus |",
        "| Cold-store file count | harness-only |",
        "",
        "## Evidence artifacts",
        "",
        "| Artifact | Path |",
        "| --- | --- |",
        "| resource-samples.csv | $ResourceSamplesPath |",
        ""
    ) + $partialLines + @(
        "",
        "## Evidence source classification",
        "",
        "| Group | Source class |",
        "| --- | --- |",
        "| Cache outcomes | public Prometheus |",
        "| Resource stability | harness-only |",
        "| Latency drift | direct stats and harness |",
        "| Server liveness | public HTTP |",
        "",
        "## Verdict",
        "",
        "Result: $Verdict",
        "",
        "Notes: $Notes"
    )

    $outPath = Join-Path $OutDir 'evidence-summary.md'
    $content = ($lines -join "`r`n") + "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outPath, $content, $utf8NoBom)
    return $outPath
}

