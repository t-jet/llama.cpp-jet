# E13-08: POST /audio/transcriptions alias probe
# Same contract as E13-07 but on the non-/v1 alias route
# Uses $ServerArgs to avoid PowerShell automatic variable collision
$ErrorActionPreference = "Stop"
$root = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\E13-08"
$base = "http://127.0.0.1:18114"
$file = "D:\source\llama.cpp-jet\.media\sample-speech-5m.mp3"

$boundary = "----E13Boundary" + (Get-Random)
$LF = "`r`n"
$fileBytes = [System.IO.File]::ReadAllBytes($file)
$fileEnc = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetString($fileBytes)
$body = "--$boundary$LF" +
    "Content-Disposition: form-data; name=`"file`"; filename=`"sample-speech-5m.mp3`"$LF" +
    "Content-Type: audio/mpeg$LF$LF" +
    $fileEnc + $LF +
    "--$boundary$LF" +
    "Content-Disposition: form-data; name=`"model`"$LF$LF" +
    "whisper-1$LF" +
    "--$boundary$LF" +
    "Content-Disposition: form-data; name=`"response_format`"$LF$LF" +
    "json$LF" +
    "--$boundary--$LF"
$bodyBytes = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($body)
[System.IO.File]::WriteAllBytes("$root\request.bin", $bodyBytes)

# 1) Route inventory probe
try {
    $r = Invoke-WebRequest -Uri "$base/v1/audio/transcriptions" -Method Options -TimeoutSec 5 -ErrorAction Stop
    "options-v1 status=$($r.StatusCode)" | Out-File "$root\route-inventory.txt" -Encoding utf8
} catch { "" | Out-File "$root\route-inventory.txt" -Encoding utf8 }

# 2) Main E13-08 alias probe
try {
    $r = Invoke-WebRequest -Uri "$base/audio/transcriptions" -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes -TimeoutSec 300 -UseBasicParsing
    [void]$r.Content | Out-File -FilePath "$root\response.json" -Encoding utf8 -NoNewline
    $r.Content | Out-File -FilePath "$root\response.json" -Encoding utf8
    "status=$($r.StatusCode) len=$($r.Content.Length)" | Out-File "$root\status.txt" -Encoding utf8
} catch {
    $msg = $_.Exception.Message
    $msg | Out-File -FilePath "$root\error.txt" -Encoding utf8
    if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
        $_.ErrorDetails.Message | Out-File -FilePath "$root\error-body.txt" -Encoding utf8
    } else {
        "no-error-details" | Out-File -FilePath "$root\error-body.txt" -Encoding utf8
    }
    "exception: $msg" | Out-File -FilePath "$root\status.txt" -Encoding utf8
}

# 3) Health re-check to detect server crash
try {
    $h = Invoke-RestMethod -Uri "$base/health" -TimeoutSec 3 -ErrorAction Stop
    $h | ConvertTo-Json | Out-File "$root\health-after.json" -Encoding utf8
} catch {
    "server-down: $($_.Exception.Message)" | Out-File "$root\health-after.json" -Encoding utf8
}

# 4) Metrics snapshot
try {
    $m = Invoke-RestMethod -Uri "$base/metrics" -TimeoutSec 5
    $m | Out-File "$root\metrics.txt" -Encoding utf8
} catch {
    "" | Out-File "$root\metrics.txt" -Encoding utf8
}

"PROBE-DONE"
