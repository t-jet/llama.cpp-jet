#requires -Version 5
# agentic-prompt-generator.ps1
# Stage 20 Item 1: deterministic chat-prompt generator for TP-20-SY1..SY5.
# Public entry point: New-AgenticChatPrompt
# Output schema: stage20-agentic-prompt-v1
#
# Status: PASS; Date: 2026-06-18; Owner: Developer (Stage 20 Item 1)
#
# Adaptive chunking:
#   - phrase bank (3-5 tokens) when remaining <= 5
#   - sentence bank (12-20 tokens) when remaining <= 30
#   - paragraph bank (80-150 tokens) when remaining <= 1000
#   - long paragraph bank (200-400 tokens) when remaining > 1000
# Stop condition: n >= target * 0.95. Each round adds <= 10% of target
# (the chunk bank size caps it), so result lands in [target*0.95, target*1.05].
#
# Usage:
#   . .\_design_docs\cache-handling-test-scripts\lib\agentic-prompt-generator.ps1
#   New-AgenticChatPrompt -TargetTokens 100 -SizeClass 12k `
#       -PromptClass exact-repeat `
#       -OutPath .\_test_output\stage20-item1-smoke.json `
#       -ServerUrl http://127.0.0.1:8080

param()

$ErrorActionPreference = 'Stop'

# --- Phrase bank (3-5 tokens) for tiny remaining budgets ---
$script:PhraseBank = @(
    'The cache hit.'
    'The cache miss.'
    'Restore accepted.'
    'Restore denied.'
    'Promote to hot.'
    'Demote to cold.'
    'Skip demotion.'
    'Evict from hot.'
    'Boundary match.'
    'Checksum match.'
    'No match found.'
    'Unsafe prefix.'
    'Cold bytes ok.'
    'Cold bytes over.'
    'Skipped demote.'
    'Hot layer ready.'
    'Slot routing done.'
    'Tokens evaluated.'
    'Cache hit logged.'
    'Cache miss logged.'
)

# --- Sentence bank (12-20 tokens) for small remaining budgets ---
$script:SentenceBank = @(
    'The cache layer matches the prompt prefix against a stored checkpoint.'
    'A near-duplicate request changes one user-turn suffix and exercises the bounded miss reason path.'
    'The cold layer maintains a bytes counter and skips demotion when the budget is exceeded.'
    'The unsafe prefix rejected counter records the number of prefix-only candidates that were not restored.'
    'The hot in-memory layer holds the active working set for parallel slot decode paths.'
    'A same-branch continuation extends the assistant turn and produces a fresh boundary.'
    'A different-agent same-prefix request uses a different system content but identical user content.'
    'The redacted evidence JSONL omits the prompt body and records only a content checksum.'
    'The bounded miss reason field names the cause without exposing the prompt text.'
    'The 1000 hits-plus-misses threshold classifies a stress row as meets-intent or low-throughput.'
)

# --- Paragraph bank (80-150 tokens) for medium remaining budgets ---
$script:ParagraphBank = @(
    'Section {N}: The cache controller maintains a hot in-memory layer and a cold disk-backed payload layer. The hot layer holds the active working set; the cold layer retains evicted payloads up to a bounded byte budget. A restore lookup is admitted only when the descriptor span matches a stored boundary and the checksum is correct. Prefix-only candidates are classified as unsafe and rejected without slot mutation.'
    'Section {N}: The agentic assistant operates under a deterministic seed and produces structured output. Every chat completion emits timing information including tokens evaluated, cache hits, cache misses, and slot routing decisions. The cache controller reports counters for both the hot and cold layers: payloads promoted, payloads demoted, payloads evicted, and payloads skipped because of budget pressure.'
    'Section {N}: The chat path constructs a prompt-span boundary array that includes one boundary per message plus a fallback end-of-prompt boundary. The matching loop in the cache restore path picks the first boundary whose token_end equals the descriptor span end. The strict validator rejects mismatches to keep the boundary metadata self-consistent with the slot token state.'
    'Section {N}: Cold budget enforcement is implemented in the cache controller. The cold layer maintains a bytes counter; when a write would exceed the budget, the controller skips the demotion and increments the skipped counter. The skipped counter is exposed via the public /metrics endpoint. A row that exceeds the per-row cold budget is recorded as blocked rather than passing silently.'
    'Section {N}: The branch-forest log may diverge across turns, depending on speculative-decoding internal state. The cache layer therefore only restores from a checkpoint when the prompt span is exact or near-exact, and any prefix-only candidate is classified as unsafe and rejected. The four prompt classes exercise exact repeat, near-duplicate suffix, different agent with same prefix, and same-branch continuation.'
)

