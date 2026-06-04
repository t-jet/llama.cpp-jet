#requires -Version 5
$ErrorActionPreference = 'Stop'

$art  = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-01-artifacts"
$bin  = "D:\source\llama.cpp-jet\build\bin\Release"
$port = 8132

# Stop any prior instance on this port.
Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$modelPath = "D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf"
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

$serverOut = Join-Path $art 'k6-server.out.log'
$serverErr = Join-Path $art 'k6-server.err.log'

# Start the server.
$proc = Start-Process -FilePath $bin\llama-server.exe -ArgumentList $argsList `
                      -RedirectStandardOutput $serverOut `
                      -RedirectStandardError  $serverErr `
                      -NoNewWindow -PassThru
"server_pid: $($proc.Id)" | Out-File -FilePath (Join-Path $art 'k6-server.pid') -Encoding utf8

# Wait for /health.
$ready = $false
$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 5
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch { }
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    "server not ready in 180s" | Out-File -FilePath (Join-Path $art 'k6-server.error') -Encoding utf8
    Stop-Process -Id $proc.Id -Force
    exit 1
}
"server_ready" | Out-File -FilePath (Join-Path $art 'k6-server.health') -Encoding utf8

# Snapshot /metrics before k6.
$before = Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10
$before.Content | Out-File -FilePath (Join-Path $art 'k6-metrics-before.txt') -Encoding utf8

# Run k6 with the simple probe script.
$k6 = "D:\app\k6\k6.exe"
$k6Args = @(
    'run',
    '--out', 'json=k6-results.json',
    '--summary-trend-stats', 'avg,min,med,p(95),max',
    (Join-Path $art 'k6-metrics-probe.js')
)
$env:SERVER_URL = "http://127.0.0.1:$port"
$env:K6_VUS = '1'
$env:K6_ITERS = '20'

Set-Location $art
& $k6 @k6Args 2>&1 | Out-File -FilePath (Join-Path $art 'k6-stdout.log') -Encoding utf8
"k6_exit: $LASTEXITCODE" | Out-File -FilePath (Join-Path $art 'k6-exit.txt') -Encoding utf8

# Snapshot /metrics after k6.
$after = Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10
$after.Content | Out-File -FilePath (Join-Path $art 'k6-metrics-after.txt') -Encoding utf8

# Save a diff of exact-blob and stage10 rows.
$lines = $after.Content -split "`n" | Where-Object { $_ -match 'cache_exact_blob_restores|cache_payload_transitions|cache_payload_evictions|cache_protected_root|cache_fallback_restores|cache_structured_diagnostics' }
$lines | Out-File -FilePath (Join-Path $art 'k6-stage10-excerpt.txt') -Encoding utf8

# Stop the server.
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
"k6_run_complete" | Out-File -FilePath (Join-Path $art 'k6-run-complete') -Encoding utf8
