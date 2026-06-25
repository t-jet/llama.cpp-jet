# Stage 25 design: atomic transaction cache state

Status: Architect design gate PASS; Manager design gate PASS; Stage 25 closed 2026-06-25 per D-CLOSURE-25-01
Date: 2026-06-25
Stage: 25 (Atomic Transaction Cache State)
Owner: Architect
Source trigger: user direction 2026-06-25
Baseline: current dirty worktree on `work-branch` after Stage 24 closure
Current gate: terminal

## Scope

Stage 25 replaces every background cache-mutating operation in
`tools/server/server-cache-hybrid.cpp` with a synchronous, in-band
transaction that runs while the controller holds a single exclusive
cache-state lock. Every operation that today runs through the async
I/O worker or through `update()` background housekeeping must instead
execute inside a critical section scoped to the slot request that
triggered the operation.

The design covers these affected surfaces:

- `demote_payload` (async cold write)
- `promote_payload` (async cold read)
- `handle_demotion_completion` (async completion)
- `handle_promotion_completion` (async completion)
- `evict_entry_by_id` (sync but interleaved with async writes)
- `mark_payload_kind_evicted` (sync demotion-first path)
- `mark_payload_evicted` (sync immediate eviction)
- `cold_budget_make_room` (sync cold eviction that mutates cold files)
- `attach_payload`, `admit_entry_with_payload`,
  `materialize_entry_payload` (sync hot admission with state mutation)
- `save_slot`, `try_restore_from_cache`, `load_slot` (slot lifecycle)
- `update` (background housekeeping called from server-context thread)

Out of scope:

- new cache policy or new CLI flags
- public metric rename (existing internal counters stay internal)
- new endpoint schema
- cold-store on-disk format change
- replacing the existing `io_worker` thread outright (kept as a
  synchronous helper invoked under lock until end of transaction;
  retirement is a separate follow-up)
- Windows SEH handler / crash-dump task from D-CLOSURE-24-01 (a)
- S03 hybrid silent crash investigation task from D-CLOSURE-24-01 (b)
- cold-store metric drift follow-up from D-CLOSURE-24-01 (c)

## Inherited invariants

Stage 25 must preserve these already-fixed invariants:

- F-21-EXEC-01: prompt-only save/lookup keeps exact repeats as exact
  hits, not unsafe prefix candidates. TP-21-UT1..UT3 stay unchanged.
- F-21-RERUN-01: demoting payloads count against hot budget until hot
  bytes are released. TP-21-UT4..UT6 stay unchanged.
- F-22-DR-01: `demote_payload` already-demoting check precedes generic
  non-hot rejection. TP-22-UT8 stays unchanged.
- Stage 5 pairing: target/draft payloads move as one descriptor-owned
  unit.
- Stage 6 cold I/O: cold writes use atomic write + rename; the
  controller owns the authoritative descriptor transition.
- Stage 8 graph rules: payload eviction and branch pruning stay
  separate; metadata-only nodes remain valid only after descriptor
  ownership is clear.
- Stage 17 cold budget: cold-budget rejection leaves descriptor hot
  and does not produce partial cold residency.
- Stage 22 ownership: descriptor is source of truth for residency;
  entries and branch nodes are derived views; `hot_payloads` is
  source of truth for hot bytes.
- D-EXEC-24-01: over-hot-budget skips demotion and falls through to
  immediate eviction.
- D-EXEC-24-02: token-limit loop guarantees progress by force-evicting
  one entry per iteration when `build_policy_candidates()` is empty.

## Problem statement

Today, every cache-mutating path splits work between the slot thread
and either the async I/O worker thread or the `update()` background
sweep. Three consequences follow:

1. Two concurrent slot requests that both need to demote a different
   hot payload can race: each marks its descriptor `demoting`, the
   worker drains completions out of order, and a slot can observe its
   descriptor in an unexpected transient state.
2. A slot request that needs to restore a cold payload must wait for
   the async promote worker to materialize bytes. The slot holds
   resources while the worker makes progress on a separate thread.
   No transactional lock prevents the worker from interleaving with a
   concurrent demote that targets a different payload in the same
   entry's owner views.
3. A slot request that needs to add a new entry while another request
   is finishing a demotion can observe the descriptor in `cold` state
   while the entry's payload accounting has not yet been refreshed.

The user requirement is: every operation that requires cache-state
modification runs in atomic transactional mode for each slot request.
All write operations from other threads block until the transaction
finishes. The transaction includes demotion, eviction, new-entry
admission, and cold-restore. The lock is per-cache-state, not
per-entry and not per-slot, because target/draft pair ownership and
owner-view sync span multiple entries.

## Design overview

Introduce a single exclusive `cache_state_mutex_` that guards the
controller's mutable state. Every operation that today mutates
`payload_descriptors`, `hot_payloads`, `entries`, `forest`, the cold
store, or related counters acquires this mutex for the duration of its
work. Operations that today return early after enqueuing an async
worker task are rewritten so the same work happens synchronously
inside the critical section. The async I/O worker is repurposed into a
synchronous helper that the transaction invokes inline, with the
mutex held.

Slot requests do not acquire the mutex directly. They call a small
public transaction API on the controller. Each transaction method
acquires the mutex once at entry and releases it once at exit.
Nested calls are detected by a per-thread reentrancy counter and
rejected as a developer error rather than deadlocking.

Part 1 catalogs the current async and background operations.
Part 2 defines the transaction protocol.
Part 3 specifies the per-operation migration.
Part 4 estimates the performance and latency impact.
Part 5 plans the migration steps and rollback.
Part 6 names the new invariants and the architecture cross-reference.
Part 7 lists risks and open questions.

## Contents

- [Part 1: current async architecture survey](cache-handling-phase25-design/part-01-current-async-architecture-survey.md)
- [Part 2: atomic transaction protocol](cache-handling-phase25-design/part-02-atomic-transaction-protocol.md)
- [Part 3: per-operation migration](cache-handling-phase25-design/part-03-per-operation-migration.md)
- [Part 4: performance and latency impact](cache-handling-phase25-design/part-04-performance-and-latency-impact.md)
- [Part 5: migration path](cache-handling-phase25-design/part-05-migration-path.md)
- [Part 6: new invariants and architecture cross-reference](cache-handling-phase25-design/part-06-new-invariants-and-architecture-cross-reference.md)
- [Part 7: risks and open questions](cache-handling-phase25-design/part-07-risks-and-open-questions.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 25 design authoring | PASS |
| Stage 25 independent design review-fix | PASS (D25-ARCH-01) |
| Stage 25 Manager design gate | PASS (D25-DESIGN-01) |
| Stage 25 implementation planning | PASS |
| Stage 25 implementation | PASS (D25-EXEC-01) |
| Stage 25 test plan | PASS (D25-TEST-PLAN-01) |
| Stage 25 QA execution | 14 PASS / 1 BLOCKED-evidence-gap / 2 BLOCKED-structural-not-infra |
| Stage 25 Manager closure | PASS (D-CLOSURE-25-01) 2026-06-25 |

## Handoff

Next owner: user. Manager closure D-CLOSURE-25-01 accepted on
2026-06-25. Code changes UNCOMMITTED per AGENTS.md; user approval
required for commit. See the Stage 25 implementation log closure
record for per-row classification, code change summary, and
follow-up task list.

This document uses LF line endings, plain ASCII labels, no BOM, no
trailing whitespace, and stays under the 300-line durable-doc cap.
