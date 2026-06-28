# Part 7: Three open questions resolved

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)
Source brief: [../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md](../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md) section 10

## D29-OQ-01: Does llama-server expose `cache_n_tokens` consistently for both modes?

**Question**: The original proposal asks whether `cache_n_tokens` (response
`timings.cache_n`) is exposed consistently for `--cache-mode legacy` and
`--cache-mode hybrid`.

**Resolution**: Both modes emit `timings.cache_n` in chat-completion
responses. The field shape is identical: integer count of reused prompt
tokens. In legacy mode, the value follows the upstream llama.cpp prompt-
cache semantics (per-prompt exact match). In hybrid mode, the value
follows the Stage 5 restore semantics (exact blob + checkpoint restore +
warm miss).

**Evidence basis**: Stage 24 evidence shows hybrid `cache_n` is non-zero on
hit (the aggregate `cache_n nonzero_rate` reported in
`test-report-20260624-06.md` for S03 hybrid is 0.1306 across 280 evidence
records with 64 hits). The Stage 24 -06 report body shows aggregate
nonzero_rate only; per-request `cache_n` values for specific requests
such as `s03-exact-0-0` live in the per-request logs at
`._test_output/stage24-chat-s02-s03-20260624-06/S03-chat/requests.jsonl`
and are not quoted verbatim in the durable report. Stage 5 design records
the restore semantics. Stage 16 implementation
([cache-handling-phase16-implementation/part-09-model-log-analysis.md](../cache-handling-phase16-implementation/part-09-model-log-analysis.md))
shows legacy `cache_n` reaches 11 on chat-completion after the chat-path
boundary fix.

**Implementation-plan verification step**: before relying on the Stage 24
-06 cache_n claim for `s03-exact-0-0`, the implementation plan must
either (a) read the per-request log at
`._test_output/stage24-chat-s02-s03-20260624-06/S03-chat/requests.jsonl`
and record the actual value, or (b) cite the Stage 24 -06 aggregate
`cache_n nonzero_rate = 0.1306` (64 hits / 280 OK requests) as the
durable signal. Stage 29 does not pre-commit to the value 15; the
implementation plan records whatever the actual evidence shows.

**Handling if missing or zero**: If `timings.cache_n` is missing or always
zero on hybrid, the report classifies the metric as
`BLOCKED-metric-unavailable` and falls back to Prometheus deltas:

- `llamacpp:cache_hits_total` (hybrid)
- `llamacpp:cache_misses_total` (hybrid)
- For legacy, the upstream `llamacpp:cache_hits_total` / `llamacpp:cache_misses_total`
  apply.

The fallback is recorded in the report's metric-unavailable list. The
report does NOT average hybrid and legacy `cache_n` values if one side is
unavailable.

## D29-OQ-02: Does the cold-path write block the request thread?

**Question**: The original proposal asks whether the cold-path write path
blocks the request thread or is asynchronous.

**Resolution**: The cold-path write is synchronous in the tx_* architecture
(post-Stage-25). Specifically:

- `tx_save` is the canonical save entry point (Stage 25 design part-02).
- When a payload is demoted to cold storage, `tx_demote_payload` calls
  `cold_store.write()` which is a synchronous file write + atomic rename
  (Stage 6 design part-02).

- The demotion happens inside the same `tx_*` transaction that triggered
  the eviction. There is no async enqueue (Stage 25 retired the worker
  thread per OQ-25-02 Option B).

The cold-path LOAD is also synchronous on first hit:

- `tx_load` is the canonical load entry point (Stage 25 design part-02).
- On cold-miss, `tx_load` reads the cold file, validates magic + format +
  version + payload-id + pair-state + size + checksum, then restores the
  payload to hot memory.

- The first cold-hit latency is dominated by the disk read + validation.
- The report separates cold-miss latency from warm-miss latency so the
  cold-path overhead is visible.

**Asymmetry summary**:

- Cold WRITE: synchronous, inside the transaction that triggered eviction.
  Affects the request that triggered eviction (rare, only when over budget).

- Cold LOAD: synchronous, on first cold-hit. Affects the request that
  hit cold.

The proposal's `ttft_ms` interpretation:

- `ttft_ms` for cold-miss includes cold-load latency.
- `ttft_ms` for warm-miss excludes cold-load latency.
- The decision-support section separates these two cases.

## D29-OQ-03: Are there workload classes where legacy outperforms hybrid by design?

**Question**: The original proposal asks whether there are workload
classes where legacy outperforms hybrid by design (e.g., short single-
turn chats with no prefix reuse).

**Resolution**: YES for short single-turn chats with no prefix reuse.
Specifically:

- Hybrid restores pay the namespace-validation cost on every restore
  attempt (Stage 5 design part-02).

- For requests with no prefix reuse (cache_class = `new_branch`), the
  hybrid path falls through to warm-miss recompute, identical to legacy.

- The namespace-validation cost on the warm-miss path adds ~1-5 ms latency
  per request, even when no restore succeeds.

The report does NOT average this away. The per-cache-class column in
Layer 2 surfaces the asymmetry:

- For `cache_class = exact`, hybrid `ttft_ms` should be << legacy `ttft_ms`
  on hit (because hybrid actually hits).

- For `cache_class = near_prefix`, hybrid `ttft_ms` should be ~legacy
  `ttft_ms` (hybrid rejects near-prefix for safety; legacy may also reject).

- For `cache_class = new_branch`, hybrid `ttft_ms` should be >= legacy
  `ttft_ms` by ~1-5 ms (namespace-validation overhead with no benefit).

If the new_branch column shows hybrid >> legacy (e.g., 2x or more), the
hybrid path has a pathological overhead and is a fix candidate.

The decision-support Q1 ("Does hybrid actually reuse more KV than legacy?")
is answered per cache_class, not aggregated. The final recommendation
includes a per-class breakdown.

## Summary table

| ID | Question | Resolution |
| --- | --- | --- |
| D29-OQ-01 | `cache_n_tokens` exposure parity | Both modes emit; fallback to Prometheus deltas if missing. |
| D29-OQ-02 | Cold-path write thread blocking | Synchronous tx_* path; cold-load latency surfaced separately. |
| D29-OQ-03 | Legacy-wins-by-design classes | Yes for new_branch; per-class columns in Layer 2; Q1 answered per class. |

## Handoff

Part 7 reviewable. Part 8 covers the reuse vs new artefacts table.
