# Stage 11 evidence plan, risks, and open decisions

Source: [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)

## Status

Planning date: 2026-06-04
Plan state: drafted.
Implementation state: closed.
QA execution state: closed.

## Test plan

The Stage 11 regression covers the prior-stage contracts the merge
touches. The Developer re-runs only the rows whose prior-stage contract
the merge changed. A regression run that excludes such a row is a
closure-contract failure.

The regression scope follows design Part 5, "Regression test reruns and
evidence." The minimum scope applies when the pre-merge analysis lists
no REWORK-REQUIRED or REVERT decisions. The expanded scope applies for
each closed rework.

### Minimum regression scope for a no-rework merge

| Test plan area | Prior-stage contract | Required evidence |
| --- | --- | --- |
| Stage 1-3 regression | Hybrid mode opt-in, legacy default, mode dispatch, non-destructive exact hits, usage tracking | ctest result for the focused cache test binaries used by the closed stages. Per-test pass or fail table. |
| Stage 4-6 regression | Byte-accounted LRU, protected roots, descriptor validation, paired atomicity, cold store integrity, root containment, async I/O | ctest result for the cache-policy, cache-store, and cache-controller test binaries. Structured-log check for the cold store error path. |
| Stage 7-8 regression | Branch forest, namespace validation, slot references, metadata-only nodes, re-materialization, mismatch handling, equivalent-branch deduplication, cold cleanup ownership | ctest result for the cache-graph and cache-io-worker test binaries. Focused-controller test result for mismatch and dedup paths. |
| Stage 9 regression | Checkpoint payload lifecycle, workload profile detection, checkpoint-first restore, exact-blob preference, prepared-prompt boundary placement | ctest result for the cache-controller test binaries. Model-backed or fixture-backed evidence only when the closed stages already required it. |
| Stage 10 regression | Public Prometheus metric set and label shape, bounded diagnostics, cold-store hardening, descriptor integrity, marker validation, OWASP mitigations, deterministic seams | ctest result for the Stage 10 test binaries. Public HTTP probe for the four `cache_checkpoint_*` rows when a hybrid-mode MTP or checkpoint-capable server is available on the host. |
| Coverage | T114 combined 80% floor and T114a product-only 70% floor | Focused exporter coverage run on the integration branch. Cite the `## Combined result` block for T114 and the `## Product-only result` block for T114a. |
| Per-file aggregation | T115 | Per-file table in `coverage-report.md` lists each hybrid-mode file exactly once, with deduplication by lowercased full path. |
| Public checkpoint admission | T121 | The four `cache_checkpoint_*` rows in the public /metrics output when a hybrid-mode MTP or checkpoint-capable server is exercised. |

The Developer does not invent new evidence formats that the closed
stages did not use. The Stage 11 evidence uses the same artifact shape
as the Stage 10 evidence, with the test plan Part 13 citation rules
for the coverage report.

### Expanded scope for a reworked stage

When a rework closes, the regression scope for the reworked stage
follows the test plan parts the rework part file lists. The rework
part file may add a focused test function, a focused exporter check,
a public HTTP probe, or a coverage row that did not exist before.

The expanded scope is:

1. The full minimum regression scope for the reworked stage.
2. The added evidence the rework part file records.
3. The focused exporter coverage run for any hybrid-mode source file
   the rework changed. The T114 combined floor and the T114a
   product-only floor remain closure contracts after the rework.
4. The structured-log check for any diagnostic field the rework added
   or renamed.
5. The public HTTP probe for any metric the rework added, removed,
   or renamed. The probe must run against a hybrid-mode server that
   exercises the affected code path.

The Developer does not start the Stage 11 regression rerun until every
open rework for the merge has closed. A rework that is still open at
the time of the Stage 11 regression is a blocker, not a known gap.

## Evidence plan

The Stage 11 evidence is a set of test reports, coverage reports,
pre-merge reports, and merge log entries. The Developer opens a new
artifact for each Stage 11 execution session.

### Artifact location and naming

