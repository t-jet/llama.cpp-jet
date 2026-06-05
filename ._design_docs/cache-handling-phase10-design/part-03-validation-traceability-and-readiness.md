# Stage 10 design: validation, traceability, and readiness -- Part 3

Source: [../cache-handling-phase10-design.md](../cache-handling-phase10-design.md)

## Benchmark design

Stage 10 benchmarks must be repeatable and must compare hybrid mode against the
legacy or hybrid-disabled baseline where the scenario supports it.

Required benchmark groups:

| Benchmark | Required measurement |
| --- | --- |
| Exact blob hit rate | Accepted exact hits, rejected candidates, fallback count, prompt-processing time saved, and resident bytes. |
| Checkpoint hit rate | Accepted checkpoint hits, restore strategy, profile, pair state, re-materialization count, and prompt-processing time saved. |
| Cold transition frequency | Demotions, promotions, evictions, cold queue pressure, cold operation latency, and fallback after promotion failure. |
| End-to-end savings | Request latency or prompt-processing duration before and after hybrid reuse for representative branch-heavy and checkpoint-dependent workloads. |

Benchmarks must document:

- model or fixture identity without leaking local paths in public reports
- prompt shape and branch pattern
- hybrid cache flags and budgets
- workload profile
- cold-store enabled or disabled
- number of slots and concurrency level
- warmup and measurement windows
- metrics used for calculations

Benchmark results are acceptance evidence only if they show correctness first.
A performance regression can be accepted only with a documented reason and a
manager decision.

## Stress-test design

Required stress scenarios:

- hot payload budget exhaustion with exact blobs and checkpoints competing
- branch-metadata budget exhaustion with protected roots and metadata-only nodes
- cold-store capacity or write failure pressure
- concurrent multi-slot traversal of shared branch nodes
- concurrent restore attempts for the same hot and cold payloads
- large branch forests with repeated mismatch-parent selection
- repeated re-materialization and equivalent-branch deduplication
- target plus draft promotion, demotion, restore, eviction, and fallback under
  pressure
- unsupported or degraded configurations under request load
- metrics and log volume under repeated fallback and integrity failures

Stress tests may use focused C++ harnesses, fake stores, and deterministic
workers when public HTTP evidence would be too slow or unstable. Public task-flow
evidence remains required for operator-visible metrics, startup validation, and
request marker behavior.

## Deterministic test behavior

Stage 10 tests must avoid uncontrolled timing and background activity when the
result depends on ordering.

Required deterministic seams:

- injected clock for LRU, latency buckets, and benchmark windows
- deterministic usage updater
- fake hot and cold stores with configured success, failure, delay, and capacity
- deterministic I/O worker completion order
- fixed branch-lookup tie-breaking
- fixed mismatch-parent selection tie-breaking
- controlled random seed if any fuzz or randomized stress input is used
- direct stats access in focused tests when public Prometheus metrics do not
  expose an internal controller state

Rows that rely on internal stats must say so in the test plan. Public metrics
cannot be claimed for values that only exist in the controller or focused test
harness.

## Coverage target

Stage 10 closes R107 by requiring at least 80% coverage for hybrid-mode code
paths. The implementation plan must define the coverage tool and denominator
before code work starts.

Coverage scope must include, at minimum:

- hybrid mode gate and legacy-disabled path checks
- exact blob save, lookup, restore, and fallback
- checkpoint save, lookup, restore, and fallback
- protected-root decisions
- payload descriptor validation
- hot and cold residency transitions
- branch pruning and metadata-only retention
- mismatch validation and re-materialization
- target/draft pair handling
- request marker validation if enabled
- observability emission paths for required metrics and diagnostics
- cold-store path and integrity failure handling

Coverage may exclude generated files, third-party code, unreachable platform
branches with documented rationale, and legacy-only paths outside the hybrid
mode. Exclusions must be listed in the implementation evidence and reviewed
before Stage 10 can close.

## Operator documentation requirements

Stage 10 must update durable operator documentation. Test reports can reference
that documentation, but they cannot be the only place where operator behavior is
described.

