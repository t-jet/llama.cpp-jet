# Stage 12 design: scope, prerequisites, assumptions, interfaces, and constraints -- Part 1

Source: [../cache-handling-phase12-design.md](../cache-handling-phase12-design.md)

## Goal

Stage 12 validates the closed hybrid-cache implementation at production
scale. It proves that hybrid mode stays correct under sustained pressure
and records benchmark baselines that future stages can use for
regression detection.

Stage 12 is not a feature stage. It defines operational evidence: what
to run, what to measure, how to compare it to legacy mode, and how to
report bottlenecks.

## Scope carried forward from the architecture

The architecture defines Stage 12 as stress testing and benchmarking.
The design keeps the architecture scope as the baseline.

Architecture deliverables the design must support:

- Stress scenarios: budget exhaustion, concurrent multi-slot access,
  large branch forests, prompt storms, mixed workload profiles
- Benchmark scenarios: exact-blob hit rate, checkpoint hit rate, cold
  transition frequency, end-to-end token throughput, restore latency
- Configuration matrix: `--cache-ram`, slot count, model size, context
  length, draft presence, workload profile
- Long-run checks: memory stability, file descriptor usage, metric
  counter stability over multi-hour runs
- Baseline numbers for regression detection in later runs
- Bottleneck and tuning report for operators

Architecture exit criteria the design must support:

- No crashes, leaks, or unbounded resource growth under stress
- Hybrid mode shows measurable gains on the configured benchmarks
- Baselines recorded for future comparison
- Bottlenecks and tuning notes are documented
- Legacy mode performance is unaffected

## Prior-stage contracts Stage 12 must preserve

Stage 12 measures behavior without weakening any prior contract.

| Contract | Source | Stage 12 validation use |
| --- | --- | --- |
| Hybrid mode remains opt-in | Stage 1, architecture R1-R4 | All hybrid rows pass `--cache-mode hybrid`; legacy rows omit it or pass `--cache-mode legacy`. |
| Legacy default path unchanged | Stage 1, R107 | Every benchmark family has a legacy baseline. Legacy failures block closure. |
| Compatibility namespace includes workload and draft identity | Stage 2, Stage 5, Stage 7, Stage 9 | Mixed workload and draft matrix rows must not reuse incompatible entries. |
| Target and draft payloads move as a pair | Stage 5 | Draft-present rows compare target-only, separate-draft, and MTP behavior without accepting partial paired restore. |
| Byte-accounted hot payload budget | Stage 4 | Budget exhaustion rows measure resident payload bytes and eviction churn against `--cache-ram`. |
| Cold payload promotion and demotion | Stage 6 | Cold-transition benchmark rows measure demotion frequency, promotion latency, and async-miss behavior. |
| Shared branch forest and global budgets | Stage 7 | Large-forest and multi-slot rows check that namespaces share budget without cross-namespace restore. |
| Metadata-only retention and re-materialization | Stage 8 | Large-forest rows check rematerialization attempts, validation mismatch handling, and metadata budget pressure. |
| Checkpoint payloads and workload profiles | Stage 9 | Checkpoint benchmarks separate plain-transformer and checkpoint-dependent profiles. |
| Public metrics and bounded diagnostics | Stage 10 | Stress and benchmark evidence uses public `/metrics` and bounded logs where possible. |
| T114/T114a/T115/T121 closure contracts | Stage 10, Stage 11, test plan Parts 12 and 13 | Stage 12 closure keeps the coverage and public checkpoint rows current; missing tools are setup blockers, not accepted skips. |

## Stage 11 follow-up baseline

Stage 12 starts from two Stage 11 states, and the design keeps them
separate:

- The original upstream-merge closure is PASS at `6e3aa045c`.
- The post-closure follow-up baseline is HEAD `02db7a768`.

On HEAD `02db7a768`, fix L is closed by the Stage 11 fix L closure
decision. The cap-fix cycle is still open: T-MTP-FIX-01 is
`PENDING_OPERATOR`, and cap-fix T114/T114a remain `BLOCKED` on coverage
tooling. Those rows cover draft/MTP and coverage evidence that Stage 12
would otherwise stress, benchmark, or carry forward.

