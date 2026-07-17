# Part 36: independent terminal ordering review

Date: 2026-07-13
Verdict: REWORK
Scope: design Part 35, implementation Part 73, aligned Parts 33 and 43,
entry documents, index, and current pressure code

## Decision

The correction puts terminal freeze after the full `tx_update()`, returns from
hot pressure before post-loop diagnostics on a guarded abort, and gives step 2
a coherent exact-cold/checkpoint-hot failure state. One generation hook is
still missing from the exact-kind phase boundary. Manager acceptance and code
work remain blocked.

## Review checks

| Check | Result | Basis |
| --- | --- | --- |
| Terminal freeze | PASS | `stage39_live_pressure_control()` already holds `cache_state_mutex_` across synchronous `tx_update()`. Freezing after that call includes `remove_from_lru_index()` and later update-owned cleanup, pruning, and token pressure. |
| Retrieval and HMAC order | PASS | Finalization first verifies terminal state, stores the current final generation, serializes once, and computes the HMAC. Response assembly follows it; retrieval checks the frozen chain and current generation under the same lock. |
| Pressure abort return | PASS | A latch check in the false-result branch of `evict_until_within_budget()` can return before its unsatisfied-budget warning and `record_branch_metadata_pressure()`. The second check in `update()` can then skip later phases. No signature change is needed. |
| Exact-kind failure state | PASS WITH BLOCKER | Exact accounting and branch sync now precede checkpoint capture. Their mutation is not assigned a production-generation advance before step 2 is armed. |
| Signature feasibility | PASS | Existing `bool` results from `tx_demote_payload()` and `mark_payload_kind_evicted()`, `void` outer calls, and the guarded latch support the planned early returns. |
| Test order | REWORK | Named tests cover the call order and terminal states, but they do not require a generation advance after the compound accounting-and-branch-sync boundary. |

## Blocking finding

### F39-TOR-01: exact phase-boundary mutation has no generation owner

Part 35 requires `refresh_entry_payload_accounting()` and
`sync_branch_node_from_entry()` to complete before step 2's expected generation
is stored. Current inline demotion advances `cache_generation_` before its final
entry-accounting refresh. `mark_payload_kind_evicted()` refreshes accounting
again after `tx_demote_payload()` returns. `sync_branch_node_from_entry()` then
writes branch links, bytes, flags, and residency without calling
`STAGE39_CACHE_MUTATED()` or `advance_cache_generation_locked()`.

Storing the existing generation after those writes contradicts Part 33's rule
that every cache mutation advances the one production generation. It also
makes the claimed post-sync step boundary indistinguishable from the preceding
demotion generation.

For an active prepared-proof session, define the accounting refresh plus branch
sync as one guarded phase-boundary mutation. After both complete and their
views verify, advance `cache_generation_` exactly once, then store that value as
step 2's expected generation and arm checkpoint capture. The advance must not
occur on an abort, failed verification, ordinary non-proof pressure, or a
read-only retrieval. Keep the existing helper signatures.

Extend
`test_stage39_live_pressure_prepared_proof_generation_chain` to capture the
generation immediately after exact demotion, require the phase-boundary advance
after accounting and branch sync, require step 2's expected generation to equal
that new value, and prove checkpoint preparation cannot run before it. Existing
abort-state and post-`tx_update()` finalization assertions stay binding.

## Handoff

Developer owns a documentation-only correction to design Part 35,
implementation Part 73, and test-plan Part 43. Return the corrected ordering
for fresh independent Architect review. Code, tests, builds, model execution,
coverage, QA, commit, and push remain blocked.
