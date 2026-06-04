# mtp-attempt1.ps1 — Attempt 1: Full draft-mtp configuration with explicit cache mode
# Includes --metrics (required to read the rows we are testing for)
$ErrorActionPreference = 'Continue'
$model = 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf'
$port = 8186
$logDir = 'D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-05-artifacts'
$coldPath = 'D:\source\llama.cpp-jet\tmp\mtp-cold-1'
$serverLog = Join-Path $logDir 'mtp-attempt1-server.log'
$serverErr = Join-Path $logDir 'mtp-attempt1-server.log.err'

if (Test-Path $coldPath) { Remove-Item -Recurse -Force $coldPath }
New-Item -ItemType Directory -Path $coldPath -Force | Out-Null

$proc = Start-Process -FilePath 'D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe' `
  -ArgumentList @('-m', $model, '--port', $port, '--host', '127.0.0.1', '-ngl', '99', '-c', '8192', '-np', '1', '--cache-mode', 'hybrid', '--cache-ram', '512', '--spec-type', 'draft-mtp', '--cache-cold-path', $coldPath, '--metrics') `
  -RedirectStandardOutput $serverLog -RedirectStandardError $serverErr -PassThru -NoNewWindow

Write-Host "Started server pid=$($proc.Id)"

$ready = $false
for ($i = 0; $i -lt 120; $i++) {
  Start-Sleep -Seconds 2
  try {
    $h = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 5
    if ($h.status -eq 'ok') { $ready = $true; Write-Host "Server ready after $((($i+1)*2))s"; break }
  } catch { }
}
if (-not $ready) {
  Write-Host "Server did not become ready"
  Get-Content $serverLog -Tail 30
  Get-Content $serverErr -Tail 30
  Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  exit 1
}

try {
  $beforeMetrics = Invoke-RestMethod -Uri "http://127.0.0.1:$port/metrics" -TimeoutSec 10
  ($beforeMetrics -join "`n") | Out-File -FilePath (Join-Path $logDir 'mtp-attempt1-metrics-before.txt')
  Write-Host "Before /metrics captured: $((($beforeMetrics -join "`n") | Measure-Object -Line).Lines) lines"
} catch {
  Write-Host "Failed to capture before metrics: $_"
}

$prompt = "The quick brown fox jumps over the lazy dog. " * 200
$body1 = @{ prompt = $prompt; n_predict = 32; cache_prompt = $true; n_probs = 1; slot_id = 0; temperature = 0.0; seed = 42 } | ConvertTo-Json -Depth 5
try {
  $resp1 = Invoke-RestMethod -Uri "http://127.0.0.1:$port/completion" -Method Post -Body $body1 -ContentType 'application/json' -TimeoutSec 180
  $resp1 | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $logDir 'mtp-attempt1-completion-1.json')
  Write-Host "Completion 1 OK"
} catch {
  Write-Host "Completion 1 failed: $_"
  $_ | Out-File -FilePath (Join-Path $logDir 'mtp-attempt1-completion-1.error')
}

Start-Sleep -Seconds 3

$body2 = @{ prompt = $prompt; n_predict = 64; cache_prompt = $true; n_probs = 1; slot_id = 0; temperature = 0.0; seed = 43 } | ConvertTo-Json -Depth 5
try {
  $resp2 = Invoke-RestMethod -Uri "http://127.0.0.1:$port/completion" -Method Post -Body $body2 -ContentType 'application/json' -TimeoutSec 180
  $resp2 | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $logDir 'mtp-attempt1-completion-2.json')
  Write-Host "Completion 2 OK"
} catch {
  Write-Host "Completion 2 failed: $_"
}

try {
  $afterMetrics = Invoke-RestMethod -Uri "http://127.0.0.1:$port/metrics" -TimeoutSec 10
  ($afterMetrics -join "`n") | Out-File -FilePath (Join-Path $logDir 'mtp-attempt1-metrics-after.txt')
  Write-Host "After /metrics captured: $((($afterMetrics -join "`n") | Measure-Object -Line).Lines) lines"
} catch {
  Write-Host "Failed to capture after metrics: $_"
}

Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Write-Host "Server stopped"

$afterContent = Get-Content (Join-Path $logDir 'mtp-attempt1-metrics-after.txt') -Raw -ErrorAction SilentlyContinue
$checkpointRows = ($afterContent -split "`n") | Where-Object { $_ -match 'cache_checkpoint' }
if ($checkpointRows) {
  Write-Host "SUCCESS: cache_checkpoint rows found"
  $checkpointRows | Out-File -FilePath (Join-Path $logDir 'mtp-attempt1-checkpoint-rows.txt')
  $checkpointRows | ForEach-Object { Write-Host "  $_" }
} else {
  Write-Host "ATTEMPT 1 FAILED: no cache_checkpoint rows"
}