Stage 12 implementation planning, QA planning, stress execution,
benchmark execution, and closure cannot open while those cap-fix rows
remain unresolved, unless the Manager approves narrowing before
execution opens. Narrowing must exclude affected draft, MTP, cap-fix, and
coverage rows from Stage 12 scope and must state which baseline,
stress, benchmark, traceability, and closure rows no longer apply.

## Interfaces under validation

Stage 12 observes existing interfaces only.

| Interface | Use in Stage 12 |
| --- | --- |
| CLI flags | `--cache-mode`, `--cache-ram`, `--parallel`, `--ctx-size`, `--model`, draft/MTP flags, `--cache-cold-path`, and existing server flags needed for metrics. |
| Public HTTP API | `/completion` or existing generation endpoint used by prior test reports, `/metrics`, `/health`, and any existing endpoint already used by the test plan. |
| Public Prometheus metrics | Cache hit, miss, restore, fallback, payload transition, payload eviction, protected-root, checkpoint, diagnostic, byte, and latency rows exposed by Stage 10. |
| Structured logs | Bounded diagnostic events and server lifecycle logs. Logs must not expose prompt text, local paths in public summaries, payload bytes, checksums, or serialized state. |
| Focused test binaries | Only for preflight, correctness gates, and evidence-source classification when public HTTP cannot create a precondition. |
| Test report artifacts | Coverage report, benchmark report, stress report, metrics snapshots, load-tool output, server stdout/stderr, and resource samples. |

Stage 12 does not define a new interface. If execution needs a new
metric, helper, script flag, or endpoint, that is a design correction or
a later implementation-plan item, not an implicit Stage 12 approval.

## Constraints

1. Correctness comes before performance. Any benchmark row that cannot
   prove output correctness or safe fallback cannot claim a performance
   gain.
2. Legacy mode is the control. Legacy performance, public surface, and
   correctness remain closure criteria.
3. Model-backed evidence is required for production-facing throughput,
   restore latency, exact-hit, checkpoint-hit, and prompt-storm claims.
4. Focused evidence may support internal preconditions, but public
   operator claims need live server metrics or logs.
5. All long-run rows record resource samples at fixed intervals.
6. All benchmark rows record warmup window, measurement window, request
   mix, seed or prompt generator, model fixture, hardware, build type,
   and dirty worktree state.
7. Missing tools, missing models, or insufficient runtime are `BLOCKED`
   setup failures unless the Manager narrows the stage before execution
   opens.
8. No run-specific results are written into this design.

## Preflight checks before execution can open

The implementation or QA plan must record these checks before any
stress or benchmark run starts:

- Clean build from the exact commit under test.
- `llama-server` binary timestamp and build configuration.
- In-scope focused tests for cache controller, Stage 10 metrics, cold
  store hardening, branch graph, Stage 8, demotion, promotion, fault
  injection, and checkpoint behavior.
- Coverage tool availability for T114 and T114a.
- Cap-fix T-MTP-FIX-01, T114, and T114a resolved, or a Manager-approved
  narrowing record excluding affected draft/MTP/cap-fix/coverage rows.
- Load tool availability and version.
- Model fixture inventory, including at least one plain-transformer
  model and any checkpoint-dependent or draft-capable fixture used.
- Disk path for cold store with enough space and safe root containment.
- Resource sampler for memory, file descriptors or Windows handles,
  process CPU, disk I/O, and server liveness.
- Artifact directory with enough space for multi-hour metrics and logs.

## Closure prerequisites

Stage 12 cannot close unless:

- Stage 11 remains closed or the Manager records a later prerequisite
  decision.
- Stage 11 post-closure follow-up state is terminal for fix L and either
  terminal for cap-fix T-MTP-FIX-01 plus T114/T114a, or explicitly
  narrowed by Manager before execution opens.
- Each required stress row is PASS or has a Manager-approved narrowed
  scope before execution starts.
- Each required benchmark row is PASS or has a Manager-approved narrowed
  scope before execution starts.
- Legacy comparison rows pass.
- Baseline and tuning report sections are complete.
- T114, T114a, T115, and T121 are current on the Stage 12 commit when
  code or test changes are part of the stage.
