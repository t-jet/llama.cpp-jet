# Stage 14 evidence plan and risks

Source: [../cache-handling-phase14-implementation.md](../cache-handling-phase14-implementation.md)

## Status

Planning date: 2026-06-11
Plan state: drafted.
Implementation state: not started.
QA execution state: not started.

## Test plan

The Stage 14 regression covers the prior-stage contracts
the merge touches. The Developer re-runs only the rows
whose prior-stage contract the merge changed. A
regression run that excludes such a row is a closure-
contract failure.

The regression scope follows design Part 5 "Regression
test reruns and evidence" and
[../upstream-merge-guide.md](../upstream-merge-guide.md)
Part 3 sections 1, 2, 5, and 9. The minimum scope applies
when the pre-merge analysis lists no REWORK-REQUIRED or
REVERT decisions. The expanded scope applies for each
closed rework.

### Minimum regression scope for a no-rework merge

| Test plan area | Prior-stage contract | Required evidence |
| --- | --- | --- |
| Stage 1-3 regression | Hybrid mode opt-in, legacy default, mode dispatch, non-destructive exact hits, usage tracking | ctest result for the focused cache test binaries used by the closed stages. Per-test pass or fail table. |
| Stage 4-6 regression | Byte-accounted LRU, protected roots, descriptor validation, paired atomicity, cold store integrity, root containment, async I/O | ctest result for the cache-policy, cache-store, and cache-controller test binaries. Structured-log check for the cold store error path. |
| Stage 7-8 regression | Branch forest, namespace validation, slot references, metadata-only nodes, re-materialization, mismatch handling, equivalent-branch deduplication, cold cleanup ownership | ctest result for the cache-graph and cache-io-worker test binaries. Focused-controller test result for mismatch and dedup paths. |
| Stage 9 regression | Checkpoint payload lifecycle, workload profile detection, checkpoint-first restore, exact-blob preference, prepared-prompt boundary placement | ctest result for the cache-controller test binaries. Model-backed or fixture-backed evidence only when the closed stages already required it. |
| Stage 10 regression | Public Prometheus metric set and label shape, bounded diagnostics, cold-store hardening, descriptor integrity, marker validation, OWASP mitigations, deterministic seams | ctest result for the Stage 10 test binaries. Public HTTP probe for the four `cache_checkpoint_*` rows when a hybrid-mode MTP or checkpoint-capable server is available on the host. |
| Stage 12 stress harness regression | Stress outputs S12-S01..S12-S08 and long-run S12-L01..S12-L03 | ctest preflight for the Stage 12 stress harness. The full stress rerun is the reworked evidence path, not the minimum scope. CUDA fallback behavior under stress is exercised by the Stage 12 harness (non-blocking observation N3). |
| Stage 12 benchmark harness regression | Benchmarks S12-B01..S12-B08 | ctest preflight for the Stage 12 benchmark harness. The full benchmark rerun is the reworked evidence path, not the minimum scope. |
| Stage 12 configuration matrix | The matrix dimensions in design Part 2 | Preflight shape check. The full matrix rerun is the reworked evidence path, not the minimum scope. |
| Stage 13 endpoint parity regression | Endpoint parity rows E13-01..E13-16, MTMD placeholder path, diagnostic-source namespace isolation, bounded `cache metadata:` format, transcript route coverage, embedding cache exclusion rationale | Stage 13 endpoint probe rerun for the affected parity rows. Public /metrics snapshot for the bounded diagnostic emission. |
| Coverage | T114 combined 80% floor and T114a product-only 70% floor | Focused exporter coverage run on the integration branch. Cite the `## Combined result` block for T114 and the `## Product-only result` block for T114a. |
| Per-file aggregation | T115 | Per-file table in `coverage-report.md` lists each hybrid-mode file exactly once, with deduplication by lowercased full path. |
| Public checkpoint admission | T121 | The four `cache_checkpoint_*` rows in the public /metrics output when a hybrid-mode MTP or checkpoint-capable server is exercised. |

The Developer does not invent new evidence formats that
the prior stages did not use. The Stage 14 evidence uses
the same artifact shape as the Stage 11 evidence, with
the citation rules below.

### Expanded scope for a reworked stage

