#requires -Version 5
# Test-Stage29OutputEquivalence.ps1
#
# Stage 29 lib helper: byte-compare legacy and hybrid decoded text
# for the 5 seed-42 prompts from Phase 1 (per design part-03 lines
# 64-72 and part-05 Layer 1 sub-check 1.2).
#
# Public entry point: Test-Stage29OutputEquivalence
# Output schema: stage29-output-equivalence-v1
#
# Usage:
#   . .\lib\Test-Stage29OutputEquivalence.ps1
#   $result = Test-Stage29OutputEquivalence `
#       -LegacyDecodedPath 'C:\runs\stage29\phase-1-output-equivalence\legacy-decoded.txt' `
#       -HybridDecodedPath 'C:\runs\stage29\phase-1-output-equivalence\hybrid-decoded.txt' `
#       -DiffOutPath        'C:\runs\stage29\phase-1-output-equivalence\diff.txt'
#   if ($result.Status -ne 'PASS') { throw 'BLOCKED-output-equivalence' }
#
# Per design part-05 sub-check 1.2: PASS requires byte-identical decoded
# text per prompt. Any difference classifies as BLOCKED-output-equivalence
# and the main workload does NOT start.

param()

$ErrorActionPreference = 'Stop'

$script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Test-Stage29OutputEquivalence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $LegacyDecodedPath,
        [Parameter(Mandatory = $true)] [string] $HybridDecodedPath,
        [Parameter(Mandatory = $true)] [string] $DiffOutPath
    )

    if (-not (Test-Path $LegacyDecodedPath)) {
        throw "Test-Stage29OutputEquivalence: legacy decoded file not found: $LegacyDecodedPath"
    }
    if (-not (Test-Path $HybridDecodedPath)) {
        throw "Test-Stage29OutputEquivalence: hybrid decoded file not found: $HybridDecodedPath"
    }

    $dir = Split-Path -Parent $DiffOutPath
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    $legacyBytes = [System.IO.File]::ReadAllBytes($LegacyDecodedPath)
    $hybridBytes = [System.IO.File]::ReadAllBytes($HybridDecodedPath)

    $legacyText = [System.Text.Encoding]::UTF8.GetString($legacyBytes).TrimEnd("`r", "`n")
    $hybridText = [System.Text.Encoding]::UTF8.GetString($hybridBytes).TrimEnd("`r", "`n")

    $legacyLines = $legacyText -split "`n"
    $hybridLines = $hybridText -split "`n"

    $diffLines = New-Object System.Collections.Generic.List[string]
    $mismatchCount = 0

    $maxLines = [Math]::Max($legacyLines.Count, $hybridLines.Count)
    for ($i = 0; $i -lt $maxLines; $i++) {
        $l = if ($i -lt $legacyLines.Count) { $legacyLines[$i] } else { '<missing>' }
        $h = if ($i -lt $hybridLines.Count) { $hybridLines[$i] } else { '<missing>' }
        if ($l -ne $h) {
            $mismatchCount++
            [void]$diffLines.Add("line $($i + 1): legacy=[$l] hybrid=[$h]")
        }
    }

    $status = if ($mismatchCount -eq 0 -and $legacyLines.Count -eq $hybridLines.Count) {
        'PASS'
    } else {
        'BLOCKED-output-equivalence'
    }

    $diffText = ($diffLines -join "`n")
    [System.IO.File]::WriteAllText($DiffOutPath, $diffText, $script:Utf8NoBom)

    return [pscustomobject]@{
        Status           = $status
        LegacyLineCount  = $legacyLines.Count
        HybridLineCount  = $hybridLines.Count
        MismatchCount    = $mismatchCount
        DiffOutPath      = $DiffOutPath
        DiffByteSize     = $diffText.Length
    }
}
