# Stage 8 implementation-plan review gate

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)
Review date: 2026-05-31
Reviewer: Architect agent
Verdict: REWORK

## Scope reviewed

Reviewed the Stage 8 implementation plan against the approved Stage 8 design
and the manager implementation-planning workflow.

### Documents checked

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase8-design.md` (entry doc)
- `._design_docs/cache-handling-phase8-design/part-01-overview-and-objectives.md`
- `._design_docs/cache-handling-phase8-design/part-02-interfaces-and-lifecycle-rules.md`
- `._design_docs/cache-handling-phase8-design/part-03-rematerialization-and-mismatch-handling.md`
- `._design_docs/cache-handling-phase8-design/part-04-deduplication-pruning-and-cleanup.md`
- `._design_docs/cache-handling-phase8-design/part-05-observability-testability-and-review-readiness.md`
- `._design_docs/cache-handling-phase8-design/design-review-gate-01.md`
- `._design_docs/cache-handling-phase8-implementation.md` (entry doc)
- `._design_docs/cache-handling-phase8-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase8-implementation/part-02-evidence-plan-and-risks.md`
- `._design_docs/cache-handling-phase7-implementation/part-03-independent-plan-review.md`
- `._design_docs/cache-handling-phase7-implementation/part-04-manager-plan-approval.md`
- `._design_docs/cache-handling-phase5-implementation/part-05-manager-implementation-plan-gate.md`
- `._agents/skills/manager/SKILL.md`
- `._agents/skills/architect/SKILL.md`

## Gate checks

| Check | Result | Notes |
| --- | --- | --- |
| Accepted design baseline is referenced | PASS | Part 1 names the Stage 8 design entry, Parts 01-05, and design-review-gate-01.md PASS. |
| Manager design gate is recorded before planning | FAIL | See B1 below. |
| Code work remains closed | PASS | Both entry doc and Part 1 state implementation is closed until independent review and manager approval. |
| Plan is executable without new design decisions | PASS | Steps map to accepted design. No new design scope introduced. |
| Affected modules are complete enough for planning | PASS | All relevant files named: graph.h/.cpp, hybrid.h/.cpp, controller.h, cold store, CMakeLists, test targets. |
| Dependency order is plausible | PASS | Forest extensions before re-materialization, budget enforcement after pruning, metrics last. |
| Tests and evidence cover Stage 8 behavior | PASS | All 11 metric counters, 13 log events, focused forest/controller/fake-cold tests, Python metric shape. |
| Stage 4 protected-root behavior is preserved | PASS | Plan preserves protected-root payload budget and eviction rules. |
| Stage 5 descriptor and pairing contracts are preserved | PASS | Pair-state eviction, descriptor ownership, transactional restore preserved. |
| Stage 6 cold residency is preserved | PASS | Cold cleanup ownership checks, Stage 6 regression reruns in scope. |
| Stage 7 branch graph semantics are preserved | PASS | Forest extension, slot refs, namespace validation, metadata accounting preserved. |
| Stage 9+ deferrals are preserved | PASS | Checkpoint-first restore and new public HTTP endpoints excluded. |
| Advisory findings 8-01 through 8-05 are addressed | PASS | Each finding has a documented resolution in Part 1. |
| Documentation size and index rules are satisfied | PASS | All files under 300 lines. |

## Findings

### B1 [BLOCKING] — Manager design gate not recorded

The Stage 8 design entry doc
(`cache-handling-phase8-design.md`) shows:

`| Stage 8 manager design gate | NOT STARTED |`

The implementation entry doc
(`cache-handling-phase8-implementation.md`) states:

`The manager design gate is NOT STARTED. Implementation planning is NOT
STARTED.`

Per the manager SKILL.md workflow, the manager design gate (step 2 in the
core workflow) must be recorded as PASS before the implementation-planning
loop (step 3) can begin. The Stage 7 precedent confirms this: Part 11
(manager design gate) was recorded before implementation planning opened.

The implementation plan is technically sound and references the correct
design baseline, but the document set has not recorded the required manager
design-gate handoff. This is the same class of process finding that caused
REWORK in Stage 5 (see
`cache-handling-phase5-implementation/part-02-independent-implementation-plan-review.md`).

**Correction:** Manager must record the Stage 8 manager design gate as PASS
in the design entry doc (or a new part file under the design directory)
before the implementation plan can be formally approved. After that record
exists, this plan can proceed to re-review.

### N1 [NON-BLOCKING] — Step 8.9 budget enforcement order ambiguity

Step 8.9 (branch-metadata budget enforcement) lists dependencies as
"Steps 8.1, 8.2" but the design Part 2 budget model specifies a 5-step
pressure order that includes payload demotion (Stage 6) and payload
eviction (Step 8.1) before metadata pruning (Step 8.2). The plan should
clarify that budget enforcement calls both eviction and pruning in the
correct order, not just pruning.

**Correction:** Add a note in Step 8.9 that budget enforcement follows the
design's 5-step pressure order: demotion, payload eviction, cold cleanup,
metadata pruning, then admission rejection or over-budget diagnostics.

### N2 [NON-BLOCKING] — Step 8.10 cold cleanup integration scope

Step 8.10 (cold cleanup ownership safety) lists affected files including
`server-cache-store-cold.h/.cpp` but does not specify whether the ownership
query is a new method on the cold store or a forest-level check that
iterates retained nodes. The design Part 4 says "prove descriptor ownership
before deletion" but does not mandate where the check lives.

**Correction:** Clarify whether the ownership check is a forest-level
method (iterating retained branch nodes) or a cold-store method. This
affects the test seam and the concurrency guard.

## Verdict

**REWORK** — One blocking finding (B1) prevents this plan from being
approved in its current state. Two non-blocking findings (N1, N2) should be
resolved before re-review.

## Required corrections

| ID | Severity | Correction | Owner |
| --- | --- | --- | --- |
| B1 | BLOCKING | Record manager design gate as PASS in the Stage 8 design entry doc or a new design part file before plan approval. | Manager |
| N1 | NON-BLOCKING | Clarify Step 8.9 budget enforcement follows the 5-step pressure order from the design. | Developer |
| N2 | NON-BLOCKING | Clarify Step 8.10 ownership check location (forest-level vs cold-store method). | Developer |

## Handoff

Handoff state: BLOCKED — manager design gate not recorded.

After B1 is resolved, the Developer should address N1 and N2, then the plan
can proceed to re-review by the Architect.

Next gate after re-review PASS: Manager implementation-plan approval.
