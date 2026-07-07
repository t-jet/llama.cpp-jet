# Stage 34 Manager implementation-plan gate: idempotent save and Path B

Status: PASS - advance to implementation
Date: 2026-07-05
Stage: 34 (reopened)
Owner: Manager
Branch: work-branch

## Authority

User directive 2026-07-05 is recorded in
`._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md`.
Decisions D34-REOPEN-05 through D34-REOPEN-08 remain binding.

## Inputs reviewed

- Implementation plan:
  `cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md`
- Independent implementation-plan review:
  `cache-handling-phase34-implementation/part-13-implementation-plan-review-20260705.md`
- Design correction:
  `cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md`
- Design review:
  `cache-handling-phase34-design/part-05-design-review-20260705.md`
- Manager design gate:
  `cache-handling-phase34-design/part-06-manager-design-gate-20260705.md`

## Decision

The implementation-plan gate PASSES. The plan review returned PASS with no
BLOCKING findings. The five NON-BLOCKING findings are implementation-session
cleanup items:

1. Correct the stale line cites for the cold re-materialize branch and admit
   return before code edits: L4878, L4879, and L4924.
2. Add the `select_mismatch_parent_for_admission` cite at L4885 to the
   implementation evidence when describing the admit branch.
3. Add T-34-PATHB-02, or record why it is deferred, so the second-pass dedupe
   branch under Path B is directly covered.
4. Destroy the first `stage25_tx::reentrancy_guard` at the first lock release
   and construct a fresh guard after re-acquiring the lock.
5. Preserve the existing `std::bad_alloc` catch path for slow-read buffer
   allocation outside the lock.

## Gate checklist

| Check | Result |
| --- | --- |
| Approved design baseline cited | PASS |
| Ordered implementation steps present | PASS |
| Affected code and test files named | PASS |
| Evidence plan present | PASS |
| Scope excludes Path C, Path D, Path E | PASS |
| Stage 25 transaction invariants preserved | PASS |
| Review verdict explicit | PASS |

## Next owner and next gate

Next owner: Developer (fresh session).
Next gate: Implementation for D34-REOPEN-06 and D34-REOPEN-07.

Implementation must update the implementation log with code/test evidence and
must not commit or push.
