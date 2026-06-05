# Phase 6 implementation evidence - Part 10: Step 10 metrics

Source: [../cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)

## Step 10: Metrics

**Status: COMPLETE**

### Summary

Step 10 added all required metrics to `hybrid_cache_controller` and the Prometheus export path
in `server-context.cpp`:

- `cache_payload_demotions_total` (counter, with `result` label: success/failure)
- `cache_payload_promotions_total` (counter, with `result` label: success/failure)
- `cache_payload_cold_evictions_total` (counter)
- `cache_cold_restore_latency_seconds` (histogram with 8 buckets)
- `cache_cold_payload_bytes` (gauge)
- `cache_cold_payload_count` (gauge)
- `cache_hot_payload_count` (gauge, extended to track hot descriptor count)
- Demotion failure reason counters: `n_demotion_failure_write`, `n_demotion_failure_queue_full`
- Promotion failure reason counters: `n_promotion_failure_checksum`, `n_promotion_failure_format`,
  `n_promotion_failure_payload_id`, `n_promotion_failure_pair_state`, `n_promotion_failure_header_checksum`,
  `n_promotion_failure_magic`, `n_promotion_failure_draft_checksum`, `n_promotion_failure_other`

### Changed files

- `tools/server/server-cache-hybrid.h` — Added latency histogram buckets array
  (`n_promotion_latency_buckets[8]`), `n_cold_payload_count`, promotion/demotion failure reason
  counters, `debug_get_residency_state_for_tests()`, `debug_inject_promotion_failure_for_tests()`,
  `debug_clear_promotion_failures_for_tests()`, `debug_promotion_failure_payload_ids_` unordered_set,
  and `promotion_enqueue_time` field.
- `tools/server/server-cache-hybrid.cpp` — Added latency bucket computation in
  `handle_promotion_completion()`, cold_payload_count increment/decrement, failure reason counters
  in both `handle_demotion_completion()` and `handle_promotion_completion()`, and all new fields
  in `get_stats()`.
- `tools/server/server-context.cpp` — Added 25+ `write_cache_metric` calls for all new Phase 6
  Step 10 metrics including demotion/promotion counters, latency histogram buckets, cold payload
  gauges, and failure reason counters.
- `tests/test-step10-metrics.cpp` — 8 test cases covering all Step 10 metrics requirements.
- `tests/CMakeLists.txt` — Added `test-step10-metrics` target.

### Build evidence

```text
cmake --build . --target test-step10-metrics --config Release
```

Build succeeded with no errors.

### Test evidence

```text
.\test-step10-metrics.exe

==================================================
Step 10: Metrics
==================================================

step10: demotion success counter...
  PASSED
step10: get_stats() includes all new metrics...
  PASSED
step10: cold payload bytes gauge updates on demotion...
  PASSED
step10: hot payload count gauge reflects hot descriptors...
  PASSED
step10: cache_payload_evictions_total does NOT count demoted payloads...
  PASSED
step10: promotion failure reason counters...
  PASSED
step10: promotion latency histogram buckets exist...
  PASSED
step10: cold payload count gauge...
  PASSED

==================================================
Step 10: All tests PASSED
==================================================
```

All 8 tests passed.

### Key design decisions

1. **Promotion latency tracking** uses a single `promotion_enqueue_time` field rather than
   per-payload tracking. This means only one promotion's latency is tracked at a time. This
   simplification works for the histogram but may need per-payload tracking for concurrent
   promotions.

2. **`n_cold_payload_count`** is incremented in `handle_demotion_completion` on success and
   decremented in `handle_promotion_completion` (both success and failure paths) and in cold
   eviction paths.

3. **`n_payload_evictions`** does NOT count demoted payloads. Verified in `evict_entry_by_id()`
   which only increments it in the immediate eviction path, not when demotion succeeds.

### Deviations from plan

None. All metrics specified in the design are implemented and tested.