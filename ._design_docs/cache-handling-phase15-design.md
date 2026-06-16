# Stage 15 design: full test suite validation, bug-fix loop, and benchmark report

Status: Design gate PASS, 2026-06-12
Date: 2026-06-12
Stage: 15 (Full Test Suite Validation, Bug-Fix Loop, and Benchmark Report)
Prerequisite Stages: 1-14 (CLOSED). Stage 14 was closed by user direction on
2026-06-12 with stale header status in the implementation log and missing
closing test report retained per user instruction "without any other
modification".

## Scope

User scope, verbatim from the tracker row at
`._design_docs/cache-handling-stage-tracker.md` line 42:

> "execute the full test suite including long-running tests, apply fixes for
> any product bugs found, and produce a benchmark report."

This design keeps the architecture-baseline scope as fixed and writes the
operational contract that lets QA execute, Developer fix bugs, Architect
review fixes, and Manager close the stage. Stage 15 is operational. It does
not add cache behavior, public endpoints, CLI flags, metrics, or test code.

Concrete deliverables under that scope:

1. A single QA execution that runs the full test suite, including the
   long-running rows S12-L01..L03 from the Stage 12 stress design
   (`._design_docs/cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md`).
2. A bug-fix loop that operates on any product bug found in step 1, with
   explicit termination rules and escalation.
3. A benchmark report that records the required metrics and compares them
   to the Stage 12 V2 bench baseline
   (`._design_docs/.test_reports/test-report-20260609-02-V2-bench.md`).

This design does not authorize implementation planning, code work, test
execution, bug-fix work, benchmark execution, commits, PR text, or reviewer
responses.

## Prerequisites and gates

- All prior stages 1-14 are closed. The Stage 14 implementation log
  retains stale "current gate" wording by user direction; that stale
  wording does not block Stage 15.
- The local working tree is on the `work-branch` branch. The user has
  not asked for any other branch in the Stage 15 brief.
- A clean build is required before any test execution. Build command:
  `cmake --build build-cov --config Release --target llama-server`
  (mirrors the Stage 12 V2 bench command and the Stage 14 integration
  log). The build directory is `build-cov`; the binary is
  `build-cov/bin/Release/llama-server.exe`.
- The closure contracts the bug-fix loop must protect, and the
  operational contracts the design re-verifies, are listed in
  [part-07](cache-handling-phase15-design/part-07-exclusions-traceability-and-handoff.md).
- Per-step gates: design authoring, independent design review, manager
  design gate, implementation planning, implementation (test execution
  and bug-fix work), test planning, test execution, test-results
  review, bug-fix loop, closure.

## Assumptions

- The QA owner can reserve enough wall-clock time for the long-running
  rows S12-L01..L03. The 6-hour S12-L01 row is the largest single
  budget item; S12-L02 is 30 minutes; S12-L03 is 2 hours. The
  long-running row caps are decided in D2.
- The local model fixture inventory from the prior stages is unchanged:
  Qwen3-8B target plus Qwen3-0.6B normal separate draft for the
  draft-capable rows, Qwen2.5-VL or the local default for plain rows,
  and the Qwen3.5-MTP or Qwen3.6-MTP fixtures for the MTP rows where
  the prior V1/V3 reports used them.
- Legacy mode remains the default. Hybrid mode remains opt-in through
  `--cache-mode hybrid`.
- The benchmark report uses the local hardware, model fixtures, build
  configuration, and server flags from this session, and records
  absolute numbers and a hybrid-vs-legacy ratio. It is a regression
  detection anchor, not a promise of matching the V2 bench exactly.
- Public Prometheus metrics and bounded diagnostics from Stage 10
  remain the operator-visible evidence source. The bug-fix loop does
  not weaken them.

## Manager decisions (recorded verbatim, not re-debated)

- D1 (2026-06-12): "Full test suite" means the union of (a) ctest on
  the build tree that the test plan documents in
  [cache-handling-test-plan/part-05-runner-and-evidence-format.md](../cache-handling-test-plan/part-05-runner-and-evidence-format.md),
  (b) the in-scope pytest rows from the same test plan, (c) the
  public HTTP probe rows from the Stage 13 endpoint test plan
  ([part-23](../cache-handling-test-plan/part-23-stage13-endpoint-compatibility.md)),
  (d) the Stage 4-9 regression rows in the test plan matrix, (e) the
  Stage 10 closure-contract rows T114, T114a, T115, and T121, and
  (f) the Stage 12 stress and benchmark contract rows S01..S08,
  L01..L03, and B01..B08 from
  [part-02](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md)
  and
  [part-03](../cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md).
  The "full" qualifier is the union, not a single command.
- D2 (2026-06-12): "Long-running tests" means the Stage 12 long-run
  rows S12-L01 (6 hours), S12-L02 (30 minutes), and S12-L03 (2
  hours). The per-row time cap is the duration from the Stage 12
  design: 6 hours, 30 minutes, and 2 hours. The driver records
  cap-exit as `BLOCKED-time-budget` and includes the actual
  wall-clock seconds in the evidence summary. Per
  `.agents/skills/self-improvement/assets/manager.md` line 188, the
  1000 hits-plus-misses threshold that applies to 30-min stress rows
  does not apply structurally to the long-run rows; the QA classifies
  long-run rows on intent (clean cache counters, monotonic metric
  shape, no crash) rather than the literal 1000 number. A long-run
  row may also end in `PASS-meets-intent` when counters are clean and
  Stub data flag is `MEASURED`, even if hits+misses is well below
  1000.