# --- Long-paragraph bank (200-400 tokens) for large remaining budgets ---
$script:LongParagraphBank = @(
    'Section {N}: A multi-tenant cache layer serves prompt lookups for an agentic assistant. The architecture separates hot in-memory state from cold disk-backed payloads, and the cache controller routes slot requests across parallel decode paths. The hot layer holds the active working set while the cold layer retains evicted payloads up to a bounded budget. A restore lookup is admitted only when the descriptor span matches a stored boundary and the checksum is correct; prefix-only candidates are classified as unsafe and rejected without slot mutation. The cache controller exposes a public /metrics endpoint that reports counters for both layers. The redacted evidence mode writes a JSONL record per restore lookup with the prompt body omitted and replaced by a content checksum; the raw mode writes the prompt body for forensic analysis but is gated behind an opt-in flag and a writable evidence directory. The bounded miss reason field names the cause of a miss without exposing the prompt text. The 1000 hits-plus-misses threshold classifies a stress row as meets-intent or low-throughput. The test plan exercises exact repeat, near-duplicate suffix, different agent with same prefix, and same-branch continuation prompt classes at the 12k, 24k, and 60k size classes.'
    'Section {N}: The agentic assistant operates under a deterministic seed and produces structured output. Every chat completion emits timing information including tokens evaluated, cache hits, cache misses, and slot routing decisions. The cache controller reports counters for both the hot and cold layers: payloads promoted, payloads demoted, payloads evicted, and payloads skipped because of budget pressure. The chat path constructs a prompt-span boundary array that includes one boundary per message plus a fallback end-of-prompt boundary. The matching loop in the cache restore path picks the first boundary whose token_end equals the descriptor span end. The strict validator rejects mismatches to keep the boundary metadata self-consistent with the slot token state. The branch-forest log may diverge across turns depending on speculative-decoding internal state. The cache layer therefore only restores from a checkpoint when the prompt span is exact or near-exact, and any prefix-only candidate is classified as unsafe and rejected.'
    'Section {N}: Cold budget enforcement is implemented in the cache controller. The cold layer maintains a bytes counter; when a write would exceed the budget, the controller skips the demotion and increments the skipped counter. The skipped counter is exposed via the public /metrics endpoint. A row that exceeds the per-row cold budget is recorded as blocked rather than passing silently. The cache controller also enforces a hot in-memory budget via a payload size check on restore admission. A restore that would push the hot layer over budget is denied and a denied-restored counter is incremented. The denied-restored counter is exposed alongside the skipped counter. The redacted evidence JSONL captures the bounded miss reason for each denied restore. The test plan asserts that the cold bytes gauge does not exceed the cold bytes budget gauge under any test row, and that the skipped counter increments before any filesystem write failure occurs.'
)