Required topics:

- enabling and disabling hybrid cache mode
- hot payload, branch metadata, and cold-store budget tuning
- cold-store root selection, permissions, cleanup expectations, and restart
  limits
- workload profiles and how the server selects them
- exact blob versus checkpoint restore behavior
- protected-root behavior and any accepted request marker surface
- metrics names, labels, and interpretation
- structured diagnostic events and common failure reasons
- deterministic and benchmark evidence operators can reproduce locally
- security limitations and unsupported configurations
- explicit exclusions: no generated-output replay, no distributed cache, no
  cross-restart cold restore guarantee, and no public cache inspection endpoint

## Requirement traceability

| Requirement | Stage 10 disposition |
| --- | --- |
| R61-R68 | Covered by the completed metric and diagnostic audit across hits, restores, promotions, demotions, evictions, branch pruning, protected roots, fallback, and failures. |
| R99-R106 | Covered through regression coverage for earlier-stage behavior, including non-destructive hits, protected roots, boundaries, cold exact blobs, cold checkpoints, target plus draft pairing, safe fallback, and checkpoint-dependent behavior. |
| R107 | Covered by the 80% hybrid path coverage requirement and reviewed coverage denominator. |
| R121 | Covered by explicit diagnostics for unsupported configurations, restore failures, residency mismatches, integrity problems, and marker validation. |
| R122 | Covered by descriptor and cold-format version validation during hardening. |
| R123-R123a | Covered by deterministic test seams and fixed tie-breaking evidence. |
| R124 | Covered by explicit configuration validation, logs, metrics, and operator documentation for alternate-mode behavior. |
| R125-R129 | Covered by focused harnesses, fake stores, deterministic integration tests, and observable correctness checks. |
| R130-R131 | Constrained. Stage 10 implementation planning must avoid broad rewrites and duplicated policy, serialization, residency, or restore logic. |
| R132-R133 | Covered by the focused OWASP review, cold-store hardening, descriptor validation, marker validation, and abuse-case review. |

Requirements not listed here remain governed by earlier accepted stage designs
and must be covered by Stage 10 regression evidence where they are part of a
production-readiness path.

## Exclusions and deferrals

Stage 10 does not include:

- generated-output replay
- distributed cache or cross-process coherence
- cross-restart cold restore guarantees
- public cache inspection or control endpoints
- replacing legacy cache behavior
- a new workload-profile selector controlled by clients
- new eviction policy families
- feature work that is not needed for observability, hardening, performance
  evidence, deterministic testing, coverage, or operator documentation

No Stage 10 requirement is intentionally deferred. If implementation planning
finds a production-readiness item that cannot be completed, the plan must record
it as an open blocker or request a manager scope decision.

## Risks

| Risk | Impact | Required mitigation before implementation approval |
| --- | --- | --- |
| Metrics are complete in focused tests but incomplete in public Prometheus output. | Operators cannot diagnose production behavior. | Separate public metrics evidence from internal stats evidence in the test plan. |
| Security review finds broad design gaps. | Stage 10 cannot close as production ready. | Record each item with owner, mitigation, and re-review requirement before implementation approval. |
| Coverage denominator is chosen too narrowly. | R107 can pass without covering real hybrid paths. | Define hybrid path coverage scope before code work and review exclusions explicitly. |
| Benchmarks are nondeterministic or fixture-bound. | Performance claims cannot be trusted. | Use fixed scenarios, deterministic clocks where possible, and repeatable model or fixture notes. |
| Operator docs drift from implementation flags or metrics. | Operators receive wrong guidance. | Treat documentation updates as required implementation evidence, not as a follow-up. |

## Review readiness

The Stage 10 design is reviewable when:

- the entry document and all part files stay under 300 lines
- `document-index.md` links the Stage 10 design
- the design keeps implementation, manager, and QA gates closed
- observability, security, hardening, benchmarks, stress tests, determinism,
  coverage, operator docs, traceability, exclusions, and risks are explicit
- no durable behavior change exists only in a test report

Current state: ready for independent Architect design review.
