$ErrorActionPreference = 'Continue'
$Root = Resolve-Path '.'
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-02-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$Port = 18131
$Base = "http://127.0.0.1:$Port"
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/Qwen2.5-Omni-3B-f16.gguf'
$Mmproj = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/mmproj-Qwen2.5-Omni-3B-f16.gguf'
$MediaPath = Join-Path $Root '.media'
$ServerOut = Join-Path $Art 'omni-server.out.log'
$ServerErr = Join-Path $Art 'omni-server.err.log'
$ServerArgs = @('--model', $Model, '--mmproj', $Mmproj, '--media-path', $MediaPath, '--host', '127.0.0.1', '--port', "$Port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
("start=" + (Get-Date -Format o)) | Set-Content -LiteralPath (Join-Path $Art 'omni-probe-timestamps.txt') -Encoding ascii
($ServerExe + ' ' + ($ServerArgs -join ' ')) | Set-Content -LiteralPath (Join-Path $Art 'omni-server-command.txt') -Encoding ascii
$proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru -WindowStyle Hidden
"pid=$($proc.Id)" | Add-Content -LiteralPath (Join-Path $Art 'omni-probe-timestamps.txt') -Encoding ascii
function Write-Json($name, $obj) { $obj | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath (Join-Path $Art $name) -Encoding ascii }
function Save-Text($name, $text) { $text | Set-Content -LiteralPath (Join-Path $Art $name) -Encoding ascii }
function Invoke-Capture($row, $method, $url, $bodyObj, $headers) {
    $reqPath = Join-Path $Art "$row-request.json"
    if ($null -ne $bodyObj) { $bodyObj | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $reqPath -Encoding ascii }
    try {
        if ($null -ne $bodyObj) {
            $body = Get-Content -Raw -LiteralPath $reqPath
            $res = Invoke-RestMethod -Method $method -Uri $url -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 240
        } else {
            $res = Invoke-RestMethod -Method $method -Uri $url -TimeoutSec 240
        }
        $res | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $Art "$row-response.json") -Encoding ascii
        "status=OK" | Set-Content -LiteralPath (Join-Path $Art "$row-status.txt") -Encoding ascii
        return $true
    } catch {
        $_.ToString() | Set-Content -LiteralPath (Join-Path $Art "$row-error.txt") -Encoding ascii
        "status=ERROR" | Set-Content -LiteralPath (Join-Path $Art "$row-status.txt") -Encoding ascii
        return $false
    }
}
$ready = $false
for ($i = 0; $i -lt 240; $i++) {
    if ($proc.HasExited) { break }
    try {
        $health = Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2
        $health | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art 'omni-health-ready.json') -Encoding ascii
        $ready = $true
        break
    } catch { Start-Sleep -Seconds 2 }
}
"ready=$ready" | Add-Content -LiteralPath (Join-Path $Art 'omni-probe-timestamps.txt') -Encoding ascii
if (-not $ready) {
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    "server_not_ready" | Set-Content -LiteralPath (Join-Path $Art 'omni-probe-blocked.txt') -Encoding ascii
    exit 2
}
try { Invoke-RestMethod -Method Get -Uri "$Base/props" -TimeoutSec 10 | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath (Join-Path $Art 'omni-props.json') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'omni-props-error.txt') -Encoding ascii }
try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'omni-metrics-start.txt') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'omni-metrics-start-error.txt') -Encoding ascii }
$imageBody = @{
    messages = @(@{ role = 'user'; content = @(
        @{ type = 'text'; text = 'In one short sentence, describe the visible content.' },
        @{ type = 'image_url'; image_url = @{ url = 'sample-15s-360p.mp4' } }
    )})
    max_tokens = 8
    temperature = 0
    stream = $false
}
Invoke-Capture 'E13-01c-chat-1' 'Post' "$Base/v1/chat/completions" $imageBody @{} | Out-Null
Invoke-Capture 'E13-01c-chat-2' 'Post' "$Base/v1/chat/completions" $imageBody @{} | Out-Null
$audioMp3 = Join-Path $Root '.media/sample-speech-5m.mp3'
$audioBytes = [System.IO.File]::ReadAllBytes($audioMp3)
$audioB64 = [Convert]::ToBase64String($audioBytes)
$audioBody = @{ file = $audioB64; filename = 'sample-speech-5m.mp3'; model = 'local'; response_format = 'json' }
Invoke-Capture 'E13-07-v1-audio-transcriptions' 'Post' "$Base/v1/audio/transcriptions" $audioBody @{} | Out-Null
Invoke-Capture 'E13-08-audio-transcriptions' 'Post' "$Base/audio/transcriptions" $audioBody @{} | Out-Null
try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'omni-metrics-end.txt') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'omni-metrics-end-error.txt') -Encoding ascii }
("end=" + (Get-Date -Format o)) | Add-Content -LiteralPath (Join-Path $Art 'omni-probe-timestamps.txt') -Encoding ascii
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "stopped=true" | Add-Content -LiteralPath (Join-Path $Art 'omni-probe-timestamps.txt') -Encoding ascii }
exit 0
