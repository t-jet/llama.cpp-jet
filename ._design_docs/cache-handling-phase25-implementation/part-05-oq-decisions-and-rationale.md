# Stage 25 implementation plan: Part 5: OQ decisions and rationale

Source: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)

This part records the open-question decisions from
[design Part 7](../cache-handling-phase25-design/part-07-risks-and-open-questions.md)
that Manager selected during the design gate, and the
rationale for each selection.

## OQ-25-01 apply-step lock scope: SPLIT

Decision: SPLIT (cache-state transaction only).

Rationale:

- The slot thread owns the live `llama_context` for the
  duration of apply. Apply mutates inference state, not
  cache state. Holding the cache-state lock during apply
  serializes inference apply with every other cache
  mutation across all slots and the server-context thread.
- The user requirement is "all operations which require
  cache modifications should be performed in atomic
  transactional mode." Apply does NOT modify cache state
  by itself; it mutates the live `llama_context`.
- The split follows the architecture Part 2 Restore and
  Residency Flow: step 7 (promote + plan) inside
  `tx_restore` under lock; step 8 (apply) outside lock on
  the slot thread; step 9 (finalize) inside `tx_apply_restore`
  under lock. The plan-and-finalize parts are the
  cache-state mutations; apply is the inference-apply step.

Alternative considered: full apply under lock.

Rejected because holding the cache-state lock for the
duration of `llama_state_seq_set_data_ext` (a multi-KiB
write to inference state) blocks every other cache
mutation for the duration of the write. For the Qwen3.5-4B
MTP fixture the apply write is bounded but non-trivial;
the regression estimate against this alternative is
unbounded because apply time scales with payload bytes.

Implementation binding: Step 5 declares
`tx_apply_restore(slot, plan)` as a public method that
re-acquires the lock for owner-view sync and metrics
finalization. The slot thread invokes
`tx_apply_restore` after apply completes. TP-25-UT5
asserts the apply step does not hold the lock.

## OQ-25-02 worker retirement: Option B

Decision: Option B (replace `io_worker` thread with
stateless synchronous helper invoked inline under lock).

Rationale:

- Option B removes a thread that no longer mutates cache
  state. The thread becomes pure overhead (memory, kernel
  scheduler entry, idle CPU).
- Option B eliminates the entire `enqueue_demotion` and
  `enqueue_promotion` queue paths and the
  `process_completions` drain. The inline implementation
  is shorter and easier to reason about.
- Option B matches the user's stated intent: "all
  operations which requires cache modifications should be
  performed in atomic transactional mode" -- the
  transactional model does not need a background thread.
- Option A (keep the thread idle) was rejected because
  it preserves dead code and confuses future readers
  (R-25-IMP-08).

Alternative considered: Option A (keep thread, call inline).

Rejected per R-25-IMP-08 and the user requirement for a
fully synchronous model.

Implementation binding: Step 2 stops starting the
`io_worker` thread in the constructor and removes the
`if (io_worker.is_running()) io_worker.stop();` line in
the destructor. The `enqueue_demotion` /
`enqueue_promotion` methods remain as signatures but
execute synchronously on the caller. TP-25-UT8 asserts
`io_worker.is_running()` returns false on a controller
constructed with a non-empty cold path.

## OQ-25-03 transaction_wait_exceeded default: 500 ms

Decision: 500 ms.

Rationale:

- 500 ms is the design's suggested default (Part 2
  timeout and deadlock detection section).
- For the Qwen3.5-4B MTP fixture, the cold-store read
  and write latencies observed in Stage 24 -06 are well
  under 100 ms for typical payloads; 500 ms gives a
  generous margin.
- A shorter default (e.g., 100 ms) would produce false
  positives on cold restores and mask real contention.
- A longer default (e.g., 1000 ms) would hide contention
  regressions.

Alternative considered: 100 ms.

Rejected as too sensitive for the typical cold-store
latency distribution.

Implementation binding: Step 6 declares
`std::chrono::milliseconds transaction_wait_threshold_{500};`
on the controller. TP-25-UT9 drives a 600 ms artificial
sleep inside the critical section and asserts the
diagnostic fires once on the waiting thread.

## OQ-25-04 reentrancy depth limit default: 4

Decision: 4.

Rationale:

- 4 is the design's suggested default (Part 2 reentrancy
  rule section).
- The documented inner-call set is 3 deep:
  `tx_save -> tx_evict_entry`,
  `tx_restore -> tx_update`,
  `tx_update -> tx_evict_entry`.
- 4 permits one level of margin (e.g., a future
  `tx_evict_entry -> tx_demote_payload` reentrance would
  still be permitted).
- 5 (limit + 1) fails-fast.

Alternative considered: 8.

Rejected as too permissive; a deep call chain is more
likely to indicate a code defect than a legitimate
reentrance.

Implementation binding: Step 7 declares
`size_t reentrancy_depth_limit_ = 4;` on the controller.
TP-25-UT6 exercises depth 5 and asserts the rejection
path returns false without mutating state.

## OQ-25-05 cold-store metric drift: KEEP SEPARATE

Decision: KEEP SEPARATE (out of scope for Stage 25).

Rationale:

- The cold-store metric-vs-filesystem drift observed in
  Stage 24 (5.78 GiB on disk vs 351.7 MiB metric in S02
  hybrid -06) is documented in D-CLOSURE-24-01 (c) as a
  separate observation.
- The drift does not block Stage 24 closure or Stage 25
  implementation. The metric-based budget check passes and
  the runner classifies the leg as PASS.
- Folding the drift into Stage 25 would expand scope and
  delay the design-correct atomic transaction work.

Alternative considered: include in Stage 25.

Rejected per scope discipline. The drift is a separate
investigation.

Implementation binding: Step 11 records the drift
observation in the Stage 25 rerun evidence but does not
attempt a fix. The drift is left as a follow-up.

## OQ-25-06 reentrancy counter: slot context member

Decision: slot context member (NOT thread_local).

Rationale:

- The counter is a property of the slot thread's
  transaction context, not a global property. Per-thread
  storage (`thread_local`) would lose the counter on
  thread exit and could mask reentrance bugs across
  thread joins.
- A slot context member (`server_slot::cache_tx_depth`)
  persists for the duration of the slot's lifetime and is
  inspectable in tests.
- The server-context thread does not have a slot, so the
  counter lives on the controller
  (`hybrid_cache_controller::server_context_tx_depth_`)
  for that thread.

Alternative considered: `thread_local` storage.

Rejected because the counter must persist across thread
exits for diagnostic completeness.

Implementation binding: Step 7 declares the slot
counter on `server_slot` and the server-context counter
on `hybrid_cache_controller`. The `debug_get_transaction_depth_for_tests`
hook (Part 2 test-only debug hook) exposes the counter
value.

## Handoff state at end of part 5

All 6 OQ decisions are recorded with rationale and
implementation binding. The decisions are consistent with
the design Parts 2, 6, and 7. Part 6 records the open
implementation questions for Architect review.
