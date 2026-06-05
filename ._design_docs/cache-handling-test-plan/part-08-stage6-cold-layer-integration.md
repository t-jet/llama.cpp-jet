# Cache handling test plan - Part 8: Stage 6 cold layer integration

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Stage 6 scope

Stage 6 adds cold payload storage and an asynchronous I/O worker on top of the descriptor and pairing contract delivered by Stage 5. Payloads evicted from hot RAM can be written to a versioned filesystem store and restored on demand. The cold layer is disabled unless `--cache-cold-path` is configured. When unconfigured, the server behaves identically to Stage 5.

Design document: [cache-handling-phase6-design.md](../cache-handling-phase6-design.md)
Implementation log: [cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)
Implementation review: [part-13-implementation-review.md](../cache-handling-phase6-implementation/part-13-implementation-review.md)

### Implementation review findings

The implementation review passed with four non-blocking findings:

- NB-1: `promotion_enqueue_time` is a single field, not per-payload. Acceptable for histogram bucketing but may need per-payload tracking for concurrent promotions in a future stage.
- NB-2: `n_cold_payload_bytes` underflow guard silently drops subtraction if the guard fails. Acceptable defensive pattern for a gauge metric.
- NB-3: `cold_store_header` byte-offset discrepancy between design and implementation. The implementation uses alignment padding at bytes 6-7 and shifts `payload_id` to bytes 8-15. The binary format is self-consistent. Should be resolved before external tools read cold files.
- NB-4: Redundant residency check in `demote_payload` (dead code, not a bug).

### Focused C++ test coverage

The following focused C++ tests cover Stage 6 internals:

- Step 1: 8 tests (state machine transitions including `demoting` and `promoting`)
- Step 2: 15 tests (cold store interface: configure, write, read, remove, validation)
- Steps 3-4: 29 tests (cold file write/read validation including atomic rename, checksums, format)
- Step 5: 20 tests (I/O worker: start, stop, enqueue, completion, queue-full, shutdown race)
- Step 6: 16 tests (demotion protocol: eligibility, transient state, completion, eviction integration, protected root warning)
- Step 7: 16 tests (promotion protocol: eligibility, transient state, completion, fallback, draft-side failure)
- Step 8: 13 tests (integration wiring: constructor, destructor, startup validation, cold store configuration)
- Step 9: 12 tests (startup validation: empty path, non-existent path, file path, non-writable, world-writable warning)
- Step 10: 8 tests (metrics: demotion/promotion counters, cold payload bytes, cold payload count, eviction exclusion)
- Step 11: 17 tests (test hooks and fault injection: residency state query, promotion failure injection, cold store backend, worker delay, queue capacity, all ten fault injection points)

These focused tests are not integration coverage. They are cited as supplemental evidence for internal failure preconditions that public HTTP cannot create.

## Cold store opt-in behavior

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| C60 | No `--cache-cold-path` — identical Stage 5 behavior | hybrid, no `--cache-cold-path` | Server starts and serves requests identically to Stage 5. No cold store is configured. No demotion occurs. Evicted payloads are discarded. `/metrics` shows no cold-layer counters. All Stage 5 regression tests (H40-H58) pass unchanged. |
| C61 | `--cache-cold-path` with valid directory | hybrid, `--cache-cold-path <valid-dir>` | Server starts. Cold store is configured. I/O worker thread is running. `/metrics` includes `llamacpp_cache_payload_demotions_total`, `llamacpp_cache_payload_promotions_total`, `llamacpp_cache_cold_payload_bytes`, and `llamacpp_cache_cold_payload_count`. |
| C62 | `--cache-cold-path` requires hybrid mode | legacy, `--cache-cold-path <valid-dir>` | Server startup fails with a diagnostic stating that `--cache-cold-path` requires hybrid mode. Process exits nonzero. |
| C63 | `--cache-cold-path` with non-existent path | hybrid, `--cache-cold-path <non-existent>` | Server startup fails with a diagnostic identifying the invalid path. Process exits nonzero. |
| C64 | `--cache-cold-path` with a file path (not directory) | hybrid, `--cache-cold-path <file>` | Server startup fails with a diagnostic identifying the path as not a directory. Process exits nonzero. |
| C65 | `--cache-cold-path` with non-writable directory | hybrid, `--cache-cold-path <non-writable-dir>` | Server startup fails with a diagnostic identifying the write-access failure. Process exits nonzero. On Windows, this check may be skipped if the POSIX permission model does not apply. |

