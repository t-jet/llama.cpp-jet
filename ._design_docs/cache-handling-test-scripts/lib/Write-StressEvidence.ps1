#requires -Version 5
# Write-StressEvidence.ps1
# Stage 12 stress evidence helper.
# Writes a per-scenario evidence-summary.md for stress runs in the
# directory layout defined by cache-handling-phase12-design/part-02 and
# part-04. This helper is a pure file writer. It does not start a
# server, generate load, or assert verdicts. QA execution invokes the
# stress driver, which calls this helper to record the per-scenario
# summary.
#
# Usage:
#   . $PSScriptRoot\Write-StressEvidence.ps1
#   Write-StressEvidence `
#       -OutDir <path> `
#       -ScenarioId 'S12-S01' `
#       -Variant 'cold-on' `
#       -ModelFixture <name> `
#       -BuildType 'Release' `
#       -ServerFlags @('--cache-mode','hybrid','--cache-ram','2') `
#       -RequestCount 1234 `
#       -Seed 42 `
#       -DurationSeconds 1800 `
#       -MetricsBeforePath <path> `
#       -MetricsDuringPath <path> `
#       -MetricsAfterPath <path> `
#       -ResourceSamplesPath <path> `
#       -PreconditionLogPath <null or path> `
#       -StubData:$false
#
# Output:
#   <OutDir>/evidence-summary.md   (per-scenario summary, ASCII only)
#
# Evidence source classification: each measurement is recorded with one
# of "public Prometheus", "structured log", "direct stats", or
# "harness-only" so QA can trace row-by-row attribution.

param()

function Write-StressEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $OutDir,
        [Parameter(Mandatory = $true)] [string] $ScenarioId,
        [Parameter(Mandatory = $true)] [string] $Variant,
        [Parameter(Mandatory = $true)] [string] $ModelFixture,
        [Parameter(Mandatory = $true)] [string] $BuildType,
        [Parameter(Mandatory = $true)] [string[]] $ServerFlags,
        [int]    $RequestCount = 0,
        [int]    $Seed = 42,
        [int]    $DurationSeconds = 1800,
        [string] $MetricsBeforePath = '',
        [string] $MetricsDuringPath = '',
        [string] $MetricsAfterPath = '',
        [string] $ResourceSamplesPath = '',
        [string] $PreconditionLogPath = '',
        [switch] $StubData,
        [string] $Verdict = 'PENDING',
        [string] $Notes = ''
    )

    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    }

    $timestamp    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $flagsLine    = ($ServerFlags -join ' ')
    $stubMarker   = if ($StubData) { 'STUB' } else { 'MEASURED' }
    $precondLine  = if ($PreconditionLogPath -and (Test-Path $PreconditionLogPath)) { $PreconditionLogPath } else { '(none)' }

    $lines = @(
        "# Stress evidence summary: $ScenarioId ($Variant)",
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
        "| Request count | $RequestCount |",
        "| Prompt generator seed | $Seed |",
        "| Duration seconds | $DurationSeconds |",
        "",
        "## Evidence artifacts",
        "",
        "| Artifact | Path |",
        "| --- | --- |",
        "| metrics-before | $MetricsBeforePath |",
        "| metrics-during | $MetricsDuringPath |",
        "| metrics-after  | $MetricsAfterPath |",
        "| resource-samples | $ResourceSamplesPath |",
        "| precondition.log | $precondLine |",
        "",
        "## Evidence source classification",
        "",
        "| Group | Source class |",
        "| --- | --- |",
        "| Cache outcomes | public Prometheus |",
        "| Payload residency | public Prometheus |",
        "| Eviction and protection | public Prometheus |",
        "| Branch graph | public Prometheus where exposed, structured log otherwise |",
        "| Checkpoint behavior | public Prometheus where exposed, structured log otherwise |",
        "| Security and leakage | structured log |",
        "| Resource stability | harness-only |",
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

