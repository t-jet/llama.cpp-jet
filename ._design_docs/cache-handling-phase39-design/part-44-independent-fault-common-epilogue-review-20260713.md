# Part 44: independent fault common-epilogue review

Date: 2026-07-13
Verdict: PASS
Scope: design Part 43, implementation Part 79, historical Part 42, test-plan
Part 43, entry documents, index, and current controller code

## Decision

D39-EXEC-17 is implementable as written. Parts 43 and 79 close F39-BBR-01
and F39-BBR-02. No findings remain. Manager may decide whether to authorize
bounded implementation; this review does not authorize code work.

## Code trace

- `tx_demote_payload()` prepares before capacity classification, commits the
  cold descriptor and accounting, erases the hot record, refreshes entry
  accounting, records the exact decision and transaction, then returns.
- `mark_payload_kind_evicted()` preserves successful exact demotion as `true`.
  `mark_payload_evicted()` carries it across checkpoint work and owns common
  branch synchronization after both kind calls.
- `refresh_entry_payload_accounting()` advances generation only on change.
  Exact demotion already refreshes all entries, so planned outer reconciliation
  is read-only in these fixtures.
- `sync_branch_node_from_entry()` copies both kind links and accounting to the
  branch, then invokes normal production generation ownership. A stale branch
  therefore yields `common_sync_generation > exact_return_generation`.
- `evict_entry_by_id()` starts counters and LRU removal only after
  `mark_payload_evicted()` returns. Planned latch propagation can stop that work
  without changing public or production helper signatures.

## Contract checks

| Check | Verdict | Basis |
| --- | --- | --- |
| Midpoint mismatch | PASS | Exact `changed` survives; checkpoint is skipped; accounting and one outer branch sync still run. |
| Step-2 fault | PASS | Capture follows prepare and precedes classification. Caller classification, admission, unlink, and later work are forbidden while common epilogue remains reachable. |
| Terminal proof | PASS | Coherence validation and proof freeze follow common sync and precede latch propagation through eviction, pressure, and update. |
| Checkpoint effects | PASS | Midpoint allows no checkpoint prepare. Step 2 allows one prepared record but no classification, admission, publish, commit, final file, descriptor mutation, or unlink. |
| Generation chain | PASS | Exact return, common sync, and final observations are ordered; stale-branch sync requires strict `>` with no fixed delta or guarded advance. |
| Seam isolation | PASS | Additions stay under `LLAMA_STAGE39_LIVE_TEST_SEAM`; signatures and seam-OFF ordering remain unchanged. |
| Tests | PASS | Exact controller and route pairs cover both faults, request failure, coherent terminal state, checkpoint non-effects, strict generation order, and no seam-only advance. |

## Supersession and handoff

Part 42 remains historical REWORK evidence. Part 43 supersedes Part 41 fault
wording; Part 79 supersedes matching Part 78 wording. Earlier session,
prepared-record, HMAC, terminal, compile-OFF, runtime-OFF, and natural
same-owner contracts remain binding.

Next owner: Manager for D39-EXEC-17 correction-plan gate. No code, tests, build,
model run, coverage, commit, or push occurred.
