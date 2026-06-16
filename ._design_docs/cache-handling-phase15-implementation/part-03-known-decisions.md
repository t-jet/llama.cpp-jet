# Stage 15 implementation plan: Manager decision log

Source: [../cache-handling-phase15-implementation.md](../cache-handling-phase15-implementation.md)

## Design decisions (recorded verbatim from the design)

These are the Manager decisions from the Stage 15 design
([cache-handling-phase15-design.md](../cache-handling-phase15-design.md)).
The plan does not re-debate them; the plan depends on them.

- D1 (2026-06-12): "Full test suite" means the union of ctest, the
  in-scope pytest rows, the Stage 13 public HTTP probe, the Stage 4-9
  regression rows, the Stage 10 closure-contract rows T114, T114a,
  T115, T121, and the Stage 12 stress, long-run, and benchmark rows
  S01..S08, L01..L03, B01..B08. The "full" qualifier is the union, not
  a single command.
- D2 (2026-06-12): "Long-running tests" means the Stage 12 long-run
  rows S12-L01 (6 hours), S12-L02 (30 minutes), and S12-L03 (2 hours).
  The driver records cap-exit as `BLOCKED-time-budget` with the actual
  wall-clock seconds in the evidence summary. The 1000 hits+misses
  threshold does not apply structurally to long-run rows per
  `.agents/skills/self-improvement/assets/manager.md` line 188. QA
  classifies long-run rows on intent (clean cache counters, monotonic
  metric shape, no crash).
- D3 (2026-06-12): The bug-fix loop terminates when (a) zero product
  bugs and all closure contracts `PASS` or `PASS-meets-intent`, (b)
  the maximum iteration count of 3 is reached, or (c) a bug cannot
  be fixed without a plan-change decision. Each iteration records
  Developer evidence, Architect review verdict, QA rerun evidence,
  and Developer test-results review. Closing with known bugs in scope
  is forbidden by the
  `do not close stage with unmet or BLOCKED requirements` rule in the
  manager improvement memory.
- D4 (2026-06-12): The benchmark report records the Stage 12 B01..B08
  metrics in the same shape as the V2 bench report and adds a
  regression-detection section that compares each metric to the V2
  bench baseline and classifies any change as `EXPECTED-COST`,
  `TUNING-GAP`, `PRODUCT-BUG`, `TOOLING-GAP`, or `LEGACY-REGRESSION`.
  The benchmark report file is
  `._design_docs/.test_reports/stage15-benchmark-20260612-01.md`.
- D5 (2026-06-12): Test artifacts use the existing durable test
  report location `._design_docs/.test_reports/` with the naming
  pattern `test-report-YYYYMMDD-NN.md` and paired
  `test-report-YYYYMMDD-NN-fixes.md` plus
  `test-report-YYYYMMDD-NN-developer-review.md` per the test plan's
  test-report-quality rules. The benchmark report uses the prefix
  `stage15-benchmark-YYYYMMDD-NN.md`. Long-running row evidence lives
  under `._design_docs/.test_reports/longrun-stage15-YYYYMMDD/` and
  stress row evidence under
  `._design_docs/.test_reports/stress-stage15-YYYYMMDD/`.

## Plan decisions (pre-recorded by the Developer)

These are the plan-level Manager decisions the Developer records
before the Architect plan review. They are decisions, not
pre-approvals of implementation.

- P1 (2026-06-12): Test execution order is the eight-step sequence
  in [part-01](part-01-implementation-plan.md) section "Ordered
  steps". Long-running rows L01..L03 are sequential by design. The
  full test suite runs once per stage in the original QA execution.
  The bug-fix loop rerun runs only the affected rows.
- P2 (2026-06-12): Bug-fix loop ownership. Developer fixes,
  Architect reviews, QA reruns in a fresh sub-session, Developer
  reviews. The four-step iteration matches design part-04.
- P3 (2026-06-12): Evidence capture per category lives in
  [part-02](part-02-evidence-plan-and-risks.md). Each category names
  the file path, the format, and the required content. Non-durable
  artifacts go to `._test_output/`; durable markdown reports go to
  `._design_docs/.test_reports/`.
- P4 (2026-06-12): The benchmark report is its own file at
  `._design_docs/.test_reports/stage15-benchmark-20260612-01.md` per
  D4. It integrates with the closing test report by being referenced
  in the QA test report's per-row table and in the Manager's closure
  entry. The benchmark report is the last durable artifact the QA
  owner produces in Stage 15.
- P5 (2026-06-12): The Manager is informed of progress during the
  long-running rows via a side log at
  `._design_docs/.test_reports/longrun-stage15-YYYYMMDD/batch-summary.log.side`
  plus a daily Manager handoff. The driver writes cap-exit events
  per design part-03 so the Manager can see the actual wall-clock
  and reason without polling.

## Open decisions (P6+)

The plan records any open decision the Architect plan review surfaces
or the Manager plan gate surfaces. As of 2026-06-12, no P6+ decisions
are open. The next entry is added in this section as the plan is
reviewed.

## Handoff to the Architect plan review

The Architect reads this decision log together with the entry doc and
parts 01-04. The Architect records any disagreement, addition, or
escalation as a finding in part-05 of this directory. The Manager
reads the Architect's findings and the plan together to make the
implementation-plan gate decision.
