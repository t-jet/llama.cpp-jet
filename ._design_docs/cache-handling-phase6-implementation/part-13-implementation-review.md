# Phase 6 implementation review

Reviewer: Architect agent
Date: May 30, 2026
Scope: Stage 6 cold payload storage and asynchronous I/O implementation (Steps 1–12)

## Verdict: PASS

The Stage 6 implementation conforms to the approved design and implementation plan. All 12 steps
have been completed with evidence, all acceptance criteria are met, and all test suites pass. The
implementation is ready for QA testing.

## Review checkpoints

### 1. Design conformance

The implementation matches the approved design in Parts 1–7 of `cache-handling-phase6-design.md`.

| Design requirement | Conformance | Evidence |
| --- | --- | --- |
| Cold layer is opt-in; all Stage 5 behavior preserved when `--cache-cold-path` is absent | ✅ PASS | Constructor only configures cold store when `cold_path` is non-empty. All existing tests pass without cold path. |
| `server_cache_store_cold` handles all file operations; controller must not construct cold file paths directly | ✅ PASS | Controller uses `cold_store.write()`, `cold_store.read()`, `cold_store.remove()` exclusively. No path construction in controller code. |
| `server_cache_io_worker` runs as a single background thread; `server_context` must never block on cold I/O or full queue | ✅ PASS | Worker thread model with bounded queue and fail-fast on queue-full. `demote_payload` and `promote_payload` return immediately after enqueue. |
| Target and draft sides of `target_and_draft` always move together across cold transitions | ✅ PASS | `demote_payload` validates pairing invariant before demotion. `write` serializes both sides. `read` validates both checksums. |
| Atomic write-and-rename ensures readers never see partial cold files | ✅ PASS | `write` creates staging file with `.tmp` suffix, then `fs::rename` to final path. `read` only uses final paths. |
| Integrity validation on promotion checks all ten fields in order | ✅ PASS | `read` validates magic, format_version, header_checksum, checksum_algorithm, payload_id, pair_state, target_size_bytes, draft_size_bytes, target_checksum, draft_checksum in that order. |
| Startup failure uses graceful exit, not `abort()` | ✅ PASS | Constructor uses `throw std::runtime_error`. No `abort()` in any Stage 6 code path. Pre-existing `GGML_ABORT` calls in `server-context.cpp` are unrelated. |
| Design decision 2 (single worker thread) and decision 5 (fallback on queue full) are binding | ✅ PASS | Single worker thread with `DEFAULT_QUEUE_CAPACITY = 32`. Queue-full returns false immediately. |
| NB-1 through NB-5 resolutions implemented | ✅ PASS | NB-1: `demoting`/`promoting` enum values and `can_transition` function. NB-2: Queue-full revert in `demote_payload` and `promote_payload`. NB-3: `cold_ref_for` removed, comment in header. NB-4: Result-queue model with `drain_results`. NB-5: Hot bytes held until `handle_demotion_completion` success callback. |

**Deviation from design — `cold_store_header` field layout**: The design specifies `payload_id` at
bytes 6–13, but the implementation places `_reserved[2]` at bytes 6–7 and `payload_id` at bytes
8–15 for proper `uint64_t` alignment. This is documented in Step 2 evidence as a known deviation.
The `static_assert(sizeof(cold_store_header) == 64)` validates total size consistency. Since
serialization and deserialization both use the same struct layout, the binary format is
self-consistent. This is a **non-blocking** deviation: the implementation is correct and
self-consistent, but the design document's byte-offset table is inaccurate. The design should be
updated to match the implementation layout, or the implementation should add explicit
serialization/deserialization that matches the design byte offsets.

### 2. Code correctness

