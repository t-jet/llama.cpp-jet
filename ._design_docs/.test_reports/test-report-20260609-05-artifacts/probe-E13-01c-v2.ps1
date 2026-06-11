# E13-01c multimodal probe v2 (Qwen2.5-Omni + video, miss/hit)
$ErrorActionPreference = "Stop"
$root = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$base = "http://127.0.0.1:18114"
$prompt = "Describe this video briefly."

function Send-Video {
    param([string]$Path, [int]$N, [int]$Seed)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $b64 = [Convert]::ToBase64String($bytes)
    $ext = $Path.Split('.')[-1]
    $body = @{
        prompt = $prompt
        n_predict = 16
        temperature = 0
        cache_prompt = $true
        media_data = @(@{ data = $b64; type = "video/$ext" })
    } | ConvertTo-Json -Depth 8 -Compress
    $reqFile = Join-Path $root "E13-01c-video-$N-request.json"
    $respFile = Join-Path $root "E13-01c-video-$N-response.json"
    $errFile = Join-Path $root "E13-01c-video-$N-error.txt"
    $body | Out-File -FilePath $reqFile -Encoding utf8
    try {
        $r = Invoke-RestMethod -Uri "$base/completion" -Method Post -ContentType "application/json" -Body $body -TimeoutSec 180
        $r | ConvertTo-Json -Depth 6 | Out-File -FilePath $respFile -Encoding utf8
        $tim = $r.timings
        Write-Host ("E13-01c-video-$N OK prompt_n={0} cache_n={1} tokens_cached={2} id_slot={3} content={4}" -f $tim.prompt_n,$tim.cache_n,$r.tokens_cached,$r.id_slot,$r.content.Substring(0,[Math]::Min(40,$r.content.Length)))
    } catch {
        $msg = $_.Exception.Message
        Write-Host "E13-01c-video-$N ERR $msg"
        if ($_.ErrorDetails) { $_.ErrorDetails.Message | Out-File -FilePath $errFile -Encoding utf8 }
    }
}

# Run two consecutive calls with same fixture
Send-Video -Path "D:\source\llama.cpp-jet\.media\sample-5s.mp4" -N 1
Send-Video -Path "D:\source\llama.cpp-jet\.media\sample-5s.mp4" -N 2

# Now also test /v1/chat/completions OpenAI image_url format
$bytes = [IO.File]::ReadAllBytes("D:\source\llama.cpp-jet\.media\sample-5s.mp4")
$b64 = [Convert]::ToBase64String($bytes)
$oaiBody = @{
    model = "Qwen2.5-Omni-3B-f16.gguf"
    messages = @(@{
        role = "user"
        content = @(
            @{ type = "text"; text = $prompt }
            @{ type = "video_url"; video_url = @{ url = "data:video/mp4;base64,$b64" } }
        )
    })
    max_tokens = 16
    temperature = 0
} | ConvertTo-Json -Depth 10 -Compress
$oaiBody | Out-File -FilePath (Join-Path $root "E13-01c-oai-video-1-request.json") -Encoding utf8
try {
    $r2 = Invoke-RestMethod -Uri "$base/v1/chat/completions" -Method Post -ContentType "application/json" -Body $oaiBody -TimeoutSec 180
    $r2 | ConvertTo-Json -Depth 8 | Out-File -FilePath (Join-Path $root "E13-01c-oai-video-1-response.json") -Encoding utf8
    $msg = $r2.choices[0].message
    Write-Host ("E13-01c-oai-video-1 OK content={0}" -f $msg.content.Substring(0,[Math]::Min(40,$msg.content.Length)))
} catch {
    $_.Exception.Message | Out-File -FilePath (Join-Path $root "E13-01c-oai-video-1-error.txt") -Encoding utf8
    Write-Host "E13-01c-oai-video-1 ERR $($_.Exception.Message)"
}

# Metrics
try {
    Invoke-RestMethod -Uri "$base/metrics" -TimeoutSec 5 | Out-File -FilePath (Join-Path $root "E13-01c-metrics.txt") -Encoding utf8
} catch { $_ | Out-File -FilePath (Join-Path $root "E13-01c-metrics-err.txt") -Encoding utf8 }
"PROBE-DONE"
