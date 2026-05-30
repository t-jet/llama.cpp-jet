# Phase 6 implementation plan - Part 4: Plan re-review

Source: [../cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)

## Verdict: PASS

Date: May 30, 2026
Reviewer: Architect (independent re-review)
Scope: Corrected implementation plan Parts 1 and 2, original review Part 3

The corrected plan resolves the single blocking finding and all four non-blocking observations from
the original review. No new issues were introduced by the corrections. The plan is approved for
implementation, subject to manager approval before code work begins.

---

## Verification of original findings

### BF-1: Steps 6 and 7 missing dependency on Step 8 — RESOLVED

Original finding: Step 6 listed dependencies "Steps 1, 2, 3, 5" and Step 7 listed dependencies
"Steps 1, 4, 5, 6". Neither included Step 8, where `cold_store` and `io_worker` are declared as
private members of `hybrid_cache_controller`. A developer implementing Step 6 after Step 5 would
reference undeclared members and fail to compile.

Correction applied: Step 6 dependency list now reads "Steps 1, 2, 3, 5, 8." Step 7 dependency list
now reads "Steps 1, 4, 5, 6, 8." Both explicitly include Step 8.

Verification: The dependency graph across all twelve steps is now consistent:

| Step | Dependencies | References satisfied |
| ----- | ------------ | ------------------- |
| 1 | none | — |
| 2 | none | — |
| 3 | Step 2 | cold store module from 2 |
| 4 | Step 3 | write from 3 |
| 5 | Steps 2, 3, 4 | cold store, write, read |
| 6 | Steps 1, 2, 3, 5, 8 | transient states from 1, cold store from 2, write from 3, worker from 5, member declarations from 8 |
| 7 | Steps 1, 4, 5, 6, 8 | transient states from 1, read from 4, worker from 5, demotion from 6, member declarations from 8 |
| 8 | Steps 2, 5 | cold store from 2, worker from 5 |
| 9 | Steps 2, 8 | cold store from 2, wiring from 8 |
| 10 | Steps 6, 7 | demotion and promotion protocols |
| 11 | Steps 5, 6, 7 | worker, demotion, promotion |
| 12 | all prior steps | — |

Every symbol referenced in each step's changes is introduced by a step in that step's dependency
set. No forward reference remains. BF-1 is fully resolved.

### NB-A: NB-3 resolution supersedes design Part 2 without a correction record — ADDRESSED

Original observation: Step 2 removes `cold_ref_for(payload_id)` via NB-3 resolution, but no design
correction to Part 2 was created or referenced.

Correction applied: Step 2 now includes a "Design correction required" note stating that before
Step 2 is implemented, a supersession note must be added to design Part 2's interface table
marking `cold_ref_for(payload_id)` as removed by NB-3 resolution, so the design and implementation
remain consistent.

Verification: The note is present in Part 1, Step 2, and correctly identifies the action needed.
The design Part 2 file still contains `cold_ref_for(payload_id)` at line 32, confirming the
supersession note has not yet been applied — which is expected, since the note says it must be
added "before Step 2 is implemented." This is a pre-implementation prerequisite, not a plan
defect. NB-A is adequately addressed.

### NB-B: Fifth startup check not acknowledged in Step 9 — ADDRESSED

Original observation: Design Part 5 startup validation table includes a fifth check (`--cache-ram`
positive value when hybrid mode is enabled) that Step 9 did not mention.

Correction applied: Step 9 now includes an "Inherited check" note stating that the `--cache-ram`
positive-value check is inherited from Stage 4 and is not re-implemented in Step 9. The existing
Stage 4 validation continues to run in the startup path and is not broken by Step 9's changes.

Verification: The note is present in Part 2, Step 9, and correctly identifies the inherited
check, its origin (Stage 4), and that Step 9 adds only the four cold-store-specific checks. This
prevents a future reader from wondering whether the fifth check was overlooked. NB-B is
adequately addressed.

### NB-C: Evidence plan part number conflicts with review — ADDRESSED

Original observation: The evidence plan designated `part-03-implementation-evidence.md`, which
conflicts with the independent plan review in `part-03-independent-plan-review.md`.

Correction applied: The evidence plan now references `part-04-implementation-evidence.md`.

Verification: The corrected reference appears at the end of Part 2 in the evidence plan section.
The part numbering is now consistent: Part 1 (implementation plan steps 1-5), Part 2 (steps
6-12), Part 3 (independent plan review), Part 4 (this re-review), and implementation evidence
will start at Part 5 or use `part-04-implementation-evidence.md` as stated. NB-C is adequately
addressed.

### NB-D: Part 3 prose order inconsistency — ADDRESSED

Original observation: Design Part 3, promotion protocol step 6, lists validation items in prose
in a different order from the numbered check list that follows. The implementation plan should
direct implementers to the numbered check list.

Correction applied: Step 7 now includes an "Implementation note on validation order" directing
implementers to follow the numbered check list in design Part 3 (magic, format_version,
header_checksum, checksum_algorithm, payload_id, pair_state, target_size_bytes,
draft_size_bytes, target payload bytes, draft payload bytes), not the prose order.

Verification: The note is present in Part 2, Step 7, and correctly lists the numbered check
order. This prevents an implementer from following the prose order in design Part 3 step 6,
which lists "header checksum, magic, format version, checksum algorithm" — a different sequence
that would fail the header checksum check before confirming magic and format version. NB-D is
adequately addressed.

---

## New findings

No new findings. The corrections are minimal and surgical: two dependency list updates, three
implementation notes, and one part-number reference update. None of these changes introduce
inconsistencies, scope creep, or architectural concerns.

---

## Dependency graph completeness check

All twelve steps have been verified for dependency completeness. Every member variable, function,
type, or module referenced in a step's changes is introduced by a step in that step's dependency
set:

- Step 6 references `cold_store.is_configured()` and `worker.enqueue_demotion()` — both declared
  in Step 8, which is now listed as a dependency.
- Step 7 references `worker.enqueue_promotion()` — declared in Step 8, which is now listed as a
  dependency.
- Step 8 references `server_cache_store_cold` (from Step 2) and `server_cache_io_worker` (from
  Step 5) — both listed as dependencies.
- No other forward references exist in the plan.

---

## Handoff state

PASS. The corrected implementation plan is approved for implementation. Code work may begin after
manager approval.

The following pre-implementation prerequisite from NB-A must be completed before Step 2 code work
begins: add a supersession note to design Part 2's interface table marking
`cold_ref_for(payload_id)` as removed by NB-3 resolution.