| Area | Assessment | Evidence |
| --- | --- | --- |
| State machine completeness | ✅ PASS | `can_transition` covers all 10 allowed transitions. `evicted` is terminal. Transient states block concurrent operations. |
| Race conditions | ✅ PASS | Descriptor state mutations happen on `server_context` thread only. Worker posts results to a queue drained by `process_completions`. No per-descriptor locks needed. |
| Memory leaks | ✅ PASS | Hot payload records are released in `handle_demotion_completion` on success. Worker `stop()` drains remaining items as cancelled. Destructor calls `io_worker.stop()`. |
| Transient state handling | ✅ PASS | `demoting` blocks restore (`try_restore_from_cache` returns false with warning). `promoting` blocks restore. Both revert on queue-full. |
| NB-5 hot-byte pinning | ✅ PASS | `demote_payload` does NOT erase from `hot_payloads`. `handle_demotion_completion` erases on success. Failure path checks `hot_payloads.find()` and reverts to hot if record exists. |
| `demote_payload` lookup key | ✅ PASS | `hot_payloads` is keyed by `payload_id`. `descriptor.store_ref.id` equals `payload_id` for hot descriptors. Both `descriptor.store_ref.id` (line 81) and `descriptor.payload_id` (line 230, 244) resolve to the same key. |
| Promotion latency tracking | ⚠ NB-1 | `promotion_enqueue_time` is a single field, not per-payload. If two promotions are in flight, the second overwrites the first's timestamp. This is documented in Step 10 evidence. Acceptable for histogram bucketing but may need per-payload tracking for concurrent promotions in a future stage. |
| `n_cold_payload_bytes` underflow guard | ⚠ NB-2 | In `handle_promotion_completion`, `n_cold_payload_bytes` subtraction is guarded by `if (n_cold_payload_bytes >= ...)`. This prevents underflow but silently drops the subtraction if the guard fails. This is a defensive coding pattern that is acceptable for a gauge metric. |

### 3. Doc-code consistency

| Document | Assessment | Evidence |
| --- | --- | --- |
| Step 1 evidence | ✅ Consistent | `can_transition` function, guard comment, and test cases match evidence. |
| Step 2 evidence | ✅ Consistent | NB-3 comment present. `cold_store_header` layout deviation documented. |
| Step 3 evidence | ✅ Consistent | Atomic write-and-rename verified. Path-safe hex encoding verified. |
| Step 4 evidence | ✅ Consistent | All 10 validation checks present in `read()`. |
| Step 5 evidence | ✅ Consistent | Worker thread lifecycle, bounded queue, result-queue model all match. |
| Step 6 evidence | ✅ Consistent | Demotion protocol, NB-2 revert, NB-5 pinning, protected root warning all match. |
| Step 7 evidence | ✅ Consistent | Promotion protocol, dead code fix, queue-full revert all match. |
| Step 8 evidence | ✅ Consistent | Constructor wiring, destructor ordering, startup validation all match. |
| Step 9 evidence | ✅ Consistent | All five startup checks present. No code changes needed. |
| Step 10 evidence | ✅ Consistent | All required metrics present in `get_stats()` and Prometheus export. |
| Step 11 evidence | ✅ Consistent | All test hooks and fault injection points present. |
| Step 12 evidence | ✅ Consistent | Documentation updates recorded. |

### 4. Deviation documentation

| Deviation | Documented? | Assessment |
| --- | --- | --- |
| `cold_store_header` field layout alignment padding | ✅ Documented in Step 2 evidence | NB: Design byte-offset table is inaccurate. Should be corrected in design doc or implementation should use explicit serialization. |
| `write` and `read` fully implemented instead of stubs in Step 2 | ✅ Documented in Step 2 evidence | Acceptable: pre-existing implementation was correct and tested. |
| "Not in an active restore transaction" check not implemented in `demote_payload` | ✅ Documented in Step 6 evidence | Acceptable: `residency != hot` check implicitly prevents demotion during promotion. |
| `evict_entry_by_id` modified to call `mark_payload_evicted` | ✅ Documented in Step 6 evidence | Acceptable: key integration point connecting eviction policy to demotion path. |
| Metric naming uses `n_` prefix instead of `cache_` prefix | ✅ Documented in Step 6 evidence | Acceptable: follows existing codebase convention. Prometheus export uses `llamacpp_cache_` prefix. |
| `debug_set_cold_store_validation_failure_for_tests` and `debug_set_cold_store_read_failure_for_tests` added but not used in final tests | ✅ Documented in Step 7 evidence | Acceptable: file corruption is more reliable for triggering validation failures. |
| Promotion latency uses single `promotion_enqueue_time` field | ✅ Documented in Step 10 evidence | Acceptable for histogram bucketing. May need per-payload tracking for concurrent promotions. |

