# Stage 10 Developer test-results review - 20260603-03

- Review ID: `test-report-20260603-03-developer-review`
- Date: 2026-06-03
- Reviewer: Developer agent
- Source report: [test-report-20260603-03.md](test-report-20260603-03.md)
- Paired fixes: [test-report-20260603-03-fixes.md](test-report-20260603-03-fixes.md)
- Same-day follow-up that built the runnable scripts: [test-report-20260603-02.md](test-report-20260603-02.md)
- Prior test-results review: [test-report-20260603-01-developer-review.md](test-report-20260603-01-developer-review.md)
- Stage 10 test plan part: [cache-handling-test-plan/part-12-stage10-observability-security-hardening.md](../cache-handling-test-plan/part-12-stage10-observability-security-hardening.md)
- Manager test-plan gate: [cache-handling-test-plan/stage-10-manager-test-plan-gate-20260602.md](../cache-handling-test-plan/stage-10-manager-test-plan-gate-20260602.md)
- Stage 10 implementation log: [cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)

## Verdict

PASS for the cache behavior under test. No product bugs found in this
execution. The 2 FAIL rows (T114, T115) and 1 BLOCKED row (T121) are
coverage-threshold, automation, and fixture-availability issues. They are
not regressions in the cache code and do not route to the bug-fix loop.

QA final counts: 19 PASS, 2 FAIL (T114, T115), 1 BLOCKED (T121), 0 SKIP.

I agree with all per-row verdicts. My independent verification of the
evidence files in [test-report-20260603-03-artifacts/](test-report-20260603-03-artifacts/)
matches the report's claims:

- [ctest.log](test-report-20260603-03-artifacts/ctest.log): 8/8 PASS in 9.39 sec.
- [pytest.log](test-report-20260603-03-artifacts/pytest.log): 3 passed, 1 xfailed in 7.58 sec.
- [coverage-merged.xml](test-report-20260603-03-artifacts/coverage/coverage-merged.xml) root: `line-rate="0.73145526093192603"`, `lines-covered="19889"`, `lines-valid="27191"` (authentic union merge, not a sum).
- [bench/metrics-after.txt](test-report-20260603-03-artifacts/bench/metrics-after.txt) vs [bench/metrics-before.txt](test-report-20260603-03-artifacts/bench/metrics-before.txt): hits delta 0 -> 12 (+12), misses delta 0 -> 1 (+1). Matches the corrected [bench/evidence-summary.md](test-report-20260603-03-artifacts/bench/evidence-summary.md).
- [k6-results.json](test-report-20260603-03-artifacts/bench/k6-results.json): 11 hit_probe iterations, `cache_hit_rate=1` per iteration, `cache_n_tokens=4` per iteration, threshold `rate>=0.60` met.

## Per-row classification

