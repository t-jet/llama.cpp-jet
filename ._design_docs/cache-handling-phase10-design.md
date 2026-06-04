# Stage 10 design: observability, security review, and hardening

Status: Design and Manager design gates passed; implementation re-review PASS; QA CLOSED
Date: 2026-06-02
Stage: 10 (Observability, security review, and hardening)
Prerequisite Stage: 9 (Checkpoint integration and workload profiles) -- CLOSED

## Scope

Stage 10 closes the production-readiness work for the alternate hybrid cache
mode. It completes observability, records a focused security review, hardens
externally influenced inputs and cold-store file handling, defines benchmark and
stress evidence, verifies deterministic tests and 80% hybrid path coverage, and
requires operator documentation.

This design covers the Stage 10 behavior contract only. It does not approve
implementation planning, code work, QA execution, commits, PR text, or reviewer
responses.

## Prerequisites

- Stage 1: Hybrid cache controller and non-destructive exact saves/loads (CLOSED)
- Stage 2: Compatibility namespace and task metadata transport (CLOSED)
- Stage 3: Exact blob cache and usage tracking (CLOSED)
- Stage 4: Byte-accounted hot payload LRU with protected roots (CLOSED)
- Stage 5: Payload descriptor separation and target/draft pairing (CLOSED)
- Stage 6: Cold payload storage and asynchronous I/O (CLOSED)
- Stage 7: Branch forest, namespace validation, slot references, metadata accounting, and global hot-payload LRU (CLOSED)
- Stage 8: Metadata-only nodes, re-materialization, mismatch handling, equivalent-branch deduplication, and cold cleanup safety (CLOSED)
- Stage 9: Checkpoint integration and workload profiles (CLOSED)

## Assumptions

- Hybrid mode remains opt-in and legacy cache behavior remains unchanged when
  hybrid mode is disabled.
- Stage 9 closure leaves no open product bug, QA harness blocker, environment
  blocker, or accepted public-evidence limit.
- Stage 6 cold-store integrity and path constraints exist, but full OWASP review
  for R132/R133 is still deferred to Stage 10.
- Deterministic seams for clocks, usage updates, stores, graph lookup, and I/O
  worker outcomes are already part of earlier stage contracts and must be used
  for Stage 10 evidence.

## Non-goals

- Replacing the current cache implementation as the default behavior
- Cross-restart cold restore guarantees
- Distributed cache service or cross-process cache coherence
- Public cache inspection or control endpoints
- Generated-output replay
- New eviction policy families beyond validating the existing public policy
  surface
- Broad refactors unrelated to observability, hardening, performance evidence,
  deterministic testing, coverage, or operator documentation

## Contents

- [Part 1: Scope, surfaces, and prerequisites](cache-handling-phase10-design/part-01-scope-surfaces-and-prerequisites.md)
- [Part 2: Observability, security, and hardening](cache-handling-phase10-design/part-02-observability-security-and-hardening.md)
- [Part 3: Benchmarks, coverage, documentation, traceability, and readiness](cache-handling-phase10-design/part-03-validation-traceability-and-readiness.md)
- [Design review gate 01](cache-handling-phase10-design/design-review-gate-01.md)
- [Part 4: Manager design gate](cache-handling-phase10-design/part-04-manager-design-gate.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 9 closure prerequisite | PASS |
| Stage 10 design authoring | PASS |
| Stage 10 independent design review | PASS (see [review gate 01](cache-handling-phase10-design/design-review-gate-01.md)) |
| Stage 10 manager design gate | PASS (see [part 4](cache-handling-phase10-design/part-04-manager-design-gate.md)) |
| Stage 10 implementation planning | PASS |
| Stage 10 implementation | PASS after S10-IMPL-01 correction |
| Stage 10 QA execution | CLOSED |

## Handoff

The Stage 10 design is approved. Implementation planning passed, and
implementation re-review passed after the S10-IMPL-01 correction.

Part 10 of the implementation log records the Architect implementation
re-review PASS for the public Stage 10 Prometheus metric shape. QA execution
remains closed.
