Set-StrictMode -Version Latest

function Write-Stage34JsonLine {
    param(
        [Parameter(Mandatory=$true)] [object] $Object,
        [Parameter(Mandatory=$true)] [string] $Path
    )
    $json = $Object | ConvertTo-Json -Depth 64 -Compress
    [System.IO.File]::AppendAllText($Path, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
}

function Get-Stage34RenderedTokenInfo {
    param(
        [Parameter(Mandatory=$true)] [object] $Request,
        [object[]] $PlanMessages = @()
    )
    $messagesForPlan = if ($PlanMessages.Count -gt 0) { $PlanMessages } else { @($Request.messages) }
    $json = $messagesForPlan | ConvertTo-Json -Depth 64 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $checksum = ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
    $messageText = ""
    foreach ($message in $messagesForPlan) {
        $content = $message.content
        if ($null -ne $content) { $messageText += " " + [string]$content }
    }
    $tokens = @([regex]::Matches($messageText.Trim(), '\S+'))
    [pscustomobject]@{
        token_count = $tokens.Count
        token_checksum = $checksum
    }
}

function ConvertTo-Stage34ChatRequest {
    param(
        [Parameter(Mandatory=$true)] [object] $Event,
        [string] $Model = "stage34-replay",
        [int] $MaxTokens = 1,
        [switch] $IncludeRawPrompts
    )
    $messages = @()
    if ($IncludeRawPrompts -and $Event.messages -and $Event.messages.Count -gt 0) {
        foreach ($m in $Event.messages) {
            $messages += $m
        }
    } else {
        $messages += @{
            role = "user"
            content = "[stage34 blocked transcript row $($Event.transcript_row)]"
        }
    }

    [pscustomobject]@{
        model = $Model
        max_tokens = $MaxTokens
        messages = $messages
        metadata = @{
            stage34 = @{
                request_id = $Event.request_id
                transcript_row = $Event.transcript_row
                session_id_hash = $Event.session_id_hash
                branch_id_hash = $Event.branch_id_hash
                parent_branch_id_hash = $Event.parent_branch_id_hash
                agent_id_hash = $Event.agent_id_hash
                turn_index = $Event.turn_index
            }
        }
    }
}

function Export-Stage34ReplayRequests {
    param(
        [Parameter(Mandatory=$true)] [object[]] $Events,
        [Parameter(Mandatory=$true)] [string] $OutputDir,
        [string] $Model = "stage34-replay",
        [int] $MaxTokens = 1,
        [switch] $IncludeRawPrompts
    )
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $rawPromptsDir = $null
    if ($IncludeRawPrompts) {
        $rawPromptsDir = Join-Path $OutputDir "raw-prompts"
        New-Item -ItemType Directory -Force -Path $rawPromptsDir | Out-Null
    }
    $eventsPath = Join-Path $OutputDir "events.jsonl"
    $requestsPath = Join-Path $OutputDir "requests.jsonl"
    Remove-Item -LiteralPath $eventsPath, $requestsPath -Force -ErrorAction SilentlyContinue

    foreach ($event in $Events) {
        $requestPath = Join-Path $OutputDir ("request-{0}.json" -f $event.request_id)
        $request = ConvertTo-Stage34ChatRequest -Event $event -Model $Model -MaxTokens $MaxTokens -IncludeRawPrompts:$IncludeRawPrompts
        $request | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $requestPath -Encoding utf8NoBOM
        if ($IncludeRawPrompts -and $event.messages -and $event.messages.Count -gt 0) {
            $rawPromptPath = Join-Path $rawPromptsDir ("request-{0}.json" -f $event.request_id)
            [pscustomobject]@{
                request_id = $event.request_id
                transcript_row = $event.transcript_row
                messages = $event.messages
            } | ConvertTo-Json -Depth 64 | Set-Content -LiteralPath $rawPromptPath -Encoding utf8NoBOM
        }
        $tokenInfo = Get-Stage34RenderedTokenInfo -Request $request -PlanMessages @($event.messages)
        $event.request_body_path = $requestPath
        $event.token_count = $tokenInfo.token_count
        $event.token_checksum = $tokenInfo.token_checksum
        $eventRow = $event | Select-Object * -ExcludeProperty messages
        Write-Stage34JsonLine -Object $eventRow -Path $eventsPath
        Write-Stage34JsonLine -Object ([pscustomobject]@{
            request_id = $event.request_id
            transcript_row = $event.transcript_row
            blocked_reason = $event.blocked_reason
            request_body_path = $requestPath
        }) -Path $requestsPath
    }

    return [pscustomobject]@{
        events_path = $eventsPath
        requests_path = $requestsPath
        request_count = $Events.Count
    }
}
