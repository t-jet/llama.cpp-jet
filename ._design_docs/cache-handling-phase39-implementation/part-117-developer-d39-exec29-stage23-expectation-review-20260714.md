# Part 117: D39-EXEC-29 Stage 23 expectation review

Date: 2026-07-14
Status: REWORK REQUIRED; TEST EXPECTATION STALE
Owner: Manager for a bounded test-only correction gate

## Classification

Part 116 exposes a test-plan mismatch, not a product defect. The Stage 23 test
still expects the pre-Stage 39 fallback: reject the second 700 KiB demotion
when the 1 MiB cold budget is occupied, evict the second payload, and report
`demotion_budget_pressure`.

Current `tx_demote_payload()` uses the Stage 39 two-layer transaction. The
second serialized object fits the positive cold budget by itself. The first
cold payload belongs to another entry and is eligible for room-making, so it
becomes the transaction victim. The transaction publishes payload 2, commits,
marks payload 1 evicted, and records:

- `retained_cold/cold_room_made` for payload 2;
- `commit/none` for the second cold transaction;
- payload 1 `evicted` and payload 2 `cold`.

This matches the Stage 39 rule that payload bytes are discarded only when
neither enabled layer can retain the complete incoming object. Restoring the
old immediate-eviction expectation would contradict the active policy.

History confirms the drift. Stage 23 originally tested an asynchronous pending
demotion and expected the second object to be evicted. Stage 28 made demotion
synchronous but kept that fallback expectation. Stage 39 removed the obsolete
hot demotion-reserve rejection and added atomic cold-victim replacement.

## Exact Release-active correction

Change only
`test_stage23_demotion_budget_fallback_stale_completion_checkpoint_attach`.
Keep every setup and side-effect call behind `require_or_abort`. Rename the
test and its comments to describe cold room-making and checkpoint attachment.

After the first eviction, require payload 1 `cold`, payload 2 `hot`, one
`retained_cold/cold_room` decision, and one `commit/none` transaction.

After the second eviction, require all of these exact results:

- payload 1 is `evicted`; payload 2 is `cold`;
- neither payload remains in `stage22_hot_payloads(ctrl)`;
- `resident_payload_bytes == 0`, `n_cold_payload_count == 1`,
  `n_cold_payload_descriptors == 1`, and
  `n_evicted_payload_descriptors == 1`;
- `n_demotion_successes == 2`, `n_demotion_failures == 0`,
  `n_cold_evictions == 1`, and `n_payload_evictions == 1`;
- cold bytes are positive and no greater than the configured 1 MiB budget;
- decision rows are exactly one `retained_cold/cold_room` and one
  `retained_cold/cold_room_made`, with total decision value 2;
- transaction rows are exactly two `commit/none`, with total transaction
  value 2;
- `demotion_budget_pressure`, `evicted/both_filled`, rollback, and recovery
  rows are absent.

Checkpoint admission must now target the second, retained-cold entry. Require
the call to succeed, `failure` to stay empty, a nonzero checkpoint payload ID,
that checkpoint descriptor to be `hot`, payload 2 to remain `cold`, and payload
1 to remain `evicted`. Require checkpoint admissions `1/0` success/failure.
Also require the decision and transaction arrays to remain unchanged across
checkpoint admission.

This strengthens the test around current policy. It proves victim state,
incoming state, exact decision ownership, transaction commit ownership,
accounting, and a safe post-transaction checkpoint attach. Evicted-entry
rejection remains covered by
`test_stage28_attach_checkpoint_payload_rejects_evicted_entry` and
`test_stage28_admit_checkpoint_store_rejects_no_tokens_entry`; do not weaken or
remove either test.

## Bounded fix and retest

Next Developer may edit only this Stage 23 test and its invocation name. No
product, server, route, model, driver, or design change is justified.

After fresh Architect review and Manager approval, rebuild only Release seam
`test-cache-controller`, then run the full controller binary once. Acceptance
requires exit zero, the corrected Stage 23 row PASS, both Stage 28 rejection
rows PASS, all seven Stage 39 forbidden-effect probes PASS, and midpoint plus
step-2 fault rows PASS. No rerun is authorized by this review.
