# Stage 34 implementation rework evidence: Path B test fidelity

Status: REWORK EVIDENCE READY
Date: 2026-07-05
Stage: 34 (reopened)
Owner: Developer
Scope: Fix implementation review findings T-34-PATHB-01 and T-34-PATHB-02 only.

## Inputs

- Implementation review:
  `cache-handling-phase34-implementation/part-16-implementation-review-20260705.md`
- Prior implementation evidence:
  `cache-handling-phase34-implementation/part-15-implementation-evidence-20260705.md`
- Manager implementation-plan gate:
  `cache-handling-phase34-implementation/part-14-manager-implementation-plan-gate-20260705.md`
- Reopen implementation plan:
  `cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md`

## Changed files

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase34-implementation.md`
- `._design_docs/cache-handling-phase34-implementation/part-17-implementation-rework-evidence-20260705.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`

## Fix summary

Finding 1, T-34-PATHB-01:

- Added `LLAMA_SERVER_CACHE_TESTS`-guarded `tx_save` hooks around the actual
  slow-read section after the first cache mutex unlock and before the target or
  draft state bytes are read.
- Replaced the synthetic sleep test with a real `tx_save` call. The save thread
  pauses in the slow-read hook after first unlock. A restore thread runs
  `tx_restore` while that hook is still holding the save in the read window.
- The test asserts the restore plan is found, the restore returns before the
  save is released, the save has not completed early, and the slow-read hook
  was reached.

Finding 2, T-34-PATHB-02:

- Added a test-only second-pass dedupe counter that increments only in the
  production `tx_save` second-pass hot dedupe branch after the slow-read
  section.
- Replaced the sequential helper commits with two production `tx_save` calls
  for the same prompt. Save A pauses in the slow-read hook after the first
  lookup. Save B runs through `tx_save`, admits one entry, and exits. Save A is
  then released and dedupes on its second-pass `find_equivalent_entry`.
- The test asserts one entry, exactly one second-pass dedupe, and one
  `use_count` increment from the deduping save.

## Test-only hook scope

All new hooks are guarded by `LLAMA_SERVER_CACHE_TESTS` or are debug methods
already declared only for test builds. Production behavior is unchanged.

The hooks added for this rework:

- `debug_set_tx_save_forced_target_bytes_for_tests`
- `debug_set_tx_save_slow_read_hook_for_tests`
- `debug_get_tx_save_second_pass_dedupes_for_tests`
- `debug_reset_tx_save_second_pass_dedupes_for_tests`

The forced target-byte hook exists because `test-cache-controller` builds a
cache controller without a real `llama_context`. It makes the controller-only
test enter the same `tx_save` split path and commit branch without model setup.

The existing slow-read counter now uses a test mutex, so concurrent Path B
tests do not read or write the map without synchronization.

## Evidence

Command:

```text
cmake --build build-cuda --target test-cache-controller --config Release
```

Result: exit 0. Built
`build-cuda/bin/Release/test-cache-controller.exe`. MSVC emitted the existing
three `%zu` warnings at test lines 5447, 5460, and 5568; this rework did not
add those warnings.

Command:

```text
.\build-cuda\bin\Release\test-cache-controller.exe
```

Result: exit 0. Output included both reworked rows:

```text
test-cache-controller: Stage 34 Path B restore runs during save read window...
  PASSED
test-cache-controller: Stage 34 Path B second-pass dedupe same prompt...
  PASSED
All tests passed successfully!
Total: 149 tests
```

Command:

```text
ctest --test-dir build-cuda -C Release -R cache --output-on-failure
```

Result: exit 0. `1/1 Test #28: test-cache-controller` passed in 0.25 seconds.

Command:

```text
git diff --check
```

Result: exit 0.

## Remaining items

- No model-backed replay was run in this focused implementation rework.
- The rework is ready for Architect implementation re-review.
- QA execution gate should stay closed until implementation re-review passes.
