#requires -Version 5
$ErrorActionPreference = 'Stop'

$art = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-01-artifacts"
$bin = "D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe"
$modelPath = "D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf"
$port = 8132

# Stop any prior instance on this port.
Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD = '1'
$env:LLAMA_SERVER_BIN_PATH = $bin

$argsList = @('--model', $modelPath,
              '--cache-mode', 'hybrid',
              '--ctx-size', '512',
              '--parallel', '1',
              '--cache-ram', '100',
              '--temp', '0',
              '--seed', '42',
              '--metrics',
              '--host', '127.0.0.1',
              '--port', "$port",
              '--log-verbosity', '3')
"args: $($argsList -join ' ')" | Out-File -FilePath (Join-Path $art 'public-command.txt') -Encoding utf8

$proc = Start-Process -FilePath $bin -ArgumentList $argsList `
                      -RedirectStandardOutput (Join-Path $art 'public-server.out.log') `
                      -RedirectStandardError  (Join-Path $art 'public-server.err.log') `
                      -NoNewWindow -PassThru
"pid: $($proc.Id)" | Out-File -FilePath (Join-Path $art 'public-server.pid') -Encoding utf8

# Wait for /health up to 180 seconds.
$deadline = (Get-Date).AddSeconds(180)
$ready = $false
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 5
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}
"health_ready: $ready at $(Get-Date -Format 'o')" | Out-File -FilePath (Join-Path $art 'public-server.health') -Encoding utf8
if (-not $ready) {
    "Server did not become ready in 180 seconds." | Out-File -FilePath (Join-Path $art 'public-server.error') -Encoding utf8
    exit 2
}

# Capture /health body.
$healthResp = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 10
$healthResp.Content | Out-File -FilePath (Join-Path $art 'health.json') -Encoding utf8

# Capture /metrics before any completion.
$m1 = Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10
$m1.Content | Out-File -FilePath (Join-Path $art 'metrics-before.txt') -Encoding utf8

# POST first completion.
$body = '{"prompt":"Cache QA deterministic prompt.","n_predict":8,"temperature":0,"seed":42,"cache_prompt":true}'
$c1 = Invoke-WebRequest -Uri "http://127.0.0.1:$port/completion" -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
$c1.Content | Out-File -FilePath (Join-Path $art 'completion-1.json') -Encoding utf8

# POST same completion again.
$c2 = Invoke-WebRequest -Uri "http://127.0.0.1:$port/completion" -Method POST -Body $body -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
$c2.Content | Out-File -FilePath (Join-Path $art 'completion-2.json') -Encoding utf8

# Capture /metrics after second completion.
$m2 = Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10
$m2.Content | Out-File -FilePath (Join-Path $art 'metrics-after-2.txt') -Encoding utf8

# Save Stage 10 rows excerpt.
$lines = $m2.Content -split "`n" | Where-Object { $_ -match 'cache_(exact_blob_restores|payload_transitions|payload_evictions_by_shape|protected_root_decisions|fallback_restores|structured_diagnostics)_by_shape_total|cache_(exact_blob_restores|payload_transitions|payload_evictions_by_shape|protected_root_decisions|fallback_restores|structured_diagnostics)_total' }
$lines | Out-File -FilePath (Join-Path $art 'metrics-stage10-excerpt.txt') -Encoding utf8

# Final checkpoint-dependent test: try to see if local fixture can produce checkpoint rows.
$linesCheckpoint = $m2.Content -split "`n" | Where-Object { $_ -match 'cache_checkpoint_' }
$linesCheckpoint | Out-File -FilePath (Join-Path $art 'metrics-checkpoint-excerpt.txt') -Encoding utf8

"probe_complete at $(Get-Date -Format 'o')" | Out-File -FilePath (Join-Path $art 'public-server.probe-complete') -Encoding utf8

# Stop server.
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Format-List
