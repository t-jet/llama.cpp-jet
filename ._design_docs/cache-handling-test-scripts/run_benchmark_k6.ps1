#requires -Version 5
# run_benchmark_k6.ps1
# Stage 10 k6 cache correctness benchmark runner.
#
# Starts llama-server in hybrid mode, captures /metrics snapshots before and
# after, runs bench-cache-correctness.js with standard k6, then produces
# evidence for T116 and T117.
#
# Usage:
#   .\._design_docs\cache-handling-test-scripts\run_benchmark_k6.ps1 `
#       [-BuildDir <path>]   # release bin parent, default .\build
#       [-ModelPath <gguf>]  # GGUF model, default LLAMA_CACHE_TEST_MODEL
#       [-K6Path <exe>]      # k6.exe path, default D:\app\k6\k6.exe
#       [-Port <int>]        # server port, default 8142
#       [-OutDir <path>]     # output directory for evidence files
#       [-Iterations <int>]  # total probe iterations for k6, default 12
#
# Output files:
#   metrics-before.txt      /metrics snapshot before k6 run
#   metrics-after.txt       /metrics snapshot after k6 run
#   k6-results.json         k6 NDJSON output
#   k6-stdout.txt           k6 console output
#   server.out.log          llama-server stdout
#   server.err.log          llama-server stderr
#   evidence-summary.md     T116 / T117 evidence classification
#
# Evidence classification:
#   T116 - Each measured type is classified as:
#     "direct stats"   : timings.cache_n, timings.prompt_ms from /completion JSON
#     "public Prometheus": counter deltas from /metrics snapshots
#     "harness-only"   : k6-derived rates and trends
#   T117 - Correctness gate: k6 must exit 0 (cache_hit_rate >= 60%)

param(
    [string] $BuildDir  = '',
    [string] $ModelPath = '',
    [string] $K6Path    = 'D:\app\k6\k6.exe',
    [string] $OutDir    = '',
    [int]    $Port      = 8142,
    [int]    $Iterations = 12
)

$ErrorActionPreference = 'Stop'

$scriptDir  = $PSScriptRoot
$sourceRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path

if (-not $BuildDir) {
    $BuildDir = Join-Path $sourceRoot 'build'
}
$binDir = Join-Path $BuildDir 'bin\Release'

if (-not $ModelPath) {
    $ModelPath = $env:LLAMA_CACHE_TEST_MODEL
}
if (-not $ModelPath) {
    $ModelPath = Join-Path $sourceRoot '._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
}

if (-not $OutDir) {
    $OutDir = Join-Path $sourceRoot '._design_docs\.test_reports\benchmark-run'
}

$k6ScriptPath = Join-Path $sourceRoot 'tools\server\tests\bench-cache-correctness.js'

