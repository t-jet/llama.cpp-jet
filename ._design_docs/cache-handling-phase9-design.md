# Stage 9 design: checkpoint integration and workload profiles

Status: Design and Manager design gates passed; ready for implementation planning
Date: 2026-06-01
Stage: 9 (Checkpoint integration and workload profiles)
Prerequisite Stage: 8 (Metadata-only nodes and re-materialization) -- CLOSED

## Scope

Stage 9 promotes checkpoint payloads to first-class branch-node payloads and
adds workload-profile-aware restore planning. Checkpoint-dependent workloads use
checkpoint nodes as the canonical branch structure. Plain-transformer workloads
continue to prefer exact full-state blobs and use checkpoints only when the
planner can prove the checkpoint restore is valid.

This design covers the Stage 9 behavior contract only. It does not approve
implementation planning, code work, test-plan execution, or the Stage 10
hardening work.

## Prerequisites

- Stage 1: Hybrid cache controller and non-destructive exact saves/loads (CLOSED)
- Stage 2: Compatibility namespace and task metadata transport (CLOSED)
- Stage 3: Exact blob cache and usage tracking (CLOSED)
- Stage 4: Byte-accounted hot payload LRU with protected roots (CLOSED)
- Stage 5: Payload descriptor separation and target/draft pairing (CLOSED)
- Stage 6: Cold payload storage and asynchronous I/O (CLOSED)
- Stage 7: Branch forest, namespace validation, slot references, metadata accounting, and global hot-payload LRU (CLOSED)
- Stage 8: Metadata-only nodes, re-materialization, mismatch handling, equivalent-branch deduplication, and cold cleanup safety (CLOSED)

## Assumptions

- Stage 8 branch nodes can remain payload-bearing or metadata-only without
  breaking lookup, traversal, or descendant reachability.
- Payload descriptors remain singularly owned by one branch node.
- Target/draft pair state and richer speculative-mode compatibility keys from
  Stage 5 remain authoritative for all checkpoint payload operations.
- Cold promotion and demotion for descriptor-owned payloads already preserve
  pair integrity and version or checksum validation.
- Prepared-prompt boundary metadata exists when chat-template instrumentation
  can produce it. `/completion` may still use token or position fallback.

## Non-goals

- Stage 10 operator documentation, security hardening, benchmark suite expansion,
  or new public cache-inspection endpoints
- New public request fields for cache markers or workload selection
- New eviction policy families or public policy selector work
- Cross-restart checkpoint restore guarantees
- Changing legacy cache behavior when hybrid mode is disabled
- Implementation work, commits, PR text, or reviewer responses

## Contents

- [Part 1: Scope and workload profiles](cache-handling-phase9-design/part-01-scope-and-workload-profiles.md)
- [Part 2: Checkpoint payload lifecycle and interfaces](cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md)
- [Part 3: Restore strategy and prepared-prompt boundaries](cache-handling-phase9-design/part-03-restore-strategy-and-prepared-prompt-boundaries.md)
- [Part 4: Pairing, cold store, metrics, and diagnostics](cache-handling-phase9-design/part-04-pairing-cold-store-metrics-and-diagnostics.md)
- [Part 5: Testability, traceability, exclusions, and risks](cache-handling-phase9-design/part-05-testability-traceability-exclusions-and-risks.md)
- [Design review gate 01](cache-handling-phase9-design/design-review-gate-01.md)
- [Part 6: Manager design gate](cache-handling-phase9-design/part-06-manager-design-gate.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 8 closure prerequisite | PASS |
| Stage 9 design authoring | PASS |
| Stage 9 independent design review | PASS (see [review gate 01](cache-handling-phase9-design/design-review-gate-01.md)) |
| Stage 9 manager design gate | PASS (see [part 6](cache-handling-phase9-design/part-06-manager-design-gate.md)) |
| Stage 9 implementation planning | NOT STARTED |
| Stage 9 implementation | NOT STARTED |

## Handoff

The Stage 9 design is approved. Next owner: Developer for implementation
planning. The implementation plan must address advisory findings 9-01 through
9-03 from the independent design review before the implementation-plan gate can
pass.