## Demotion: hot payloads demoted to cold

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H60 | Demotion under budget pressure | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>` | Create enough unique entries to exceed the hot budget. When eviction selects a hot payload, the descriptor transitions to `cold` instead of `evicted`. `/metrics` shows `llamacpp_cache_payload_demotions_total{result="success"}` incremented. `llamacpp_cache_cold_payload_bytes` increases by the demoted payload size. `llamacpp_cache_cold_payload_count` increases. |
| H61 | Demotion preserves target/draft pair | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, draft model | Save a `target_and_draft` entry. Trigger demotion. Both target and draft bytes are written to the same cold file. The descriptor transitions to `cold` as a unit. `llamacpp_cache_payload_demotions_total{result="success"}` increments once for the pair. |
| H62 | Demoted payload is not in hot store | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>` | After demotion, the hot payload record is released. `llamacpp_cache_hot_payload_descriptors` decreases. The descriptor `residency_state` is `cold`. A subsequent restore attempt for the same entry triggers promotion, not a hot hit. |
| H63 | Protected root demotion warning | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, stats-capable harness | When a protected root is demoted, the server emits a warning diagnostic and increments `n_protected_root_demotions`. The demotion still proceeds; protection does not prevent demotion when no unprotected candidates remain. |
| H64 | Demotion does not block server_context | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>` | During demotion, the server continues to serve requests. No request latency spike correlates with cold file I/O. Use a stats-capable harness or focused C++ test to verify that `demote_payload` returns immediately after enqueue. |
| H65 | Queue-full demotion fallback | hybrid, `--cache-cold-path <dir>`, queue capacity 1 (test hook) | When the I/O worker queue is full, `demote_payload` returns false. The descriptor reverts to `hot`. A diagnostic is emitted. The payload may be evicted immediately if the hot budget still requires it. |

## Promotion: cold payloads promoted back to hot

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H66 | Promotion on cache hit | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>` | Save entry A. Trigger demotion so A becomes cold. Send a request that would hit A. The controller enqueues promotion for A. The current request falls back (cache miss). After promotion completes, a subsequent request hits A as hot. `llamacpp_cache_payload_promotions_total{result="success"}` increments. |
| H67 | Promotion restores target and draft | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, draft model | Demote a `target_and_draft` entry. Trigger promotion. Both target and draft bytes are restored to the hot store. The descriptor transitions to `hot`. A subsequent request hits with `timings.cache_n > 0`. |
| H68 | Promotion failure marks evicted | hybrid, `--cache-cold-path <dir>`, fault injection | Corrupt a cold file (flip a byte). Trigger promotion. The descriptor transitions to `evicted`. `llamacpp_cache_payload_promotions_total{result="failure"}` increments with a `failure_reason` label. A diagnostic is emitted. The cold file is retained for inspection. |
| H69 | Queue-full promotion fallback | hybrid, `--cache-cold-path <dir>`, queue capacity 1 (test hook) | When the I/O worker queue is full, `promote_payload` returns false. The descriptor remains `cold`. The current request falls back. A diagnostic is emitted. |
| H70 | Promotion latency is observable | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, `--metrics` | After a successful promotion, `/metrics` includes `llamacpp_cache_cold_restore_latency_seconds` histogram buckets with at least one observation. |

## Startup validation

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| N30 | Empty `--cache-cold-path` | hybrid, `--cache-cold-path ""` | Server startup fails with a diagnostic stating the path is empty. Process exits nonzero. |
| N31 | Non-existent `--cache-cold-path` | hybrid, `--cache-cold-path <non-existent>` | Server startup fails with a diagnostic identifying the non-existent path. Process exits nonzero. |
| N32 | `--cache-cold-path` points to a file | hybrid, `--cache-cold-path <file>` | Server startup fails with a diagnostic stating the path is not a directory. Process exits nonzero. |
| N33 | Non-writable `--cache-cold-path` | hybrid, `--cache-cold-path <non-writable-dir>` | Server startup fails with a diagnostic identifying the write-access failure. On Windows, this check may be skipped. |
| N34 | World-writable `--cache-cold-path` warning | hybrid, `--cache-cold-path <world-writable-dir>` | Server starts with a warning diagnostic about world-writable permissions. Startup does not fail. |
| N35 | `--cache-cold-path` without hybrid mode | legacy, `--cache-cold-path <valid-dir>` | Server startup fails with a diagnostic stating `--cache-cold-path` requires hybrid mode. Process exits nonzero. |