# Verify prerequisites.
$serverExe = Join-Path $binDir 'llama-server.exe'
foreach ($required in @($serverExe, $K6Path, $k6ScriptPath)) {
    if (-not (Test-Path $required)) {
        Write-Error "Required file not found: $required"
    }
}
if (-not (Test-Path $ModelPath)) {
    Write-Error "Model not found: $ModelPath. Set -ModelPath or LLAMA_CACHE_TEST_MODEL."
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# Stop any prior server on this port.
Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

Write-Host "Starting llama-server (hybrid mode, port $Port)"
$serverArgs = @(
    '--model',         $ModelPath,
    '--cache-mode',    'hybrid',
    '--ctx-size',      '512',
    '--parallel',      '1',
    '--cache-ram',     '100',
    '--temp',          '0',
    '--seed',          '42',
    '--metrics',
    '--host',          '127.0.0.1',
    '--port',          "$Port",
    '--log-verbosity', '1'
)
$serverProc = Start-Process -FilePath $serverExe -ArgumentList $serverArgs `
                             -RedirectStandardOutput (Join-Path $OutDir 'server.out.log') `
                             -RedirectStandardError  (Join-Path $OutDir 'server.err.log') `
                             -NoNewWindow -PassThru

# Wait for /health.
$ready    = $false
$deadline = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $deadline) {
    try {
        $h = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 4
        if ($h.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
    Start-Sleep -Seconds 2
}
if (-not $ready) {
    Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue
    Write-Error "Server did not become ready in 180 s."
}
Write-Host "Server ready"

# Warmup request to seed the cache entry before k6 probes.
$warmupBody = '{"prompt":"Cache QA deterministic prompt.","n_predict":8,"temperature":0,"seed":42,"cache_prompt":true}'
Write-Host "Sending warmup request"
$null = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/completion" -Method POST `
                          -Body $warmupBody -ContentType 'application/json' `
                          -UseBasicParsing -TimeoutSec 120

# Snapshot /metrics before k6 run.
$metBefore = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content
$metBefore | Out-File -FilePath (Join-Path $OutDir 'metrics-before.txt') -Encoding utf8
Write-Host "Metrics snapshot: before"

# Run k6 correctness benchmark.
Write-Host "Running k6 ($Iterations iterations)"
$k6ResultsPath = Join-Path $OutDir 'k6-results.json'
$k6StdoutPath  = Join-Path $OutDir 'k6-stdout.txt'

$env:BENCH_URL        = "http://127.0.0.1:$Port"
$env:BENCH_ITERS      = "$Iterations"
$env:BENCH_N_PREDICT  = '8'

$k6Args = @(
    'run',
    '--out', "json=$k6ResultsPath",
    '--summary-trend-stats', 'avg,min,med,p(95),max',
    $k6ScriptPath
)
$k6Proc = Start-Process -FilePath $K6Path -ArgumentList $k6Args `
                         -NoNewWindow -PassThru -Wait `
                         -RedirectStandardOutput $k6StdoutPath `
                         -RedirectStandardError  (Join-Path $OutDir 'k6-stderr.txt')
$k6Exit = $k6Proc.ExitCode
Write-Host "k6 exit: $k6Exit"

# Snapshot /metrics after k6 run.
$metAfter = (Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -TimeoutSec 10).Content
$metAfter | Out-File -FilePath (Join-Path $OutDir 'metrics-after.txt') -Encoding utf8
Write-Host "Metrics snapshot: after"

# Stop the server.
Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue
Write-Host "Server stopped"

# Parse counter deltas from /metrics snapshots (public Prometheus evidence).
function Get-MetricValue {
    param([string] $Text, [string] $Pattern)
    $line = $Text -split "`n" | Where-Object { $_ -match "^$Pattern\b" } | Select-Object -First 1
    if ($line -match '} (\S+)$') { return [double]$Matches[1] }
    if ($line -match '\s(\S+)$')  { return [double]$Matches[1] }
    return 0
}

$hitsBeforeMode   = Get-MetricValue $metBefore 'llamacpp_cache_hits_total\{mode="hybrid"\}'
$missBeforeMode   = Get-MetricValue $metBefore 'llamacpp_cache_misses_total\{mode="hybrid"\}'
$hitsAfterMode    = Get-MetricValue $metAfter  'llamacpp_cache_hits_total\{mode="hybrid"\}'
$missAfterMode    = Get-MetricValue $metAfter  'llamacpp_cache_misses_total\{mode="hybrid"\}'

$hitsDelta  = $hitsAfterMode  - $hitsBeforeMode
$missDelta  = $missAfterMode  - $missBeforeMode

# Parse k6 summary from stdout.
$k6SummaryLines = Get-Content $k6StdoutPath -ErrorAction SilentlyContinue |
                  Where-Object { $_ -match 'cache_hit_rate|cache_n_tokens|cache_miss_prompt|cache_hit_prompt' }

# Write evidence summary.
$summaryLines = @(
    "# T116 / T117 benchmark evidence summary",
    "",
    "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "k6 exit code: $k6Exit",
    "T117 correctness gate: $(if ($k6Exit -eq 0) { 'PASS' } else { 'FAIL' })",
    "",
    "## Evidence classification",
    "",
    "| Scenario | Measurement | Source class |",
    "| --- | --- | --- |",
    "| Exact-hit | timings.cache_n > 0 per /completion response | direct stats |",
    "| Exact-hit | llamacpp_cache_hits_total delta after probes | public Prometheus |",
    "| Exact-hit | cache_hit_rate threshold (k6 Rate metric) | harness-only |",
    "| Cache-miss prompt time | timings.prompt_ms for cache_n=0 responses | direct stats |",
    "| Cache-hit prompt time  | timings.prompt_ms for cache_n>0 responses | direct stats |",
    "| Probe misses | llamacpp_cache_misses_total delta | public Prometheus |",
    "",
    "## Public Prometheus counter deltas",
    "",
    "| Counter | Before | After | Delta |",
    "| --- | --- | --- | --- |",
    "| llamacpp_cache_hits_total (hybrid) | $hitsBeforeMode | $hitsAfterMode | $hitsDelta |",
    "| llamacpp_cache_misses_total (hybrid) | $missBeforeMode | $missAfterMode | $missDelta |",
    "",
    "## k6 direct stats",
    ""
) + $k6SummaryLines

$summaryPath = Join-Path $OutDir 'evidence-summary.md'
$summaryLines | Out-File -FilePath $summaryPath -Encoding utf8

Write-Host ""
Write-Host "Prometheus hits delta : $hitsDelta"
Write-Host "Prometheus misses delta: $missDelta"
Write-Host "Evidence summary: $summaryPath"
Write-Host "T117 correctness gate: $(if ($k6Exit -eq 0) { 'PASS' } else { 'FAIL' })"

if ($k6Exit -ne 0) {
    Write-Warning "k6 exited ${k6Exit}: cache correctness threshold not met. See $k6StdoutPath"
    exit 1
}
