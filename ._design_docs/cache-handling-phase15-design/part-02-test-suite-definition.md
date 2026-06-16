# Stage 15 design: test suite definition -- Part 2

Source: [../cache-handling-phase15-design.md](../cache-handling-phase15-design.md)

## Test categories

The "full test suite" is the union of these categories. Each
category has a path, an invocation, and a per-row PASS criterion.
The union is the contract; no category is optional.

| ID | Category | Path | Invocation | PASS criterion |
| --- | --- | --- | --- | --- |
| C-ctest | ctest on the build tree | `build-cov` (Release) | `ctest --test-dir build-cov -C Release --output-on-failure` after the clean build | 0 FAIL, 0 unhandled exceptions; the pre-existing `test-stage10-policy-lru` semantic bug is recorded as `BLOCKED-pre-existing` and does not block Stage 15 closure. |
| C-pytest | in-scope pytest rows from the test plan | `._design_docs/cache-handling-test-scripts/` runner | `& ._design_docs/cache-handling-test-scripts/execute_tests.ps1 -BuildDir build-cov` | All C, H, N, B, D, R, M, F, S, and S80-S99 rows PASS, FAIL, SKIP, or BLOCKED per their per-row contract; no row returns 0 expected calls with non-zero unexpected calls. |
| C-public-http | Stage 13 public endpoint parity probe | `._design_docs/.test_reports/` evidence root | the Stage 13 endpoint probe with `--cache-mode hybrid` and `--cache-mode legacy` for each route family in the Stage 13 route inventory | E13-01..E13-16 PASS; the bounded `cache metadata:` line at task launch emits on degraded paths; transcription route coverage and embedding route exclusion rationale are recorded. |
| C-regression | Stage 4-9 regression rows | the test plan matrix rows R10..R23, R20..R23, and the H30..H74 closed-stage rows | the same runner invocation as C-pytest | Each row PASS, FAIL, SKIP, or BLOCKED per the per-row contract from the test plan Parts 1-12. |
| C-closure | Stage 10 closure contracts T114, T114a, T115, T121 | `._design_docs/cache-handling-test-scripts/run_coverage.ps1` and the public HTTP /metrics probe | `& ._design_docs/cache-handling-test-scripts/run_coverage.ps1 -BuildDir build-cov` then public HTTP `/metrics` on the MTP-capable row | T114 combined rate `>= 0.80`; T114a product-only rate `>= 0.70`; T115 per-file aggregation PASS; T121 four `cache_checkpoint_*` rows exposed through public `/metrics` on the MTP-capable fixture. |
| C-stress | Stage 12 stress rows S01..S08 | `._design_docs/cache-handling-test-scripts/stress/stress_s12_sXX_*.ps1` | per-row script with the Stage 12 configuration matrix | Each S01..S08 row PASS per [part-02 of Stage 12 design](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md); correctness checks pass even when throughput is unchanged; no crash, no deadlock, no corrupt restore. |
| C-longrun | Stage 12 long-run rows L01..L03 | `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_lXX_*.ps1` | per-row script with the durations from D2 | See part-3 of this design. L02 meets intent; L01 and L03 meet intent or end in `BLOCKED-time-budget` with the actual wall-clock recorded. |
| C-bench | Stage 12 benchmark rows B01..B08 | `._design_docs/cache-handling-test-scripts/bench/bench_s12_bXX_*.ps1` | per-row script with the Stage 12 benchmark configuration | Each B01..B08 row PASS per [part-03 of Stage 12 design](../cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md); legacy comparison row included; output feeds the benchmark report (part-5). |

## Invoked-from entry point

The QA owner starts from a single working directory on `work-branch`
and runs the categories in this order:

1. Clean build per the prerequisite (D-series assumes it).
2. ctest (C-ctest) to catch the unit-level regression first.
3. pytest runner (C-pytest) with the same `build-cov` tree.
4. Stage 13 public HTTP probe (C-public-http) on a freshly started
   hybrid-mode server.
5. Coverage run (C-closure) and the MTP-capable public /metrics
   probe (T121 row) on the same build.
6. Stress rows (C-stress) one after another, each on a fresh
   server process, to keep metrics isolated.
7. Long-run rows (C-longrun) on dedicated server processes; the
   6-hour L01 row runs to completion or cap.
8. Benchmark rows (C-bench) on fresh server processes per row.
9. Stage 4-9 regression (C-regression) at the end so a stress or
   benchmark run does not contaminate the regression sample.

The QA evidence is one test report per category, named per D5. The
benchmark report is the C-bench output plus the regression-detection
section from D4.

## Per-row verdict sources

The test plan's Parts 1-12 already define per-row evidence sources
(public HTTP, focused controller, stats-capable harness, focused
C++ test, or fault injection). Stage 15 re-uses those sources. The
QA classifies each row against its existing per-row contract, not
against a new contract.

For C-ctest, the source is the ctest log. For C-pytest, the source
is the runner log plus the per-row evidence summary under
`._design_docs/.test_reports/run-YYYYMMDD/`. For C-public-http, the
source is the Stage 13 evidence format. For C-closure, the source is
`coverage-report.md` plus the public /metrics snapshot. For
C-stress, C-longrun, and C-bench, the source is the per-row evidence
directory under D5.

## Counts and the summary line

The QA report records final counts at the end of each category:

- PASS, FAIL, SKIP, BLOCKED, product-bug count
- duration of each long-running row
- any cap-exit records from part-3

The combined stage 15 verdict at the end of the QA report uses the
same four labels: PASS, FAIL, BLOCKED, and product-bug count. The
combined verdict is the input to the bug-fix loop in part-4.

## What is not part of the full test suite

- Upstream `master` CI: not a closure contract on this fork.
- Third-party fuzzing or property-based tests not in the current
  test plan.
- The pre-existing `test-stage10-policy-lru` semantic bug: tracked
  separately, not a Stage 15 PASS blocker.
- Stage 12 V2/V3/non-MTP follow-up synthetic matrix expansion: out
  of scope; the 2026-06-09 close-at-current-progress decision is
  preserved.

## Handoff to the long-running tests and the bug-fix loop

The long-running rows C-longrun are detailed in part-3. The
bug-fix loop that operates on FAIL or product-bug rows from this
test suite is detailed in part-4.
