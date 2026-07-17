# Part 14: final policy fix and verification

Date: 2026-07-12
Status: PARTIAL

## Production contract completed

Hot-pressure eviction now calls `tx_demote_payload` with final-decision
emission deferred. A non-capacity failure retains the hot descriptor, bytes,
entry, and branch owner. The eviction caller stops without unlinking the entry.
Only a cold-capacity failure may continue to payload eviction, where the caller
records `evicted/both_filled`.

The caller records one final decision for the candidate. Cold transaction rows
remain transaction evidence and do not replace or duplicate that decision.

## Focused regression

`test_stage39_non_capacity_demotion_failure_retains_hot` drives the production
pressure path with an injected cold write failure. It verifies hot byte
retention, zero payload evictions, `retained_hot/io_error`, and one final
decision.

## Verification

- Release `test-cache-controller` and `llama-server` build: PASS.
- Release controller executable: PASS, `All tests passed successfully!`.
- `ctest --test-dir build -C Release -R cache --output-on-failure`: PASS, 1/1.
- Existing compiler warnings at test lines 6109, 6122, and 6230 are unchanged.

## Remaining gate

Implementation-ready is not declared. TP-39-13 still needs complete exact-fit,
one-byte-over, serialized-format overhead, and checked-add overflow controller
rows. TP-39-14 still needs controller-level fault seams and fresh-controller
pre-commit/post-commit recovery, multi-victim replay, exact/checkpoint owner,
idempotence, conflicting-state, missing-owner, and claimed-path rows. Live
automation and focused changed-line coverage also remain open. No large-model
run was attempted.
