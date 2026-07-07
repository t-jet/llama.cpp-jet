# Stage 34: Design correction - idempotent save (D34-REOPEN-06) and Path B slow-read relocation (D34-REOPEN-07)

## Header

- Status: Active
- Date: 2026-07-05
- Stage: 34 (reopened)
- Owner: Architect
- Active gate: Architect design correction of Manager decisions D34-REOPEN-05..08
- Branch: work-branch
- Source authority: `._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md` (User directive verbatim, 2026-07-05; recorded decisions D34-REOPEN-05..08)
- Skill-load confirmation: Loaded in order at session start: (1) `.agents/skills/self-improvement/SKILL.md`, (2) `.agents/skills/self-improvement/assets/architect.md` (applied every matching Condition/Action), (3) `.agents/skills/architect/SKILL.md`, (4) `.agents/skills/caveman/SKILL.md` (used ultra mode for internal thinking), (5) `.agents/skills/humanizer/SKILL.md` (applied to prose). Latest applied memory entry: "Design correction vs new stage for post-closure follow-ups" and "Post-closure follow-up design review scope and dual-doc traceability".

## Scope

This correction adds two bounded behavior changes to `tx_save` and records one test-plan reclassification, in response to user directive 2026-07-05. It does NOT re-open the Stage 34 design, does NOT change Stage 25 transaction semantics, and does NOT merge slot lifecycle with cache lifecycle (Path E is rejected; see Out of scope).

In scope:

- D34-REOPEN-05: Reclassification note for TP-34-CC as EXPECTED-BEHAVIOR (test-plan wording; cache code unchanged).
- D34-REOPEN-06: Idempotent `tx_save` with hot-counter bump (Behavior change ONE).
- D34-REOPEN-07: Relocate slow `llama_state_seq_get_data_ext` reads outside the lock-held region; lock held only for snapshot read and final mutation commit (Behavior change TWO, "Path B").
- New invariants I-34-01 and I-34-02.

Out of scope (see Out of scope section for rejection rationale): Path C, Path D, Path E, dispatch-ordering fix, slot lifecycle change.

## Bind facts (line numbers verified by Select-String on 2026-07-05)

Code facts, `tools/server/server-cache-hybrid.cpp`:

- `tx_save` signature at L4754.
- `tx_save` acquires `cache_state_mutex_` via `std::lock_guard<std::recursive_mutex> lock(cache_state_mutex_)` at L4759, held for the entire function body.
- Existing dedupe path: `auto existing = find_equivalent_entry(entry_tokens, namespace_id)` at L4819; if a payload-bearing equivalent entry exists, `refresh_existing_entry(existing, protected_root)` at L4822 then `acquire_branch_node_ref_for_slot` at L4824 and `return true` at L4825 (no slow read on this path).
- Slow target read `llama_state_seq_get_data_ext(ctx_tgt, target_payload.data(), ...)` at L4840. Slow draft read `llama_state_seq_get_data_ext(ctx_dft, draft_payload.data(), ...)` at L4855. Both run INSIDE the L4759 lock_guard scope.
- Post-read mutation under lock: re-materialize branch (`materialize_entry_payload` + `sync_branch_node_from_entry` + `acquire_branch_node_ref_for_slot`) at L4896-L4911, or new-entry admission (`admit_entry_with_payload` + `acquire_branch_node_ref_for_slot`) at L4914-L4925.
- `tx_restore` signature at L5176; `cache_state_mutex_` acquired at L5179; `find_nodes_by_token_span` call at L5196.
- `refresh_existing_entry(it, protected_root)` helper at L2998 calls `mark_used(next_use_sequence())` and `use_count` increments inside `mark_used` (server-cache-hybrid.h mark_used).

Code facts, `tools/server/server-cache-hybrid.h`:

- `hybrid_cache_entry` struct at L207; field `size_t use_count = 0` at L219 (the existing hot reuse counter used for LRU/reuse ranking).
- `void mark_used(uint64_t sequence)` at L253: `use_sequence = sequence; use_count++;`.

Code facts, `tools/server/server-cache-graph.cpp`:

- `branch_forest_index` uses its own `std::mutex mutex_`; `std::lock_guard<std::mutex> lock(mutex_)` at L188 (`create_node`), L194 (`remove_node`), L203 (`get_node`), L225 (`find_nodes_by_token_span`), L244 (`find_nodes_by_checksum_span`).
- `find_nodes_by_token_span` body at L199-L219; matches a token-span prefix against every node's `token_span` in the namespace.
- `find_nodes_by_checksum_span` body at L222-L241; matches namespace + checksum + match_tokens against every node's `prefix_checksums[match_tokens - 1]`.

