# Stage 34: Architect independent design review of part-04 (idempotent save and Path B)

## Header

- Status: Active
- Date: 2026-07-05
- Stage: 34 (reopened)
- Owner: Architect
- Active gate: Design review of part-04
- Branch: work-branch
- Source authority: `._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md` (user directive verbatim 2026-07-05; decisions D34-REOPEN-05..08)
- Skill-load confirmation: Loaded in order at session start: (1) `.agents/skills/self-improvement/SKILL.md`, (2) `.agents/skills/self-improvement/assets/architect.md` (applied every matching Condition/Action), (3) `.agents/skills/architect/SKILL.md`, (4) `.agents/skills/caveman/SKILL.md` (ultra mode for internal thinking), (5) `.agents/skills/humanizer/SKILL.md` (applied to prose). Latest applied memory entries: "Self-claim format verification in review subjects", "Atomic-operation design reviews", "Code-review findings tied to approved docs".
- Scope: Independent review of `part-04-design-correction-idempotent-save-and-path-b-20260705.md`. Verifies Bind facts by Select-String against the live tree, checks conformance with I-25-01..03, audits I-34-01 and I-34-02, audits the idempotent-save claim, audits Path B SPLIT ordering, audits the TP-34-CC reclassification note, and reviews out-of-scope rejections. REVIEW ONLY: this session does NOT modify part-04, the manager-input file, `document-index.md`, the tracker, the test plan, any implementation log, or any production code.

## 1. Bind fact verification table

All Select-String on live tree at `tools/server/server-cache-hybrid.cpp` (cpp), `.h` (header), `server-cache-graph.cpp` (graph). "PASS" = exact match; "OFF" = +/- 1-3 lines but same site; "DIVERGENT" = wrong line or wrong mapping.

| Claim in part-04 | Claimed | Actual | Verdict |
| --- | --- | --- | --- |
| cpp tx_save signature | L4754 | L4754 | PASS |
| cpp tx_save `lock_guard cache_state_mutex_` | L4759 | L4759 | PASS |
| cpp `find_equivalent_entry(entry_tokens, namespace_id)` dedupe call | L4819 | L4819 | PASS |
| cpp `refresh_existing_entry(existing, protected_root)` dedupe call | L4822 | L4822 | PASS |
| cpp `acquire_branch_node_ref_for_slot` after dedupe | L4824 | L4823 | OFF (1) |
| cpp `return true` after dedupe | L4825 | L4826 | OFF (1) |
| cpp slow target read `llama_state_seq_get_data_ext(ctx_tgt` | L4840 | L4840 | PASS |
| cpp slow draft read `llama_state_seq_get_data_ext(ctx_dft` | L4855 | L4855 | PASS |
| cpp `materialize_entry_payload` re-materialize branch | L4896-L4911 | L4865-L4882 | DIVERGENT (`materialize_entry_payload` call at L4865, range cited covers admit-case instead) |
| cpp `admit_entry_with_payload` new entry branch | L4914-L4925 | L4886-L4923 | DIVERGENT (admit call at L4886, `acquire_branch_node_ref_for_slot(it_new)` at L4907, `return true` at L4923) |
| cpp tx_restore signature | L5176 | L5176 | PASS |
| cpp tx_restore lock | L5179 | L5179 | PASS |
| cpp `find_nodes_by_token_span` call inside tx_restore | L5196 | L5196 | PASS |
| cpp `refresh_existing_entry` helper definition | L2998 | L2998 | PASS |
| cpp `mark_used(next_use_sequence())` inside refresh_existing_entry | (implied L2998) | L3001 | PASS (helper body) |
| cpp `sync_branch_node_from_entry` propagates `use_count` | L3239 assign | sync body L3232, `use_count` assign L3239 | PASS |
| header `hybrid_cache_entry` struct | L207 | L207 | PASS |
| header `size_t use_count = 0` | L219 | L219 | PASS |
| header `void mark_used(uint64_t sequence)` | L253 | L253 (`use_count++` at L255) | PASS |
| graph forest `lock_guard mutex_` at L188 (create_node) | L188 | L188 is `get_node`, not create_node; create_node lock at L122, remove_node at L152 | DIVERGENT (function-name mapping wrong) |
| graph forest `lock_guard mutex_` at L194 (remove_node) | L194 | L194 is `get_node const`, not remove_node | DIVERGENT |
| graph forest `lock_guard mutex_` at L203 (get_node) | L203 | L203 is `find_nodes_by_token_span` | DIVERGENT |
| graph forest `lock_guard mutex_` at L225 (find_nodes_by_token_span) | L225 | L225 is `find_nodes_by_checksum_span` | DIVERGENT |
| graph forest `lock_guard mutex_` at L244 (find_nodes_by_checksum_span) | L244 | L244 is `get_children` | DIVERGENT |
| graph `find_nodes_by_token_span` body | L199-L219 | L199 sig, L203 lock, body L204-L218, return L219 | PASS |
| graph `find_nodes_by_checksum_span` body | L222-L241 | L221 sig (off by 1), L225 lock, body L226-L240 | OFF (1) on signature start |
| part-06 I-25-01 / I-25-02 / I-25-03 | L11 / L30 / L49 | L11 / L30 / L49 | PASS |
| part-06 I-25-02 implementation contract "hot + empty hot_payloads" | L42-45 | phrase at L46-47, clause starts L42 | OFF (1-2); clause correct, phrase offset |
| part-02 Lock granularity section | L7-L32 | L7-L32 | PASS |
| part-02 Reentrancy rule | L94-L122 | L94-L117 | OFF (5); rule body ends before L122 |
| part-03 row 19 (save_slot) | L32 | L32 | PASS |
| part-03 row 20 (try_restore_from_cache) | L33 | L33 | PASS |
| part-07 OQ-25-01 SPLIT | L28-L43 | L28 (OQ-25-01 section starts) | PASS |
| Stage 33 closure report L14, L23, L29, L49 | cited | L14, L23, L29, L49 | PASS |
| Stage 33 D33-CLOSURE-01 | cited | L29 | PASS |

