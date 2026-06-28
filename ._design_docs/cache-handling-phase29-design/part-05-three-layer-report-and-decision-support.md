# Part 5: Three-layer report and decision-support framing

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)

## Layer 1: Correctness (mandatory before any performance claim)

Correctness is gated on three sub-checks. ALL three must PASS for the
report to claim hybrid is correct on the workload.

### Sub-check 1.1: Cold-store validity (hybrid only)

- Every cold file passes magic, format, version, payload-id, pair-state,
  size, and checksum validation.

- `llamacpp:cache_descriptor_validation_failures_total` delta = 0 during the
  workload.

- `llamacpp:cache_pairing_violations_total` delta = 0 during the workload.
- `llamacpp:cache_restore_failures_total` delta = 0 during the workload.

If any of the above is non-zero, the leg is `FAIL-correctness-cold-store`
and the comparison report classifies hybrid as incorrect.

### Sub-check 1.2: Output equivalence (pre-workload gate)

- 5 prompts with seed=42, max_tokens=8, identical `messages`.
- Byte-identical decoded text per prompt across legacy and hybrid.
- Diff text recorded in `phase-1-output-equivalence/diff.txt`.
- Byte-identical = PASS. Any difference = `BLOCKED-output-equivalence` and
  the main workload does NOT start.

### Sub-check 1.3: Fallback restore rate (hybrid only)

- `llamacpp:cache_fallback_restores_total` delta divided by total restores.
- Target: < 5% fallback rate. Above 5% = `OK-with-fallback-warning`.
  Above 20% = `FAIL-correctness-fallback-rate`.

### Verdict

- PASS: all three sub-checks pass.
- FAIL-correctness-cold-store: sub-check 1.1 fails.
- BLOCKED-output-equivalence: sub-check 1.2 fails (pre-workload).
- FAIL-correctness-fallback-rate: sub-check 1.3 fails.
- OK-with-warnings: all three pass but with bounded warnings recorded.

## Layer 2: Per-request comparison

Side-by-side per-request table (one row per request, ordered by
`request_id`):

| Column | Legacy | Hybrid | Delta |
| --- | --- | --- | --- |
| `cache_class` | value | value | n/a |
| `cache_n_ratio` | value | value | hybrid - legacy |
| `ttft_ms` | value | value | hybrid - legacy |
| `wall_clock_ms` | value | value | hybrid - legacy |
| `cache_hit` (bool) | value | value | n/a |
| `request_status` | value | value | n/a |

Distributions over the full workload (per mode, per cache_class):

- p50, p95, p99 of `wall_clock_ms`
- p50, p95, p99 of `ttft_ms`
- p50, p95, p99 of `cache_n_ratio`

If hybrid is slower on cache hits than legacy on hits, the report flags
this as a `hybrid-hit-overhead` signal and the decision-support section
treats it as a fix candidate.

## Layer 3: Aggregated comparison

Across all cycles, per mode:

- Mean cache hit rate (from response `cache_n > 0`).
- Mean cache hit rate (from `llamacpp:cache_hits_total` /
  `(cache_hits_total + cache_misses_total)`).

- Total tokens reused (sum of `cache_n_tokens`).
- Total wall-clock for the leg (driver-side).
- Cold-store utilization at end of leg (hybrid only).
- Cold-store drift ratio (hybrid only).
- VRAM peak per mode.
- Failure modes observed: cold-store validation errors, fallback restores,
  eviction storms, request errors.

- Total wall-clock savings (or cost) of hybrid over legacy.

The aggregate section answers: "On this workload, does hybrid give back
more than it costs?"

## Decision-support framing

The report answers five questions, in order, each with a concrete metric
threshold:

### Q1: Does hybrid actually reuse more KV than legacy on this workload?

- Compare mean `cache_n_ratio` across modes.
- If `mean(hybrid) < mean(legacy) + 0.05`, the hybrid path is not hitting
  the cache that legacy would have. Look for cold-store write failures,
  namespace mismatches, descriptor-validation mismatches.

- Decision: `SHIP` if hybrid >= legacy + 0.05; `FIX-TARGET` if hybrid is
  close to legacy; `REVERT` if hybrid < legacy.

### Q2: When hybrid hits, is it faster than legacy?

- Compare p50 `ttft_ms` of cache-hit requests between modes.
- If `ttft_ms_hybrid_hit` p50 > `ttft_ms_legacy_hit` p50 * 1.10, the
  restore path has overhead. Likely fixes: blob deserialization, namespace
  re-validation, pdb source-path substitution.

- Decision: `SHIP` if hybrid hit <= legacy hit x 1.10; `FIX-TARGET` if
  hybrid hit > legacy hit x 1.10.

### Q3: When hybrid misses, how much overhead?

- Compare cold-miss `ttft_ms` vs warm-miss `ttft_ms` (hybrid only).
- If cold-miss median > warm-miss median + 50 ms (proposed threshold for
  Qwen3.5-4B-MTP), the cold-path is slow. Decide whether the cold-path
  is worth it given hit rate.

- Decision: `ACCEPT-COLD` if cold overhead <= threshold; `FIX-TARGET` if
  cold overhead > threshold.

### Q4: Does hybrid evict the hot set too aggressively?

- Compare `llamacpp:cache_payload_evictions_by_shape_total` rate (per
  1000 requests) with cache hit rate.

- If eviction rate > 100 per 1000 requests AND hit rate < 50%, eviction is
  hurting reuse. Look at Stage 4 LRU + protected roots.

- Decision: `SHIP` if eviction rate <= threshold or hit rate >= 50%;
  `FIX-TARGET` otherwise.

### Q5: Does hybrid correctness hold?

- Validate Layer 1 verdict.
- If Layer 1 PASS: `SHIP-CORRECTNESS-OK`.
- If Layer 1 FAIL or BLOCKED: do not ship; route to Developer bug-fix loop.

### Final recommendation

Each question produces a per-question verdict (`SHIP`, `FIX-TARGET`,
`REVERT`, `ACCEPT-COLD`). The final recommendation is:

- `SHIP-HYBRID-AS-DEFAULT` if all five questions are SHIP or ACCEPT-COLD.
- `SHIP-HYBRID-AS-OPTIONAL` if Q1 SHIP and any of Q2-Q4 FIX-TARGET.
- `DO-NOT-SHIP` if Q1 FIX-TARGET or REVERT or Q5 FAIL/BLOCKED.

The decision-support section cites the per-question metric values and the
specific evidence paths in the non-durable artifacts.

## Handoff

Part 5 reviewable. Part 6 covers the six binding decisions.
