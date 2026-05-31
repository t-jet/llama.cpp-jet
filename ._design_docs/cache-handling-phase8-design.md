# Stage 8 design: metadata-only nodes and re-materialization

Status: Ready for independent design review  
Date: 2026-05-31  
Stage: 8 (Metadata-only nodes and re-materialization)  
Prerequisite Stage: 7 (Branch graph foundation) -- CLOSED

## Scope

Stage 8 turns the Stage 7 branch forest into a graph that can keep useful topology after payload bytes are gone. It separates payload eviction from branch pruning, lets retained nodes become metadata-only, validates re-materialization before replay, handles validation mismatch as prompt divergence, deduplicates equivalent branches, and enforces the branch-metadata budget with safe pruning rules.

This stage advances exactly one gate: design authoring. It does not implement code, write a test plan, approve implementation, or close the design review gate.

## Prerequisites

- Stage 1: Hybrid cache controller and non-destructive exact saves/loads (CLOSED)
- Stage 2: Compatibility namespace and task metadata transport (CLOSED)
- Stage 3: Exact blob cache and usage tracking (CLOSED)
- Stage 4: Byte-accounted hot payload LRU with protected roots (CLOSED)
- Stage 5: Payload descriptor separation and target/draft pairing (CLOSED)
- Stage 6: Cold payload storage and asynchronous I/O (CLOSED)
- Stage 7: Branch forest, namespace validation, slot references, metadata accounting, and global hot-payload LRU (CLOSED)

## Assumptions

- Stage 7's `BranchNode`, `BranchForestIndex`, namespace validation, slot reference model, and metadata byte accounting are the baseline.
- Payload descriptors remain singularly owned by one branch node.
- Exact full-state payload restore remains the Stage 8 materialization mechanism. Checkpoint-first restore remains Stage 9 scope.
- Public metadata-budget CLI remains deferred unless Manager explicitly opens a CLI surface stage. Stage 8 may use internal or test configuration for branch-metadata budget enforcement.

## Non-goals

- Checkpoint-first restore planning for checkpoint-dependent workloads (Stage 9)
- New public HTTP endpoints or request fields
- New eviction policy families or a public policy selector
- Cross-restart branch graph restore guarantees
- Tolerant namespace matching
- PR text, commits, test plans, or implementation work

## Contents

- [Part 1: Overview and objectives](cache-handling-phase8-design/part-01-overview-and-objectives.md)
- [Part 2: Interfaces and lifecycle rules](cache-handling-phase8-design/part-02-interfaces-and-lifecycle-rules.md)
- [Part 3: Re-materialization and mismatch handling](cache-handling-phase8-design/part-03-rematerialization-and-mismatch-handling.md)
- [Part 4: Deduplication, pruning, and cleanup](cache-handling-phase8-design/part-04-deduplication-pruning-and-cleanup.md)
- [Part 5: Observability, testability, and review readiness](cache-handling-phase8-design/part-05-observability-testability-and-review-readiness.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 7 closure prerequisite | PASS |
| Stage 8 design authoring | READY FOR REVIEW |
| Stage 8 independent design review | NOT STARTED |
| Stage 8 manager design gate | NOT STARTED |
| Stage 8 implementation planning | NOT STARTED |
