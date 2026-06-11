$ErrorActionPreference = "Continue"
$base = "http://127.0.0.1:18113"
$slotPath = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$logFile = "$slotPath\text-server-20260610-02.stderr.log"
$prefix = "E13-14-v2"

$secret = "SECRET-E13-14-DO-NOT-LEAK-XYZ-9999"
$toolArg = "TOOLARG_E13_14_LPAREN_hunter2_RPAREN_DO_NOT_LEAK"
$marker = "MARKER_E13_14_AAAAAAAAAA_DO_NOT_LEAK"

# Mark log section
Add-Content -Path $logFile -Value "===$prefix-RUN-START $((Get-Date).ToString('o'))==="

# 1. Send completion with secret + tool arg + marker in prompt
$body1 = @{
    prompt = "$secret $toolArg $marker"
    n_predict = 4
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
$r1 = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body1 -TimeoutSec 60
$r1 | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-1-completion-response.json"

# 2. Send chat completion with empty messages (boundary-missing)
$body2 = @{
    messages = @()
    max_tokens = 4
    temperature = 0.0
} | ConvertTo-Json -Compress
try {
    $r2 = Invoke-RestMethod -Uri "$base/v1/chat/completions" -Method Post -ContentType "application/json" -Body $body2 -TimeoutSec 60
    $r2 | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-2-chat-empty-response.json"
} catch {
    "chat-empty error: $($_.Exception.Message)" | Out-File "$slotPath\$prefix-2-chat-empty-response.json"
}

# 3. Send chat completion with single empty-content message
$body3 = @{
    messages = @(@{ role = "user"; content = "" })
    max_tokens = 4
    temperature = 0.0
} | ConvertTo-Json -Compress
try {
    $r3 = Invoke-RestMethod -Uri "$base/v1/chat/completions" -Method Post -ContentType "application/json" -Body $body3 -TimeoutSec 60
    $r3 | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-3-chat-blank-content-response.json"
} catch {
    "chat-blank error: $($_.Exception.Message)" | Out-File "$slotPath\$prefix-3-chat-blank-content-response.json"
}

# 4. Send chat completion with secret in user content
$body4 = @{
    messages = @(@{ role = "user"; content = "$secret please process" })
    max_tokens = 4
    temperature = 0.0
} | ConvertTo-Json -Compress
try {
    $r4 = Invoke-RestMethod -Uri "$base/v1/chat/completions" -Method Post -ContentType "application/json" -Body $body4 -TimeoutSec 60
    $r4 | ConvertTo-Json -Depth 6 | Out-File "$slotPath\$prefix-4-chat-secret-response.json"
} catch {
    "chat-secret error: $($_.Exception.Message)" | Out-File "$slotPath\$prefix-4-chat-secret-response.json"
}

# 5. /metrics snapshot
try {
    $m = Invoke-RestMethod -Uri "$base/metrics" -TimeoutSec 30
    $m | Out-File -FilePath "$slotPath\$prefix-5-metrics.txt" -Encoding utf8
} catch {
    "metrics-err: $($_.Exception.Message)" | Out-File "$slotPath\$prefix-5-metrics.txt"
}

Add-Content -Path $logFile -Value "===$prefix-RUN-END $((Get-Date).ToString('o'))==="
Write-Host "$prefix-DONE"
