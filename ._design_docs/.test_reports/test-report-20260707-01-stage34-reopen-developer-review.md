# Stage 34 reopen developer review: test results

Status: PASS
Date: 2026-07-07
Stage: 34 (reopened)
Owner: Developer
Branch: work-branch
Gate: test-results review

This is a REVIEW-ONLY gate. It produced this one report and no other artifact.
It did not rebuild, rerun tests, run ctest, edit production code, edit test
code, edit any test plan or implementation part file, edit document-index.md,
edit the stage tracker, or commit or push.

## Skill-load confirmation

Loaded in order before any other task action, then AGENTS.md and the humanizer
skill:

- `.agents/skills/self-improvement/SKILL.md`
- `.agents/skills/self-improvement/assets/developer.md` (every matching
  Condition/Action applied)
- `AGENTS.md`
- `.agents/skills/developer/SKILL.md`
- `.agents/skills/humanizer/SKILL.md` (applied to prose; ASCII status labels
  preserved unchanged)

## Constraints honored

- REVIEW-ONLY; no rebuild, no rerun, no ctest, no replay harness.
- No edits to production code, test code, scripts, manager-input files, the
  stage tracker, document-index.md, the QA test report, or any
  implementation / test-plan part file.
- No commit, no push.
- Scope held to D34-REOPEN-06 / D34-REOPEN-07 plus the TP-34-CC scope note.
  The original Stage 34 replay harness (part-37) is out of scope; that work
  closed in part-09 and is not under review here.

## Inputs reviewed

- `._design_docs/.test_reports/test-report-20260707-01-stage34-reopen.md`
  (QA report under review; primary target)
- `._design_docs/cache-handling-test-plan/part-38-stage34-reopen-idempotent-save-and-path-b.md`
  (test plan with row definitions, invariants, PASS signals, acceptance)
- `._design_docs/cache-handling-test-plan/part-39-stage34-reopen-test-plan-review-20260706.md`
  (independent test-plan review PASS)
- `._design_docs/cache-handling-phase34-implementation/part-18-implementation-re-review-20260705.md`
  (Architect implementation re-review PASS)
- `._design_docs/cache-handling-phase34-implementation/part-20-manager-test-plan-gate-20260706.md`
  (Manager test-plan gate PASS, opens test-execution)
- `._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md`
  (user directive with D34-REOPEN-05..08)

## Per-row classification table

| Row | Invariant | QA verdict | Reviewer classification | Evidence cited |
| --- | --- | --- | --- | --- |
| T-34-IDEM-01 | I-34-01 (D34-REOPEN-06 hot-residency dedupe) | PASS | PASS | `_test_output/stage34-reopen-test-stdout.txt` Test-Path True (21178 bytes); label at line 114, `PASSED` at line 115 |
| T-34-IDEM-02 | I-34-01 + I-34-02 first-section fast dedupe | PASS | PASS | `_test_output/stage34-reopen-test-stdout.txt` Test-Path True (21178 bytes); label at line 116, `PASSED` at line 117 |
| T-34-IDEM-03 | I-34-01 widened per Manager required-action 1 | PASS | PASS | `_test_output/stage34-reopen-test-stdout.txt` Test-Path True (21178 bytes); label at line 118, `PASSED` at line 119 |
| T-34-PATHB-01 | I-34-02 (D34-REOPEN-07 slow-read relocation) | PASS | PASS | `_test_output/stage34-reopen-test-stdout.txt` Test-Path True (21178 bytes); label at line 120, `PASSED` at line 121 |
| T-34-PATHB-02 | I-34-02 second-pass dedupe (D34-REOPEN-07) | PASS | PASS | `_test_output/stage34-reopen-test-stdout.txt` Test-Path True (21178 bytes); label at line 122, `PASSED` at line 123 |
| TP-34-CC | n/a (scope note, D34-REOPEN-05) | N/A-not-an-execution-row | N/A-not-an-execution-row (EXPECTED-BEHAVIOR dispatch-ordering race per Stage 33 precedent; reclassification only, no execution row, no cache code change) | part-38 scope note (Section: TP-34-CC reclassification); Stage 33 closure report `test-report-20260630-03-stage33-01-manager-closure.md` Test-Path True |