Net: most cpp/header citations are exact or within +/- 1-2 lines on the same site. Three real divergences: (a) the post-read mutation range L4896-L4925 is shifted (true re-materialize case is L4865-L4882, admit case is L4886-L4923); (b) the graph forest `lock_guard` mapping is mislabeled for L188, L194, L203, L225, L244 (those lock lines exist but belong to different functions). None of these change the design's substance; they are correction-grade documentation hygiene issues tied to one finding below.

## 2. Architecture conformance

The two behavior changes preserve I-25-01..03 if implemented as described.

- I-25-01 (atomicity): Behavior change ONE keeps lookup and `mark_used` inside one critical section (L4759 lock). Behavior change TWO splits tx_save into two atomic sections; mutations to `entries`, `forest`, `hot_payloads`, `payload_descriptors`, `lru_index`, `prefix_index` happen only inside one of the two sections. The slot-thread `llama_context` reads at ex-L4840/L4855 are explicitly outside the lock per the Stage 25 lock-granularity rule (part-02 L25-L32: the lock does NOT guard `llama_context`).
- I-25-02 (isolation): the second-pass dedupe at step 8 absorbs any parallel-commit race during the slow read; a parallel tx sees either pre-admission state (no entry) or post-admission state (entry with hot residency). No transient hot-without-bytes state is published because admission (`admit_entry_with_payload` calls `attach_payload` before `entries.push_back`) and re-materialize (`materialize_entry_payload` calls `attach_payload` then `mark_used`/`sync`) both install bytes before the entry becomes externally visible.
- I-25-03 (durability within transaction): `tx_save` performs no cold-store write, so Path B leaves durability untouched.

The "PRESERVED slot lifecycle separation" claim is accurate: neither change adds a save-in-progress signal to the dispatcher, neither delays slot recycling, and Path E is correctly rejected.

## 3. Invariant I-34-01 review

I-34-01 reads: equivalent payload-bearing entry exists -> no new entry, `use_count`++ once, `tx_save` returns true without slow read.

Strengths: matches the L4819-L4826 dedupe under one critical section; the increment is single-stepped inside `refresh_existing_entry` -> `mark_used` (L3001). Testable via T-34-IDEM-01 and T-34-IDEM-02.

