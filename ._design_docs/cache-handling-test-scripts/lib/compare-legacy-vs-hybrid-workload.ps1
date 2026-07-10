#requires -Version 5
# compare-legacy-vs-hybrid-workload.ps1
#
# Stage 29 workload builder. Wraps lib/agentic-prompt-generator.ps1 (Stage 20)
# to emit a per-request JSONL with a cache_class distribution matching the
# Stage 29 design (exact / near_prefix / new_branch) and the part-04 metric
# fields. This is the Stage 29 design-correction option (a) for review
# finding B-01 (see part-12-design-review-20260628.md).
#
# Status: design correction (Architect session, 2026-06-28).
# Owner: Architect (Stage 29 correction). Stage 20 lib is unchanged.
#
# Public entry point: New-ComparisonWorkload
# Output schema: stage29-comparison-workload-v1
# Stage 36 adds an opt-in burst duplicate mode. Default Stage 29 behavior is
# unchanged unless -BurstDuplicateMode is passed.
#
# Usage:
#   . .\lib\agentic-prompt-generator.ps1
#   . .\lib\compare-legacy-vs-hybrid-workload.ps1
#   New-ComparisonWorkload -RequestCount 200 `
#       -Distribution @{ exact = 0.4; near_prefix = 0.3; new_branch = 0.3 } `
#       -Seed 42 -MaxTokens 8 `
#       -ServerUrl http://127.0.0.1:8900 `
#       -OutPath .\_test_output\stage29\workload.jsonl

param()

$ErrorActionPreference = 'Stop'

$script:DefaultDistribution = @{
    exact       = 0.4
    near_prefix = 0.3
    new_branch  = 0.3
}

# Map Stage 29 cache_class to Stage 20 lib PromptClass.
# exact       -> exact-repeat (identical messages)
# near_prefix -> near-duplicate (suffix differs)
# new_branch  -> different-agent-same-prefix (no shared prefix)
$script:PromptClassMap = @{
    exact       = 'exact-repeat'
    near_prefix = 'near-duplicate'
    new_branch  = 'different-agent-same-prefix'
}

# Supported SizeClass values. Each entry maps the design label to the
# (target_tokens, lib-size-class) pair passed to New-AgenticChatPrompt.
$script:SizeClassMap = @{
    '2k'  = @{ Target = 2000;  SizeClass = '2k'  }
    '12k' = @{ Target = 12000; SizeClass = '12k' }
    '24k' = @{ Target = 24000; SizeClass = '24k' }
    '60k' = @{ Target = 60000; SizeClass = '60k' }
}