Stage 25 design facts:

- Invariants I-25-01 (atomicity), I-25-02 (isolation), I-25-03 (durability within transaction) at `cache-handling-phase25-design/part-06-new-invariants-and-architecture-cross-reference.md` L11, L30, L49.
- I-25-02 implementation contract (verified text): "never a transient state with descriptor `hot` and `hot_payloads` empty" at part-06 L42-45.
- Lock granularity (single recursive `cache_state_mutex_`, does NOT guard `llama_context` or `server_slot`) at `cache-handling-phase25-design/part-02-atomic-transaction-protocol.md` L7-L32.
- Reentrancy rule (documented inner-call set `tx_save -> tx_evict_entry`, depth limit 4) at part-02 L94-L122.
- `save_slot` migration row 19 (recursive mutex acquired at entry; "existing save tests continue") at `cache-handling-phase25-design/part-03-per-operation-migration.md` L32.
- `try_restore_from_cache` migration row 20 at part-03 L33: split into `tx_restore` (plan + promote, under lock) and second-pass `tx_apply_restore` (after live-slot apply, under lock). This SPLIT established the precedent that a slow slot-owned operation can run between two locked regions.
- OQ-25-01 SPLIT decision (plan under lock, apply outside lock, finalize under lock) recorded as acceptable at `cache-handling-phase25-design/part-07-risks-and-open-questions.md` L28-L43.

Stage 33 reclassification precedent:

- `cache-handling-phase33-design/part-...` (Stage 33 closure): the "Hybrid reuse" row was reclassified `FAIL -> EXPECTED BEHAVIOR` with rationale "not a product regression; expected steady-state answer". Source: `._design_docs/.test_reports/test-report-20260630-03-stage33-01-manager-closure.md` L14, L23, L29, L49 (decision D33-CLOSURE-01).

## Reclassification note for TP-34-CC (D34-REOPEN-05)

Following the Stage 33 precedent (Bind fact 20), TP-34-CC is reclassified from FAIL to EXPECTED-BEHAVIOR for the dispatch-ordering race it observes. Rationale (from part-03 architect review, "Why the cache code correctly returns MISS" + Scenario 1 + Scenario 2 Bob-actual):

- The race window is between two slot-lifecycle events: (a) the predecessor's inference completes and (b) the predecessor's `tx_save` is invoked by `server-context.cpp` post-inference. During that window the predecessor's entry is not yet in `entries` or `forest`, so a duplicate slot's `tx_restore` correctly returns MISS by I-25-02 isolation.
- The cache code is correct: `tx_restore` sees a consistent snapshot and a save that has not started is correctly invisible.
- The dispatch-ordering race is inherent to concurrent dispatch with throttle > 1, the Stage 34 acceptance mode. The hit-rate expectation in the test plan was too optimistic for this dispatch model.

Cache code does not change for this row. The test-plan row classification changes from FAIL to EXPECTED-BEHAVIOR. The cache invariants I-25-01..03 are preserved.

## Behavior change ONE: idempotent tx_save with hot-counter bump (D34-REOPEN-06)

### Where the dedupe lookup runs

The dedupe lookup already runs at L4819 inside the existing dedupe branch (Bind fact 3), under the L4759 lock. The current branch only fires when `find_equivalent_entry(entry_tokens, namespace_id)` returns an entry AND `entry_has_payload_for_restore(*existing)` is true (Bind fact 3). This already prevents duplicate entry creation when an equivalent payload-bearing entry exists at the moment the lock is acquired.

The user directive extends this to the case where the duplicate's `tx_save` runs AFTER the duplicate did its full inference (the Scenario 1 Bob-actual path, where Bob's restore missed; or the case where the duplicate arrived after the predecessor committed). D34-REOPEN-06 says: "Bob on his own turn should find that prompt is already in cache and increase hot counter instead of creating his own cache record."

This is already the current code path. The dedupe at L4819-L4825 catches it: `find_equivalent_entry` finds the predecessor's entry that Alice's earlier `tx_save` committed, `refresh_existing_entry` bumps the hot reuse counter, and `tx_save` returns `true` without doing the slow read at L4840/L4855.

### Match fields

Match uses the same fields `tx_restore` uses for exact-hit lookup (Bind fact 6, 11, 12):

- Token-span match: `find_nodes_by_token_span` at server-cache-graph.cpp L199 matches namespace + full token-span prefix.
- Checksum-span match: `find_nodes_by_checksum_span` at server-cache-graph.cpp L222 matches namespace + checksum + match_tokens.
- Plus `find_equivalent_entry`'s `canonical_node_id` short-circuit (L3107) and `find_exact_match` fallback (L3118).