Granularity issue: I-34-01 only covers the "payload-bearing" branch (L4820 `entry_has_payload_for_restore(*existing)` true). The live code is stronger than the invariant: when `existing != entries.end()` but residency is no longer hot, the slow-read fall-through at L4863-L4883 STILL reuses the existing entry via `materialize_entry_payload` (which calls `mark_used` at L3088) and does NOT call `admit_entry_with_payload`. So the live code already prevents duplicate entry creation in BOTH the hot-dedupe and the cold-rematerialize case. I-34-01 should be widened to "no duplicate entry is created for any `find_equivalent_entry` hit regardless of residency" to match the code and to cover the user directive's Bob-actual extension. Recorded as finding.

## 4. Invariant I-34-02 review

I-34-02 reads: slow reads run outside the lock; mutations only inside the first or second section; parallel tx_save cannot produce two entries for the same equivalence.

SPLIT precedent: the tx_restore OQ-25-01 SPLIT (plan under lock, apply outside lock, finalize under lock) is conceptually identical. The tx_save SPLIT (snapshot under lock, slow read outside, dedupe-or-admit under lock) is the symmetric pattern. Both critical sections are atomic at the section level.

Snapshot-to-mutation guard: sound. The slot's intent is not observable during the read window (no cache state mutated, no intent registered). Second-pass dedupe at step 8 catches a parallel committer using the same lookup fields (`find_equivalent_entry`). The guard correctly relies on `mark_used`-based increment (idempotent on number of saves, monotone increase of `use_count`).

Missed failure mode (one): the design does not state what happens if a parallel slot EVICTS the matched existing entry between step 4 and step 8. `entries.erase` during eviction invalidates any iterator captured at step 4 (part-04 does not capture an iterator at step 4, it re-runs `find_equivalent_entry` at step 8, so this is operationally safe), but the design should explicitly state that the re-lookup at step 8 is RE-INVALIDATION-safe because no iterator or pointer survives past lock release. Recorded as NON-BLOCKING finding.

## 5. Idempotent-save claim audit

part-04 says D34-REOPEN-06 "is already the current code path" requiring no new code, only the documented invariant.

Verified against L4819-L4826 and L4863-L4883:

- Hot residency at lookup time: L4820 dedupe fires, `refresh_existing_entry` bumps `use_count` via `mark_used` (L3001), `tx_save` returns true at L4826 without slow read. The user Scenario 1 (Alice's save committed hot; Bob's save afterward) is handled by this branch.
- Cold residency at lookup time but entry still in `entries`: L4820 fails the predicate AND L4863 re-checks `existing != entries.end()` and routes to `materialize_entry_payload` (L4865) which attaches the new bytes, calls `it->mark_used(next_use_sequence())` at L3088, and updates the branch_node mirror. NO new entry is created and `use_count` still increments.

Strong simplification finding: the live code is MORE idempotent than part-04's I-34-01 asserts. The implementation plan therefore only needs invariant wording, not new production code, for the user directive's Bob-actual extension. Gap: part-04's Risks note acknowledges the residency-within-one-critical-section argument but does not state the cold-rematerialize branch as a separate, independent idempotency surface. Recorded.

Edge case part-04 misses: if `find_equivalent_entry` returns `entries.end()` at L4819 because Alice's entry was evicted entirely (Alice committed but a later eviction erased her entry before Bob's save), then Bob will run the slow read and admit a new entry. This is acceptable cache behavior (Bob is genuinely the first save after eviction) and does not violate idempotency. Non-issue.

## 6. Path B claim audit

The SPLIT ordering (snapshot -> read outside lock -> re-dedupe-or-admit under lock) is conceptually identical to OQ-25-01. The slow read reads per-slot `llama_context` data into function-local `std::vector<uint8_t>` buffers that are not cache state. No other thread mutates this slot's context during `tx_save` (slot is not running inference during save; slot lifecycle owned by slot thread per part-02 L25-L32).

Failure modes part-04 missed (NON-BLOCKING):

- Iterator/pointer invalidation between sections (mitigated because step 8 re-looks-up, but the design does not state this explicitly).
- Budget check at the first section (step 2) is against the snapshot; a parallel committer that admits a large entry during the slow read could push the cache over budget by the time step 8 runs. The existing `evict_until_within_budget` is called inside `materialize_entry_payload` (L3094) and `admit_entry_with_payload` (L3195), so budget is re-enforced at step 8; the design should cite this as the budget-recheck guarantee.

## 7. Reclassification note review

