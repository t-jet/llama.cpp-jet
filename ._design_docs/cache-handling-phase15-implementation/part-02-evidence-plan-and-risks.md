# Stage 15 implementation plan: evidence plan and risk table

Source: [../cache-handling-phase15-implementation.md](../cache-handling-phase15-implementation.md)

## Per-category evidence capture

Each test category has a file path, a format, and required content.
The QA owner records the evidence in the named path and references it
from the QA test report. Non-durable artifacts go to `._test_output/`
per the test plan folder convention; durable markdown reports go to
`._design_docs/.test_reports/`.

### C-ctest

- File path: `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
  under heading "C-ctest".
- Format: ctest log captured with `2>&1 | Tee-Object -FilePath
  ._test_output/ctest-YYYYMMDD-NN.log`.
- Required content: ctest invocation, exit code, full PASS/FAIL/SKIP
  list, the per-test `output-on-failure` excerpt for any FAIL, and the
  `BLOCKED-pre-existing` annotation for `test-stage10-policy-lru`.
- Source: ctest log.

### C-pytest

- File path: `._design_docs/.test_reports/run-YYYYMMDD-NN/` for the
  per-row evidence summary plus the QA test report
  `test-report-YYYYMMDD-NN.md` for the verdict table.
- Format: PowerShell runner log under
  `._test_output/pytest-YYYYMMDD-NN.log` plus per-row evidence
  directory.
- Required content: per-row `PASS`, `FAIL`, `SKIP`, `BLOCKED` count,
  the per-row evidence summary, and the bounded log excerpt for any
  row that records a closure-contract value.
- Source: runner log plus per-row evidence summary.

### C-public-http

- File path: `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
  under heading "C-public-http" plus per-route evidence under
  `._test_output/stage13-routes-YYYYMMDD/`.
- Format: Stage 13 evidence format from
  [cache-handling-test-plan/part-23](../cache-handling-test-plan/part-23-stage13-endpoint-compatibility.md).
- Required content: E13-01..E13-16 verdicts, the bounded
  `cache metadata:` line at task launch on degraded paths, transcript
  route coverage, embedding cache exclusion rationale, and the leak
  scan result.
- Source: Stage 13 evidence format.

### C-closure

- File path: `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
  under heading "C-closure" plus
  `._design_docs/.test_reports/coverage-run-YYYYMMDD/coverage-report.md`.
- Format: OpenCppCoverage union report and the public HTTP /metrics
  snapshot.
- Required content: T114 combined rate, T114a product-only rate, T115
  per-file aggregation table (dedup by lowercased full path), T121
  four `cache_checkpoint_*` rows on the MTP-capable fixture.
- Source: coverage report plus /metrics snapshot.

### C-stress

- File path: `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
  under heading "C-stress" plus per-row evidence directory under
  `._design_docs/.test_reports/stress-stage15-YYYYMMDD/S12-S0X/<subrun>/`.
- Format: per-row evidence format from the Stage 12 implementation log
  part-01 (server.out.log, server.err.log, metrics snapshots, resource
  samples, evidence-summary.md).
- Required content: per-row S01..S08 verdict, request count, request
  mix, concurrency, seed, metrics snapshots before/after warmup and
  load, resource samples, and bounded log excerpt.
- Source: per-row evidence directory plus QA test report.

### C-longrun

- File path: `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
  under heading "C-longrun" plus per-row evidence directory under
  `._design_docs/.test_reports/longrun-stage15-YYYYMMDD/`.
- Format: per-row evidence format from the Stage 12 implementation log
  part-01 (server.out.log, server.err.log, metrics samples, resource
  samples, cap-exit.json, summary.md, evidence-summary.md).
- Required content: per-row L01..L03 verdict (PASS-meets-intent or
  BLOCKED-time-budget), actual wall-clock seconds, the cap-exit
  reason, and the resource stability check results from design part-03.
- Source: per-row evidence directory plus the side log at
  `._design_docs/.test_reports/longrun-stage15-YYYYMMDD/batch-summary.log.side`.

### C-bench

- File path: `._design_docs/.test_reports/stage15-benchmark-20260612-01.md`
  per D4 plus per-row evidence directory under
  `._design_docs/.test_reports/bench-stage15-YYYYMMDD/S12-B0X/<row>/`.
- Format: per-row evidence format from the Stage 12 implementation log
  part-01 (server.out.log, server.err.log, metrics snapshots, k6
  results for B01 and B06, load-tool output for non-k6 rows, baseline
  JSON, legacy baseline JSON when applicable, evidence-summary.md).
- Required content: per-row B01..B08 verdict, the eight metrics from
  design part-05, the regression classification per Stage 12 design
  part-03, and the legacy comparison row.
- Source: per-row evidence directory plus the benchmark report.

### C-regression

- File path: `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
  under heading "C-regression" plus the runner evidence under
  `._design_docs/.test_reports/run-YYYYMMDD/`.
- Format: same as C-pytest, scoped to the Stage 4-9 regression rows
  from the test plan matrix.
- Required content: per-row verdict for R10..R23, R20..R23, and the
  H30..H74 closed-stage rows. The QA table records the actual R and H
  row IDs from the test plan matrix, resolving the N1 finding from
  the design review.
- Source: runner log plus the test plan matrix at
  [cache-handling-test-plan/part-03](../cache-handling-test-plan/part-03-integration-test-matrix.md).

