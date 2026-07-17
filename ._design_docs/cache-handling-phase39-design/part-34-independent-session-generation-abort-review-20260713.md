# Part 34: independent session, generation, and abort review

Date: 2026-07-13
Verdict: REWORK
Scope: design Part 33, implementation Part 72, aligned Parts 31 and 71,
test-plan Part 43, entry documents, index, and current pressure code

## Decision

Immutable apply-created session identity, per-step generations, the real seam
guard, and the five named tests are sound. Existing signatures can carry a
guarded terminal latch without production API changes. Three ordering gaps
remain. Each can make a valid proof fail immediately or leave post-fault work
and stale branch state. Manager acceptance and implementation remain blocked.

## Review checks

| Check | Result | Basis |
| --- | --- | --- |
| Session and run binding | PASS | Apply creates one immutable session after retryable validation and binds every record, error, snapshot, and retrieval to both IDs and process identity. |
| Step generation chain | REWORK | Per-step matching is valid, but exact-kind bookkeeping and terminal finalization are not placed after all mutations they must cover. |
| Abort signature feasibility | PASS WITH BLOCKER | `bool` demotion and kind results plus guarded latch checks can preserve current public signatures. Pressure needs its own immediate terminal return. |
| Failure-state safety | REWORK | Step 2 keeps the exact commit, but the specified no-sync return can leave its branch view stale. |
| Compile boundary | PASS | All live proof state and route behavior use default-OFF `LLAMA_STAGE39_LIVE_TEST_SEAM`; subordinate injection alone may use `LLAMA_SERVER_CACHE_TESTS`. |
| Evidence map | PASS | Part 43 names three controller tests and two route tests for the corrected chain and abort behavior. |

## Blocking findings

### F39-SGAR-01: terminal generation freezes before later mutations

Part 33 freezes `final_generation` after checkpoint eviction and accounting.
Current `evict_entry_by_id()` then removes the retained entry from the LRU.
`remove_from_lru_index()` advances `cache_generation_`. `update()` can also run
cold cleanup, metadata pruning, and token pressure after hot pressure. A
snapshot frozen inside checkpoint marking can therefore be stale before
`tx_update()` returns.

Freeze the terminal snapshot only in the guarded caller after the complete
normal `tx_update()` returns, the latch is clear, the expected exact and
checkpoint results are verified, and all update-owned mutations are complete.
Store that current generation as `final_generation`, then compute the HMAC.
Retrieval must require equality with that value. Also place step 2's expected
generation after all exact-kind accounting and branch synchronization, not
merely after `tx_demote_payload()` returns.

### F39-SGAR-02: pressure performs work after a terminal abort

Part 33 lets `evict_entry_by_id()` return `false` and says
`evict_until_within_budget()` stops its plan. Current pressure code breaks the
loop, then may emit the unsatisfied-budget warning and always calls
`record_branch_metadata_pressure()` before `update()` can inspect the latch.
That contradicts the promised return before pressure diagnostics.

After a false eviction result, `evict_until_within_budget()` must check the
guarded latch and return immediately. It must skip remaining victims, the
unsatisfied-budget classification or warning, and branch-pressure diagnostics.
Ordinary false results keep current behavior. `update()` then performs its
second latch check and returns before cleanup, pruning, or token pressure.

### F39-SGAR-03: step 2 abort can leave committed exact state unsynchronized

Successful exact demotion updates descriptor, hot bytes, entry accounting,
and generation. Current branch synchronization normally occurs only after both
kind calls in `mark_payload_evicted()`. Part 33 instead requires a checkpoint
abort to return without further sync work. That can leave the branch node's
payload bytes or residency view behind the committed exact state.

Complete exact-kind accounting and `sync_branch_node_from_entry()` before
arming step 2 and before checkpoint preparation. Store step 2's expected
generation after that sync. A later checkpoint abort can then return without
post-fault repair while exact remains cold, checkpoint remains hot and linked,
and entry plus branch views agree. Add these state checks to the step 2
controller test.

## Closed prior findings

F39-PSR-03 is closed. F39-PSR-01 and F39-PSR-02 are corrected in structure but
remain open until F39-SGAR-01 through F39-SGAR-03 fix the exact call ordering.
The requested three controller and two route test names are present and remain
binding.

## Handoff

Developer owns documentation correction only. Update design Part 33,
implementation Part 72, and test-plan Part 43 with the exact finalization,
pressure-return, and exact-sync positions. Return them for fresh independent
Architect review. No code, tests, builds, model execution, coverage, QA,
commit, or push is authorized.
