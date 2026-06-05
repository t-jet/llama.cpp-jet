# Phase 5 implementation: review-fix evidence

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Scope

Review-fix date: May 27, 2026

This part records the fix for the blocker in [Part 7](part-07-implementation-review.md): production rollback was not exact when a pre-restore target or draft side had no serialized byte image.

## Starting state

The worktree already had uncommitted Stage 5 code, documentation, and memory edits before this review-fix pass. The Phase 5 design and implementation documents were untracked at task start. This part records only the new review-fix changes and evidence from this pass.

## Fix

Changed files:

- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase5-implementation.md`
- `._design_docs/cache-handling-phase5-implementation/part-08-review-fix-evidence.md`
- `._design_docs/document-index.md`

Production restore now treats an empty pre-restore side as a real state. For each target or draft side:

- If `llama_state_seq_get_size_ext(...)` returns bytes, rollback restores those bytes and snapshot capture fails closed if `llama_state_seq_get_data_ext(...)` returns a different size.
- If the pre-restore side has no serialized bytes, rollback clears the sequence with `llama_memory_seq_rm(..., seq_id, -1, -1)`.
- The empty-side clear path is checked before any payload bytes are applied. If the API cannot clear the sequence, restore returns false, increments restore failure and fallback counters, and leaves the live state untouched.
- Draft failure after target apply calls the same rollback lambda, so target bytes are removed when the target side was empty before restore.
- Failed restore paths still return false before hit accounting, usage refresh, or recency refresh.

The same correction was applied to both production restore entry points:

- `hybrid_cache_controller::try_restore_from_cache`
- `hybrid_cache_controller::load_slot`

## Regression coverage

`tests/test-cache-controller.cpp` now includes an empty-preimage draft-failure check in the Stage 5 transaction failure test. It models the blocker directly: target bytes are applied, draft apply fails, the pre-restore target and draft images are empty, rollback clears both live sides, no rollback failure is counted, and no hit is recorded.

This is failure-injection evidence for the production contract. The live production code uses `llama_memory_seq_rm` for the same empty-side rollback behavior and preflights unsupported clear paths before mutation.

No full model-backed live-slot probe was added in this pass. The focused build available in this workspace does not provide a small target-plus-draft model fixture. The production code path is covered by build evidence, and the failure-injection regression covers the empty-preimage branch that caused the blocker.

## Evidence

Commands run:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
cmake --build build --config Release --target llama-server -j 4
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build/bin/Release/llama-server.exe); $env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'; pytest tools/server/tests/unit/test_cache_modes.py
```

Observed results:

- `test-cache-controller` build: passed.
- `ctest -R test-cache-controller`: passed, 1/1 test, 0.04 seconds.
- `llama-server` build: passed.
- `pytest tools/server/tests/unit/test_cache_modes.py`: 2 passed, 1 xfailed in 4.84 seconds. The xfail is the existing hybrid repeated-restore exposure limitation in the test file.

## QA coverage follow-up

Follow-up date: May 28, 2026

QA report [test-report-20260528-02.md](../.test_reports/test-report-20260528-02.md) found no product bug, but it blocked Stage 5 on missing focused evidence for malformed descriptors, reverse pair-state mismatch, cold residency, rollback failure, and unsupported empty-side clear.

Changed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase5-implementation/part-08-review-fix-evidence.md`

New focused coverage:

- `test_hybrid_payload_descriptor_fault_injection` injects unsupported descriptor version, unsupported kind, zero target size, target size mismatch, missing target bytes, bad store reference, missing hot record, owner mismatch, cold residency, invalid draft presence, draft size mismatch, draft checksum mismatch, and the reverse runtime-with-draft rejecting target-only descriptor case.
- `test_hybrid_restore_transaction_failures` now also covers rollback failure and unsupported empty-side clear preflight. Both paths record restore failure, fallback, rollback failure, and no hit.

Commands run:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
cmake --build build --config Release --target llama-server -j 4
```

Observed results:

- `test-cache-controller` build: passed.
- `ctest -R test-cache-controller`: passed, 1/1 test, 0.15 seconds.
- `llama-server` build: passed.

Rows with new focused evidence:

- H41: malformed descriptor validation branches.
- H42 and N20: both pair-state mismatch directions.
- H44: validation failure, target apply failure, draft apply failure, commit failure, and rollback failure.
- H46 and N23: unsupported empty-side clear preflight.
- H48 and N21: evicted and cold residency rejection.
- N16: unsupported descriptor version and kind.
- N17: bad store reference, missing hot record, and owner mismatch.
- N18: target size zero, size mismatch, checksum mismatch, and missing target bytes.
- N19: invalid draft presence for target-only and target-plus-draft descriptors.

H43 still needs an external draft-model fixture for public model-backed target-plus-draft restore evidence.

## Review finding status

Finding 1 is fixed from the developer side.

The production rollback path now has exact behavior for the empty pre-restore case that Part 7 called out:

- Empty target before restore rolls back by clearing target sequence state.
- Empty draft before restore rolls back by clearing draft sequence state.
- Unsupported empty-side rollback is detected before applying target payload bytes.
- A failed draft apply after target success cannot leave a half-restored target/draft pair through this path.

## Remaining risk

No remaining developer blocker is known.

Architect re-review should verify that `llama_memory_seq_rm(..., seq_id, -1, -1)` is an acceptable exact empty-side rollback primitive for the supported llama memory backends.
