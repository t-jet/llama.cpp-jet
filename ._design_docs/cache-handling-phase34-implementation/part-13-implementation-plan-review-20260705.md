# Stage 34: Architect independent implementation-plan review of part-12 (idempotent save and Path B)

## Header

- Status: Active
- Date: 2026-07-05
- Stage: 34 (reopened)
- Owner: Architect
- Active gate: Implementation-plan review of `part-12-reopen-implementation-plan-20260705.md`
- Branch: work-branch
- Source authority:
  - `._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md` (user directive verbatim, 2026-07-05; decisions D34-REOPEN-05..08)
  - Design: `cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md`
  - Design review: `cache-handling-phase34-design/part-05-design-review-20260705.md` (PASS, 0 BLOCKING, 6 NON-BLOCKING)
  - Manager gate: `cache-handling-phase34-design/part-06-manager-design-gate-20260705.md` (PASS, 8 required-action items)
  - Stage 25 design: `cache-handling-phase25-design/part-02-atomic-transaction-protocol.md`, `part-06-new-invariants-and-architecture-cross-reference.md`, `part-07-risks-and-open-questions.md` (OQ-25-01 SPLIT)
- Skill-load confirmation: Loaded in order at session start before any other task action: (1) `.agents/skills/self-improvement/SKILL.md`, (2) `.agents/skills/self-improvement/assets/architect.md` (applied every matching Condition/Action; latest applied: "Code-review findings tied to approved docs", "Atomic-operation design reviews", "Plan-review code-snippet type and format check", "Bind-facts numbered list spanning prose headers trips MD029"), (3) `.agents/skills/architect/SKILL.md`, (4) `.agents/skills/caveman/SKILL.md` (ultra mode for internal thinking), (5) `.agents/skills/humanizer/SKILL.md` (applied to prose).
- Scope: Independent review of `part-12-reopen-implementation-plan-20260705.md`. Verifies Section 4 line claims by Select-String against the live tree, audits the SPLIT pattern against OQ-25-01, audits the eight required-action items from part-06, audits I-34-01 and I-34-02 test coverage, reviews risks and scope, and checks planning-only boundaries. REVIEW ONLY: this session does NOT modify part-12, the manager-input file, `document-index.md`, the tracker, the design parts, prior implementation logs, or any production code; it does NOT run builds, replay, tests, or coverage; it does NOT commit or push.

## 1. Bind fact verification table

`.h` = `tools/server/server-cache-hybrid.h`; `cpp` = `tools/server/server-cache-hybrid.cpp`; `ctx.cpp` = `tools/server/server-context.cpp`. PASS = exact; OFF(n) = same site, lines shifted by n; DIVERGENT = wrong site or wrong mapping.

| Claim in part-12 Section 4 | Claimed | Actual | Verdict |
| --- | --- | --- | --- |
| cpp tx_save signature | L4754 | L4754 | PASS |
| cpp tx_save `lock_guard<recursive_mutex> lock(cache_state_mutex_)` | L4759 | L4759 | PASS |
| `reentrancy_depth_limit_` declared in header | `server-cache-hybrid.h:696` | L696 (`size_t reentrancy_depth_limit_ = 4;`) | PASS |
| cpp `llama_state_seq_get_size_ext(ctx_tgt` (size probe) | ~L4770 | L4770 (target), L4771 (draft) | PASS |
| cpp empty target reject | L4789 | `if` guard L4789, SRV_WRN L4790 | PASS |
| cpp empty draft reject | L4794 | `if` guard L4794, SRV_WRN L4795 | PASS |
| cpp budget check `hot_payload_budget_enabled() && total_size > limit_size` | L4800 | L4800 | PASS |
| cpp null task reject | L4813 | `if` guard L4813, SRV_WRN L4814 | PASS |
| cpp `slot.task->tokens.clone()` | L4817 | L4817 | PASS |
| cpp `find_equivalent_entry(entry_tokens, namespace_id)` | L4819 | L4819 | PASS |
| cpp hot dedupe returns true | L4826 | L4826 | PASS |
| cpp `refresh_existing_entry(existing, protected_root)` | L4822 (Section 4 body) | L4822 | PASS |
| cpp slow target read `llama_state_seq_get_data_ext(ctx_tgt` | L4840 | L4840 | PASS |
| cpp slow draft read `llama_state_seq_get_data_ext(ctx_dft` | L4855 | L4855 | PASS |
| cpp `mark_used` call site inside `refresh_existing_entry` | L3001 (Section 4 prose) | L3001 | PASS |
| cpp `materialize_entry_payload` re-materialize call | L4865 | L4865 | PASS |
| cpp `mark_used` inside materialize branch | L3088 | L3088 | PASS |
| cpp `evict_until_within_budget` inside materialize | L3094 | L3094 | PASS |
| cpp cold branch syncs branch at | L4876 | L4878 (`sync_branch_node_from_entry(*existing)`) | OFF(2) |
| cpp cold branch acquires ref at | L4877 | L4879 (`acquire_branch_node_ref_for_slot(slot, existing->branch_node_id)`) | OFF(2) |
| cpp cold branch returns true at | L4882 | L4882 | PASS |
| cpp `admit_entry_with_payload` admit call | L4886 | L4886 | PASS |
| cpp admit branch acquires ref at | L4907 | L4907 (`acquire_branch_node_ref_for_slot(slot, it_new->branch_node_id)`) | PASS |
| cpp admit branch returns true at | L4923 | L4924 | OFF(1) |
| cpp `evict_until_within_budget` inside admit | L3195 | L3195 | PASS |
| cpp admit branch `select_mismatch_parent_for_admission` call | not cited in Section 4 prose; cited in Step 2 only | L4885 | OFF, minor omission |
| header `hybrid_cache_entry` struct | L207 | L207 | PASS |
| header `use_count` field | L219 | L219 | PASS |
| header `mark_used(uint64_t)` body | L253-L255 | L253 sig, `use_count++` L255 | PASS |

