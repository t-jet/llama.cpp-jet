# Stage 14 design: regression test reruns and evidence -- Part 5

Source: [../cache-handling-phase14-design.md](../cache-handling-phase14-design.md)

## Goal

The regression test reruns are the evidence that the prior-stage
contracts in Part 1 still hold on the integrated tree. This part
records the minimum regression scope, the expanded scope when a
stage is reworked, and the evidence format the Developer
produces.

## Minimum regression scope for a no-rework merge

When the pre-merge analysis lists no REWORK-REQUIRED or REVERT
decisions, the regression scope is the set of test plan parts
that cover the prior-stage contracts in Part 1. The Developer
re-runs the full regression only on the test plan parts whose
prior-stage contract touched a path the merge changed. The merge
log records the path list and the matching test plan parts.

The minimum regression scope covers:

| Test plan area | Prior-stage contract | Required evidence |
| --- | --- | --- |
| Stage 1-3 regression | Hybrid mode opt-in, legacy default, mode dispatch, non-destructive exact hits, usage tracking | ctest result for the focused cache test binaries that the closed stages used; per-test pass or fail table. |
| Stage 4-6 regression | Byte-accounted LRU, protected roots, descriptor validation, paired atomicity, cold store integrity, root containment, async I/O | ctest result for the cache-policy, cache-store, and cache-controller test binaries; structured-log check for the cold store error path. |
| Stage 7-8 regression | Branch forest, namespace validation, slot references, metadata-only nodes, re-materialization, mismatch handling, equivalent-branch deduplication, cold cleanup ownership | ctest result for the cache-graph and cache-io-worker test binaries; focused-controller test result for mismatch and dedup paths. |
| Stage 9 regression | Checkpoint payload lifecycle, workload profile detection, checkpoint-first restore, exact-blob preference, prepared-prompt boundary placement | ctest result for the cache-controller test binaries; model-backed or fixture-backed evidence only when the closed stages already required it. |
| Stage 10 regression | Public Prometheus metric set and label shape, bounded diagnostics, cold-store hardening, descriptor integrity, marker validation, OWASP mitigations, deterministic seams | ctest result for the Stage 10 test binaries; public HTTP probe for the four `cache_checkpoint_*` rows when a hybrid-mode MTP or checkpoint-capable server is available on the host. |
| Stage 12 stress harness regression | Stress outputs S12-S01..S12-S08 and long-run S12-L01..S12-L03 | ctest preflight for the Stage 12 stress harness; the full stress rerun is the reworked evidence path, not the minimum scope. |
| Stage 12 benchmark harness regression | Benchmarks S12-B01..S12-B08 | ctest preflight for the Stage 12 benchmark harness; the full benchmark rerun is the reworked evidence path, not the minimum scope. |
| Stage 12 configuration matrix | The matrix dimensions in Part 2 | Preflight shape check; the full matrix rerun is the reworked evidence path, not the minimum scope. |
| Stage 13 endpoint parity regression | Endpoint parity rows E13-01..E13-16, MTMD placeholder path, diagnostic-source namespace isolation, bounded `cache metadata:` format, transcript route coverage, embedding cache exclusion rationale | Stage 13 endpoint probe rerun for the affected parity rows; public /metrics snapshot for the bounded diagnostic emission. |
| Coverage | T114 combined 80% floor and T114a product-only 70% floor | Focused exporter coverage run on the integration branch, citing the `## Combined result` block for T114 and the `## Product-only result` block for T114a per the test plan Part 13 citation rules. |
| Per-file aggregation | T115 | Per-file table in `coverage-report.md` lists each hybrid-mode file exactly once, with deduplication by lowercased full path. |

The Developer re-runs only the rows above that the merge
touched. A regression run that excludes a row whose prior-stage
contract the merge touched is a closure-contract failure, not a
rework candidate.

The Stage 12 stress harness and benchmark harness rows are new
in Stage 14. They are minimum-scope preflight checks when the
merge did not touch a stress or benchmark source file, and they
expand to the full reworked evidence path when a REWORK-REQUIRED
or INTEGRATE decision touched the corresponding source file.

The Stage 13 endpoint parity row is new in Stage 14. It is the
minimum-scope rerun for the E13-01..E13-16 parity rows, the
MTMD placeholder path, the diagnostic-source namespace isolation
rule, the bounded `cache metadata:` format at task launch, the
transcript route coverage, and the embedding cache exclusion
rationale. A regression run that excludes any of these rows
when the merge touched the corresponding adapter is a
closure-contract failure, not a rework candidate.

## Expanded scope for a reworked stage

When a rework closes, the regression scope for the reworked
stage follows the test plan parts the rework part file lists.
The rework part file may add a focused test function, a focused
exporter check, a public HTTP probe, a stress harness row, a
benchmark row, an endpoint probe row, or a coverage row that
did not exist before. The rework part file records the added
evidence.

The expanded scope is:

1. The full minimum regression scope for the reworked stage.
2. The added evidence the rework part file records.
3. The focused exporter coverage run for any hybrid-mode source
   file the rework changed. The T114 combined floor and the
   T114a product-only floor remain closure contracts after the
   rework.
4. The structured-log check for any diagnostic field the rework
   added or renamed. The bounded `cache metadata:` format at
   task launch is part of this check; a rework that touches the
   format must re-emit the field in the same
   `{source, method, degraded, tokens, boundaries}` shape.