- D3 (2026-06-12): The bug-fix loop terminates when one of three
  conditions is met: (a) the report shows zero product bugs and the
  closure contracts T114, T114a, T115, T121, S01..S08, L01..L03, and
  B01..B08 are all `PASS` or `PASS-meets-intent`; (b) the maximum
  iteration count is reached; or (c) a bug cannot be fixed without a
  plan-change decision. The maximum iteration count is 3. Each
  iteration must record Developer evidence, Architect review verdict,
  QA rerun evidence, and Developer test-results review. If a bug
  cannot be fixed within 3 iterations, the Developer escalates to
  the Manager with a clear plan-change decision; the bug-fix loop
  does not close with known bugs in scope. Closing with known bugs
  is forbidden by the
  `do not close stage with unmet or BLOCKED requirements` rule in
  the manager improvement memory.
- D4 (2026-06-12): The benchmark report records the Stage 12
  B01..B08 metrics in the same shape as the V2 bench report: exact-
  blob hit rate, checkpoint hit rate, cold transition frequency,
  end-to-end token throughput, restore latency, prompt-storm
  efficiency, mixed-profile comparison, and large-forest lookup
  cost. The report adds a regression-detection section that compares
  each metric to the V2 bench baseline
  (`._design_docs/.test_reports/test-report-20260609-02-V2-bench.md`)
  and classifies any change as `EXPECTED-COST`, `TUNING-GAP`,
  `PRODUCT-BUG`, `TOOLING-GAP`, or `LEGACY-REGRESSION` per the
  Stage 12 benchmark design
  ([part-03](../cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md)).
  The benchmark report file is
  `._design_docs/.test_reports/stage15-benchmark-20260612-01.md`.
- D5 (2026-06-12): Test artifacts use the existing durable test
  report location `._design_docs/.test_reports/` with the naming
  pattern `test-report-YYYYMMDD-NN.md` and paired
  `test-report-YYYYMMDD-NN-fixes.md` plus
  `test-report-YYYYMMDD-NN-developer-review.md` per the test plan's
  test-report-quality rules
  ([part-07](../cache-handling-test-plan/part-07-test-report-quality-and-templates.md)).
  The benchmark report uses the Stage 15 prefix
  `stage15-benchmark-YYYYMMDD-NN.md` to distinguish it from
  per-session test reports. Long-running row evidence lives under
  `._design_docs/.test_reports/longrun-stage15-YYYYMMDD/` and
  stress row evidence under
  `._design_docs/.test_reports/stress-stage15-YYYYMMDD/`. The
  non-durable output convention from the test plan
  (`._test_output/`, ignored) is unchanged.

## Non-goals

- Adding or changing cache behavior, public endpoints, CLI flags,
  metrics, or bounded diagnostics.
- Weakening any prior closure contract (T114, T114a, T115, T121,
  E13-01..E13-16, S01..S08, L01..L03, B01..B08) by reclassifying
  FAIL or BLOCKED rows to softer statuses.
- Closing the stage with known bugs in scope. Closing without
  resolution requires an explicit Manager plan-change decision
  recorded in the test plan or in the Manager's status, not a
  reclassification of the bug-fix loop output.
- Resuming the synthetic Stage 12 V2/V3/non-MTP matrix expansion
  beyond what the architecture-baseline scope requires.
- Fixing the `test-stage10-policy-lru` pre-existing semantic bug. It
  is out of Stage 15 scope and is tracked separately.
- Producing PR text, reviewer responses, commits, or test reports
  in this design gate.

## Contents

- [Part 2: test suite definition](cache-handling-phase15-design/part-02-test-suite-definition.md)
- [Part 3: long-running tests](cache-handling-phase15-design/part-03-long-running-tests.md)
- [Part 4: bug-fix loop](cache-handling-phase15-design/part-04-bug-fix-loop.md)
- [Part 5: benchmark report](cache-handling-phase15-design/part-05-benchmark-report.md)
- [Part 6: observability, testability, and risks](cache-handling-phase15-design/part-06-observability-testability-risks.md)
- [Part 7: exclusions, traceability, and handoff](cache-handling-phase15-design/part-07-exclusions-traceability-and-handoff.md)

The entry doc stays under the 300-line cap. Content that would push
the entry past 300 lines lives in the part files. Part 1 is omitted
because scope, prerequisites, assumptions, and decisions fit in the
entry doc. Part 8 is the Architect independent design review and is
authored by a fresh Architect session, not by this one.

## Current gate

Current gate: design authoring in progress. The next owner after
this draft is the Architect for an independent design review
(recorded in part-08 by a fresh Architect session). After the
independent review, the next owner is the Manager for the design
gate decision.

## Stage gate

| Gate | Status |
| --- | --- |
| Design authoring | IN PROGRESS, 2026-06-12 |
| Independent design review | NOT STARTED |
| Manager design gate | NOT STARTED |
| Implementation planning | NOT STARTED |
| Implementation | NOT STARTED |
| Test planning | NOT STARTED |
| Test execution | NOT STARTED |
| Test-results review | NOT STARTED |
| Bug-fix loop | NOT STARTED |
| Closure | NOT STARTED |

## Handoff

This design is the Stage 15 design deliverable. It is ready for the
independent Architect design review and then the Manager design-gate
review. The next gate after Manager approval is implementation
planning; the next owner is the Developer. Test execution, bug-fix
work, and the benchmark report are not authorized by this design.
