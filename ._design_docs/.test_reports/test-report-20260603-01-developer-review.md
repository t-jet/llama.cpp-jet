# Stage 10 Developer test-results review - 20260603-01

Source report: [test-report-20260603-01.md](test-report-20260603-01.md)
Paired fixes file: [test-report-20260603-01-fixes.md](test-report-20260603-01-fixes.md)
Prior report (BLOCKED): [test-report-20260602-02.md](test-report-20260602-02.md)
Coverage headliner: [test-report-20260603-01-artifacts/coverage-summary.md](test-report-20260603-01-artifacts/coverage-summary.md)

Reviewer: Developer agent
Date: 2026-06-03
Verdict: **PASS-with-environment-blockers**

## Verdict summary

The rework report narrows the blocker set from 5 BLOCKED in 20260602-02 to
2 FAIL and 3 BLOCKED in 20260603-01. The QA report's own "Product bugs"
section states: "None found in this execution session." My independent review
agrees. The 2 FAILs are coverage-toolchain environment issues, and the 3
BLOCKEDs are benchmark/fixture environment constraints. None of them points
at a product defect in cache behavior.

Counts from the report: 16 PASS, 2 FAIL (T114, T115), 1 SKIP (T110 by
design - no marker surface), 3 BLOCKED (T116, T117, T121).

## Per-row review

### T114 - Hybrid path coverage - FAIL

- Classification: **environment constraint (coverage toolchain)**, not a
  product bug.
- Rationale: the 80% threshold is a contractual number from the Stage 10
  design and the test plan. OpenCppCoverage reported a combined line rate of
  0.2127. The focused tests themselves are at 99-100% line coverage. The
  hybrid source files (`server-cache-hybrid.cpp` 0.22-0.36,
  `server-cache-store-cold.cpp` 0.13-0.76, `server-context.cpp` 0.00-0.01)
  are low because focused tests do not drive the HTTP integration paths and
  because `server-context.cpp` (3138 lines) is in the denominator without an
  HTTP-server probe. The LLVM source-based coverage path failed at link time
  on this host (`__profc_` symbols unresolved under lld-link, plus an MSVC
  C2668 in `tests/test-cache-controller.cpp(1804)` that only survives under
  MSVC, not clang-cl). These are toolchain issues, not cache behavior bugs.
- Recommended action: route to **Manager** for an explicit gating decision
  on the 80% threshold and the coverage-tool fallback. The follow-on QA
  session 20260603-02 already wrote the correct reusable
  `run_coverage.ps1` and a corrected k6 script; the next execution should
  produce a defensible number with the corrected denominator. No Developer
  code change is required for T114.

### T115 - Coverage denominator and exclusions - FAIL

- Classification: **environment constraint + test-plan gap**, not a
  product bug.
- Rationale: downstream of T114. OpenCppCoverage does not emit branch
  coverage, so the branch-totals column is absent by tool limitation; the
  test plan row allows "branch totals when available," which leaves room
  for the fallback. The uncovered-hybrid-paths-above-risk-threshold list
  is the more substantive gap, and it was not produced beyond the per-file
  line rates.
- Recommended action: route to **Manager** for an explicit gating decision
  on the missing uncovered-paths list and the branch-totals absence. The
  corrected `run_coverage.ps1` in 20260603-02 should also report
  uncovered-paths-above-risk. No Developer code change is required for T115.

### T116 - Benchmark evidence - BLOCKED

- Classification: **environment/test-plan gap**, not a product bug.
- Rationale: `k6` 2.0.0-rc1 is installed at `D:\app\k6\k6.exe`; `matplotlib`
  3.10.9 is now installed. The k6 run in 20260603-01 was a connectivity
  probe against `/health` and `/metrics` only and produced no
  exact-hit/checkpoint-hit/cold-transition/end-to-end savings
  measurements. `python tools/server/bench/bench.py` was not run.
- Recommended action: route to **Manager** for an explicit gating decision
  on whether the bench toolchain presence (k6 + matplotlib installed) plus
  the connectivity probe is enough to release the gate, or whether the
  full bench scenarios must run before closure. The follow-on session
  20260603-02 already wrote `tools/server/tests/bench-cache-correctness.js`
  and `._design_docs/cache-handling-test-scripts/run_benchmark_k6.ps1` to
  produce the T116/T117 evidence. No Developer code change is required for
  T116.