TP-34-CC reclassification FAIL -> EXPECTED-BEHAVIOR is consistent with the Stage 33 precedent. Stage 33 Hybrid reuse row reclassification (L14, L23, L29, L49; D33-CLOSURE-01) records the same shape: not a product bug; expected steady-state behavior under the workload / dispatch model. TP-34-CC's dispatch-ordering race in throttle > 1 simultaneous dispatch is the analogous case. Citation is accurate.

## 8. Out-of-scope review

- Path C (optimistic commit): rejected correctly against the I-25-02 implementation contract. Cited line range matches the contract clause.
- Path D (test driver pre-warm): rejected correctly against the Stage 34 acceptance criterion of concurrent dispatch.
- Path E (delay slot recycling): rejected correctly against the Stage 25 slot/cache lifecycle separation. The note that Path E is the only full fix is preserved.

All three rejections are sound and tie to the relevant precedent.

## 9. Findings

1. NON-BLOCKING. I-34-01 over-narrows the existing code's idempotency to the "payload-bearing" branch. Required action: widen I-34-01 to assert "no new entry is created when `find_equivalent_entry` returns non-end, regardless of residency," and add a T-34-IDEM-03 assertion exercising the cold-residency re-materialize branch. This makes the invariant match the code and the user directive.
2. NON-BLOCKING. Bind facts: post-read mutation ranges L4896-L4911 (re-materialize case) and L4914-L4925 (admit case) are off. Actual re-materialize case L4865-L4882, admit case L4886-L4923. Required action: correct the ranges before implementation planning so reviewers can cite exact lines.
3. NON-BLOCKING. Bind facts: graph forest `lock_guard mutex_` mapping mislabels L188, L194, L203, L225, L244 (those lock lines are real but belong to different functions). Required action: relabel to L188 (`get_node`), L194 (`get_node const`), L203 (`find_nodes_by_token_span`), L225 (`find_nodes_by_checksum_span`), L244 (`get_children`); optionally cite L122 (`create_node`) and L152 (`remove_node`).
4. NON-BLOCKING. Behavior change TWO should cite `evict_until_within_budget` (cpp L3094 inside `materialize_entry_payload`, L3195 inside `admit_entry_with_payload`) as the budget-recheck guarantee after the second-pass dedupe. Required action: add one sentence so the implementation plan knows budget is re-enforced in the second critical section.
5. NON-BLOCKING. Behavior change TWO should state explicitly that no iterator or pointer captured at step 4 survives the lock release, so step 8's re-lookup is iterator-invalidation-safe. Required action: add one sentence.
6. NON-BLOCKING (observation). I-34-02 says "same token-span + namespace + payload residency combination." The residency qualifier is implicit in the dedupe predicate (`entry_has_payload_for_restore`); make the predicate-or-not crystal in the invariant body so the test author knows whether the second-pass dedupe requires hot residency or accepts any residency.

No BLOCKING findings. The design genuinely preserves I-25-01..03, the invariants are testable, the SPLIT argument is sound and matches OQ-25-01, and the reclassification cites Stage 33 accurately.

## 10. Verdict

PASS. Manager can advance to implementation planning. The six NON-BLOCKING findings are documentation hygiene and one invariant-absorption widening; none block implementation. The implementation plan should note that the user directive's Bob-actual extension requires essentially no new production code for idempotent save because the live L4819-L4826 and L4863-L4883 paths already cover it; Behavior change TWO (Path B) is the only behavior change that requires code restructuring.

## 11. Files NOT modified

- No production code (`tools/server/`, `src/`, `include/`, `common/`, `ggml/`) modified.
- No `document-index.md` modified (Manager updates the index; part-04 not yet indexed).
- No `cache-handling-stage-tracker.md` modified (Manager updates the tracker).
- No test plan (`cache-handling-test-plan/`) modified.
- No prior reviews or design parts (part-01, part-02, part-03, part-04) modified.
- No implementation log (`cache-handling-phase34-implementation/`) modified.
- No manager-input file modified.
- No Stage 25 design parts modified.
- No `git add`, `git commit`, or `git push` performed.

This review-only session created exactly one new durable file: this document.

## 12. Final hygiene

- CR=0; LF only; BOM=NO; ASCII only.
- Line count: `(Get-Content '<this file>').Count` reported in final reply; <= 250.
- `git diff --check` on the new file exit code: reported in final reply.
