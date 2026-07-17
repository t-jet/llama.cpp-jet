# Part 118: Architect D39-EXEC-29 Stage 23 expectation review

Date: 2026-07-14
Status: REWORK REQUIRED; TEST-ONLY CONTRACT CORRECTION
Reviewed: Parts 116-117, Stage 39 policy and transaction code, the affected
Stage 23 test, and the two Stage 28 rejection regressions

## Verdict

Part 117 classifies the product behavior correctly. The second 700 KiB object
fits the positive 1 MiB cold budget after the transaction evicts the eligible
first object. Production must commit the incoming object as
`retained_cold/cold_room_made`, leave the victim descriptor as an `evicted`
tombstone, and record `commit/none`. Restoring the old
`demotion_budget_pressure` fallback would violate Stage 39.

The proposed test plan is not executable as written. It requires final
`n_payload_evictions == 1`, but each `debug_evict_*_payload_for_tests()` wrapper
increments that counter after `mark_payload_evicted()` returns. The second
cold-room transaction also increments it for the displaced cold victim. From a
fresh controller, the exact sequence is 0 before pressure, 1 after the first
wrapper, and 3 after the second wrapper. The cold transaction's victim must be
proved by `n_cold_evictions`, the descriptor tombstone, and cold-store
reconciliation; the wrapper-inflated generic counter is not sole proof.

Part 117 also stops short of exact byte reconciliation and post-checkpoint
accounting. Those gaps would leave this Release regression weaker than the
transaction it now exercises.

## Required test-only correction

Rename the affected test and its invocation to describe cold room-making and
checkpoint attachment. Keep all setup, mutation, and verdict checks
Release-active. Update only stale Stage 28 comments that claim this Stage 23
test still supplies an evicted second entry; do not change either Stage 28 test
body or invocation.

Use before, after-first, after-second, and after-checkpoint snapshots. Require:

- initial decision and transaction totals are zero;
- after the first wrapper, payload 1 is cold, payload 2 is hot, both entries and
  exact links remain, hot bytes equal 700 KiB, and the only decision and
  transaction are `retained_cold/cold_room` and `commit/none`;
- after the second wrapper, payload 1 is an evicted descriptor tombstone and
  payload 2 is cold; both entries and exact links remain; neither payload is in
  the hot map; hot bytes are zero; descriptor counts are cold 1, evicted 1, hot
  0; demotion successes/failures are 2/0; cold evictions are 1;
- `n_payload_evictions` is exactly 1 after the first wrapper and 3 after the
  second, with a comment that the two wrapper increments are test-helper
  accounting and the extra second-step increment is the cold victim;
- exactly one `.cold` file remains; its bytes equal `n_cold_payload_bytes` and
  `cache_cold_bytes`, are positive, and do not exceed 1 MiB; no quarantine file
  remains;
- final decision rows contain only one `retained_cold/cold_room` and one
  `retained_cold/cold_room_made`; final transaction rows contain only two
  `commit/none`; both family totals are 2;
- `demotion_budget_pressure`, `evicted/both_filled`, rollback, and recovery are
  absent from their respective transition, decision, and transaction families.

Checkpoint admission targets the second entry. Require success, empty failure,
one success and zero failures, a nonzero checkpoint ID, checkpoint kind and
owner linkage to the second entry, target-only hot residency with 96 target
bytes and no draft, and unchanged exact residencies. After admission, require
hot/cold/evicted descriptor counts 1/1/1, resident hot bytes 96, unchanged cold
bytes and cold file, and byte-identical decision and transaction arrays.

The existing
`test_stage28_attach_checkpoint_payload_rejects_evicted_entry` and
`test_stage28_admit_checkpoint_store_rejects_no_tokens_entry` remain the
independent Release-active rejection proof. Keeping both bodies and invocations
unchanged preserves that safety coverage.

## Scope and handoff

This is a bounded test-only correction. No server, controller, route, model,
driver, public metric, or design change is justified. Developer must correct
Part 117 or implement the exact Part 118 contract under a fresh Manager gate.
After approval, rebuild only Release seam `test-cache-controller`, then run the
full controller binary once. Acceptance requires exit zero, the renamed Stage
23 row PASS, both Stage 28 rejection rows PASS, all seven Stage 39 forbidden-
effect probes PASS, and midpoint plus step-2 common-epilogue fault rows PASS.
No rerun is authorized by this review.
