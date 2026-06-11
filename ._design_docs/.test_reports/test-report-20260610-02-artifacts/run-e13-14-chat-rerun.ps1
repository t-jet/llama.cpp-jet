$ErrorActionPreference = 'Continue'
$Root = Resolve-Path '.'
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-02-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$Port = 18137
$Base = "http://127.0.0.1:$Port"
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf'
$ServerOut = Join-Path $Art 'e13-14-chat-server.out.log'
$ServerErr = Join-Path $Art 'e13-14-chat-server.err.log'
$ServerArgs = @('--model', $Model, '--host', '127.0.0.1', '--port', "$Port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '1024', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
("start=" + (Get-Date -Format o)) | Set-Content -LiteralPath (Join-Path $Art 'e13-14-chat-timestamps.txt') -Encoding ascii
($ServerExe + ' ' + ($ServerArgs -join ' ')) | Set-Content -LiteralPath (Join-Path $Art 'e13-14-chat-server-command.txt') -Encoding ascii
$proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru -WindowStyle Hidden
"pid=$($proc.Id)" | Add-Content -LiteralPath (Join-Path $Art 'e13-14-chat-timestamps.txt') -Encoding ascii
function SaveText($name, $text) { $text | Set-Content -LiteralPath (Join-Path $Art $name) -Encoding ascii }
$ready = $false
for ($i=0; $i -lt 180; $i++) { if ($proc.HasExited) { break }; try { Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2 | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art 'e13-14-chat-health-ready.json') -Encoding ascii; $ready=$true; break } catch { Start-Sleep -Seconds 2 } }
"ready=$ready" | Add-Content -LiteralPath (Join-Path $Art 'e13-14-chat-timestamps.txt') -Encoding ascii
if ($ready) {
  $secret = 'STAGE13_SECRET_DO_NOT_LEAK_CHAT tool_arg=password123 path=C:\secret\chat.bin checksum=abcdef rawmedia=bytes'
  $bodyObj = @{ messages = @(@{ role='system'; content='Answer briefly.' }, @{ role='user'; content=$secret }); max_tokens = 2; temperature = 0; stream = $false }
  $bodyObj | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath (Join-Path $Art 'E13-14-chat-degraded-request.json') -Encoding ascii
  try {
    $body = Get-Content -Raw -LiteralPath (Join-Path $Art 'E13-14-chat-degraded-request.json')
    $res = Invoke-RestMethod -Method Post -Uri "$Base/v1/chat/completions" -ContentType 'application/json' -Body $body -TimeoutSec 300
    $res | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $Art 'E13-14-chat-degraded-response.json') -Encoding ascii
    SaveText 'E13-14-chat-degraded-status.txt' 'status=OK'
  } catch { SaveText 'E13-14-chat-degraded-error.txt' $_.ToString(); SaveText 'E13-14-chat-degraded-status.txt' 'status=ERROR' }
  try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'E13-14-chat-metrics-end.txt') -Encoding ascii } catch { SaveText 'E13-14-chat-metrics-end-error.txt' $_.ToString() }
}
("end=" + (Get-Date -Format o)) | Add-Content -LiteralPath (Join-Path $Art 'e13-14-chat-timestamps.txt') -Encoding ascii
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "stopped=true" | Add-Content -LiteralPath (Join-Path $Art 'e13-14-chat-timestamps.txt') -Encoding ascii } else { "server_exit=$($proc.ExitCode)" | Add-Content -LiteralPath (Join-Path $Art 'e13-14-chat-timestamps.txt') -Encoding ascii }
exit 0
