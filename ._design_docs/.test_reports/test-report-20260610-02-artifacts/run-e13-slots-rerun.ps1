$ErrorActionPreference = 'Continue'
$Root = Resolve-Path '.'
$Art = (Resolve-Path '._design_docs/.test_reports/test-report-20260610-02-artifacts').Path
$SaveDir = Join-Path $Art 'slot-save-dir'
New-Item -ItemType Directory -Force -Path $SaveDir | Out-Null
$env:PATH = 'D:\app\cuda_13_2\bin\x64;D:\app\cuda_13_2\bin;' + $env:PATH
$Port = 18136
$Base = "http://127.0.0.1:$Port"
$ServerExe = Join-Path $Root 'build-cuda-stage13/bin/Release/llama-server.exe'
$Model = Join-Path $Root '._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf'
$ServerOut = Join-Path $Art 'slots-rerun-server.out.log'
$ServerErr = Join-Path $Art 'slots-rerun-server.err.log'
$ServerArgs = @('--model', $Model, '--host', '127.0.0.1', '--port', "$Port", '--cache-mode', 'hybrid', '--cache-ram', '100', '--ctx-size', '1024', '--parallel', '1', '--metrics', '--slots', '--slot-save-path', $SaveDir, '--log-verbosity', '5', '--n-gpu-layers', '999')
("start=" + (Get-Date -Format o)) | Set-Content -LiteralPath (Join-Path $Art 'slots-rerun-timestamps.txt') -Encoding ascii
($ServerExe + ' ' + ($ServerArgs -join ' ')) | Set-Content -LiteralPath (Join-Path $Art 'slots-rerun-server-command.txt') -Encoding ascii
$proc = Start-Process -FilePath $ServerExe -ArgumentList $ServerArgs -RedirectStandardOutput $ServerOut -RedirectStandardError $ServerErr -PassThru -WindowStyle Hidden
"pid=$($proc.Id)" | Add-Content -LiteralPath (Join-Path $Art 'slots-rerun-timestamps.txt') -Encoding ascii
function SaveJson($name, $obj) { $obj | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath (Join-Path $Art $name) -Encoding ascii }
function SaveText($name, $text) { $text | Set-Content -LiteralPath (Join-Path $Art $name) -Encoding ascii }
function JsonPost($row, $route, $bodyObj) {
    $reqPath = Join-Path $Art "$row-request.json"
    $bodyObj | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $reqPath -Encoding ascii
    try {
        $body = Get-Content -Raw -LiteralPath $reqPath
        $res = Invoke-RestMethod -Method Post -Uri "$Base$route" -ContentType 'application/json' -Body $body -TimeoutSec 300
        SaveJson "$row-response.json" $res
        SaveText "$row-status.txt" 'status=OK'
    } catch { SaveText "$row-error.txt" $_.ToString(); SaveText "$row-status.txt" 'status=ERROR' }
}
function GetCapture($row, $route) {
    try { $res = Invoke-RestMethod -Method Get -Uri "$Base$route" -TimeoutSec 30; SaveJson "$row-response.json" $res; SaveText "$row-status.txt" 'status=OK' }
    catch { SaveText "$row-error.txt" $_.ToString(); SaveText "$row-status.txt" 'status=ERROR' }
}
$ready = $false
for ($i=0; $i -lt 180; $i++) { if ($proc.HasExited) { break }; try { Invoke-RestMethod -Method Get -Uri "$Base/health" -TimeoutSec 2 | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $Art 'slots-rerun-health-ready.json') -Encoding ascii; $ready=$true; break } catch { Start-Sleep -Seconds 2 } }
"ready=$ready" | Add-Content -LiteralPath (Join-Path $Art 'slots-rerun-timestamps.txt') -Encoding ascii
if ($ready) {
  GetCapture 'E13-10-rerun-slots-before' '/slots'
  JsonPost 'E13-10-rerun-seed-completion' '/completion' @{ prompt = 'Slots save restore erase CUDA Stage 13 seed.'; n_predict = 4; temperature = 0; id_slot = 0; cache_prompt = $true }
  GetCapture 'E13-10-rerun-slots-after-seed' '/slots'
  JsonPost 'E13-10-rerun-slots-save' '/slots/0?action=save' @{ filename = 'stage13-e13-10.slot' }
  JsonPost 'E13-10-rerun-slots-restore' '/slots/0?action=restore' @{ filename = 'stage13-e13-10.slot' }
  JsonPost 'E13-10-rerun-slots-erase' '/slots/0?action=erase' @{}
  GetCapture 'E13-10-rerun-slots-after-erase' '/slots'
}
("end=" + (Get-Date -Format o)) | Add-Content -LiteralPath (Join-Path $Art 'slots-rerun-timestamps.txt') -Encoding ascii
if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force; "stopped=true" | Add-Content -LiteralPath (Join-Path $Art 'slots-rerun-timestamps.txt') -Encoding ascii } else { "server_exit=$($proc.ExitCode)" | Add-Content -LiteralPath (Join-Path $Art 'slots-rerun-timestamps.txt') -Encoding ascii }
exit 0
