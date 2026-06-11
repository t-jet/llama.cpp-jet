# E13-07 + E13-08 audio transcriptions probe
$ErrorActionPreference = "Stop"
$root = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts"
$base = "http://127.0.0.1:18115"

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
        Write-Host "$Label-$N OK status=$($r.StatusCode) content=$($r.Content.Substring(0,[Math]::Min(80,$r.Content.Length)))"
    } catch {
        $msg = $_.Exception.Message
        Write-Host "$Label-$N ERR $msg"
        if ($_.ErrorDetails) { $_.ErrorDetails.Message | Out-File -FilePath $errFile -Encoding utf8 }
        if ($_.Exception.Response) {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $errBody = $reader.ReadToEnd()
            $errBody | Out-File -FilePath $errFile -Append -Encoding utf8
        }
    }
}

# E13-07: /v1/audio/transcriptions
Send-Transcription -Route "/v1/audio/transcriptions" -Label "E13-07-v1-audio" -N 1
Send-Transcription -Route "/v1/audio/transcriptions" -Label "E13-07-v1-audio" -N 2
# E13-08: /audio/transcriptions alias
Send-Transcription -Route "/audio/transcriptions" -Label "E13-08-alias-audio" -N 1
Send-Transcription -Route "/audio/transcriptions" -Label "E13-08-alias-audio" -N 2

# Metrics
try {
    Invoke-RestMethod -Uri "$base/metrics" -TimeoutSec 5 | Out-File -FilePath (Join-Path $root "E13-07-08-metrics.txt") -Encoding utf8
} catch { $_ | Out-File -FilePath (Join-Path $root "E13-07-08-metrics-err.txt") -Encoding utf8 }
"PROBE-DONE"
