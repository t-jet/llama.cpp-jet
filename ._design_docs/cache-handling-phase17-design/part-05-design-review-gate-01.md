VERDICT: PASS

# Stage 17 design review gate 01

Status: PASS
Date: 2026-06-17
Stage: 17 (Agentic Cache Reuse, Cold Budget, and Checkpoint Policy)
Review type: independent design review
Owner: Architect

## Scope

This review covers the Stage 17 design only. It does not approve code
changes, test execution, commits, PR text, or reviewer responses.

Reviewed inputs:

| Input | Result |
| --- | --- |
| `cache-handling-phase17-design.md` | Reviewed |
| `cache-handling-phase17-design/part-01-restore-diagnostics-and-prompt-evidence.md` | Reviewed |
| `cache-handling-phase17-design/part-02-agentic-reuse-and-checkpoint-policy.md` | Reviewed |
| `cache-handling-phase17-design/part-03-cold-storage-budget-and-eviction.md` | Reviewed |
| `cache-handling-phase17-design/part-04-observability-qa-acceptance-traceability.md` | Reviewed |
| `cache-handling-phase16-implementation/part-09-model-log-analysis.md` | Reviewed |
| `cache-handling-requirements.md` and parts | Reviewed |
| `cache-handling-architecture.md` and parts 2, 4, 5, 9 | Reviewed |
| Stage 9 checkpoint design parts 2 and 3 | Reviewed |
| Stage 12/15 stress and longrun planning docs | Reviewed |
| Stage 16 chat-path test-plan part 26 | Reviewed |

## Blocking findings

None.

## Non-blocking findings

| ID | Finding | Required follow-up |
| --- | --- | --- |
| N17-01 | The design leaves two implementation-facing choices open: final cold-budget flag name and prompt evidence file shape. This is acceptable for design review because the semantics are fixed and part 4 lists them as review questions. | Manager design gate or implementation-plan review should record the accepted CLI name and evidence record format before code work starts. |
| N17-02 | The prefix-restore policy is intentionally deferred. The design is safe because prefix candidates are classified as `unsafe_prefix_rejected` until all validation checks exist. | Implementation planning must keep prefix restore out of Stage 17 code scope unless Manager opens a separate approved scope change. |

## Info findings

| ID | Note |
| --- | --- |
| I17-01 | The restore-miss reason model is bounded and avoids prompt text, raw paths, raw namespaces, and raw descriptor IDs in labels. |
| I17-02 | Cold budget semantics match the Stage 6 cold-layer model: hot and cold budgets stay separate, failed demotion does not attach cold residency, and cleanup stays under the configured cold root. |
| I17-03 | Checkpoint-density policy keeps Stage 9 checkpoint-first behavior and the Stage 16 chat-path prompt-span invariant by using a narrow compatibility exception for checkpoint-dependent, target-plus-draft, and MTP-heavy modes. |
| I17-04 | QA hooks are generic enough for later QA planning: synthetic agentic prompts, Stage 12/15 stress-longrun extension, and heavy manual or nightly reproduction are separated by cost and evidence type. |

## Review checklist

| Area | Verdict | Evidence |
| --- | --- | --- |
| Requirement traceability | PASS | Part 4 maps Stage 17 behavior to R4a-R133 and constrains deferred prefix behavior. |
| Architecture fit | PASS | Parts 1-3 follow architecture restore order, payload/pruning distinction, byte-accounted policy, and chat-path invariant. |
| Scope and non-goals | PASS | Entry doc and parts keep generated-output replay, cross-restart restore guarantee, new public endpoints, and legacy-path changes out of scope. |
| Exact versus prefix restore | PASS | Exact restore remains the only required implementation target; prefix restore is evidence and policy only. |
| Restore-miss reasons | PASS | Part 1 defines one primary bounded reason per lookup and forbids prompt data in labels. |
| Cold budget and startup behavior | PASS | Part 3 defines `0`, positive, and `-1` semantics, startup validation, accounting, cleanup, and skip-before-write behavior. |
| Checkpoint density | PASS | Part 2 prefers semantic admissions while preserving required checkpoint continuity. |
| Observability | PASS | Part 4 uses existing metrics/log surfaces and bounded labels. |
| Testability | PASS | Part 4 lists focused tests and QA tiers that map to Stage 12/15 evidence patterns. |
| Document size and navigation | PASS | Entry and parts are under 300 lines; review file is under 300 lines. |

## Handoff

Design review PASS. Manager can open the Stage 17 design gate and decide
whether implementation planning starts immediately or after recording the
CLI-name and evidence-format choices from N17-01.

Next owner: Manager for design gate decision. After Manager gate PASS, next
owner is Developer for implementation planning.
