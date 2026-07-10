#requires -Version 5
# compare-legacy-vs-hybrid.ps1
#
# Stage 29 main driver: A/B comparison of `--cache-mode legacy` against
# `--cache-mode hybrid` on a reproducible agentic-shaped workload.
# Implements the 5 phases from design part-03 (Phase 0 preflight, Phase 0.5
# tokenize helper, Phase 1 output equivalence, Phase 2 cold-start cycle,
# Phase 3 warm cycles) and the three-layer report emitter per part-05.
#
# Usage:
#   .\_design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
#       -RunId stage29-cache-modes-20260628-01 `
#       -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
#       -RunRoot ._test_output\stage29-cache-modes-20260628-01 `
#       -LlamaServerPath build-cuda\bin\Release\llama-server.exe `
#       -DryRun

param(
    [string]   $RunId                  = ('stage29-cache-modes-' + (Get-Date -Format 'yyyyMMdd')),
    [string]   $ModelPath              = '',
    [string]   $RunRoot                = '',
    [string]   $ReportPath             = '',
    [string]   $CacheColdPath          = 'D:\tmp\cache-cold-stage29',
    [int]      $BasePort               = 8900,
    [int]      $LegDurationMin         = 10,
    [int]      $ColdBudgetMiB          = 2048,
    [int]      $HotBudgetMiB           = 512,
    [int]      $Cycles                 = 3,
    [int]      $OutputEquivalencePrompts = 5,
    [string]   $LlamaServerPath        = '',
    [int]      $ContextSize            = 4096,
    [int]      $Parallel               = 2,
    [int]      $Seed                   = 42,
    [int]      $RequestCount           = 200,
    [switch]   $BurstDuplicateMode,
    [int]      $BurstCount             = 8,
    [int]      $RepeatsPerBurst        = 6,
    [int]      $FillerCount            = 0,
    [switch]   $DryRun,
    [switch]   $OutputEquivalenceOnly
)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$repoRoot  = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$libDir    = Join-Path $scriptDir 'lib'
. (Join-Path $libDir 'agentic-prompt-generator.ps1')
. (Join-Path $libDir 'compare-legacy-vs-hybrid-workload.ps1')
. (Join-Path $libDir 'Read-Stage29MetricSnapshot.ps1')
. (Join-Path $libDir 'Write-Stage29EvidenceRow.ps1')
. (Join-Path $libDir 'Test-Stage29OutputEquivalence.ps1')
. (Join-Path $libDir 'Wait-Stage29VramBaseline.ps1')
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Resolve-Stage29Path { param([string]$P) if ([System.IO.Path]::IsPathRooted($P)) { return $P } return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $P)) }
function Test-PortFree { param([int]$P) $l = $null; try { $l = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Parse('127.0.0.1')), $P; $l.Start(); return $true } catch { return $false } finally { if ($l) { $l.Stop() } } }
function Write-Stage29Text { param([string]$Path,[string]$Text) $d = Split-Path -Parent $Path; if ($d -and -not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }; [System.IO.File]::WriteAllText($Path, $Text, $utf8) }

function Get-CudaBuildProof {
    $buildRoot = $null
    if ($LlamaServerPath -and (Test-Path $LlamaServerPath)) {
        $dir = (Get-Item -LiteralPath $LlamaServerPath).Directory
        if ($dir.Name -eq 'Release') { $dir = $dir.Parent }
        if ($dir.Name -eq 'bin')     { $dir = $dir.Parent }
        $buildRoot = $dir.FullName
    }
    $cachePath = if ($buildRoot) { Join-Path $buildRoot 'CMakeCache.txt' } else { $null }
    $state = 'BLOCKED-cuda-configure-missing'
    if ($cachePath -and (Test-Path $cachePath)) {
        $line = Get-Content -LiteralPath $cachePath | Where-Object { $_ -match '^GGML_CUDA:BOOL=' } | Select-Object -First 1
        if ($line -eq 'GGML_CUDA:BOOL=ON') { $state = 'PASS' }
    }
    return [pscustomobject]@{ state = $state; build_root = $buildRoot; cmake_cache = $cachePath }
}

function Invoke-Preflight {
    $out = [ordered]@{
        ps_version_ok = ($PSVersionTable.PSVersion.Major -ge 5)
        binary_exists = (Test-Path $LlamaServerPath)
        fixture_exists = (Test-Path (Resolve-Stage29Path $ModelPath))
        port_free = (Test-PortFree $BasePort)
        cuda_proof = (Get-CudaBuildProof).state
        git_head = (& git rev-parse HEAD 2>$null).Trim()
        git_dirty = (& git status --porcelain 2>$null | Measure-Object).Count
    }
    $out.status = if ($out.ps_version_ok -and $out.binary_exists -and $out.fixture_exists -and $out.port_free -and $out.cuda_proof -eq 'PASS') { 'PASS' } else { 'BLOCKED-preflight' }
    return [pscustomobject]$out
}

