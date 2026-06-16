# Stage 15 implementation plan: ordered steps, owners, and gate sequencing

Source: [../cache-handling-phase15-implementation.md](../cache-handling-phase15-implementation.md)

## Plan owner

This plan is authored by the Developer. The Architect reviews the
plan in part-05 of this directory. The Manager records the
implementation-plan gate decision in the tracker row at
[cache-handling-stage-tracker.md](../cache-handling-stage-tracker.md)
line 42. The plan does not authorize code, tests, fixes, or PR text.

## Ordered steps

The plan follows the design's five-step procedure (test suite, long
running, bug-fix loop, benchmark, close) and expands it with concrete
commands, file paths, owners, deliverables, and exit conditions. Each
step has a gate.

### Step 1: clean build (gate: build PASS, binary timestamp recorded)

Owner: Developer (or QA if the Developer is not the build owner).

Commands:

```powershell
Remove-Item -Recurse -Force build-cov -ErrorAction SilentlyContinue
cmake -S . -B build-cov
cmake --build build-cov --config Release --target llama-server -j 4

$Binary = Get-Item build-cov\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

Deliverable: the binary timestamp and a single line `BUILD OK` written
to the implementation log. Exit condition: the build PASSES and the
binary is fresh within 10 minutes. No test execution starts before
this gate.

### Step 2: full test suite (gate: QA test report PASS or PASS-with-observations)

Owner: QA execution (per P2). The Developer supports the run as needed.

Execution order, per design part-02 "Invoked-from entry point":

1. ctest on `build-cov` (C-ctest).
2. pytest runner on the same build tree (C-pytest).
3. Stage 13 public HTTP probe on a freshly started hybrid-mode server
   (C-public-http).
4. Coverage run (C-closure) and the MTP-capable public `/metrics` probe
   (T121 row).
5. Stress rows (C-stress) one after another, each on a fresh server
   process.
6. Long-run rows (C-longrun) on dedicated server processes. The 6-hour
   L01 row runs to completion or cap-exit per design part-03.
7. Benchmark rows (C-bench) on fresh server processes per row.
8. Stage 4-9 regression (C-regression) at the end.

Concrete commands:

- C-ctest: `ctest --test-dir build-cov -C Release --output-on-failure`.
- C-pytest: `& ._design_docs/cache-handling-test-scripts/execute_tests.ps1 -BuildDir build-cov`.
- C-public-http: follow the Stage 13 evidence format from
  [cache-handling-test-plan/part-23](../cache-handling-test-plan/part-23-stage13-endpoint-compatibility.md).
  Use a fresh `test-report-YYYYMMDD-NN.md` per D5.
- C-closure: `& ._design_docs/cache-handling-test-scripts/run_coverage.ps1 -BuildDir build-cov`
  then public HTTP `/metrics` on the MTP-capable fixture.
- C-stress: per-row driver under
  `._design_docs/cache-handling-test-scripts/stress/stress_s12_sXX_*.ps1`.
- C-longrun: kickoff driver `kickoff-v2-stress-longrun.ps1` plus
  per-row driver under
  `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_lXX_*.ps1`.
  See [part-04](part-04-prerequisites-and-host-tooling.md) for the
  side log and cap-exit handling.
- C-bench: per-row driver under
  `._design_docs/cache-handling-test-scripts/bench/bench_s12_bXX_*.ps1`.
- C-regression: same runner invocation as C-pytest; the per-row table
  cites the test plan matrix rows R10..R23 and H30..H74.

Resolution of the N1 finding (C-regression row subrange typo
`R10..R23, R20..R23`): the canonical R-numbering comes from the test
plan matrix at
[cache-handling-test-plan/part-03](../cache-handling-test-plan/part-03-integration-test-matrix.md).
QA records the actual row IDs in the per-row evidence table and the
N1 finding is closed at execution when the QA table matches the test
plan matrix. If a row is missing from the matrix, QA records the gap
and the Developer decides whether to add the row or escalate.

Deliverable: one durable QA test report at
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` per D5 with
the eight-category verdict table. The longrun and stress sub-evidence
lives under `longrun-stage15-YYYYMMDD/` and `stress-stage15-YYYYMMDD/`.
The bench sub-evidence lives under `bench-stage15-YYYYMMDD/`. Exit
condition: the QA report records per-row verdicts and the combined
stage 15 verdict is `PASS`, `PASS-with-observations`, or the bug-fix
loop opens.

### Step 3: bug-fix loop (gate: zero product bugs and closure contracts met)

Owner per iteration (P2 and design part-04): Developer fix, Architect
review, QA rerun, Developer test-results review. Maximum 3 iterations
per bug per D3. Escalation path: if a bug cannot be fixed within 3
iterations, the Developer escalates to the Manager with a clear
plan-change decision.

Per-iteration sequence:

1. Developer reads the QA report, identifies the symptom and the
   affected code path, writes a focused fix in a single commit, and
   records the change in `test-report-YYYYMMDD-NN-fixes.md` per D5.
