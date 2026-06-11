$ErrorActionPreference = 'Continue'
$Root = Resolve-Path '.'
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-02-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$Port = 18139
$Base = "http://127.0.0.1:$Port"
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/Qwen2.5-Omni-3B-f16.gguf'
$Mmproj = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/mmproj-Qwen2.5-Omni-3B-f16.gguf'
$ServerOut = Join-Path $Art 'audio-alias-first-server.out.log'
$ServerErr = Join-Path $Art 'audio-alias-first-server.err.log'
$ServerArgs = @('--model', $Model, '--mmproj', $Mmproj, '--host', '127.0.0.1', '--port', "$Port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
("start=" + (Get-Date -Format o)) | Set-Content -LiteralPath (Join-Path $Art 'audio-alias-first-timestamps.txt') -Encoding ascii
($ServerExe + ' ' + ($ServerArgs -join ' ')) | Set-Content -LiteralPath (Join-Path $Art 'audio-alias-first-server-command.txt') -Encoding ascii
$proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru -WindowStyle Hidden
"pid=$($proc.Id)" | Add-Content -LiteralPath (Join-Path $Art 'audio-alias-first-timestamps.txt') -Encoding ascii
$ready=$false
for($i=0;$i -lt 240;$i++){ if($proc.HasExited){break}; try{Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2 | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art 'audio-alias-first-health-ready.json') -Encoding ascii; $ready=$true; break}catch{Start-Sleep -Seconds 2}}
"ready=$ready" | Add-Content -LiteralPath (Join-Path $Art 'audio-alias-first-timestamps.txt') -Encoding ascii
if($ready){
  $curl=(Get-Command curl.exe).Source
  $audio=Join-Path $Root '.media/sample-speech-5m.mp3'
  & $curl -sS -X POST "$Base/audio/transcriptions" -F "file=@$audio" -F "model=local" -F "response_format=json" -F "max_tokens=8" -F "temperature=0" -o (Join-Path $Art 'E13-08-audio-alias-first-response.json') 2> (Join-Path $Art 'E13-08-audio-alias-first-curl.err.txt')
  "exit=$LASTEXITCODE" | Set-Content -LiteralPath (Join-Path $Art 'E13-08-audio-alias-first-status.txt') -Encoding ascii
}
("end=" + (Get-Date -Format o)) | Add-Content -LiteralPath (Join-Path $Art 'audio-alias-first-timestamps.txt') -Encoding ascii
if(-not $proc.HasExited){Stop-Process -Id $proc.Id -Force; "stopped=true" | Add-Content -LiteralPath (Join-Path $Art 'audio-alias-first-timestamps.txt')} else {"server_exit=$($proc.ExitCode)" | Add-Content -LiteralPath (Join-Path $Art 'audio-alias-first-timestamps.txt')}
exit 0
