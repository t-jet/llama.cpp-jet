# E13-01c multimodal probe v3 (Qwen2.5-Omni + video, miss/hit) on omni 18114
$ErrorActionPreference = "Stop"
$root = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$base = "http://127.0.0.1:18114"
$prompt = "Describe this video briefly."

function Send-Video {
    param([string]$Path, [int]$N)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $b64 = [Convert]::ToBase64String($bytes)
    $ext = $Path.Split('.')[-1]
    $body = @{
        prompt = $prompt
        n_predict = 12
        temperature = 0
        cache_prompt = $true
        media_data = @(@{ data = $b64; type = "video/$ext" })
    } | ConvertTo-Json -Depth 8 -Compress
    $reqFile = Join-Path $root "E13-01c-v3-video-$N-request.json"
    $respFile = Join-Path $root "E13-01c-v3-video-$N-response.json"
    $errFile = Join-Path $root "E13-01c-v3-video-$N-error.txt"
    $body | Out-File -FilePath $reqFile -Encoding utf8
    try {
        $r = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 300
        $r | ConvertTo-Json -Depth 6 | Out-File -FilePath $respFile -Encoding utf8
        $tim = $r.timings
        $contentShort = $r.content.Substring(0,[Math]::Min(40,$r.content.Length))
        Write-Host ("E13-01c-v3-video-$N OK prompt_n={0} cache_n={1} tokens_cached={2} id_slot={3} content={4}" -f $tim.prompt_n,$tim.cache_n,$r.tokens_cached,$r.id_slot,$contentShort)
    } catch {
        $msg = $_.Exception.Message
        Write-Host "E13-01c-v3-video-$N ERR $msg"
        if ($_.ErrorDetails) { $_.ErrorDetails.Message | Out-File -FilePath $errFile -Encoding utf8 }
    }
}

Send-Video -Path "D:\source\llama.cpp-jet\.media\sample-5s.mp4" -N 1
Send-Video -Path "D:\source\llama.cpp-jet\.media\sample-5s.mp4" -N 2

try {
    $m = Invoke-RestMethod -Uri "$base/metrics" -TimeoutSec 5
    $m | Out-File -FilePath (Join-Path $root "E13-01c-v3-metrics.txt") -Encoding utf8
    Write-Host "metrics OK"
} catch {
    $_ | Out-File -FilePath (Join-Path $root "E13-01c-v3-metrics-err.txt") -Encoding utf8
}

# Probe route-neutral evidence: server stdout for cache metadata lines
"PROBE-DONE"
