# Part 42: independent both-kind batch-boundary review

Date: 2026-07-13
Verdict: REWORK
Scope: design Part 41, implementation Part 78, Developer Part 77,
superseded Parts 39, 40, 75, and 76, test-plan Part 43, entry documents,
index, and current controller code

## Decision

D39-EXEC-16 fixes the main ordering error. Midpoint validation now excludes
the stale branch aggregate, checkpoint capture runs before capacity handling,
and the normal outer branch synchronization remains available after a step-2
fault. Two boundary cases remain underspecified. Manager acceptance and code
work stay blocked.

## Verified design points

- `tx_demote_payload()` commits exact cold state, erases its hot record, and
  refreshes entry accounting before returning. It does not sync the branch.
- `mark_payload_evicted()` owns the common branch sync after both kind calls.
  That location can reconcile exact-cold/checkpoint-hot state after a guarded
  checkpoint fault without changing seam-OFF ordering.
- Capture immediately after `cold_store.prepare()` can remove staging and
  return before cold-budget classification, victim enumeration, manifest
  admission, descriptor eviction, hot erase, unlink, and forest mutation.
- The latch can then stop `evict_entry_by_id()`, the pressure loop, and
  `update()` before counters, LRU removal, later pressure, cleanup, and
  diagnostics. Final guarded validation remains feasible after `tx_update()`
  returns.
- Part 41 removes the synthetic boundary advance. Compile and runtime guards
  remain `LLAMA_STAGE39_LIVE_TEST_SEAM`, so seam-OFF behavior can stay
  unchanged.

## Blocking findings

| ID | Finding | Required correction |
| --- | --- | --- |
| F39-BBR-01 | Midpoint mismatch occurs after exact has committed and while the branch still projects exact-hot plus checkpoint-hot. Part 41 says to latch and skip checkpoint, but its common-cleanup rule starts only after the checkpoint call returns. Part 78 likewise does not say that this path preserves exact `changed`, runs the outer sync, validates coherent exact-cold/checkpoint-hot state, then propagates the latch. No named test covers this fault. An early latch return can leave the branch stale. | Require every post-exact midpoint failure to bypass checkpoint but still run the same outer common sync before `evict_entry_by_id()` observes the latch. Limit that sync to the already committed exact state. Add controller and route tests that corrupt one midpoint field, prove no checkpoint prepare/classification/admission/unlink, and prove coherent entry, branch, file, byte, and generation state before the terminal response. |
| F39-BBR-02 | Part 41 permits `both_kind_complete_generation == exact_return_generation` after a step-2 fault. Current exact return leaves the branch stale. `sync_branch_node_from_entry()` then updates that branch and unconditionally calls `STAGE39_CACHE_MUTATED()`. Equality therefore cannot prove the required common sync and does not match current generation ownership. | Require the fault chain to observe the production common-sync advance after exact return. Record exact return, common-sync completion, and final post-update generations in order; require common-sync completion to be later when the stale branch is reconciled. Keep fixed deltas out of the contract. Extend success, step-2 fault, midpoint-fault, HMAC, and tamper tests to prove no explicit or duplicate seam-only advance. |

## Supersession check

Parts 39, 40, 75, and 76 are correctly marked historical. Part 77 remains the
accurate blocker record for D39-EXEC-15. Part 41 and Part 78 may supersede their
boundary wording only after F39-BBR-01 and F39-BBR-02 close. Earlier session,
prepared-record, abort, terminal, HMAC, natural same-owner, compile-OFF, and
runtime-OFF contracts remain binding.

## Handoff

Developer owns a documentation-only correction to Parts 41, 78, and test-plan
Part 43. Fresh independent Architect re-review is required. No code, build,
test, model run, coverage, commit, or push is authorized.