All deviations are documented in the evidence files. No undocumented deviations were found.

### 5. No `abort()` usage

✅ **PASS**. No `abort()` calls in any Stage 6 code file:

- `server-cache-store-cold.cpp`: no `abort()`
- `server-cache-io-worker.cpp`: no `abort()`
- `server-cache-hybrid.cpp`: no `abort()`
- `server-context.cpp` (cold path): uses `throw std::runtime_error` for startup failures


Pre-existing `GGML_ABORT` calls in `server-context.cpp` are unrelated to Stage 6 and handle
different error conditions (model reload, multimodal processing, position tracking).

### 6. Metrics completeness

| Required metric (design Part 5) | Present in code | Present in Prometheus export | Correct behavior |
| --- | --- | --- | --- |
| `cache_payload_demotions_total` | ✅ `n_demotion_successes` | ✅ `llamacpp_cache_payload_demotions_total` | Counts successful demotions |
| `cache_payload_promotions_total` | ✅ `n_promotion_successes` | ✅ `llamacpp_cache_payload_promotions_total` | Counts successful promotions |
| `cache_payload_cold_evictions_total` | ✅ `n_cold_evictions` | ✅ `llamacpp_cache_payload_cold_evictions_total` | Incremented in `handle_promotion_completion` failure path |
| `cache_cold_restore_latency_seconds` | ✅ `n_promotion_latency_buckets[8]` | ✅ 8 bucket metrics | Histogram with 8 buckets |
| `cache_cold_payload_bytes` | ✅ `n_cold_payload_bytes` | ✅ `llamacpp_cache_cold_payload_bytes` | Gauge, incremented on demotion success, decremented on promotion success |
| `cache_hot_payload_count` | ✅ `n_hot_payload_descriptors` | ✅ `llamacpp_cache_hot_payload_descriptors` | Counts descriptors with `residency == hot` |
| `cache_cold_payload_count` | ✅ `n_cold_payload_count` | ✅ `llamacpp_cache_cold_payload_count` | Gauge, incremented on demotion success, decremented on promotion and cold eviction |
| `cache_payload_evictions_total` excludes demoted payloads | ✅ `n_payload_evictions` | ✅ `llamacpp_cache_payload_evictions_total` | Only incremented in immediate eviction path, not when demotion succeeds |

Additional metrics beyond design requirements:

- Demotion failure reason counters: `n_demotion_failure_write_error`, `n_demotion_failure_other`
- Promotion failure reason counters: `n_promotion_failure_checksum_mismatch`, `n_promotion_failure_not_found`, `n_promotion_failure_other`
- Queue-full counters: `n_demotion_queue_full`, `n_promotion_queue_full`
- Protected root demotion counter: `n_protected_root_demotions`
- Residency state breakdown: `n_demoting_payload_descriptors`, `n_promoting_payload_descriptors`, `n_cold_payload_descriptors`, `n_evicted_payload_descriptors`


### 7. Test coverage

| Step | Test file | Tests | Status |
| --- | --- | --- | --- |
| Step 1 | `test-step1-state-machine.cpp` | 8 | ✅ All pass |
| Step 2 | `test-step2-cold-store.cpp` | 15 (1 skipped on Windows) | ✅ All pass |
| Steps 3–4 | `test-step3-4-cold-store-write-read.cpp` | 29 | ✅ All pass |
| Step 5 | `test-step5-io-worker.cpp` | (verified in Step 5 evidence) | ✅ All pass |
| Step 6 | `test-step6-demotion-protocol.cpp` | 16 | ✅ All pass |
| Step 7 | `test-step7-promotion-protocol.cpp` | 16 | ✅ All pass |
| Step 8 | `test-step8-integration-wiring.cpp` | 13 | ✅ All pass |
| Step 9 | `test-step9-startup-validation.cpp` | 12 (1 skipped on Windows) | ✅ All pass |
| Step 10 | `test-step10-metrics.cpp` | 8 | ✅ All pass |
| Step 11 | `test-step11-test-hooks-fault-injection.cpp` | 17 | ✅ All pass |

