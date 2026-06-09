#requires -Version 5
# Write-BenchEvidence.ps1
# Stage 12 benchmark evidence helper.
# Writes a per-scenario evidence-summary.md for benchmark runs. Mirrors
# Write-StressEvidence.ps1 in shape but adds baseline.json and
# legacy-baseline.json links, and a tuning-report row pointer.
#
# Usage:
#   . $PSScriptRoot\Write-BenchEvidence.ps1
#   Write-BenchEvidence `
#       -OutDir <path> `
#       -ScenarioId 'S12-B01' `
#       -Variant 'hybrid-parallel-1' `
#       -ModelFixture <name> `
#       -BuildType 'Release' `
#       -ServerFlags @('--cache-mode','hybrid') `
#       -BaselinePath <path> `
#       -LegacyBaselinePath <null or path> `
#       -K6ResultsPath <null or path> `
#       -LoadToolOutputPath <null or path> `
#       -MetricsBeforePath <path> `
#       -MetricsDuringPath <path> `
#       -MetricsAfterPath <path> `
#       -TuningRow 1 `
#       -StubData:$false
#
# Output:
#   <OutDir>/evidence-summary.md

param()

function Write-BenchEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $OutDir,
        [Parameter(Mandatory = $true)] [string] $ScenarioId,
        [Parameter(Mandatory = $true)] [string] $Variant,
        [Parameter(Mandatory = $true)] [string] $ModelFixture,
        [Parameter(Mandatory = $true)] [string] $BuildType,
        [Parameter(Mandatory = $true)] [string[]] $ServerFlags,
        [string] $BaselinePath = '',
        [string] $LegacyBaselinePath = '',
        [string] $K6ResultsPath = '',
        [string] $LoadToolOutputPath = '',
        [string] $MetricsBeforePath = '',
        [string] $MetricsDuringPath = '',
        [string] $MetricsAfterPath = '',
        [int]    $TuningRow = 0,
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
    $legacyLine   = if ($LegacyBaselinePath -and (Test-Path $LegacyBaselinePath)) { $LegacyBaselinePath } else { 'N/A' }
    $k6Line       = if ($K6ResultsPath -and (Test-Path $K6ResultsPath)) { $K6ResultsPath } else { '(none)' }
    $loadLine     = if ($LoadToolOutputPath -and (Test-Path $LoadToolOutputPath)) { $LoadToolOutputPath } else { '(none)' }
    $tuningLine   = if ($TuningRow -gt 0) { "row $TuningRow" } else { 'n/a' }

    $lines = @(
        "# Benchmark evidence summary: $ScenarioId ($Variant)",
        "",
        "Date: $timestamp",
        "Stub data flag: $stubMarker",
        "Tuning report link: $tuningLine",
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
        "",
        "## Evidence artifacts",
        "",
        "| Artifact | Path |",
        "| --- | --- |",
        "| baseline.json | $BaselinePath |",
        "| legacy-baseline.json | $legacyLine |",
        "| k6-results.json | $k6Line |",
        "| load-tool-output.txt | $loadLine |",
        "| metrics-before | $MetricsBeforePath |",
        "| metrics-during | $MetricsDuringPath |",
        "| metrics-after  | $MetricsAfterPath |",
        "",
        "## Evidence source classification",
        "",
        "| Group | Source class |",
        "| --- | --- |",
        "| Cache outcomes | public Prometheus |",
        "| Payload residency | public Prometheus |",
        "| Eviction and protection | public Prometheus |",
        "| Branch graph | public Prometheus where exposed |",
        "| Checkpoint behavior | public Prometheus where exposed |",
        "| Security and leakage | structured log |",
        "| Resource stability | harness-only |",
        "| Load tool latency | load-tool output |",
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

