# Stage 32 design review 2026-06-30

VERDICT: PASS

## Scope and gate status

Review subject:

- `._design_docs/cache-handling-phase32-design.md`

Inputs checked:

- `._design_docs/document-index.md`
- `._design_docs/.manager-inputs/manager-input-20260629-stage32-fix-stage31-and-rerun-comparison.md`
- `._design_docs/cache-handling-phase31-design.md`
- `._design_docs/cache-handling-phase31-implementation.md`
- `._design_docs/cache-handling-phase31-implementation/part-06-manager-closure-20260629.md`
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`
- `._design_docs/.test_reports/test-report-20260629-13-stage31-01.md`
- `._design_docs/.test_reports/test-report-20260629-13-stage31-01-developer-review.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-architecture/part-01-method.md`
- `._design_docs/cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `._design_docs/cache-handling-architecture/part-03-api-endpoint-compatibility.md`
- `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-requirements/part-01-status.md`
- `._design_docs/cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`

Gate status: Stage 32 design is ready for Developer planning. QA can execute after Developer records the exact command line, paths, and any narrow evidence extractor changes allowed by the design.

## Decisions

| Check | Decision |
| --- | --- |
| Architecture and requirements traceability | PASS. The design traces to the hybrid-cache requirements for opt-in behavior, non-destructive shared reuse, fail-safe correctness, observability, benchmarkability, and API-compatible `/metrics` exposure. |
| Stage 31 baseline correctness | PASS. The design correctly treats Stage 31 as closed PASS, keeps the full live rerun advisory for Stage 31 closure, and opens Stage 32 only for live comparison confidence. |
| Contradiction risk | PASS. The design does not reopen Stage 31, does not strand durable behavior in test reports, and does not permit product-code edits before live evidence or Developer planning identifies a missing evidence hook. |
| Scope and non-goals | PASS. Debug-only const-mutex build repair, pre-existing `%zu` Release warnings, and response caching are excluded with enough detail. |
| Evidence requirements | PASS. The design requires per-request `cache_hit`, `cache_n`, summary or metrics hit deltas, namespace gauge checks, bounded-label grep, HELP/TYPE counts, output equivalence, cold-store counters, and server-log checks. |
| Performance criteria | PASS. Stage 30 cold-cycle values are the baseline, with explicit RAM and throughput thresholds plus PARTIAL and FAIL handling. |
| Wall-clock budget | PASS. The 150 minute reserve and 180 minute extension match the Stage 30 timing evidence and avoid the prior 60-90 minute cap. |
| Stale-binary rules | PASS. The design requires clean Release build proof, binary metadata, CUDA proof when applicable, and a BLOCKED-stale-binary classification if the binary predates the Stage 31 source changes. |
| Failure handling | PASS. Zero reuse, high namespace cardinality, metric shape failures, and performance regressions all have explicit classification and artifact preservation rules. |
| Developer and QA readiness | PASS. The design identifies the driver, workload, run shape, artifacts, post-processing needs, and report rows. Developer still must write exact command lines and paths as the next gate, which the design explicitly requires. |

## Findings

No blocking or non-blocking findings.

## Notes

- The reused driver API matches the design's main parameters: `RunId`, `RunRoot`, `ReportPath`, `CacheColdPath`, `Cycles`, `OutputEquivalencePrompts`, `LlamaServerPath`, `ContextSize`, `Parallel`, `Seed`, and `RequestCount`.
- The driver already emits `cache_n`, `cache_n_ratio`, `cache_hit`, `summary.json`, per-leg metrics snapshots, and an underscore-form metric regression check. Stage 32 post-processing can stay additive.
- The workload library supports `SizeClass` values including `2k`, and emits the expected `exact`, `near_prefix`, and `new_branch` classes.

## Required corrections

None.

## Handoff

Ready for Developer planning. Developer should record exact command lines, binary paths, run paths, build proof, and any evidence-only post-processing before QA execution opens.