Combined with `entry_has_payload_for_restore`, these are the same fields `tx_restore` uses for an exact hit, so dedupe-on-save and exact-hit-on-restore agree on the equivalence relation.

### What "bump hot counter" means in concrete code terms

The existing field is `use_count` on `hybrid_cache_entry` (Bind fact 8, server-cache-hybrid.h:219). It is incremented by `mark_used(next_use_sequence())` (Bind fact 9, server-cache-hybrid.h:253-255). `refresh_existing_entry` (server-cache-hybrid.cpp:2998) already calls `mark_used` on the existing iterator and then `sync_branch_node_from_entry` propagates `use_count` to the branch_node (server-cache-hybrid.cpp:3239). No new field needs to be added. "Bump hot counter" means: `existing->mark_used(next_use_sequence())` runs, `use_count` goes from N to N+1, and the branch_node mirror at L3239 is updated so `select_restore_candidate` LRU ranking reflects the duplicate access.

D34-REOPEN-06 therefore is a documentation-and-design restatement of an existing code path, plus the new invariant below. No new field is introduced.

### What tx_save returns when dedupe is taken

`tx_save` returns `true` at L4825, with no slow `llama_state_seq_get_data_ext` read executed. The duplicate slot avoids saving the same bytes; the existing entry's hot counter is incremented.

### Concurrency argument under I-25-02

The dedupe lookup at L4819-L4825 runs UNDER the L4759 lock_guard. By I-25-02 isolation, the snapshot of `entries` and `forest` seen at L4819 is consistent for the duration of this critical section. A parallel `tx_save` for the same prompt cannot interleave between the `find_equivalent_entry` check and the `mark_used` action because both are inside the same critical section. Either the parallel save committed before this lock acquire (and the lookup finds it), or it has not yet started (and this save creates the entry; the parallel save will later see it via the same lookup). The check-then-act pattern is atomic under the lock.

### New invariant I-34-01

I-34-01: idempotent save - a slot whose prompt token-span and namespace match an existing payload-bearing entry never creates a duplicate entry; the existing entry's `use_count` increments exactly once per such save; `tx_save` returns true without invoking `llama_state_seq_get_data_ext`.

### What this does NOT fix

I-34-01 does NOT fix the Scenario 1 Bob-actual dispatch-ordering miss (Bind fact part-03 Scenario 2 step d). When Bob's restore ran before Alice's save committed, Bob's `tx_restore` correctly returned MISS. The idempotent save only protects against duplicate entry creation on the SAVE side. The original miss remains EXPECTED-BEHAVIOR per D34-REOPEN-05.

## Behavior change TWO: relocate slow read outside the lock (D34-REOPEN-07, Path B)

### New ordering

`tx_save` is restructured to follow the same SPLIT precedent OQ-25-01 established for `tx_restore` (Bind fact 18, 19):

1. Acquire `cache_state_mutex_` (first critical section).
2. Run input validation (token nonempty, budget check, task non-null).
3. Try D34-REOPEN-06 dedupe lookup. If it hits, bump `use_count` and return true (no slow read, no second lock pass). [Existing L4819-L4825 path.]
4. Snapshot the read-only inputs the slow read needs: `slot.id`, `slot.ctx_dft`, `state_size_tgt`, `state_size_dft`, `entry_tokens`, `metadata`, `namespace_id`, `runtime_has_draft`, `protected_root`.
5. Release `cache_state_mutex_`.
6. Run the slow reads OUTSIDE the lock: `llama_state_seq_get_data_ext(ctx_tgt, target_payload.data(), state_size_tgt, slot.id, ...)` (was L4840) and `llama_state_seq_get_data_ext(ctx_dft, draft_payload.data(), state_size_dft, slot.id, ...)` (was L4855). Buffers `target_payload` and `draft_payload` are local to this call; they are NOT shared cache state.
7. Re-acquire `cache_state_mutex_` (second critical section).
8. Re-run D34-REOPEN-06 dedupe lookup under the lock. If a parallel tx committed the same prompt while this slot was reading, take the dedupe path (bump `use_count`, discard the now-redundant buffers, return true). Otherwise proceed.
9. Run the existing post-read mutation under the lock: `materialize_entry_payload` (re-materialize case, L4896-L4911) or `admit_entry_with_payload` (new-entry case, L4914-L4925). Both call helpers that assert mutex held.
10. Release `cache_state_mutex_`.

