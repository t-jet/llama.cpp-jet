# Part 38: independent generation-boundary review

Date: 2026-07-13
Verdict: REWORK
Scope: design Parts 35 and 37, implementation Parts 73 and 74, test-plan
Part 43, entry documents, index, and current controller code

## Decision

The correction chooses the right mutex boundary, keeps the extra generation
under `LLAMA_STAGE39_LIVE_TEST_SEAM`, orders checkpoint arming after
verification, and binds the two boundary values into terminal validation and
the HMAC. Its planned hook would not advance exactly once in current code.
Manager acceptance and code work remain blocked.

## Review checks

| Check | Result | Basis |
| --- | --- | --- |
| Hook and mutex | PASS | `mark_payload_evicted()` runs under `cache_state_mutex_` through the transactional pressure path and calls exact before checkpoint. |
| Step 2 order | PASS WITH BLOCKER | The plan puts step 2 binding and arming after accounting and branch verification, but its refresh and sync calls already own generation side effects. |
| Seam-OFF behavior | PASS | The proposed state, helper, and explicit advance require `LLAMA_STAGE39_LIVE_TEST_SEAM`; the default build has no added generation path. |
| HMAC chain | PASS | Terminal serialization orders both boundary generations before step 2 and final generation, then computes one HMAC after `tx_update()`. Retrieval checks the frozen values under the mutex. |
| No-double-advance evidence | PASS WITH BLOCKER | The named controller and route assertions are sufficient once the first boundary has one unambiguous generation owner. |
| Code feasibility | REWORK | Existing demotion completion and branch-sync behavior conflict with the planned delta of one. |

## Blocking finding

### F39-GBR-01: planned boundary has more than one generation owner

Part 37 records `exact_demotion_generation`, calls
`refresh_entry_payload_accounting()`, calls `sync_branch_node_from_entry()`,
then calls `advance_cache_generation_locked()`. Current code does not make
those first two calls generation-neutral:

- `refresh_entry_payload_accounting()` calls `STAGE39_CACHE_MUTATED()` when
  cached bytes or payload flags change;
- `sync_branch_node_from_entry()` calls `STAGE39_CACHE_MUTATED()`
  unconditionally; and
- under `LLAMA_STAGE39_LIVE_TEST_SEAM`, that macro calls
  `advance_cache_generation_locked()`.

The exact demotion completion path already refreshes the owner entry and syncs
its branch before `tx_demote_payload()` returns. The successful
`mark_payload_kind_evicted()` path refreshes the entry again. Calling both
mutators once more in the new helper advances at least once in branch sync,
then the explicit advance advances again. This contradicts D39-EXEC-13,
`phase_boundary_generation == exact_demotion_generation + 1`, and the proposed
no-double-advance assertions.

Correct Parts 37, 74, 35, 73, and test-plan Part 43 to give the boundary one
owner. The narrow feasible sequence is:

1. After the successful exact-kind call, record the current generation. Do not
   call either mutation helper again.
2. Verify that the completed production demotion has already reconciled exact
   cold plus checkpoint hot descriptor and entry accounting, and that the
   branch carries both payload links plus the expected aggregate residency and
   byte projection.
3. On mismatch, latch the guarded terminal error without advancing or calling
   checkpoint preparation.
4. On match and only from `awaiting_exact_boundary`, call
   `advance_cache_generation_locked()` once, store that value as the phase
   boundary and step 2 expected generation, set the one-shot state, then arm
   capture.
5. A repeated call must fail closed before any mutator or generation call.

This uses the production demotion's existing accounting and branch sync as the
state transition, then gives the verified proof boundary one guarded marker
advance. It preserves helper signatures and changes no seam-OFF behavior. If
the design instead refactors the two mutation helpers, it must name a
generation-neutral projection/apply path and prove ordinary callers retain
their current generation ownership.

Extend the controller test to record the generation returned by the exact-kind
call, require unchanged generation during boundary validation, then require
exactly one increment before step 2 arm. The duplicate-call test must observe
the same generation before and after the rejected second attempt. Route HMAC
tamper tests remain binding.

## Handoff

Developer owns a documentation-only correction for F39-GBR-01. Return it for a
fresh independent Architect review. Code, tests, builds, model execution,
coverage, QA, commit, and push remain blocked.
