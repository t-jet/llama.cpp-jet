# Stage 14 implementation plan, ordered steps, and gates

Source: [../cache-handling-phase14-implementation.md](../cache-handling-phase14-implementation.md)

## Status

Planning date: 2026-06-11
Plan state: drafted for Architect implementation-plan review
and Manager implementation-plan gate.
Implementation state: not started.
QA execution state: not started.

## Accepted design baseline

Built on [../cache-handling-phase14-design.md](../cache-handling-phase14-design.md)
parts 01-07. Architect design review
[part-07](../cache-handling-phase14-design/part-07-design-review-gate-01.md):
PASS, 0 BLOCKING, 3 non-blocking (N1 conflict resolution
reference, N2 Part 4 edge case label, N3 Part 5 CUDA fallback
row under Stage 12 stress preflight), 4 INFO. Manager design
gate PASS 2026-06-11. Scope is fixed by the architecture.
Procedure baseline is
[../upstream-merge-guide.md](../upstream-merge-guide.md) and its
four part files; this plan references the guide for procedure
and does not duplicate it.

## Prerequisites and gates

| Prerequisite | Owner | Status | Source |
| --- | --- | --- | --- |
| Stage 12 closure record, no open product bug, no QA harness blocker, no environment blocker | Manager | PASS, 2026-06-07 | Stage 12 implementation log |
| Stage 13 closure record, no open product bug, no QA harness blocker, no environment blocker | Manager | PASS, 2026-06-10 | Stage 13 implementation log |
| Stage 14 design authoring, Architect review, Manager design-gate | Manager | PASS, 2026-06-11 | Design part-07 |
| Remote-tracking ref `origin/upstream_master` current against actual upstream `master` per D1 | Developer | PASS via Path C decision 2026-06-11 | Design Part 1. D4 resolved via Path C. |
| Local default branch checked out at a clean tree at cycle open | Developer | NOT STARTED | Design Part 1. Open D5. |
| Host can run focused ctest, focused exporter coverage, k6, Stage 12 stress harness, Stage 12 benchmark harness, Stage 13 endpoint probe | Developer | NOT STARTED | [part-04-prerequisites.md](part-04-prerequisites.md) |
| `build-cov` available for T114 and T114a coverage run | Developer | present | Stage 10 cap-fix closure 2026-06-07 |
| `build-cuda-stage13` available for E13 endpoint probe | Developer | present | Stage 13 closure 2026-06-10 |
| Model fixtures for Stage 12 stress regression reruns (S01..S08, L01..L03) | Developer | NOT STARTED | Stage 12 closure fixture inventory |
| Architect implementation-plan review of this plan | Architect | NOT STARTED | Next gate |
| Manager implementation-plan gate decision | Manager | NOT STARTED | Follows Architect review |

## Ordered steps

The merge activity follows the six steps below. Steps 1 through
6 do not start until every prerequisite Developer gate above
closes. The six steps mirror upstream-merge-guide Part 1 section
1 procedure-at-a-glance and the Stage 11 implementation plan
part-01, with the Stage 14 specifics applied.

### Step 1: pre-merge analysis

Owner: Developer. Reviewer: Architect. Approver: Manager for any
rework-trigger decision. Deliverable: durable pre-merge report at
`._design_docs/.test_reports/pre-merge-report-YYYYMMDD-NN.md`
following the seven required sections from design Part 2 and
upstream-merge-guide Part 1 section 5.

Activities:

1. Confirm the working tree is clean and the local default
   branch is checked out at the fork point. If dirty, stop and
   surface to the Manager per open decision D5.
2. Fetch the upstream ref per D1 (`git fetch origin`) and
   re-verify `git rev-parse origin/upstream_master`. Record
   the remote ref tip SHA, the actual upstream tip SHA via
   `git ls-remote https://github.com/ggml-org/llama.cpp.git
   master`, and the gap in the pre-merge report "Upstream
   reference verification" section. The remote ref is the
   source of truth. No local branch is required.
3. Compute the merge base
   (`git merge-base LOCAL origin/upstream_master`) and the
   commit range
   (`git log --oneline LOCAL..origin/upstream_master | wc -l`).
   Record the fork point SHA and the total commit count.
4. Apply the file-glob filter from design Part 2 "File-glob
   groups for scope selection". Record the filtered commit
   count and the file-glob groups matched per commit.
5. Assign one triage decision per in-scope commit:
   NO-OP, INTEGRATE, REWORK-REQUIRED, DEFER, or REVERT.
   Cite the prior-stage contract from design Part 1 the
   commit leaves untouched, modifies, or breaks. Reasons
   that only restate the commit subject are not acceptable.