function New-ComparisonWorkload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [int]    $RequestCount,
        [Parameter(Mandatory = $true)] [string] $ServerUrl,
        [Parameter(Mandatory = $true)] [string] $OutPath,
        [hashtable] $Distribution,
        [int]    $Seed               = 42,
        [int]    $MaxTokens          = 8,
        [int]    $Temperature        = 0,
        [int]    $MinAnchors         = 10,
        [string] $SizeClass          = '2k',
        [int]    $TokenizeTimeoutSec = 60,
        [int]    $MaxIterations      = 200,
        [switch] $BurstDuplicateMode,
        [int]    $BurstCount         = 8,
        [int]    $RepeatsPerBurst    = 6,
        [int]    $FillerCount        = 0
    )

    if ($RequestCount -le 0) {
        throw "New-ComparisonWorkload: RequestCount must be positive (got $RequestCount)"
    }
    if ($MaxTokens -le 0) {
        throw "New-ComparisonWorkload: MaxTokens must be positive (got $MaxTokens)"
    }
    if (-not $Distribution) {
        $Distribution = $script:DefaultDistribution
    }
    $sumDist = ($Distribution.Values | Measure-Object -Sum).Sum
    if ([Math]::Abs($sumDist - 1.0) -gt 0.001) {
        throw "New-ComparisonWorkload: Distribution values must sum to 1.0 (got $sumDist)"
    }
    foreach ($k in 'exact','near_prefix','new_branch') {
        if (-not $Distribution.ContainsKey($k)) {
            throw "New-ComparisonWorkload: Distribution must contain key '$k'"
        }
    }
    if (-not $script:SizeClassMap.ContainsKey($SizeClass)) {
        throw "New-ComparisonWorkload: unknown SizeClass '$SizeClass'"
    }
    if ($BurstDuplicateMode) {
        if ($BurstCount -le 0) {
            throw "New-ComparisonWorkload: BurstCount must be positive (got $BurstCount)"
        }
        if ($RepeatsPerBurst -le 1) {
            throw "New-ComparisonWorkload: RepeatsPerBurst must be greater than 1 (got $RepeatsPerBurst)"
        }
        if ($FillerCount -lt 0) {
            throw "New-ComparisonWorkload: FillerCount must be non-negative (got $FillerCount)"
        }
        if ($FillerCount -gt 48) {
            throw "New-ComparisonWorkload: FillerCount must be <= 48 for burst mode (got $FillerCount)"
        }
    }

    if (-not (Test-Path (Split-Path -Parent $OutPath))) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
    }
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("stage29-anchors-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

    $rng = New-Object System.Random($Seed)
    $target = $script:SizeClassMap[$SizeClass].Target
    $sizeClassName = $script:SizeClassMap[$SizeClass].SizeClass
    $requestLines = New-Object System.Collections.Generic.List[string]

    if ($BurstDuplicateMode) {
        $reqIdx = 0
        for ($burstIdx = 0; $burstIdx -lt $BurstCount; $burstIdx++) {
            $anchorPath = Join-Path $tempDir ("burst-anchor-{0:D4}.json" -f $burstIdx)
            New-AgenticChatPrompt `
                -TargetTokens $target `
                -SizeClass $sizeClassName `
                -PromptClass 'different-agent-same-prefix' `
                -OutPath $anchorPath `
                -ServerUrl $ServerUrl `
                -Seed ($Seed + $burstIdx) `
                -TimeoutSec $TokenizeTimeoutSec `
                -MaxIterations $MaxIterations | Out-Null
            $anchorJson = Get-Content -Raw -Path $anchorPath | ConvertFrom-Json
            for ($repeatIdx = 0; $repeatIdx -lt $RepeatsPerBurst; $repeatIdx++) {
                $reqIdx++
                $line = [pscustomobject]@{
                    request_id   = "r-{0:D4}" -f $reqIdx
                    cache_class  = 'exact'
                    burst_id     = "b-{0:D4}" -f ($burstIdx + 1)
                    burst_repeat = $repeatIdx + 1
                    messages     = @($anchorJson.messages)
                    max_tokens   = $MaxTokens
                    temperature  = $Temperature
                    seed         = $Seed
                }
                [void]$requestLines.Add(($line | ConvertTo-Json -Depth 10 -Compress))
            }
        }
        for ($fillerIdx = 0; $fillerIdx -lt $FillerCount; $fillerIdx++) {
            $freshPath = Join-Path $tempDir ("burst-filler-{0:D4}.json" -f $fillerIdx)
            New-AgenticChatPrompt `
                -TargetTokens $target `
                -SizeClass $sizeClassName `
                -PromptClass 'different-agent-same-prefix' `
                -OutPath $freshPath `
                -ServerUrl $ServerUrl `
                -Seed ($Seed + $fillerIdx + 10000) `
                -TimeoutSec $TokenizeTimeoutSec `
                -MaxIterations $MaxIterations | Out-Null
            $freshJson = Get-Content -Raw -Path $freshPath | ConvertFrom-Json
            $reqIdx++
            $line = [pscustomobject]@{
                request_id  = "r-{0:D4}" -f $reqIdx
                cache_class = 'new_branch'
                burst_id    = $null
                messages    = @($freshJson.messages)
                max_tokens  = $MaxTokens
                temperature = $Temperature
                seed        = $Seed
            }
            [void]$requestLines.Add(($line | ConvertTo-Json -Depth 10 -Compress))
        }

        Write-ComparisonWorkloadLines -OutPath $OutPath -RequestLines $requestLines
        Remove-Item -Recurse -Force -Path $tempDir -ErrorAction SilentlyContinue

        return [pscustomobject]@{
            OutPath          = $OutPath
            RequestCount     = $requestLines.Count
            Distribution     = @{ exact = 1.0; near_prefix = 0.0; new_branch = 0.0 }
            Seed             = $Seed
            BurstDuplicateMode = $true
            BurstCount       = $BurstCount
            RepeatsPerBurst  = $RepeatsPerBurst
            FillerCount      = $FillerCount
        }
    }

    # Pass 1: build the anchor pool. Exact/near_prefix requests reuse anchor
    # messages, so the pool must be large enough to cover those classes.
    $anchorCount = [Math]::Max($MinAnchors, [int]([Math]::Ceiling($RequestCount * $Distribution['exact'])))
    $anchors = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $anchorCount; $i++) {
        $anchorPath = Join-Path $tempDir ("anchor-{0:D4}.json" -f $i)
        New-AgenticChatPrompt `
            -TargetTokens $target `
            -SizeClass $sizeClassName `
            -PromptClass 'different-agent-same-prefix' `
            -OutPath $anchorPath `
            -ServerUrl $ServerUrl `
            -Seed ($Seed + $i) `
            -TimeoutSec $TokenizeTimeoutSec `
            -MaxIterations $MaxIterations | Out-Null
        $anchorJson = Get-Content -Raw -Path $anchorPath | ConvertFrom-Json
        [void]$anchors.Add($anchorJson)
    }

    # Pass 2: build per-request entries using the distribution.
    $exactCutoff       = $Distribution['exact']
    $nearPrefixCutoff  = $exactCutoff + $Distribution['near_prefix']

    for ($reqIdx = 0; $reqIdx -lt $RequestCount; $reqIdx++) {
        $roll = $rng.NextDouble()
        if     ($roll -lt $exactCutoff)      { $cacheClass = 'exact' }
        elseif ($roll -lt $nearPrefixCutoff) { $cacheClass = 'near_prefix' }
        else                                 { $cacheClass = 'new_branch' }

        $requestId = "r-{0:D4}" -f ($reqIdx + 1)
        $messages  = $null

        if ($cacheClass -eq 'exact' -and $anchors.Count -gt 0) {
            $source = $anchors[$rng.Next(0, $anchors.Count)]
            $messages = @($source.messages)
        }
        elseif ($cacheClass -eq 'near_prefix' -and $anchors.Count -gt 0) {
            $source = $anchors[$rng.Next(0, $anchors.Count)]
            $messages = Get-ModifiedMessagesForNearPrefix -SourceMessages $source.messages -Rng $rng
        }
        else {
            $freshPath = Join-Path $tempDir ("fresh-{0:D4}.json" -f $reqIdx)
            New-AgenticChatPrompt `
                -TargetTokens $target `
                -SizeClass $sizeClassName `
                -PromptClass $script:PromptClassMap[$cacheClass] `
                -OutPath $freshPath `
                -ServerUrl $ServerUrl `
                -Seed ($Seed + $reqIdx + 10000) `
                -TimeoutSec $TokenizeTimeoutSec `
                -MaxIterations $MaxIterations | Out-Null
            $freshJson = Get-Content -Raw -Path $freshPath | ConvertFrom-Json
            $messages = @($freshJson.messages)
        }

        $line = [pscustomobject]@{
            request_id  = $requestId
            cache_class = $cacheClass
            messages    = $messages
            max_tokens  = $MaxTokens
            temperature = $Temperature
            seed        = $Seed
        }
        [void]$requestLines.Add(($line | ConvertTo-Json -Depth 10 -Compress))
    }

    Write-ComparisonWorkloadLines -OutPath $OutPath -RequestLines $requestLines

    Remove-Item -Recurse -Force -Path $tempDir -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        OutPath      = $OutPath
        RequestCount = $RequestCount
        Distribution = $Distribution
        Seed         = $Seed
    }
}

function Write-ComparisonWorkloadLines {
    param(
        [Parameter(Mandatory = $true)] [string] $OutPath,
        [Parameter(Mandatory = $true)] $RequestLines
    )
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($OutPath, $RequestLines, $utf8)
    $content = [System.IO.File]::ReadAllText($OutPath) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($OutPath, $content, $utf8)
}

function Get-ModifiedMessagesForNearPrefix {
    param(
        [Parameter(Mandatory = $true)] $SourceMessages,
        [Parameter(Mandatory = $true)] $Rng
    )
    $copy = @()
    $msgList = @($SourceMessages)
    for ($i = 0; $i -lt $msgList.Count; $i++) {
        $m = $msgList[$i]
        if ($i -eq ($msgList.Count - 1) -and $m.role -eq 'user') {
            $copy += [pscustomobject]@{
                role    = 'user'
                content = $m.content + "`nsuffix-token-" + $Rng.Next(10000,99999)
            }
        } else {
            $copy += $m
        }
    }
    return ,$copy
}
