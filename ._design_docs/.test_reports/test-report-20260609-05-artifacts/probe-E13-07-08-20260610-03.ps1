# E13-07 + E13-08 audio transcriptions probe v3 on omni 18114
$ErrorActionPreference = "Stop"
$root = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$base = "http://127.0.0.1:18114"

function Send-Transcription {
    param([string]$Route, [string]$Label, [int]$N)
    $path = "D:\source\llama.cpp-jet\.media\sample-speech-5m.mp3"
    $boundary = "----E13Boundary" + (Get-Random)
    $LF = "`r`n"
    $fileBytes = [IO.File]::ReadAllBytes($path)
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
    $reqFile = Join-Path $root "$Label-$N-request.bin"
    $respFile = Join-Path $root "$Label-$N-response.json"
    $errFile = Join-Path $root "$Label-$N-error.txt"
    [IO.File]::WriteAllBytes($reqFile, $bodyBytes)
    try {
        $r = Invoke-WebRequest -Uri "$base$Route" -Method Post -ContentType "multipart/form-data; boundary=$boundary" -Body $bodyBytes -TimeoutSec 300 -UseBasicParsing
        $r.Content | Out-File -FilePath $respFile -Encoding utf8
        Write-Host "$Label-$N OK status=$($r.StatusCode) content=$($r.Content.Substring(0,[Math]::Min(120,$r.Content.Length)))"
    } catch {
        $msg = $_.Exception.Message
        Write-Host "$Label-$N ERR $msg"
        $errOut = $msg
        if ($_.ErrorDetails) { $errOut += "`n---DETAILS---`n" + $_.ErrorDetails.Message }
        $errOut | Out-File -FilePath $errFile -Encoding utf8
    }
}

# E13-07: /v1/audio/transcriptions
Send-Transcription -Route "/v1/audio/transcriptions" -Label "E13-07-v3-v1-audio" -N 1
# E13-08: /audio/transcriptions alias (run only if first call did not crash server)
try { $h = Invoke-RestMethod -Uri "$base/health" -TimeoutSec 3 -ErrorAction Stop } catch { $h = $null }
if ($h -and $h.status -eq "ok") {
    Send-Transcription -Route "/audio/transcriptions" -Label "E13-08-v3-alias-audio" -N 1
} else {
    Write-Host "OMNI-SERVER-DOWN-SKIP-ALIAS"
    "OMNI-SERVER-DOWN" | Out-File -FilePath (Join-Path $root "E13-08-v3-alias-skipped.txt") -Encoding utf8
}

try {
    $m = Invoke-RestMethod -Uri "$base/metrics" -TimeoutSec 5
    $m | Out-File -FilePath (Join-Path $root "E13-07-08-v3-metrics.txt") -Encoding utf8
} catch {
    $_ | Out-File -FilePath (Join-Path $root "E13-07-08-v3-metrics-err.txt") -Encoding utf8
}

"PROBE-DONE"
