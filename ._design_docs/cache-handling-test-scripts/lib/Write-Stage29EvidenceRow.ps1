#requires -Version 5
# Write-Stage29EvidenceRow.ps1
#
# Stage 29 lib helper: write per-cycle evidence row to summary.json
# at the run root. Maintains a list of rows, one entry per leg, with
# the per-leg counters, gauges, filesystem, and process samples from
# design part-04. Also computes counter deltas between a Before and
# After snapshot hashtable.
#
# Public entry points:
#   Write-Stage29EvidenceRow - append or replace a row in summary.json
#   Get-Stage29CounterDelta  - compute a single counter delta
#
# Output schema: stage29-summary-v1
#
# Usage:
#   . .\lib\Write-Stage29EvidenceRow.ps1
#   $delta = Get-Stage29CounterDelta -Before $before.Snapshot -After $after.Snapshot `
#       -CounterName 'llamacpp:cache_hits_total'
#   Write-Stage29EvidenceRow -SummaryPath 'C:\runs\stage29\summary.json' `
#       -Row @{ run_id='r1'; mode='legacy'; cycle=1; counter_deltas=@{...} }

param()

$ErrorActionPreference = 'Stop'

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$script:SummaryVersion = 'stage29-summary-v1'

function Get-Stage29CounterDelta {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [hashtable] $Before,
        [Parameter(Mandatory = $true)] [hashtable] $After,
        [Parameter(Mandatory = $true)] [string]    $CounterName
    )

    $beforeVal = 0.0
    $afterVal  = 0.0
    if ($Before.ContainsKey($CounterName)) { $beforeVal = [double]$Before[$CounterName] }
    if ($After.ContainsKey($CounterName))  { $afterVal  = [double]$After[$CounterName]  }

    return [pscustomobject]@{
        counter = $CounterName
        before  = $beforeVal
        after   = $afterVal
        delta   = $afterVal - $beforeVal
    }
}

function Read-Stage29Summary {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)] [string] $SummaryPath)

    if (-not (Test-Path $SummaryPath)) {
        return [pscustomobject]@{
            version = $script:SummaryVersion
            rows    = @()
        }
    }

    $raw = [System.IO.File]::ReadAllText($SummaryPath)
    $obj = $raw | ConvertFrom-Json
    if ($null -eq $obj.rows) { $obj.rows = @() }
    return $obj
}

function Write-Stage29EvidenceRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string]   $SummaryPath,
        [Parameter(Mandatory = $true)] [hashtable] $Row,
        [switch] $Replace
    )

    $summary = Read-Stage29Summary -SummaryPath $SummaryPath
    $rows = @($summary.rows)

    $rowObj = [pscustomobject]$Row

    if ($Replace) {
        $rows = @()
    }

    $rows += $rowObj

    $out = [pscustomobject]@{
        version = $script:SummaryVersion
        rows    = $rows
    }

    $dir = Split-Path -Parent $SummaryPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $json = ConvertTo-Json -InputObject $out -Depth 12
    [System.IO.File]::WriteAllText($SummaryPath, $json, $script:Utf8NoBom)

    return $out
}