When a rework closes, the regression scope for the
reworked stage follows the test plan parts the rework
part file lists. The rework part file may add a focused
test function, a focused exporter check, a public HTTP
probe, a stress harness row, a benchmark row, an endpoint
probe row, or a coverage row that did not exist before.
The expanded scope adds the rework-specific evidence on
top of the minimum scope for the reworked stage.

The T114 combined floor and the T114a product-only floor
remain closure contracts after the rework. The Stage 12
stress rerun and benchmark rerun are the reworked
evidence path; the full S12-S01..S12-S08, S12-L01..S12-L03,
and S12-B01..S12-B08 evidence is on disk before the
cycle closes. The Stage 13 endpoint probe rerun is the
reworked evidence path; the affected E13-01..E13-16 rows
are re-evidenced before the cycle closes.

The Developer does not start the Stage 14 regression
rerun until every open rework for the merge has closed.
A rework that is still open at the time of the Stage 14
regression is a blocker for the Stage 14 regression
rerun, not a known gap.

## Evidence plan

The Stage 14 evidence is a set of test reports, coverage
reports, stress reports, benchmark reports, endpoint probe
reports, pre-merge reports, and merge log entries. The
Developer opens a new artifact for each Stage 14
execution session.

### Artifact location and naming

| Artifact | Location | Naming convention |
| --- | --- | --- |
| Pre-merge report | `._design_docs/.test_reports/` | `pre-merge-report-YYYYMMDD-NN.md` |
| Pre-merge report review | `._design_docs/.test_reports/` | `pre-merge-report-YYYYMMDD-NN-architect-review.md` |
| Stage 14 test report | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN.md` |
| Stage 14 fixes handoff | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN-fixes.md` |
| Stage 14 Developer test-results review | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN-developer-review.md` |
| Stage 14 Architect test-results review | `._design_docs/.test_reports/` | `test-report-YYYYMMDD-NN-architect-review.md` |
| ctest raw output | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/` | `ctest.log` |
| Coverage Cobertura XML | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/coverage/` | `coverage-merged.xml` |
| Coverage markdown summary | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/coverage/` | `coverage-report.md` |
| MTP probe artifacts | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/` | `mtp-probe-*.{log,err,metrics-after.txt,metrics-before.txt,completion-*.json,checkpoint-rows.txt}` |
| Endpoint probe artifacts | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/` | `endpoint-probe-*` |
| Stress harness preflight | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/` | `stress-harness-preflight.*` |
| Benchmark harness preflight | `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/` | `benchmark-harness-preflight.*` |
| Merge log | `._design_docs/.test_reports/` | `merge-log-YYYYMMDD-NN.md` |
| Merge log review | `._design_docs/.test_reports/` | `merge-log-YYYYMMDD-NN-architect-review.md` |
| Per-rework part file | in affected stage's `cache-handling-phaseN-design/` directory | per stage's naming convention |
| Per-rework implementation plan | in affected stage's `cache-handling-phaseN-implementation/` directory | per stage's naming convention |
| Per-rework evidence | in affected stage's `cache-handling-phaseN-implementation/` directory | per stage's naming convention |

### Required evidence per execution

The Stage 14 test report always contains:

- The ctest result with the per-test pass or fail table.
- The clean-build evidence line, naming the local build
  directory and the build target set used for the
  regression run.
- The Stage 1-13 regression rows.
- The T114 verdict citing the `## Combined result` block
  in `coverage-report.md`.
- The T114a verdict citing the `## Product-only result`
  block in `coverage-report.md`.
- The T115 verdict citing the per-file table in
  `coverage-report.md`.
- The T121 verdict citing the MTP probe
  `cache_checkpoint_admission_failures_total` row in the
  public /metrics output, when a hybrid-mode MTP or
  checkpoint-capable server is available on the host.
- The E13-01..E13-16 endpoint parity verdicts citing the
  Stage 13 endpoint probe artifacts.
- The Stage 12 stress harness preflight verdict when the
  merge touched a stress-harness source file.
- The Stage 12 benchmark harness preflight verdict when
  the merge touched a benchmark source file.
- The Stage 13 bounded `cache metadata:` format check
  citing the diagnostic emission site when the merge
  touched a diagnostic surface.
- The Stage 13 MTMD placeholder path check when the
  merge touched an MTMD path.

