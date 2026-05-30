# Phase 6 implementation plan - Part 2 (continued)

Source: [../cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)

Continuation of [Part 1](part-01-implementation-plan.md).

## Ordered implementation steps (continued)

### Step 6: Demotion protocol

Goal: implement the hot-to-cold demotion flow in `hybrid_cache_controller`, including enqueue,
transient state, NB-2 revert on queue-full, and completion handling with pinned hot-byte release
(NB-5).

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`

Changes:

- Add a `demote_payload(payload_id)` method to `hybrid_cache_controller`. This method:
  1. Validates the descriptor is eligible for demotion (residency `hot`, cold store configured,
     no in-progress demotion, not in an active restore transaction).
  2. For `target_and_draft`, confirms both sides are present and passes the pairing validator.
  3. Sets `residency_state = demoting`. Does NOT release the hot record at this point.
  4. Calls `worker.enqueue_demotion(payload_id, ...)`. If enqueue returns queue-full, immediately
     reverts `residency_state = hot` and emits a warning diagnostic. Returns failure.
  5. Returns. The `server_context` thread is not blocked.
- Add `handle_demotion_completion(io_completion_result)` called from `process_completions`:
  - On success: set `store_ref.id` to the cold ref from the result, set
    `residency_state = cold`, release the hot payload record from `hot_payloads`, increment
    `cache_payload_demotions_total{result=success}` and `cache_cold_payload_bytes`.
  - On failure: if the hot record still exists, revert `residency_state = hot`. If the hot
    record has already been released (should not happen with NB-5 pinning but must be handled),
    set `residency_state = evicted`. Emit error diagnostic. Increment demotion failure counter.
- Hot bytes are held in the hot payload record until `handle_demotion_completion` receives a
  success result. This is the explicit pin required by NB-5. The staging file write and rename
  complete before the worker posts a success result.
- Add `process_completions()` method that drains the worker result queue and dispatches each
  result to the appropriate handler. Call this at the start of `update()` before policy evaluation.
- In the eviction path (`update()`), call `demote_payload` for LRU-selected descriptors when the
  cold store is configured, rather than immediately evicting them.
- Emit a warning diagnostic when a protected root is demoted.

Acceptance test: add a focused test that demotes a hot descriptor through a fake cold store. Confirm
`residency_state == cold` after `process_completions`. Confirm hot record is released. Confirm
queue-full reverts residency to `hot`. Confirm hot bytes are still present in the hot record during
the demotion window (before callback). Add cases to `tests/test-cache-controller.cpp`.

Dependencies: Steps 1, 2, 3, 5, 8.

---

### Step 7: Promotion protocol

Goal: implement the cold-to-hot promotion flow in `hybrid_cache_controller`, including enqueue,
transient state, NB-2 revert on queue-full, and completion handling.

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`

Changes:

- Add a `promote_payload(payload_id)` method to `hybrid_cache_controller`. This method:
  1. Validates the descriptor has `residency_state == cold`, cold store is configured, and no
     promotion is already in progress.
  2. Sets `residency_state = promoting`.
  3. Calls `worker.enqueue_promotion(payload_id, cold_ref, descriptor_snapshot, ...)`. If enqueue
     returns queue-full, immediately reverts `residency_state = cold`, emits a warning diagnostic,
     and returns failure. The current request falls back to the slower path.
  4. Returns. The `server_context` thread is not blocked.
- Add `handle_promotion_completion(io_completion_result)` called from `process_completions`:
  - On success: insert promoted bytes into `hot_payloads`, update `store_ref.id` to the new hot
    record key, set `residency_state = hot`, increment `cache_payload_promotions_total{result=success}`.
  - On failure: set `residency_state = evicted`, emit error diagnostic, increment promotion failure
    counter. Cold file is retained (not removed) for operator inspection unless it is not found.
- In `try_restore_from_cache`, when the selected descriptor has `residency_state == cold`, call
  `promote_payload` and fall back for the current request. Subsequent requests will find the
  descriptor hot after promotion completes.
- **Implementation note on validation order:** design Part 3, promotion protocol step 6, contains
  both prose and a numbered check list. The prose lists validation items in a different order
  from the numbered list. Implementers must follow the numbered check list order (magic,
  format_version, header_checksum, checksum_algorithm, payload_id, pair_state, target_size_bytes,
  draft_size_bytes, target payload bytes, draft payload bytes), not the prose order.

Acceptance test: add a focused test that promotes a cold descriptor through a fake cold store.
Confirm `residency_state == hot` after `process_completions`. Confirm queue-full leaves
`residency_state == cold`. Confirm draft-side failure for `target_and_draft` transitions to
`evicted` and not partially hot. Add cases to `tests/test-cache-controller.cpp`.

