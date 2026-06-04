# public-probe.ps1 - 20260603-03 session
# Public HTTP /metrics probe against Qwen3-0.6B-Q8_0.gguf in hybrid mode.

$ErrorActionPreference = 'Stop'
$art     = "D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-03-artifacts"
$port    = 8140
$model   = "D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf"
$bin     = "D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe"

if (-not (Test-Path $model)) { throw "model not found: $model" }
if (-not (Test-Path $bin))   { throw "llama-server.exe not found: $bin" }

# Stop any prior server on this port.
Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$args = @(
    '--model',         $model,
    '--cache-mode',    'hybrid',
    '--ctx-size',      '512',
    '--parallel',      '1',
    '--cache-ram',     '100',
    '--temp',          '0',
    '--seed',          '42',
    '--metrics',
    '--host',          '127.0.0.1',
    '--port',          "$port",
    '--log-verbosity', '1'
)

Write-Host "Starting llama-server on port $port"
$proc = Start-Process -FilePath $bin -ArgumentList $args `
                      -RedirectStandardOutput (Join-Path $art 'public-server.out.log') `
                      -RedirectStandardError  (Join-Path $art 'public-server.err.log') `
                      -NoNewWindow -PassThru
$proc.Id | Out-File -FilePath (Join-Path $art 'public-server.pid') -Encoding ascii

# Wait for /health (up to 240 s).
$ready    = $false
$deadline = (Get-Date).AddSeconds(240)
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 4
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw "Server did not become ready in 240 s. See $art\public-server.err.log"
}
$h.Content | Out-File -FilePath (Join-Path $art 'health.json') -Encoding utf8
Write-Host "Server ready at $(Get-Date -Format 'HH:mm:ss')"
"health_ready: True at $(Get-Date -Format 'o')" | Out-File -FilePath (Join-Path $art 'public-server.health') -Encoding ascii

# /metrics before completions
$met0 = (Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10).Content
$met0 | Out-File -FilePath (Join-Path $art 'metrics-before.txt') -Encoding utf8
Write-Host "Metrics snapshot: before"

# First completion (cache miss -> cold)
$body1 = '{"prompt":"Cache QA deterministic prompt.","n_predict":8,"temperature":0,"seed":42,"cache_prompt":true,"stream":false}'
$r1 = Invoke-WebRequest -Uri "http://127.0.0.1:$port/completion" -Method POST `
                        -Body $body1 -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
$r1.Content | Out-File -FilePath (Join-Path $art 'completion-1.json') -Encoding utf8
$j1 = $r1.Content | ConvertFrom-Json
"cache_n=$($j1.timings.cache_n); prompt_ms=$($j1.timings.prompt_ms)" | Out-File -FilePath (Join-Path $art 'completion-1.summary') -Encoding ascii
Write-Host "Completion 1: cache_n=$($j1.timings.cache_n) prompt_ms=$($j1.timings.prompt_ms)"

# Second completion (cache hit expected)
$r2 = Invoke-WebRequest -Uri "http://127.0.0.1:$port/completion" -Method POST `
                        -Body $body1 -ContentType 'application/json' -UseBasicParsing -TimeoutSec 120
$r2.Content | Out-File -FilePath (Join-Path $art 'completion-2.json') -Encoding utf8
$j2 = $r2.Content | ConvertFrom-Json
"cache_n=$($j2.timings.cache_n); prompt_ms=$($j2.timings.prompt_ms)" | Out-File -FilePath (Join-Path $art 'completion-2.summary') -Encoding ascii
Write-Host "Completion 2: cache_n=$($j2.timings.cache_n) prompt_ms=$($j2.timings.prompt_ms)"

# /metrics after both completions
$met1 = (Invoke-WebRequest -Uri "http://127.0.0.1:$port/metrics" -UseBasicParsing -TimeoutSec 10).Content
$met1 | Out-File -FilePath (Join-Path $art 'metrics-after.txt') -Encoding utf8
Write-Host "Metrics snapshot: after"

# Build Stage 10 metric excerpt
$exStage10 = ($met1 -split "`n" | Where-Object {
    $_ -match '^cache_exact_blob_restores_total' -or
    $_ -match '^cache_payload_transitions_total' -or
    $_ -match '^cache_payload_evictions_by_shape_total' -or
    $_ -match '^cache_protected_root_decisions_by_shape_total' -or
    $_ -match '^cache_fallback_restores_by_shape_total' -or
    $_ -match '^cache_structured_diagnostics_total' -or
    $_ -match '^cache_structured_diagnostics_by_shape_total'
}) -join "`n"
$exStage10 | Out-File -FilePath (Join-Path $art 'metrics-stage10-excerpt.txt') -Encoding utf8

# Checkpoint metric excerpt (T121)
$exCkpt = ($met1 -split "`n" | Where-Object { $_ -match '^cache_checkpoint_' }) -join "`n"
$exCkpt | Out-File -FilePath (Join-Path $art 'metrics-checkpoint-excerpt.txt') -Encoding utf8

# Stop the server.
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Write-Host "Server stopped"
"probe_complete: True at $(Get-Date -Format 'o')" | Out-File -FilePath (Join-Path $art 'public-server.probe-complete') -Encoding ascii
