<#
Stage 21 heavy tier runner for TP-21-HV1/TP-21-HV2.

Default mode runs the binding HV-chat-feasible profile:
- Qwen3.6-27B-MTP, -c 2048, -np 1, --cache-ram 2048
- mixed chat workload: originals, near-prefix variants, new prompts, repeats
- redacted prompt evidence, metrics scrape, request/response JSON, summary JSON

Use -DryRun for contract checks without launching llama-server.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('TP-21-HV1','TP-21-HV2')]
    [string[]] $RowsToRun = @('TP-21-HV1','TP-21-HV2'),

    [Parameter(Mandatory=$true)]
    [string] $CacheColdPath,

    [Parameter(Mandatory=$false)]
    [int] $CacheColdMaxMib = 4096,

    [Parameter(Mandatory=$false)]
    [int] $CacheRamMib = 2048,

    [Parameter(Mandatory=$false)]
    [int] $CtxSize = 2048,

    [Parameter(Mandatory=$false)]
    [int] $NParallel = 1,

    [Parameter(Mandatory=$false)]
    [int] $BasePort = 8930,

    [Parameter(Mandatory=$false)]
    [int] $TimeBudgetMin = 60,

    [Parameter(Mandatory=$false)]
    [int] $RequestsPerRow = 30,

    [Parameter(Mandatory=$false)]
    [int] $RequestTimeoutSec = 120,

    [Parameter(Mandatory=$false)]
    [string] $Stage16AnalysisPath = 'd:\source\llama.cpp-jet\._design_docs\cache-handling-phase16-implementation\part-09-model-log-analysis.md',

    [Parameter(Mandatory=$false)]
    [string] $Stage20ReportPath = 'd:\source\llama.cpp-jet\._design_docs\.test_reports\stage20-heavy-20260618-01.md',

    [Parameter(Mandatory=$false)]
    [string] $EvidenceDir,

    [Parameter(Mandatory=$false)]
    [string] $ChatTemplateFile,

    [Parameter(Mandatory=$false)]
    [string] $ChatTemplateOverrideReason,

    [Parameter(Mandatory=$false)]
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$script:StageRunName = "stage21-heavy-$(Get-Date -Format 'yyyyMMdd')-01"
if ([string]::IsNullOrWhiteSpace($EvidenceDir)) {
    $EvidenceDir = "d:\source\llama.cpp-jet\._test_output\$script:StageRunName"
}
if ($ChatTemplateFile -and [string]::IsNullOrWhiteSpace($ChatTemplateOverrideReason)) {
    throw "ChatTemplateOverrideReason is required when ChatTemplateFile is set"
}

$script:RunId = Get-Date -Format 'yyyyMMdd-HHmmss'
$script:EvidencePath = Join-Path $EvidenceDir $script:RunId
New-Item -ItemType Directory -Force -Path $script:EvidencePath | Out-Null

function Write-SideLog {
    param([string]$Message)
    $logLine = "$(Get-Date -Format 'HH:mm:ss') $Message"
    Write-Host $logLine
    Add-Content -Path (Join-Path $script:EvidencePath 'side.log') -Value $logLine
}

function Get-Sha256Hex {
    param([string]$Value)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
    $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
    return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
}