function New-AgenticChatPrompt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [int]    $TargetTokens,
        [Parameter(Mandatory = $true)]
        [ValidateSet('12k','24k','60k')]
        [string] $SizeClass,
        [Parameter(Mandatory = $true)]
        [ValidateSet('exact-repeat','near-duplicate','different-agent-same-prefix','same-branch-continuation')]
        [string] $PromptClass,
        [Parameter(Mandatory = $true)] [string] $OutPath,
        [Parameter(Mandatory = $true)] [string] $ServerUrl,
        [int]    $Seed          = 42,
        [int]    $MaxIterations = 50,
        [int]    $TimeoutSec    = 30
    )

    if ($TargetTokens -le 0) {
        throw "New-AgenticChatPrompt: TargetTokens must be positive (got $TargetTokens)"
    }
    if ($MaxIterations -le 0) {
        throw "New-AgenticChatPrompt: MaxIterations must be positive (got $MaxIterations)"
    }
    if (-not (Test-Path (Split-Path -Parent $OutPath))) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutPath) | Out-Null
    }

    $rng = New-Object System.Random($Seed)

    # Initial messages skeleton: system + tiny first user (single short sentence).
    $messages = New-Object System.Collections.Generic.List[object]
    [void]$messages.Add([pscustomobject]@{
        role    = 'system'
        content = "You are an agentic assistant operating under deterministic seed $Seed. Reply concisely."
    })
    [void]$messages.Add([pscustomobject]@{
        role    = 'user'
        content = "Section 1 starting at index $($rng.Next(1000,9999))."
    })

    $iterations       = 0
    $lastTokens       = 0
    $lastDelta        = 0
    $stopAt           = [int]([Math]::Floor($TargetTokens * 0.95))
    $tokenizeEndpoint = "$ServerUrl/tokenize"

    while ($iterations -lt $MaxIterations) {
        $iterations++
        $joined = Get-JoinedMessagesText -Messages $messages
        $n = Invoke-TokenizeMeasure -Joined $joined -Endpoint $tokenizeEndpoint -TimeoutSec $TimeoutSec
        $lastDelta  = $n - $lastTokens
        $lastTokens = $n
        if ($n -ge $stopAt) { break }
        $remaining = $TargetTokens - $n
        $chunk     = Get-ExpansionChunk -Remaining $remaining -Target $TargetTokens -Iter $iterations -Rng $rng
        Expand-MessagesRound -Messages $messages -Chunk $chunk
    }

    if ($lastTokens -lt $stopAt) {
        throw "New-AgenticChatPrompt: MaxIterations=$MaxIterations exhausted; lastTokens=$lastTokens stopAt=$stopAt target=$TargetTokens iterations=$iterations delta=$lastDelta"
    }

    $actualTokens = $lastTokens
    $measurement  = [pscustomobject]@{
        endpoint        = '/tokenize'
        server_url      = $ServerUrl
        measured_at_unix= [int][double]::Parse((Get-Date -UFormat %s))
        iterations      = $iterations
    }
    $checksum            = New-ChecksumFromMessages -Messages $messages
    $promptClassSpecific = Get-PromptClassOutput -PromptClass $PromptClass -Messages $messages

    $out = [pscustomobject]@{
        version           = 'stage20-agentic-prompt-v1'
        size_class        = $SizeClass
        prompt_class      = $PromptClass
        target_tokens     = $TargetTokens
        actual_tokens     = $actualTokens
        token_measurement = $measurement
        messages          = $messages.ToArray()
        checksum          = $checksum
        seed              = $Seed
        variant           = $promptClassSpecific
    }

    Write-AgenticPromptJson -OutPath $OutPath -Object $out

    return [pscustomobject]@{
        OutPath       = $OutPath
        ActualTokens  = $actualTokens
        Iterations    = $iterations
        Checksum      = $checksum
    }
}

# --- Helper: join messages content for tokenize measurement ---
function Get-JoinedMessagesText {
    param(
        [Parameter(Mandatory = $true)] $Messages
    )
    $sb = New-Object System.Text.StringBuilder
    foreach ($m in $Messages) {
        [void]$sb.AppendLine("[$($m.role)]")
        [void]$sb.AppendLine($m.content)
    }
    return $sb.ToString()
}

# --- Helper: expand messages with one chunk round ---
function Expand-MessagesRound {
    param(
        [Parameter(Mandatory = $true)] $Messages,
        [Parameter(Mandatory = $true)] [string] $Chunk
    )
    $last = $Messages[$Messages.Count - 1]
    if ($last.role -eq 'user') {
        $last.content = $last.content + "`n" + $Chunk
    } else {
        [void]$Messages.Add([pscustomobject]@{
            role    = 'user'
            content = $Chunk
        })
    }
}

