#requires -Version 5
# stage38-prefix-restore-and-cold-budget.ps1
#
# Stage 38 standalone evidence: chat duplicate-plus-suffix partial restore
# (cached_tokens > 0, timings.cache_n match, public prompt_tokens exact
# rendered request length), hybrid hit delta, prefix metrics, and the public
# Prometheus 2147483648 cold-budget gauge for 2048 MiB.
#
# This script is standalone. It does not depend on a prior run or artifact dir.
# Reuse compare-legacy-vs-hybrid.ps1 -BurstDuplicateMode for broad A/B runs;
# this script adds the Stage-38-specific suffix turn + cached_tokens/cache_n
# assertion + rendered prompt_tokens check + cold-budget gauge line check.
#
# Usage:
#   pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\stage38-prefix-restore-and-cold-budget.ps1 `
#       -ModelPath .\_test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
#       -LlamaServerPath build\bin\Release\llama-server.exe `
#       -RunRoot ._test_output\stage38-prefix-restore-YYYYMMDD-NN `
#       -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN-stage38.md `
#       -ColdBudgetMiB 2048

param(
    [string] $ModelPath       = '',
    [string] $LlamaServerPath = '',
    [string] $RunRoot         = '',
    [string] $ReportPath      = '',
    [int]    $BasePort        = 8180,
    [int]    $HotBudgetMiB    = 512,
    [int]    $ColdBudgetMiB   = 2048,
    [int]    $ContextSize     = 4096,
    [int]    $Seed            = 42,
    [int]    $ServerStartSec  = 60,
    [string] $CacheColdPath   = ''
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$scriptDir = $PSScriptRoot
$repoRoot  = (Resolve-Path (Join-Path $scriptDir '..\..')).Path

function Resolve-S38 { param([string]$P) if ([string]::IsNullOrEmpty($P)) { return '' }; if ([System.IO.Path]::IsPathRooted($P)) { return $P }; return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $P)) }
function Test-PortFree { param([int]$P) $l = $null; try { $l = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Parse('127.0.0.1')), $P; $l.Start(); return $true } catch { return $false } finally { if ($l) { $l.Stop() } } }
function Write-S38 { param([string]$Path, [string]$Text) $d = Split-Path -Parent $Path; if ($d -and -not (Test-Path $d)) { [void](New-Item -ItemType Directory -Force -Path $d) }; [System.IO.File]::WriteAllText($Path, $Text, $utf8) }
function ConvertTo-S38Json { param([object]$Value) return ($Value | ConvertTo-Json -Depth 20 -Compress) }
function Get-S38Tokens {
    param([string]$Prompt)
    $tokenizeBody = ConvertTo-S38Json @{ content = $Prompt; add_special = $true; parse_special = $true }
    $tokenizeResp = Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/tokenize" -Method Post -Body $tokenizeBody -ContentType 'application/json' -UseBasicParsing -TimeoutSec 60
    $tokenizeJson = $tokenizeResp.Content | ConvertFrom-Json
    return [pscustomobject]@{ Response = $tokenizeResp; Json = $tokenizeJson; Tokens = @($tokenizeJson.tokens) }
}
function Test-S38StrictTokenPrefix {
    param([object[]]$PrefixTokens, [object[]]$FullTokens)
    if ($PrefixTokens.Count -ge $FullTokens.Count) { return $false }
    for ($i = 0; $i -lt $PrefixTokens.Count; $i++) {
        if ([int64]$PrefixTokens[$i] -ne [int64]$FullTokens[$i]) { return $false }
    }
    return $true
}