## Metrics

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| M10 | Demotion and promotion counters | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, `--metrics` | After demotion, `/metrics` includes `llamacpp_cache_payload_demotions_total{result="success"}`. After promotion, `/metrics` includes `llamacpp_cache_payload_promotions_total{result="success"}`. Failure counters increment on demotion or promotion failure. |
| M11 | Cold payload bytes gauge | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, `--metrics` | After demotion, `llamacpp_cache_cold_payload_bytes` increases by the demoted payload size (target + draft bytes). After promotion, it decreases. After cold eviction, it decreases. |
| M12 | Cold payload count gauge | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, `--metrics` | `llamacpp_cache_cold_payload_count` reflects the number of descriptors with `residency_state == cold`. It increases on demotion and decreases on promotion or cold eviction. |
| M13 | Hot payload count gauge | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, `--metrics` | `llamacpp_cache_hot_payload_count` reflects the number of descriptors with `residency_state == hot`. It decreases on demotion and increases on promotion. |
| M14 | Eviction excludes demoted payloads | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, `--metrics` | `llamacpp_cache_payload_evictions_total` does not count payloads that are demoted to cold. Demoted payloads are tracked by `llamacpp_cache_payload_demotions_total` instead. |
| M15 | Cold restore latency histogram | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, `--metrics` | After a successful promotion, `llamacpp_cache_cold_restore_latency_seconds` histogram has at least one observation. |
| M16 | Demotion failure reason counters | hybrid, `--cache-cold-path <dir>`, fault injection | `llamacpp_cache_payload_demotions_total{result="failure"}` increments on demotion failure. Failure reason counters (`n_demotion_failure_write`, `n_demotion_failure_queue_full`) are available in controller stats. |
| M17 | Promotion failure reason counters | hybrid, `--cache-cold-path <dir>`, fault injection | `llamacpp_cache_payload_promotions_total{result="failure"}` increments on promotion failure. Failure reason counters (checksum, format, payload_id, pair_state, header_checksum, magic, draft_checksum, other) are available in controller stats. |

## Fault tolerance

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| F01 | Cold file checksum corruption | hybrid, `--cache-cold-path <dir>`, fault injection | Flip a byte in a cold file after demotion. Trigger promotion. The descriptor transitions to `evicted`. A checksum mismatch diagnostic is emitted. `llamacpp_cache_payload_promotions_total{result="failure"}` increments. The cold file is retained for inspection. |
| F02 | Cold store read failure | hybrid, `--cache-cold-path <dir>`, fault injection | Inject a read failure in the cold store backend. Trigger promotion. The descriptor transitions to `evicted`. A diagnostic is emitted. No partial payload is restored. |
| F03 | Cold file header truncation | hybrid, `--cache-cold-path <dir>`, fault injection | Write a truncated cold file (short header). Trigger promotion. Header checksum validation fails. The descriptor transitions to `evicted`. No partial parse occurs. |
| F04 | Format version mismatch | hybrid, `--cache-cold-path <dir>`, fault injection | Write a cold file with an unsupported format version. Trigger promotion. The descriptor transitions to `evicted`. A diagnostic notes the unsupported version. |
| F05 | Payload ID mismatch | hybrid, `--cache-cold-path <dir>`, fault injection | Write a cold file with a different `payload_id`. Trigger promotion. The descriptor transitions to `evicted`. A diagnostic notes possible file collision or corruption. |
| F06 | Pair state mismatch | hybrid, `--cache-cold-path <dir>`, fault injection | Write a cold file with `target_only` for a `target_and_draft` descriptor. Trigger promotion. The descriptor transitions to `evicted`. A pair state mismatch diagnostic is emitted. |
| F07 | Magic mismatch | hybrid, `--cache-cold-path <dir>`, fault injection | Write a cold file with an invalid magic marker. Trigger promotion. The descriptor transitions to `evicted`. A diagnostic notes the invalid magic. |
| F08 | Draft-side promotion failure for `target_and_draft` | hybrid, `--cache-cold-path <dir>`, fault injection, draft model | Corrupt the draft checksum in a cold file for a `target_and_draft` descriptor. Trigger promotion. The descriptor transitions to `evicted`. No partial-hot state results. Target bytes are not left in the hot store. |
| F09 | Demotion write failure | hybrid, `--cache-cold-path <dir>`, fault injection | Inject a write failure in the cold store backend during demotion. The descriptor reverts to `hot` if the hot record is still held, or transitions to `evicted` if the hot record has been released. A diagnostic is emitted. |
| F10 | Worker shutdown race | hybrid, `--cache-cold-path <dir>`, test hook | Call `stop()` on the I/O worker while a demotion or promotion task is in progress. The in-progress task completes. Queued tasks receive a cancelled failure callback. No descriptor is left in an ambiguous state. |

## Protected root demotion warning

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H71 | Protected root demoted with warning | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, stats-capable harness | When all hot payloads are protected roots and the budget is exceeded, the LRU policy selects a protected root for demotion. The server emits a warning diagnostic. `n_protected_root_demotions` increments. The demotion proceeds; protection does not prevent demotion when no unprotected candidates remain. |