The cache-state mutations (`entries`, `forest`, `hot_payloads`, `payload_descriptors`, `lru_index`, `prefix_index`) all still run inside either the first or the second critical section. I-25-01 atomicity is preserved at the granularity of each critical section.

### Why the slow read is safe outside the lock

Per the Stage 25 lock-granularity rule (Bind fact 15, part-02 L7-L32), `cache_state_mutex_` does NOT guard the `llama_context` and does NOT guard the `server_slot`. The slot thread owns its live `llama_context` for inference and apply. During `tx_save`:

- The slot is in `tx_save`, which is invoked by `server-context.cpp` after the slot's inference loop completes. The slot is NOT running inference concurrently.
- The slot's `llama_context` (`ctx_tgt`, `slot.ctx_dft`) is stable for the duration of `tx_save`; no other thread mutates this slot's context while the slot is in `tx_save`.
- The reads at L4840/L4855 read the slot's own state, not shared cache state. The buffers are function-local `std::vector<uint8_t>`.

Therefore no other lock should be held during the slow read. The same reasoning that justified the apply-step SPLIT for `tx_restore` (Bind fact 18, part-03 L130-L138) justifies the slow-read SPLIT for `tx_save`.

### Snapshot-to-mutation window guard

Between step 4 (snapshot) and step 7 (re-acquire), another slot's `tx_save` for the same prompt could commit an equivalent entry. The guard is the second-pass dedupe at step 8: under the second lock, re-run `find_equivalent_entry`. If a match exists, bump `use_count` and return true (the redundant local buffers are freed by going out of scope). If no match exists, proceed to admit or re-materialize, atomically with respect to other transactions because the second lock is held.

The slot's intent to commit is not observable to other slots during the read window: the slot has not written any cache state, has not modified `entries`, `forest`, or `hot_payloads`, and has not registered its intent anywhere visible. Other slots that race a `tx_save` for the same prompt will independently dedupe against the first one to commit on their second lock pass.

### Interaction with Behavior change ONE

Under D34-REOPEN-06, the second-pass dedupe at step 8 is identical to the first-pass dedupe at step 3. Behavior change ONE's invariant I-34-01 holds on both passes. The combination: a slot either finds the equivalent entry on the first pass (no slow read at all), or reads its buffers, then on the second pass either dedupes against a parallel committer (buffers discarded, `use_count` bumped) or admits its own new entry.

### New invariant I-34-02

I-34-02: tx_save slow-read-outside-lock - the slow `llama_state_seq_get_data_ext` reads of the slot's own `llama_context` do not hold `cache_state_mutex_`; the only cache-state mutations occur inside the first or second critical section; a parallel tx_save for the same prompt cannot produce two entries for the same token-span + namespace + payload residency combination.

## New invariants table

| ID | Statement | Stage 25 interaction |
| --- | --- | --- |
| I-34-01 | Idempotent save: equivalent payload-bearing entry exists -> no new entry, `use_count`++, `tx_save` returns true without slow read. | Preserves I-25-02 isolation (lookup-and-bump atomic under one critical section). Strengthens I-25-01 atomicity (no partial duplicate entry). |
| I-34-02 | `tx_save` slow `llama_state_seq_get_data_ext` reads run outside `cache_state_mutex_`; cache-state mutations only inside first or second critical section. | Preserves I-25-01 atomicity (each critical section is atomic), I-25-02 isolation (parallel tx observes either pre-admission or post-admission state, no transient), I-25-03 durability (no cold-store write in `tx_save`). Reuses OQ-25-01 SPLIT precedent. |

## Architecture impact

The slot lifecycle separation from cache lifecycle (Stage 25 design choice, Bind fact 15) is PRESERVED. Neither behavior change merges the two lifecycles:

- Behavior change ONE touches only cache state (`entries`, `branch_node.use_count`); it does not require the dispatcher to know about `tx_save` progress.
- Behavior change TWO moves a slow slot-owned read outside the lock; it does not require the dispatcher to wait for `tx_save`. The slot's recyclability is unchanged.

