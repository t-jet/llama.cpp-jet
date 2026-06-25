# Stage 25 implementation: atomic transactional cache writes

Status: closed; Manager gate decision D-CLOSURE-25-01 2026-06-25
Date: 2026-06-25
Stage: 25 (Atomic Transactional Cache Writes)
Author: Developer (implementation)
Source design: [cache-handling-phase25-design.md](cache-handling-phase25-design.md)
Manager gate: D-CLOSURE-25-01
Current gate: terminal (Stage 25 closed)

## Scope

This implementation plan covers Stage 25, which replaces every
background or async cache-mutating operation in the hybrid cache
controller with a synchronous transaction that runs while the
controller holds a single recursive mutex for the duration of one
slot request.

The plan covers the migration of these operation categories:

- `demote_payload` and `promote_payload` (async demote/promote)
- `handle_demotion_completion` and `handle_promotion_completion`
  (async completion dispatch)
- `process_completions` and `update` (background housekeeping)
- `evict_entry_by_id`, `mark_payload_evicted`,
  `mark_payload_kind_evicted`, `cold_budget_make_room`,
  `attach_payload`, `admit_entry_with_payload`,
  `materialize_entry_payload`, `remove_payload` (sync helpers
  that currently race with the worker thread and `update`)
- `save_slot`, `try_restore_from_cache`, `load_slot` (slot
  lifecycle; methods live in `server-context.cpp` but mutate
  hybrid state)

Out of scope (preserved as documented design decisions):

- replacing the existing `io_worker` thread with a stateless
  helper (kept as a synchronous inline helper invoked under
  lock; Option B selection per OQ-25-02)
- cold-store on-disk format changes
- public CLI flags, public metric shape, public endpoint
  schemas
- Windows SEH handler for future S03 crash investigation
  (D-CLOSURE-24-01 a, b, c remain in future-stage scope)

## Inherited invariants

Stage 25 must preserve these already-fixed invariants:

- F-21-EXEC-01: prompt-only save/lookup keeps exact repeats as
  exact hits, not unsafe prefix candidates. TP-21-UT1..UT3 stay
  unchanged.
- F-21-RERUN-01: demoting payloads count against hot budget
  until hot bytes are released. TP-21-UT4..UT6 stay unchanged.
- F-22-DR-01: `demote_payload` already-demoting check precedes
  generic non-hot rejection. TP-22-UT8 stays unchanged.
- Stage 5 target/draft pairing invariant
- Stage 6 atomic write + rename invariant
- Stage 8 payload eviction vs branch pruning separation
- Stage 17 cold budget rejection leaves descriptor hot
- Stage 22 descriptor-as-source-of-truth ownership
- D-EXEC-24-01 over-hot-budget skips demotion, immediate evict
- D-EXEC-24-02 token-limit guaranteed-progress force-evict
- Stage 16 chat-path prompt-span boundary invariant

## New invariants (added by Stage 25)

- I-25-01 atomicity: every cache-state mutation runs inside one
  critical section that holds `cache_state_mutex_` for the
  duration of the operation. Other threads block until the
  section exits.
- I-25-02 isolation: parallel slot requests cannot observe
  partial transaction state. The mutex is exclusive.
- I-25-03 durability-within-transaction: cold-store writes
  commit (atomic write + rename) before the transaction that
  initiated them returns.

## Approved baseline

- [Stage 25 design](cache-handling-phase25-design.md):
  Architect design gate PASS and Manager design gate PASS
  (D25-DESIGN-01). Six design files plus the rework of
  [cache-handling-architecture.md](cache-handling-architecture.md)
  and parts 1-9 to reflect target state. Independent design
  review-fix loop PASS D25-ARCH-01 (0 BLOCKING, 0
  non-blocking, 2 INFO).
- Architecture entry doc and parts already reworked to the
  target-state wording; Stage 25 implementation does not
  re-author architecture parts (out of scope per Part 6).

## Affected files

Planned implementation edits after plan gates:

