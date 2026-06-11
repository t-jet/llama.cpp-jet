$url = "http://127.0.0.1:18114/v1/audio/transcriptions"
$file = "D:\source\llama.cpp-jet\.media\sample-speech-5m.mp3"
$boundary = [System.Guid]::NewGuid().ToString()
$lf = "`r`n"
$fileBytes = [System.IO.File]::ReadAllBytes($file)
$fileName = Split-Path $file -Leaf
$bodyLines = @(
    "--$boundary",
    "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"",
    "Content-Type: audio/mpeg",
    "",
    ""
)
$bodyStart = ($bodyLines -join $lf) + $lf
$bodyMid = $lf + "--$boundary" + $lf +
    "Content-Disposition: form-data; name=`"model`"" + $lf + $lf + "whisper-1" + $lf +
    "--$boundary" + $lf +
    "Content-Disposition: form-data; name=`"response_format`"" + $lf + $lf + "json" + $lf +
    "--$boundary" + $lf +
    "Content-Disposition: form-data; name=`"temperature`"" + $lf + $lf + "0.0" + $lf +
    "--$boundary--$lf"
$ms = New-Object System.IO.MemoryStream
$sw = New-Object System.IO.StreamWriter($ms, [System.Text.Encoding]::ASCII)
$sw.Write($bodyStart)
$sw.Flush()
$ms.Write($fileBytes, 0, $fileBytes.Length)
$sw = New-Object System.IO.StreamWriter($ms, [System.Text.Encoding]::ASCII)
$sw.Write($bodyMid)
$sw.Flush()
$contentType = "multipart/form-data; boundary=$boundary"
try {
    $r = Invoke-WebRequest -Uri $url -Method Post -ContentType $contentType -Body $ms.ToArray() -TimeoutSec 600 -ErrorAction Stop
    Write-Host "OK status=$($r.StatusCode) len=$($r.Content.Length)"
    $r.Content | Out-File "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\E13-07-v1-audio-transcriptions-response.json"
} catch {
    $msg = $_.Exception.Message
    Write-Host "ERR msg=$msg"
    if ($_.Exception.Response) {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $body = $reader.ReadToEnd()
        $body | Out-File "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260609-05-artifacts\E13-07-v1-audio-transcriptions-body.txt"
        Write-Host "BODY_LEN=$($body.Length)"
    }
}
