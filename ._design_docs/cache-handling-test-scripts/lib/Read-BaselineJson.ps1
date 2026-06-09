#requires -Version 5
# Read-BaselineJson.ps1
# Stage 12 baseline JSON reader.
# Reads a baseline.json or legacy-baseline.json file produced by the
# benchmark scripts and returns it as a hashtable. Returns $null if the
# file is missing or malformed. The shape matches the design part-04
# baseline JSON fields:
#   commit_sha, dirty_worktree, build_type, binary_timestamp,
#   host_hardware, model_fixture, slot_count, ctx_size, draft_mode,
#   server_flags, prompt_seed, warmup_window, measurement_window,
#   request_count, throughput, p50_latency_ms, p95_latency_ms,
#   p99_latency_ms, exact_hit_rate, checkpoint_hit_rate,
#   restore_latency_by_kind, demotion_count, promotion_count,
#   eviction_count, workingset_samples, handle_samples,
#   correctness_verdict
#
# Usage:
#   . $PSScriptRoot\Read-BaselineJson.ps1
#   $b = Read-BaselineJson -Path <path>
#   if ($null -eq $b) { ... } else { $b.throughput }

param()

function Read-BaselineJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $raw  = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        $conv = $raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
        return $null
    }

    $h = @{}
    foreach ($prop in $conv.PSObject.Properties) {
        $h[$prop.Name] = $prop.Value
    }
    return $h
}

