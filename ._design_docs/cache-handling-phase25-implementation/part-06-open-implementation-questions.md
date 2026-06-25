# Stage 25 implementation plan: Part 6: open implementation questions

Source: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)

This part records the open implementation questions for
Architect review. Each question names the specific
ambiguity in the target state spec or the test
infrastructure, and the proposed resolution.

## OQ-25-IMP-01: stage22_handle_demotion_completion test helper retention

The existing test helper
`stage22_handle_demotion_completion(ctrl, result)` in
`tests/test-cache-controller.cpp` line 3461 injects a
specific completion result into
`hybrid_cache_controller::handle_demotion_completion`
for tests that need to assert on a specific residency
transition (TP-22-UT1..UT8).

After Stage 25 the inline implementation runs
synchronously and there are no queued completions. The
helper remains as a private access path because the
inline implementation still calls
`handle_demotion_completion` internally to apply the
success or failure path. TP-22-UT1..UT8 continue to work.

Question: is the retention of the helper acceptable, or
should the test access path be reworked to drive the
inline implementation directly?

Proposed resolution: retain the helper. The inline
implementation is the new canonical entry point; the
helper is a private seam for tests that need fine-grained
control over completion injection. No production code
outside the controller calls `handle_demotion_completion`.

## OQ-25-IMP-02: io_worker.execute_inline signature compatibility

The current `enqueue_demotion` /
`enqueue_promotion` methods on `server_cache_io_worker`
return `bool` (true if enqueued, false if queue full).
After Stage 25 they execute synchronously and return the
completion result inline.

Question: should the signatures change to return
`io_completion_result` directly, or should they keep the
`bool` return and write the result to an out-parameter?

Proposed resolution: keep the `bool` return and add an
out-parameter `io_completion_result & out`. This is the
minimum-change path that preserves the public signature
and lets the inline implementation pass the completion
result up to the transaction method.

Alternative: change to `std::optional<io_completion_result>`
return. Cleaner but requires a wider signature change.

Architect review should select one. The plan defaults to
the out-parameter approach.

## OQ-25-IMP-03: tx_apply_restore argument shape

The proposed signature is
`void tx_apply_restore(server_slot & slot, const cache_response & plan);`.

The `cache_response` type holds the restore plan from
`try_restore_from_cache` and includes the
`RestorePlanKind` (exact_blob_hot, checkpoint_or_blob,
fallback_recompute) and the selected payload id.

Question: should `tx_apply_restore` take the slot by
reference or by pointer? Should the plan be by value or
by const reference?

Proposed resolution: take the slot by reference and the
plan by const reference. The slot is mutable (apply
mutates it) and the plan is read-only. Matches the
existing `try_restore_from_cache(slot, task)` signature.

Architect review should confirm.

## OQ-25-IMP-04: tp_assert_mutex_held behavior in release builds

The proposed `tx_assert_mutex_held` helper uses
`assert(cache_state_mutex_.try_lock() == false);` which
compiles to a no-op when `NDEBUG` is defined.

Question: should the helper remain a no-op in release
builds, or should it use a runtime check that does not
depend on `NDEBUG`?

Proposed resolution: remain a no-op in release builds.
The helper is a developer-time guard, not a runtime
correctness check. Production code that fails to hold
the lock at the helper entry is a code defect caught at
test time, not at runtime. The build/test infrastructure
already runs with `#undef NDEBUG` in the test file
(`tests/test-cache-controller.cpp` line 22), so the
assertion fires during the test pack.

Architect review should confirm.

## OQ-25-IMP-05: reentrancy counter thread-safety

The two reentrancy counters (`server_slot::cache_tx_depth`
and `hybrid_cache_controller::server_context_tx_depth_`)
are read and written only by their respective threads.
No cross-thread access occurs.

Question: should the counters be `std::atomic<size_t>` or
plain `size_t`?

Proposed resolution: plain `size_t`. The counters are
single-threaded (each thread has its own counter). The
mutex that protects cache state does not need to extend
to the counter.

Architect review should confirm.

## OQ-25-IMP-06: Stage 24 chat rerun runner contract

The existing `stage24-chat-s02-s03-comparison.ps1`
runner is unchanged. The Stage 25 rerun uses the same
runner script with the new binary.

Question: does the runner need to record the new binary's
`git rev-parse HEAD` SHA in the run root metadata, or is
the binary path sufficient?

Proposed resolution: the runner already records the
binary path and the CUDA build proof in the dry-run
plan. Add the git SHA to the run root metadata via a
runner-side `--GitSha` argument if needed. Otherwise
record the SHA in the implementation log manually.

Architect review should confirm.

## OQ-25-IMP-07: Stage 16 chat-path boundary regression test

The Stage 16 chat-path prompt-span boundary invariant
is preserved but the slot lifecycle now goes through
`tx_restore` + `tx_apply_restore`. There is no
Stage 16-specific regression test for this transition.

Question: should Stage 25 add a TP-16 regression test,
or rely on the Stage 24 chat S02 hybrid near-prefix
`cache_n=0` count from the rerun?

Proposed resolution: rely on the Stage 24 chat rerun
near-prefix `cache_n=0` count. Adding a TP-16 unit test
would require building a controller with a real
`llama_context`, which is out of scope for the focused
test pack.

Architect review should confirm.

## OQ-25-IMP-08: future architecture Part 10 timing

The architecture Part 6 records that a future
`cache-handling-architecture/part-10-atomic-transaction-invariants.md`
file will be added after Stage 25 closes. The new part
file documents I-25-01..03 and updates the Part 2
sequence diagram and the Part 4 narrative.

Question: is the future Part 10 timing acceptable as
post-closure work, or should it be authored during
implementation?

Proposed resolution: post-closure work. The Stage 25
implementation focus is the production code and the test
pack. The architecture update is documentation-only and
can be authored after the implementation review PASS
and Manager gate D25-IMPLEMENT-PLAN-02.

Architect review should confirm.

## Handoff state at end of part 6

8 open implementation questions are recorded for
Architect review. None of the questions block the 12-step
implementation; each has a proposed resolution that the
Architect can confirm, reject, or rework.

If the Architect rejects any question, the
implementation plan must be reworked and re-submitted for
Architect plan review before code work starts.
