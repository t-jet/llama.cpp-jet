#requires -Version 5
# Read-Stage29MetricSnapshot.ps1
#
# Stage 29 lib helper: read /metrics endpoint from a llama-server
# instance and return a parsed snapshot hashtable. Writes the raw
# metrics text to OutPath for before/after diff comparison.
#
# Public entry point: Read-Stage29MetricSnapshot
# Output schema: stage29-metric-snapshot-v1
#
# Usage:
#   . .\lib\Read-Stage29MetricSnapshot.ps1
#   $snap = Read-Stage29MetricSnapshot -ServerUrl 'http://127.0.0.1:8900' `
#       -OutPath 'C:\runs\stage29\phase-2-cycle-1\legacy\metrics-before.txt'
#
# Per design part-04, only the post-Stage-26 colon-prefix namespace
# (llamacpp:cache_X) is accepted. Underscore-form lines in the raw text
# surface as FAIL-metric-format-regression at the report layer (the
# driver runs the grep; this helper just preserves the raw text).

param()

$ErrorActionPreference = 'Stop'

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Stage29MetricSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $ServerUrl,
        [Parameter(Mandatory = $true)] [string] $OutPath,
        [int]    $TimeoutSec = 30
    )

    if (-not $ServerUrl.EndsWith('/metrics')) {
        $metricsUrl = "$ServerUrl/metrics"
    } else {
        $metricsUrl = $ServerUrl
    }

    $dir = Split-Path -Parent $OutPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $response = $null
    try {
        $response = Invoke-WebRequest -Uri $metricsUrl -TimeoutSec $TimeoutSec `
            -UseBasicParsing -ErrorAction Stop
    } catch {
        throw "Read-Stage29MetricSnapshot: GET $metricsUrl failed: $($_.Exception.Message)"
    }

    if ($response.StatusCode -ne 200) {
        throw "Read-Stage29MetricSnapshot: GET $metricsUrl returned status $($response.StatusCode)"
    }

    $rawText = $response.Content -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($OutPath, $rawText, $script:Utf8NoBom)

    $snapshot = @{}
    $lines = $rawText -split "`n"
    foreach ($line in $lines) {
        if (-not $line -or $line.StartsWith('#')) { continue }
        $match = [regex]::Match($line, '^([a-zA-Z_:][a-zA-Z0-9_:]*)(\{[^}]*\})?\s+([0-9eE+\-.]+)\s*$')
        if ($match.Success) {
            $name = $match.Groups[1].Value
            $value = [double]$match.Groups[3].Value
            if (-not $snapshot.ContainsKey($name)) {
                $snapshot[$name] = $value
            }
        }
    }

    return [pscustomobject]@{
        OutPath      = $OutPath
        ServerUrl    = $metricsUrl
        MetricCount  = $snapshot.Count
        Snapshot     = $snapshot
    }
}
