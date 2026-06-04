# MTP public probe for T121 - Stage 10 bug-fix loop
# Drives llama-server with a Qwen3.5-4B MTP fixture, exercises a /completion
# request that should admit a checkpoint descriptor, and compares
# cache_checkpoint_* rows in /metrics before/after.

[CmdletBinding()]
param(
    [string]$ServerExe = 'D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe',
    [string]$Model = 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf',
    [int]$Port = 8183,
    [int]$WaitSeconds = 240,
    [string]$OutDir = 'D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260603-04-artifacts'
)

$ErrorActionPreference = 'Stop'
$env:LLAMA_CACHE_TEST_MODEL = $Model

function Get-Metrics {
    param([int]$P)
    try {
        $resp = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$P/metrics" -TimeoutSec 30
        return $resp.Content
    } catch {
        return $null
    }
}

function Get-CacheCheckpointLines {
    param([string]$Text)
    if (-not $Text) { return @() }
    $lines = $Text -split "`n"
    return $lines | Where-Object { $_ -match 'cache_checkpoint' }
}

function Test-ServerReady {
    param([int]$P)
    try {
        $h = Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:$P/health" -TimeoutSec 5
        return ($h.StatusCode -eq 200)
    } catch {
        return $false
    }
}

# Cleanup any prior server
Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | ForEach-Object {
    try { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue } catch {}
}
Start-Sleep -Seconds 2

$logPath = Join-Path $OutDir 'mtp-public-probe.log'
if (Test-Path $logPath) { Remove-Item $logPath -Force }

$serverArgs = @(
    '-m', $Model,
    '--port', "$Port",
    '--host', '127.0.0.1',
    '-ngl', '99',
    '-c', '8192',
    '-np', '1'
)
$serverLog = Join-Path $OutDir 'mtp-server-stdout.log'

Write-Host "Starting llama-server on port $Port with MTP fixture..."
$proc = Start-Process -FilePath $ServerExe `
    -ArgumentList $serverArgs `
    -RedirectStandardOutput $serverLog `
    -RedirectStandardError "$serverLog.err" `
    -PassThru -NoNewWindow

$ready = $false
$deadline = (Get-Date).AddSeconds($WaitSeconds)
while ((Get-Date) -lt $deadline) {
    if ($proc.HasExited) { break }
    if (Test-ServerReady -P $Port) { $ready = $true; break }
    Start-Sleep -Seconds 3
}

if (-not $ready) {
    Write-Host "Server did not become ready in $WaitSeconds seconds"
    Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] SERVER_NOT_READY exit=$($proc.HasExited)"
    if (Test-Path $serverLog) { Add-Content -Path $logPath -Value (Get-Content $serverLog -Raw) }
    if (Test-Path "$serverLog.err") { Add-Content -Path $logPath -Value (Get-Content "$serverLog.err" -Raw) }
    try { Stop-Process -Id $proc.Id -Force } catch {}
    exit 1
}

Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] SERVER_READY"
Write-Host "Server ready."

# Capture before metrics
$beforeRaw = Get-Metrics -P $Port
$before = Get-CacheCheckpointLines -Text $beforeRaw
$before | Out-File -FilePath (Join-Path $OutDir 'mtp-metrics-before.txt') -Encoding utf8
Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] METRICS_BEFORE checkpoint_rows=$($before.Count)"

# Attempt 1: simple completion
$payload1 = @{
    prompt = "The quick brown fox"
    n_predict = 32
    temperature = 0
    stream = $false
} | ConvertTo-Json -Depth 5

try {
    $r1 = Invoke-WebRequest -UseBasicParsing `
        -Uri "http://127.0.0.1:$Port/completion" `
        -Method POST `
        -ContentType 'application/json' `
        -Body $payload1 `
        -TimeoutSec 120
    $r1.Content | Out-File -FilePath (Join-Path $OutDir 'mtp-completion-1.json') -Encoding utf8
    Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] COMPLETION_1 status=$($r1.StatusCode) len=$($r1.Content.Length)"
} catch {
    Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] COMPLETION_1_ERROR $($_.Exception.Message)"
}

# Attempt 2: MTP-flavored completion with speculative-like params
$payload2 = @{
    prompt = "The quick brown fox jumps over the lazy dog"
    n_predict = 64
    temperature = 0
    stream = $false
    n_probs = 1
    slot_id = 0
} | ConvertTo-Json -Depth 5

try {
    $r2 = Invoke-WebRequest -UseBasicParsing `
        -Uri "http://127.0.0.1:$Port/completion" `
        -Method POST `
        -ContentType 'application/json' `
        -Body $payload2 `
        -TimeoutSec 120
    $r2.Content | Out-File -FilePath (Join-Path $OutDir 'mtp-completion-2.json') -Encoding utf8
    Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] COMPLETION_2 status=$($r2.StatusCode) len=$($r2.Content.Length)"
} catch {
    Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] COMPLETION_2_ERROR $($_.Exception.Message)"
}

# Capture after metrics
$afterRaw = Get-Metrics -P $Port
$after = Get-CacheCheckpointLines -Text $afterRaw
$after | Out-File -FilePath (Join-Path $OutDir 'mtp-metrics-after.txt') -Encoding utf8
Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] METRICS_AFTER checkpoint_rows=$($after.Count)"

# Compare
$nonZeroBefore = ($before | Where-Object { $_ -notmatch ' 0(\.0+)?$' }).Count
$nonZeroAfter  = ($after  | Where-Object { $_ -notmatch ' 0(\.0+)?$' }).Count
Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] NONZERO_BEFORE=$nonZeroBefore NONZERO_AFTER=$nonZeroAfter"

Write-Host "nonZeroBefore=$nonZeroBefore nonZeroAfter=$nonZeroAfter"

# Shutdown
try { Stop-Process -Id $proc.Id -Force } catch {}
Add-Content -Path $logPath -Value "[$(Get-Date -Format 'o')] SERVER_STOPPED"
