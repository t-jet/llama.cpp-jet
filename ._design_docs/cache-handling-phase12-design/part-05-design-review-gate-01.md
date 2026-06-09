VERDICT: REWORK

# Stage 12 design review gate 01

Date: 2026-06-07
Reviewer: Architect
Scope: Stage 12 design deliverable only

## Scope and gate status

Reviewed:

- [../cache-handling-phase12-design.md](../cache-handling-phase12-design.md)
- [part-01-scope-prerequisites-interfaces.md](part-01-scope-prerequisites-interfaces.md)
- [part-02-stress-scenarios-and-config-matrix.md](part-02-stress-scenarios-and-config-matrix.md)
- [part-03-benchmarks-baselines-and-legacy.md](part-03-benchmarks-baselines-and-legacy.md)
- [part-04-observability-testability-traceability.md](part-04-observability-testability-traceability.md)
- [../document-index.md](../document-index.md)

Review references:

- [../cache-handling-architecture.md](../cache-handling-architecture.md)
- [../cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md](../cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md)
- [../cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md](../cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md)
- [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)
- [../cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md](../cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md)
- [../cache-handling-phase11-implementation/part-23-stage11-mtp-cap-fix-implementation-review.md](../cache-handling-phase11-implementation/part-23-stage11-mtp-cap-fix-implementation-review.md)
- [../cache-handling-phase11-implementation/part-27-stage11-fix-l-closure-decision.md](../cache-handling-phase11-implementation/part-27-stage11-fix-l-closure-decision.md)
- [../.test_reports/test-report-20260604-06.md](../.test_reports/test-report-20260604-06.md)
- [../.test_reports/test-report-20260606-01.md](../.test_reports/test-report-20260606-01.md)
- [../.test_reports/test-report-20260606-02.md](../.test_reports/test-report-20260606-02.md)
- [../cache-handling-test-plan/part-12-stage10-observability-security-hardening.md](../cache-handling-test-plan/part-12-stage10-observability-security-hardening.md)
- [../cache-handling-test-plan/part-13-t114-product-only-coverage.md](../cache-handling-test-plan/part-13-t114-product-only-coverage.md)

Gate verdict: REWORK. Stage 12 design cannot move to Manager design gate until the finding below is corrected.

## Finding

| ID | Severity | Finding | Evidence | Required correction |
| --- | --- | --- | --- | --- |
| S12-DESIGN-01 | BLOCKER | The Stage 12 starting baseline is stale. The design says Stage 12 starts from the Stage 11 closure on `6e3aa045c` and treats Stage 11 as closed, but later Stage 11 follow-up records changed speculative decode behavior on HEAD `02db7a768`. The cap-fix cycle is not fully closed: `test-report-20260606-01.md` leaves T-MTP-FIX-01 PENDING_OPERATOR and T114/T114a BLOCKED; `part-27-stage11-fix-l-closure-decision.md` closes only fix L and says full Stage 11 follow-up closure awaits cap-fix repro. This is a prerequisite gap for Stage 12 stress and benchmark design because Stage 12 explicitly covers draft/MTP, mixed workload profiles, long-run stability, legacy comparison, T114/T114a/T115/T121 carry-forward, and speculative behavior under load. | Entry doc "Starting evidence baseline"; Part 1 "Prior-stage contracts" and "Closure prerequisites"; Part 2 draft/MTP and mixed-profile matrix; Part 3 benchmark draft/MTP and legacy comparison; Part 4 T114/T114a/T115/T121 traceability. Latest Stage 11 follow-up evidence: `part-19`, `part-23`, `part-27`, `test-report-20260606-01.md`, and `test-report-20260606-02.md`. | Update the Stage 12 design baseline and prerequisites to account for post-closure Stage 11 follow-up state. The correction must name the current validated baseline, distinguish closed fix L from the open cap-fix cycle, and state whether Stage 12 execution/planning is blocked until T-MTP-FIX-01 plus cap-fix T114/T114a are resolved, or whether a Manager-approved narrowing lets Stage 12 proceed with explicit exclusions. The correction must also update the configuration matrix, evidence rules, and closure prerequisites if draft/MTP rows or coverage rows are narrowed. |

## Decisions

Architecture scope is otherwise preserved. The design keeps Stage 12 as an operational validation stage and does not invent new behavior, endpoints, flags, metrics, or test results.

The stress scenarios, benchmark scenarios, configuration matrix, long-run checks, baseline report, tuning report, legacy comparison, observability rules, evidence-source split, and traceability are shaped correctly once the prerequisite baseline is fixed.

No code, tests, commits, PR text, or reviewer-response work is authorized by this review.

## Required corrections

Before re-review:

- Update the entry doc status, starting evidence baseline, current gate, stage gate, and handoff to reflect this REWORK verdict.
- Update Part 1 closure prerequisites so Stage 12 cannot open execution or planning from stale `6e3aa045c` evidence if later Stage 11 follow-up behavior remains open.
- Update Parts 2 through 4 wherever draft/MTP, cap-fix, coverage, or fixture evidence rules depend on the latest Stage 11 follow-up state.
- Update document-index status text after the corrected design is ready for re-review.

## Handoff

State: REWORK. Owner: design author. Next gate: Architect design re-review after correction. Manager design gate remains closed.