6. Record the aggregate summary (counts per decision, set
   of prior stages touched, expected touched file list)
   and the Manager decisions requested (D4-D11, and any
   open question from the triage).

Exit criteria: the pre-merge report is on disk with the
triage table complete, the aggregate summary populated, the
Manager decisions requested section populated, and the
seven required sections present.

### Step 2: Manager review of the pre-merge analysis

Owner: Manager. Reviewer: Architect. Deliverable: Architect
pre-merge review verdict at
`._design_docs/.test_reports/pre-merge-report-YYYYMMDD-NN-architect-review.md`
and a Manager decision record in the pre-merge report
"Manager decisions requested" section.

Activities:

1. Architect records a review verdict. Verdict PASSES only
   when triage reasons cite a contract, a path, or a test
   surface; the aggregate summary is consistent with the
   triage table; and the upstream reference verification
   matches the local repo state.
2. Manager reviews the Architect verdict. Manager is the
   only agent that can change NO-OP, INTEGRATE, or DEFER
   into REWORK-REQUIRED. Manager records the change with
   the date and the prior-stage contract the change
   protects.
3. Rework part files for any escalation open in Step 4,
   not here. The pre-merge report records the Manager
   decisions and the rework part file links.

Exit criteria: the pre-merge report carries an Architect
verdict and a Manager decision on every revisited row, and
every REWORK-REQUIRED entry has a follow-up owner named in
the report.

### Step 3: merge execution

Owner: Developer. Reviewer: Architect. Deliverable: a merge
commit on the local default branch verified with
`git rev-list --parents -n 1 <merge-sha>` to show two parents,
and an initial merge log update. Conflict resolution policy per
upstream-merge-guide Part 2 section 1 (hybrid and legacy
default preservation, local-first for hybrid mode,
upstream-first for legacy mode).

Activities:

1. Re-confirm the commit range. If the range changed since
   Step 1, reopen Step 1 and stop.
2. Run the merge into the local default branch. A
   fast-forward is acceptable only when the pre-merge
   analysis lists no INTEGRATE or REWORK-REQUIRED
   decisions. Otherwise a `--no-ff` merge commit is
   required. The merge is a real two-parent merge.
3. Resolve conflicts per design Part 3 and
   upstream-merge-guide Part 2 section 1. For semantic
   conflicts the merge tool does not catch (duplicates,
   divergent fix paths, mechanical renames, stale defensive
   code, behavior changes), apply the patterns from
   upstream-merge-guide Part 2 sections 4 through 11.
4. Run the build and test command family from design Part
   3: local configure, local build, local ctest, focused
   exporter coverage when the merge touched a hybrid-mode
   source file, Stage 12 stress harness preflight when the
   merge touched a stress-harness source file, Stage 12
   benchmark harness preflight when the merge touched a
   benchmark source file, and Stage 13 endpoint probe when
   the merge touched an endpoint adapter source file.
5. Update the merge log with the merge command, the
   conflict list, the resolution list, the build result,
   the test result, and the date.

Exit criteria: the integration branch builds, the prior-
stage ctest binaries pass, the focused exporter coverage
rerun is on disk (when applicable), and the merge log
records the merge command, conflicts, resolutions, and
intermediate test results.

### Step 4: per-rework planning

Owner: Architect (design), Developer (implementation).
Reviewer: Architect. Approver: Manager. Deliverable: a rework
part file in the affected stage's design directory per
REWORK-REQUIRED entry, with the rework implementation plan in
the affected stage's implementation log.

Activities:

1. For each REWORK-REQUIRED entry, the Architect opens a
   rework part file in the affected stage's design
   directory. The rework part file references the prior-
   stage contract from design Part 1, the upstream change
   that triggered the rework, and the contract gap the
   rework must close.
2. The rework follows the standard stage workflow (Design,
   Implementation, Test, Closure) but is limited to the
   contract gap. Broader redesign opens as a new stage
   through the standard intake.
3. The Developer writes a rework implementation plan in
   the affected stage's implementation log. The rework
   plan follows the same shape as the original stage plan
   but is scoped to the contract gap.
4. The rework evidence lives in the affected stage's
   implementation log. The Stage 14 implementation log
   records the rework list, the status of each rework, and
   the close date.
5. When more than one upstream change maps to the same
   prior stage, the Architect opens a single rework. A
   second rework opens only when a later Stage 14 cycle
   surfaces a new contract gap.

