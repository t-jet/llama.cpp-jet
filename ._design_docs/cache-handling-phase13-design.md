# Stage 13 design: endpoint compatibility corrections

Status: QA planning PASS; endpoint execution open; Date: 2026-06-09

Stage: 13 (Endpoint compatibility corrections)
Prerequisite stage: 12 (Stress testing and benchmarking) -- CLOSED at current progress by Manager decision 2026-06-09

## Scope

Stage 13 fixes endpoint compatibility gaps found after Stage 12. The
goal is endpoint parity: public route families keep their documented
request and response schemas while every enabled hybrid-cache behavior is
selected by llama-server command-line options and internal metadata.

Stage 12 remains closed. The synthetic Stage 12 matrix stopped by
Manager decision is historical evidence, not a Stage 13 prerequisite.
Do not resume V2, V3, or non-MTP synthetic Stage 12 expansion before
Stage 13 implementation and endpoint testing.

Stage 13 must test real public endpoints after implementation. The
minimum endpoint set includes native `/completion`, native `/embedding`,
OpenAI-compatible chat/completions/responses/embeddings where available,
and Anthropic-compatible message/completion routes where available.

This design does not authorize implementation, QA execution, commits, PR
text, or reviewer responses.

## Prerequisites

- Stage 1-11 cache feature stages are closed.
- Stage 12 is closed at current progress per the Stage 12 implementation
  log and Manager handoff.
- Stage 12 V1 fallback fix and V2 `draft-simple` harness correction stay
  in the baseline.
- Architecture Part 3 and Part 8 define the public endpoint contract.

## Non-goals

- Do not add cache-specific request fields.
- Do not add a public cache control endpoint.
- Do not change `/slots` save or restore semantics.
- Do not require users to edit model templates for cache behavior.
- Do not make the fork-only Jinja marker interface public API.
- Do not weaken Stage 12 stress, benchmark, or long-run requirements.

## Contents

- [Part 1: Route scope and endpoint contract](cache-handling-phase13-design/part-01-route-scope-and-endpoint-contract.md)
- [Part 2: Metadata construction and parity rules](cache-handling-phase13-design/part-02-metadata-construction-and-parity-rules.md)
- [Part 3: Acceptance checks and implementation handoff](cache-handling-phase13-design/part-03-acceptance-checks-and-handoff.md)
- [Part 4: Design review gate 01](cache-handling-phase13-design/part-04-design-review-gate-01.md)
- [Part 5: Manager design gate](cache-handling-phase13-design/part-05-manager-design-gate.md)

## Current gate

Current gate: Stage 13 endpoint execution. Manager design gate,
Manager implementation-plan gate, implementation review, QA planning
re-review, and Manager test-plan gate passed on 2026-06-09. Closure is
not started.

## Stage gate

| Gate | Status |
| --- | --- |
| Stage 12 close-at-current-progress prerequisite | PASS, 2026-06-09 |
| Stage 13 design authoring | PASS, 2026-06-09 |
| Stage 13 independent design review | PASS, 2026-06-09 |
| Stage 13 manager design gate | PASS, 2026-06-09 |
| Stage 13 implementation planning | PASS, 2026-06-09 |
| Stage 13 independent plan review | REWORK, 2026-06-09 |
| Stage 13 independent plan re-review | PASS, 2026-06-09 |
| Stage 13 manager implementation-plan gate | PASS, 2026-06-09 |
| Stage 13 implementation | COMPLETE, 2026-06-09 |
| Stage 13 implementation review | PASS, 2026-06-09 |
| Stage 13 QA planning | PASS, 2026-06-09 |
| Stage 13 endpoint execution | OPEN |
| Stage 13 closure | NOT STARTED |

## Handoff

Next owner: QA execution.

QA execution must start from a clean build, create a fresh report, and
record real endpoint evidence for the accepted Stage 13 plan before
Developer test-results review.
