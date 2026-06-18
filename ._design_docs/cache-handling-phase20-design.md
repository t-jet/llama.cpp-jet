# Stage 20 design: Stage 17 test infrastructure additions

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 20 (Stage 17 Test Infrastructure Additions)
Author: Architect (design, fresh session)
Source: [Stage 17 implementation closure decisions](cache-handling-phase17-implementation.md) D17-CLOSURE-01 BLOCKED-acceptable rows; [Stage 17 test plan part-27 synthetic, stress-longrun, and heavy tier rows](cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md) TP-17-SY1..SY5, TP-17-ST1..ST3, TP-17-HV1..HV2
Scope: Stage 20 design only. Not re-review of Stage 17 or any other stage.
Current gate: Design

## Scope

This design addresses three deferred Stage 17 test infrastructure items
that were classified `BLOCKED-acceptable` at Stage 17 closure (2026-06-17)
under D17-CLOSURE-01. Each item becomes testable in Stage 20 once the
infrastructure exists.

Items in scope:

1. Agentic prompt generator that produces chat prompts of specified
   token sizes (12k, 24k, 60k) for the synthetic tier (TP-17-SY1..SY5).
2. Qwen3.6-27B-MTP fixture for the heavy tier (TP-17-HV1, TP-17-HV2).
   The fixture is currently absent from `._test_models/`.
3. Re-invocation of the Stage 12/15 stress and long-run framework with
   Stage 17 hooks (TP-17-ST1..ST3).

Out of scope:

- Reopening Stage 17 implementation or test plan.
- D17-EXEC-02 (system-level model warmup crash). Closed at Stage 19.
- D17-EXEC-03 (duplicate cold-path-hybrid check). Closed at Stage 18.
- F-16-TR-03 (`/Zi /DEBUG:FULL` on `build-cov`). Closed at Stage 18.
- Any code change to `tools/server/*` or `tests/*`.
- Any change to the S/L framework scripts themselves (only re-invocation
  is in scope; framework changes are a separate task).
- Adding new public endpoints, CLI flags, or metrics.
- Re-running Stage 17 closed rows (unit, integration, focused regression).

## Prerequisites

- Stage 17 closed on 2026-06-17 per
  [cache-handling-stage-tracker.md](cache-handling-stage-tracker.md) row 17.
- Stage 17 test plan part-27 records the 10 deferred rows (5 synthetic +
  3 stress-longrun + 2 heavy) at
  [cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md](cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md).
- Stage 18 closed on 2026-06-18 (D17-EXEC-03 + D17-CLOSURE-02 fixes).
- Stage 19 closed on 2026-06-18 (D17-EXEC-02 Branch C, no reproduction).
- The Stage 12/15 S/L framework scripts are present at
  `._design_docs/cache-handling-test-scripts/stress/` (8 files) and
  `._design_docs/cache-handling-test-scripts/longrun/` (3 files) plus
  `kickoff-v2-stress-longrun.ps1` (verified by `Get-ChildItem` 2026-06-18).
- The Qwen3.6-27B-MTP fixture is absent from `._test_models/` (verified
  by `Test-Path 'd:\source\llama.cpp-jet\._test_models\Qwen3.6-27B-MTP-GGUF'`
  returning `False` on 2026-06-18). The Qwen3.5-4B-MTP fixture is
  present at `._test_models/Qwen3.5-4B-MTP-GGUF/` and may serve as a
  smaller-MTP substitute only after Manager decision.
- R-20-DESIGN-MGR-01 (Qwen3.6-27B-MTP fixture acquisition path) is OPEN
  and gates Item 2. See "Manager decision point" below.

## Contents

- [Part 1: Item 1 design - agentic prompt generator](cache-handling-phase20-design/part-01-item1-agentic-prompt-generator.md)
- [Part 2: Item 2 design - Qwen3.6-27B-MTP fixture and Manager decision](cache-handling-phase20-design/part-02-item2-mtp27b-fixture-and-manager-decision.md)
- [Part 3: Item 3 design - S/L framework re-invocation](cache-handling-phase20-design/part-03-item3-sl-framework-reinvocation.md)
- [Part 4: test plan rows, traceability, risks, and handoff](cache-handling-phase20-design/part-04-test-plan-rows-traceability-risks-handoff.md)

## Manager decision point

This design proposes one Manager decision: **R-20-DESIGN-MGR-01
(Qwen3.6-27B-MTP fixture acquisition path)**. The decision is binding
for Item 2 and may close or reshape the heavy-tier rows (TP-17-HV1,
TP-17-HV2) before Stage 20 test plan authoring.

The decision options are listed in part 2 section "R-20-DESIGN-MGR-01
options" with rationale and consequences. The Architect does NOT pick
a fallback. The Architect surfaces this as a Manager decision.

The Manager decision is referenced in all three item parts and in
part 4 traceability.

## Gate status

| Gate | Status |
| --- | --- |
| Stage 20 design authoring | PASS (this file and parts 1-4) |
| Stage 20 design review | NOT STARTED |
| Stage 20 Manager design gate | NOT STARTED |
| Stage 20 implementation planning | NOT STARTED |
| Stage 20 implementation | NOT STARTED |
| Stage 20 implementation review | NOT STARTED |
| Stage 20 test planning | NOT STARTED |
| Stage 20 test-plan review | NOT STARTED |
| Stage 20 Manager test-plan gate | NOT STARTED |
| Stage 20 QA execution | NOT STARTED |
| Stage 20 test-results review | NOT STARTED |
| Stage 20 closure | NOT STARTED |

## Handoff

Next owner: Architect for design review in a fresh session.

After Architect design review PASS, the design advances to Manager for
the design gate. The Manager design gate MUST record R-20-DESIGN-MGR-01
with one of the four options in part 2 before implementation planning
opens. After Manager design gate PASS, the design advances to Developer
for implementation planning and implementation.

The Stage 17 implementation log, tracker, document-index, and any other
durable doc are NOT modified by this design. The Stage 20 design files
are untracked until the user approves their inclusion in the index; the
Manager adds the Stage 20 row to `document-index.md` and the design
entry description only after Manager design gate PASS.

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap.
