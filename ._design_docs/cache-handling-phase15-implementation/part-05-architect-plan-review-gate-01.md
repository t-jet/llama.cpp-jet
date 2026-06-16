# Stage 15 implementation-plan review gate 01

Source: [../cache-handling-phase15-implementation.md](../cache-handling-phase15-implementation.md)

Date: 2026-06-12

Reviewer session: Architect (Stage 15 implementation-plan review, fresh session). Reviewer did not author the plan.

## Status

Verdict: REWORK

Counts:

- BLOCKING: 1
- Non-blocking: 1
- INFO: 0

## Scope and gate status

Scope matches the user request recorded in
`._design_docs/cache-handling-stage-tracker.md` line 42. The plan
re-states that scope verbatim in the entry doc, treats the
architecture-baseline scope as fixed, and writes the operational
contract that lets QA, Developer, Architect, and Manager work the
test suite, the bug-fix loop, and the benchmark report without
redefining scope.

The current gate is `implementation planning in progress`. After
this review returns REWORK, the Developer addresses the single
BLOCKING finding (I1: file hygiene, CRLF line endings) and
re-submits the plan for a re-review. The next gate after
re-review PASS is the Manager implementation-plan gate decision.

The design review (part-08) returned PASS on 2026-06-12 with one
non-blocking observation (N1, C-regression row subrange typo).
That N1 finding is addressed in the plan at part-01 step 2 and
part-02 C-regression. The plan does not modify the design, the
entry doc, or any part 02-07 file. This review file is the only
new file authored by this review session.

All referenced scripts exist on disk:
`kickoff-v2-stress-longrun.ps1`, `execute_tests.ps1`,
`run_coverage.ps1`, `run-v2-bench-batch.ps1`, and the test plan
parts 03, 07, 23 (verified by Test-Path).

## Findings

| ID | Section | Description | Evidence |
| --- | --- | --- | --- |
| N1 | part-02 risk table | The plan's risk table does not list a `flaky tests` risk. The design part-06 risk table also omits this category. The plan faithfully extends the design. Not a closure contract; the plan already covers related concepts in `Pre-existing test bug becomes a hard fail` and `Bug-fix loop exhausts the 3-iteration cap`. Optional addition for future plan revisions. | `cache-handling-phase15-implementation/part-02-evidence-plan-and-risks.md` risk table. |

The BLOCKING finding is recorded under Checklist verification
item I1 below and Required corrections.

## Checklist verification

