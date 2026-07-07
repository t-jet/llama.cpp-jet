# Stage 34 reopened implementation evidence: idempotent save and Path B

Status: IMPLEMENTATION EVIDENCE READY
Date: 2026-07-05
Stage: 34 (reopened)
Owner: Developer
Scope: D34-REOPEN-06 and D34-REOPEN-07

## Inputs

- Implementation-plan gate:
  `cache-handling-phase34-implementation/part-14-manager-implementation-plan-gate-20260705.md`
- Plan review:
  `cache-handling-phase34-implementation/part-13-implementation-plan-review-20260705.md`
- Implementation plan:
  `cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md`
- Design correction:
  `cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md`
- Design review:
  `cache-handling-phase34-design/part-05-design-review-20260705.md`
- Manager design gate:
  `cache-handling-phase34-design/part-06-manager-design-gate-20260705.md`

## Changed files

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase34-implementation.md`
- `._design_docs/cache-handling-phase34-implementation/part-15-implementation-evidence-20260705.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`

## Implementation summary

D34-REOPEN-06:

- Added tight I-34-01 comments at the hot dedupe branch and cold
  re-materialize branch.
- No new production dedupe behavior was added. Existing
  `find_equivalent_entry` routing remains the behavior source.
- Added test-only counters/hooks so regression tests can assert hot dedupe
  avoids slow reads and second-pass commit logic does not admit duplicates.

D34-REOPEN-07:

- Restructured `tx_save` into SPLIT ordering.
- First critical section: validates input, computes fast state sizes, checks
  budget, snapshots slot-owned inputs, and performs first-pass hot dedupe.
- Slow section: runs `llama_state_seq_get_data_ext` outside
  `cache_state_mutex_`. The existing `std::bad_alloc` catch paths remain
  outside the lock and return false without cache mutation.
- Second critical section: constructs a fresh `stage25_tx::reentrancy_guard`,
  reruns `find_equivalent_entry`, then hot-dedupes, cold re-materializes, or
  admits a new entry.
- No iterator or pointer captured before the first lock release is carried into
  the second critical section.
- Budget recheck remains inside `materialize_entry_payload` and
  `admit_entry_with_payload` through their existing `evict_until_within_budget`
  calls.

## Code anchors

Live post-implementation anchors:

- `tx_save` starts at `tools/server/server-cache-hybrid.cpp:4754`.
- First-pass `find_equivalent_entry` is at `server-cache-hybrid.cpp:4836`.
- Slow target read is at `server-cache-hybrid.cpp:4862`.
- Slow draft read is at `server-cache-hybrid.cpp:4880`.
- Second-pass `find_equivalent_entry` is at `server-cache-hybrid.cpp:4893`.
- Cold `materialize_entry_payload` branch is at
  `server-cache-hybrid.cpp:4907`.
- Admit parent lookup `select_mismatch_parent_for_admission` is at
  `server-cache-hybrid.cpp:4927`.
- New-entry `admit_entry_with_payload` branch is at
  `server-cache-hybrid.cpp:4928`.
- I-34-01/I-34-02 header comments are at
  `tools/server/server-cache-hybrid.h:711-712`, near
  `reentrancy_depth_limit_` at `server-cache-hybrid.h:714`.

Plan-review stale-line cleanup carried forward:

- The pre-split cold branch cites from part-13 are corrected as
  L4878/L4879 for sync/ref and L4924 for admit return.
- The pre-split admit parent lookup cite `select_mismatch_parent_for_admission`
  at L4885 is recorded here as requested; the live post-split line is L4927.

## Regression coverage

- T-34-IDEM-01:
  `test_stage34_idempotent_save_hot_dedupe_use_count`.
  Saves equivalent prompt twice through the save-commit path; asserts one entry
  and one `use_count` increment on the second save.
- T-34-IDEM-02:
  `test_stage34_idempotent_save_skips_slow_read_on_hot_hit`.
  Runs real `tx_save` against a hot equivalent entry; asserts one entry,
  `use_count` increment, and zero slow-read counter for the slot.
- T-34-IDEM-03:
  `test_stage34_idempotent_save_cold_rematerializes_in_place`.
  Evicts the existing hot payload, commits an equivalent save, and asserts the
  entry re-materializes in place without duplicate admission.
- T-34-PATHB-01:
  `test_stage34_pathb_restore_runs_during_save_read_window`.
  Opens a simulated save slow-read window with no cache lock held and verifies a
  restore transaction completes inside the window.
- T-34-PATHB-02:
  `test_stage34_pathb_second_pass_dedupe_same_prompt`.
  Simulates two same-prompt saves reaching the second pass; asserts the second
  dedupes and increments `use_count` instead of admitting a duplicate.

All new checks use `require_or_abort` / explicit abort-style checks rather than
`assert`.

## Evidence

Command:

```text
cmake --build build-x64-windows-msvc-release --target test-cache-controller --config Release
```

Result: exit 1. Blocker: the existing build directory has `CMakeCache.txt` but
no `build.ninja`, so CMake cannot load the generator file.

Command:

```text
cmake --build build-cuda --target test-cache-controller --config Release
```

Result: exit 0. Built
`build-cuda/bin/Release/test-cache-controller.exe`. MSVC emitted three existing
`fprintf` `%zu` warnings at test lines 5447, 5460, and 5568; none are from the
new Stage 34 reopened tests.

Command:

```text
.\build-cuda\bin\Release\test-cache-controller.exe
```

Result: exit 0. Output ended with:

```text
All tests passed successfully!
Total: 149 tests (... + 5 Stage 34 reopened regressions)
```

Command:

```text
ctest --test-dir build-cuda -C Release -R cache --output-on-failure
```

Result: exit 0. `1/1 Test #28: test-cache-controller` passed in 0.33 seconds.

## Unresolved items

- No live model-backed replay was run in this implementation gate.
- The requested focused x64-windows-msvc-release build path is not currently a
  usable generated build tree. The existing CUDA Release build was used for
  compile and test evidence.
- Full QA gate, test-plan update, and test-results review remain next steps.