The test report opens a paired fixes report when any row
is FAIL or BLOCKED. The fixes report lives beside the
test report and uses the test plan paired-name
convention.

### Pre-merge report format

The pre-merge report follows the seven required sections
from design Part 2 "Pre-merge analysis artifact format":
cover and metadata, upstream reference verification,
commit range, per-commit triage table, aggregate summary,
Manager decisions requested, and open questions. The
Developer opens the pre-merge report at Step 1 and the
Architect reviews it at Step 2.

### Merge log format

The merge log follows the nine required sections from
design Part 6 "Merge log format": cover and metadata,
upstream reference verification, decisions, deferred
upstream commits, known gaps, conflicts encountered,
reworks opened, regression evidence, and closure status.
The Developer opens the merge log at Step 3 and updates
it through Step 6. The Architect reviews the merge log at
Step 6.

## Citation rules

The Stage 14 test report cites:

- The `## Combined result` block in `coverage-report.md`
  for the T114 verdict. The XML root attributes are not
  the verdict source.
- The `## Product-only result` block in
  `coverage-report.md` for the T114a verdict. The T114
  block and the T114a block are separate sections in the
  same report.
- The per-file table in `coverage-report.md` for the
  T115 verdict. The T115 verdict checks that the table
  lists each hybrid-mode file exactly once, after
  lowercased full-path deduplication.
- The MTP probe `cache_checkpoint_admission_failures_total`
  row in the public /metrics output for the T121 verdict,
  when an MTP or checkpoint-capable server is exercised.
- The Stage 13 endpoint probe artifacts for the
  E13-01..E13-16 parity rows. A row that cites the wrong
  artifact is sent back to the Developer for a rewrite.
- The Stage 12 stress harness preflight artifacts for
  the S12-S01..S12-S08 and S12-L01..S12-L03 rows.
- The Stage 12 benchmark harness preflight artifacts for
  the S12-B01..S12-B08 rows.
- The ctest log for the per-test pass or fail count for
  the Stage 1-13 regression rows.
- The merge log for the conflict list, the resolution
  list, the deferred upstream commits, and the known
  gaps.

A verdict that cites the wrong artifact is sent back to
the Developer for a rewrite. The Architect does not
change a verdict to make the citation match the result.

A row that cites the XML root attributes for the
combined-rate verdict is a denial-of-service attack on
the test plan Part 13 citation rule. The XML root covers
all tracked files and is almost always lower than the
filtered-denominator rate. The Developer estimates the
true rate from the per-file table before deciding on a
bug-fix loop.

## Known risks

The risks below are inherited from design Part 6 and the
open Manager decisions in the entry doc. The plan does
not add risks of its own; new risks identified during the
merge activity are recorded in the merge log, not in
this plan.