if ([string]::IsNullOrEmpty($RunRoot))        { $RunRoot = Join-Path $repoRoot ('.\_test_output\stage38-prefix-restore-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
if ([string]::IsNullOrEmpty($CacheColdPath))  { $CacheColdPath = Join-Path $env:TEMP ('stage38-cold-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
$ModelPath       = Resolve-S38 $ModelPath
$LlamaServerPath = Resolve-S38 $LlamaServerPath
$RunRoot         = Resolve-S38 $RunRoot
$ReportPath      = Resolve-S38 $ReportPath
[void](New-Item -ItemType Directory -Force -Path $RunRoot)
[void](New-Item -ItemType Directory -Force -Path $CacheColdPath)
$chatTemplatePath = Join-Path $RunRoot 'stage38-chatml-template.jinja'
$chatTemplateText = @'
{%- for message in messages -%}
{{ '<|im_start|>' + message.role + '\n' + message.content + '<|im_end|>\n' }}
{%- endfor -%}
{%- if add_generation_prompt -%}
{{ '<|im_start|>assistant\n' }}
{%- endif -%}
'@
Write-S38 $chatTemplatePath $chatTemplateText

# Stale-binary check: llama-server.exe must be newer than 10 minutes ago.
if (-not (Test-Path $LlamaServerPath)) { throw "llama-server.exe not found at: $LlamaServerPath" }
$binItem  = Get-Item $LlamaServerPath
$binAge   = (Get-Date) - $binItem.LastWriteTime
if ($binAge.TotalMinutes -gt 10) { throw "llama-server.exe is stale ($([int]$binAge.TotalMinutes) min old). Run the clean build again." }
if (-not (Test-Path $ModelPath))  { throw "Model fixture not found: $ModelPath" }
if (-not (Test-PortFree $BasePort)) { throw "Port $BasePort is not free." }

# --- Preflight row ---
$rows = [System.Collections.Generic.List[object]]::new()
function Add-Row { param([string]$Id, [string]$Name, [string]$Outcome, [string]$Evidence) $rows.Add([pscustomobject]@{ Id = $Id; Name = $Name; Outcome = $Outcome; Evidence = $Evidence }) }

$gitHead = (& git -C $repoRoot rev-parse HEAD 2>$null)
Add-Row 'setup' 'Clean Release build + fresh binary proof' 'PASS' "bin age $([math]::Round($binAge.TotalMinutes,1)) min; HEAD=$gitHead"

# --- Start hybrid server ---
$serverLog = Join-Path $RunRoot 'server.log'
$serverArgs = @('-m', $ModelPath, '--cache-mode', 'hybrid', '--port', $BasePort, '-c', $ContextSize, '--seed', $Seed, '--cache-ram', $HotBudgetMiB, '--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-path', $CacheColdPath, '--chat-template-file', $chatTemplatePath, '--metrics')
if (Test-Path $serverLog) { Remove-Item $serverLog -Force }
$proc = Start-Process -FilePath $LlamaServerPath -ArgumentList $serverArgs -PassThru -RedirectStandardOutput $serverLog -RedirectStandardError (Join-Path $RunRoot 'server.err.log')

$healthy = $false
$deadline = (Get-Date).AddSeconds($ServerStartSec)
while ((Get-Date) -lt $deadline) {
    try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/health" -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200) { $healthy = $true; break } } catch {}
    Start-Sleep -Seconds 2
}

if (-not $healthy) {
    Add-Row 'setup' 'Server health (/health)' 'BLOCKED' "server did not reach /health within $ServerStartSec s"
    if ($proc -and -not $proc.HasExited) { try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {} }
    return
}

# --- Baseline metrics (hybrid hits before suffix turn) ---
try { $metricsPre = (Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/metrics" -UseBasicParsing).Content } catch { $metricsPre = '' }
function Extract-Metric { param([string]$Text, [string]$Pattern) $m = [regex]::Match($Text, $Pattern); if ($m.Success) { return [double]$m.Groups[1].Value } else { return $null } }
$hybridHitsPre = Extract-Metric $metricsPre 'llamacpp:cache_hits_total\{mode="hybrid"\}\s+(\d+)'

$systemMsg = [ordered]@{ role = 'system'; content = 'You are a concise assistant.' }
$userMsg   = [ordered]@{ role = 'user'; content = 'Summarize the three principles of hydrostatic pressure in three short bullet points.' }
$suffixMsg = [ordered]@{ role = 'user'; content = 'Now give one practical example for the second principle.' }
$baseOptions = [ordered]@{
    max_tokens = 8
    temperature = 0
    seed = 42
    reasoning_format = 'none'
    chat_template_kwargs = @{ enable_thinking = $false }
}
$body1Obj = [ordered]@{
    messages = @($systemMsg, $userMsg)
    max_tokens = $baseOptions.max_tokens
    temperature = $baseOptions.temperature
    seed = $baseOptions.seed
    reasoning_format = $baseOptions.reasoning_format
    chat_template_kwargs = $baseOptions.chat_template_kwargs
}
$body1 = ConvertTo-S38Json $body1Obj

# Turn 1: establish exact entry.
$resp1 = $null
$turn1Json = $null
$actualAssistantMsg = $null
try {
    $resp1 = Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/v1/chat/completions" -Method Post -Body $body1 -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
    $turn1Json = $resp1.Content | ConvertFrom-Json
    $turn1Msg = $turn1Json.choices[0].message
    $assistantContent = [string]$turn1Msg.content
    $actualAssistantMsg = [ordered]@{ role = 'assistant'; content = $assistantContent }
    if ($turn1Msg.PSObject.Properties.Name -contains 'reasoning_content') {
        $actualAssistantMsg.reasoning_content = [string]$turn1Msg.reasoning_content
    } elseif ($baseOptions.chat_template_kwargs.enable_thinking -eq $false) {
        $actualAssistantMsg.reasoning_content = ''
    }
} catch { Add-Row 'turn1' 'Turn 1 establish exact entry' 'FAIL' $_.Exception.Message }

# Turn 2: replay the actual turn 1 assistant message, then append a new user
# turn. This proves strict rendered-token prefix compatibility before cache
# assertions, and avoids synthetic assistant text.
$body2 = ''
if ($actualAssistantMsg) {
    $body2Obj = [ordered]@{
        messages = @($systemMsg, $userMsg, $actualAssistantMsg, $suffixMsg)
        max_tokens = $baseOptions.max_tokens
        temperature = $baseOptions.temperature
        seed = $baseOptions.seed
        reasoning_format = $baseOptions.reasoning_format
        chat_template_kwargs = $baseOptions.chat_template_kwargs
    }
    $body2 = ConvertTo-S38Json $body2Obj
}

$resp2 = $null
$cachedTokens = 0; $promptTokens = 0; $timingsCacheN = $null
$renderedPromptTokenCount = $null
$turn1TemplateResp = $null; $turn1TokenInfo = $null; $prefixTemplateResp = $null; $prefixTokenInfo = $null; $templateResp = $null; $tokenizeResp = $null; $tokenizeJson = $null
$strictPrefixOk = $false; $assistantPrefixOk = $false
$suffixOk = $false; $timingsOk = $false; $fullPromptExactOk = $false; $promptLongerThanPrefix = $false
try {
    if ([string]::IsNullOrEmpty($body2)) { throw 'turn1 assistant message was not available for replay' }

    $turn1TemplateResp = Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/apply-template" -Method Post -Body $body1 -ContentType 'application/json' -UseBasicParsing -TimeoutSec 60
    $turn1Prompt = [string](($turn1TemplateResp.Content | ConvertFrom-Json).prompt)
    $turn1TokenInfo = Get-S38Tokens $turn1Prompt

    $prefixObj = [ordered]@{
        messages = @($systemMsg, $userMsg, $actualAssistantMsg)
        add_generation_prompt = $false
        reasoning_format = $baseOptions.reasoning_format
        chat_template_kwargs = $baseOptions.chat_template_kwargs
    }
    $prefixBody = ConvertTo-S38Json $prefixObj
    $prefixTemplateResp = Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/apply-template" -Method Post -Body $prefixBody -ContentType 'application/json' -UseBasicParsing -TimeoutSec 60
    $prefixPrompt = [string](($prefixTemplateResp.Content | ConvertFrom-Json).prompt)
    $prefixTokenInfo = Get-S38Tokens $prefixPrompt

    $templateResp = Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/apply-template" -Method Post -Body $body2 -ContentType 'application/json' -UseBasicParsing -TimeoutSec 60
    $templateJson = $templateResp.Content | ConvertFrom-Json
    $renderedPrompt = [string]$templateJson.prompt
    $tokenInfo = Get-S38Tokens $renderedPrompt
    $tokenizeResp = $tokenInfo.Response
    $tokenizeJson = $tokenInfo.Json
    $renderedPromptTokenCount = $tokenInfo.Tokens.Count

    $strictPrefixOk = Test-S38StrictTokenPrefix $turn1TokenInfo.Tokens $tokenInfo.Tokens
    $assistantPrefixOk = Test-S38StrictTokenPrefix $prefixTokenInfo.Tokens $tokenInfo.Tokens

    $resp2 = Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/v1/chat/completions" -Method Post -Body $body2 -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
    $j = $resp2.Content | ConvertFrom-Json
    $promptTokens  = $j.usage.prompt_tokens
    $detailCached0 = $null
    if ($j.usage.prompt_tokens_details) { $detailCached0 = $j.usage.prompt_tokens_details.cached_tokens }
    if ($null -ne $detailCached0) { $cachedTokens = [int64]$detailCached0 }
    if ($j.timings -and $null -ne $j.timings.cache_n) { $timingsCacheN = [int64]$j.timings.cache_n }
    $suffixOk = $cachedTokens -gt 0
    $timingsOk = ($null -ne $timingsCacheN) -and ($timingsCacheN -eq $cachedTokens)
    $fullPromptExactOk = ($promptTokens -eq $renderedPromptTokenCount)
    $promptLongerThanPrefix = ($promptTokens -gt $cachedTokens)
} catch { Add-Row 'turn2' 'Turn 2 suffix turn /v1/chat/completions' 'FAIL' $_.Exception.Message }

# --- Post-suffix metrics ---
Start-Sleep -Seconds 1
try { $metricsPost = (Invoke-WebRequest -Uri "http://127.0.0.1:$BasePort/metrics" -UseBasicParsing).Content } catch { $metricsPost = '' }
$hybridHitsPost = Extract-Metric $metricsPost 'llamacpp:cache_hits_total\{mode="hybrid"\}\s+(\d+)'
$prefixAccepted = [regex]::IsMatch($metricsPost, 'llamacpp:cache_prefix_candidates_total\{(?=[^}]*result="accepted")(?=[^}]*reason="accepted_strict_prefix")[^}]*\}\s+[1-9]\d*')
$hitDelta = ($hybridHitsPost - $hybridHitsPre)

# --- Cold-budget gauge row (TP-38-MET-01) ---
$gaugeMatch = [regex]::Match($metricsPost, 'llamacpp:cache_cold_budget_bytes\{mode="hybrid"\}\s+(-?\d+)')
$gaugeOk = $false; $gaugeVal = ''
if ($gaugeMatch.Success) { $gaugeVal = $gaugeMatch.Groups[1].Value; $gaugeOk = ($gaugeVal -eq '2147483648') }

# --- Classify suffix row ---
if ($null -ne $resp2) {
    $prefixEvidence = "turn1_request_tokens=$($turn1TokenInfo.Tokens.Count); assistant_replay_tokens=$($prefixTokenInfo.Tokens.Count); turn2_rendered_tokens=$renderedPromptTokenCount"
    if ($strictPrefixOk -and $assistantPrefixOk) {
        Add-Row 'TP-38-PR-02-prefix-proof' 'Rendered-token strict prefix proof' 'PASS' $prefixEvidence
    } else {
        Add-Row 'TP-38-PR-02-prefix-proof' 'Rendered-token strict prefix proof' 'FAIL' "$prefixEvidence; turn1_prefix=$strictPrefixOk; assistant_replay_prefix=$assistantPrefixOk"
    }

    $suffixEvidence = "cached_tokens=$cachedTokens; timings.cache_n=$timingsCacheN; prompt_tokens=$promptTokens; rendered_request_tokens=$renderedPromptTokenCount"
    if ($strictPrefixOk -and $assistantPrefixOk -and $suffixOk -and $timingsOk -and $fullPromptExactOk -and $promptLongerThanPrefix) {
        Add-Row 'TP-38-PR-02-live' 'Suffix turn cache fields and public prompt total' 'PASS' $suffixEvidence
    } elseif (-not ($strictPrefixOk -and $assistantPrefixOk)) {
        Add-Row 'TP-38-PR-02-live' 'Suffix turn cache fields and public prompt total' 'FAIL' "$suffixEvidence (strict rendered-token prefix proof must pass first)"
    } elseif (-not $suffixOk) {
        Add-Row 'TP-38-PR-02-live' 'Suffix turn cache fields and public prompt total' 'FAIL' "$suffixEvidence (expected cached_tokens > 0)"
    } elseif (-not $timingsOk) {
        Add-Row 'TP-38-PR-02-live' 'Suffix turn cache fields and public prompt total' 'FAIL' "$suffixEvidence (timings.cache_n must equal cached_tokens)"
    } elseif (-not $fullPromptExactOk) {
        Add-Row 'TP-38-PR-02-live' 'Suffix turn cache fields and public prompt total' 'FAIL' "$suffixEvidence (prompt_tokens must equal rendered request token count)"
    } elseif (-not $promptLongerThanPrefix) {
        Add-Row 'TP-38-PR-02-live' 'Suffix turn cache fields and public prompt total' 'FAIL' "$suffixEvidence (prompt_tokens must be greater than cached_tokens)"
    }
}

if ($null -ne $hybridHitsPre -and $null -ne $hybridHitsPost) {
    if ($hitDelta -gt 0) { Add-Row 'TP-38-PR-02-hit' 'Hybrid hit delta positive (suffix turn)' 'PASS' "pre=$hybridHitsPre post=$hybridHitsPost delta=$hitDelta" }
    else { Add-Row 'TP-38-PR-02-hit' 'Hybrid hit delta positive (suffix turn)' 'FAIL' "pre=$hybridHitsPre post=$hybridHitsPost delta=$hitDelta" }
} else { Add-Row 'TP-38-PR-02-hit' 'Hybrid hit delta positive (suffix turn)' 'BLOCKED' "metric not found" }

if ($prefixAccepted) { Add-Row 'TP-38-PR-02-prefix-metric' 'Prefix accepted row present in /metrics' 'PASS' 'accepted row present' }
else { Add-Row 'TP-38-PR-02-prefix-metric' 'Prefix accepted row present in /metrics' 'FAIL' 'no accepted prefix row in metrics snapshot' }

if ($gaugeOk) { Add-Row 'TP-38-MET-01-live' 'Public Prometheus cold-budget gauge 2147483648' 'PASS' $gaugeVal } else { Add-Row 'TP-38-MET-01-live' 'Public Prometheus cold-budget gauge 2147483648' 'FAIL' "got=$gaugeVal" }

# --- Save raw evidence ---
Write-S38 (Join-Path $RunRoot 'metrics-pre.txt')  $metricsPre
Write-S38 (Join-Path $RunRoot 'metrics-post.txt') $metricsPost
Write-S38 (Join-Path $RunRoot 'turn1-request.json') $body1
Write-S38 (Join-Path $RunRoot 'turn2-request.json') $body2
if ($resp1) { Write-S38 (Join-Path $RunRoot 'turn1.json') $resp1.Content }
if ($resp2) { Write-S38 (Join-Path $RunRoot 'turn2.json') $resp2.Content }
if ($turn1TemplateResp) { Write-S38 (Join-Path $RunRoot 'turn1-apply-template.json') $turn1TemplateResp.Content }
if ($turn1TokenInfo) { Write-S38 (Join-Path $RunRoot 'turn1-tokenize.json') (ConvertTo-S38Json $turn1TokenInfo.Json) }
if ($prefixTemplateResp) { Write-S38 (Join-Path $RunRoot 'turn1-assistant-replay-apply-template.json') $prefixTemplateResp.Content }
if ($prefixTokenInfo) { Write-S38 (Join-Path $RunRoot 'turn1-assistant-replay-tokenize.json') (ConvertTo-S38Json $prefixTokenInfo.Json) }
if ($templateResp) { Write-S38 (Join-Path $RunRoot 'turn2-apply-template.json') $templateResp.Content }
if ($tokenizeJson) { Write-S38 (Join-Path $RunRoot 'turn2-tokenize.json') (ConvertTo-S38Json $tokenizeJson) }

# --- Stop server ---
if ($proc -and -not $proc.HasExited) { try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}; Start-Sleep -Seconds 3 }
$portFreeAfter = Test-PortFree $BasePort
if ($portFreeAfter) { Add-Row 'cleanup' 'No server process remains, port free' 'PASS' 'port free after stop' }
else { Add-Row 'cleanup' 'No server process remains, port free' 'BLOCKED' 'port still in use after stop' }

# --- Report ---
$passN  = ($rows | Where-Object Outcome -eq 'PASS').Count
$failN  = ($rows | Where-Object Outcome -eq 'FAIL').Count
$blockN = ($rows | Where-Object Outcome -eq 'BLOCKED').Count
$verdict = if ($failN -gt 0) { 'FAIL' } elseif ($blockN -gt 0) { 'BLOCKED' } else { 'PASS' }

$report = New-Object System.Text.StringBuilder
[void]$report.AppendLine("# Stage 38 prefix-restore and cold-budget evidence")
[void]$report.AppendLine("")
[void]$report.AppendLine("Run: $RunRoot")
[void]$report.AppendLine("Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
[void]$report.AppendLine("HEAD: $gitHead")
[void]$report.AppendLine("Model: $ModelPath")
[void]$report.AppendLine("Cold budget MiB: $ColdBudgetMiB (expected gauge value 2147483648)")
[void]$report.AppendLine("")
[void]$report.AppendLine("## Rows")
[void]$report.AppendLine("")
[void]$report.AppendLine("| Row | Name | Outcome | Evidence |")
[void]$report.AppendLine("| --- | --- | --- | --- |")
foreach ($r in $rows) { [void]$report.AppendLine("| $($r.Id) | $($r.Name) | $($r.Outcome) | $($r.Evidence) |") }
[void]$report.AppendLine("")
[void]$report.AppendLine("## Summary")
[void]$report.AppendLine("")
[void]$report.AppendLine("PASS=$passN FAIL=$failN BLOCKED=$blockN")
[void]$report.AppendLine("Verdict: $verdict")

if ([string]::IsNullOrEmpty($ReportPath) -eq $false) { Write-S38 $ReportPath $report.ToString() }
Write-Output $report.ToString()

if ($verdict -ne 'PASS') { exit 1 }