Each QA observed signal matches the part-38 expected PASS signal and matches
the actual binary stdout line read from `_test_output/stage34-reopen-test-stdout.txt`.

## Spot-check verification

The QA report cites `_test_output/stage34-reopen-test-stdout.txt` and
`_test_output/stage34-reopen-ctest.txt`. Both files exist (Test-Path True).
Spot-checks against the durable file content:

- File size: 21178 bytes. Matches the QA report's 21178-byte claim.
- Five reopen-label PASSED lines: read directly. Labels at stdout lines 114,
  116, 118, 120, 122; each is immediately followed by a `PASSED` line at
  115, 117, 119, 121, 123. Matches the QA report's claim (lines 114, 116,
  118, 120, 122).
- Total-tests line: stdout line 395 reads `Total: 149 tests (...)` including
  the `+ 5 Stage 34 reopened regressions` term. Matches the QA report's 149
  claim and the five-row count.
- ctest file: `_test_output/stage34-reopen-ctest.txt`, 301 bytes, reports
  `100% tests passed, 0 tests failed out of 1`, `1/1 Test #28:
  test-cache-controller ... Passed`. Matches the QA report's exit 0 / 1
  passed / 0 failed / 0 skipped claim.

The durable files agree with the QA prose. No discrepancy found.

## Status check: part-18 implementation re-review PASS findings

The part-18 PASS findings remain consistent with the QA evidence:

- SPLIT pattern line ranges: part-18 cites first lock
  `server-cache-hybrid.cpp:4772-4858`, slow target read `4863-4894`, slow
  draft read `4896-4912`, second lock `4914-4918`, second-pass
  `find_equivalent_entry` `4920`. part-39 independently re-verified these
  same live-tree ranges. The QA run exercises this exact path (T-34-PATHB-01
  restore-during-save-read and T-34-PATHB-02 second-pass dedupe both passed),
  confirming the SPLIT relocation is live and exercised. Consistent.
- Test-only hooks present and gated: part-18 confirms
  `debug_run_save_transaction_for_tests`,
  `debug_set_tx_save_slow_read_hook_for_tests`,
  `debug_set_tx_save_forced_target_bytes_for_tests`,
  `debug_get_tx_save_second_pass_dedupes_for_tests`, and the slow-read
  counter are guarded by `LLAMA_SERVER_CACHE_TESTS`, with `GGML_UNUSED`
  stubs in non-test builds. part-39 re-verified the live declarations. The
  five rows PASS only when these hooks fire, so the hooks are present and
  active in the tested binary. Consistent.
- Five tests registered in main: part-18 cites registration at
  `tests/test-cache-controller.cpp:5860-5864` and total 149 tests. part-39
  independently cites `main:5859-5863`. The QA evidence shows the five
  labels print and the total reads 149. Consistent.

No drift between part-18 and the QA evidence.

## No-bug determination

Verdict: no product bug remains under the reopen-cycle scope
(D34-REOPEN-06 / D34-REOPEN-07).

Basis:

- D34-REOPEN-06 (idempotent `tx_save` with hot-counter bump): covered by
  T-34-IDEM-01 (hot dedupe, one entry, `use_count` advances), T-34-IDEM-02
  (first-pass hot dedupe skips slow read, counter zero), and T-34-IDEM-03
  (cold-residency re-materialize in place, one entry, `use_count` advances).
  All three PASS against a clean 2026-07-07 Release CUDA binary. part-18
  PASS confirms the hot refresh at `server-cache-hybrid.cpp:4848-4857`,
  second-pass hot refresh at `4920-4930`, and cold re-materialize at
  `4933-4955`.
- D34-REOPEN-07 (Path B slow-read relocation and second-pass dedupe):
  covered by T-34-PATHB-01 (restore completes during paused save's
  slow-read window) and T-34-PATHB-02 (second-pass dedupe counter exactly
  one, one entry, `use_count` advances). Both PASS. part-18 PASS confirms
  the SPLIT relocation and the second-pass `find_equivalent_entry` branch.