Net: of 28 in-block claims, 24 PASS, 3 OFF by 1-2 lines on the same site (cold-branch sync ref at L4878/L4879 vs L4876/L4877; admit-return at L4924 vs L4923), 1 minor omission (`select_mismatch_parent_for_admission` parent lookup at L4885 is named in Step 2 only, not in Section 4 prose). No DIVERGENT matches. Substance of every claim is correct: the dedupe, the slow reads, the cold re-materialize branch, the new-entry admit branch, the budget recheck sites, the `use_count` field, and the reentrancy limit. The OFF-line items are correction-grade documentation hygiene the implementer should fix while editing.

## 2. Bind fact verification: OQ-25-01 SPLIT pattern

| Claim in part-12 / source docs | Claimed | Actual | Verdict |
| --- | --- | --- | --- |
| `try_restore_from_cache` definition | `tools/server/server-context.cpp:5886` | `tools/server/server-context.cpp:5886` | PASS |
| Apply step (`llama_state_seq_set_data_ext`) runs OUTSIDE cache lock | in `try_restore_from_cache` body | L5976 (target), L5997 (draft), no `cache_state_mutex_` acquired in that function body | PASS |
| `tx_apply_restore` definition | `server-cache-hybrid.cpp:5311` | L5311 | PASS |
| `tx_apply_restore` re-acquires cache lock for finalize | (implied) | L5313 `std::lock_guard<std::recursive_mutex> lock(cache_state_mutex_)` | PASS |
| OQ-25-01 documented as plan-under-lock / apply-outside / finalize-under-lock | `cache-handling-phase25-design/part-07-risks-and-open-questions.md` L28-L43 | Section heading at L28; "plan under lock, apply outside lock, finalize under lock" wording at L35-L36 | PASS |

Net: the SPLIT precedent the plan leans on is real, lives where the plan says it lives, and the tx_restore implementation matches it step-for-step. The tx_save SPLIT in Step 2 is the symmetric pattern and is permissible under I-25-01/02 given the Stage 25 lock-granularity rule (`cache_state_mutex_` does NOT guard `llama_context`).

## 3. Conformance to part-04 + part-05 + part-06

The plan implements what those three parts authorize:

- part-04 (design correction). Plan Step 1 carries the invariant-comment wording for I-34-01; Step 2 carries the Path B SPLIT for Behavior change TWO (D34-REOPEN-07); Step 4 enumerates the four regression tests; Section 7 carries the TP-34-CC reclassification label for QA; Section 11 carries Path C/D/E rejection rationale. No new design decision is introduced.
- part-05 (design review, 6 NON-BLOCKING). All six findings fold into the plan as the part-06 required-action items; see Section 4.
- part-06 (manager gate, 8 required-actions). All eight items are addressed; see Section 4.
- part-04's "no production code needed for D34-REOPEN-06" claim is preserved in plan Section 4 conclusion and Step 1 (comments only). The plan does NOT silently add new code for the idempotent-save behavior, which matches part-04 and part-05 finding 5.

The plan does NOT redefine I-25-01..03, does NOT introduce new invariants beyond I-34-01/I-34-02, and does NOT touch slot lifecycle or dispatcher behavior.

