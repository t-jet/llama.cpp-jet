# Test plan part 38: Stage 34 reopen idempotent save and Path B

Status: authored; pending QA test-plan review
Date: 2026-07-06
Stage: 34 (reopened)
Owner: QA
Source:
[../cache-handling-test-plan.md](../cache-handling-test-plan.md),
[part-37](./part-37-stage34-real-agentic-transcript-replay.md),
[../.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md](../.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md)

This is a focused addition to the original Stage 34 cycle plan in part-37. It
does not replace part-37 and does not edit it. It covers the C++ regression
tests for D34-REOPEN-06 (idempotent `tx_save`) and D34-REOPEN-07 (Path B
slow-read relocation), the D34-REOPEN-05 reclassification note for TP-34-CC,
and the carry-forward project-root output rule. This is planning only. It does
not run any test, replay, or build.

## Authority

- User directive 2026-07-05:
  [manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md](../.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md)
  (binding decisions D34-REOPEN-05 through D34-REOPEN-08).
- Manager design gate:
  [../cache-handling-phase34-design/part-06-manager-design-gate-20260705.md](../cache-handling-phase34-design/part-06-manager-design-gate-20260705.md)
  (PASS; eight required-action items; required-action 1 widens I-34-01 to any
  residency; required-action 2 asks for T-34-IDEM-03).
- Implementation plan (reopen):
  [../cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md](../cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md)
  (Step 4 names T-34-IDEM-01..03 and T-34-PATHB-01; Step 6 delegates the
  test-plan rows to this gate; Step 7 gives the exact TP-34-CC reclassification
  label).
- Manager implementation gate:
  [../cache-handling-phase34-implementation/part-19-manager-implementation-gate-20260706.md](../cache-handling-phase34-implementation/part-19-manager-implementation-gate-20260706.md)
  (PASS; next owner QA; lists the five rows QA must add plus the
  reclassification note and the F34-PATH-01 carry-forward).
- Implementation re-review PASS:
  [../cache-handling-phase34-implementation/part-18-implementation-re-review-20260705.md](../cache-handling-phase34-implementation/part-18-implementation-re-review-20260705.md)
  (confirms the five tests and the SPLIT pattern).

## Scope

In scope for this part:

- Five C++ regression rows (T-34-IDEM-01, T-34-IDEM-02, T-34-IDEM-03,
  T-34-PATHB-01, T-34-PATHB-02) implemented in `tests/test-cache-controller.cpp`.
- One scope note reclassifying TP-34-CC as EXPECTED-BEHAVIOR per D34-REOPEN-05.
- Carry-forward of the F34-PATH-01 project-root output rule for any reuse of
  the original replay harness referenced in part-37.
- Acceptance criteria for the follow-on test-execution gate.

Out of scope for this part:

- Test execution, live replay, model-backed runs, or builds.
- Editing part-37 (the original-cycle plan remains authoritative for its rows).
- Authoring or modifying production code, test code, scripts, fixtures, the
  manager-input file, `document-index.md`, the stage tracker, or any
  implementation part file.
- Path C, Path D, and Path E (rejected in part-04; see part-37 out-of-scope).

## Production invariants verified

This part covers two production invariants introduced by the reopen cycle:

- I-34-01 (D34-REOPEN-06): a `tx_save` for a prompt token-span and namespace
  that already has an equivalent entry in the cache never creates a duplicate.
  The existing entry's hot counter is bumped via `mark_used` instead. This
  holds regardless of whether the matched entry is hot or cold residency
  (widened per Manager required-action 1).
- I-34-02 (D34-REOPEN-07): `tx_save` follows the SPLIT pattern. The slow
  `llama_state_seq_get_data_ext` reads for target and draft run outside any
  held `cache_state_mutex_` region. A second-pass dedupe after the slow read
  still prevents a duplicate entry when a parallel save admitted the same
  prompt while this save was reading.

Both invariants preserve the Stage 25 transaction invariants
(I-25-01..03, OQ-25-01 SPLIT pattern, reentrancy limit).

## Test rows

The five rows below are C++ regression tests in `tests/test-cache-controller.cpp`.
They run inside `tests/test-cache-controller.exe` and are exercised by
`ctest -R cache`. All test-only hooks are gated behind the
`LLAMA_SERVER_CACHE_TESTS` preprocessor guard.

### T-34-IDEM-01

- Purpose: prove two saves for the same prompt token-span and namespace produce
  exactly one entry and bump the existing entry's hot counter.
- Production invariant verified: I-34-01 (D34-REOPEN-06, hot-residency dedupe).
- Test-only hooks: none beyond the standard
  `LLAMA_SERVER_CACHE_TESTS`-gated cache controller surface.
- Pass signal: after both saves return, the cache has exactly one entry
  (`entries.size() == 1`) and that entry's `use_count` reflects at least two
  reuses.
- Fail signal: the cache admits a second entry, or the saved entry's
  `use_count` does not advance as expected.

### T-34-IDEM-02

- Purpose: prove the first-pass hot dedupe returns before any slow read runs,
  so the second save for an equivalent prompt skips the slow
  `llama_state_seq_get_data_ext` read entirely.
- Production invariant verified: I-34-01 (D34-REOPEN-06) plus the Path B
  first-section fast-dedupe property carried by I-34-02.
- Test-only hooks: the slow-read counter gated by
  `LLAMA_SERVER_CACHE_TESTS` (see implementation plan Step 3).
- Pass signal: the second save's `tx_save` returns true, the cache has exactly
  one entry, and the slow-read counter for the second slot's id reads zero.
- Fail signal: the second slot reaches the slow read, indicating the first-pass
  dedupe did not fire.

### T-34-IDEM-03