| # | Item | Verdict | Note |
| --- | --- | --- | --- |
| F1 | D1-D5 carried forward verbatim or with documented refinement | PASS | part-03 records D1-D5 with dates 2026-06-12 in quoted form; entry doc D1-D5 also present. |
| F2 | P1-P5 have IDs, dates, verbatim statements | PASS | part-03 P1-P5 all dated 2026-06-12 with verbatim statements and IDs. |
| F3 | Carry-forward contracts enumerated: E13-01..E13-16, MTMD placeholder, diagnostic-source namespace isolation, bounded cache metadata format, T114/T114a/T115/T121, S01..S08, L01..L03, B01..B08 | PASS | entry doc `Carry-forward contracts from prior stages` lists all required contracts. |
| F4 | N1 non-blocking finding from design review addressed | PASS | part-01 step 2 has `Resolution of the N1 finding` paragraph; part-02 C-regression notes resolution; entry doc references the N1 finding. |
| F5 | Scope statement present | PASS | entry doc scope: `Stage 15 is operational. It does not add new cache behavior, public endpoints, CLI flags, metrics, or test code.` |
| G1 | Test suite execution order with justification | PASS | part-01 Step 2 lists the 8-step order (ctest, pytest, public-http, closure, stress, longrun, bench, regression) with category IDs. |
| G2 | Long-running test driver, side log path, cap-exit parsing, per-row delegation | PASS | part-04 names `kickoff-v2-stress-longrun.ps1`; side log at `longrun-stage15-YYYYMMDD/batch-summary.log.side`; cap-exit via `cap-exit.json` and `summary.md`; per-row delegation through the kickoff driver. |
| G3 | Bug-fix loop procedure: per-iteration sequence, max 3 iterations, escalation, regression evidence | PASS | part-01 Step 3 names the 4-step sequence, 3-iteration cap, Manager escalation path, and `test-report-YYYYMMDD-NN-fixes.md` regression evidence shape. |
| G4 | Benchmark report path and content per D4 with B01..B08 metrics | PASS | part-01 Step 4 names path `stage15-benchmark-20260612-01.md`; lists 8 required sections, 8 metrics from design part-05. |
| G5 | Public endpoint parity rerun: E13-01..E13-16 | PASS | part-02 C-public-http section names the Stage 13 evidence format and the E13-01..E13-16 verdict requirement. |
| G6 | Coverage rerun: T114/T114a/T115/T121 | PASS | part-02 C-closure section names combined rate, product-only rate, per-file aggregation, four `cache_checkpoint_*` rows on MTP-capable fixture. |
| G7 | MTMD placeholder path rerun procedure | PASS | Carry-forward contracts list MTMD placeholder path; C-public-http uses Stage 13 evidence format which includes the route-family value check. |
| G8 | Diagnostic-source namespace isolation test procedure | PASS | Carry-forward contracts list the isolation rule; C-public-http uses Stage 13 evidence format. |
| G9 | Bounded `cache metadata:` format test procedure at task launch | PASS | part-02 C-public-http required content names the bounded `cache metadata:` line on degraded paths. |
| G10 | Stage 12 stress and benchmark contracts rerun (S01..S08, L01..L03, B01..B08) | PASS | part-02 C-stress, C-longrun, C-bench cover all 19 rows. |
| G11 | Worktree and branch state: work-branch, no merge to master | PASS | part-04 `Branch and worktree state` section. |
| G12 | Clean-build rule: command and gate | PASS | part-04 `Clean-build rule` and part-01 Step 1 freshness check. |
| H1 | D1-D5 and P1-P5 are decisions, not pre-approvals | PASS | entry doc: `not pre-approvals of implementation`; part-03 same wording for P1-P5. |
| H2 | Manager decisions log present and dated | PASS | part-03 is the dated Manager decision log; all entries dated 2026-06-12. |
| H3 | Handoff section names next owner (Developer for implementation) | PASS | entry doc handoff: `next owner is Developer for implementation`. |
| H4 | Per-step ownership explicit (Developer, Architect, QA, Manager) | PASS | part-01 Step 1-5 each name an owner. |
| H5 | Evidence plan covers per-category capture (file path, format, content) | PASS | part-02 `Per-category evidence capture` covers all 8 categories. |
| H6 | Risk table has time budget overrun, flaky tests, real product bug found, environment blocker, MTP model availability | PASS | Table has 13 items. `flaky tests` not explicit; related concepts covered in `Pre-existing test bug becomes a hard fail` and `Bug-fix loop exhausts the 3-iteration cap`. Recorded as non-blocking observation N1. |
| H7 | Prerequisites and host tooling list concrete | PASS | part-04 names clean-build command, k6 path, OpenCppCoverage path, fixtures, MTP model. |
| H8 | Plan does not invent a new longrun driver | PASS | part-04 re-uses `kickoff-v2-stress-longrun.ps1`; explicitly says `the plan does not invent one`. |
| I1 | All files LF-only UTF-8 with no BOM | FAIL | All 5 plan files (entry doc + parts 01-04) have CRLF line endings (CRLF count equals line count, 0 bare LF). BLOCKING. |
| I2 | No file exceeds 300 lines | PASS | entry doc 168 lines, part-01 225, part-02 177, part-03 97, part-04 180. All under 300. |
| I3 | Plain ASCII only; no emoji, no unicode icons | PASS | 0 non-ASCII bytes across all 5 files. |
| I4 | `git diff --check` exit 0 on the touched files | PASS | exit code 0 on plan files (untracked, so no diff to check; CRLF in untracked content is not flagged by `git diff --check`). |
| I5 | Plan does not modify any prior stage's design or implementation docs | PASS | git status shows only M on tracker.md and document-index.md; all phase15 files are untracked. |
| I6 | Plan does not contain code, test changes, or commits | PASS | Part-01 has PowerShell command snippets in fenced blocks as reference commands, not as code changes. Plan does not authorize commits. |

## Required corrections

1. (BLOCKING, I1) Convert all 5 plan files
   (`cache-handling-phase15-implementation.md` and
   `cache-handling-phase15-implementation/part-01-implementation-plan.md`
   through `part-04-prerequisites-and-host-tooling.md`) to LF-only
   UTF-8 with no BOM. Current state: every line in all 5 files
   uses CRLF line endings. The design files use LF-only. The plan
   must match the design convention. The Developer should use
   `ReadAllText` followed by `-replace "\r\n", "\n"` and
   `WriteAllText` with `UTF8Encoding($false)`, then verify
   with `[regex]::Matches` on `"\r\n"` returning 0 and a BOM
   check on the first three bytes. After conversion, re-run
   `git diff --check` and confirm 0 errors on the plan files.

