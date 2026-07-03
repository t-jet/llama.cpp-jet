Set-StrictMode -Version Latest

function ConvertTo-Stage34Hash {
    param([AllowNull()][object] $Value)
    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    if ($text.Length -eq 0) { return "" }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Get-Stage34JsonValue {
    param(
        [Parameter(Mandatory=$true)] [object] $Object,
        [Parameter(Mandatory=$true)] [string] $Name
    )
    if ($null -eq $Object) { return $null }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Find-Stage34JsonValues {
    param(
        [AllowNull()][object] $Object,
        [Parameter(Mandatory=$true)] [string] $Name,
        [int] $Limit = 32
    )
    $results = New-Object System.Collections.Generic.List[object]
    $queue = New-Object System.Collections.Queue
    if ($null -ne $Object) { $queue.Enqueue($Object) }
    while ($queue.Count -gt 0 -and $results.Count -lt $Limit) {
        $item = $queue.Dequeue()
        if ($null -eq $item -or $item -is [string]) { continue }
        if ($item -is [System.Collections.IEnumerable] -and -not ($item -is [pscustomobject])) {
            foreach ($child in $item) { if ($null -ne $child) { $queue.Enqueue($child) } }
            continue
        }
        foreach ($prop in $item.PSObject.Properties) {
            if ($prop.Name -eq $Name) { $results.Add($prop.Value) }
            if ($null -ne $prop.Value -and $prop.Value -isnot [string]) { $queue.Enqueue($prop.Value) }
        }
    }
    return $results.ToArray()
}

function New-Stage34ReplayEvent {
    param(
        [int] $TranscriptRow,
        [string] $RequestId,
        [string] $EventKind,
        [string] $SessionId,
        [string] $AgentId,
        [string] $ParentAgentId,
        [string] $BranchId,
        [string] $ParentBranchId,
        [int] $TurnIndex,
        [string] $ModelId,
        [string] $PromptSource,
        [string] $PromptCapture,
        [string] $RenderPolicy,
        [string] $BlockedReason,
        [object[]] $Messages
    )
    $messagesJson = if ($Messages.Count -gt 0) { $Messages | ConvertTo-Json -Depth 32 -Compress } else { "" }
    [pscustomobject]@{
        schema_version = 1
        transcript_row = $TranscriptRow
        request_id = $RequestId
        event_kind = $EventKind
        session_id_hash = ConvertTo-Stage34Hash $SessionId
        agent_id_hash = ConvertTo-Stage34Hash $AgentId
        parent_agent_id_hash = ConvertTo-Stage34Hash $ParentAgentId
        branch_id_hash = ConvertTo-Stage34Hash $BranchId
        parent_branch_id_hash = ConvertTo-Stage34Hash $ParentBranchId
        turn_index = $TurnIndex
        model_id_hash = ConvertTo-Stage34Hash $ModelId
        prompt_source = $PromptSource
        prompt_capture = $PromptCapture
        render_policy = $RenderPolicy
        request_body_path = ""
        messages_sha256 = ConvertTo-Stage34Hash $messagesJson
        token_count = 0
        token_checksum = ""
        blocked_reason = $BlockedReason
        messages = $Messages
    }
}

function Get-Stage34FirstString {
    param([object[]] $Values, [string] $Default = "")
    foreach ($value in $Values) {
        if ($null -ne $value -and [string]$value) { return [string]$value }
    }
    return $Default
}

function Get-Stage34EventKind {
    param([object] $Row, [string] $AgentId, [string] $ParentAgentId, [string] $Default = "main_request")
    $explicit = Get-Stage34JsonValue $Row "stage34_event_kind"
    if ($null -eq $explicit) { $explicit = Get-Stage34JsonValue $Row "event_kind" }
    if ($null -ne $explicit -and [string]$explicit) { return [string]$explicit }
    $kindValues = @(Find-Stage34JsonValues $Row "kind" 8)
    foreach ($kind in $kindValues) {
        $text = ([string]$kind).ToLowerInvariant()
        if ($text -match "subagent.*return|return.*subagent") { return "subagent_return" }
        if ($text -match "continuation|resume") { return "continuation" }
        if ($text -match "subagent|delegate|task") { return "subagent_request" }
    }
    if ($ParentAgentId -and $AgentId -and $AgentId -ne $ParentAgentId) { return "subagent_request" }
    return $Default
}

function Get-Stage34BranchIds {
    param(
        [object] $Row,
        [string] $EventKind,
        [string] $AgentId,
        [string] $ParentAgentId,
        [int] $RowNumber
    )
    $branchId = Get-Stage34JsonValue $Row "stage34_branch_id"
    if ($null -eq $branchId) { $branchId = Get-Stage34JsonValue $Row "branch_id" }
    if ($null -eq $branchId) { $branchId = Get-Stage34JsonValue $Row "branchId" }

    $parentBranchId = Get-Stage34JsonValue $Row "stage34_parent_branch_id"
    if ($null -eq $parentBranchId) { $parentBranchId = Get-Stage34JsonValue $Row "parent_branch_id" }
    if ($null -eq $parentBranchId) { $parentBranchId = Get-Stage34JsonValue $Row "parentBranchId" }

    if (-not [string]$branchId) {
        if ($EventKind -eq "subagent_request" -or $EventKind -eq "subagent_return") {
            $childSeed = "{0}|{1}|{2}" -f $ParentAgentId, $AgentId, $RowNumber
            $branchId = "child-" + (ConvertTo-Stage34Hash $childSeed).Substring(0, 12)
        } else {
            $branchId = "main"
        }
    }

    if (-not [string]$parentBranchId) {
        if ($EventKind -eq "subagent_return" -or $EventKind -eq "continuation") {
            $parentBranchId = "main"
        } else {
            $parentBranchId = ""
        }
    }

    return [pscustomobject]@{
        BranchId = [string]$branchId
        ParentBranchId = [string]$parentBranchId
    }
}

function ConvertTo-Stage34ReplayEvents {
    param(
        [Parameter(Mandatory=$true)] [object[]] $Rows,
        [string] $DefaultSessionId = "stage34-session"
    )
    $events = New-Object System.Collections.Generic.List[object]
    $sessionId = $DefaultSessionId
    $turn = 0
    foreach ($row in $Rows) {
        $rowNumber = [int]$row.__stage34_row
        $root = Get-Stage34JsonValue $row "v"
        if ($null -eq $root) { $root = $row }

        $sessions = @(Find-Stage34JsonValues $row "sessionId" 4)
        if ($sessions.Count -gt 0 -and [string]$sessions[0]) { $sessionId = [string]$sessions[0] }

        $requests = @(Find-Stage34JsonValues $row "requestId" 16)
        $messages = @(Find-Stage34JsonValues $row "messages" 1)
        $promptValues = @(Find-Stage34JsonValues $row "prompt" 1)
        $inputTextValues = @(Find-Stage34JsonValues $row "inputText" 1)
        $agentNames = @(Find-Stage34JsonValues $row "name" 8)
        $agentIds = @(Find-Stage34JsonValues $row "agent_id" 4)
        $parentAgentIds = @(Find-Stage34JsonValues $row "parent_agent_id" 4)
        $modelIds = @(Find-Stage34JsonValues $row "modelId" 4)

        $agentId = Get-Stage34FirstString -Values @($agentIds + $agentNames) -Default "agent"
        $parentAgentId = Get-Stage34FirstString -Values $parentAgentIds -Default ""
        $modelId = Get-Stage34FirstString -Values $modelIds -Default ""
        $eventKind = Get-Stage34EventKind -Row $row -AgentId $agentId -ParentAgentId $parentAgentId
        $branch = Get-Stage34BranchIds -Row $row -EventKind $eventKind -AgentId $agentId -ParentAgentId $parentAgentId -RowNumber $rowNumber

        if ($messages.Count -gt 0) {
            $turn++
            $events.Add((New-Stage34ReplayEvent `
                -TranscriptRow $rowNumber `
                -RequestId ("row-{0:D5}" -f $rowNumber) `
                -EventKind $eventKind `
                -SessionId $sessionId `
                -AgentId $agentId `
                -ParentAgentId $parentAgentId `
                -BranchId $branch.BranchId `
                -ParentBranchId $branch.ParentBranchId `
                -TurnIndex $turn `
                -ModelId $modelId `
                -PromptSource "captured_messages" `
                -PromptCapture "captured" `
                -RenderPolicy "captured" `
                -BlockedReason "" `
                -Messages @($messages[0])))
            continue
        }

        if ($promptValues.Count -gt 0 -or $inputTextValues.Count -gt 0) {
            $text = if ($promptValues.Count -gt 0) { [string]$promptValues[0] } else { [string]$inputTextValues[0] }
            $turn++
            $events.Add((New-Stage34ReplayEvent `
                -TranscriptRow $rowNumber `
                -RequestId ("row-{0:D5}" -f $rowNumber) `
                -EventKind $eventKind `
                -SessionId $sessionId `
                -AgentId $agentId `
                -ParentAgentId $parentAgentId `
                -BranchId $branch.BranchId `
                -ParentBranchId $branch.ParentBranchId `
                -TurnIndex $turn `
                -ModelId $modelId `
                -PromptSource "captured_text" `
                -PromptCapture "captured" `
                -RenderPolicy "text_to_chat" `
                -BlockedReason "" `
                -Messages @(@{ role = "user"; content = $text })))
            continue
        }

        foreach ($requestId in $requests) {
            $turn++
            $events.Add((New-Stage34ReplayEvent `
                -TranscriptRow $rowNumber `
                -RequestId ([string]$requestId) `
                -EventKind $eventKind `
                -SessionId $sessionId `
                -AgentId $agentId `
                -ParentAgentId $parentAgentId `
                -BranchId $branch.BranchId `
                -ParentBranchId $branch.ParentBranchId `
                -TurnIndex $turn `
                -ModelId $modelId `
                -PromptSource "provider_patch" `
                -PromptCapture "reconstructed" `
                -RenderPolicy "blocked_transcript_incomplete" `
                -BlockedReason "BLOCKED-transcript-incomplete" `
                -Messages @()))
        }
    }
    return $events.ToArray()
}

function Read-Stage34Transcript {
    param([Parameter(Mandatory=$true)] [string] $Path)
    $rows = New-Object System.Collections.Generic.List[object]
    $rowNumber = 0
    foreach ($line in [System.IO.File]::ReadLines((Resolve-Path -LiteralPath $Path))) {
        $rowNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $obj = $line | ConvertFrom-Json -Depth 100
        $obj | Add-Member -NotePropertyName "__stage34_row" -NotePropertyValue $rowNumber -Force
        $rows.Add($obj)
    }
    return $rows.ToArray()
}