## 4. Required-action item audit (part-06 numbered 1-8)

1. Widen I-34-01 to cover any residency on `find_equivalent_entry` hit. ADDRESSED. Step 1 (comment wording at L4819-L4826 hot branch AND L4863-L4883 cold re-materialize branch) and Step 4 (T-34-IDEM-03 exercises the cold branch). Section 5 row 1 records the fold explicitly.
2. Add T-34-IDEM-03 cold-residency re-materialize test. ADDRESSED. Step 4 lists T-34-IDEM-03 with a demote-then-save-same-prompt scenario and a `use_count`-incremented assertion.
3. Carry corrected line ranges (re-materialize L4865-L4882; admit L4886-L4923). PARTIALLY ADDRESSED. Section 4 prose carries the corrected re-materialize range header (L4865, L4863-L4883). Admit-case cite of L4886-L4923 matches; admit-return line is L4924 in the live tree, not L4923 (OFF by 1). The cold-branch sync/ref cites in Section 4 (L4876/L4877) are OFF by 2 from the live L4878/L4879. Required action for implementer: correct L4876/L4877 to L4878/L4879 and L4923 to L4924 before code edits.
4. Carry corrected `branch_forest_index` lock-mapping if implementation touches forest lookups. ADDRESSED (informational). Section 5 row 4 records the corrected mapping (`get_node` L188, `get_node const` L194, `find_nodes_by_token_span` L203, `find_nodes_by_checksum_span` L225, `get_children` L244; plus `create_node` L122, `remove_node` L152) and explicitly states Path B does NOT add new forest calls. Confirmed by Select-String against `tools/server/server-cache-graph.cpp`.
5. Cite `evict_until_within_budget` as the budget recheck inside the second critical section. ADDRESSED. Step 2 acceptance criteria sentence 1 cites cpp L3094 (inside `materialize_entry_payload`) and L3195 (inside `admit_entry_with_payload`). Both confirmed against the live tree.
6. State explicitly that no iterator or pointer captured before lock release survives to the second critical section. ADDRESSED. Step 2 acceptance criteria sentence 2; Section 8 risk wording (third risk paragraph) repeats the iterator-invalidation-safe re-lookup contract.
7. Make the residency qualifier on I-34-02 explicit. ADDRESSED. Step 2 acceptance criteria sentence 3 states the second-pass dedupe uses `find_equivalent_entry` (any-residency), NOT a hot-only predicate; a cold-residency hit on the second pass reuses the existing entry. Section 8 last paragraph reinforces this.
8. Restructure tx_save into the SPLIT pattern. ADDRESSED. Step 2 enumerates the four-phase ordering (first critical section, between sections, second critical section, scope-exit release) with the exact slow-read calls moved outside the lock and the second-pass dedupe re-run under the lock. The Section 4 conclusion correctly narrows the production-code change to Behavior change TWO only.

All eight required-action items from part-06 are folded. Items 3 and 4 carry into the implementer's correction list (item 3 has the L4876/L4877/L4923 off-by-1/2 issues noted above).

## 5. Step 2 (Path B SPLIT) traceability against OQ-25-01

Walk against the OQ-25-01 precedence (plan under lock, apply outside lock, finalize under lock):

- Snapshot field set. The plan enumerates `slot.id`, `ctx_tgt`, `slot.ctx_dft`, `state_size_tgt`, `state_size_dft`, `entry_tokens`, `metadata`, `namespace_id`, `runtime_has_draft`, `protected_root`. This covers every read-only input the two slow reads (`llama_state_seq_get_data_ext(ctx_tgt, ...)` and `llama_state_seq_get_data_ext(ctx_dft, ...)`) and the second-pass admit branch (`admit_entry_with_payload(std::move(entry_tokens), metadata, namespace_id, protected_root, std::move(target_payload), std::move(draft_payload), runtime_has_draft, parent_node_id, ...)`) consume. `parent_node_id` is computed by `select_mismatch_parent_for_admission(entry_tokens, namespace_id)` which itself reads `entries`/`forest`; the plan correctly implies the parent lookup belongs in the second critical section (it reads forest state), and Step 2 names the call in the second-section admit branch. Snapshot set is complete for the slot-owned inputs.
- Re-lookups. The second critical section re-runs `find_equivalent_entry(entry_tokens, namespace_id)` (Step 2). This matches the first-pass lookup fields and is correct: `entry_tokens` and `namespace_id` are the slot-owned inputs and are stable across the slow read. No iterator or pointer captured before lock release survives; `existing` is re-derived. `select_mismatch_parent_for_admission` is re-computed inside the second section because it walks live forest state.
- Error paths. The plan covers `n_tgt != state_size_tgt` and `n_dft != state_size_dft` (return false with no cache mutation, taking the local buffers down with scope exit). The descriptor-validation reject path inside `admit_entry_with_payload` (`it_new == entries.end()`) and the `materialize_entry_payload` metadata-only reject path both return false inside the second critical section without publishing partial state. Coverage is complete.
- SPLIT correctness against I-25-01/02. Each critical section is atomic at the section level. The slow reads touch only slot-owned `llama_context` and function-local buffers, not shared cache state, so I-25-02 isolation is preserved during the read window. Admission and re-materialize install bytes (via `attach_payload` inside the helpers) before the entry is externally visible, so no transient hot-without-bytes state is published (preserves the I-25-02 implementation contract).