function Start-Stage29Server {
    param([string]$Mode, [int]$Port)
    if ($Mode -eq 'hybrid' -and $CacheColdPath -and -not (Test-Path $CacheColdPath)) {
        New-Item -ItemType Directory -Force -Path $CacheColdPath | Out-Null
    }
    $args = @('-m', (Resolve-Stage29Path $ModelPath), '--cache-mode', $Mode, '--port', $Port, '-c', $ContextSize, '--parallel', $Parallel, '--cache-ram', $HotBudgetMiB, '--metrics', '--seed', $Seed)
    if ($Mode -eq 'hybrid') {
        $args += @('--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-path', $CacheColdPath)
    }
    return Start-Process -FilePath $LlamaServerPath -ArgumentList $args -PassThru -RedirectStandardOutput "$RunRoot\server.out.log" -RedirectStandardError "$RunRoot\server.err.log"
}

function Stop-Stage29Server {
    param([System.Diagnostics.Process]$Proc)
    if (-not $Proc) { return }
    try { Stop-Process -Id $Proc.Id -Force -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Seconds 5
}

function Wait-Stage29Health {
    param([int]$Port, [int]$TimeoutSec = 60)
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try { $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 3; if ($r.StatusCode -eq 200) { return $true } } catch {}
        Start-Sleep -Seconds 2
    }
    return $false
}

function Invoke-Phase1OutputEquivalence {
    $eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'
    if (-not (Test-Path $eqPath)) { throw 'equivalence-prompts.jsonl missing (Phase 0.5 not run)' }
    $outDir = Join-Path $RunRoot 'phase-1-output-equivalence'
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $legacyDecoded = Join-Path $outDir 'legacy-decoded.txt'
    $hybridDecoded = Join-Path $outDir 'hybrid-decoded.txt'
    $diffPath      = Join-Path $outDir 'diff.txt'
    foreach ($mode in @('legacy','hybrid')) {
        $proc = Start-Stage29Server -Mode $Mode -Port $BasePort
        if (-not (Wait-Stage29Health -Port $BasePort -TimeoutSec 30)) { Stop-Stage29Server $proc; throw "$mode failed /health within 30s" }
        try {
            $decoded = New-Object System.Collections.Generic.List[string]
            Get-Content -LiteralPath $eqPath | ForEach-Object {
                $obj = $_ | ConvertFrom-Json
                $resp = Send-Stage29ChatPrompt -ServerUrl "http://127.0.0.1:$BasePort" -MessagesJson (ConvertTo-Json -InputObject $obj.messages -Depth 10 -Compress) -MaxTokens $obj.max_tokens -SeedVal $obj.seed
                [void]$decoded.Add($resp.choices[0].message.content)
            }
            $target = if ($mode -eq 'legacy') { $legacyDecoded } else { $hybridDecoded }
            [System.IO.File]::WriteAllText($target, ($decoded -join "`n"), $utf8)
        } finally {
            Stop-Stage29Server $proc
            Wait-Stage29VramBaseline -BaselineMiB 0 -ToleranceMiB 200 -MaxWaitSec 60 -SleepSec 10 | Out-Null
        }
    }
    return (Test-Stage29OutputEquivalence -LegacyDecodedPath $legacyDecoded -HybridDecodedPath $hybridDecoded -DiffOutPath $diffPath)
}

function Invoke-Phase05WorkloadBuild {
    $proc = Start-Stage29Server -Mode 'legacy' -Port $BasePort
    $healthy = Wait-Stage29Health -Port $BasePort -TimeoutSec 60
    if (-not $healthy) { Stop-Stage29Server $proc; throw 'BLOCKED-workload-build: tokenize helper failed /health' }
    try {
        $wlPath = Join-Path $RunRoot 'workload.jsonl'
        $workloadArgs = @{
            RequestCount = $RequestCount
            ServerUrl = "http://127.0.0.1:$BasePort"
            OutPath = $wlPath
            Seed = $Seed
            MaxTokens = 8
            MaxIterations = 200
            SizeClass = '2k'
        }
        if ($BurstDuplicateMode) {
            $workloadArgs.BurstDuplicateMode = $true
            $workloadArgs.BurstCount = $BurstCount
            $workloadArgs.RepeatsPerBurst = $RepeatsPerBurst
            $workloadArgs.FillerCount = $FillerCount
        }
        New-ComparisonWorkload @workloadArgs
        $eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'
        New-ComparisonWorkload -RequestCount $OutputEquivalencePrompts -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $eqPath -Seed $Seed -MaxTokens 8 -MaxIterations 200 -SizeClass '2k'
    } finally {
        Stop-Stage29Server $proc
        Wait-Stage29VramBaseline -BaselineMiB 0 -ToleranceMiB 200 -MaxWaitSec 60 -SleepSec 10 | Out-Null
    }
    return @{ workload = $wlPath; equivalence = $eqPath }
}

