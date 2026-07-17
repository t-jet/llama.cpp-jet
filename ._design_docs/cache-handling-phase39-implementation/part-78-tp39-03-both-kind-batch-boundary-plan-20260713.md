# Part 78: TP-39-03 both-kind batch-boundary plan

Date: 2026-07-13
Status: REVIEWED REWORK IN DESIGN PART 42
Authority: D39-EXEC-16 and design Part 41

## Controller plan

Keep all additions under `LLAMA_STAGE39_LIVE_TEST_SEAM` and preserve current
production signatures.

1. Add a guarded midpoint observer after successful exact-kind return. Validate
   only the prepared record, descriptors, stores, files, cold accounting, hot
   checkpoint record, and entry accounting listed in design Part 41. Do not
   read branch aggregate as a completed projection.
2. On midpoint success, store the current generation as both exact-return and
   step-2 expected generation, then arm checkpoint capture. Do not call a cache
   mutator or `advance_cache_generation_locked()`.
3. Call the checkpoint kind. Its prepared-record validation remains inside
   `tx_demote_payload()` after `cold_store.prepare()` and before budget
   admission or victim enumeration.
4. If step 2 latches an error, make `mark_payload_kind_evicted()` return before
   capacity classification, decision, admission, residency change, hot erase,
   unlink, forest eviction, or other checkpoint work.
5. Do not return from `mark_payload_evicted()` at that point. Exact kind has
   already refreshed entry accounting. Preserve its `changed` result and run
   the existing outer branch sync. Do not add another refresh or repair. Only
   then expose the latch to `evict_entry_by_id()`.
6. Keep the existing guarded early returns in `evict_entry_by_id()`,
   `evict_until_within_budget()`, and `update()` after common cleanup. They must
   precede LRU/counter changes, warning/diagnostic emission, cold cleanup,
   metadata pressure, and later victims.
7. After `tx_update()`, validate final branch state for success. For step-2
   failure, validate coherent exact-cold/checkpoint-hot state and forbidden
   side-effect deltas before returning the redacted terminal error.

## Generation and proof plan

Delete the synthetic phase-boundary advance, delta-one field, and duplicate
boundary contract from Parts 39 and 75. Store and serialize:

- step-1 preparation generation;
- exact-return generation;
- step-2 expected and preparation generations;
- both-kind completion generation; and
- final post-update generation.

Bind the ordered values to process, session, run, owner, request, role, payload,
kind, pair, component sizes, checksums, serialized sizes, result, and terminal
state. HMAC creation and retrieval use one canonical field order. Retrieval
rejects missing, reordered, duplicated, or modified observations and any
current-generation drift.

Assertions require no generation change between exact return and checkpoint
prepare, a production-owned advance after step 2 on the success path, and no
seam-only advance. Do not require a fixed numeric delta across demotion,
classification, cleanup, or finalization.

## Tests

Add the four controller and two route tests named in design Part 41. Adapt the
existing prepared-proof tests for step-1 abort, terminal finalization, stale
retrieval, and natural TP-39-03. Remove assertions for `delta == 1`, a synthetic
boundary field, and duplicate guarded boundary invocation.

The step-2 fault fixture fires after `cold_store.prepare()` has produced the
authenticated record and before budget handling. It must prove staging cleanup,
common entry/branch reconciliation, retained exact cold file, retained hot
checkpoint, and zero forbidden effects. The success fixture must prove normal
checkpoint `evicted/both_filled`, common cleanup, post-update branch validation,
and an authenticated real generation sequence.

After a Manager gate, run focused controller and route suites. Model execution,
canonical TP-39-03, coverage, full QA, commit, and push remain blocked pending
fresh implementation review.

## Supersession and handoff

This plan supersedes implementation Part 75 and the conflicting phase-boundary
steps in Parts 72 through 74. Part 77 remains the correct record of why
D39-EXEC-15 stopped before code change. Design Part 41 is the current contract.

Design Part 42 records REWORK. Developer must correct F39-BBR-01 and
F39-BBR-02 before fresh independent Architect re-review. No code or tests
changed in this documentation correction.
