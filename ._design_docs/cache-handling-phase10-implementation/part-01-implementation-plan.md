# Stage 10 implementation plan - Part 1

Source: [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)

## Status

Planning date: 2026-06-02
Plan state: drafted for Architect review and Manager implementation-plan gate.
Implementation state: closed.
QA execution state: closed.

## Accepted design baseline

Implement Stage 10 against the accepted design in
[cache-handling-phase10-design.md](../cache-handling-phase10-design.md), Parts
01 through 03, plus the Manager design gate in
[part-04-manager-design-gate.md](../cache-handling-phase10-design/part-04-manager-design-gate.md).

Binding decisions:

- Hybrid mode remains opt-in.
- Legacy cache behavior stays unchanged when hybrid mode is disabled.
- Exact blobs, checkpoints, target/draft pairing, metadata-only nodes, cold
  payloads, protected roots, and workload profiles keep the contracts closed in
  Stages 1 through 9.
- Stage 10 does not add a new cache algorithm or a public cache inspection
  endpoint.
- Metrics and diagnostics must use bounded labels and safe fields only.
- Cold-store paths, descriptors, request markers, and unsupported configuration
  combinations must fail safely.
- Benchmark and stress evidence must prove correctness before performance is
  used as acceptance evidence.
- Operator behavior must be documented in durable project docs.

## Affected code and documentation surfaces

Primary implementation surfaces to inspect and, if needed, change:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-store-cold.h`
- `tools/server/server-cache-store-cold.cpp`
- `tools/server/server-cache-io-worker.h`
- `tools/server/server-cache-io-worker.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-metrics.cpp`
- `tools/server/server-task.h`
- `tools/server/server.cpp`
- `tools/server/README.md`
- `tools/server/README-dev.md`
- `tools/server/bench/README.md`
- `tools/server/tests/README.md`
- `._design_docs/cache-handling-test-plan.md` and split Stage 10 test-plan
  part, if QA planning opens later

Expected focused test surfaces:

- `tests/test-cache-controller.cpp`
- `tests/test-step10-metrics.cpp`
- `tests/test-step12-branch-graph.cpp`
- `tests/test-step13-stage8.cpp`
- `tests/test-step6-demotion-protocol.cpp`
- `tests/test-step7-promotion-protocol.cpp`
- `tests/test-step11-test-hooks-fault-injection.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- a Stage 10 benchmark or stress harness only if existing targets cannot
  collect repeatable evidence

## Minimal-intrusion rule for 10-01

R107 has two meanings in the requirements set. Stage 10 must satisfy both:

- R107 minimal intrusion: keep the default legacy cache path structurally intact
  and route alternate behavior through the hybrid controller, metrics exporter,
  validation helpers, and test seams.
- R107 coverage: prove at least 80% coverage for the hybrid-mode code paths
  listed in Part 2.

Any touched legacy cache path must be justified before code work starts. The
allowed reasons are:

- startup validation must reject an unsafe hybrid configuration before the
  legacy request path accepts work
- the shared metrics exporter must expose hybrid metrics through the existing
  `/metrics` surface
- the shared request parser must validate an accepted cache marker before it can
  reach cache policy
- the shared slot or prompt-processing handoff must preserve existing legacy
  behavior while passing already normalized hybrid metadata
- a test seam is required to prove hybrid behavior without changing production
  legacy behavior

The implementation log must record every touched legacy file with one of those
reasons. If a change cannot fit one reason, stop and request design or Manager
review.

## Ordered implementation steps

1. Audit existing Stage 1 through 9 metrics and diagnostics against R61-R68.
   List missing counters, gauges, labels, and structured log events before
   editing code.
2. Add or complete bounded metric emission for exact hits, checkpoint restores,
   promotions, demotions, evictions, branch pruning, protected-root decisions,
   fallback, restore failures, marker validation, descriptor integrity failures,
   unsupported configurations, cold-store validation, branch validation,
   re-materialization, byte gauges, cold latency, and queue pressure.
3. Add structured diagnostics for unsupported configurations, marker decisions,
   descriptor rejection, cold-store root validation, promotion, demotion,
   eviction, cleanup failure, protected-root pressure, branch pruning,
   metadata-only retention, fallback, and integrity failure.
4. Harden startup validation for hybrid cache flags, hot payload budget, branch
   metadata budget, cold-store root, cold budget if present, eviction policy,
   policy parameters, and unsupported multimodal, draft, or workload-profile
   combinations.
5. Harden request-provided cache marker handling if any marker surface is
   enabled. Enforce size, encoding, allowed characters, enum values, normalized
   internal form, and safe diagnostics.
6. Harden cold-store path handling: canonical root retention, root containment,
   path-safe internal payload names, staging-file containment, pre-operation
   containment checks, permission warning or rejection, and sanitized path
   diagnostics.
7. Harden descriptor and restore validation before promotion, demotion,
   eviction, restore, or deletion. Re-check owner, namespace, profile, pair
   state, speculative identity, payload kind, residency, size, checksum,
   metadata-only validation, and paired target/draft availability.
8. Add abuse and pressure tests for repeated invalid markers, tiny budgets, hot
   pressure without cold storage, cold pressure, branch-metadata pressure, large
   forests, promotion queue pressure, shutdown with pending work, repeated
   integrity failures, and unsupported runtime shapes.
9. Add repeatable benchmark collection for exact hits, checkpoint hits, cold
   transitions, and end-to-end savings. Use the evidence-source categories in
   Part 2.
10. Add deterministic seams or use existing seams for clocks, usage updates,
    fake stores, worker completion order, branch lookup tie-breaking, mismatch
    selection, and seeded stress input.
11. Collect hybrid path coverage with the Part 2 denominator. Record exclusions
    and touched legacy path justifications in the implementation log.
12. Update operator docs for flags, budgets, cold-store setup, workload
    profiles, exact and checkpoint restore behavior, protected roots, accepted
    marker surface, metrics, diagnostics, benchmark reproduction, security
    limits, and unsupported configurations.
13. Update the implementation log after each completed step with changed files,
    behavior, tests, benchmark or coverage evidence, failures, and remaining
    risks.

## Operator documentation plan

Update durable docs, not only design notes or test reports:

- `tools/server/README.md`: user-facing flags, budgets, cold-store setup,
  workload profiles, metrics, diagnostics, and unsupported configurations.
- `tools/server/README-dev.md`: developer-facing architecture notes,
  deterministic seams, metrics ownership, and security review scope.
- `tools/server/bench/README.md`: repeatable benchmark setup, measurement
  windows, warmup, models or fixtures, and reporting format.
- `tools/server/tests/README.md`: focused and public evidence rules for Stage
  10 tests once QA planning opens.
- `._design_docs/cache-handling-test-plan.md`: add a Stage 10 QA plan only
  when QA planning is explicitly opened.

## Handoff state

Implementation planning is drafted. Production code, test code, benchmark
execution, coverage execution, security review execution, and QA execution stay
closed until the plan passes the required reviews.
