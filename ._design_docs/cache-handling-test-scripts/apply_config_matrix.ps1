#requires -Version 5
# apply_config_matrix.ps1
# Stage 12 config matrix helper.
# Reads the configuration matrix from the implementation plan and
# applies the selected dimension set to a test run config file
# (JSON). QA selects dimensions and values; this helper resolves them
# into a single JSON config that benchmark or stress drivers can read.
#
# Usage:
#   .\apply_config_matrix.ps1 `
#       -MatrixFile <path-to-matrix.json> `
#       -OutFile <path-to-run-config.json>
#
# Matrix file shape (input):
#   {
#     "rows": [
#       {
#         "id": "S12-B04-hybrid",
#         "cache_mode": "hybrid",
#         "hot_budget_mib": 100,
#         "cold_path": "",
#         "slot_count": 1,
#         "ctx_size": 512,
#         "draft_model": "",
#         "prompt_mix": "exact-repeat",
#         "run_length_s": 300
#       }
#     ]
#   }
#
# Output (run config):
#   {
#     "rows": [
#       {
#         "id": "S12-B04-hybrid",
#         "server_flags": ["--cache-mode","hybrid","--cache-ram","100",
#                          "--parallel","1","--ctx-size","512"],
#         "host_args": { "hot_budget_mib":100, "slot_count":1, "ctx_size":512 }
#       }
#     ]
#   }
#
# Cold path is only added when non-empty. Draft model is only added
# when non-empty. All MiB values are integer-only per design part-02.

param(
    [Parameter(Mandatory = $true)] [string] $MatrixFile,
    [Parameter(Mandatory = $true)] [string] $OutFile
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $MatrixFile)) { Write-Error "Matrix file not found: $MatrixFile" }

$matrix = Get-Content -LiteralPath $MatrixFile -Raw | ConvertFrom-Json
if (-not $matrix.rows) { Write-Error "Matrix file has no rows array" }

$outRows = @()
foreach ($r in $matrix.rows) {
    $flags = New-Object System.Collections.Generic.List[string]
    $flags.Add('--cache-mode'); $flags.Add([string]$r.cache_mode)
    $flags.Add('--cache-ram'); $flags.Add([string]([int]$r.hot_budget_mib))
    $flags.Add('--parallel'); $flags.Add([string]([int]$r.slot_count))
    $flags.Add('--ctx-size'); $flags.Add([string]([int]$r.ctx_size))
    if ($r.cold_path -and $r.cold_path.Trim().Length -gt 0) {
        $flags.Add('--cache-cold-path'); $flags.Add([string]$r.cold_path)
    }
    if ($r.draft_model -and $r.draft_model.Trim().Length -gt 0) {
        $flags.Add('--model-draft'); $flags.Add([string]$r.draft_model)
    }
    $outRows += @{
        id          = [string]$r.id
        server_flags = $flags.ToArray()
        host_args   = @{
            hot_budget_mib = [int]$r.hot_budget_mib
            slot_count     = [int]$r.slot_count
            ctx_size       = [int]$r.ctx_size
        }
        prompt_mix   = [string]$r.prompt_mix
        run_length_s = [int]$r.run_length_s
    }
}

$payload = @{ rows = $outRows }
$payload | ConvertTo-Json -Depth 6 | Out-File -FilePath $OutFile -Encoding utf8
Write-Host "Wrote $($outRows.Count) row(s) to $OutFile"
