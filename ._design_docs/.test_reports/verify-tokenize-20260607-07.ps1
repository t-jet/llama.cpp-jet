#requires -Version 5
# Tokenize verification for the 19 base drivers and the new helper.
# Does NOT run the drivers; only parses them with [System.Management.Automation.PSParser]::Tokenize.

$ErrorActionPreference = 'Stop'

$scriptDir  = $PSScriptRoot
$srcRoot    = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$helperPath = Join-Path $srcRoot '._design_docs\cache-handling-test-scripts\lib\Read-GgufChatTemplate.ps1'
$scriptRoot = Join-Path $srcRoot '._design_docs\cache-handling-test-scripts'

$drivers = @(
    'stress\stress_s12_s01_budget_exhaustion.ps1'
    'stress\stress_s12_s02_concurrent_multi_slot.ps1'
    'stress\stress_s12_s03_large_branch_forests.ps1'
    'stress\stress_s12_s04_prompt_storms.ps1'
    'stress\stress_s12_s05_mixed_workload_profiles.ps1'
    'stress\stress_s12_s06_cold_queue_pressure.ps1'
    'stress\stress_s12_s07_protected_root_pressure.ps1'
    'stress\stress_s12_s08_integrity_failure_under_load.ps1'
    'bench\bench_s12_b01_exact_blob_hit_rate.ps1'
    'bench\bench_s12_b02_checkpoint_hit_rate.ps1'
    'bench\bench_s12_b03_cold_transition_frequency.ps1'
    'bench\bench_s12_b04_end_to_end_token_throughput.ps1'
    'bench\bench_s12_b05_restore_latency.ps1'
    'bench\bench_s12_b06_prompt_storm_efficiency.ps1'
    'bench\bench_s12_b07_mixed_profile_comparison.ps1'
    'bench\bench_s12_b08_large_forest_lookup_cost.ps1'
    'longrun\longrun_s12_l01_6h_hybrid_stability.ps1'
    'longrun\longrun_s12_l02_30m_legacy_comparison.ps1'
    'longrun\longrun_s12_l03_2h_mixed_workload.ps1'
)

$paths = @($helperPath)
foreach ($d in $drivers) { $paths += (Join-Path $scriptRoot $d) }

$allPass = $true
$rows = @()
foreach ($p in $paths) {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$null, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        $allPass = $false
        $rows += [pscustomobject]@{ File = $p; Errors = $errs.Count; FirstError = $errs[0].Message; Status = 'FAIL' }
    } else {
        $rows += [pscustomobject]@{ File = $p; Errors = 0; FirstError = ''; Status = 'PASS' }
    }
}

$rows | Format-Table -AutoSize | Out-String | Write-Host
"total=$($rows.Count) pass=$(@($rows | Where-Object Status -eq PASS).Count) fail=$(@($rows | Where-Object Status -eq FAIL).Count)"
if (-not $allPass) { exit 1 } else { exit 0 }
