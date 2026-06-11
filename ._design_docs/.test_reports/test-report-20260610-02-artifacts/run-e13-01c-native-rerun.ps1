$ErrorActionPreference = 'Continue'
$Root = Resolve-Path '.'
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-02-artifacts').Path
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$Port = 18133
$Base = "http://127.0.0.1:$Port"
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen2.5-VL-3B-Instruct-GGUF/Qwen2.5-VL-3B-Instruct-Q6_K.gguf'
$Mmproj = Join-Path $Root '._test_models/Qwen2.5-VL-3B-Instruct-GGUF/mmproj-model-f16.gguf'
$ServerOut = Join-Path $Art 'e13-01c-native-server.out.log'
$ServerErr = Join-Path $Art 'e13-01c-native-server.err.log'
$ServerArgs = @('--model', $Model, '--mmproj', $Mmproj, '--host', '127.0.0.1', '--port', "$Port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '4096', '--parallel', '1', '--metrics', '--slots', '--log-verbosity', '5', '--n-gpu-layers', '999')
("start=" + (Get-Date -Format o)) | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-native-timestamps.txt') -Encoding ascii
($ServerExe + ' ' + ($ServerArgs -join ' ')) | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-native-server-command.txt') -Encoding ascii
$proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru -WindowStyle Hidden
"pid=$($proc.Id)" | Add-Content -LiteralPath (Join-Path $Art 'e13-01c-native-timestamps.txt') -Encoding ascii
function Invoke-Native($row) {
    $media = Join-Path $Root '.media/sample-5s.mp4'
    $b64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($media))
    $bodyObj = @{ prompt = @{ prompt_string = 'Describe this media in one short sentence.'; multimodal_data = @($b64) }; n_predict = 8; temperature = 0; cache_prompt = $true }
    $reqPath = Join-Path $Art "$row-request.json"
    $bodyObj | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reqPath -Encoding ascii
    try {
        $body = Get-Content -Raw -LiteralPath $reqPath
        $res = Invoke-RestMethod -Method Post -Uri "$Base/completion" -ContentType 'application/json' -Body $body -TimeoutSec 600
        $res | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $Art "$row-response.json") -Encoding ascii
        "status=OK" | Set-Content -LiteralPath (Join-Path $Art "$row-status.txt") -Encoding ascii
    } catch {
        $_.ToString() | Set-Content -LiteralPath (Join-Path $Art "$row-error.txt") -Encoding ascii
        "status=ERROR" | Set-Content -LiteralPath (Join-Path $Art "$row-status.txt") -Encoding ascii
    }
}
$ready = $false
for ($i=0; $i -lt 240; $i++) {
  if ($proc.HasExited) { break }
  try { Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2 | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-native-health-ready.json') -Encoding ascii; $ready=$true; break } catch { Start-Sleep -Seconds 2 }
}
"ready=$ready" | Add-Content -LiteralPath (Join-Path $Art 'e13-01c-native-timestamps.txt') -Encoding ascii
if ($ready) {
  try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-native-metrics-start.txt') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-native-metrics-start-error.txt') -Encoding ascii }
  Invoke-Native 'E13-01c-native-1'
  Invoke-Native 'E13-01c-native-2'
  try { Invoke-RestMethod -Method Get -Uri "$Base/metrics" -TimeoutSec 10 | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-native-metrics-end.txt') -Encoding ascii } catch { $_.ToString() | Set-Content -LiteralPath (Join-Path $Art 'e13-01c-native-metrics-end-error.txt') -Encoding ascii }
}
("end=" + (Get-Date -Format o)) | Add-Content -LiteralPath (Join-Path $Art 'e13-01c-native-timestamps.txt') -Encoding ascii
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "stopped=true" | Add-Content -LiteralPath (Join-Path $Art 'e13-01c-native-timestamps.txt') -Encoding ascii } else { "server_exit=$($proc.ExitCode)" | Add-Content -LiteralPath (Join-Path $Art 'e13-01c-native-timestamps.txt') -Encoding ascii }
exit 0
