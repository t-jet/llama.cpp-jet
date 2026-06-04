# Stage 11 design: regression test reruns and evidence -- Part 5

Source: [../cache-handling-phase11-design.md](../cache-handling-phase11-design.md)

## Goal

The regression test reruns are the evidence that the prior-stage
contracts in Part 1 still hold on the integrated tree. This part
records the minimum regression scope, the expanded scope when a stage
is reworked, and the evidence format the Developer produces.

## Minimum regression scope for a no-rework merge

When the pre-merge analysis lists no REWORK-REQUIRED or REVERT
decisions, the regression scope is the set of test plan parts that
cover the prior-stage contracts in Part 1. The Developer re-runs the
full regression only on the test plan parts whose prior-stage contract
touched a path the merge changed. The merge log records the path list
and the matching test plan parts.

The minimum regression scope covers:

| Test plan area | Prior-stage contract | Required evidence |
| --- | --- | --- |
| Stage 1-3 regression | Hybrid mode opt-in, legacy default, mode dispatch, non-destructive exact hits, usage tracking | ctest result for the focused cache test binaries that the closed stages used; per-test pass or fail table. |
| Stage 4-6 regression | Byte-accounted LRU, protected roots, descriptor validation, paired atomicity, cold store integrity, root containment, async I/O | ctest result for the cache-policy, cache-store, and cache-controller test binaries; structured-log check for the cold store error path. |
| Stage 7-8 regression | Branch forest, namespace validation, slot references, metadata-only nodes, re-materialization, mismatch handling, equivalent-branch deduplication, cold cleanup ownership | ctest result for the cache-graph and cache-io-worker test binaries; focused-controller test result for mismatch and dedup paths. |
| Stage 9 regression | Checkpoint payload lifecycle, workload profile detection, checkpoint-first restore, exact-blob preference, prepared-prompt boundary placement | ctest result for the cache-controller test binaries; model-backed or fixture-backed evidence only when the closed stages already required it. |
| Stage 10 regression | Public Prometheus metric set and label shape, bounded diagnostics, cold-store hardening, descriptor integrity, marker validation, OWASP mitigations, deterministic seams | ctest result for the Stage 10 test binaries; public HTTP probe for the four `cache_checkpoint_*` rows when a hybrid-mode MTP or checkpoint-capable server is available on the host. |
| Coverage | T114 combined 80% floor and T114a product-only 70% floor | Focused exporter coverage run on the integration branch, citing the `## Combined result` block for T114 and the `## Product-only result` block for T114a per the test plan Part 13 citation rules. |
| Per-file aggregation | T115 | Per-file table in `coverage-report.md` lists each hybrid-mode file exactly once, with deduplication by lowercased full path. |

The Developer re-runs only the rows above that the merge touched. A
regression run that excludes a row whose prior-stage contract the
merge touched is a closure-contract failure, not a rework candidate.

## Expanded scope for a reworked stage

When a rework closes, the regression scope for the reworked stage
follows the test plan parts the rework part file lists. The rework
part file may add a focused test function, a focused exporter check, a
public HTTP probe, or a coverage row that did not exist before. The
rework part file records the added evidence.

The expanded scope is:

1. The full minimum regression scope for the reworked stage.
2. The added evidence the rework part file records.
3. The focused exporter coverage run for any hybrid-mode source file
   the rework changed. The T114 combined floor and the T114a
   product-only floor remain closure contracts after the rework.
4. The structured-log check for any diagnostic field the rework added
   or renamed.
5. The public HTTP probe for any metric the rework added, removed, or
   renamed. The probe must run against a hybrid-mode server that
   exercises the affected code path.

The Developer does not start the Stage 11 regression rerun until every
open rework for the merge has closed. A rework that is still open at
the time of the Stage 11 regression is a blocker for the Stage 11
regression rerun, not a known gap.

## Evidence format

The regression evidence is a set of test reports, coverage reports,
and merge log entries. The exact report file name follows the test
plan convention: `test-report-YYYYMMDD-NN.md`. The Developer opens a
new report for each Stage 11 execution.

### Required evidence per execution

| Artifact | Purpose | Required when |
| --- | --- | --- |
| `test-report-YYYYMMDD-NN.md` | Stage 11 regression test report. Records the ctest result, the public HTTP probe, the focused exporter coverage, the OWASP table, and the prior-stage regression. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/ctest.log` | Raw ctest output for the regression run. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/coverage/coverage-merged.xml` | Raw Cobertura XML from the focused exporter coverage run. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/coverage/coverage-report.md` | Markdown summary of the focused exporter coverage run. Must contain the per-file table, the `## Combined result` block, and the `## Product-only result` block. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/mtp-probe-*.{log,err,metrics-after.txt,metrics-before.txt,completion-*.json,checkpoint-rows.txt}` | Public HTTP probe artifacts for the T121 checkpoint admission row. | Only when a hybrid-mode MTP or checkpoint-capable server is available on the host. |
| Clean-build evidence | A line in the test report showing the local build directory and the build target set used for the regression run. | Always. |
| `test-report-YYYYMMDD-NN-fixes.md` | The Stage 11 handoff from QA when the regression surfaces a FAIL or BLOCKED row. | Only when the regression surfaces a FAIL or BLOCKED row. |
| `test-report-YYYYMMDD-NN-developer-review.md` | The Stage 11 test-results review from the Developer when the test report has a non-trivial verdict. | Only when the Developer classifies any row as FAIL, BLOCKED, or reclassification candidate. |
| `test-report-YYYYMMDD-NN-architect-review.md` | The Stage 11 Architect review of the test report and the test-results review. | Only when the Architect review is required by the test-results verdict. |

The Developer does not invent new evidence formats that the closed
stages did not use. The Stage 11 evidence uses the same artifact shape
as the Stage 10 evidence, with the test plan Part 13 citation rules
for the coverage report.

## Evidence citation rules

The Stage 11 test report cites:

- The `## Combined result` block in `coverage-report.md` for the T114
  verdict. The XML root attributes are not the verdict source.
- The `## Product-only result` block in `coverage-report.md` for the
  T114a verdict. The T114 block and the T114a block are separate
  sections in the same report.
- The per-file table in `coverage-report.md` for the T115 verdict.
  The T115 verdict checks that the table lists each hybrid-mode file
  exactly once, after lowercased full-path deduplication.
- The MTP probe `cache_checkpoint_admission_failures_total` row in the
  public /metrics output for the T121 verdict, when an MTP or
  checkpoint-capable server is exercised.
- The ctest log for the per-test pass or fail count for the
  Stage 1-9 regression rows.
- The merge log for the conflict list, the resolution list, the
  deferred upstream commits, and the known gaps.

A verdict that cites the wrong artifact is sent back to the Developer
for a rewrite. The Architect does not change a verdict to make the
citation match the result.