Dependencies: Steps 1, 4, 5, 6, 8.

---

### Step 8: Integration with `hybrid_cache_controller` - wiring and startup configuration

Goal: wire the cold store and worker into `hybrid_cache_controller` construction and add startup
configuration check for `--cache-cold-path`.

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`

Changes:

- `server-cache-hybrid.h`: add `server_cache_store_cold cold_store` and
  `server_cache_io_worker io_worker` as private members of `hybrid_cache_controller`.
  Add `cold_path` field in construction parameters if the constructor receives it directly, or
  read it from `params` if `common_params` already carries `--cache-cold-path`.
- `server-cache-hybrid.cpp`: in the `hybrid_cache_controller` constructor, if
  `cold_path` is non-empty, call `cold_store.configure(cold_path, FORMAT_VERSION_1)`. If
  `configure` fails, throw or propagate the error. If configure succeeds, call `io_worker.start()`.
  Store configured state. In the destructor, call `io_worker.stop()` before releasing the cold
  store.
- `server-context.cpp`: in the server startup sequence that constructs the cache controller,
  validate `--cache-cold-path` (see Step 9) before passing it to the constructor. If validation
  fails, terminate startup with an error diagnostic. Do not use the C `abort()` function; use a graceful exit mechanism (return error code, `exit()`, or throw).

Acceptance test: construct `hybrid_cache_controller` with a valid temporary directory as cold path.
Confirm `cold_store.is_configured()` returns true. Confirm the worker thread is running. Call the
destructor, confirm the worker thread has joined. Add to focused C++ tests.

Dependencies: Steps 2, 5.

---

### Step 9: Startup validation

Goal: implement all five startup validation checks for the cold store configuration specified in
design Part 5.

Affected files:

- `tools/server/server-cache-store-cold.cpp`
- `tools/server/server-context.cpp`

Changes:

- In `server_cache_store_cold::configure`: check that root path is non-empty, exists as a
  directory, and is writable by the server process. On any check failure, log a diagnostic that
  includes the failing check name and the configured path value, and return failure. Do not throw.
- In `server_cache_store_cold::configure` or in the worker startup: worker thread creation failure
  is treated as startup failure. Log diagnostic and return failure.
- In `server-context.cpp` startup: if `--cache-cold-path` is set and `configure` returns failure,
  terminate server startup with an error before `accept()` with a message sufficient for an operator to correct the
  configuration without consulting source code.
- Add a world-writable directory check: if the cold store root is world-writable, emit a warning
  diagnostic. Do not terminate startup for this condition alone.
- **Inherited check:** design Part 5 startup validation table includes a fifth check that
  `--cache-ram` is set to a positive value when hybrid mode is enabled. This check was implemented
  in Stage 4 and is not re-implemented in Step 9. The existing Stage 4 validation continues to run
  in the startup path and is not broken by Step 9's changes. Step 9 adds only the four cold-store-
  specific checks listed above.

Acceptance test: start `llama-server` with a non-existent cold path; confirm exit before accepting
requests with a diagnostic message. Start with a non-writable path (chmod 000 on Linux or deny
write on Windows); confirm termination. Confirm that a valid path starts the server normally. These
checks can be added to the Python test suite as pytest cases.

**Implementation note on startup failure handling:** All startup validation failures must terminate the server process using a graceful exit mechanism. Do not use the C `abort()` function or any mechanism that triggers a dialog or crash handler. Acceptable patterns include returning a non-zero exit code from `main()`, calling `exit(EXIT_FAILURE)`, or throwing an exception that is caught at the top level. The `abort()` function produces an unhandleable dialog on Windows and must not be used.

Dependencies: Steps 2, 8.

---

### Step 10: Metrics

Goal: add `cache_payload_promotions_total`, `cache_payload_demotions_total`,
`cache_payload_cold_evictions_total`, `cache_cold_restore_latency_seconds`,
`cache_cold_payload_bytes`, `cache_cold_payload_count`, and extended `cache_hot_payload_count` as
specified in design Part 5.

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`

Changes:

- Add counters for demotion success, demotion failure (with reason), promotion success, promotion
  failure (with failure_reason label matching design Part 5), and cold eviction to the stats
  struct.
- Add a latency tracker field: record enqueue timestamp for each promotion, compute elapsed time
  on promotion completion, bucket into the histogram.
- Add gauge fields for current `cache_cold_payload_bytes` and `cache_cold_payload_count`. Update
  them in demotion completion (add) and in cold eviction or promotion completion (subtract or
  reassign).
