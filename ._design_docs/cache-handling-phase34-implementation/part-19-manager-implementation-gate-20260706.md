# Stage 34 Manager implementation gate: idempotent save and Path B

Status: PASS - advance to test-planning for the reopen cycle
Date: 2026-07-06
Stage: 34 (reopened)
Owner: Manager
Branch: work-branch

## Authority

User directive 2026-07-05 recorded in
`._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md`.
Decisions D34-REOPEN-05 through D34-REOPEN-08 remain binding. D34-REOPEN-08
requires all gates (design, implementation-planning, implementation,
test-planning, test-execution, test-results review) pass before closure.

## Inputs reviewed

- Implementation evidence:
  [part 15](part-15-implementation-evidence-20260705.md)
- Implementation review REWORK:
  [part 16](part-16-implementation-review-20260705.md)
- Rework evidence:
  [part 17](part-17-implementation-rework-evidence-20260705.md)
- Implementation re-review PASS:
  [part 18](part-18-implementation-re-review-20260705.md)
- Implementation plan gate:
  [part 14](part-14-manager-implementation-plan-gate-20260705.md)
- Design correction:
  [../cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md](../cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md)
- Manager design gate:
  [../cache-handling-phase34-design/part-06-manager-design-gate-20260705.md](../cache-handling-phase34-design/part-06-manager-design-gate-20260705.md)

## Decision

The implementation gate PASSES. The re-review returned PASS with no blocking
findings. The part 16 REWORK findings on T-34-PATHB-01 and T-34-PATHB-02 are
fixed in part 17 and verified in part 18.

- D34-REOPEN-06 (idempotent tx_save with hot counter bump) is implemented via
  the existing `find_equivalent_entry` dedupe and `mark_used` calls in both the
  hot and cold branches of tx_save. Tests T-34-IDEM-01/02/03 cover hot, hot
  first-pass dedupe, and cold re-materialize. Parts 17 and 18 confirm the
  production code at
  `tools/server/server-cache-hybrid.cpp:4848-4857` (first-pass hot refresh) and
  `4920-4955` (second-pass hot dedupe and cold re-materialize) is unchanged in
  behavior and only gained invariant comments.
- D34-REOPEN-07 (Path B slow-read relocation, SPLIT pattern) is implemented.
  tx_save now splits into a first critical section
  (`server-cache-hybrid.cpp:4772-4858`), an unlocked slow-read section
  (`4863-4912`), and a second critical section with a fresh
  `reentrancy_guard` (`4914-4918`). Tests T-34-PATHB-01 and T-34-PATHB-02
  exercise production tx_save through `debug_run_save_transaction_for_tests`
  and assert the slow-read window and second-pass dedupe behavior.

The implementation re-review confirms the Stage 25 invariants hold: no iterator
captured before lock release survives to the second section, the second-pass
re-lookup is iterator-invalidation-safe, and budget recheck remains in the
existing commit helpers (`evict_until_within_budget` at cpp L3094 and L3195).

## Gate checklist

| Check | Result |
| --- | --- |
| Approved design baseline cited | PASS |
| Implementation matches approved plan (D34-REOPEN-06/07) | PASS |
| Test-only hooks guarded by LLAMA_SERVER_CACHE_TESTS | PASS |
| Production behavior unchanged outside new invariant comments and Path B restructure | PASS |
| Stage 25 transaction invariants preserved (OQ-25-01 SPLIT, reentrancy limit) | PASS |
| C++ regression tests cover all four rows (IDEM-01/02/03, PATHB-01, PATHB-02) | PASS |
| Clean build and full test execution (149 tests) | PASS |
| `git diff --check` clean | PASS |
| Code and implementation docs describe the same state | PASS |
| Implementation review PASS with no blocking findings | PASS |

## Carry-forward notes

- The five new tests (T-34-IDEM-01/02/03, T-34-PATHB-01/02) plus the five
  existing Stage 34 reopen tests bring the test count from 144 to 149.
- D34-REOPEN-05 (TP-34-CC reclassification to EXPECTED-BEHAVIOR) is a QA
  test-plan note, not a code change. It carries into the test-planning gate.
- The original Stage 34 design's broader replay work (replay parser, renderer,
  analyzer, runner) was implemented and reviewed in the first closure cycle
  (parts 03-09). The reopen cycle scope is only D34-REOPEN-06/07 plus the QA
  reclassification note.

## Next owner and next gate

Next owner: QA (fresh session).
Next gate: Test-planning for the reopen cycle.

QA must:

1. Append rows for T-34-IDEM-01, T-34-IDEM-02, T-34-IDEM-03, T-34-PATHB-01, and
   T-34-PATHB-02 to the Stage 34 test plan (part-37 or a new part if part-37 is
   treated as the original-cycle plan).
2. Record the D34-REOPEN-05 reclassification label for TP-34-CC as
   `EXPECTED-BEHAVIOR dispatch-ordering race (Stage 33 precedent)` with a scope
   note pointing at the Stage 33 closure report and the part-04 design
   correction.
3. Confirm or extend the F34-PATH-01 project-root output rule still applies for
   any reuse of the original replay harness.
4. Keep the test plan generic (no specific run dates or output paths in the
   plan body).

Implementation must not commit or push. Code changes remain UNCOMMITTED per
AGENTS.md; user approval required for commit.
