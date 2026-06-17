# Stage 17 design: agentic cache reuse, cold budget, and checkpoint policy

Status: Design and Manager design gates passed; ready for implementation planning
Date: 2026-06-17
Stage: 17 (Agentic Cache Reuse, Cold Budget, and Checkpoint Policy)
Source: [Stage 16 model-log analysis](cache-handling-phase16-implementation/part-09-model-log-analysis.md)
Current gate: Implementation planning

## Scope

Stage 17 turns the Stage 16 long-run model-log findings into durable cache
behavior for large agentic chat workloads. It covers:

- bounded restore-miss diagnostics
- prompt identity evidence in raw and redacted modes
- exact restore versus prefix restore policy for large agentic prompts
- cold storage disk budget and cold-byte eviction behavior
- checkpoint-density policy for agentic chats
- QA hooks for synthetic, stress-longrun, and heavy manual reproduction

This design does not approve implementation planning, code work, test-plan
execution, design review, commits, PR text, or reviewer responses.

## Prerequisites

- Stages 1-10 are closed for hybrid cache foundations, cold storage,
  checkpoint integration, observability, and hardening.
- Stage 12 and Stage 15 define stress, longrun, and benchmark evidence shapes.
- Stage 16 is closed for the chat-path prompt-span boundary fix. Its model-log
  analysis is evidence for Stage 17 scope, not a Stage 16 gate change.
- Architecture Part 2 restore order, Part 4 payload/pruning distinction, Part
  5 byte-accounted LRU, and Part 9 chat-path prompt-boundary invariant remain
  binding.

## Assumptions

- Correctness has priority over hit rate. Unsafe reuse falls back to recompute.
- Public endpoints keep their current schemas. Stage 17 adds no request fields.
- Prompt text may be sensitive. Raw prompt capture is opt-in, and redacted mode
  must be useful without prompt text.
- Cold storage is process-lifetime cache storage, not a restart guarantee.
- Checkpoint-dependent and MTP workloads still need checkpoint-compatible
  branch continuity.

## Non-goals

- Generated-output replay or output memoization
- Cross-restart cold restore guarantee
- Distributed cache or cross-process cache coherence
- New public cache inspection endpoint
- Full prefix restore implementation in Stage 17 design scope
- Replacing exact full-state blob restore
- Changing legacy cache behavior when hybrid mode is disabled

## Contents

- [Part 1: restore diagnostics and prompt evidence](cache-handling-phase17-design/part-01-restore-diagnostics-and-prompt-evidence.md)
- [Part 2: agentic reuse and checkpoint policy](cache-handling-phase17-design/part-02-agentic-reuse-and-checkpoint-policy.md)
- [Part 3: cold storage budget and eviction](cache-handling-phase17-design/part-03-cold-storage-budget-and-eviction.md)
- [Part 4: observability, QA, acceptance, and traceability](cache-handling-phase17-design/part-04-observability-qa-acceptance-traceability.md)
- [Part 5: independent design review gate 01](cache-handling-phase17-design/part-05-design-review-gate-01.md)
- [Part 6: Manager design gate](cache-handling-phase17-design/part-06-manager-design-gate.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 17 design authoring | PASS |
| Stage 17 independent design review | PASS (see [part 5](cache-handling-phase17-design/part-05-design-review-gate-01.md)) |
| Stage 17 manager design gate | PASS (see [part 6](cache-handling-phase17-design/part-06-manager-design-gate.md)) |
| Stage 17 implementation planning | NOT STARTED |
| Stage 17 implementation | NOT STARTED |
| Stage 17 QA execution | NOT STARTED |

## Handoff

Stage 17 design gate passed. Next owner: Developer for implementation
planning. The implementation plan must carry D17-01 through D17-03 from
[part 6](cache-handling-phase17-design/part-06-manager-design-gate.md).
