$base = "http://127.0.0.1:18113"
$slotPath = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$logFile = "$slotPath\E13-14-server-stderr.log"
$secret = "SECRET-MARKER-DO-NOT-LEAK-7878"
$toolArg = "tool_call(test, args: <password=hunter2>)"

# Truncate server stderr log marker
$marker = "===E13-14-RUN-START $((Get-Date).ToString('o'))==="
$markerLine = $marker
Add-Content -Path $logFile -Value $markerLine

# Bounded degraded fallback probe: empty prompt that should produce a degraded diagnostic
# But not surface prompt text, marker, or tool args in logs.
$body = @{
    prompt = ""
    n_predict = 4
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
try {
    $r = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 60
    $r | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-14-1-empty-prompt.json"
    Write-Host "EMPTY content=$($r.content) timings=$($r.timings | ConvertTo-Json -Compress)"
} catch {
    Write-Host "EMPTY-ERR $($_.Exception.Message)"
}

# Whitespace-only prompt (also degraded)
$body2 = @{
    prompt = "    "
    n_predict = 4
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
try {
    $r2 = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body2 -TimeoutSec 60
    $r2 | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-14-2-ws-prompt.json"
    Write-Host "WS content=$($r2.content)"
} catch {
    Write-Host "WS-ERR $($_.Exception.Message)"
}

# Degraded request with a secret token that must NOT leak in logs
$body3 = @{
    prompt = $secret
    n_predict = 4
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
try {
    $r3 = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body3 -TimeoutSec 60
    $r3 | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-14-3-secret-prompt.json"
    Write-Host "SECRET content=$($r3.content)"
} catch {
    Write-Host "SECRET-ERR $($_.Exception.Message)"
}

# Tool args + path probe (must not appear in logs)
$body4 = @{
    prompt = $toolArg
    n_predict = 4
    temperature = 0.0
    cache_prompt = $true
} | ConvertTo-Json -Compress
try {
    $r4 = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body4 -TimeoutSec 60
    $r4 | ConvertTo-Json -Depth 6 | Out-File "$slotPath\E13-14-4-tool-arg-prompt.json"
    Write-Host "TOOLARG content=$($r4.content)"
} catch {
    Write-Host "TOOLARG-ERR $($_.Exception.Message)"
}

# /metrics snapshot
try {
    $m = Invoke-RestMethod -Uri "$base/metrics" -TimeoutSec 30
    $m | Out-File -FilePath "$slotPath\E13-14-5-metrics.txt" -Encoding utf8
} catch {
    Write-Host "METRICS-ERR $($_.Exception.Message)"
}

Add-Content -Path $logFile -Value "===E13-14-RUN-END $((Get-Date).ToString('o'))==="
Write-Host "E13-14-OK"
