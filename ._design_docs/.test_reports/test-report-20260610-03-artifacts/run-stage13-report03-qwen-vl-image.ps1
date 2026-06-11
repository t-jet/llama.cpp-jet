$ErrorActionPreference = 'Continue'
$Root=(Resolve-Path '.').Path
$Art=(Resolve-Path '._design_docs/.test_reports/test-report-20260610-03-artifacts').Path
$env:PATH='D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$ServerExe=Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model=Join-Path $Root '._test_models/Qwen2.5-VL-3B-Instruct-GGUF/Qwen2.5-VL-3B-Instruct-Q6_K.gguf'
$Mmproj=Join-Path $Root '._test_models/Qwen2.5-VL-3B-Instruct-GGUF/mmproj-model-f16.gguf'
$Image=Join-Path $Art 'generated-red-square.jpg'
function SaveText($Name,$Text){$Text|Set-Content -LiteralPath (Join-Path $Art $Name)-Encoding ascii}
function AppendText($Name,$Text){$Text|Add-Content -LiteralPath (Join-Path $Art $Name)-Encoding ascii}
$Port=18241; $Base="http://127.0.0.1:$Port"; $Prefix='e13-01c-qwen-vl-image-marker'
$Args=@('--model',$Model,'--mmproj',$Mmproj,'--host','127.0.0.1','--port',"$Port",'--cache-mode','hybrid','--cache-ram','100','--ctx-size','4096','--parallel','1','--metrics','--slots','--log-verbosity','5','--n-gpu-layers','999')
SaveText "$Prefix-timestamps.txt" ("start="+(Get-Date -Format o)); SaveText "$Prefix-server-command.txt" ($ServerExe+' '+($Args -join ' '))
$proc=Start-Process -FilePath $ServerExe -ArgumentList $Args -RedirectStandardOutput (Join-Path $Art "$Prefix-server.out.log") -RedirectStandardError (Join-Path $Art "$Prefix-server.err.log") -PassThru -WindowStyle Hidden
AppendText "$Prefix-timestamps.txt" "pid=$($proc.Id)"
$ready=$false
for($i=0;$i -lt 240;$i++){ if($proc.HasExited){break}; try{Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2|ConvertTo-Json -Depth 20|Set-Content -LiteralPath (Join-Path $Art "$Prefix-health-ready.json") -Encoding ascii; try{Invoke-RestMethod -Method Get -Uri "$Base/props" -TimeoutSec 10|ConvertTo-Json -Depth 40|Set-Content -LiteralPath (Join-Path $Art "$Prefix-props.json") -Encoding ascii}catch{SaveText "$Prefix-props-error.txt" $_.ToString()}; $ready=$true; break}catch{Start-Sleep -Seconds 2}}
AppendText "$Prefix-timestamps.txt" "ready=$ready"
function Invoke-Native($Row){
  $b64=[Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Image))
  $body=@{prompt=@{prompt_string='What color is the square? <__media__> Answer in one word.'; multimodal_data=@($b64)}; n_predict=4; temperature=0; cache_prompt=$true}
  $req=Join-Path $Art "$Row-request.json"; $body|ConvertTo-Json -Depth 80|Set-Content -LiteralPath $req -Encoding ascii
  try{$res=Invoke-RestMethod -Method Post -Uri "$Base/completion" -ContentType 'application/json' -Body (Get-Content -Raw -LiteralPath $req) -TimeoutSec 900; $res|ConvertTo-Json -Depth 80|Set-Content -LiteralPath (Join-Path $Art "$Row-response.json") -Encoding ascii; SaveText "$Row-status.txt" 'status=OK'}catch{SaveText "$Row-error.txt" $_.ToString(); SaveText "$Row-status.txt" 'status=ERROR'}
}
if($ready){try{Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10|Set-Content -LiteralPath (Join-Path $Art "$Prefix-metrics-start.txt") -Encoding ascii}catch{SaveText "$Prefix-metrics-start-error.txt" $_.ToString()}; Invoke-Native 'E13-01c-qwen-vl-image-marker-1'; Invoke-Native 'E13-01c-qwen-vl-image-marker-2'; try{Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10|Set-Content -LiteralPath (Join-Path $Art "$Prefix-metrics-end.txt") -Encoding ascii}catch{SaveText "$Prefix-metrics-end-error.txt" $_.ToString()}}
AppendText "$Prefix-timestamps.txt" ("end="+(Get-Date -Format o)); if(-not $proc.HasExited){Stop-Process -Id $proc.Id -Force; AppendText "$Prefix-timestamps.txt" 'stopped=true'}else{AppendText "$Prefix-timestamps.txt" "server_exit=$($proc.ExitCode)"}
