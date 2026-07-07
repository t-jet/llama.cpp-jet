# Stage 34 reopened implementation review: D34-REOPEN-06/07

Status: REWORK
Date: 2026-07-05
Stage: 34 (reopened)
Owner: Architect
Scope: Fresh implementation review of D34-REOPEN-06 and D34-REOPEN-07.

## Inputs reviewed

- `cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md`
- `cache-handling-phase34-implementation/part-13-implementation-plan-review-20260705.md`
- `cache-handling-phase34-implementation/part-14-manager-implementation-plan-gate-20260705.md`
- `cache-handling-phase34-implementation/part-15-implementation-evidence-20260705.md`
- `cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md`
- `cache-handling-phase34-design/part-05-design-review-20260705.md`
- `cache-handling-phase34-design/part-06-manager-design-gate-20260705.md`

Code and docs reviewed:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tests/test-cache-controller.cpp`
- `cache-handling-phase34-implementation.md`
- `document-index.md`
- `cache-handling-stage-tracker.md`
- `part-15-implementation-evidence-20260705.md`

## Verdict

REWORK. The production `tx_save` restructure mostly matches the approved Path B
shape, but the new tests do not prove two required branches:

- T-34-PATHB-01 does not run production `tx_save`; it uses a synthetic thread
  that opens a sleep window after briefly acquiring and releasing the cache
  mutex.
- T-34-PATHB-02 does not exercise the production second-pass dedupe after a
  slow-read window; it calls `debug_stage34_commit_saved_payload_for_tests`
  twice, sequentially, under one helper-owned critical section per call.

These gaps leave I-34-02's implementation evidence weaker than the approved
plan and Manager gate require. Passing build and test execution do not close
branch coverage that the tests never reach.

## Code conformance checks

PASS: `tx_save` now uses SPLIT ordering in
`tools/server/server-cache-hybrid.cpp:4769-4928`.

- First lock: validates token/task state, computes target/draft sizes and
  budget, snapshots slot-owned inputs, clones prompt tokens, snapshots
  checkpoints, and performs first-pass `find_equivalent_entry` at L4836.
- Slow section: target read at L4862 and draft read at L4880 run outside
  `cache_state_mutex_`.
- Second lock: a fresh `stage25_tx::reentrancy_guard` is constructed at L4888;
  second-pass `find_equivalent_entry` runs at L4893; hot dedupe, cold
  re-materialize, or new admission follows.
- No iterator or pointer from the first lock is used after relock. The first
  `existing` iterator is scoped to the first critical section; the second
  iterator is re-derived at L4893.

PASS: D34-REOPEN-06 stays within the existing idempotent-save behavior.

- Hot equivalent entry path refreshes via `refresh_existing_entry` at L4840 and
  returns without slow read.
- Cold equivalent entry path re-materializes in place via
  `materialize_entry_payload` at L4907.
- `refresh_existing_entry` calls `mark_used(next_use_sequence())` at L3001.
  `materialize_entry_payload` calls `mark_used(next_use_sequence())` at L3088.
- Comments were added at the hot and cold paths and in the header. No new
  production dedupe policy was introduced.

PASS: slow-read allocation and size-mismatch failures return false before cache
mutation.

- Target `std::bad_alloc` catch returns false at L4854-L4856.
- Target size mismatch returns false at L4863-L4865.
- Draft `std::bad_alloc` catch returns false at L4872-L4874.
- Draft size mismatch returns false at L4881-L4883.
- These paths happen before the second critical section and before
  `materialize_entry_payload` or `admit_entry_with_payload`.

PASS: budget recheck remains delegated to the existing helpers.

- `materialize_entry_payload` calls `evict_until_within_budget` at L3094.
- `admit_entry_with_payload` calls `evict_until_within_budget` at L3195.

PASS: test registration and total count are internally consistent.

- T-34-IDEM-01/02/03 and T-34-PATHB-01/02 are called by `main` at
  `tests/test-cache-controller.cpp:5801-5805`.
- Final output string was updated to `Total: 149 tests` at L5927.
- Direct test execution printed that same total.

## Findings

1. BLOCKING: T-34-PATHB-01 does not exercise production `tx_save` slow-read
   relocation.

   The approved row is meant to prove that a restore can run while a real save
   is in the `llama_state_seq_get_data_ext` window outside `cache_state_mutex_`.
   The implemented test at `tests/test-cache-controller.cpp:5681-5722` creates
   `save_reader`, briefly locks `debug_get_cache_state_mutex_for_tests()`, then
   sleeps. No call enters `hybrid_cache_controller::tx_save`, no slow-read hook
   is reached, and no target/draft read window is observed. This proves only
   that an unrelated synthetic sleep outside the mutex does not block restore.

   Required correction: add a test hook that lets production `tx_save` pause or
   signal around the actual L4862/L4880 slow-read section, then run restore
   during that window and assert it completes before the save window closes.

2. BLOCKING: T-34-PATHB-02 does not exercise production second-pass dedupe.

   The approved row requires two same-prompt saves where one save commits while
   the other is between the first lookup and the second lookup, so the second
   save dedupes at `server-cache-hybrid.cpp:4893-4900`. The implemented test at
   `tests/test-cache-controller.cpp:5726-5742` calls
   `debug_stage34_commit_saved_payload_for_tests` twice in sequence. That helper
   mirrors save-commit logic under one lock and never executes the production
   first-lock, slow-read-outside-lock, second-lock path.

   Required correction: use production `tx_save` with a deterministic slow-read
   window, start two same-prompt saves, allow one to admit, then release the
   other into the second lock. Assert one entry and one `use_count` bump through
   the real L4893-L4900 second-pass branch.

3. NON-BLOCKING: T-34-IDEM-01 and T-34-IDEM-03 use a helper path, not production
   `tx_save`.

   The helper `debug_stage34_commit_saved_payload_for_tests` at
   `server-cache-hybrid.cpp:5399-5458` mirrors the commit branches and is useful
   for deterministic fixture setup, but it is not the runtime save entry point.
   T-34-IDEM-02 does call `tx_save` for the hot first-pass dedupe path, and the
   production code review confirms the cold re-materialize path. Strengthen
   T-34-IDEM-03 if the rework hook can cover cold second-pass behavior cheaply.

4. NON-BLOCKING: the test-only slow-read counter is mutated outside the cache
   mutex.

   `debug_tx_save_slow_reads_by_slot_` is an `std::unordered_map` and increments
   at L4860 and L4878, outside `cache_state_mutex_`. The current direct test
   uses it from a single `tx_save`, so this is not a production defect. If new
   concurrent Path B tests read this counter from another thread, protect it
   with a separate test mutex, use atomics, or avoid shared-map access during
   the concurrent window.

## Evidence and command results

- `git diff --check -- <requested touched paths>`: exit 0.
- `cmake --build build-cuda --target test-cache-controller --config Release`:
  exit 0.
- `.\build-cuda\bin\Release\test-cache-controller.exe`: exit 0. Output ended
  with `All tests passed successfully!` and `Total: 149 tests`.
- `ctest --test-dir build-cuda -C Release -R cache --output-on-failure`: exit
  0. `1/1 Test #28: test-cache-controller` passed in 0.34 seconds.

The Developer evidence in part 15 is plausible for the CUDA Release build and
test path. The x64-windows-msvc-release build-tree failure is also plausible:
the report says that tree had `CMakeCache.txt` but no `build.ninja`. This
review reran the cheap CUDA Release build and tests instead.

## Handoff

State: REWORK.

Next owner: Developer for focused test rework. After rework evidence is added,
return to Architect for implementation re-review. QA test-plan update or test
execution should not open until the implementation review passes.
