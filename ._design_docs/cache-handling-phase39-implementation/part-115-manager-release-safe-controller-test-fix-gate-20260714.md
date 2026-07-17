# Part 115: Manager Release-safe controller test fix gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-29

Developer Part 113 and Architect Part 114 classify the D39-EXEC-28 crash as a
Release-only test bug. Product and Stage 39 seam behavior are not implicated.

Developer may edit only the Stage 23 demotion-budget fallback stale-checkpoint
test in `tests/test-cache-controller.cpp`. Require exactly two entries before
iterator/front access. Replace all 12 `assert` expressions in that function
with Release-active abort checks: four side-effecting attach/eviction calls and
eight ID, residency, map, and metric results. Preserve the explicit rejected
admit and failed-result checks.

After the test-only change, perform one incremental Release seam
`test-cache-controller` build and one full controller-suite run. Acceptance
requires build and suite exit zero, the repaired Stage 23 test PASS, all seven
Stage 39 observation probes PASS, and midpoint plus step-2 faults PASS.

Server rebuild, product changes, pure tests, model route nodes, default build,
canonical TP-39-03, coverage, full QA, commit, push, PR, and reviewer responses
remain blocked. Fresh Architect fix review is required before route execution.