The SPLIT ordering is internally consistent, traces to OQ-25-01, and preserves the Stage 25 invariants.

## 6. Risk review

The plan's risk section covers: (a) slot-thread ownership of `slot.id`/`ctx_tgt`/`slot.ctx_dft`/sizes/metadata during tx_save (Stage 25 lock-granularity), (b) transient memory pressure from parallel duplicate-buffered payloads (bounded by `n_parallel * payload_size`, first-section budget check still rejects oversized payloads), (c) parallel eviction between dedupe check and `use_count` increment (single-section current code prevents this; under Path B, the second-pass re-lookup absorbs the eviction-only-turns-dedupe-into-legitimate-new-entry outcome).

Two failure modes the plan does NOT name:

- Slow-read allocation failure under Path B. The current code wraps `target_payload.resize(state_size_tgt)` and `draft_payload.resize(state_size_dft)` in `try { ... } catch (const std::bad_alloc & e) { SRV_ERR(...); return false; }`. Under the SPLIT these catches run outside the lock and return false with no cache mutation. The plan does not state this explicitly. NON-BLOCKING: the implementer keeps the existing try/catch and the outcome is unchanged.
- Reentrancy guard reset between critical sections. The plan releases the lock between sections and re-acquires it, but does not say whether the `stage25_tx::reentrancy_guard` is destroyed at the first release and re-installed at the second acquire, or kept alive across the release. Re-installing a fresh guard at the second acquire is correct; reusing the same guard object across a release/reacquire depends on the guard's internal state machine. The plan implies re-installation (Step 2 says "Re-acquire `cache_state_mutex_` and re-install the reentrancy guard"), but the wording could be tighter. NON-BLOCKING: the implementer should destroy the first guard at release and construct a new guard at re-acquire to match the documented depth-limit semantics.

No additional risk blocks implementation.

## 7. Test coverage review

| Test | Asserts | Verdict |
| --- | --- | --- |
| T-34-IDEM-01 | Two same-prompt slots both save; `entries.size() == 1`, single entry's `use_count >= 2`. Asserts I-34-01 hot-residency. | Covers invariant for the hot-dedupe branch at L4820-L4826. |
| T-34-IDEM-02 | Slot A then slot B (post-A) for same prompt; B's `tx_save` returns true; Step 3 slow-read counter for B's id reads zero. Asserts first-pass dedupe skips slow read. | Proves I-34-01's "without invoking `llama_state_seq_get_data_ext`" clause via the Step 3 hook. |
| T-34-IDEM-03 | Pre-load A, demote A's payload to cold so `entry_has_payload_for_restore` is false but the entry exists; save B same prompt; one entry exists, `use_count` incremented. Asserts cold re-materialize branch. | Covers the widened I-34-01 from required-action 1. |
| T-34-PATHB-01 | Slot in tx_save plus second slot attempting tx_restore for unrelated prompt; restore completes during slow-read window without blocking for the slow-read duration (lock-wait time below threshold). Asserts I-34-02. | Proves the SPLIT shrinks lock hold time. |

The four tests collectively prove the two new invariants. The plan correctly delegates harness rows (test-plan updates, fixture specifics, threshold value) to QA's next gate rather than authoring them in planning. NON-BLOCKING observation: T-34-PATHB-02 (two slots racing tx_save for the same prompt with staggered starts; assert one admits, the other takes the second-pass dedupe, and `use_count` reflects both) is named in design part-04 but is NOT in the plan's Step 4 list. Required action for the implementer or QA: add T-34-PATHB-02 to the regression set (or document why it is deferred) so the second-pass dedupe branch under Path B is exercised. Without it, the second-pass dedupe code path added by Step 2 has no direct test.

## 8. Scope creep check

