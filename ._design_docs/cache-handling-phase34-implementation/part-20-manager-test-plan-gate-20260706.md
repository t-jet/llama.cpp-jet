# Stage 34 Manager test-plan gate: idempotent save and Path B reopen cycle

Status: PASS - advance to test execution
Date: 2026-07-06
Stage: 34 (reopened)
Owner: Manager
Branch: work-branch

## Authority

User directive 2026-07-05 in
`._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md`.
Decisions D34-REOPEN-05 through D34-REOPEN-08 remain binding.

## Inputs reviewed

- Test-plan addition:
  [part 38](../cache-handling-test-plan/part-38-stage34-reopen-idempotent-save-and-path-b.md)
- Independent test-plan review:
  [part 39](../cache-handling-test-plan/part-39-stage34-reopen-test-plan-review-20260706.md)
- Manager implementation gate:
  [part 19](part-19-manager-implementation-gate-20260706.md)
- Implementation re-review:
  [part 18](part-18-implementation-re-review-20260705.md)

## Decision

The test-plan gate PASSES. The independent review returned PASS with 0
BLOCKING and 0 NON-BLOCKING findings. All five rows (T-34-IDEM-01,
T-34-IDEM-02, T-34-IDEM-03, T-34-PATHB-01, T-34-PATHB-02) bind correctly to
the live code (test registration in `tests/test-cache-controller.cpp`, hooks
in `server-cache-hybrid.{h,cpp}` gated by `LLAMA_SERVER_CACHE_TESTS`, tx_save
SPLIT line ranges verified).

- D34-REOPEN-06 coverage: T-34-IDEM-01/02/03 cover hot-residency dedupe, hot
  first-pass dedupe (zero slow reads), and cold-residency re-materialize.
- D34-REOPEN-07 coverage: T-34-PATHB-01 and T-34-PATHB-02 cover production
  tx_save through the slow-read window and second-pass dedupe.
- D34-REOPEN-05 scope note: TP-34-CC reclassification uses the exact label
  `EXPECTED-BEHAVIOR dispatch-ordering race (Stage 33 precedent)`.
- F34-PATH-01 carry-forward: project-root `_test_output/stage34-<run-name>/`
  rule reaffirmed for any reuse of the original replay harness.
- Plan is generic: no run dates, no output paths, no model paths in the body.

## Gate checklist

| Check | Result |
| --- | --- |
| Five rows bind to live code (tests + hooks + SPLIT line ranges) | PASS |
| Verified invariants named per row (I-34-01 / I-34-02) | PASS |
| D34-REOPEN-05 reclassification scope note present and exact | PASS |
| F34-PATH-01 project-root output rule carried forward | PASS |
| Plan generic, no run-specific content in body | PASS |
| ASCII-only status labels, no unicode icons | PASS |
| Acceptance criteria name PASS signal without claiming prior session run as test-execution evidence | PASS |
| Independent review PASS with 0 BLOCKING | PASS |

## Next owner and next gate

Next owner: QA (fresh session).
Next gate: Test execution for the reopen cycle.

QA must:

1. Perform a clean Release CUDA configure and a clean `test-cache-controller`
   build before any test run.
2. Run `.\build-cuda\bin\Release\test-cache-controller.exe` and capture the
   output, including the five reopen-cycle rows and the total count (149
   tests expected).
3. Run `ctest --test-dir build-cuda -C Release -R cache --output-on-failure`
   and capture the result.
4. Write a fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
   following the test-plan acceptance criteria. Use today's date. Pick the next
   available NN sequence for today.
5. Record per-row verdicts for the five rows and the reclassification scope
   note (the scope note is `N/A-not-an-execution-row`).
6. Run `git diff --check` and record the result.
7. Do NOT run the broader replay harness from part-37; the reopen cycle scope
   is the five C++ regression rows only.

Code remains UNCOMMITTED per AGENTS.md; user approval required for commit.
