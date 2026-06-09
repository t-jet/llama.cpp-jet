#requires -Version 5
# Write-TuningReport.ps1
# Stage 12 tuning report skeleton writer.
# Writes the seven-section tuning-report.md skeleton from design part-03.
# QA fills the value rows with run results; this helper emits the
# section titles, placeholder text, and the source-row mapping table.
#
# Usage:
#   . $PSScriptRoot\Write-TuningReport.ps1
#   Write-TuningReport `
#       -OutDir <path> `
#       -RunId 'benchmark-run-20260607-01' `
#       -SourceRows @('S12-B01','S12-B02','S12-B03','S12-B04')
#
# Output:
#   <OutDir>/tuning-report.md

param()

function Write-TuningReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $OutDir,
        [Parameter(Mandatory = $true)] [string] $RunId,
        [string[]] $SourceRows = @(),
        [switch] $StubData
    )

    if (-not (Test-Path $OutDir)) {
        New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    }

    $timestamp  = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $stubMarker = if ($StubData) { 'STUB' } else { 'PENDING' }
    $sourceLine = if ($SourceRows.Count -gt 0) { ($SourceRows -join ', ') } else { '(none)' }

    $lines = @(
        "# Tuning report: $RunId",
        "",
        "Date: $timestamp",
        "Stub flag: $stubMarker",
        "Source rows: $sourceLine",
        "",
        "## 1. Hot budget guidance",
        "",
        "Smallest budget that avoids constant eviction per workload: TBD",
        "Protected-root pressure effect: TBD",
        "",
        "## 2. Cold store guidance",
        "",
        "When cold storage helps: TBD",
        "Latency cost observed: TBD",
        "Disk behavior: TBD",
        "",
        "## 3. Slot count guidance",
        "",
        "Throughput by slot count: TBD",
        "p95 latency by slot count: TBD",
        "Contention point: TBD",
        "",
        "## 4. Context length guidance",
        "",
        "Longer-context reuse benefit: TBD",
        "Restore or serialization cost: TBD",
        "",
        "## 5. Draft and MTP guidance",
        "",
        "Supported draft modes: TBD",
        "Namespace reuse effect: TBD",
        "Stage 12 scope: out of required scope (cap-fix closure PASS 2026-06-07; Manager plan keeps draft and MTP rows out of scope)",
        "",
        "## 6. Workload profile guidance",
        "",
        "Plain-transformer result: TBD",
        "Checkpoint-dependent result: TBD",
        "Target-plus-draft result: TBD",
        "",
        "## 7. Bottlenecks",
        "",
        "CPU: TBD",
        "Memory: TBD",
        "Disk: TBD",
        "Cold I/O: TBD",
        "Branch lookup: TBD",
        "Queue pressure: TBD",
        "Metric export: TBD"
    )

    $outPath = Join-Path $OutDir 'tuning-report.md'
    $content = ($lines -join "`r`n") + "`r`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($outPath, $content, $utf8NoBom)
    return $outPath
}