- Purpose: prove the cold-residency branch of the idempotent save also avoids a
  duplicate. The matched entry exists but its payload has been demoted so
  `entry_has_payload_for_restore` is false; the save re-materializes the entry
  rather than admitting a parallel duplicate.
- Production invariant verified: I-34-01 widened per Manager required-action 1.
- Test-only hooks: the cold-store demotion and cache inspection helpers gated
  by `LLAMA_SERVER_CACHE_TESTS`.
- Pass signal: after the save, exactly one entry exists for the prompt
  token-span and namespace, and its `use_count` has advanced.
- Fail signal: a duplicate entry is admitted, or `use_count` stays flat
  indicating the re-materialize branch did not invoke `mark_used`.

### T-34-PATHB-01

- Purpose: prove a restore (`tx_restore`) for an unrelated prompt completes
  during the slow-read window of a paused save, and completes before the paused
  save is released.
- Production invariant verified: I-34-02 (D34-REOPEN-07, slow reads no longer
  block unrelated transactions).
- Test-only hooks: `debug_run_save_transaction_for_tests` to drive the save
  through production code, and
  `debug_set_tx_save_slow_read_hook_for_tests` to park the save inside the
  slow-read window. Both gated by `LLAMA_SERVER_CACHE_TESTS`.
- Pass signal: the restore returns while the save is still paused in its
  slow-read hook, and the restore finishes before the save is released.
- Fail signal: the restore cannot run until after the save's slow read and
  second section commit, meaning Path B did not relocate the slow read out of
  the held-lock region.

### T-34-PATHB-02

- Purpose: prove two production `tx_save` calls for the same prompt serialize
  through the SPLIT pattern. Save A parks in the slow-read hook; save B for the
  same prompt then admits the entry while A is parked; once A is released, A's
  second pass dedupes against B's entry instead of admitting a duplicate.
- Production invariant verified: I-34-02 second-pass dedupe (D34-REOPEN-07).
- Test-only hooks: `debug_run_save_transaction_for_tests` to drive both saves
  through production code, `debug_set_tx_save_slow_read_hook_for_tests` to park
  save A, and `debug_get_tx_save_second_pass_dedupes_for_tests` to read the
  second-pass dedupe counter. All gated by `LLAMA_SERVER_CACHE_TESTS`.
- Pass signal: exactly one entry exists after both saves, the second-pass
  dedupe counter is exactly one, and the entry's `use_count` advances by one
  from the deduping save.
- Fail signal: two entries exist (Path B second-pass dedupe missing), or the
  second-pass dedupe counter does not record exactly one dedupe.

## Scope note: TP-34-CC reclassification (D34-REOPEN-05)

This is a scope note, not a new test execution row. TP-34-CC from part-37 is
reclassified as `EXPECTED-BEHAVIOR dispatch-ordering race (Stage 33 precedent)`.

Rationale: the dispatch-ordering behavior TP-34-CC observed is the same shape
Stage 33 already closed on, and the reopen design correction records no cache
code change for this case. The user directive (D34-REOPEN-05) accepts Path A:
the dispatch ordering stays expected behavior while the reopen cycle focuses on
idempotent save (D34-REOPEN-06) and Path B (D34-REOPEN-07). The cache code is
unchanged for this case. Refer to:

- Stage 33 closure report:
  [../.test_reports/test-report-20260630-03-stage33-01-manager-closure.md](../.test_reports/test-report-20260630-03-stage33-01-manager-closure.md)
- Reopen cycle design correction:
  [../cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md](../cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md)

## Output path rule (F34-PATH-01 carry-forward)

This part carries the part-37 output rule forward unchanged. All non-durable
replay artifacts produced while exercising the original Stage 34 replay harness
must be written under the project root at
`_test_output/stage34-<run-name>/`. The durable tree under `._design_docs/`
holds documentation only; no row output belongs there. If any execution session
later reuses the part-37 harness to provide context for the reopen cycle, that
session must still honor this rule.

## Acceptance criteria for the test-execution gate

The test-execution gate that follows this planning gate will re-run the five
rows against the existing test binaries. The implementation re-review already
ran these commands successfully; that prior run is not durable QA evidence. The
test-execution gate re-runs them in a fresh per-session report under
`._design_docs/.test_reports/`.

PASS for that gate requires, against a clean Release build:

- `tests/test-cache-controller.exe` reports all tests pass (the build that
  passed part-18 reported 149 tests, all pass). The five reopen rows must be
  among the passing set, in addition to the original Stage 34 reopen tests.
- `ctest -R cache` reports all selected tests pass, with no failures and no
  skips among the cache suite.
- The per-session report records clean-build evidence, the per-test pass count,
  and the test binary mtime. A stale binary invalidates the run.
- The per-session report cites the new binary output, not the part-18 prior
  output.
- No `LLAMA_SERVER_CACHE_TESTS`-gated hook is reachable in a production build
  that does not define the guard.

BLOCKED applies if a clean build cannot be produced or the test binary cannot
run. FAIL applies if any of the five rows fails or `ctest -R cache` reports a
failure in the cache suite.

## Out of scope

- Path C (optimistic commit before slow read), Path D (driver pre-warm delay),
  and Path E (delay slot recycling until predecessor save commits) remain
  rejected per part-04 and part-37. A full fix for the dispatch-ordering miss
  itself stays out of scope under D34-REOPEN-05.

## Closure link

Closure of Stage 34 requires all gates in D34-REOPEN-08 to pass: design,
implementation-planning, implementation, test-planning, test-execution, and
test-results review. This part advances test-planning for the reopen cycle. It
does not close the stage.

## Next owner and next gate

Next owner: QA test-plan reviewer in a fresh session.
Next gate: test-plan review of this part file.