## Side log and cap-exit handling

The longrun kickoff driver writes a side log at
`._design_docs/.test_reports/longrun-stage15-YYYYMMDD/batch-summary.log.side`
per P5. The side log records:

- Driver start, kill, sleep, launch, and stop events with timestamps.
- Per-batch summary with the per-row verdict and the actual wall-clock.
- Cap-exit events with the reason and the partial-state line.
- Manager handoff entry per the daily handoff convention.

The driver writes `cap-exit.json` per row with `started_at`, `ended_at`,
`wall_clock_seconds`, `cap_seconds`, `reason`, and `partial_state` per
design part-03. The summary.md under the per-row directory records
the same cap-exit event under a `cap-exit` heading for grep
discoverability. The QA test report records the cap-exit verdict in
the per-row table.

## Risk table

| Risk | Trigger | Impact | Mitigation |
| --- | --- | --- | --- |
| Long-running row cannot complete 6h on the local host | Host reboot, fixture fallback, or operator stop before the 6h cap | L01 row ends in `BLOCKED-time-budget`; closure contract still records the partial state | Per-row cap-exit record per design part-03; QA reports the actual wall-clock and reason; closure decision is the Manager's, not QA's |
| Fixture becomes unavailable mid-run | Local model fixture inventory changes between categories | Affected row ends in `BLOCKED-fixture`; V2 bench precedent allows this for B02 | QA records the missing fixture and the affected row; Manager may narrow the matrix before closure |
| Coverage tool fails on the current build | OpenCppCoverage or its dependencies break between sessions | T114 and T114a end in `BLOCKED-tooling` instead of `PASS` | QA cites the failure mode and the tool version; Manager decides whether to retry, switch tools, or record a plan-change |
| Pre-existing test bug becomes a hard fail | `test-stage10-policy-lru` flips from `BLOCKED-pre-existing` to a hard crash that blocks ctest | C-ctest ends with one extra FAIL | QA records the bug as `BLOCKED-pre-existing` per prior decisions; ctest category is not blocked by it; bug stays out of Stage 15 scope |
| Bug-fix loop exhausts the 3-iteration cap | Bug cannot be fixed without a prior-stage design change | Developer escalates to Manager with a plan-change decision | Per Step 3; loop does not close with known bugs; Manager records the decision |
| Benchmark regression masks a real product bug | `TUNING-GAP` classification hides a `PRODUCT-BUG` symptom | Closure decision accepts a metric the design treats as a blocking defect | Architect reviews the regression classification in the benchmark report; a `TUNING-GAP` that hides a correctness symptom is reclassified |
| Synthetic matrix expansion resumes | User request to add V3 or non-MTP rows re-opens the Stage 12 follow-up | Wall-clock budget explodes; closure decision slips | 2026-06-09 close-at-current-progress decision is preserved in non-goals; Manager narrows the matrix before closure |
| Public endpoint parity row flips FAIL | Route family changes shape or bounded diagnostic emission site moves | E13-01..E13-16 fails | QA cites the route family and the failure; Developer opens a bug-fix iteration; closure waits for the rerun |
| N1 finding not resolved at execution | QA records the typo'd R-numbering without consulting the test plan matrix | Regression evidence is ambiguous and the closure checklist cannot cite canonical row IDs | QA resolves N1 against the test plan matrix at execution per the design review; this plan records the resolution path in Step 2 |
| Build becomes stale during multi-day execution | Long-running rows and overnight pauses span more than the 10-minute freshness window | Step 1 freshness check fails on the next test session | QA reruns Step 1 (clean build) at the start of each test session and records the binary timestamp in the QA report |
| Worktree drift between sessions | A Developer commit during a paused longrun run lands in `work-branch` | The binary used by QA no longer matches the implementation log | Step 1 includes `git status --short` and the commit SHA in the QA report; if the worktree is dirty, the QA records the state before starting the next session |
| MTP fixture absent on the local host | T121 row requires the MTP-capable fixture | T121 ends in `BLOCKED-fixture` | Per design part-07, T121 is a closure contract; QA cites the missing fixture and Manager may narrow the matrix before closure |
| L01 row does not auto-resume after a pause | Driver stops on operator stop and the next session does not pick up the row | The 6-hour budget is lost | Driver records the pause in the side log; the row is `BLOCKED-time-budget` with reason `operator-stop`; QA does not auto-resume |

## Excluded risk categories

The plan does not re-examine these from the design (part-06):

- Host-level security or network exposure from running the server in
  `--cache-mode hybrid` for 6 hours. The Stage 12 design part-04
  already covers the OWASP review scope and the cold-store root
  containment rule.
- Long-term storage growth in the cold store. The Stage 6 design and
  the Stage 12 stress row S06 already cover cold queue pressure and
  orphan growth.
- Upstream merge risk. Stage 14 is closed.
- Cross-host portability. The benchmark report and the bug-fix loop
  operate on the local host.
- Performance optimization that would change cache behavior. The
  bug-fix loop fixes product bugs; it does not tune performance beyond
  what the closure contracts already require.

## Handoff to execution

The evidence plan and risk table are inputs to the QA owner's
execution. The Developer uses the risk table to triage any blocker
during the bug-fix loop. The Architect uses the risk table to
classify regression rows in the benchmark report. The Manager uses
the risk table to record the closure decision.
