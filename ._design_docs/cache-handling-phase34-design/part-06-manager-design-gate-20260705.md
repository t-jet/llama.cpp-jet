# Stage 34 Manager design-gate: idempotent save and Path B (2026-07-05)

Status: PASS - advance to implementation planning
Date: 2026-07-05
Stage: 34 (reopened)
Owner: Manager
Branch: work-branch

## Authority

User directive 2026-07-05 recorded at
`._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md`.
Decisions D34-REOPEN-05..08 are binding. This gate records the Manager
review of Architect design creation and Architect independent design review.

## Inputs reviewed

- Design creation: `cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md`
- Design review: `cache-handling-phase34-design/part-05-design-review-20260705.md`
- Authority: `._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md`
- Prior architect PARTIAL review: `cache-handling-phase34-design/part-03-architect-review-concurrent-reuse-structural-finding-20260701.md`

## Decision

The design gate PASSES. The design meets the four Manager decisions:

- D34-REOPEN-05: TP-34-CC reclassified as EXPECTED-BEHAVIOR via the Stage 33
  precedent. Cache code unchanged.
- D34-REOPEN-06: idempotent `tx_save`. The Architect review confirmed the
  existing dedupe branches at `tools/server/server-cache-hybrid.cpp:4819-4826`
  (hot residency) and `:4863-4883` (cold re-materialize) already implement
  what the user described. No new production code needed for this behavior
  beyond the invariant wording and the regression tests. New invariant
  I-34-01 (widened per finding 1 to cover both residency cases).
- D34-REOPEN-07: Path B slow-read relocation. The SPLIT pattern follows
  OQ-25-01's precedent. New invariant I-34-02.
- D34-REOPEN-08: stage will not close until both behaviors pass design,
  implementation, test-planning, test-execution, and test-results review.

The independent design review returned PASS with 0 BLOCKING and
6 NON-BLOCKING findings. The findings are documentation hygiene plus one
invariant widening. The findings fold into the implementation plan as
required-action items; they do not reopen the design.

## Required-action items for the implementation plan

The implementation plan must:

1. Widen I-34-01 to assert no duplicate entry is created when
   `find_equivalent_entry` returns non-end, regardless of residency (covers
   both the hot-dedupe L4820-L4826 path and the cold re-materialize
   L4863-L4883 path).
2. Add a T-34-IDEM-03 regression test exercising the cold-residency
   re-materialize branch.
3. Carry the corrected Bind fact line ranges into the implementation plan:
   - `materialize_entry_payload` re-materialize case: L4865-L4882
   - `admit_entry_with_payload` new-entry case: L4886-L4923
4. Carry the corrected `branch_forest_index` lock-mapping if the implementation
   touches forest lookups: lock_guard lines are L188 (`get_node`),
   L194 (`get_node const`), L203 (`find_nodes_by_token_span`),
   L225 (`find_nodes_by_checksum_span`), L244 (`get_children`); also L122
   (`create_node`) and L152 (`remove_node`).
5. Cite `evict_until_within_budget` (cpp L3094 inside
   `materialize_entry_payload`, L3195 inside `admit_entry_with_payload`) as
   the budget recheck guarantee inside the second critical section of
   Behavior change TWO.
6. State explicitly that the slow-read SPLIT releases any iterator or
   pointer captured before lock release; the second-pass re-lookup is
   iterator-invalidation-safe.
7. Make the residency qualifier on I-34-02 explicit. State whether the
   second-pass dedupe predicate accepts any residency or only hot residency.
8. Restructure `tx_save` to follow the SPLIT pattern: acquire lock, validate,
   first dedupe (no slow read on hit), snapshot read inputs, release lock,
   slow read, re-acquire lock, second dedupe OR admit/re-materialize.

## Format hygiene

`part-04`: CR=0 LF=230 BOM=NO ASCII-only, 230 LF lines, no trailing
whitespace.
`part-05`: CR=0 LF=154 BOM=NO ASCII-only, 154 LF lines, no trailing
whitespace.

## Scope authority

- Architect review confirmed Paths C, D, E are correctly out of scope.
- Slot lifecycle separation from cache lifecycle is preserved.
- I-25-01..03 invariants are preserved by both behavior changes.
- No production code was edited.

## Next owner and next gate

Next owner: Developer (fresh session).
Next gate: Implementation planning for D34-REOPEN-06 and D34-REOPEN-07,
with the eight required-action items above folded into the plan.