Exit criteria: every REWORK-REQUIRED entry has an opened
rework with a status recorded in the Stage 14 implementation
log, or has been reclassified by Manager as a known gap with
a follow-up owner and target cycle.

### Step 5: regression test scope

Owner: QA. Reviewer: Developer. Approver: Architect and
Manager. Deliverable: a Stage 14 test report at
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
with the artifact set the design Part 5 "Evidence format"
table prescribes.

Activities:

1. Run the minimum regression scope for the no-rework case,
   narrowed to the test plan parts whose prior-stage
   contract touched a path the merge changed. The minimum
   scope is in
   [part-02-evidence-plan-and-risks.md](part-02-evidence-plan-and-risks.md).
2. For each closed rework, run the expanded scope the
   rework part file records. The expanded scope adds the
   rework-specific evidence on top of the minimum scope
   for the reworked stage.
3. Record the T114 verdict from the `## Combined result`
   block, the T114a verdict from the `## Product-only
   result` block, the T115 per-file aggregation verdict,
   the T121 public checkpoint admission verdict, and the
   E13-01..E13-16 endpoint parity verdicts. The XML root
   attributes are not the verdict source. The citation
   rules match upstream-merge-guide Part 3 section 3.
4. Open a paired fixes report when any row is FAIL or
   BLOCKED. The fixes report lives beside the test report
   and uses the test plan paired-name convention.

Exit criteria: every test plan row whose prior-stage
contract the merge touched is on disk with a verdict, and
the closure contracts T114, T114a, T115, T121, and the
E13-01..E13-16 endpoint parity rows are all PASS or
documented as a known gap with a Manager follow-up owner
and target cycle.

### Step 6: merge log and Stage 14 closure

Owner: Developer. Reviewer: Architect. Approver: Manager.
Deliverable: a complete merge log at
`._design_docs/.test_reports/merge-log-YYYYMMDD-NN.md` with
the nine required sections from design Part 6 "Merge log
format" table, and a Stage 14 closure record in the Stage
14 implementation log entry doc.

Activities:

1. Open the merge log with the nine required sections:
   cover and metadata, upstream reference verification,
   decisions, deferred upstream commits, known gaps,
   conflicts encountered, reworks opened, regression
   evidence, and closure status.
2. Record the final triage decision per in-scope commit,
   with a reason that names a prior-stage contract from
   design Part 1. Changes from the pre-merge report carry
   the date and the agent who changed the decision.
3. Record the architecture exit criteria from design Part
   1 that the integration branch has met, and the criteria
   still open with the follow-up action the Manager
   assigned.
4. Manager records the Stage 14 closure decision in the
   Stage 14 implementation log. The closure confirms the
   integration branch satisfies the architecture exit
   criteria and the prior-stage closure contracts.

Exit criteria: the merge log is on disk with every required
section populated, and the Manager has recorded a Stage 14
closure decision in the Stage 14 implementation log.

## Per-step summary

| Step | Deliverable | Owner | Exit condition |
| --- | --- | --- | --- |
| 1 Pre-merge analysis | Pre-merge report with seven required sections, triage table, aggregate summary, Manager decisions requested | Developer (Architect review) | Report on disk, all sections populated, in-scope commits triaged with contract-citing reasons |
| 2 Manager review | Architect verdict, Manager decision record on pre-merge report | Manager (Architect review) | Architect verdict PASS, Manager decision on every revisited row, rework follow-up owner named for each REWORK-REQUIRED entry |
| 3 Merge execution | Real two-parent merge commit, conflict resolution list, build and test results, initial merge log | Developer (Architect review) | Integration branch builds, prior-stage ctest passes, focused exporter coverage on disk when applicable, merge log updated with conflicts and resolutions |
| 4 Per-rework planning | Rework part file per REWORK-REQUIRED entry in affected stage's design tree, rework implementation plan in affected stage's implementation log | Architect (design), Developer (plan) | Every REWORK-REQUIRED entry has an opened rework with a status, or has been reclassified as a known gap with a follow-up owner and target cycle |
| 5 Regression test scope | Stage 14 test report with T114, T114a, T115, T121, E13-01..E13-16 verdicts and cited artifacts, paired fixes report on FAIL or BLOCKED | QA (Developer review) | Every test plan row whose prior-stage contract the merge touched is on disk with a verdict, closure contracts and endpoint parity rows PASS or documented as a known gap with Manager follow-up |
| 6 Merge log and closure | Complete merge log with nine required sections, Stage 14 closure record in implementation log | Developer (Architect review, Manager approval) | Merge log on disk with every section populated, Manager records Stage 14 closure decision in implementation log |