- Extend `cache_hot_payload_count` gauge to decrement when a descriptor moves out of `hot`
  (including to `demoting`) and increment when a descriptor moves back to `hot` (promotion success
  or demotion revert).
- Update `get_stats()` JSON and the Prometheus metric export path to include all new counters and
  gauges.
- `cache_payload_evictions_total` from Stage 4 must NOT count payloads that are successfully
  demoted to cold. Only payloads discarded without a successful cold write increment it.

Acceptance test: run focused tests that drive demotion and promotion through a fake store. Check
`get_stats()` output for all new counters. Run the existing metrics-shape Python test; extend it
to check for the new metric names. Confirm `cache_payload_evictions_total` does not increment on
successful demotion.

Dependencies: Steps 6, 7.

---

### Step 11: Test hooks and fault injection

Goal: add `LLAMA_SERVER_CACHE_TESTS` guarded test hooks for the cold store and worker to enable
isolated testing without disk I/O against a real filesystem.

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-store-cold.h`
- `tools/server/server-cache-io-worker.h`
- `tests/test-cache-controller.cpp`

Changes:

- Add an injectable fake cold store backend: `debug_set_cold_store_backend_for_tests` replaces
  the real `server_cache_store_cold` with an in-memory fake that records operations without
  disk I/O. The fake supports configurable failure injection per payload_id.
- Add `debug_set_worker_completion_delay_for_tests(ms)` to inject latency between task enqueue
  and callback, enabling verification that `server_context` does not block.
- Add `debug_set_worker_queue_capacity_for_tests(n)` to override queue depth to 1 for queue-full
  tests.
- Add `debug_inject_promotion_failure_for_tests(payload_id)` to configure the fake store to
  return a checksum mismatch failure for a specific payload_id.
- Add `debug_get_residency_state_for_tests(payload_id)` to read the current `residency_state`
  without going through the normal restore path.
- Add fault injection test cases to `tests/test-cache-controller.cpp` covering all ten fault
  injection points listed in design Part 6.

Acceptance test: all ten fault injection cases from design Part 6 must have a corresponding test
case that compiles and passes under `ctest -R test-cache-controller`.

Dependencies: Steps 5, 6, 7.

---

### Step 12: Documentation updates

Goal: update durable documents to reflect Stage 6 implementation state.

Affected files:

- `._design_docs/cache-handling-phase6-implementation.md`
- `._design_docs/cache-handling-phase6-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase6-implementation/part-02-implementation-plan-continued.md`
- `._design_docs/document-index.md` (if not already updated)

Changes:

- After each step completes, update the Phase 6 implementation log status and record changed files,
  behavior changes, and evidence in a new implementation evidence part.
- Update `document-index.md` if new implementation parts are added.
- Do not modify design documents for implementation details. If a design gap is found, record it
  as a blocker and follow the design correction process before continuing.

Acceptance test: `document-index.md` links to the Phase 6 implementation entry. The entry
document TOC links to all created parts.

Dependencies: all prior steps.

---

## Known risks and mitigations

| Risk | Mitigation |
| --- | --- |
| `common_params` does not yet carry a `--cache-cold-path` field | Add the field to `common_params` in Step 8 or pass the path as a constructor argument; do not add to upstream CLI until the cold layer is complete |
| Hot-byte release ordering bug leaves a descriptor stuck in `demoting` | NB-5 pin in Step 6 makes release conditional on success callback; fault injection in Step 11 verifies the ordering |
| FNV-1a checksum collisions on cold file content | FNV-1a is chosen for consistency with Stage 5; design records algorithm in the file header so a future algorithm upgrade does not silently break old files |
| Atomic rename unavailable on cross-volume cold store path | Startup path normalization in Step 9 should detect cross-volume conditions; if not detectable at startup, rename failure at write time triggers the demotion failure path and reverts to hot |
| Worker thread join hangs at shutdown if a file I/O call blocks indefinitely | Worker thread uses O_NONBLOCK or a timeout where available; if the OS does not support it, shutdown join is capped and the risk is documented in implementation evidence |
| Test-hook fake store diverges from real store behavior | Fake store must implement the same validation sequence as the real store; discrepancies found during review block the step |

## Evidence plan

After each numbered step completes, the developer records the following before advancing:

- Changed file paths
- Description of behavior change or new behavior
- Build command and output (pass or fail)
- Focused test result: `ctest -R test-cache-controller --output-on-failure` output
- For Steps 9 and 10: Python pytest output for relevant test cases
- Any deviation from the plan and the resolution

Evidence is written to a new implementation evidence part (`part-04-implementation-evidence.md`
or later parts if size requires splitting) before the step is marked complete.
