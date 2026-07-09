# Stage 35 TP-35-COV-01 rerun developer review

Report reviewed: [test-report-20260708-02.md](test-report-20260708-02.md)
Prior report: [test-report-20260708-01.md](test-report-20260708-01.md)
Date: 2026-07-08
Reviewer: Developer
Verdict: MANAGER-DECISION

## Scope

This is a test-results review for the focused TP-35-COV-01 rerun after
F35-QA-FIX-01 Architect fix re-review PASS. No production code fix, test fix,
merge abort, commit, push, PR, reviewer response, or broad rerun was performed.

Inputs reviewed:

- [document-index.md](../document-index.md)
- [cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)
- [Part 40 Stage 35 test plan](../cache-handling-test-plan/part-40-stage35-upstream-merge-regression.md)
- [test-report-20260708-01.md](test-report-20260708-01.md)
- [test-report-20260708-01-developer-review.md](test-report-20260708-01-developer-review.md)
- [test-report-20260708-01-fixes.md](test-report-20260708-01-fixes.md)
- [test-report-20260708-01-fix-re-review.md](test-report-20260708-01-fix-re-review.md)
- [test-report-20260708-02.md](test-report-20260708-02.md)
- `_test_output/stage35-upstream-merge-20260708-02/coverage-manual/coverage-report.md`
- `_test_output/stage35-upstream-merge-20260708-02/coverage-manual/coverage-summary.json`
- `._design_docs/cache-handling-test-scripts/run_coverage.ps1`

## Verdict

F35-QA-02 is a coverage-contract failure that needs Manager decision. It is
not a product runtime bug on the current evidence.

QA report -01 passed the clean build, source proof, cache controller, cache
`ctest`, MTP/KV/speculative rows, route probes, router smoke, stream smoke,
checkpoint rows, metrics boundedness, and Stage 34 synthetic row. The only
remaining required row is TP-35-COV-01.

QA report -02 proves that the stale compile drift is fixed: the corrected
coverage targets build and run under OpenCppCoverage. The row still fails
because measured markdown coverage is below the required floors:

| Metric | Measured | Required | Result |
| --- | --- | --- | --- |
| Combined T114-style line rate | 0.734, 5879 / 8010 | >= 0.80 | FAIL |
| Product-only T114a line rate | 0.5856, 2350 / 4013 | >= 0.70 | FAIL |

This does not identify a broken cache behavior. It identifies that the current
focused coverage evidence no longer satisfies the Stage 10/Stage 11 closure
contract after Stage 35 and the F35-QA-01 coverage-target cleanup.

## Classification

| Finding | Classification | Owner | Decision |
| --- | --- | --- | --- |
| F35-QA-02 / TP-35-COV-01: corrected coverage target set is measurable but below T114/T114a floors. | Coverage-contract issue. | Manager. | Decide whether Stage 35 must add coverage tests until both floors pass, or whether the contract should be revised or accepted for this merge gate. |
| `run_coverage.ps1` Start-Process path produced no `.cov` files while direct OpenCppCoverage worked. | Tooling gap, secondary. | Developer if Manager opens a tooling fix. | Does not hide F35-QA-02 because direct OpenCppCoverage produced usable markdown, XML, HTML, and `.cov` evidence. |

Rejected classifications:

- Product bug: no failing functional row or bad runtime behavior remains in the
  reviewed reports.
- Test gap owned directly by Developer: adding more tests may be one Manager
  decision, but the immediate failure is the already-defined coverage floor.
- Acceptable without Manager decision: Part 40 and the T114/T114a contract make
  the row required when feature-mode files changed.
- Blocker: coverage tooling was available, PDBs were present, and direct
  OpenCppCoverage produced usable evidence.

## Evidence basis

Part 40 requires TP-35-COV-01 when feature-mode source files change. Its pass
signal cites markdown combined, product-only, and per-file coverage blocks and
uses the T114/T114a/T115-style thresholds.

The main test plan says Stage 11 onward splits the coverage contract into
combined T114 >= 0.80 and product-only T114a >= 0.70. Both are closure
contracts when present in a stage plan.

The rerun's markdown report uses the current 16-file denominator:

- 11 product files.
- 5 current focused test files.
- Retired async-only Step 6, Step 7, and Step 11 targets are no longer in the
  active coverage target set after F35-QA-FIX-01.

Product-only coverage is low enough that this is not a rounding or citation
issue. The largest low-rate rows are current product files, especially
`server-cache-hybrid.cpp` at 0.5178, `server-cache-io-worker.cpp` at 0.4535,
`server-cache-graph.h` at 0.1, and `server-cache-controller.h` at 0.4.

## Owner and retest scope

No product bug owner is assigned from this review.

Next owner is Manager because the open decision is about the Stage 35 coverage
contract:

- Option A: require Developer to add or restore current, meaningful coverage
  until both T114 and T114a floors pass, then QA reruns TP-35-COV-01.
- Option B: revise the Stage 35 coverage contract or denominator and send QA
  back for a focused rerun under the revised contract.
- Option C: accept the below-threshold coverage as a Manager exception for this
  merge gate and record the residual coverage debt before closure.

If Manager chooses Option A, Developer retest scope should stay focused on
coverage work unless production code changes:

1. Add current focused coverage for uncovered product paths, primarily
   `server-cache-hybrid.cpp` and other low-rate product files.
2. Rebuild the Stage 35 corrected coverage target set in `build-stage35-qa`.
3. Rerun TP-35-COV-01 and cite the markdown combined, product-only, and per-file
   blocks.
4. Rerun prior functional Stage 35 rows only if production cache behavior
   changes.

If Manager chooses a tooling fix for the wrapper issue, retest only the wrapper
path until `run_coverage.ps1` produces `.cov` files. That tooling fix alone
does not satisfy TP-35-COV-01 unless the markdown coverage rates also pass or
Manager changes the threshold contract.

## Handoff

Stage 35 QA remains open. F35-QA-01 compile drift is closed. F35-QA-02 is
measured and below threshold.

Next gate: Manager coverage-contract decision. Commit, push, PR, merge abort,
and reviewer response remain blocked unless separately requested.
