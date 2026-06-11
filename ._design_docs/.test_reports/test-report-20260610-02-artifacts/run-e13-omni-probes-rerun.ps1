$ErrorActionPreference = 'Continue'
$Root = Resolve-Path '.'
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-02-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$Port = 18132
$Base = "http://127.0.0.1:$Port"
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/Qwen2.5-Omni-3B-f16.gguf'
$Mmproj = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/mmproj-Qwen2.5-Omni-3B-f16.gguf'
$MediaPath = Join-Path $Root '.media'
$ServerOut = Join-Path $Art 'omni-rerun-server.out.log'
$ServerErr = Join-Path $Art 'omni-rerun-server.err.log'
$ServerArgs = @('--model', $Model, '--mmproj', $Mmproj, '--media-path', $MediaPath, '--host', '127.0.0.1', '--port', "$Port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
("start=" + (Get-Date -Format o)) | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-probe-timestamps.txt') -Encoding ascii
($ServerExe + ' ' + ($ServerArgs -join ' ')) | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-server-command.txt') -Encoding ascii
$proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru -WindowStyle Hidden
"pid=$($proc.Id)" | Add-Content -LiteralPath (Join-Path $Art 'omni-rerun-probe-timestamps.txt') -Encoding ascii
function Invoke-JsonCapture($row, $url, $bodyObj) {
    $reqPath = Join-Path $Art "$row-request.json"
    $bodyObj | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $reqPath -Encoding ascii
    try {
        $body = Get-Content -Raw -LiteralPath $reqPath
        $res = Invoke-RestMethod -Method Post -Uri $url -ContentType 'application/json' -Body $body -TimeoutSec 600
        $res | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $Art "$row-response.json") -Encoding ascii
        "status=OK" | Set-Content -LiteralPath (Join-Path $Art "$row-status.txt") -Encoding ascii
        return $true
    } catch {
        $_.ToString() | Set-Content -LiteralPath (Join-Path $Art "$row-error.txt") -Encoding ascii
        "status=ERROR" | Set-Content -LiteralPath (Join-Path $Art "$row-status.txt") -Encoding ascii
        return $false
    }
}
function Invoke-CurlMultipart($row, $route) {
    $curl = (Get-Command curl.exe).Source
    $audio = Join-Path $Root '.media/sample-speech-5m.mp3'
    $out = Join-Path $Art "$row-response.json"
    $err = Join-Path $Art "$row-curl.err.txt"
    "curl.exe -sS -X POST $Base$route -F file=@$audio -F model=local -F response_format=json -F max_tokens=8 -F temperature=0" | Set-Content -LiteralPath (Join-Path $Art "$row-command.txt") -Encoding ascii
    & $curl -sS -X POST "$Base$route" -F "file=@$audio" -F "model=local" -F "response_format=json" -F "max_tokens=8" -F "temperature=0" -o $out 2> $err
    $exit = $LASTEXITCODE
    "exit=$exit" | Set-Content -LiteralPath (Join-Path $Art "$row-status.txt") -Encoding ascii
}
$ready = $false
for ($i = 0; $i -lt 240; $i++) {
    if ($proc.HasExited) { break }
    try {
        $health = Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2
        $health | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-health-ready.json') -Encoding ascii
        $ready = $true
        break
    } catch { Start-Sleep -Seconds 2 }
}
"ready=$ready" | Add-Content -LiteralPath (Join-Path $Art 'omni-rerun-probe-timestamps.txt') -Encoding ascii
if (-not $ready) {
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    "server_not_ready" | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-probe-blocked.txt') -Encoding ascii
    exit 2
}
try { Invoke-RestMethod -Method Get -Uri "$Base/props" -TimeoutSec 10 | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-props.json') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-props-error.txt') -Encoding ascii }
try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-metrics-start.txt') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-metrics-start-error.txt') -Encoding ascii }
$video = Join-Path $Root '.media/sample-5s.mp4'
$videoB64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($video))
$mmBody = @{
    messages = @(@{ role = 'user'; content = @(
        @{ type = 'text'; text = 'Describe the media in one short sentence.' },
        @{ type = 'image_url'; image_url = @{ url = "data:video/mp4;base64,$videoB64" } }
    )})
    max_tokens = 8
    temperature = 0
    stream = $false
}
Invoke-JsonCapture 'E13-01c-rerun-chat-1' "$Base/v1/chat/completions" $mmBody | Out-Null
Invoke-JsonCapture 'E13-01c-rerun-chat-2' "$Base/v1/chat/completions" $mmBody | Out-Null
Invoke-CurlMultipart 'E13-07-rerun-v1-audio-transcriptions' '/v1/audio/transcriptions'
Invoke-CurlMultipart 'E13-08-rerun-audio-transcriptions' '/audio/transcriptions'
try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-metrics-end.txt') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'omni-rerun-metrics-end-error.txt') -Encoding ascii }
("end=" + (Get-Date -Format o)) | Add-Content -LiteralPath (Join-Path $Art 'omni-rerun-probe-timestamps.txt') -Encoding ascii
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "stopped=true" | Add-Content -LiteralPath (Join-Path $Art 'omni-rerun-probe-timestamps.txt') -Encoding ascii }
exit 0