- TP-34-CC: reclassification only, no execution row, no cache code change
  (D34-REOPEN-05). Not a product bug.

The bin exit code was 0 and ctest reported 0 failures. No crash, no
assertion, no size mismatch, no duplicate entry, no stale iterator signal
appears in the QA evidence. part-18 PASS plus the QA five-row PASS together
close the reopen-cycle scope with no outstanding defect.

## Disk-verification summary

Every cited artifact was checked with `Test-Path` before being written into
this report. Results:

- Deliverable target `._design_docs/.test_reports/test-report-20260707-01-stage34-reopen-developer-review.md`:
  `Get-ChildItem` returned no entry (file does not yet exist). Created by
  this review.
- `_test_output/stage34-reopen-test-stdout.txt`: Test-Path True (21178 bytes).
- `_test_output/stage34-reopen-ctest.txt`: Test-Path True (301 bytes).
- `._design_docs/.test_reports/test-report-20260707-01-stage34-reopen.md`:
  Test-Path True.
- `._design_docs/cache-handling-test-plan/part-38-stage34-reopen-idempotent-save-and-path-b.md`:
  Test-Path True.
- `._design_docs/cache-handling-test-plan/part-39-stage34-reopen-test-plan-review-20260706.md`:
  Test-Path True.
- `._design_docs/cache-handling-phase34-implementation/part-18-implementation-re-review-20260705.md`:
  Test-Path True.
- `._design_docs/cache-handling-phase34-implementation/part-20-manager-test-plan-gate-20260706.md`:
  Test-Path True.
- `._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md`:
  Test-Path True.
- `._design_docs/.test_reports/test-report-20260630-03-stage33-01-manager-closure.md`:
  Test-Path True.

No cited path was invented. The durable files were trusted over the QA prose
where both spoke; they agreed.

## Proposed Manager closure recommendation text

Verbatim, ready for the Manager to copy into the closure record:

```text
D-CLOSURE-34-REOPEN-01: PASS Stage 34 reopen cycle (D34-REOPEN-06/07) with
5 PASS (T-34-IDEM-01/02/03, T-34-PATHB-01/02) / 0 FAIL / 0 BLOCKED /
1 N/A-not-an-execution-row (TP-34-CC reclassified EXPECTED-BEHAVIOR
dispatch-ordering race per D34-REOPEN-05, Stage 33 precedent) / 0 SKIP.
The test-results review gate (Developer, test-report-20260707-01-stage34-reopen-developer-review.md)
PASSes; all six prior gates (design, implementation-planning, implementation,
test-planning, test-execution, plus the part-18 implementation re-review and
part-39 independent test-plan review) PASS. No product bug remains under the
reopen-cycle scope. Production C++ carries the uncommitted Stage 27/28/30/31/32
plus Stage 34 reopen fixes; per AGENTS.md user approval is required for commit.
Closure does NOT authorize commit.
```

## Code state note

The production code changes for D34-REOPEN-06 (idempotent `tx_save` with
hot-counter bump) and D34-REOPEN-07 (Path B slow-read relocation and
second-pass dedupe), plus the Stage 34 reopen regression tests, remain
UNCOMMITTED in the worktree. Per AGENTS.md, committing or pushing requires
explicit human approval for each action. This review's PASS and any Manager
closure decision do NOT authorize a commit.

## Overall verdict

Reviewer verdict: PASS. All five execution rows PASS, the TP-34-CC scope note
is correctly N/A-not-an-execution-row, no product bug remains under the
reopen-cycle scope, and the part-18 implementation re-review findings still
hold against the QA evidence.

Reviewer verdict: PASS - Manager may close the Stage 34 reopen cycle.

## Next owner and next gate

Next owner: Manager.
Next gate: Stage closure (D34-REOPEN-08). Optional Architect closure doc sweep
if any durable docs are stale; none were found stale in this review.