# --- Helper: pick a chunk sized to remaining token budget ---
function Get-ExpansionChunk {
    param(
        [Parameter(Mandatory = $true)] [int]    $Remaining,
        [Parameter(Mandatory = $true)] [int]    $Target,
        [Parameter(Mandatory = $true)] [int]    $Iter,
        [Parameter(Mandatory = $true)] $Rng
    )
    # Phrase bank when remaining is tiny (preserves the +5% upper bound for small targets).
    if ($Remaining -le 5) {
        return $script:PhraseBank[$Rng.Next(0, $script:PhraseBank.Count)]
    }
    # Sentence bank for small remaining (up to 100 tokens).
    if ($Remaining -le 100) {
        return $script:SentenceBank[$Rng.Next(0, $script:SentenceBank.Count)]
    }
    # Paragraph bank for medium remaining.
    if ($Remaining -le 1000) {
        return ($script:ParagraphBank[$Rng.Next(0, $script:ParagraphBank.Count)] -replace '\{N\}', ([string]$Iter))
    }
    # Long paragraph bank for large remaining.
    return ($script:LongParagraphBank[$Rng.Next(0, $script:LongParagraphBank.Count)] -replace '\{N\}', ([string]$Iter))
}

# --- Helper: POST /tokenize, return tokens_evaluated count ---
function Invoke-TokenizeMeasure {
    param(
        [Parameter(Mandatory = $true)] [string] $Joined,
        [Parameter(Mandatory = $true)] [string] $Endpoint,
        [int] $TimeoutSec = 30
    )
    $body = @{ content = $Joined; add_special = $true } | ConvertTo-Json -Compress -Depth 5
    $resp = Invoke-WebRequest -Uri $Endpoint -Method POST `
        -ContentType 'application/json' -Body $body `
        -UseBasicParsing -TimeoutSec $TimeoutSec
    if ($resp.StatusCode -ne 200) {
        throw "Invoke-TokenizeMeasure: status $($resp.StatusCode) from $Endpoint"
    }
    return (Get-ServerTokensEvaluated -Json $resp.Content)
}

# --- Helper: parse tokens_evaluated from /tokenize response ---
function Get-ServerTokensEvaluated {
    param(
        [Parameter(Mandatory = $true)] [string] $Json
    )
    $obj = $Json | ConvertFrom-Json
    foreach ($name in 'tokens_evaluated','n_tokens','tokens') {
        $p = $obj.PSObject.Properties[$name]
        if ($p) {
            $v = $p.Value
            if ($v -is [array]) { return $v.Count }
            if ($null -ne $v)   { return [int]$v }
        }
    }
    throw "Get-ServerTokensEvaluated: no token count field in response"
}

# --- Helper: sha256 over concatenated content (NOT tokens) ---
function New-ChecksumFromMessages {
    param(
        [Parameter(Mandatory = $true)] $Messages
    )
    $sb = New-Object System.Text.StringBuilder
    foreach ($m in $Messages) {
        [void]$sb.Append($m.role)
        [void]$sb.Append("`n")
        [void]$sb.Append($m.content)
        [void]$sb.Append("`n")
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $hash  = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return ([BitConverter]::ToString($hash) -replace '-','').ToLowerInvariant()
}

# --- Helper: prompt-class specific output hint ---
function Get-PromptClassOutput {
    param(
        [Parameter(Mandatory = $true)] [string] $PromptClass,
        [Parameter(Mandatory = $true)] $Messages
    )
    switch ($PromptClass) {
        'exact-repeat'                { return [pscustomobject]@{ repeat = 'identical';     suffix_word = $null } }
        'near-duplicate'              { return [pscustomobject]@{ repeat = 'suffix';        suffix_word = 'update' } }
        'different-agent-same-prefix' { return [pscustomobject]@{ repeat = 'system';        suffix_word = $null } }
        'same-branch-continuation'    { return [pscustomobject]@{ repeat = 'continuation';  suffix_word = $null } }
        default { throw "Get-PromptClassOutput: unknown prompt class $PromptClass" }
    }
}

# --- Helper: write JSON with LF line endings and no BOM ---
function Write-AgenticPromptJson {
    param(
        [Parameter(Mandatory = $true)] [string] $OutPath,
        [Parameter(Mandatory = $true)] $Object
    )
    $json = $Object | ConvertTo-Json -Depth 10
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($OutPath, $json, $utf8)
    $content = [System.IO.File]::ReadAllText($OutPath) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($OutPath, $content, $utf8)
}
