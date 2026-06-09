# Stage 12 design: stress testing and benchmarking

Status: Stage 12 CLOSED 2026-06-07; scope-expansion design in part-10; Date: 2026-06-07

Stage 12 CLOSED 2026-06-07. Manager closure decision in cache-handling-phase12-implementation/part-07-stage12-closure-decision.md.

Stage: 12 (Stress testing and benchmarking)
Prerequisite Stage: 11 (Upstream merge integration) -- CLOSED at
`6e3aa045c`; post-closure follow-up on HEAD `02db7a768` has fix L closed
and cap-fix evidence still open

## Scope

Stage 12 validates hybrid mode under sustained load and measures
end-to-end performance against the legacy path. It is an operational
validation stage. It does not add cache features, public endpoints, CLI
flags, metrics, or test execution results.

The architecture defines the Stage 12 scope as a fixed set of
deliverables and exit criteria. This design records the validation
contract, the scenario matrix, the evidence format, and the closure
rules for stress and benchmark work.

This design does not authorize implementation planning, code work, test
execution, benchmark execution, commits, PR text, or reviewer responses.

## Prerequisites

- Stage 1: Hybrid cache controller and non-destructive exact saves/loads
  (CLOSED)
- Stage 2: Compatibility namespace and task metadata transport (CLOSED)
- Stage 3: Exact blob cache and usage tracking (CLOSED)
- Stage 4: Byte-accounted hot payload LRU with protected roots (CLOSED)
- Stage 5: Payload descriptor separation and target/draft pairing
  (CLOSED)
- Stage 6: Cold payload storage and asynchronous I/O (CLOSED)
- Stage 7: Branch forest, namespace validation, slot references,
  metadata accounting, and global hot-payload LRU (CLOSED)
- Stage 8: Metadata-only nodes, re-materialization, mismatch handling,
  equivalent-branch deduplication, and cold cleanup safety (CLOSED)
- Stage 9: Checkpoint integration and workload profiles (CLOSED)
- Stage 10: Observability, security review, hardening, benchmark and
  stress evidence classes, deterministic testing, 80% hybrid path
  coverage, and operator documentation (CLOSED)
- Stage 11: Upstream merge integration (CLOSED at `6e3aa045c`; later
  follow-up baseline is HEAD `02db7a768`)

## Starting evidence baseline

Stage 11 closed with Manager re-closure PASS on commit `6e3aa045c`,
effective from the re-closure commit on top of `dc929d62`. The
authoritative closure evidence is
[test-report-20260604-06.md](.test_reports/test-report-20260604-06.md).
Those closure contract results were:

- T114 combined hybrid-path coverage: 0.8553 PASS
- T114a product-only hybrid-path coverage: 0.7035 PASS
- T115 per-file aggregation: PASS
- T121 public checkpoint admission row: PASS
- ctest, in-scope pytest, k6, OWASP, and Stage 4-9 regression: PASS

Post-closure Stage 11 follow-up state on HEAD `02db7a768` is now part of
the Stage 12 prerequisite baseline:

- Fix L cycle is CLOSED by
  [part-27-stage11-fix-l-closure-decision.md](cache-handling-phase11-implementation/part-27-stage11-fix-l-closure-decision.md)
  and [test-report-20260606-02.md](.test_reports/test-report-20260606-02.md).
- The cap-fix cycle is CLOSED 2026-06-07 per
  [part-29-cap-fix-closure-decision.md](cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md)
  and [test-report-20260607-03.md](.test_reports/test-report-20260607-03.md).
  Cap-fix T114=0.9276 PASS and T114a=0.8418 PASS.
- test-stage10-policy-lru is a pre-existing semantic bug, OUT OF
  CAP-FIX SCOPE, tracked separately as a new stage to be scheduled
  after Stage 12 closure. Source evidence in
  [test-report-20260607-03-developer-review.md](.test_reports/test-report-20260607-03-developer-review.md).