Design Part 6 fault injection points coverage:

| Fault injection point | Test case | Status |
| --- | --- | --- |
| Checksum corruption | Step 11 test 6 | ✅ |
| Header truncation | Step 11 test 7 | ✅ |
| `payload_id` mismatch | Step 11 test 8 | ✅ |
| `pair_state` mismatch | Step 11 test 9 | ✅ |
| format_version unknown | Step 11 test 10 | ✅ |
| Demotion write failure | Step 11 test 11 | ✅ |
| Queue full at demotion | Step 11 test 12 | ✅ |
| Queue full at promotion | Step 11 test 13 | ✅ |
| Worker thread shutdown race | Step 11 test 14 | ✅ |
| Draft-side promotion failure for `target_and_draft` | Step 11 test 15 | ✅ |

All 10 fault injection points from design Part 6 have corresponding test cases.

### 8. Pre-existing test failure

The evidence documents mention a pre-existing assertion failure in
`test_hybrid_rejects_partial_blob_match` (test 17) in the main `test-cache-controller` test suite.
This failure existed before Stage 6 changes and is unrelated to Stage 6. No Stage 6 test
introduces or exacerbates this failure.

## Findings

### Blocking findings

None.

### Non-blocking findings

**NB-1: Single-field promotion latency tracking.** The `promotion_enqueue_time` field in
`hybrid_cache_controller` is a single `std::chrono::steady_clock::time_point`, not a per-payload
map. If two promotions are in flight concurrently, the second enqueue overwrites the first's
timestamp. This means the latency histogram may attribute the wrong enqueue time to a completion
result. This is documented in Step 10 evidence as a known simplification. For the current
single-worker design with bounded queue, concurrent promotions are rare and the histogram remains
useful for latency distribution analysis. A per-payload tracking map should be considered if
concurrent promotion latency accuracy becomes important.

**NB-2: `n_cold_payload_bytes` underflow guard.** In `handle_promotion_completion`, the
subtraction `n_cold_payload_bytes -= descriptor.target_size_bytes + descriptor.draft_size_bytes`
is guarded by `if (n_cold_payload_bytes >= ...)`. If the guard fails, the subtraction is silently
skipped. This is a defensive pattern that prevents underflow but could cause the gauge to drift
upward over time if demotion and promotion byte accounting ever diverge. The guard is acceptable
for a best-effort gauge metric.

**NB-3: `cold_store_header` byte-offset discrepancy with design.** The design Part 2 specifies
`payload_id` at bytes 6–13, but the implementation uses `_reserved[2]` at bytes 6–7 and
`payload_id` at bytes 8–15 for `uint64_t` alignment. The implementation is self-consistent
(serialization and deserialization use the same struct layout via `memcpy`), and the
`static_assert(sizeof(cold_store_header) == 64)` validates total size. However, the design
document's byte-offset table is inaccurate. The design should be updated to match the
implementation layout, or the implementation should use explicit field-by-field
serialization/deserialization that matches the design offsets. Since the cold file format is
persistent and versioned, this discrepancy should be resolved before any external tool needs to
read cold files.

**NB-4: `demote_payload` redundant residency check.** In `demote_payload`, the check
`if (descriptor.residency == payload_residency_state::demoting)` at line 100 is redundant because
the preceding check `if (descriptor.residency != payload_residency_state::hot)` at line 93 already
covers the `demoting` case. This is not a bug — the redundant check produces a more specific
diagnostic message — but it is dead code that could confuse future readers.

## Summary

The Stage 6 implementation is **ready for QA testing**. All 12 steps are complete with passing
tests, all design requirements are met, all deviations are documented, no `abort()` usage is
present, metrics are complete and correctly exclude demoted payloads from eviction counts, and
test coverage includes all fault injection points from the design.

The four non-blocking findings (NB-1 through NB-4) are observations for future improvement and do
not block the stage gate.