- No Path C work. Section 11 rejects Path C with the same I-25-02 rationale as part-04.
- No Path D work. Section 11 rejects Path D against the Stage 34 concurrent-dispatch criterion.
- No Path E work. Section 11 rejects Path E and notes it is the only full fix for the dispatch-ordering miss; that miss stays EXPECTED-BEHAVIOR per D34-REOPEN-05.
- No new dispatcher or slot-lifecycle integration. Step 2 keeps the SPLIT inside `tx_save`; no save-in-progress signal to the dispatcher.
- No new metrics. Step 3 adds a debug counter gated behind an existing preprocessor guard, used only by T-34-IDEM-02; this is test instrumentation, not a new public surface.
- No unrelated restructuring. Step 2 keeps the existing helpers (`refresh_existing_entry`, `materialize_entry_payload`, `admit_entry_with_payload`, `select_mismatch_parent_for_admission`, `sync_branch_node_from_entry`, `acquire_branch_node_ref_for_slot`) in place; only `tx_save`'s critical-section layout changes.
- No test-plan expansion beyond part-04's enumerated rows plus the required-action #2 addition (T-34-IDEM-03). T-34-PATHB-02 (from part-04) is omitted; see Section 7.
- No production code, test, fixture, or script edits in this planning session. Section 10 and Section 13 confirm.

Scope is bounded to D34-REOPEN-06 (comments + regression tests) and D34-REOPEN-07 (Path B SPLIT + regression test). No silent additions.

## 9. Findings

1. NON-BLOCKING. Section 4 line cites for the cold re-materialize branch (sync at L4876, ref at L4877) are OFF by 2 against the live tree (actual sync L4878, ref L4879). Admit-branch return cite L4923 is OFF by 1 (actual L4924). Required action: implementer corrects to L4878/L4879/L4924 before code edits so reviewers can cite exact lines.
2. NON-BLOCKING. Section 4 does not name `select_mismatch_parent_for_admission` at L4885 (the parent-node lookup consumed by the admit branch). It is named in Step 2 only. Required action: add L4885 to Section 4 for traceability with the other admit-branch helpers.
3. NON-BLOCKING. T-34-PATHB-02 (second-pass dedupe under Path B with two racing tx_save calls for the same prompt) is named in design part-04's Testability section but is missing from the plan's Step 4 regression set. Required action: implementer or QA adds T-34-PATHB-02 to the regression set, or the plan records why it is deferred. Without it, the second-pass dedupe added by Step 2 has no direct test.
4. NON-BLOCKING. The plan does not state whether the `stage25_tx::reentrancy_guard` is destroyed at the first release and re-constructed at the second acquire, or kept alive across the release. Step 2 says "re-install the reentrancy guard", which implies fresh construction. Required action: implementer destroys the first guard at release and constructs a new guard at the second acquire to preserve documented depth-limit semantics.
5. NON-BLOCKING. The plan does not name the slow-read `std::bad_alloc` catch path (`target_payload.resize`/`draft_payload.resize`) as preserved under the SPLIT. Required action: implementer keeps the existing try/catch wrapping the resize calls outside the lock, returning false with no cache mutation on allocation failure.

No BLOCKING findings. The plan implements what part-04/part-05/part-06 authorize, folds all eight required-action items, preserves I-25-01..03 via the SPLIT pattern documented in OQ-25-01, names tests that prove I-34-01 and I-34-02, cites verified line numbers (with the Section 4 corrections noted above), and does not silently add Path C/D/E or unrelated scope.

## 10. Verdict

PASS. The Manager can advance to implementation execution. The five NON-BLOCKING findings are correction-grade (line numbers, one missing test, one guard-lifecycle clarification, one error-path preservation note) for the implementer to address during the code session; none of them block the plan from being executable as written.

## 11. Files NOT modified

- No production code (`tools/server/`, `src/`, `include/`, `common/`, `ggml/`) modified.
- No `document-index.md` modified.
- No `cache-handling-stage-tracker.md` modified.
- No test plan (`cache-handling-test-plan/`) modified.
- No manager-input file modified.
- No design parts (part-01..part-06 of phase34-design) modified.
- No implementation log parts (part-01..part-12 of phase34-implementation) modified.
- No Stage 25 design parts modified.
- No `git add`, `git commit`, or `git push` performed.

This review-only session created exactly one new durable file: this document.

## 12. Final hygiene

- CR=0; LF only; BOM=NO; ASCII only; no trailing whitespace.
- Line count: target under 250; reported in the final reply.
- `git diff --check` exit code on the new file: reported in the final reply.
