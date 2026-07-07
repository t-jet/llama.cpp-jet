# MANAGER INPUTS - NOT AN APPROVED DESIGN

Stage: 34 (reopened)
Date: 2026-07-05
Branch: work-branch
Gate at intake: BLOCKED structural - Architect PARTIAL verdict on TP-34-CC, awaiting user decision per D34-REOPEN-03

## User directive verbatim

For the phase 34:

1. accept Path A for the TP-34-CC, but ensure that the same cache entries
   wouldn't be saved twice, but increase cache hit on save if same path would
   be found in the cache. E.g. if in the Scenario 1 Alice will finish first,
   lock cache and write her prompt, then Bob on his own turn should find that
   prompt is already and cache and increase hot counter instead of creating
   his own cache record.

2. Implement improvement from Path B.

When both points will be done (design/implementation/test with all reviews
etc according to the manager skill) then stage can be closed.

## Why this proposal is not the design

The user is the authority for stage direction. Path A reclassification is
granted. The two new behavior changes (idempotent save with hot-counter bump,
and Path B slow-read relocation) are durable product behavior changes that
require Stage 25 transaction protocol review before they can be implemented.
They cannot land as inline code edits. They must flow through design review,
implementation-plan review, implementation review, test-plan review, test
execution, and test-results review before the stage can close.

## Manager decisions recorded from this directive

| ID | Decision |
| --- | --- |
| D34-REOPEN-05 | Accept Path A. Reclassify TP-34-CC dispatch-ordering race as EXPECTED-BEHAVIOR, following the Stage 33 closure precedent. |
| D34-REOPEN-06 | Add a new behavior: idempotent `tx_save`. If a duplicate slot finds the same prompt already cached when its save begins, the slot bumps the existing entry's hot counter instead of creating a duplicate entry. |
| D34-REOPEN-07 | Add a new behavior: relocate the slow `llama_state_seq_get_data_ext` reads in `tx_save` outside the lock-held region (Path B). Lock is held only for the snapshot read and for the final mutation commit. |
| D34-REOPEN-08 | Stage 34 cannot close until both new behaviors pass design, implementation-planning, implementation, test-planning, test-execution, and test-results review gates. |

## Source authority

User chat message 2026-07-05, ventana de chat del Manager mode. The Architect
PARTIAL review
(cache-handling-phase34-design/part-03-architect-review-concurrent-reuse-structural-finding-20260701.md)
and the D34-REOPEN-03 pause provide the explicit authority for the user to
direct this stage.
