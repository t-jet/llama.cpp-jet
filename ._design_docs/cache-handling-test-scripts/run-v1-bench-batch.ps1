#requires -Version 5
# run-v1-bench-batch.ps1
# Stage 12 V1 session bench rows (1-min each, sequential via &).
# 16 rows: 8 bench (b01..b08) x 2 jinja variants.
# Uses direct & invocation to avoid Start-Process / AppExecAlias issues.
# Evidence root:
#   ._design_docs/.test_reports/mtp-jinja-run-20260607-V1/S12-MTP-{BASE}-V1-J{var}/

param(
    [string] $BuildDir  = 'D:\source\llama.cpp-jet\build-cov',
    [string] $ModelPath = 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf',
    [string] $RunRoot   = 'D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1',
    [string] $ScriptDir = 'D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts',
    [string] $SummaryLog = ''
)

$ErrorActionPreference = 'Continue'
# bench script name -> full filename map (descriptive suffixes differ per row)
$rowMap = @{
    'b01' = 'bench_s12_b01_exact_blob_hit_rate.ps1'
    'b02' = 'bench_s12_b02_checkpoint_hit_rate.ps1'
    'b03' = 'bench_s12_b03_cold_transition_frequency.ps1'
    'b04' = 'bench_s12_b04_end_to_end_token_throughput.ps1'
    'b05' = 'bench_s12_b05_restore_latency.ps1'
    'b06' = 'bench_s12_b06_prompt_storm_efficiency.ps1'
    'b07' = 'bench_s12_b07_mixed_profile_comparison.ps1'
    'b08' = 'bench_s12_b08_large_forest_lookup_cost.ps1'
}
$rows = @('b01','b02','b03','b04','b05','b06','b07','b08')
$variants = @('original','marked')

if (-not $SummaryLog) { $SummaryLog = Join-Path $RunRoot 'bench-batch-summary.log' }
$parentPipeFile = "$SummaryLog.parent"
$useSideLog = Test-Path $parentPipeFile
if ($useSideLog) { $SummaryLog = "$SummaryLog.side" }
if (-not (Test-Path $RunRoot)) { New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null }

$globalIndex = 0
$results = @()
foreach ($b in $rows) {
    foreach ($v in $variants) {
        $globalIndex++
        $baseUpper = $b.ToUpper()
        $rowId  = "S12-MTP-$baseUpper-V1-J$v"
        $evDir  = Join-Path $RunRoot $rowId
        if (-not (Test-Path $evDir)) { New-Item -ItemType Directory -Force -Path $evDir | Out-Null }
        $scriptPath = Join-Path $ScriptDir "bench\$($rowMap[$b])"
        $port       = 8310 + [int]$b.Substring(1) + ($(if ($v -eq 'marked') { 16 } else { 0 }))

        "$globalIndex] $rowId start port=$port $(Get-Date -Format 'o')" | Out-File -FilePath $SummaryLog -Append -Encoding utf8
        Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1

        $out = & $scriptPath `
            -BuildDir     $BuildDir `
            -ModelPath    $ModelPath `
            -OutDir       $evDir `
            -Port         $port `
            -MtpVariant   1 `
            -JinjaVariant $v 2>&1 | Out-String
        $rc = $LASTEXITCODE

        Get-Process -Name llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1

        $live = Join-Path $evDir 'live.log'
        $out | Out-File -FilePath $live -Append -Encoding utf8
        "rc=$rc end $(Get-Date -Format 'o')" | Out-File -FilePath $live -Append -Encoding utf8
        "$v" | Out-File -FilePath (Join-Path $evDir 'jinja-variant.txt') -Encoding utf8
        '1'  | Out-File -FilePath (Join-Path $evDir 'mtp-variant.txt')   -Encoding utf8
        $jinjaFile = if ($v -eq 'marked') { 'chat_template_new.jinja' } else { 'chat_template.jinja' }
        $jinjaAbs  = Join-Path (Split-Path $ModelPath -Parent) $jinjaFile
        $jinjaAbs  | Out-File -FilePath (Join-Path $evDir 'jinja-path.txt') -Encoding utf8

        "$rowId rc=$rc" | Out-File -FilePath $SummaryLog -Append -Encoding utf8
        $results += [pscustomobject]@{ Row=$rowId; Rc=$rc }
    }
}

"bench batch complete $(Get-Date -Format 'o')" | Out-File -FilePath $SummaryLog -Append -Encoding utf8
$results | Format-Table -AutoSize | Out-String | Out-File -FilePath $SummaryLog -Append -Encoding utf8