function Send-Stage29ChatPrompt {
    param([string]$ServerUrl, [string]$MessagesJson, [int]$MaxTokens, [int]$SeedVal)
    $body = @{ messages = ($MessagesJson | ConvertFrom-Json); max_tokens = $MaxTokens; temperature = 0; seed = $SeedVal; stream = $false } | ConvertTo-Json -Depth 12
    return Invoke-RestMethod -Uri "$ServerUrl/v1/chat/completions" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 60
}

function Get-Stage29ResponseStats {
    param($Resp)
    $cacheN = 0
    $promptN = 0
    $predictedN = 0
    $promptMs = 0
    if ($Resp.timings) {
        if ($null -ne $Resp.timings.cache_n)     { $cacheN = [int]$Resp.timings.cache_n }
        if ($null -ne $Resp.timings.prompt_n)    { $promptN = [int]$Resp.timings.prompt_n }
        if ($null -ne $Resp.timings.predicted_n) { $predictedN = [int]$Resp.timings.predicted_n }
        if ($null -ne $Resp.timings.prompt_ms)   { $promptMs = [double]$Resp.timings.prompt_ms }
    }
    if ($Resp.usage) {
        if ($null -ne $Resp.usage.prompt_tokens_details.cached_tokens) { $cacheN = [int]$Resp.usage.prompt_tokens_details.cached_tokens }
        if ($null -ne $Resp.usage.prompt_tokens)                       { $promptN = [int]$Resp.usage.prompt_tokens }
        if ($null -ne $Resp.usage.completion_tokens)                   { $predictedN = [int]$Resp.usage.completion_tokens }
    }
    return [pscustomobject]@{ cache_n = $cacheN; prompt_n = $promptN; predicted_n = $predictedN; prompt_ms = $promptMs }
}

function Invoke-CycleLeg {
    param([int]$Cycle, [string]$Mode, [string]$WorkloadPath, [string]$Phase)
    $legDir = Join-Path $RunRoot ("$Phase-cycle-$Cycle/$Mode")
    New-Item -ItemType Directory -Force -Path $legDir | Out-Null
    $beforePath = Join-Path $legDir 'metrics-before.txt'
    $afterPath  = Join-Path $legDir 'metrics-after.txt'
    $reqPath    = Join-Path $legDir 'requests.jsonl'
    $proc = Start-Stage29Server -Mode $Mode -Port $BasePort
    if (-not (Wait-Stage29Health -Port $BasePort -TimeoutSec 90)) { Stop-Stage29Server $proc; throw "BLOCKED-server-not-running: $Phase/$Mode failed /health" }
    try {
        $beforeSnap = Read-Stage29MetricSnapshot -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $beforePath
        $lines = Get-Content -LiteralPath $WorkloadPath
        $reqOut = New-Object System.Collections.Generic.List[string]
        $counts = @{ exact = 0; near_prefix = 0; new_branch = 0 }
        foreach ($line in $lines) {
            $obj = $line | ConvertFrom-Json
            $resp = Send-Stage29ChatPrompt -ServerUrl "http://127.0.0.1:$BasePort" -MessagesJson (ConvertTo-Json -InputObject $obj.messages -Depth 10 -Compress) -MaxTokens $obj.max_tokens -SeedVal $obj.seed
            $t = Get-Stage29ResponseStats -Resp $resp
            $row = [pscustomobject]@{ request_id = $obj.request_id; cache_class = $obj.cache_class; cache_n = $t.cache_n; prompt_n = $t.prompt_n; predicted_n = $t.predicted_n; prompt_ms = $t.prompt_ms; cache_n_ratio = if ($t.prompt_n -gt 0) { [math]::Round($t.cache_n / $t.prompt_n, 4) } else { 0 }; cache_hit = ($t.cache_n -gt 0); http_status = 200 }
            [void]$reqOut.Add(($row | ConvertTo-Json -Compress))
            if ($counts.ContainsKey($obj.cache_class)) { $counts[$obj.cache_class]++ }
        }
        [System.IO.File]::WriteAllText($reqPath, ($reqOut -join "`n"), $utf8)
        $afterSnap = Read-Stage29MetricSnapshot -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $afterPath
        $hitDelta = (Get-Stage29CounterDelta -Before $beforeSnap.Snapshot -After $afterSnap.Snapshot -CounterName 'llamacpp:cache_hits_total').delta
        $missDelta = (Get-Stage29CounterDelta -Before $beforeSnap.Snapshot -After $afterSnap.Snapshot -CounterName 'llamacpp:cache_misses_total').delta
        $under = Select-String -Path $afterPath -Pattern '^llamacpp_cache_' | Measure-Object
        Write-Stage29EvidenceRow -SummaryPath (Join-Path $RunRoot 'summary.json') -Row @{ cycle = $Cycle; mode = $Mode; phase = $Phase; cache_class_counts = $counts; hit_delta = $hitDelta; miss_delta = $missDelta; underscore_format_lines = $under.Count; status = if ($under.Count -gt 0) { 'FAIL-metric-format-regression' } else { 'PASS' } }
    } finally {
        Stop-Stage29Server $proc
        Wait-Stage29VramBaseline -BaselineMiB 0 -ToleranceMiB 200 -MaxWaitSec 120 -SleepSec 30 | Out-Null
    }
}