function Get-ServerHealth {
    param([int]$Port, [int]$MaxWaitSec = 240)
    for ($i = 0; $i -lt $MaxWaitSec; $i++) {
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -ErrorAction Stop -TimeoutSec 5
            return $r.StatusCode
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    return 0
}

function Stop-ServerCleanly {
    param([int]$Port)
    $proc = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($proc) {
        $p = Get-Process -Id $proc.OwningProcess -ErrorAction SilentlyContinue
        if ($p) {
            Write-SideLog "Stopping PID $($p.Id) on port $Port"
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
    }
    Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

function New-Stage21Prompt {
    param([string]$Label, [string]$Class)
    $topic = switch -Regex ($Label) {
        '^A' { 'release checklist for a cache-aware code review'; break }
        '^B' { 'incident note for a bounded cache restore miss'; break }
        '^C' { 'operator runbook for redacted cache evidence'; break }
        '^D' { 'short comparison of hot and cold cache budgets'; break }
        default { 'QA note for exact-repeat verification'; break }
    }
    if ($Class -eq 'near-prefix') {
        return "Write two compact bullets about the $topic, then add one caveat about unsafe prefix reuse."
    }
    return "Write two compact bullets about the $topic. Keep the answer factual."
}

function Get-Stage21Workload {
    $rows = @(
        @{ id = 1; label = 'A-original'; class = 'exact-original' },
        @{ id = 2; label = 'B-original'; class = 'exact-original' },
        @{ id = 3; label = 'C-original'; class = 'exact-original' },
        @{ id = 4; label = 'A-near'; class = 'near-prefix' },
        @{ id = 5; label = 'B-near'; class = 'near-prefix' },
        @{ id = 6; label = 'D-new'; class = 'new-prompt' },
        @{ id = 7; label = 'E-new'; class = 'new-prompt' },
        @{ id = 8; label = 'A-repeat'; class = 'exact-repeat' },
        @{ id = 9; label = 'B-repeat'; class = 'exact-repeat' },
        @{ id = 10; label = 'C-repeat'; class = 'exact-repeat' }
    )
    foreach ($row in $rows) {
        $prompt = New-Stage21Prompt -Label $row.label -Class $row.class
        $row.prompt_sha256 = Get-Sha256Hex $prompt
        $row.prompt = $prompt
    }
    return $rows
}

function Get-Stage21ServerArgs {
    param([int]$Port, [string]$OutDir)
    $serverArgs = @(
        '--port', $Port,
        '--model', 'd:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf',
        '--cache-mode', 'hybrid',
        '--cache-cold-path', $CacheColdPath,
        '--cache-cold-max-mib', $CacheColdMaxMib,
        '--cache-ram', $CacheRamMib,
        '--cache-prompt-evidence', 'redacted',
        '--cache-prompt-evidence-dir', $OutDir,
        '-c', $CtxSize,
        '-np', $NParallel,
        '--jinja',
        '--metrics',
        '--temp', '0',
        '--seed', '42'
    )
    if ($ChatTemplateFile) {
        $serverArgs += @('--chat-template-file', $ChatTemplateFile)
    }
    return $serverArgs
}

function Write-MetricsScrape {
    param([int]$Port, [string]$Path, [string]$Label)
    try {
        Invoke-WebRequest -Uri "http://127.0.0.1:$Port/metrics" -UseBasicParsing -ErrorAction Stop -TimeoutSec 10 |
            Select-Object -ExpandProperty Content |
            Out-File -FilePath $Path -Encoding utf8
        return @{ status = 'OK'; path = $Path }
    } catch {
        Write-SideLog "$Label metrics scrape failed: $($_.Exception.Message)"
        return @{ status = 'BLOCKED-metric-unavailable'; path = $Path; error = $_.Exception.Message }
    }
}

function Read-PromptEvidence {
    param([string]$OutDir, [array]$Workload)
    $files = Get-ChildItem -Path $OutDir -Filter '*.jsonl' -File -ErrorAction SilentlyContinue
    $result = @{
        status = if ($files.Count -gt 0) { 'OK' } else { 'BLOCKED-metric-unavailable' }
        files = @($files | ForEach-Object { $_.FullName })
        records = 0
        lookup_outcomes = @{}
        prefix_candidate_records = 0
        redaction_leak = $false
    }
    foreach ($file in $files) {
        foreach ($line in Get-Content -Path $file.FullName -ErrorAction SilentlyContinue) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $result.records++
            foreach ($item in $Workload) {
                if ($line.Contains($item.prompt)) { $result.redaction_leak = $true }
            }
            try {
                $record = $line | ConvertFrom-Json
                if ($record.lookup_outcome) {
                    $key = [string]$record.lookup_outcome
                    if (-not $result.lookup_outcomes.ContainsKey($key)) { $result.lookup_outcomes[$key] = 0 }
                    $result.lookup_outcomes[$key]++
                }
                if ($record.prefix_candidate -or $record.prefix_candidates -or $record.prefix_candidate_count) {
                    $result.prefix_candidate_records++
                }
            } catch {
                if (-not $result.lookup_outcomes.ContainsKey('parse_error')) { $result.lookup_outcomes.parse_error = 0 }
                $result.lookup_outcomes.parse_error++
            }
        }
    }
    return $result
}

function Get-HV1Verdict {
    param([array]$Requests, [hashtable]$MetricsBefore, [hashtable]$MetricsAfter, [hashtable]$PromptEvidence)
    $exactRepeats = @($Requests | Where-Object { $_.request_class -eq 'exact-repeat' })
    $near = @($Requests | Where-Object { $_.request_class -eq 'near-prefix' })
    $newPrompts = @($Requests | Where-Object { $_.request_class -eq 'new-prompt' })
    $httpFailures = @($Requests | Where-Object { $_.http_status -ne 200 -and $_.http_status -ne 'DRYRUN' })
    $nearHits = @($near | Where-Object { $_.cache_n -gt 0 })
    $exactHits = @($exactRepeats | Where-Object { $_.cache_n -gt 0 })

    $reasons = @()
    if ($httpFailures.Count -gt 0) { $reasons += 'http-failure' }
    if ($nearHits.Count -gt 0) { $reasons += 'unsafe-prefix-hit' }
    if ($PromptEvidence.redaction_leak) { $reasons += 'redaction-leak' }
    if ($Requests.Count -gt 0 -and $exactHits.Count -eq 0) { $reasons += 'exact-repeat-no-hit' }

    $coldEviction = 'not-observed'
    if ($MetricsAfter.status -eq 'OK' -and (Test-Path $MetricsAfter.path)) {
        $evictionLine = Select-String -Path $MetricsAfter.path -Pattern 'cache_cold_evictions_total' | Select-Object -First 1
        if ($evictionLine) {
            $coldEviction = 'observed-metric-row'
        }
    }

    $status = if ($Requests.Count -eq 0 -and $DryRun) { 'DRYRUN' } elseif ($reasons.Count -eq 0) { 'PASS-candidate' } else { 'FAIL-candidate' }
    return @{
        status = $status
        reasons = $reasons
        exact_repeat_hits = $exactHits.Count
        near_prefix_hits = $nearHits.Count
        new_prompt_count = $newPrompts.Count
        metrics_before = $MetricsBefore.status
        metrics_after = $MetricsAfter.status
        prompt_evidence = $PromptEvidence.status
        cold_eviction_pressure = $coldEviction
    }
}

function Start-HV1Row {
    param([int]$Port, [int]$TimeBudgetSec, [string]$OutDir)
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $serverOut = Join-Path $OutDir 'server.out.log'
    $serverErr = Join-Path $OutDir 'server.err.log'
    $metricsBefore = Join-Path $OutDir 'metrics-before.txt'
    $metricsAfter = Join-Path $OutDir 'metrics-after.txt'
    Remove-Item $serverOut, $serverErr -ErrorAction SilentlyContinue

    $serverArgs = Get-Stage21ServerArgs -Port $Port -OutDir $OutDir
    $workload = Get-Stage21Workload
    Write-SideLog "TP-21-HV1 launch profile: port=$Port ctx=$CtxSize np=$NParallel cache-ram=$CacheRamMib cold-max-mib=$CacheColdMaxMib timeout-sec=$RequestTimeoutSec"
    if ($ChatTemplateFile) {
        Write-SideLog "TP-21-HV1 template override: $ChatTemplateFile reason=$ChatTemplateOverrideReason"
    } else {
        Write-SideLog "TP-21-HV1 template mode: built-in GGUF chat template"
    }

    if ($DryRun) {
        Write-SideLog "DRYRUN: would launch llama-server with: $($serverArgs -join ' ')"
        $dryRequests = @()
        foreach ($item in $workload) {
            $dryRequests += @{
                request_id = ('req-{0:D3}' -f $item.id)
                request_class = $item.class
                label = $item.label
                http_status = 'DRYRUN'
                cache_n = $null
                prompt_n = $null
                duration_ms = 0
                prompt_sha256 = $item.prompt_sha256
                request_body_sha256 = $null
                verdict_contribution = 'dry-run-only'
            }
        }
        $summary = @{
            row = 'TP-21-HV1'
            status = 'DRYRUN'
            server_args = $serverArgs
            required_flags_checked = Test-Stage21Flags -ServerArgs $serverArgs
            request_timeout_sec = $RequestTimeoutSec
            requests = $dryRequests
            verdict = @{ status = 'DRYRUN'; cold_eviction_pressure = 'not-observed' }
        }
        $summary | ConvertTo-Json -Depth 8 | Out-File (Join-Path $OutDir 'summary.json') -Encoding utf8
        return $summary
    }

    $proc = Start-Process -FilePath 'd:\source\llama.cpp-jet\build-cov\bin\Release\llama-server.exe' `
        -ArgumentList $serverArgs `
        -RedirectStandardOutput $serverOut `
        -RedirectStandardError $serverErr `
        -PassThru -WindowStyle Hidden

    Write-SideLog "TP-21-HV1 launched PID $($proc.Id)"
    $health = Get-ServerHealth -Port $Port -MaxWaitSec 240
    if ($health -ne 200) {
        Write-SideLog "TP-21-HV1 failed health wait: HTTP $health"
        Stop-ServerCleanly -Port $Port
        return @{ row='TP-21-HV1'; status='FAIL-health'; requests=@(); health=$health }
    }

    $before = Write-MetricsScrape -Port $Port -Path $metricsBefore -Label 'TP-21-HV1 before'
    $deadline = (Get-Date).AddSeconds($TimeBudgetSec)
    $requests = @()
    $requestNum = 0
    while ((Get-Date) -lt $deadline -and $requestNum -lt $RequestsPerRow) {
        $item = $workload[$requestNum % $workload.Count]
        $requestNum++
        $payloadObject = @{
            model = 'any'
            messages = @(@{ role = 'user'; content = $item.prompt })
            max_tokens = 60
            temperature = 0
            seed = 42
        }
        $payload = $payloadObject | ConvertTo-Json -Depth 6 -Compress
        $requestBase = "req-{0:D3}-{1}" -f $requestNum, $item.label
        $payloadObject | ConvertTo-Json -Depth 6 | Out-File (Join-Path $OutDir "$requestBase-request.json") -Encoding utf8
        $reqStart = Get-Date
        $row = @{
            request_id = ('req-{0:D3}' -f $requestNum)
            request_class = $item.class
            label = $item.label
            prompt_sha256 = $item.prompt_sha256
            request_body_sha256 = Get-Sha256Hex $payload
        }
        try {
            $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/v1/chat/completions" `
                -Method POST -ContentType 'application/json' -Body $payload `
                -UseBasicParsing -ErrorAction Stop -TimeoutSec $RequestTimeoutSec
            $reqEnd = Get-Date
            $resp = $r.Content | ConvertFrom-Json
            $row.http_status = $r.StatusCode
            $row.cache_n = [int]$resp.timings.cache_n
            $row.prompt_n = [int]$resp.timings.prompt_n
            $row.duration_ms = [int](($reqEnd - $reqStart).TotalMilliseconds)
            $row.verdict_contribution = if ($item.class -eq 'near-prefix' -and $row.cache_n -gt 0) { 'FAIL-unsafe-prefix-hit' } elseif ($item.class -eq 'exact-repeat' -and $row.cache_n -gt 0) { 'PASS-exact-repeat-hit' } else { 'evidence' }
            $resp | ConvertTo-Json -Depth 10 | Out-File (Join-Path $OutDir "$requestBase-response.json") -Encoding utf8
            Write-SideLog "TP-21-HV1 req $requestNum [$($item.label) $($item.class)] HTTP $($r.StatusCode) cache_n=$($row.cache_n) prompt_n=$($row.prompt_n) duration=$($row.duration_ms)ms"
        } catch {
            $row.http_status = 0
            $row.cache_n = 0
            $row.prompt_n = 0
            $row.duration_ms = [int](((Get-Date) - $reqStart).TotalMilliseconds)
            $row.error = $_.Exception.Message
            $row.verdict_contribution = 'FAIL-request-error'
            Write-SideLog "TP-21-HV1 req $requestNum [$($item.label) $($item.class)] failed: $($_.Exception.Message)"
        }
        $requests += $row
        Start-Sleep -Seconds 1
    }

    $after = Write-MetricsScrape -Port $Port -Path $metricsAfter -Label 'TP-21-HV1 after'
    $promptEvidence = Read-PromptEvidence -OutDir $OutDir -Workload $workload
    Stop-ServerCleanly -Port $Port
    $verdict = Get-HV1Verdict -Requests $requests -MetricsBefore $before -MetricsAfter $after -PromptEvidence $promptEvidence
    $summary = @{
        row = 'TP-21-HV1'
        status = 'OK'
        request_timeout_sec = $RequestTimeoutSec
        requests = $requests
        prompt_evidence = $promptEvidence
        verdict = $verdict
    }
    $summary | ConvertTo-Json -Depth 8 | Out-File (Join-Path $OutDir 'summary.json') -Encoding utf8
    return $summary
}

function Test-Stage21Flags {
    param([array]$ServerArgs)
    $joined = " $($ServerArgs -join ' ') "
    $checks = [ordered]@{
        cache_mode_hybrid = $joined.Contains(' --cache-mode hybrid ')
        cache_cold_path = $joined.Contains(' --cache-cold-path ')
        cache_cold_max_mib_4096 = $joined.Contains(' --cache-cold-max-mib 4096 ')
        cache_ram_2048 = $joined.Contains(' --cache-ram 2048 ')
        redacted_evidence = $joined.Contains(' --cache-prompt-evidence redacted ')
        evidence_dir = $joined.Contains(' --cache-prompt-evidence-dir ')
        metrics = $joined.Contains(' --metrics ')
        ctx_2048 = $joined.Contains(' -c 2048 ')
        np_1 = $joined.Contains(' -np 1 ')
        jinja = $joined.Contains(' --jinja ')
        built_in_template_default = -not $joined.Contains(' --chat-template-file ')
    }
    return $checks
}

function Start-HV2Row {
    param([string]$OutDir)
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $stage16Exists = Test-Path $Stage16AnalysisPath
    $stage20Exists = Test-Path $Stage20ReportPath
    $comparison = @{
        row = 'TP-21-HV2'
        stage16_analysis_path = $Stage16AnalysisPath
        stage16_analysis_status = if ($stage16Exists) { 'OK' } else { 'BLOCKED-baseline-missing' }
        stage20_report_path = $Stage20ReportPath
        stage20_report_status = if ($stage20Exists) { 'OK' } else { 'BLOCKED-prerequisite' }
        stage21_summary_path = Join-Path (Join-Path (Split-Path $OutDir -Parent) 'hv1') 'summary.json'
        differences = @()
    }
    if ($stage16Exists) {
        $stage16ZeroRefs = (Select-String -Path $Stage16AnalysisPath -Pattern 'cache_n=0','cache_n = 0','"cache_n":0' -SimpleMatch | Measure-Object).Count
        $comparison.differences += @{ source='Stage 16'; item='cache_n=0 references'; value=$stage16ZeroRefs; classification='baseline' }
    }
    if ($stage20Exists) {
        $stage20Text = Get-Content -Path $Stage20ReportPath -Raw
        $classification = if ($stage20Text.Contains('cache_n=0')) { 'expected-baseline' } else { 'inconclusive' }
        $comparison.differences += @{ source='Stage 20'; item='heavy report cache_n=0 pattern'; classification=$classification }
    }
    if (Test-Path $comparison.stage21_summary_path) {
        $hv1 = Get-Content -Path $comparison.stage21_summary_path -Raw | ConvertFrom-Json
        if ($hv1.status -eq 'DRYRUN') {
            $exactHits = 'DRYRUN'
            $classification = 'inconclusive'
        } else {
            $exactHits = $hv1.verdict.exact_repeat_hits
            $classification = if ($exactHits -gt 0) { 'improved' } else { 'inconclusive' }
        }
        $comparison.differences += @{ source='Stage 21'; item='exact repeat hit count'; value=$exactHits; classification=$classification }
    } elseif ($DryRun) {
        $comparison.differences += @{ source='Stage 21'; item='exact repeat hit count'; value='DRYRUN'; classification='inconclusive' }
    } else {
        $comparison.differences += @{ source='Stage 21'; item='HV1 summary missing'; classification='BLOCKED-runner-contract' }
    }
    $comparison.status = if ($stage16Exists -and $stage20Exists) { 'OK' } else { 'BLOCKED' }
    $comparison | ConvertTo-Json -Depth 6 | Out-File (Join-Path $OutDir 'comparison.json') -Encoding utf8
    return $comparison
}

Write-SideLog "Stage 21 heavy tier runner starting"
Write-SideLog "RunId: $script:RunId"
Write-SideLog "Evidence path: $script:EvidencePath"
Write-SideLog "Rows to run: $($RowsToRun -join ', ')"
Write-SideLog "Time budget per row: $TimeBudgetMin min"
Write-SideLog "Requests per row: $RequestsPerRow"
Write-SideLog "Request timeout: $RequestTimeoutSec sec"
Write-SideLog "Workload: 10 prompts (3 originals, 2 near-prefix, 2 new, 3 repeats)"

$summary = @{
    stage = 21
    run_name = $script:StageRunName
    run_id = $script:RunId
    evidence_path = $script:EvidencePath
    dry_run = [bool]$DryRun
    rows = @{}
}

if ('TP-21-HV1' -in $RowsToRun) {
    $hv1Dir = Join-Path $script:EvidencePath 'hv1'
    $summary.rows['TP-21-HV1'] = Start-HV1Row -Port $BasePort -TimeBudgetSec ($TimeBudgetMin * 60) -OutDir $hv1Dir
}

if ('TP-21-HV2' -in $RowsToRun) {
    $hv2Dir = Join-Path $script:EvidencePath 'hv2'
    $summary.rows['TP-21-HV2'] = Start-HV2Row -OutDir $hv2Dir
}

$summary | ConvertTo-Json -Depth 10 | Out-File (Join-Path $script:EvidencePath 'summary.json') -Encoding utf8

Write-SideLog "Stage 21 heavy tier runner complete"
Write-SideLog "Summary written to $(Join-Path $script:EvidencePath 'summary.json')"

return $summary