2. Architect reviews the fix against the approved design and the
   affected prior-stage contract. Verdict is `PASS`,
   `PASS-with-observations`, or `REWORK`.
3. QA reruns the affected rows only (not the full test suite) in a
   fresh sub-session. The QA report is a new file with the same D5
   naming pattern.
4. Developer reviews the QA rerun, classifies the row, and records the
   verdict in `test-report-YYYYMMDD-NN-developer-review.md`.

Termination:

- A. The QA report shows zero product bugs and every closure contract
  row is `PASS` or `PASS-meets-intent`.
- B. Iteration count reaches 3. Developer escalates to Manager.
- C. A bug cannot be fixed without a prior-stage design change.
  Developer opens a rework part file in the affected stage's design
  tree.

Regression evidence per iteration: a `test-report-YYYYMMDD-NN-fixes.md`
with the change scope, diff summary, affected rows, build evidence,
affected prior-stage contract, and regression evidence. The Architect
verdict and the QA rerun are paired with the fixes file.

Deliverable: zero open product bugs on the closure checklist, or a
plan-change decision recorded by the Manager. Exit condition: combined
stage 15 verdict is `PASS` or `PASS-with-observations`, and closure
contracts T114, T114a, T115, T121, E13-01..E13-16, S01..S08, L01..L03,
and B01..B08 are all `PASS` or `PASS-meets-intent`.

### Step 4: benchmark report (gate: report filed at the D4 path)

Owner: QA execution. The Developer supports the rerun if the bug-fix
loop changes a benchmark row.

Required content per design part-05:

- Header: date, owner, scope (Stage 15 B01..B08 re-run), evidence root
  path, baseline report path
  (`._design_docs/.test_reports/test-report-20260609-02-V2-bench.md`).
- Build evidence: clean build, binary timestamp, binary path.
- Per-row table in the same shape as the V2 bench report.
- Per-metric comparison: B01..B08 with V2 baseline, Stage 15 number,
  delta, and regression classification.
- Legacy comparison row per benchmark family.
- Regression-detection section: classification per the Stage 12 design
  part-03 set.
- Summary: PASS, FAIL, BLOCKED counts and cap-exit references.
- Handoff: next owner (Manager for closure).

File path: `._design_docs/.test_reports/stage15-benchmark-20260612-01.md`
per D4. Evidence root: `._design_docs/.test_reports/bench-stage15-YYYYMMDD/`.

The benchmark report is durable. The Manager references it from the
closure entry in the implementation log. The document index gains a
row in the "Cache implementation, verification, and tests" section.

If the benchmark surfaces a `PRODUCT-BUG` or `LEGACY-REGRESSION`
classification, the row opens a bug-fix loop iteration per Step 3.
The benchmark report is re-issued with the post-fix numbers after the
loop closes the bug or escalates.

Deliverable: the benchmark report file plus the per-row evidence
directory. Exit condition: the report cites the V2 baseline, the
per-row verdict, the per-metric comparison, the regression
classification, and the handoff section.

### Step 5: closure (gate: Manager closure decision)

Owner: Manager. The Developer and QA provide handoff context.

The Manager reads the QA test report, the bug-fix loop evidence (if
any), the benchmark report, and the closure-contract rows from
[part-07 of the design](../cache-handling-phase15-design/part-07-exclusions-traceability-and-handoff.md).
The Manager records the stage 15 closure decision in the
implementation log and updates the tracker row at
[cache-handling-stage-tracker.md](../cache-handling-stage-tracker.md)
line 42 to a closed status with the closure date.

Closing with known bugs in scope is forbidden. The
`do not close stage with unmet or BLOCKED requirements` rule in the
manager improvement memory applies. A Manager plan-change decision is
required to close with an open item, and the decision is recorded in
the test plan or in the Manager's status, not in a reclassification of
the bug-fix loop output.

Deliverable: the implementation log status update, the tracker row
update, and the document index update for the implementation log and
the benchmark report. Exit condition: stage 15 is closed in the
tracker and a new operational stage is not pending unless the user
requests one.

## Gate sequencing summary

| Gate | Status | Owner |
| --- | --- | --- |
| Implementation planning | IN PROGRESS, 2026-06-12 | Developer |
| Architect implementation plan review | NOT STARTED | Architect (part-05) |
| Manager implementation plan gate | NOT STARTED | Manager |
| Clean build (Step 1) | NOT STARTED | Developer / QA |
| Full test suite (Step 2) | NOT STARTED | QA |
| Bug-fix loop (Step 3) | NOT STARTED | Developer / Architect / QA |
| Benchmark report (Step 4) | NOT STARTED | QA |
| Closure (Step 5) | NOT STARTED | Manager |

## Handoff to execution

The plan does not authorize code, tests, fixes, commits, PR text, or
reviewer responses. The next gate after Manager plan-gate PASS is the
clean build (Step 1). The Developer starts the build only after the
Manager records the plan-gate decision. Test execution, bug-fix work,
and the benchmark report remain unauthorized until the Manager
records the plan-gate decision.