| Path | Planned action | Reason |
| --- | --- | --- |
| `tools/server/server-cache-hybrid.h` | Add `cache_state_mutex_` member; declare `tx_*` public methods and `tx_assert_mutex_held` private helper; add reentrancy-depth member. | New transactional API. |
| `tools/server/server-cache-hybrid.cpp` | Implement `tx_save`, `tx_restore`, `tx_apply_restore`, `tx_load`, `tx_update`, `tx_evict_entry`, `tx_demote_payload`, `tx_promote_payload`, `tx_cold_budget_make_room`; refactor `update`, `evict_entry_by_id`, `mark_payload_evicted`, `mark_payload_kind_evicted`, `cold_budget_make_room`, `attach_payload`, `admit_entry_with_payload`, `materialize_entry_payload`, `remove_payload`, `demote_payload`, `promote_payload` to acquire the mutex once at entry and inline the worker call. | Replace async and background paths with synchronous transactions. |
| `tools/server/server-context.cpp` | The slot lifecycle methods (`save_slot`, `try_restore_from_cache`, `load_slot`) currently live here and dispatch into the hybrid controller. They keep the same signatures but call into the new `tx_*` methods on the controller. | Keep public API stable; route slot calls to transactions. |
| `tests/test-cache-controller.cpp` | Add `TP-25-UT1..UT10` unit tests; register each in `main()`; bump the printed total from 122 to 132. | Regression coverage for the new transaction layer. |
| `._design_docs/cache-handling-phase25-implementation.md` | Update after each implementation step. | Keep the durable implementation log current. |

No public CLI flags, endpoint schemas, public metric names, model
fixtures, runner scripts, or CMake files are planned.

## OQ decisions (verbatim)

These decisions are recorded for Manager design-gate closure:

- OQ-25-01 apply-step lock scope: SPLIT (cache-state
  transaction only). `tx_restore` returns a plan; the slot
  thread applies the plan to the live slot outside the
  cache-state lock; `tx_apply_restore` re-acquires the lock to
  finalize owner-view sync. The slot thread owns the live
  `llama_context` for apply, and the cache-state lock is not
  held during apply.
- OQ-25-02 worker retirement: Option B (replace `io_worker`
  thread with a stateless synchronous helper invoked inline
  under the cache-state lock). Remove the thread and the
  queue; keep `io_worker.execute_inline(task)` as the API.
- OQ-25-03 transaction_wait_exceeded default: 500 ms.
- OQ-25-04 reentrancy depth limit default: 4.
- OQ-25-05 cold-store metric drift follow-up: KEEP SEPARATE
  (out of scope for Stage 25; tracked under D-CLOSURE-24-01 c).
- OQ-25-06 reentrancy counter: slot context member (NOT
  thread_local). The counter lives on `server_slot` for slot
  threads and on the controller for the server-context thread.

## Contents

- [Part 1: ordered implementation steps](cache-handling-phase25-implementation/part-01-ordered-implementation-steps.md)
- [Part 2: affected code surfaces](cache-handling-phase25-implementation/part-02-affected-code-surfaces.md)
- [Part 3: evidence plan](cache-handling-phase25-implementation/part-03-evidence-plan.md)
- [Part 4: risks and dependencies](cache-handling-phase25-implementation/part-04-risks-and-dependencies.md)
- [Part 5: OQ decisions and rationale](cache-handling-phase25-implementation/part-05-oq-decisions-and-rationale.md)
- [Part 6: open implementation questions](cache-handling-phase25-implementation/part-06-open-implementation-questions.md)
- [Part 7: implementation evidence 2026-06-25](cache-handling-phase25-implementation/part-07-implementation-evidence-20260625.md)
- [Part 8: Architect implementation review 2026-06-25](cache-handling-phase25-implementation/part-08-architect-implementation-review-20260625.md)
- [Part 9: implementation rework evidence 2026-06-25](cache-handling-phase25-implementation/part-09-stage25-rework-evidence-20260625.md)
- [Part 10: Manager closure 2026-06-25](cache-handling-phase25-implementation/part-10-manager-closure-20260625.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 25 design authoring | PASS (D25-DESIGN-01) |
| Stage 25 independent design review-fix | PASS (D25-ARCH-01) |
| Stage 25 Manager design gate | PASS (D25-DESIGN-01) |
| Stage 25 implementation planning | PASS |
| Stage 25 implementation iter 1 | PASS (12 of 12 steps; review REWORK) |
| Stage 25 Architect implementation review | REWORK (B-1, NB-1) |
| Stage 25 implementation rework iter 2 | PASS (D25-EXEC-01) |
| Stage 25 test plan | PASS (D25-TEST-PLAN-01) |
| Stage 25 QA execution | 14 PASS / 1 BLOCKED-evidence-gap / 2 BLOCKED-structural-not-infra |
| Stage 25 Manager closure | PASS (D-CLOSURE-25-01) |

## Handoff

Next owner: user. Manager closure D-CLOSURE-25-01 accepted on
2026-06-25. Code changes UNCOMMITTED per AGENTS.md; user approval
required for commit. See [Part 10](cache-handling-phase25-implementation/part-10-manager-closure-20260625.md)
for closure summary, per-row classification, Manager decisions,
code change summary, and follow-up task list.

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