| ID | QA verdict | Developer agreement | Product bug? | Notes |
| --- | --- | --- | --- | --- |
| T100 | PASS | Agree | No | `test-step10-metrics` confirms bounded label shape on the focused exporter. |
| T101 | PASS | Agree | No | Quote and newline escaping covered in focused exporter test. |
| T102 | PASS | Agree | No | Bounded enum-like labels; no prompt, marker, path, or payload leak. |
| T103 | PASS | Agree | No | Cold-store root containment from `test-stage10-cold-store-hardening`. |
| T104 | PASS | Agree | No | Cold-file integrity fallback in focused controller test. |
| T105 | PASS | Agree | No | Startup validation in focused and Python startup tests. |
| T106 | PASS | Agree | No | Pressure handling in `test-stage10-cold-store-hardening`. |
| T107 | PASS | Agree | No | Deterministic stress seams documented. |
| T108 | PASS | Agree | No | Operator docs in Section 8 of the report match the implementation. |
| T109 | PASS | Agree | No | Bounded label set verified in `metrics-stage10-excerpt.txt` (the one production row carries count 1; the other five are zero-valued placeholders as designed). |
| T110 | PASS | Agree | No | No marker surface exposed; T110 is the "no row required" sentinel. |
| T111 | PASS | Agree | No | Descriptor and restore hardening in `test-cache-controller` and `test-step11-test-hooks-fault-injection`. |
| T112 | PASS | Agree | No | Unsupported runtime shapes in `test-stage10-cold-store-hardening`. |
| T113 | PASS | Agree | No | OWASP table in Section 9 of the report uses focused and public evidence from this run. |
| T114 | FAIL | Agree | No (coverage threshold) | `coverage-merged.xml` line rate 0.7315 < 0.80 threshold. Not a defect; see Manager decision section. |
| T115 | FAIL | Agree | No (automation / script) | Merged XML is correct union merge (verified by reading the root attributes). `coverage-report.md` per-file table is decorative and lists each file 8x due to a renderer bug in `run_coverage.ps1`. The 80% threshold is still not met regardless of aggregation quality. Script-quality follow-up recommended, not a stage-10 closure blocker. |
| T116 | PASS (corrected) | Agree | No | I verified `bench/metrics-after.txt` and `bench/metrics-before.txt`: hits +12, misses +1. The original `bench/evidence-summary.md` parsing bug (showed 0/0/0) is fixed in the corrected file in the same artifacts directory. k6 `cache_hit_rate=1.0` (11/11). Direct stats and public Prometheus both confirm exact-hit restore. |
| T117 | PASS | Agree | No | k6 `rate>=0.60` threshold met (`cache_hit_rate=1.0`). |
| T118 | PASS | Agree | No | `test-cache-controller` covers Stage 4-5 regression. |
| T119 | PASS | Agree | No | `test-step6-demotion-protocol` and `test-step7-promotion-protocol` cover Stage 6 regression. |
| T120 | PASS | Agree | No | `test-step12-branch-graph` and `test-step13-stage8` cover Stage 7-8 regression. |
| T121 | BLOCKED | Agree | No (fixture blocker) | Qwen3-0.6B is plain-transformer. The four `cache_checkpoint_*` rows in `metrics-checkpoint-excerpt.txt` are at zero-valued bounded placeholders. The metric label shape and presence are verified; dynamic counters cannot fire without a checkpoint-capable fixture. The focused substitute evidence in `test-cache-controller` covers checkpoint descriptor validation, pair validation, and metric label shape. The test plan's blocker-not-skip rule is honored. |

### T116 scope note

The current bench run produced evidence for the `exact-hit` scenario only
(direct stats, public Prometheus, and harness-only). The `checkpoint-hit`,
`cold-transition`, and `end-to-end savings` scenarios were not produced in
this run. The cold-transition scenario has focused evidence in
`test-stage10-cold-store-hardening`. The T116 row is PASS for the
exact-hit scenario per the evidence classification table in the report,
and the test plan does not require all four scenarios in the same
execution. If Manager wants the missing scenarios added to the bench
script as a follow-up, that is a Manager decision, not a Developer fix.

## Bug-fix decision

**Bug-fix loop: NOT OPENED. No product bugs found in this execution.
T114/T115/T121 are coverage/automation/fixture issues for Manager to
triage, not product defects.**

Per the Manager memory rule and the test plan's blocker-not-skip policy:

- T114: coverage threshold not met. The denominator and union merge are
  correct. The gap is a focused-test coverage shortfall, not a defect in
  the implementation.
- T115: the merged XML is the source of truth. The per-file renderer
  bug in `coverage-report.md` is a script-quality issue, not a product
  bug. The 80% threshold is still not met regardless.
- T121: no checkpoint-capable fixture in the local catalog. The four
  `cache_checkpoint_*` metric rows are present and correctly shaped.
  The focused substitute evidence in `test-cache-controller` covers
  descriptor validation, pair validation, and metric label shape.

I do not propose any Developer code-fix session for product code on the
strength of this report.

