# Stage 35 Manager coverage-contract decision 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Verdict

REWORK. Developer must add or restore meaningful focused coverage until
TP-35-COV-01 satisfies the Stage 35 coverage contract.

## Evidence reviewed

- QA report [test-report-20260708-02.md](../.test_reports/test-report-20260708-02.md)
  reran TP-35-COV-01 after F35-QA-FIX-01. Corrected targets built and ran under
  OpenCppCoverage.
- Developer review
  [test-report-20260708-02-developer-review.md](../.test_reports/test-report-20260708-02-developer-review.md)
  classified F35-QA-02 as a coverage-contract issue, not a product runtime bug
  or tooling blocker.
- Measured coverage is below both required floors:
  - combined: 0.734, required >= 0.80;
  - product-only: 0.5856, required >= 0.70.

## Decision

Stage 35 does not get a coverage exception. The design keeps prior-stage
coverage contracts binding, and Part 40 makes TP-35-COV-01 required because
feature-mode files changed. The miss is too large to treat as rounding,
formatting, or a closure-note exception.

Developer owns focused coverage work. The fix should prefer current,
meaningful tests over denominator changes. Removing obsolete async-only coverage
targets remains accepted from F35-QA-FIX-01; the next fix must cover current
synchronous cache behavior.

## Required Developer scope

- Add or restore focused coverage for current product paths, primarily the low
  product rows identified in the coverage report:
  `server-cache-hybrid.cpp`, `server-cache-io-worker.cpp`,
  `server-cache-graph.h`, `server-cache-controller.h`,
  `server-cache-policy-lru.cpp`, and cold-store paths as useful.
- Keep production behavior unchanged unless a real defect is found. If
  production code changes, rerun the functional rows affected by that change.
- Rebuild the corrected Stage 35 coverage target set.
- Produce a fix report or update
  [test-report-20260708-01-fixes.md](../.test_reports/test-report-20260708-01-fixes.md)
  with coverage-test changes, commands, and evidence.
- Return for Architect fix review before QA reruns TP-35-COV-01.

The `run_coverage.ps1` Start-Process issue is secondary. It may be fixed if
cheap, but it does not close TP-35-COV-01 unless markdown coverage also meets
the thresholds.

## Next owner

Developer.

Next gate: focused coverage-test rework for F35-QA-02.