## Handoff state

Review verdict: REWORK.

Next gate: Architect plan review re-submit after the Developer
addresses the single BLOCKING finding (I1: file hygiene).

Next owner: Developer.

The Developer converts the 5 plan files to LF-only UTF-8 with no
BOM, then re-issues the plan for re-review. The Architect
re-reads the files, confirms the conversion, and either returns
PASS or records any new finding. After Architect re-review PASS,
the next gate is the Manager implementation-plan gate decision.
The Manager reads this review together with the plan, the entry
doc, and parts 01-04, and records the plan-gate decision. Test
execution, bug-fix work, and the benchmark report remain
unauthorized until the Manager records the plan-gate decision.

## Re-review (REWORK I1 fix verification)

Date: 2026-06-12

Reviewer session: Architect (Stage 15 implementation-plan
re-review, fresh session). Reviewer did not author the I1 fix.

## I1 fix verification

Byte-level check for the 5 plan files, after the Developer's
CRLF-to-LF conversion. CR=0, LF>0, BOM=False for all 5 files
matches the LF-only design baseline
(`cache-handling-phase15-design.md` CR=0 LF=216 BOM=False;
`cache-handling-phase15-design/part-08-design-review-gate-01.md`
CR=0 LF=102 BOM=False).

| File | CR | LF | BOM | Verdict |
| --- | --- | --- | --- | --- |
| `cache-handling-phase15-implementation.md` | 0 | 168 | False | PASS |
| `cache-handling-phase15-implementation/part-01-implementation-plan.md` | 0 | 225 | False | PASS |
| `cache-handling-phase15-implementation/part-02-evidence-plan-and-risks.md` | 0 | 177 | False | PASS |
| `cache-handling-phase15-implementation/part-03-known-decisions.md` | 0 | 97 | False | PASS |
| `cache-handling-phase15-implementation/part-04-prerequisites-and-host-tooling.md` | 0 | 180 | False | PASS |

`git diff --check` on the 5 plan files produced no output and
exit code 0. Untracked file path; the `git diff --check` exit
0 reflects the absence of whitespace errors, not a missed
content requirement, but the byte-level check above is the
authoritative LF-only verification.

## Regression check

LF count after conversion (168, 225, 177, 97, 180) matches the
line counts recorded in the original review (168, 225, 177, 97,
180). First-line of each file is the expected heading
(`# Stage 15 implementation log: full test suite validation,
bug-fix loop, and benchmark report`,
`# Stage 15 implementation plan: ordered steps, owners, and
gate sequencing`, and the three remaining `part-NN` titles).
Closing sentences of each file are intact: the entry doc closes
on the architecture-scope sentence, part-01 closes on the
unauthorized-until-Manager-decision sentence, part-02 closes on
the Manager-uses-risk-table sentence, part-03 closes on the
implementation-plan-gate-decision sentence, and part-04 closes
on the implementation-plan-review-closes sentence. No new
non-ASCII characters and no trailing whitespace were introduced
on any of the 5 plan files (nonAscii=0, trailingWsLines=0
across all 5 files).

## Scope of changes

`git status --short` shows only the 5 expected modifications:
M on `cache-handling-stage-tracker.md`,
`document-index.md`, and the three repo-memory files
(architect.md, developer.md, manager.md), plus the four
untracked paths for the design and implementation trees
(`cache-handling-phase15-design.md`,
`cache-handling-phase15-design/`,
`cache-handling-phase15-implementation.md`,
`cache-handling-phase15-implementation/`). No design file,
prior-stage implementation file, or other review file was
modified. No new files outside the 5 plan files were
introduced.

## New verdict

PASS.

Counts:

- BLOCKING: 0
- Non-blocking: 0 (N1 from the original review is unchanged and
  remains QA-resolves-at-execution per the original review
  verdict)
- INFO: 0

The original review's I1 BLOCKING is closed by the LF-only
conversion. All other checklist items (F1-F5, G1-G12, H1-H8,
I2-I6) remain PASS per the original review; the I1 fix did not
touch any of their evidence.

## Handoff state

Review verdict: PASS.

Next gate: Manager implementation-plan gate decision.

Next owner: Manager.

The Manager reads this re-review together with the original
review, the plan entry doc, and parts 01-04, and records the
plan-gate decision. The Architect re-review is closed. The
Developer remains on hold for code, tests, fixes, and commits
until the Manager records the plan-gate decision.