Path E (delay slot recycling until predecessor's `tx_save` commits) is NOT taken. The cache controller does NOT gain a "save-in-progress" signal to the dispatcher. The dispatcher continues to assign free slots without consulting `tx_save` state.

## Risks

Behavior change ONE:

- Risk: cache entry churn if the existing entry was demoted (cold residency) between the check at L4819 and a later read on the branch_node. Mitigation: the dedupe at L4819 already requires `entry_has_payload_for_restore(*existing)` (hot residency with bytes installed); a cold-only or evicted entry does not satisfy this predicate and `tx_save` falls through to the slow read path. The check and the path are inside one critical section, so the residency cannot change under the lock.

Behavior change TWO:

- Risk: a snapshot taken at step 4 (state_size values, slot.id, slot.ctx_dft) becomes stale if another thread mutates the slot between step 4 and step 6. Mitigation: per Stage 25 lock-granularity (Bind fact 15) the slot thread owns its slot; no other thread mutates `slot.ctx_dft` or the slot's `llama_context` state during `tx_save`. The slot is not running inference during `tx_save`. The snapshot fields are read-only inputs the slow read needs and are stable for the call duration.
- Risk: extra memory pressure while a parallel `tx_save` for the same prompt also buffers its own ~85 MiB target + draft payloads before the second-pass dedupe discards one set. Mitigation: bounded by `n_parallel` * payload size; the budget check at the first critical section still rejects a payload exceeding `limit_size`, and the dispatcher's slot count is the natural bound on concurrent buffers. The duplicate-discard path is acceptable transient memory.
- Risk: a slow read returns short (`n_tgt != state_size_tgt`, was L4841). Mitigation: existing error path is unchanged; `tx_save` returns false inside the second critical section with no cache mutation.

## Testability

C++ unit tests (assertion points, to be added by the test plan, not this design):

- T-34-IDEM-01: two slots with the same prompt token-span and namespace, save both; assert `entries.size() == 1` after both return and the single entry's `use_count` is at least 2. Asserts I-34-01.
- T-34-IDEM-02: one slot saves, second slot saves after first returns; assert second slot's `tx_save` returns true without invoking `llama_state_seq_get_data_ext` (detect via a debug hook that counts slow-read calls).
- T-34-PATHB-01: a slot in `tx_save` plus a second slot attempting `tx_restore` for an unrelated prompt; assert the restore completes during the slow-read window without blocking for the slow-read duration (lock wait time below `transaction_wait_threshold_ms`). Asserts I-34-02.
- T-34-PATHB-02: two slots race `tx_save` for the same prompt with staggered starts; assert one entry is admitted, the other takes the second-pass dedupe; assert `use_count` reflects both calls. Asserts I-34-01 under Path B.

Harness rows (proposed for the Stage 34 reopen test plan, not authored here):

- Concurrent warm replay against the existing fixture: assert `cache_entries_total` metric does not increase by more than the count of distinct prompts (no duplicate entries from concurrent duplicate saves).
- Concurrent warm replay: assert `cache_state_mutex_wait_seconds` p99 (when added) is below the slow-read duration, confirming Path B shrunk the hold time.

## Out of scope

- Path C (optimistic commit / placeholder node before slow read): rejected per part-03 review "Why an optimistic commit (Path C) violates I-25-01 atomicity"; would create a transient descriptor-hot-without-bytes state forbidden by I-25-02 implementation contract (Bind fact 14).
- Path D (test driver pre-warm delay): rejected per part-03 review; contradicts the Stage 34 acceptance criterion of concurrent dispatch.
- Path E (delay slot recycling until predecessor's `tx_save` commits): rejected per part-03 review; merges slot lifecycle with cache lifecycle. Path E is the only path that fully fixes the dispatch-ordering race, but it is a separate-stage design that violates the Stage 25 lifecycle separation. Not pursued in this cycle.
- A fix for the Bob-actual dispatch-ordering miss itself. The miss remains EXPECTED-BEHAVIOR per D34-REOPEN-05. The two behavior changes here reduce lock contention and prevent duplicate cache entries; they do not change when the predecessor's entry becomes visible to a parallel restore.
- New metrics, observability surfaces, or harness infrastructure not already present.

## Files NOT modified

- No production code (`tools/server/`, `src/`, `include/`, `common/`, `ggml/`) modified.
- No `document-index.md` modified (Manager updates the index).
- No `cache-handling-stage-tracker.md` modified (Manager updates the tracker).
- No test plan (`cache-handling-test-plan/`) modified (test plan follow-up picks up the proposed rows).
- No prior reviews (part-01, part-02, part-03 of this design directory) modified.
- No implementation log (`cache-handling-phase34-implementation/`) modified.
- No manager-input file modified.
- No prior Stage 25 design parts modified.
- No `git add`, `git commit`, or `git push` performed.

This design-only session created exactly one new durable file: this document.

## Final hygiene

- LF line endings only.
- No BOM.
- No trailing whitespace.
- ASCII only.
- Line count: `(Get-Content '<this file>').Count` reported in the final reply; target <= 300.
- `git diff --check` exit code on the new file: reported in the final reply.
