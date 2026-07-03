param(
    [Parameter(Mandatory=$false)] [string] $TranscriptPath,
    [string] $OutputDir,
    [string] $Model = "stage34-replay",
    [ValidateSet("dry-run", "sequential", "concurrent")] [string] $Mode = "dry-run",
    [string] $ServerUrl,
    [int] $MaxTokens = 1,
    [int] $TimeoutSec = 120,
    [int] $ThrottleLimit = 4,
    [int] $HotBudgetMiB = 2048,
    [int] $ColdBudgetMiB = 8192,
    [double] $EstimatedPayloadMiBPerToken = 0.0,
    [switch] $IncludeRawPrompts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\lib\stage34-replay-parser.ps1"
. "$PSScriptRoot\lib\stage34-request-renderer.ps1"
. "$PSScriptRoot\lib\stage34-result-analyzer.ps1"

function Invoke-Stage34MetricsCapture {
    param(
        [Parameter(Mandatory=$true)] [string] $ServerUrl,
        [Parameter(Mandatory=$true)] [string] $Path,
        [int] $TimeoutSec = 30
    )
    try {
        Invoke-WebRequest -Uri "$ServerUrl/metrics" -UseBasicParsing -TimeoutSec $TimeoutSec -OutFile $Path
        return $true
    } catch {
        Set-Content -LiteralPath $Path -Encoding utf8NoBOM -Value ("METRICS-CAPTURE-FAILED: " + $_.Exception.Message)
        return $false
    }
}

function Invoke-Stage34RequestFile {
    param(
        [Parameter(Mandatory=$true)] [string] $ServerUrl,
        [Parameter(Mandatory=$true)] [object] $RequestRow,
        [int] $TimeoutSec = 120
    )
    $started = Get-Date
    try {
        $body = Get-Content -Raw -LiteralPath $RequestRow.request_body_path
        $response = Invoke-RestMethod -Uri "$ServerUrl/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec
        $elapsed = [int]((Get-Date) - $started).TotalMilliseconds
        return [pscustomobject]@{
            request_id = $RequestRow.request_id
            transcript_row = $RequestRow.transcript_row
            replay_order = $RequestRow.replay_order
            http_status = 200
            elapsed_ms = $elapsed
            error = ""
            response = $response
        }
    } catch {
        $elapsed = [int]((Get-Date) - $started).TotalMilliseconds
        return [pscustomobject]@{
            request_id = $RequestRow.request_id
            transcript_row = $RequestRow.transcript_row
            replay_order = $RequestRow.replay_order
            http_status = 0
            elapsed_ms = $elapsed
            error = $_.Exception.Message
            response = $null
        }
    }
}

function Invoke-Stage34LiveReplay {
    param(
        [Parameter(Mandatory=$true)] [string] $ServerUrl,
        [Parameter(Mandatory=$true)] [string] $RequestsPath,
        [Parameter(Mandatory=$true)] [string] $OutputDir,
        [ValidateSet("sequential", "concurrent")] [string] $Mode,
        [int] $TimeoutSec = 120,
        [int] $ThrottleLimit = 4
    )
    $responsesPath = Join-Path $OutputDir "responses.jsonl"
    Remove-Item -LiteralPath $responsesPath -Force -ErrorAction SilentlyContinue
    $rows = @(Read-Stage34JsonLines -Path $RequestsPath)
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $rows[$i] | Add-Member -NotePropertyName "replay_order" -NotePropertyValue ($i + 1) -Force
    }
    $results = New-Object System.Collections.Generic.List[object]
    $effectiveThrottle = [Math]::Max(1, $ThrottleLimit)

    if ($Mode -eq "sequential") {
        foreach ($row in $rows) {
            $results.Add((Invoke-Stage34RequestFile -ServerUrl $ServerUrl -RequestRow $row -TimeoutSec $TimeoutSec))
        }
    } else {
        $pending = New-Object System.Collections.Generic.List[object]
        foreach ($row in $rows) {
            while ($pending.Count -ge $effectiveThrottle) {
                $done = Wait-Job -Job @($pending.ToArray()) -Any -Timeout 1
                if ($done) {
                    foreach ($job in @($done)) {
                        $results.Add((Receive-Job -Job $job))
                        Remove-Job -Job $job
                        [void]$pending.Remove($job)
                    }
                }
            }
            $job = Start-ThreadJob -ArgumentList $ServerUrl, $row, $TimeoutSec -ScriptBlock {
                param($ServerUrl, $RequestRow, $TimeoutSec)
                $started = Get-Date
                try {
                    $body = Get-Content -Raw -LiteralPath $RequestRow.request_body_path
                    $response = Invoke-RestMethod -Uri "$ServerUrl/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec $TimeoutSec
                    [pscustomobject]@{
                        request_id = $RequestRow.request_id
                        transcript_row = $RequestRow.transcript_row
                        replay_order = $RequestRow.replay_order
                        http_status = 200
                        elapsed_ms = [int]((Get-Date) - $started).TotalMilliseconds
                        error = ""
                        response = $response
                    }
                } catch {
                    [pscustomobject]@{
                        request_id = $RequestRow.request_id
                        transcript_row = $RequestRow.transcript_row
                        replay_order = $RequestRow.replay_order
                        http_status = 0
                        elapsed_ms = [int]((Get-Date) - $started).TotalMilliseconds
                        error = $_.Exception.Message
                        response = $null
                    }
                }
            }
            $pending.Add($job)
        }
        while ($pending.Count -gt 0) {
            $done = Wait-Job -Job @($pending.ToArray()) -Any -Timeout 1
            if ($done) {
                foreach ($job in @($done)) {
                    $results.Add((Receive-Job -Job $job))
                    Remove-Job -Job $job
                    [void]$pending.Remove($job)
                }
            }
        }
    }

    $completionOrder = 0
    foreach ($result in $results) {
        $completionOrder++
        $result | Add-Member -NotePropertyName "completion_order" -NotePropertyValue $completionOrder -Force
    }

    foreach ($result in ($results | Sort-Object replay_order, transcript_row, request_id)) {
        Write-Stage34JsonLine -Path $responsesPath -Object $result
    }

    return [pscustomobject]@{
        responses_path = $responsesPath
        response_count = $results.Count
        success_count = @($results | Where-Object { $_.http_status -eq 200 }).Count
        error_count = @($results | Where-Object { $_.http_status -ne 200 }).Count
    }
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path "_test_output" "stage34-dry-run"
}
if (-not [System.IO.Path]::IsPathRooted($OutputDir)) {
    $workspaceRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
    $OutputDir = Join-Path $workspaceRoot $OutputDir
}
if ([string]::IsNullOrWhiteSpace($TranscriptPath)) {
    $TranscriptPath = Join-Path $PSScriptRoot "_fixtures\stage34\synthetic-agentic.jsonl"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$rows = Read-Stage34Transcript -Path $TranscriptPath
$events = ConvertTo-Stage34ReplayEvents -Rows $rows
$render = Export-Stage34ReplayRequests -Events $events -OutputDir $OutputDir -Model $Model -MaxTokens $MaxTokens -IncludeRawPrompts:$IncludeRawPrompts

$expectedPath = Join-Path $OutputDir "expected-hits.jsonl"
& "$PSScriptRoot\analyze-stage34-expected-hits.ps1" -EventsPath $render.events_path -OutputPath $expectedPath -HotBudgetMiB $HotBudgetMiB -ColdBudgetMiB $ColdBudgetMiB -EstimatedPayloadMiBPerToken $EstimatedPayloadMiBPerToken | Out-Host

$summary = [pscustomobject]@{
    mode = $Mode
    transcript_path = (Resolve-Path -LiteralPath $TranscriptPath).Path
    transcript_rows = $rows.Count
    replay_events = $events.Count
    captured_events = (@($events | Where-Object { $_.prompt_capture -eq "captured" })).Count
    reconstructed_events = (@($events | Where-Object { $_.prompt_capture -eq "reconstructed" })).Count
    blocked_events = (@($events | Where-Object { $_.blocked_reason })).Count
    events_path = $render.events_path
    requests_path = $render.requests_path
    expected_hits_path = $expectedPath
    raw_prompt_capture = [bool]$IncludeRawPrompts
    hot_budget_mib = $HotBudgetMiB
    cold_budget_mib = $ColdBudgetMiB
    estimated_payload_mib_per_token = $EstimatedPayloadMiBPerToken
    server_url = $ServerUrl
    responses_path = ""
    metrics_before_path = ""
    metrics_after_path = ""
    response_count = 0
    success_count = 0
    error_count = 0
}

if ($Mode -ne "dry-run") {
    if ([string]::IsNullOrWhiteSpace($ServerUrl)) {
        throw "Stage 34 $Mode live replay requires -ServerUrl."
    }
    $beforePath = Join-Path $OutputDir "metrics-before.txt"
    $afterPath = Join-Path $OutputDir "metrics-after.txt"
    [void](Invoke-Stage34MetricsCapture -ServerUrl $ServerUrl -Path $beforePath)
    $live = Invoke-Stage34LiveReplay -ServerUrl $ServerUrl -RequestsPath $render.requests_path -OutputDir $OutputDir -Mode $Mode -TimeoutSec $TimeoutSec -ThrottleLimit $ThrottleLimit
    [void](Invoke-Stage34MetricsCapture -ServerUrl $ServerUrl -Path $afterPath)
    $summary.metrics_before_path = $beforePath
    $summary.metrics_after_path = $afterPath
    $summary.responses_path = $live.responses_path
    $summary.response_count = $live.response_count
    $summary.success_count = $live.success_count
    $summary.error_count = $live.error_count
}

$summary | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath (Join-Path $OutputDir "summary.json") -Encoding utf8NoBOM

Write-Host "Stage34 replay summary:"
$summary | ConvertTo-Json -Depth 16