5. The public HTTP probe for any metric the rework added,
   removed, or renamed. The probe must run against a
   hybrid-mode server that exercises the affected code path.
6. The Stage 12 stress harness rerun for any reworked stage
   whose contract the stress harness exercises. The stress
   rerun is the reworked evidence path; the full
   S12-S01..S12-S08 and S12-L01..S12-L03 evidence is on disk
   before the cycle closes.
7. The Stage 12 benchmark harness rerun for any reworked stage
   whose contract the benchmark harness exercises. The
   benchmark rerun is the reworked evidence path; the full
   S12-B01..S12-B08 evidence is on disk before the cycle
   closes.
8. The Stage 13 endpoint probe rerun for any reworked stage
   whose contract the endpoint adapter exercises. The endpoint
   probe rerun is the reworked evidence path; the affected
   E13-01..E13-16 rows are re-evidenced before the cycle
   closes.

The Developer does not start the Stage 14 regression rerun
until every open rework for the merge has closed. A rework that
is still open at the time of the Stage 14 regression is a
blocker for the Stage 14 regression rerun, not a known gap.

## Evidence format

The regression evidence is a set of test reports, coverage
reports, stress reports, benchmark reports, endpoint probe
reports, and merge log entries. The exact report file name
follows the test plan convention:
`test-report-YYYYMMDD-NN.md`. The Developer opens a new report
for each Stage 14 execution.

### Required evidence per execution

| Artifact | Purpose | Required when |
| --- | --- | --- |
| `test-report-YYYYMMDD-NN.md` | Stage 14 regression test report. Records the ctest result, the public HTTP probe, the focused exporter coverage, the Stage 13 endpoint probe, and the prior-stage regression. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/ctest.log` | Raw ctest output for the regression run. | Always. |
| `test-report-YYYYMMDD-NN-artifacts/coverage/coverage-merged.xml` | Raw Cobertura XML from the focused exporter coverage run. | Always, when the cycle touched a feature-mode source file. |
| `test-report-YYYYMMDD-NN-artifacts/coverage/coverage-report.md` | Markdown summary of the focused exporter coverage run. Must contain the per-file table, the `## Combined result` block, and the `## Product-only result` block. | Always, when the cycle touched a feature-mode source file. |
| `test-report-YYYYMMDD-NN-artifacts/mtp-probe-*` | Public HTTP probe artifacts for the T121 checkpoint admission row. | Only when a hybrid-mode MTP or checkpoint-capable server is available on the host. |
| `test-report-YYYYMMDD-NN-artifacts/endpoint-probe-*` | Stage 13 endpoint probe artifacts for the affected E13-01..E13-16 rows. | Always, when the cycle touched an endpoint adapter source file. |
| `test-report-YYYYMMDD-NN-artifacts/stress-harness-preflight.*` | Stage 12 stress harness preflight artifacts. | Always, when the cycle touched a stress harness source file. |
| `test-report-YYYYMMDD-NN-artifacts/benchmark-harness-preflight.*` | Stage 12 benchmark harness preflight artifacts. | Always, when the cycle touched a benchmark harness source file. |
| Clean-build evidence | A line in the test report showing the local build directory and the build target set used for the regression run. | Always. |
| `test-report-YYYYMMDD-NN-fixes.md` | The Stage 14 handoff from QA when the regression surfaces a FAIL or BLOCKED row. | Only when the regression surfaces a FAIL or BLOCKED row. |
| `test-report-YYYYMMDD-NN-developer-review.md` | The Stage 14 test-results review from the Developer when the test report has a non-trivial verdict. | Only when the Developer classifies any row as FAIL, BLOCKED, or reclassification candidate. |
| `test-report-YYYYMMDD-NN-architect-review.md` | The Stage 14 Architect review of the test report and the test-results review. | Only when the Architect review is required by the test-results verdict. |

The Developer does not invent new evidence formats that the
prior stages did not use. The Stage 14 evidence uses the same
artifact shape as the Stage 11 evidence, with the citation
rules below.

## Evidence citation rules

The Stage 14 test report cites:

- The `## Combined result` block in `coverage-report.md` for the
  T114 verdict. The XML root attributes are not the verdict
  source.
- The `## Product-only result` block in `coverage-report.md` for
  the T114a verdict. The T114 block and the T114a block are
  separate sections in the same report.
- The per-file table in `coverage-report.md` for the T115
  verdict. The T115 verdict checks that the table lists each
  hybrid-mode file exactly once, after lowercased full-path
  deduplication.
- The MTP probe `cache_checkpoint_admission_failures_total` row
  in the public /metrics output for the T121 verdict, when an
  MTP or checkpoint-capable server is exercised.
- The Stage 13 endpoint probe artifacts for the E13-01..E13-16
  parity rows. A row that cites the wrong artifact is sent back
  to the Developer for a rewrite.
- The ctest log for the per-test pass or fail count for the
  Stage 1-13 regression rows.
- The merge log for the conflict list, the resolution list, the
  deferred upstream commits, and the known gaps.

A verdict that cites the wrong artifact is sent back to the
Developer for a rewrite. The Architect does not change a verdict
to make the citation match the result.

A row that cites the XML root attributes for the combined-rate
verdict is a denial-of-service attack on the test plan Part 13
citation rule. The XML root covers all tracked files and is
almost always lower than the filtered-denominator rate. The
Developer estimates the true rate from the per-file table before
deciding on a bug-fix loop.
