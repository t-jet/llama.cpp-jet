# Part 4: Per-request metric list

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)

## Metric naming convention

All Prometheus metric names use the post-Stage-26 namespace
`llamacpp:cache_X`. The pre-Stage-26 underscore form (`llamacpp_cache_X`) is
**NOT** accepted. Any leg emitting an underscore-form metric is classified
as `FAIL-metric-format-regression` because Stage 26 alignment closed the
underscore form.

The driver enforces this with a `metrics-format` assertion: a grep for
`^llamacpp_cache_` must return zero matches in any `metrics-after.txt`.

## Per-request metric list

For each request, the driver captures the following:

| Metric | Source | Evidence class | Required |
| --- | --- | --- | --- |
| `wall_clock_ms` | driver, request start to last byte | Direct stats | yes |
| `ttft_ms` | response `timings.prompt_ms` | Direct stats | yes |
| `prompt_n` | response `timings.prompt_n` | Direct stats | yes |
| `predicted_n` | response `timings.predicted_n` | Direct stats | yes |
| `cache_n_tokens` | response `timings.cache_n` | Direct stats | yes |
| `cache_n_ratio` | derived: `cache_n / prompt_n` | Direct stats | yes |
| `cache_hit` | derived: `cache_n > 0` | Direct stats | yes |
| `cache_class` | driver (exact / near_prefix / new_branch) | Direct stats | yes |
| `request_id` | driver | Direct stats | yes |
| `cycle_id` | driver | Direct stats | yes |
| `mode` | driver (legacy / hybrid) | Direct stats | yes |
| `request_status` | HTTP status from driver | Direct stats | yes |
| `error_class` | bounded: timeout, http_500, server_died, none | Direct stats | yes |

## Per-leg Prometheus counter deltas

Captured before the first request and after the last request of each leg:

| Metric | Counter type | Evidence class | Required |
| --- | --- | --- | --- |
| `llamacpp:cache_hits_total` | delta | Public Prometheus | yes |
| `llamacpp:cache_misses_total` | delta | Public Prometheus | yes |
| `llamacpp:cache_fallback_restores_total` | delta | Public Prometheus | yes |
| `llamacpp:cache_exact_blob_restores_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_payload_transitions_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_payload_evictions_by_shape_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_checkpoint_admissions_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_checkpoint_admission_failures_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_descriptor_validation_failures_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_pairing_violations_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_restore_failures_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_payload_demotions_total` | delta | Public Prometheus | hybrid-only |
| `llamacpp:cache_payload_promotions_total` | delta | Public Prometheus | hybrid-only |

For hybrid-only counters, the legacy leg records `0` (counter not emitted
in legacy mode) and the report classifies this as `NOT-APPLICABLE-legacy`,
not as a metric-unavailable block.

## Per-leg Prometheus gauge snapshots

| Metric | Source | Evidence class | Required |
| --- | --- | --- | --- |
| `llamacpp:cold_payload_bytes` | gauge snapshot before/after leg | Public Prometheus | hybrid-only |
| `llamacpp:cold_payload_count` | gauge snapshot before/after leg | Public Prometheus | hybrid-only |
| `llamacpp:cache_hot_payload_descriptors` | gauge snapshot before/after leg | Public Prometheus | hybrid-only |
| `llamacpp:cache_evicted_payload_descriptors` | gauge snapshot before/after leg | Public Prometheus | hybrid-only |

## Ground-truth cross-checks (filesystem)

| Metric | Source | Evidence class | Required |
| --- | --- | --- | --- |
| `cold_store_bytes_on_disk` | `du -sb` on cold dir | Direct stats (ground truth) | hybrid-only |
| `cold_store_file_count` | `find` on cold dir | Direct stats (ground truth) | hybrid-only |
| `cold_store_drift_ratio` | derived: `filesystem_bytes / max(metric_bytes, 1)` | Direct stats (drift signal) | hybrid-only |
| `hot_payload_count_proxy` | count of restored tokens in log per leg | Structured log | hybrid-only |

## Ground-truth cross-checks (process / GPU)

| Metric | Source | Evidence class | Required |
| --- | --- | --- | --- |
| `vram_peak_mib` | `nvidia-smi --query-gpu=memory.used --format=csv,noheader` polled every 5s during leg | Direct stats | yes |
| `vram_baseline_mib` | `nvidia-smi` after server shutdown | Direct stats | yes |
| `cpu_pct_avg` | `Get-Process -Id $pid` CPU sample | Direct stats | yes |
| `ram_mib_peak` | `Get-Process -Id $pid` working set peak | Direct stats | yes |

## Evidence classification summary

Following the Stage 10 / hybrid-cache.md evidence-classification rule:

- **Public Prometheus**: counter deltas and gauge snapshots. Mandatory for
  cache-hit/miss, restore, fallback, eviction, cold-store utilization.

- **Structured log**: restore strategy, fallback reason, unsupported config
  reason. Used as substitute when Prometheus is unavailable.

- **Direct stats**: per-request timings, filesystem bytes, process samples.
  Headline per-request KV-reuse indicators.

- **Harness-only**: prompt-processing time saved (derived), cold-miss vs
  warm-miss latency split. Driver computes these.

## Reconciliation with Stage 26 metric rename

The original proposal listed 7 metrics, several with pre-Stage-26 names:

| Proposal name | Post-Stage-26 name | Action |
| --- | --- | --- |
| `llamacpp:cache_hits_total` | `llamacpp:cache_hits_total` | keep |
| `llamacpp:cache_misses_total` | `llamacpp:cache_misses_total` | keep |
| `cache_exact_blob_restores_total` | `llamacpp:cache_exact_blob_restores_total` | rename |
| `cache_fallback_restores_total` | `llamacpp:cache_fallback_restores_total` | rename |
| `cache_payload_transitions_total` | `llamacpp:cache_payload_transitions_total` | rename |
| `cache_payload_evictions_by_shape_total` | `llamacpp:cache_payload_evictions_by_shape_total` | rename |
| `llamacpp:cold_payload_bytes` | `llamacpp:cold_payload_bytes` | keep |
| `llamacpp:cold_payload_count` | `llamacpp:cold_payload_count` | keep |

This design uses the post-Stage-26 names for all rows. The driver greps
each `metrics-after.txt` for `^llamacpp_` (underscore) and fails the leg
with `FAIL-metric-format-regression` if any underscore-form metric appears.

## Cold-store drift handling

`cold_store_drift_ratio` is the primary drift signal. Per Stage 26 part-04
target, drift ratio should be <= 1.10 after Stage 28 R28-BUG-02 cold-store
reconcile. If drift ratio > 1.10:

- The leg is NOT auto-failed (drift is a quality signal, not a blocker).
- The report records the ratio per leg.
- The report classifies the leg as `OK-with-drift-warning` and the
  aggregate report surfaces the drift across all hybrid legs.

- If drift ratio > 5.0 in any leg, the leg is `BLOCKED-cold-store-drift`
  and Manager is notified.

## Handoff

Part 4 reviewable. Part 5 covers the three-layer report structure.