| Artifact | Location | Naming convention |
| --- | --- | --- |
| Pre-merge report | `._design_docs/.test_reports/` | `pre-merge-report-YYYYMMDD-NN.md` |
| Pre-merge report review | `._design_docs/.test_reports/` | `pre-merge-report-YYYYMMDD-NN-architect-review.md` |
| Stage 11 test report | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN.md` |
| Stage 11 fixes handoff | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN-fixes.md` |
| Stage 11 Developer test-results review | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN-developer-review.md` |
| Stage 11 Architect test-results review | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN-architect-review.md` |
| ctest raw output | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/` | `ctest.log` |
| Coverage Cobertura XML | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/coverage/` | `coverage-merged.xml` |
| Coverage markdown summary | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/coverage/` | `coverage-report.md` |
| MTP probe artifacts | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/` | `mtp-probe-*.{log,err,metrics-after.txt,metrics-before.txt,completion-*.json,checkpoint-rows.txt}` |
| Merge log | `._design_docs/.test_reports/` | `merge-log-YYYYMMDD-NN.md` |
| Merge log review | `._design_docs/.test_reports/` | `merge-log-YYYYMMDD-NN-architect-review.md` |

### Required evidence per execution

The Stage 11 test report always contains:

- The ctest result with the per-test pass or fail table.
- The clean-build evidence line, naming the local build directory and
  the build target set used for the regression run.
- The OWASP table for the affected files, classified as mitigated,
  accepted with rationale, or not applicable. The Developer does not
  re-derive the OWASP review when the merge did not touch an OWASP
  surface.
- The Stage 4-9 regression rows.
- The T114 verdict citing the `## Combined result` block in
  `coverage-report.md`.
- The T114a verdict citing the `## Product-only result` block in
  `coverage-report.md`.
- The T115 verdict citing the per-file table in `coverage-report.md`.
- The T121 verdict citing the MTP probe
  `cache_checkpoint_admission_failures_total` row in the public
  /metrics output, when a hybrid-mode MTP or checkpoint-capable
  server is available on the host.

The test report opens a paired fixes report when any row is FAIL or
BLOCKED. The fixes report lives beside the test report and uses the
test plan paired-name convention.

### Pre-merge report format

The pre-merge report is a separate report owned by the Developer and
reviewed by the Architect. The design Part 2 prescribes the required
sections:

- Cover and metadata (upstream remote name, upstream ref, fork point
  SHA, integration branch name, dates, owner, reviewer)
- Commit range (range expression, total commit count, filtered
  commit count)
- Per-commit triage table (upstream SHA, subject, file-glob groups
  matched, affected prior-stage contracts, triage decision, one-line
  reason, follow-up owner)
- Aggregate summary (counts of NO-OP, INTEGRATE, REWORK-REQUIRED,
  DEFER, and REVERT decisions; affected prior stages with expected
  rework count; expected touched file list)
- Open questions (commits where the decision needs an Architect or
  Manager decision, contract gaps the analysis surfaced but did not
  close)

The Developer does not start the merge until the Architect records a
review verdict on the pre-merge report.

### Merge log format

The merge log is a separate report owned by the Developer and
reviewed by the Architect. The design Part 6 prescribes the required
sections:

- Cover and metadata (stage number, design baseline link, dates,
  owner, reviewer, approver, upstream remote name, upstream ref, fork
  point SHA, integration branch name, integration branch tip SHA)
- Decisions (per-commit final triage with reason; any change from
  the pre-merge report with date and agent)
- Deferred upstream commits (SHA, subject, affected contract,
  deferral reason, follow-up owner, lift condition)
- Known gaps (contract gaps the merge exposed but did not close via
  rework, with follow-up owner, target cycle, and contract link)
- Conflicts encountered (per conflict: upstream SHA, local path,
  local resolution, contract preserved; merge tool and policy)
- Reworks opened (per rework: affected stage, triggering change,
  rework part file link, status on date of last update)
- Regression evidence (test report link, ctest, coverage, and MTP
  probe artifacts; T114, T114a, T115, and T121 verdicts with cited
  artifact section for each)
- Closure status (architecture exit criteria met, exit criteria
  still open with Manager-assigned follow-up)

The merge log that is missing any required section fails the Architect
review.

## Citation rules

The Stage 11 test report cites:

- The `## Combined result` block in `coverage-report.md` for the T114
  verdict. The XML root attributes are not the verdict source.
- The `## Product-only result` block in `coverage-report.md` for the
  T114a verdict. The T114 block and the T114a block are separate
  sections in the same report.
- The per-file table in `coverage-report.md` for the T115 verdict.
  The T115 verdict checks that the table lists each hybrid-mode file
  exactly once, after lowercased full-path deduplication.
