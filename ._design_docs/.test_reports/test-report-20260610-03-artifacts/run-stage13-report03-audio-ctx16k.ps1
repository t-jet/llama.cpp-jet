$ErrorActionPreference = 'Continue'
$Root = (Resolve-Path '.').Path
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-03-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/Qwen2.5-Omni-3B-f16.gguf'
$Mmproj = Join-Path $Root '._test_models/Qwen2.5-Omni-3B-GGUF/mmproj-Qwen2.5-Omni-3B-f16.gguf'
$Audio = Join-Path $Root '.media/sample-speech-5m.mp3'
function SaveText($Name, $Text) { $Text | Set-Content -LiteralPath (Join-Path $Art $Name) -Encoding ascii }
function AppendText($Name, $Text) { $Text | Add-Content -LiteralPath (Join-Path $Art $Name) -Encoding ascii }
function Start-Server($Prefix, $Port) {
  $args = @('--model',$Model,'--mmproj',$Mmproj,'--host','127.0.0.1','--port',"$Port",'--cache-mode','hybrid','--cache-ram','100','--ctx-size','16384','--parallel','1','--metrics','--slots','--log-verbosity','5','--n-gpu-layers','999')
  SaveText "$Prefix-timestamps.txt" ("start=" + (Get-Date -Format o))
  SaveText "$Prefix-server-command.txt" ($ServerExe + ' ' + ($args -join ' '))
  $proc = Start-Process -FilePath $ServerExe -ArgumentList $args -RedirectStandardOutput (Join-Path $Art "$Prefix-server.out.log") -RedirectStandardError (Join-Path $Art "$Prefix-server.err.log") -PassThru -WindowStyle Hidden
  AppendText "$Prefix-timestamps.txt" "pid=$($proc.Id)"
  $base = "http://127.0.0.1:$Port"
  $ready = $false
  for ($i=0; $i -lt 240; $i++) { if ($proc.HasExited) { break }; try { Invoke-RestMethod -Method Get -Uri "$base/health" -TimeoutSec 2 | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art "$Prefix-health-ready.json") -Encoding ascii; $ready=$true; break } catch { Start-Sleep -Seconds 2 } }
  AppendText "$Prefix-timestamps.txt" "ready=$ready"
  return @{Proc=$proc; Base=$base; Prefix=$Prefix; Ready=$ready}
}
function Stop-Server($State) { AppendText "$($State.Prefix)-timestamps.txt" ("end=" + (Get-Date -Format o)); if (-not $State.Proc.HasExited) { Stop-Process -Id $State.Proc.Id -Force; AppendText "$($State.Prefix)-timestamps.txt" 'stopped=true' } else { AppendText "$($State.Prefix)-timestamps.txt" "server_exit=$($State.Proc.ExitCode)" } }
function Invoke-Audio($State, $Route, $Row) {
  $curl=(Get-Command curl.exe).Source
  SaveText "$Row-command.txt" "curl.exe -sS -X POST $($State.Base)$Route -F file=@$Audio -F model=local -F response_format=json -F max_tokens=8 -F temperature=0"
  & $curl -sS -X POST "$($State.Base)$Route" -F "file=@$Audio" -F "model=local" -F "response_format=json" -F "max_tokens=8" -F "temperature=0" -o (Join-Path $Art "$Row-response.json") 2> (Join-Path $Art "$Row-curl.err.txt")
  SaveText "$Row-status.txt" "exit=$LASTEXITCODE"
  try { Invoke-RestMethod -Method Get -Uri "$($State.Base)/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art "$Row-metrics-end.txt") -Encoding ascii } catch { SaveText "$Row-metrics-end-error.txt" $_.ToString() }
}
$s=Start-Server 'e13-07-omni-v1-audio-ctx16k' 18242
if($s.Ready){Invoke-Audio $s '/v1/audio/transcriptions' 'E13-07-v1-audio-transcriptions-ctx16k'}
Stop-Server $s
$s=Start-Server 'e13-08-omni-alias-audio-ctx16k' 18243
if($s.Ready){Invoke-Audio $s '/audio/transcriptions' 'E13-08-audio-transcriptions-alias-ctx16k'}
Stop-Server $s
