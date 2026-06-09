#requires -Version 5
# run-v2-bench-batch.ps1
# QA V1 follow-up batch runner for B01..B08 x 2 jinja = 16 rows.
# Uses -MtpVariant=1, -JinjaVariant=original|marked, V1 fixture.
# Re-runs B01 and B02 with the Developer fixes (k6 prefix_match_rate
# threshold; B02 MtpVariant fixture switch). Per-row timeout 600000 ms.
# Writes per-row start/end and verdict to the session side log.
# Verdict read from hybrid/evidence-summary.md ## Verdict (not $LASTEXITCODE).
#
# IMPORTANT: uses hashtable splat (@splat) not array splat (@argList).
# Array splat with -Name Value pairs is interpreted positionally in this
# pwsh host and mis-binds -Port to the next -OutDir token, causing
# "Cannot convert -OutDir to System.Int32" and a 0-second "row" that
# does not actually invoke the driver. Hashtable splat is reliable.

param(
    [string] $BuildDir  = 'D:\source\llama.cpp-jet\build-cov',
    [string] $RunRoot   = 'D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1',
    [string] $ModelPath = 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf',
    [int]    $PerRowTimeoutMs = 600000
)

$ErrorActionPreference = 'Continue'
$benchDir = Join-Path $PSScriptRoot 'bench'
$sideLog  = Join-Path $RunRoot   'bench-batch-summary.log.side'
$csvOut   = Join-Path $RunRoot   'bench-batch-verdicts-v2.csv'

$plan = @(
    @{ Id='B01'; Port=8301; Driver='bench_s12_b01_exact_blob_hit_rate.ps1';
       Extra=@{ MeasurementSec=60 } },
    @{ Id='B02'; Port=8302; Driver='bench_s12_b02_checkpoint_hit_rate.ps1';
       Extra=@{} },
    @{ Id='B03'; Port=8303; Driver='bench_s12_b03_cold_transition_frequency.ps1';
       Extra=@{ DurationSec=60 } },
    @{ Id='B04'; Port=8304; Driver='bench_s12_b04_end_to_end_token_throughput.ps1';
       Extra=@{ DurationSec=60 } },
    @{ Id='B05'; Port=8305; Driver='bench_s12_b05_restore_latency.ps1';
       Extra=@{ DurationSec=60 } },
    @{ Id='B06'; Port=8306; Driver='bench_s12_b06_prompt_storm_efficiency.ps1';
       Extra=@{} },
    @{ Id='B07'; Port=8307; Driver='bench_s12_b07_mixed_profile_comparison.ps1';
       Extra=@{ DurationSec=60 } },
    @{ Id='B08'; Port=8308; Driver='bench_s12_b08_large_forest_lookup_cost.ps1';
       Extra=@{ DurationSec=60 } }
)

$env:LLAMA_CACHE_TEST_MODEL = $ModelPath

Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

$results = New-Object System.Collections.Generic.List[object]
$now = Get-Date -Format 'o'
"$now] bench-batch-V2 start; rows=$($plan.Count * 2); perRowTimeoutMs=$PerRowTimeoutMs; model=$ModelPath" |
    Out-File -FilePath $sideLog -Append -Encoding utf8

foreach ($row in $plan) {
    foreach ($jv in @('original','marked')) {
        $rowId = "S12-MTP-$($row.Id)-V1-J$jv"
        $outDir = Join-Path $RunRoot $rowId
        $hybrid = Join-Path $outDir 'hybrid'
        $startIso = (Get-Date).ToString('o')
        $rowPort = $row.Port + $(if ($jv -eq 'marked') { 16 } else { 0 })
        "$startIso] $rowId start port=$rowPort" |
            Out-File -FilePath $sideLog -Append -Encoding utf8

        Get-Process -Name 'llama-server' -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500

        $driver = Join-Path $benchDir $row.Driver
        $splat = @{
            BuildDir     = $BuildDir
            ModelPath    = $ModelPath
            OutDir       = $outDir
            Port         = $rowPort
            MtpVariant   = 1
            JinjaVariant = $jv
        }
        foreach ($k in $row.Extra.Keys) { $splat[$k] = $row.Extra[$k] }

        $rowStart = Get-Date
        try {
            & $driver @splat 2>&1 | Out-Null
        } catch {
            "$startIso] $rowId driver-exception: $($_.Exception.Message)" |
                Out-File -FilePath $sideLog -Append -Encoding utf8
        }
        $rowEnd = Get-Date
        $elapsed = [int]([math]::Round(($rowEnd - $rowStart).TotalSeconds))

        $esPath  = Join-Path $hybrid 'evidence-summary.md'
        $bjPath  = Join-Path $hybrid 'baseline.json'
        $verdict = 'PENDING'
        $notes   = ''
        if (Test-Path $esPath) {
            $rs = Select-String -Path $esPath -Pattern '^Result:\s*(\S+)' -Raw
            if ($rs) { $verdict = ($rs -split ':')[-1].Trim() }
            $ns = Select-String -Path $esPath -Pattern '^Notes:\s*(.+)$' -Raw
            if ($ns) { $notes = ($ns -split ':',2)[-1].Trim() }
        }
        $baseVerdict = ''
        if (Test-Path $bjPath) {
            try { $bj = Get-Content $bjPath -Raw | ConvertFrom-Json -ErrorAction Stop
                  $baseVerdict = [string]$bj.correctness_verdict } catch {}
        }
        $k6pmr = ''
        if ($row.Id -in @('B01','B06')) {
            $k6 = Join-Path $hybrid 'k6-results.json'
            if (Test-Path $k6) {
                $lines = Get-Content $k6 -ErrorAction SilentlyContinue
                $pm = $lines | Where-Object { $_ -match '"metric":"prefix_match_rate"' } | Select-Object -Last 1
                if ($pm) {
                    $vals = ([regex]::Matches($pm, '"value":\s*([0-9.]+)') | ForEach-Object { [double]$_.Groups[1].Value })
                    if ($vals.Count -gt 0) { $k6pmr = ('{0:F4}' -f ($vals | Measure-Object -Average).Average) }
                }
            }
        }
        $results.Add([pscustomobject]@{
            Row = $rowId
            Port = $rowPort
            ElapsedSec = $elapsed
            SummaryVerdict = $verdict
            BaseVerdict = $baseVerdict
            K6PrefixMatchRate = $k6pmr
            Notes = $notes
        })
        $endIso = (Get-Date).ToString('o')
        "$endIso] $rowId end elapsed=${elapsed}s verdict=$verdict base=$baseVerdict pmr=$k6pmr" |
            Out-File -FilePath $sideLog -Append -Encoding utf8
    }
}

$results | Export-Csv -NoTypeInformation -Path $csvOut -Encoding utf8
"$( Get-Date -Format 'o' )] bench-batch-V2 end; csv=$csvOut" |
    Out-File -FilePath $sideLog -Append -Encoding utf8

$results | Format-Table -AutoSize -Property Row, ElapsedSec, SummaryVerdict, BaseVerdict, K6PrefixMatchRate | Out-String -Width 200
"--- per-row notes ---"
$results | ForEach-Object { "$($_.Row): $($_.Notes)" }