- The MTP probe `cache_checkpoint_admission_failures_total` row in
  the public /metrics output for the T121 verdict, when an MTP or
  checkpoint-capable server is exercised.
- The ctest log for the per-test pass or fail count for the
  Stage 1-9 regression rows.
- The merge log for the conflict list, the resolution list, the
  deferred upstream commits, and the known gaps.

A verdict that cites the wrong artifact is sent back to the Developer
for a rewrite. The Architect does not change a verdict to make the
citation match the result.

## Known risks

The risks below are inherited from design Part 6. The plan does not
add risks of its own; new risks identified during the merge activity
are recorded in the merge log, not in this plan.

| Risk | Impact | Mitigation before merge approval |
| --- | --- | --- |
| Upstream cache or checkpoint changes invalidate a prior-stage contract that the closed stages did not record. | The merge integrates a contract-breaking change without a rework. | The Architect's pre-merge review surfaces every contract gap the triage table lists. The Manager decides rework vs known gap. |
| An upstream change touches a hybrid-mode source file the closed stages did not test. | The regression rerun passes locally but the production path breaks. | The focused exporter coverage and the ctest rerun include the affected file. The T114 and T114a floors remain closure contracts. |
| An upstream change renames a public metric or a bounded diagnostic field. | Operator dashboards and log queries break. | The Architect records the upstream metric or field change in the pre-merge report with the proposed mapping. The Manager decides whether the rename is a rework, a known gap, or a silent integration with a documented mapping. |
| The merge tool produces a fast-forward even though INTEGRATE decisions require a merge commit. | The local adjustments are silently skipped. | The Developer does not allow a fast-forward when the pre-merge analysis lists at least one INTEGRATE or REWORK-REQUIRED decision. The merge log records the merge strategy actually used. |
| A reworked stage closes after the Stage 11 regression rerun. | The Stage 11 regression rerun is stale. | The Stage 11 regression rerun is rerun after every rework closes. The merge log records the date and the rerun count. |
| The pre-merge analysis is reopened after the merge has already started. | The merge log and the triage table are out of date. | The Developer stops the merge, reopens the pre-merge analysis, and the Architect re-reviews the report. The merge restarts only after the re-review verdict. |
| The T114 combined or T114a product-only coverage floor drops below the threshold after the merge. | The Stage 11 closure contract is unmet. | The Developer reopens the coverage evidence and records the drop in the merge log. The Manager decides whether the drop is a rework, a known gap, or a silent integration with a follow-up plan. |
| The `run_coverage.ps1` prerequisite is not in place when the regression runs. | The T114a verdict has no `## Product-only result` block to cite. | The prerequisite Developer gate runs before Step 1. The Developer confirms the block is in the report before the regression rerun starts. The placement rationale is in [part-04-prerequisites.md](part-04-prerequisites.md). |
| The fork point is changed silently between the pre-merge analysis and the merge. | The commit range and the triage table are out of date. | The Developer does not change the fork point. A change is recorded in the merge log and reopens the pre-merge analysis. |
| The Developer adds a public metric, a diagnostic field, or a CLI flag during the merge. | Operators read a new surface that the design did not approve. | The Developer stops and requests a Manager decision. The exclusion list in design Part 6 names the surfaces Stage 11 does not change. |

## Open decisions

The decisions below need Manager input. The Developer cannot make any
of them without a Manager record. The full decision text and the
recommended default for each is in
[part-03-known-decisions.md](part-03-known-decisions.md).

- Upstream fork point SHA confirmation before Step 1 starts.
- Rework-trigger threshold for a specific contract when the
  pre-merge analysis surfaces a borderline case.
- Acceptance of a known gap that the pre-merge analysis flags but
  the rework would scope-creep into a new stage.
- Approval of a documented mapping when an upstream metric or
  diagnostic field rename lands as a silent integration.
- Approval to extend the upstream commit range past the design Part
  1 rule when the Architect recommends it for a contract reason.

The Developer opens the merge activity with the assumption that the
upstream remote is `upstream`, the upstream branch is `master`, and
the local default branch is the integration branch, per the design
Part 1 upstream reference strategy. Any change to that assumption is
recorded in the merge log and reopens the pre-merge analysis.

## Handoff state

Implementation planning is drafted. The pre-merge report, the merge
execution, the rework Stage N work, the regression reruns, the merge
log, the test plan, the implementation review, the test report, and
the QA execution remain closed until the implementation-plan review
and the Manager implementation-plan gate both pass.