## Recommended follow-up tasks (Manager-decision, not Developer-fix)

The three non-pass rows belong to Manager for explicit gating decisions
per the project's stage-closure workflow. None of them is a Developer
fix session.

### T114 coverage threshold (73.15% < 80%)

- Manager decision needed on one of:
  - (a) Add focused tests for the uncovered hybrid paths in
    `server-cache-hybrid.cpp/.h` and `server-cache-store-cold.cpp/.h`
    to lift the union rate above 80%. Preferred option per the fixes
    file.
  - (b) Raise the threshold to the measured value (for example, 73% or
    75%) with an explicit Manager decision recorded against the
    cache-handling test plan. The threshold change is a test-plan
    change, not a Developer code change.
  - (c) Reclassify T114 as `BLOCKED-with-coverage-evidence` until a
    checkpoint-capable public fixture is added, since the public probe
    paths are limited to plain-transformer behaviour in the current
    fixture catalog.

### T115 per-file aggregation (`run_coverage.ps1`)

- Optional Developer follow-up to fix `run_coverage.ps1` so it
  aggregates per-file line rates from the merged XML (the source of
  truth) instead of concatenating per-test Cobertura exports. This is a
  script-quality fix for the report renderer; the coverage measurement
  itself is correct.
- Not a stage-10 closure blocker. The 80% threshold is still not met
  regardless of aggregation quality.

### T121 checkpoint-capable fixture

- Manager decision needed on one of:
  - (a) Add a checkpoint-capable model to the local fixture catalog.
    `Qwen3.5-4B-MTP-GGUF` is a candidate (already in
    `D:\source\llama.cpp-jet\._test_models\`); the MTP/draft path must
    be exercised by the public probe and validated against the public
    `cache_checkpoint_*` rows.
  - (b) Re-scope T121 to use focused-substitute evidence for the public
    row, with an explicit Manager decision recorded against the
    cache-handling test plan. The focused substitute already covers
    descriptor validation, pair validation, and metric label shape.

### Bench script scope (informational, not a separate row)

- If Manager wants the missing `checkpoint-hit`, `cold-transition`, and
  `end-to-end savings` bench scenarios in a future execution, route that
  to a future QA or Developer session. The current T116 PASS verdict
  is justified for the exact-hit scenario per the test plan.

## Cross-references and prior sessions

- [test-report-20260603-02.md](test-report-20260603-02.md) is the
  same-day QA follow-up that built the runnable `run_coverage.ps1` and
  `run_benchmark_k6.ps1` scripts. The current 20260603-03 report
  executes those scripts and produces the corrected evidence. The
  20260603-02 session owns the script-quality improvements and is
  referenced here so the Manager gate decision sees the full chain of
  evidence and the in-flight automation work.
- [test-report-20260603-01-developer-review.md](test-report-20260603-01-developer-review.md)
  is the prior Developer review. It reached the same overall verdict
  (PASS-with-environment-blockers) for the previous execution. The
  current review supersedes it.

## Stage 10 closure readiness

All T100-T121 rows are classified. T114/T115/T121 are not product bugs.
The Stage 10 test plan is fully executed within available fixtures.
Recommend Manager advance to Stage closure.

- 19 PASS rows have real evidence and match the test plan.
- 2 FAIL rows are coverage/automation issues for Manager triage, not
  product defects.
- 1 BLOCKED row is a fixture-availability constraint, with focused
  substitute evidence in place per the test plan's blocker-not-skip
  rule.

No Developer fix session for product code is required for the cache
behavior under test.

## Handoff

- Next gate: Stage 10 closure (Manager).
- Next owner: Manager.
- Manager is asked to make explicit gating decisions on T114 (coverage
  threshold), T115 (script fix scope), and T121 (fixture or scope
  re-classification) per the project's stage-closure workflow.
- Developer will not run another fix session for product code on the
  strength of this report.