### T117 - Benchmark correctness gate - BLOCKED

- Classification: **environment/test-plan gap**, not a product bug.
- Rationale: depends on T116. With no exact-hit/checkpoint-hit/
  cold-transition measurements, the gate cannot be evaluated. The 20260603-01
  k6 run established that `/health` and `/metrics` return 200 with 0%
  failures at p(95) 1.07 ms, but the bench correctness gate as defined in
  the test plan requires T116 evidence first.
- Recommended action: route to **Manager** for an explicit gating decision.
  No Developer code change is required for T117.

### T121 - Stage 9 regression / model-backed checkpoint `/metrics` - BLOCKED

- Classification: **environment/fixture constraint**, not a product bug.
- Rationale: the public probe ran on `Qwen3-0.6B-Q8_0.gguf`, which is a
  plain-transformer model. The four `cache_checkpoint_*` rows are at
  zero-valued bounded-shape placeholders because no checkpoint descriptor
  can be admitted for a plain-transformer workload. The same fixture
  limitation was already flagged in 20260602-02 and is unchanged here.
- Recommended action: route to **Manager** for an explicit gating decision
  on whether a checkpoint-capable fixture is required for Stage 10 closure,
  or whether the focused T111/T119 evidence (descriptor validation, paired
  target/draft, fault-injection) plus the public bounded-shape placeholders
  are sufficient for the Stage 9 regression check. No Developer code change
  is required for T121.

## Cross-check: OWASP and operator-doc rows

The report's OWASP classification table is inherited from 20260602-02 and
not modified. Every category remains PASS with the same evidence: focused
tests cover the relevant behavior, and the report explicitly states no
unmitigated correctness, confidentiality, or operator-control issue was
found. No regression in T108 (operator documentation) or T113 (security
evidence) compared with 20260602-02. The Developer review agrees with
both PASS rows.

## Limitation: 8 focused C++ tests not explicitly rerun via ctest

The report explicitly states that the focused `ctest -R "test-(...)"`
command from 20260602-02 was not rerun in 20260603-01. The 8/8 pass
outcome is inferred from the per-test exit codes under OpenCppCoverage
(all 0) and the existence of all 8 binaries in the clean Release tree
with same-day timestamps.

This is a session limitation, not a defect in the report or in the
product. The next QA execution can close it by reissuing the explicit
`ctest --test-dir build -C Release -R "test-(cache-controller|step10-metrics|stage10-cold-store-hardening|step6-demotion-protocol|step7-promotion-protocol|step11-test-hooks-fault-injection|step12-branch-graph|step13-stage8)" --output-on-failure`
command from the test plan's Part 12 "Clean build, coverage, and
execution rules" section. Per the task instructions, I do not escalate
this as a bug; I record it for the next session.

## Product bugs

None. The QA report states no product bugs were found in this execution
session. My independent review of T100-T121 (excluding T110 SKIP) and the
public probe evidence (timings.cache_n=0 then 4, bounded Stage 10 rows,
zero-valued checkpoint placeholders) confirms the classification. The
clang-cl `__profc_` link failure and the MSVC `error C2668` at
`tests/test-cache-controller.cpp(1804)` are toolchain issues; the
OpenCppCoverage run used the MSVC-built `test-cache-controller.exe` and
the focused tests pass under that build.

## Recommendation to Manager

The blocker set has narrowed materially: 5 BLOCKED in 20260602-02 became
2 FAIL + 3 BLOCKED in 20260603-01, and the blockers are all environment
or fixture constraints, not product defects. Manager should make the
explicit Stage 10 closure decision, weighing:

- the 80% coverage threshold (T114/T115) against the OpenCppCoverage
  fallback and the corrected `run_coverage.ps1` in 20260603-02
- the benchmark scenarios (T116/T117) against the installed k6 and
  matplotlib, the connectivity probe, and the new
  `bench-cache-correctness.js` script
- the Stage 9 model-backed checkpoint regression (T121) against the
  absence of a checkpoint-capable fixture on this host

My Developer verdict is **PASS-with-environment-blockers** for the cache
behavior under test, and I do not propose any Developer fix session for
product code on the strength of this report.

## Next gate

Stage closure (Manager).
