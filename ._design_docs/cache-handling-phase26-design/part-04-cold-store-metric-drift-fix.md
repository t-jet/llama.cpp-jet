# Part 4: Cold-store metric vs filesystem drift fix

Status: design draft
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope: investigate and fix the 5.78 GiB on-disk vs 352 MiB metric
discrepancy observed in Stage 24 -06 S02 hybrid.

## Symptom

From [test-report-20260624-06.md](../.test_reports/test-report-20260624-06.md),
S02 hybrid -06 reports:

- `cold_budget.metric_bytes_after: 368840836` (351.7 MiB)
- `cold_budget.filesystem_bytes_after: 6006843768` (5.6 GiB)
- 115 cold files on disk, 50.25 MiB each

The runner classified the leg as PASS because the metric-based budget
check passed (351.7 MiB < 512 MiB budget). The filesystem shows
~16x more bytes than the metric.

Same drift persisted in [test-report-20260624-05.md](../.test_reports/test-report-20260624-05.md).
Recorded in Stage 24 part-16 as D-EXEC-24-03-c and carried into Stage
25 part-10 as an open observation.

## Root cause (most likely)

The metric `llamacpp:cache_cold_payload_bytes` (current name
`llamacpp_cache_cold_payload_bytes`, line 4489 in
`tools/server/server-context.cpp`) is incremented in the demote path
when a payload is successfully written to cold storage. It is
decremented in the eviction path when a payload is removed from cold
storage.

The most likely accounting gap:

1. The cold-store files on disk include both the payload bytes
   (counted in the metric) AND per-file header bytes (NOT counted in
   the metric). With 115 files and a 5.78 GiB total, the per-file
   overhead would need to be ~47 MiB per file for the gap to come
   entirely from header overhead. 47 MiB is too large for a header
   (typical llama_state_seq_save_file header is <1 KiB).
2. The metric increments per payload demote but does NOT decrement
   on eviction. Eviction removes the file from disk (via the cold-
   cleanup path at lines 939..990) but the metric is only updated in
   the eviction-counter path, not the byte-counter path.
3. The metric increments on demote success and ALSO on payload
   re-demote (an existing entry with payload is demoted again to a
   new cold file). If the same entry is demoted multiple times, the
   metric counts both, but only the latest file is tracked.
4. The metric is `n_cold_payload_bytes` declared at
   `tools/server/server-cache-hybrid.h` line 762 with comment
   "incremented on demotion success". If eviction does NOT decrement
   the counter but does delete the file, the metric drifts up.

Hypothesis #2 is the most likely cause: every cold cleanup cycle
removes bytes from disk but does NOT remove bytes from the metric
counter. Stage 24 -05 and -06 both ran long enough for many
demote-evict cycles to compound the drift.

## Fix

Track cold-payload bytes per file and subtract on eviction. The
metric `n_cold_payload_bytes` is a `size_t` counter; adding a
`std::map<uint64_t, size_t>` from payload_id to on-disk byte size
would let each eviction subtract exactly what it removed.

Alternative: track total on-disk bytes via a single file-system
walk at metric-emit time. This avoids per-payload accounting but
adds an O(directory) operation on every `/metrics` call. For 115
files this is fast (single readdir). Recommendation: file-system
walk, gated by a `--cache-cold-fs-walk` flag defaulting to off
(metric-based accounting stays default; FS walk is opt-in for
debugging).

Concrete fix sequence:

1. In `cold_budget_make_room` (line 603) and demote paths, capture
   the exact `result.bytes_written` value from the demote completion.
   This is already returned by `handle_demotion_completion` (line
   677..) so the value is available.
2. Add a `std::map<uint64_t, size_t> cold_payload_bytes_by_id_`
   field to `hybrid_cache_controller`. Key is `payload_id`, value is
   the last successful write size.
3. On demote success: insert or update `cold_payload_bytes_by_id_[pid]`
   with the actual write size; increment `n_cold_payload_bytes` by
   the same amount.
4. On cold cleanup (line 939..990) and on
   `mark_payload_kind_evicted` (line 3330) and
   `mark_payload_evicted` (line 3379): look up the size in
   `cold_payload_bytes_by_id_`, subtract from `n_cold_payload_bytes`,
   and erase the entry.
5. Add a `n_cold_payload_files` counter for the file count so
   the runner can compare metric vs filesystem file count.

## Expected evidence

- New metric `llamacpp:cache_cold_payload_files` (current name
  `llamacpp_cache_cold_payload_count` already exists at line 4490;
  verify it tracks file count, not descriptor count).
- After implementation: Stage 24 rerun S02 hybrid should show
  metric_bytes_after within 10% of filesystem_bytes_after, OR a
  explicit accounting-fix note in the test report explaining
  the residual delta.
- Stage 24 rerun cold_budget check stays PASS under both metric-
  based and filesystem-based budgets.

## Handoff

Part-04 is reviewable. Implementation order in part-06 sequences the
accounting fix before the Stage 24 rerun so the rerun produces
drift-fixed evidence.
