Set-StrictMode -Version Latest

function Get-Stage34CachedTokens {
    param([AllowNull()][object] $Response)
    if ($null -eq $Response) { return 0 }
    $usage = $Response.PSObject.Properties["usage"]
    if ($null -ne $usage) {
        $details = $usage.Value.PSObject.Properties["prompt_tokens_details"]
        if ($null -ne $details) {
            $cached = $details.Value.PSObject.Properties["cached_tokens"]
            if ($null -ne $cached) { return [int]$cached.Value }
        }
    }
    $timings = $Response.PSObject.Properties["timings"]
    if ($null -ne $timings) {
        $cacheN = $timings.Value.PSObject.Properties["cache_n"]
        if ($null -ne $cacheN) { return [int]$cacheN.Value }
    }
    return 0
}

function Read-Stage34JsonLines {
    param([Parameter(Mandatory=$true)] [string] $Path)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($line in [System.IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $rows.Add(($line | ConvertFrom-Json -Depth 64))
    }
    return $rows.ToArray()
}

function Join-Stage34ReplayResults {
    param(
        [Parameter(Mandatory=$true)] [string] $ExpectedHitsPath,
        [Parameter(Mandatory=$true)] [string] $ResponsesPath
    )
    $expectedRows = Read-Stage34JsonLines -Path $ExpectedHitsPath
    $responseRows = Read-Stage34JsonLines -Path $ResponsesPath
    $responses = @{}
    foreach ($row in $responseRows) { $responses[$row.request_id] = $row }

    foreach ($expected in $expectedRows) {
        $cached = 0
        $httpStatus = $null
        $errorText = ""
        $hasResponse = $false
        if ($responses.ContainsKey($expected.replay_request_id)) {
            $responseRow = $responses[$expected.replay_request_id]
            $httpStatus = $responseRow.http_status
            $errorText = [string]$responseRow.error
            $response = $responseRow.response
            if ($null -ne $response) {
                $hasResponse = $true
                $cached = Get-Stage34CachedTokens -Response $response
            }
        }
        $verdict = "PASS"
        if ($expected.expected_result -eq "hit") {
            if ($null -eq $httpStatus -or [int]$httpStatus -ne 200) {
                $verdict = "FAIL-http"
            } elseif (-not $hasResponse) {
                $verdict = "FAIL-null-response"
            } elseif ($cached -le 0) {
                $verdict = "FAIL-cache-miss"
            }
        }
        [pscustomobject]@{
            replay_request_id = $expected.replay_request_id
            expected_result = $expected.expected_result
            bounded_miss_reason = $expected.bounded_miss_reason
            http_status = $httpStatus
            response_present = $hasResponse
            error = $errorText
            cache_n = $cached
            verdict = $verdict
        }
    }
}