| Risk | Impact | Required mitigation before merge approval |
| --- | --- | --- |
| Stale `origin/upstream_master` relative to actual upstream `master` | The cycle merges from a stale fork point. Last fetch 2026-06-04 per D1. The remote ref is the source of truth; no local `upstream_master` branch is required for Stage 14. | Per D1, the Developer verifies remote ref currency against the actual upstream `master` via `git ls-remote https://github.com/ggml-org/llama.cpp.git master` before the merge opens. A gap is a known gap recorded in the merge log. |
| Fork point SHA recovery | The merge base is unknown until Step 1 runs. | The Developer runs `git merge-base LOCAL origin/upstream_master` at Step 1. A fork point the Developer cannot recover is itself a known gap recorded in the pre-merge report "Open questions" section. |
| `test-stage10-policy-lru` pre-existing semantic bug is out of Stage 14 scope | The cycle may treat the test bug as a closure blocker. | The triage records the upstream commit as a DEFER or INTEGRATE with a one-line reason that references the tracked-separately record. The test bug is not a Stage 14 rework trigger (carry-forward Manager plan-change decision D2). |
| Synthetic Stage 12 V2/V3/non-MTP matrix expansion is paused | An upstream change resumes the expansion silently and the 2026-06-09 close-at-current-progress decision is reversed. | The triage records the upstream commit as a rework candidate for Stage 12. The cycle does not lift the pause; lifting requires a separate Manager decision (carry-forward Manager plan-change decision D3). |
| No `upstream` remote configured | The D1 carry-forward references "upstream remote" but the local `origin` is the jet fork, not the upstream `ggml-org/llama.cpp`. The cycle operates against `origin/upstream_master` directly per Path C. | The Developer records the actual `origin` URL and the actual upstream tip via `git ls-remote https://github.com/ggml-org/llama.cpp.git master` in the pre-merge report. The Manager confirms the jet-fork-vs-actual-upstream gap (open Manager decision D6). |
| Model fixtures unavailable for Stage 12 stress reruns (S01..S08 and L01..L03) | The stress harness preflight and the full stress rerun cannot run. | The Developer confirms the model fixture inventory per Stage 12 closure at Step 1. Missing fixtures are a known gap recorded in the pre-merge report and the merge log "Known gaps" section. The Manager decides whether the gap is a rework, a known gap, or a follow-up. |
| CUDA build unavailable for E13 endpoint probe | The endpoint parity rows that require CUDA cannot run. | The Developer confirms `build-cuda-stage13` is available at Step 1. A missing build is a known gap; rows that require CUDA are recorded as BLOCKED with the environment reason, not as FAIL. |
| Coverage toolchain (OpenCppCoverage) unavailable for T114 and T114a | The coverage evidence cannot run on the integration branch. | The Developer confirms OpenCppCoverage is on PATH at Step 1. A missing toolchain is a known gap; the cycle re-evidences T114 and T114a on the host with the toolchain. |
| k6 unavailable for stress regression | The k6 stress regression rerun cannot run. | The Developer confirms k6 is on PATH at Step 1. A missing tool is a known gap; the cycle re-evidences the stress regression with the available tool. |
| Worktree dirty at cycle open | The cycle opens with uncommitted edits the merge cannot distinguish from the cycle's own work. | The Developer confirms the working tree is clean at Step 1. Uncommitted edits are a blocker; the Developer stashes, commits, or discards them before the merge opens. The Manager decides per open Manager decision D5. |
| Upstream cache, checkpoint, or endpoint changes invalidate a prior-stage contract the closed stages did not record | The merge integrates a contract-breaking change without a rework. | The Architect pre-merge review surfaces every contract gap the triage table lists. The Manager decides rework vs known gap. The Stage 12 and Stage 13 post-closure contracts are part of the lens. |
| An upstream change touches a hybrid-mode source file the closed stages did not test | The regression rerun passes locally but the production path breaks. | The focused exporter coverage and the ctest rerun include the affected file. The T114 and T114a floors remain closure contracts. |
| An upstream change touches a Stage 13 endpoint adapter and breaks an E13-01..E13-16 parity row | Public endpoint parity evidence fails. | The Stage 13 endpoint probe rerun includes the affected row. The Developer records the failing row, the request payload, and the contract the row covers. |
| An upstream change renames a public metric, a bounded diagnostic field, the MTMD placeholder path, or the bounded `cache metadata:` format | Operator dashboards, log queries, and route adapters break. | The Architect records the upstream rename in the pre-merge report with the proposed mapping. The Manager decides whether the rename is a rework, a known gap, or a silent integration with a documented mapping. |
| The merge tool produces a fast-forward even though INTEGRATE decisions require a merge commit | The local adjustments are silently skipped. | The Developer does not allow a fast-forward when the pre-merge analysis lists at least one INTEGRATE or REWORK-REQUIRED decision. The merge log records the merge strategy actually used. |
| A reworked stage closes after the Stage 14 regression rerun | The Stage 14 regression rerun is stale. | The Stage 14 regression rerun is rerun after every rework closes. The merge log records the date and the rerun count. |
| The pre-merge analysis is reopened after the merge has already started | The merge log and the triage table are out of date. | The Developer stops the merge, reopens the pre-merge analysis, and the Architect re-reviews the report. The merge restarts only after the re-review verdict. |
| The T114 combined or T114a product-only coverage floor drops below the threshold after the merge | The Stage 14 closure contract is unmet. | The Developer reopens the coverage evidence and records the drop in the merge log. The Manager decides whether the drop is a rework, a known gap, or a silent integration with a follow-up plan. |

## Handoff state

Implementation planning is drafted. The pre-merge report,
the merge execution, the rework Stage N work, the
regression reruns, the merge log, the implementation
review, the test report, and the QA execution remain
closed until the implementation-plan review and the Manager
implementation-plan gate both pass.