## Target/draft pair demotion and promotion as a unit

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| H72 | Target/draft pair demoted together | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, draft model | Save a `target_and_draft` entry. Trigger demotion. Both target and draft bytes are written to the same cold file. The descriptor transitions to `cold` as a single unit. `llamacpp_cache_payload_demotions_total{result="success"}` increments once. |
| H73 | Target/draft pair promoted together | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>`, draft model | Demote a `target_and_draft` entry. Trigger promotion. Both target and draft bytes are restored to the hot store. The descriptor transitions to `hot`. A subsequent request hits with `timings.cache_n > 0`. |
| H74 | Draft-side failure evicts entire pair | hybrid, `--cache-cold-path <dir>`, fault injection, draft model | Corrupt the draft checksum in a cold file for a `target_and_draft` descriptor. Trigger promotion. The entire descriptor transitions to `evicted`. No partial-hot state results. Target bytes are not left in the hot store. |

## Stage 4 and Stage 5 regression

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| R10 | Stage 4 regression with cold store configured | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>` | Re-run H30-H39 evidence paths. Cold store configuration must not weaken byte budget enforcement, LRU ordering, protected-root priority, failed-restore recency semantics, equivalent refresh budget enforcement, or Stage 4 metric export. |
| R11 | Stage 5 regression with cold store configured | hybrid, `--cache-ram 1`, `--cache-cold-path <dir>` | Re-run H40-H58 evidence paths. Descriptor ownership, pair-state validation, transactional restore, and Stage 5 metrics must remain correct when the cold store is configured. |
| R12 | Legacy mode unchanged by cold store flags | legacy, `--cache-cold-path <valid-dir>` | Server startup fails because `--cache-cold-path` requires hybrid mode. Legacy mode is not altered by the presence of cold store configuration. |

## Observable signals for Stage 6

For cold layer tests, verify:

- `/metrics` includes `llamacpp_cache_payload_demotions_total{result="success"}` and `llamacpp_cache_payload_demotions_total{result="failure"}`.
- `/metrics` includes `llamacpp_cache_payload_promotions_total{result="success"}` and `llamacpp_cache_payload_promotions_total{result="failure"}`.
- `/metrics` includes `llamacpp_cache_cold_payload_bytes` and `llamacpp_cache_cold_payload_count`.
- `/metrics` includes `llamacpp_cache_hot_payload_count`.
- `/metrics` includes `llamacpp_cache_cold_restore_latency_seconds` histogram buckets.
- `llamacpp_cache_payload_evictions_total` does not count demoted payloads.
- Server logs contain demotion, promotion, and cold store diagnostics.
- Cold files exist in the configured `--cache-cold-path` directory after demotion.
- Cold files are removed or retained on promotion failure per the design.
- Startup fails with a clear diagnostic for invalid `--cache-cold-path` configurations.

## Evidence requirements

Public HTTP can prove:

- Cold store opt-in behavior (server starts or fails based on `--cache-cold-path`).
- Demotion and promotion counter changes in `/metrics`.
- Cold payload byte and count gauge changes in `/metrics`.
- Eviction counter does not count demoted payloads.
- Startup validation rejects invalid configurations.
- Stage 4 and Stage 5 regression when cold store is configured.

Public HTTP cannot directly prove:

- Residency state transitions (`demoting`, `promoting`, `cold`).
- Descriptor state after demotion or promotion completion.
- I/O worker queue-full behavior.
- Cold file integrity validation order.
- Hot byte release timing (NB-5 pinning).
- Protected root demotion warning diagnostics.
- Draft-side promotion failure atomicity.

For these internal behaviors, use focused C++ controller tests (Steps 1-11) or a stats-capable integration harness. Report rows that require internal evidence as `BLOCKED` if the harness is not available, and hand the gap to Developer.

## Notes on NB findings

- NB-1 (single-field promotion latency): The `promotion_enqueue_time` field is overwritten by concurrent promotions. This is acceptable for histogram bucketing but may produce inaccurate latency measurements when multiple promotions are in flight. Test evidence should note this limitation.
- NB-2 (`n_cold_payload_bytes` underflow guard): The subtraction guard silently drops the subtraction if the guard fails. This is a defensive pattern. Test evidence should verify that `n_cold_payload_bytes` does not underflow in normal operation.
- NB-3 (`cold_store_header` byte-offset discrepancy): The implementation uses alignment padding at bytes 6-7, shifting `payload_id` to bytes 8-15. The binary format is self-consistent. This should be resolved before external tools read cold files, but it does not affect integration testing because the implementation reads and writes the same format.
- NB-4 (redundant residency check): The "already demoting" check in `demote_payload` is dead code because the "not hot" check catches it first. This does not affect behavior.
