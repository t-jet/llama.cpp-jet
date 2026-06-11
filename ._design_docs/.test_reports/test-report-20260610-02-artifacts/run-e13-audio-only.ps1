$ErrorActionPreference = 'Continue'
$Root = Resolve-Path '.'
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-02-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$Port = 18138
$Base = "http://127.0.0.1:$Port"
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/Qwen2.5-Omni-3B-f16.gguf'
$Mmproj = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/mmproj-Qwen2.5-Omni-3B-f16.gguf'
$ServerOut = Join-Path $Art 'audio-only-server.out.log'
$ServerErr = Join-Path $Art 'audio-only-server.err.log'
$ServerArgs = @('--model', $Model, '--mmproj', $Mmproj, '--host', '127.0.0.1', '--port', "$Port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
("start=" + (Get-Date -Format o)) | Set-Content -LiteralPath (Join-Path $Art 'audio-only-timestamps.txt') -Encoding ascii
($ServerExe + ' ' + ($ServerArgs -join ' ')) | Set-Content -LiteralPath (Join-Path $Art 'audio-only-server-command.txt') -Encoding ascii
$proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru -WindowStyle Hidden
"pid=$($proc.Id)" | Add-Content -LiteralPath (Join-Path $Art 'audio-only-timestamps.txt') -Encoding ascii
$ready=$false
for($i=0;$i -lt 240;$i++){ if($proc.HasExited){break}; try{Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2 | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art 'audio-only-health-ready.json') -Encoding ascii; $ready=$true; break}catch{Start-Sleep -Seconds 2}}
"ready=$ready" | Add-Content -LiteralPath (Join-Path $Art 'audio-only-timestamps.txt') -Encoding ascii
if($ready){
  $curl=(Get-Command curl.exe).Source
  $audio=Join-Path $Root '.media/sample-speech-5m.mp3'
  foreach($row in @(@('E13-07-audio-only-v1','/v1/audio/transcriptions'),@('E13-08-audio-only-alias','/audio/transcriptions'))){
    $name=$row[0]; $route=$row[1]
    "curl.exe -sS -X POST $Base$route -F file=@$audio -F model=local -F response_format=json -F max_tokens=8 -F temperature=0" | Set-Content -LiteralPath (Join-Path $Art "$name-command.txt") -Encoding ascii
    & $curl -sS -X POST "$Base$route" -F "file=@$audio" -F "model=local" -F "response_format=json" -F "max_tokens=8" -F "temperature=0" -o (Join-Path $Art "$name-response.json") 2> (Join-Path $Art "$name-curl.err.txt")
    "exit=$LASTEXITCODE" | Set-Content -LiteralPath (Join-Path $Art "$name-status.txt") -Encoding ascii
  }
  try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'audio-only-metrics-end.txt') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'audio-only-metrics-end-error.txt') -Encoding ascii }
}
("end=" + (Get-Date -Format o)) | Add-Content -LiteralPath (Join-Path $Art 'audio-only-timestamps.txt') -Encoding ascii
if(-not $proc.HasExited){Stop-Process -Id $proc.Id -Force; "stopped=true" | Add-Content -LiteralPath (Join-Path $Art 'audio-only-timestamps.txt')} else {"server_exit=$($proc.ExitCode)" | Add-Content -LiteralPath (Join-Path $Art 'audio-only-timestamps.txt')}
exit 0
