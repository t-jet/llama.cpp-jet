# Stage 22 Architect implementation review gate 01

VERDICT: REWORK
Date: 2026-06-19
Reviewer: Architect
Scope: Stage 22 implementation in `tools/server/server-cache-hybrid.cpp`,
`tests/test-cache-controller.cpp`, and the implementation log, checked against
the accepted Stage 22 design and implementation plan. Production code and tests
were not edited in this review.

## Checks

| Area | Result | Notes |
| --- | --- | --- |
| `demote_payload` validation order | PASS | The already-demoting branch at `server-cache-hybrid.cpp:374` now runs before the generic non-hot rejection at line 382 and records `in_progress`. |
| Completion idempotence | PASS | Success from `demoting` increments cold bytes/count once; duplicate success from `cold` records `duplicate_success` without incrementing cold bytes/count again. Stale success after `evicted` does not recreate ownership. |
| Target/draft ownership | PASS | TP-22-UT7 covers target/draft completion plus duplicate success and checks pair state, target bytes, draft bytes, cold counter stability, and owner-view accounting. |
| Owner-view sync and F-21-RERUN-01 | PASS | Completion success, failure-revert, and failure-evict paths call owner-view sync. Demoting payloads remain counted by `refresh_entry_payload_accounting` until hot bytes are released. |
| F-21-EXEC-01 | PASS | TP-21-UT1..UT3 remain registered and passed in the focused run. No prompt-only save path regression was found in the reviewed diff. |
| Public surface stability | PASS | The Stage 22 diff changes private controller logic and test code only. No public CLI flag, endpoint schema, runner, fixture, CMake file, or public metric family name changed. |
| Implementation evidence | REWORK | Evidence is mostly complete, but it overstates TP-22-UT6 as a focused Stage 22 test even though the registered wrapper only asserts `true`. |

## Findings

| ID | Severity | Finding | Required correction |
| --- | --- | --- | --- |
| F-22-IR-01 | BLOCKING | `tests/test-cache-controller.cpp:3379` defines `test_stage22_stage21_invariant_pack`, but the body only prints and `assert(true)`. The six TP-21 invariant tests are real and are registered separately at lines 3762-3768, so the invariant coverage exists, but the Stage 22 implementation evidence claims eight focused tests and names this wrapper as one of them. That makes TP-22-UT6 not meaningful as a registered Stage 22 test and makes the evidence wording incomplete for the accepted plan's TP-22-UT1..UT8 checklist. | Either make TP-22-UT6 actively verify the Stage 21 invariant registration/execution contract, or remove the placeholder from the Stage 22 focused-test count and update the implementation log to state that TP-22-UT6 is satisfied by the directly registered TP-21-UT1..UT6 PASS lines. Rerun `test-cache-controller.exe` and `git diff --check` after the correction. |

## Verification

- `cmake --build build-cov --config Release --target test-cache-controller -j 4`: exit 0.
- `.\build-cov\bin\Release\test-cache-controller.exe`: exit 0, 105 tests passed.
- Visible TP-21 PASS lines: all six invariant tests passed.
- Visible TP-22 PASS lines: all eight registered Stage 22 functions passed, but TP-22-UT6 is the placeholder covered by F-22-IR-01.
- `git diff --check -- tools/server/server-cache-hybrid.cpp tests/test-cache-controller.cpp ._design_docs/cache-handling-phase22-implementation.md ._design_docs/document-index.md ._design_docs/cache-handling-stage-tracker.md`: exit 0 before this review doc edit.

## Handoff

Next owner: Developer for F-22-IR-01 correction.

Gate state: REWORK. Architect re-review required after the correction evidence
is recorded. QA must not start the Stage 21 HV rerun from Stage 22 until this
implementation review passes.
