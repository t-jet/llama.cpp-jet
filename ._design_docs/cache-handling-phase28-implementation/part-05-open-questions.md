# Stage 28 implementation plan part 5: open questions

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)

This part lists the 5 open questions for Manager review. Each
question records the question, why it matters, the Developer's
proposed default if no answer is provided, and the reopen
condition.

## Open question 1: R28-BUG-02 iteration scope

Question: If R28-BUG-02 diagnosis (Step 3) reveals the orphan-file
path is fundamentally a refactor (not a one-line tweak), should
iter 1 close with R28-BUG-02 OPEN, or should iter 1 stretch to
2-3 implementation passes to fully close it?

Why it matters: iter 1 closure contract requires all 4 HIGH fixes
verified. Stretching iter 1 to multiple implementation passes
increases wall-time and complicates the test-execution gate.
Closing iter 1 with R28-BUG-02 OPEN shifts the bug to Stage 29 and
adds a follow-up entry to the Stage 27 closure follow-ups list.

Proposed default: stretch iter 1 if fix scope <= 200 production
lines; close iter 1 with R28-BUG-02 OPEN if scope > 200 lines or
requires a new module/metric.

Reopen condition: Step 3 diagnosis completes; Architect reviews
the new path; Manager decides.

## Open question 2: Stage 28 -08 rerun parallel with QA

Question: Should Stage 24 -08 rerun in Step 8 be executed by
Developer (to capture own evidence) or by QA (to maintain
separation of concerns)?

Why it matters: Developer ownership of the rerun keeps evidence
collection tight to the implementation. QA ownership maintains
the test-execution-vs-test-design separation that prior stages
used. The Stage 27 closure used Developer-executed rerun for the
-07 verification, so precedent is Developer.

Proposed default: Developer-executed rerun (per Stage 27 precedent).
QA executes the final Stage 28 -08 closure rerun if iter 2 makes
substantive changes.

Reopen condition: Manager decides separation-of-concerns rule.

## Open question 3: R28-TD-05 conditional deletion threshold

Question: How many deprecation warnings post-Step 7 are acceptable
before R28-TD-05 (Step 10) is skipped?

Why it matters: R28-TD-05 is conditional on Step 7 having zero
deprecation warnings. If 1-5 tests genuinely need the worker thread's
race timing and cannot be migrated cleanly, the build will have 1-5
warnings. Deletion (Step 10) will then leave those tests un-buildable.

Proposed default: 0 warnings required for Step 10 to proceed. If
1-5 warnings remain, leave those tests as documented exceptions
(warnings only, not errors) and skip Step 10; document the
remaining tests as R28-TD-19+ for a future async-worker-revival
stage.

Reopen condition: Step 7 reveals > 0 deprecation warnings that
cannot be resolved within iter 1 wall-time budget.

## Open question 4: test plan addendum timing

Question: When should TP-28-UT-01..03 be added to the cache-handling-
test-plan durable doc?

Why it matters: The new tests are designed in Steps 4 and 9 but
the test plan addendum (per design part-04 "Test plan addendum"
section) is a separate durable doc work item. Adding the addendum
in iter 2 keeps the test count aligned with the implementation log
at iter 2 closure.

Proposed default: Author test plan addendum at Stage 28 closure
sweep (after iter 2 PASS), not in this planning session. The
implementation log captures test counts and PASS evidence; the
test plan addendum is a follow-up doc update.

Reopen condition: Manager decides test plan timing.

## Open question 5: 11 LOW items final disposition

Question: Should the 11 LOW severity items (R28-TD-08..18) be
closed as DEFERRED in the Stage 28 closure record, or remain OPEN
without closure?

Why it matters: The Stage 27 closure pattern is "follow-ups open"
with explicit ownership. Closing the LOW items as DEFERRED gives
a clean closure record but loses the per-item rationale. Leaving
them OPEN keeps the rationale but makes the closure record
incomplete.

Proposed default: close LOW items as DEFERRED in the Stage 28
closure record with a single sentence rationale ("cosmetic; not
user-impacting"). The detailed inventory stays in design part-01
LOW section.

Reopen condition: Manager decides closure wording.

---

## Manager decisions requested

The following 5 Manager decisions are needed to close the
implementation plan gate:

- D28-PLAN-01: approve proposed OQ-28-01..06 resolutions (or amend).
- D28-PLAN-02: approve iter 1 wall-time budget (4 hours estimated;
  6 hours cap).
- D28-PLAN-03: approve iter 2 wall-time budget (2 hours estimated;
  4 hours cap).
- D28-PLAN-04: approve the test plan addendum timing (default:
  closure sweep, not this planning session).
- D28-PLAN-05: approve Stage 24 -08 rerun ownership (default:
  Developer-executed per Stage 27 precedent).

## Scope clarifications

The following scope clarifications are binding from this session:

- R28-BUG-02 fix scope is 30-60 production lines + 50 test lines
  per design part-02. Stretch scope if Step 3 diagnosis reveals
  a 4th candidate.
- R28-BUG-04 Phase B test migration scope is 41+ test refs;
  unbuildable tests become R28-TD-19+ items (out of Stage 28).
- R28-TD-05 deletion scope is conditional on Step 7 zero warnings.
- R28-TD-04 + R28-TD-07 runner fix scope is 5 lines total per
  design part-01.
- 11 LOW items (R28-TD-08..18) are out-of-scope.

## Stage 28 deliverables (summary)

| Deliverable | Path |
| --- | --- |
| Entry doc | `._design_docs/cache-handling-phase28-implementation.md` |
| Part 1 ordered steps | `._design_docs/cache-handling-phase28-implementation/part-01-ordered-implementation-steps.md` |
| Part 2 affected files | `._design_docs/cache-handling-phase28-implementation/part-02-affected-files.md` |
| Part 3 evidence plan | `._design_docs/cache-handling-phase28-implementation/part-03-evidence-plan.md` |
| Part 4 risks + OQ | `._design_docs/cache-handling-phase28-implementation/part-04-risks-and-oq-resolutions.md` |
| Part 5 open questions | `._design_docs/cache-handling-phase28-implementation/part-05-open-questions.md` |
| Iter 1 evidence | `._test_output/stage24-r28-bug02-diag.log`, `._test_output/build-r28-*.log`, `._test_output/test-r28-*.log`, `._design_docs/.test_reports/test-report-20260627-01.md` |
| Iter 2 evidence | `._test_output/test-r28-td*.log`, `._design_docs/.test_reports/test-report-20260627-02.md` |
| Implementation log evidence parts | `._design_docs/cache-handling-phase28-implementation/part-11-iter1-evidence.md`, `part-12-iter2-evidence.md` (TBD at iter close) |
| Manager closure | `._design_docs/cache-handling-phase28-implementation/part-13-manager-closure-20260627.md` (TBD at closure) |
| Document-index row | (added at closure sweep, not in this planning session) |

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