function Write-Stage29Report {
    $summaryPath = Join-Path $RunRoot 'summary.json'
    if (-not (Test-Path $summaryPath)) { return }
    $s = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json
    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in @('# Stage 29 Cache Modes Comparison Report', '', "Run: $RunId", '', '## Per-leg summary', '', '| cycle | mode | phase | hit_delta | miss_delta | status |', '| ---: | --- | --- | ---: | ---: | --- |')) {
        [void]$lines.Add($line)
    }
    foreach ($r in $s.rows) { [void]$lines.Add(("| {0} | {1} | {2} | {3} | {4} | {5} |" -f $r.cycle, $r.mode, $r.phase, $r.hit_delta, $r.miss_delta, $r.status)) }
    [void]$lines.Add(''); [void]$lines.Add('## Decision-support'); [void]$lines.Add(''); [void]$lines.Add('Q1..Q5 verdict is computed at QA execution from the per-leg evidence rows.')
    Write-Stage29Text -Path $ReportPath -Text ($lines -join "`n")
}

function Main {
    if (-not $RunRoot)   { $RunRoot = Join-Path $repoRoot "._test_output\$RunId" }
    if (-not $ReportPath) { $ReportPath = Join-Path $repoRoot "._design_docs\.test_reports\test-report-$(Get-Date -Format 'yyyyMMdd')-01-stage29-01.md" }
    New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null
    $preflight = Invoke-Preflight
    if ($DryRun) { Write-Output ("DryRun preflight: " + ($preflight | ConvertTo-Json -Compress)); exit 0 }
    if ($OutputEquivalenceOnly) {
        try {
            $result = Invoke-Phase1OutputEquivalence
            Write-Output ("OutputEquivalence status=" + $result.Status + " mismatch=" + $result.MismatchCount)
            if ($result.Status -ne 'PASS') { [Environment]::Exit(3) }
        } catch {
            $msg = $_.Exception.Message
            Write-Output ("BLOCKED-server-not-running: " + $msg)
            [Environment]::Exit(4)
        }
        [Environment]::Exit(0)
    }
    if ($preflight.status -ne 'PASS') { Write-Error ("BLOCKED-preflight: " + ($preflight | ConvertTo-Json -Compress)); exit 2 }
    $wl = Invoke-Phase05WorkloadBuild
    $wlPath = ([string]$wl.workload).TrimStart()
    $eqPath = ([string]$wl.equivalence).TrimStart()
    Write-Output ("Workload built at " + $wlPath)
    try {
        $eq = Invoke-Phase1OutputEquivalence
    } catch {
        $msg = $_.Exception.Message
        Write-Error ("BLOCKED-server-not-running: " + $msg)
        exit 4
    }
    Write-Output ("OutputEquivalence status=" + $eq.Status + " mismatch=" + $eq.MismatchCount)
    if ($eq.Status -ne 'PASS') { Write-Error ("BLOCKED-output-equivalence: " + ($eq | ConvertTo-Json -Compress)); exit 5 }
    Invoke-CycleLeg -Cycle 1 -Mode 'legacy' -WorkloadPath $wlPath -Phase 'cold-start'
    Invoke-CycleLeg -Cycle 1 -Mode 'hybrid' -WorkloadPath $wlPath -Phase 'cold-start'
    for ($c = 1; $c -le $Cycles; $c++) {
        Invoke-CycleLeg -Cycle $c -Mode 'legacy' -WorkloadPath $wlPath -Phase 'warm'
        Invoke-CycleLeg -Cycle $c -Mode 'hybrid' -WorkloadPath $wlPath -Phase 'warm'
    }
    Write-Stage29Report
    Write-Output ("Report emitted to $ReportPath")
}

Main