Stage 12 implementation planning, QA planning, stress execution,
benchmark execution, and closure are UNBLOCKED. If a later upstream
merge or post-closure correction changes cache, checkpoint, speculative
decoding, server context, slot, or HTTP behavior before execution opens,
the Manager must decide whether to reopen Stage 11 or update the Stage
12 prerequisite baseline.

## Assumptions

- The local host can run clean builds, focused tests, public HTTP probes,
  long-running server processes, coverage tooling, k6 or an equivalent
  HTTP load tool, and model-backed benchmark fixtures.
- The QA owner can reserve enough wall-clock time for multi-hour runs.
- Legacy mode remains the default. Hybrid mode remains opt-in through
  `--cache-mode hybrid`.
- The benchmark owner records local hardware, model fixtures, build
  configuration, and server flags so future runs can compare results.
- Public Prometheus metrics and bounded diagnostics from Stage 10 remain
  the operator-visible evidence source.

## Non-goals

- Adding or changing cache behavior.
- Adding new public metrics, endpoints, CLI flags, or diagnostics.
- Changing benchmark or stress pass/fail thresholds after execution has
  started.
- Replacing correctness checks with throughput numbers.
- Accepting missing coverage, benchmark tooling, or model fixtures as
  durable skips.
- Producing PR text, reviewer responses, commits, or test reports in this
  design gate.

## Contents

- [Part 1: Scope, prerequisites, assumptions, interfaces, and constraints](cache-handling-phase12-design/part-01-scope-prerequisites-interfaces.md)
- [Part 2: Stress scenarios, configuration matrix, and long-run checks](cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md)
- [Part 3: Benchmark scenarios, baseline, tuning report, and legacy comparison](cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md)
- [Part 4: Observability, testability, evidence, traceability, risks, and handoff](cache-handling-phase12-design/part-04-observability-testability-traceability.md)
- [Part 5: Design review gate 01](cache-handling-phase12-design/part-05-design-review-gate-01.md)
- [Part 6: Design correction for S12-DESIGN-01](cache-handling-phase12-design/part-06-design-correction-s12-design-01.md)
- [Part 7: Design re-review gate 01](cache-handling-phase12-design/part-07-design-re-review-gate-01.md)
- [Part 8: Manager design gate](cache-handling-phase12-design/part-08-manager-design-gate.md)
- [Part 9: Cap-fix closure prerequisite update (2026-06-07)](cache-handling-phase12-design/part-09-cap-fix-closure-prereq-update.md)

## Current gate

Current gate: Stage 12 CLOSED 2026-06-07. Manager handoff in part-09 cap-fix closure prereq + impl part-07 closure decision.

## Stage gate

| Gate | Status |
| --- | --- |
| Stage 11 closure prerequisite | PASS for `6e3aa045c` closure |
| Stage 11 post-closure follow-up baseline | CORRECTED: HEAD `02db7a768`, fix L closed, cap-fix open |
| Stage 12 design authoring | PASS |
| Stage 12 independent design review | REWORK, 2026-06-07 |
| Stage 12 design correction | PASS, 2026-06-07 |
| Stage 12 design re-review | PASS, 2026-06-07 |
| Stage 12 manager design gate | PASS, 2026-06-07 |
| Stage 12 implementation planning | UNBLOCKED 2026-06-07 (Manager cap-fix closure PASS per part-29) |
| Stage 12 implementation | NOT STARTED |
| Stage 12 QA planning | UNBLOCKED 2026-06-07 (Manager cap-fix closure PASS per part-29) |
| Stage 12 stress execution | UNBLOCKED 2026-06-07 (Manager cap-fix closure PASS per part-29) |
| Stage 12 benchmark execution | UNBLOCKED 2026-06-07 (Manager cap-fix closure PASS per part-29) |
| Stage 12 closure | UNBLOCKED 2026-06-07 (Manager cap-fix closure PASS per part-29) |

## Handoff

Manager design gate passed. The next active gate is the Stage 11 cap-fix
prerequisite blocker: T-MTP-FIX-01 plus cap-fix T114/T114a remain open.
Stage 12 implementation planning, QA planning, stress runs, benchmark
runs, and report creation remain closed until those rows close or the
Manager records an explicit narrowing decision before execution opens.
