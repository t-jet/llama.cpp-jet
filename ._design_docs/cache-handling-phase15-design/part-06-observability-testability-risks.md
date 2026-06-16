# Stage 15 design: observability, testability, and risks -- Part 6

Source: [../cache-handling-phase15-design.md](../cache-handling-phase15-design.md)

## Observability

Stage 15 re-uses the public Prometheus metric set and bounded
diagnostics from Stage 10. No new metric, label, or diagnostic
is added. The QA rows cite the public /metrics endpoint, not
internal controller stats. The metric shape is the
post-S10-IMPL-01 shape from the Stage 10 implementation log.

Required metric and diagnostic families per category:

- ctest, pytest, regression: the same /metrics rows the prior
  test reports cited; the QA records the metric name and the
  value in the per-row evidence summary.
- public HTTP: the Stage 13 endpoint probe records the bounded
  `cache metadata:` line on degraded paths in the same format
  Stage 13 fixed: `{source, method, degraded, tokens,
  boundaries}`.
- closure contracts: T121 cites the four
  `cache_checkpoint_*` rows on the MTP-capable fixture. The
  QA records the row name, the labels, and the value.
- stress, long-run, bench: the per-row evidence summary cites
  the public metric set, the resource samples (working set,
  handle count, disk I/O), and the bounded diagnostic for any
  failure path. The Stage 12 design Part 4 metric families are
  the source list.

## Testability

Stage 15 does not add new test seams, harnesses, or fixtures.
The QA owner runs the existing harnesses. Where a row needs
focused controller, stats-capable harness, focused C++ test, or
fault-injection evidence, the QA cites the existing harness
name and the per-row contract from the test plan.

The pytest runner under
`._design_docs/cache-handling-test-scripts/execute_tests.ps1`
already records stdout, stderr, process exit codes, and a
report file. The QA uses the same runner for C-pytest. The
ctest invocation uses the standard ctest output. The
coverage run uses
`._design_docs/cache-handling-test-scripts/run_coverage.ps1`.
The stress, long-run, and bench scripts under
`._design_docs/cache-handling-test-scripts/{stress,longrun,bench}/`
are the per-row drivers.

The QA evidence is reproducible from the recorded command line,
the recorded configuration matrix values, the recorded fixture
identity, and the recorded binary timestamp. A reader can rerun
the same row and compare counters.

## Risk table

| Risk | Trigger | Impact | Mitigation |
| --- | --- | --- | --- |
| Long-running row cannot complete 6h on the local host | Host reboot, fixture fallback, or operator stop before the 6h cap | L01 row ends in `BLOCKED-time-budget`; the closure contract still records the partial state and the counter shape | Per-row cap-exit record per part-3; the QA reports the actual wall-clock and the reason; the closure decision is the Manager's, not the QA's |
| Fixture becomes unavailable mid-run | The local model fixture inventory changes between categories | The affected row ends in `BLOCKED-fixture`; the V2 bench precedent allows this for B02 | The QA records the missing fixture and the affected row; the Manager may narrow the matrix before the closure decision |
| Coverage tool fails on the current build | OpenCppCoverage or its dependencies break between sessions | T114 and T114a end in `BLOCKED-tooling` instead of `PASS` | The QA cites the failure mode and the tool version; the Manager decides whether to retry, switch tools, or record a plan-change |
| Pre-existing test bug becomes a hard fail | `test-stage10-policy-lru` flips from `BLOCKED-pre-existing` to a hard crash that blocks ctest | The ctest category ends with one extra FAIL | The QA records the bug as `BLOCKED-pre-existing` per the prior decisions; the ctest category is not blocked by it; the bug stays out of Stage 15 scope |
| Bug-fix loop exhausts the 3-iteration cap | A bug cannot be fixed without a prior-stage design change | The Developer escalates to the Manager with a plan-change decision | Per part-4; the loop does not close with known bugs; the Manager records the decision in the test plan or in the Manager's status |
| Benchmark regression masks a real product bug | A `TUNING-GAP` classification hides a `PRODUCT-BUG` symptom | The closure decision accepts a metric the design treats as a blocking defect | The regression classification is reviewed by the Architect in the benchmark report; a `TUNING-GAP` that hides a correctness symptom is reclassified |
| Synthetic matrix expansion resumes | A new request to add V3 or non-MTP rows re-opens the Stage 12 follow-up | The wall-clock budget explodes; the closure decision slips | The 2026-06-09 close-at-current-progress decision is preserved in the non-goals; the Manager narrows the matrix before the closure decision if the user re-opens the matrix |
| Public endpoint parity row flips FAIL | A route family changes shape or the bounded diagnostic emission site moves | The closure contract row E13-01..E13-16 fails | The QA cites the route family and the failure; the Developer opens a bug-fix iteration; the closure decision waits for the rerun |

## Excluded risk categories

- Host-level security or network exposure from running the
  server in `--cache-mode hybrid` for 6 hours. The Stage 12
  design Part 4 already covers the OWASP review scope and the
  cold-store root containment rule. Stage 15 does not
  re-examine the threat model.
- Long-term storage growth in the cold store. The Stage 6
  design and the Stage 12 stress row S06 already cover cold
  queue pressure and orphan growth. Stage 15 re-runs them, not
  redesign them.
- Upstream-merge risk. Stage 14 is closed. Stage 15 does not
  re-merge upstream.
