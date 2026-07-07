# Stage 34 implementation plan: idempotent save and Path B (2026-07-05)

Status: PLANNING ONLY - no production code, tests, or fixtures touched in this session
Date: 2026-07-05
Stage: 34 (reopened)
Owner: Developer
Active gate: Implementation-planning for D34-REOPEN-06 and D34-REOPEN-07
Branch: work-branch
Source authority: `._design_docs/.manager-inputs/manager-input-20260705-stage34-reopen-idempotent-save-and-path-b.md` (user directive 2026-07-05; decisions D34-REOPEN-05..08)
Skill-load confirmation: Loaded in order at session start: (1) `self-improvement/SKILL.md`, (2) `self-improvement/assets/developer.md` (applied every matching Condition/Action; latest applied entry used line-verify-before-citing and durable-doc LF/BOM/markdown-lint rules), (3) `developer/SKILL.md`, (4) `caveman/SKILL.md` (ultra for internal thinking), (5) `humanizer/SKILL.md` (applied to prose).

## 1. Scope

In scope:

- Plan D34-REOPEN-06 (idempotent tx_save with hot counter bump).
- Plan D34-REOPEN-07 (Path B slow-read relocation, SPLIT pattern).
- Record D34-REOPEN-05 (reclassification note) and D34-REOPEN-08 (closure requires all gates) as fixed decisions.
- Fold all eight required-action items from part-06 into plan steps or acceptance criteria.
- Enumerate ordered implementation steps, affected files, risks, evidence plan.

NOT in scope (this session):

- No production code edits (`tools/server/`, `src/`, `include/`, `common/`, `ggml/`).
- No test, fixture, or script edits.
- No live replay, no build, no test run.
- No commit, no push.
- No edits to `document-index.md`, the tracker, the manager-input file, the design parts, or prior implementation logs.
- Out of scope behaviors: Path C, Path D, Path E (rejected by part-04; see section 11).

## 2. Approved baseline

- Design: `cache-handling-phase34-design/part-04-design-correction-idempotent-save-and-path-b-20260705.md`.
- Design review: `cache-handling-phase34-design/part-05-design-review-20260705.md` (PASS, 0 BLOCKING, 6 NON-BLOCKING).
- Manager gate: `cache-handling-phase34-design/part-06-manager-design-gate-20260705.md` (PASS, 8 required-action items).
- Prior architect review: `cache-handling-phase34-design/part-03-architect-review-concurrent-reuse-structural-finding-20260701.md` (PARTIAL).
- Stage 25 design: `cache-handling-phase25-design/part-02-atomic-transaction-protocol.md` (lock granularity, OQ-25-01 SPLIT pattern, reentrancy rule) and `part-06-new-invariants-and-architecture-cross-reference.md` (I-25-01..03).

## 3. Fixed decisions

| ID | Decision | Plan action |
| --- | --- | --- |
| D34-REOPEN-05 | TP-34-CC reclassified EXPECTED-BEHAVIOR (Stage 33 precedent). Cache code unchanged. | Section 12 of this plan hands QA the exact reclassification label. No code step. |
| D34-REOPEN-06 | Idempotent tx_save with hot counter bump. | Section 4 explains this needs no new production code beyond invariant comments. Step 1 adds comments; Step 4 adds T-34-IDEM-01..03 regression tests. |
| D34-REOPEN-07 | Path B slow-read relocation. | Step 2 restructures tx_save into the SPLIT pattern. Step 4 adds T-34-PATHB-01. |
| D34-REOPEN-08 | Stage 34 does not close until design, implementation, test-planning, test-execution, and test-results review all pass. | Recorded as the closure gate; not a per-step action. |

## 4. Current code state summary

`tx_save` lives at `tools/server/server-cache-hybrid.cpp:4754`. It acquires `cache_state_mutex_` once at L4759 via `std::lock_guard<std::recursive_mutex>` and installs the `reentrancy_guard` at L4760 (depth limit 4, defined in `server-cache-hybrid.h:696`). Under that single lock it: sizes the target and draft payloads via `llama_state_seq_get_size_ext(ctx_tgt, ...)` at L4770 (a size probe, fast); rejects empty target at L4789 and empty draft at L4794; runs the budget check `hot_payload_budget_enabled() && total_size > limit_size` at L4800; rejects null task at L4813; clones prompt tokens at L4817; runs the dedupe lookup `find_equivalent_entry(entry_tokens, namespace_id)` at L4819. The hot-residency dedupe at L4819-L4826 fires when `entry_has_payload_for_restore(*existing)` is true: it calls `refresh_existing_entry(existing, protected_root)` at L4822 (which calls `mark_used(next_use_sequence())` at L3001, bumping `use_count` at header L255), acquires the branch ref at L4823, and returns true at L4826 with no slow read. The slow target read `llama_state_seq_get_data_ext(ctx_tgt, ...)` at L4840 and slow draft read `llama_state_seq_get_data_ext(ctx_dft, ...)` at L4855 both run inside the same critical section. After the reads, the cold-residency re-materialize branch (`existing != entries.end()`) at L4863 calls `materialize_entry_payload(existing, ...)` at L4865 (which calls `mark_used` at L3088 and `evict_until_within_budget` at L3094), syncs the branch at L4876, acquires the ref at L4877, and returns true at L4882. Otherwise the new-entry admit branch runs `admit_entry_with_payload(...)` at L4886 (which calls `evict_until_within_budget` at L3195), acquires the ref at L4907, and returns true at L4923.

D34-REOPEN-06 conclusion: the live code at L4819-L4826 and L4863-L4883 already produces exactly one entry for a given token-span + namespace on repeated tx_save calls and bumps `use_count` via `mark_used` in both branches. The hot counter on `hybrid_cache_entry` (`server-cache-hybrid.h:219`) is the existing reuse counter. Therefore D34-REOPEN-06 needs no new production code beyond invariant-comment wording in tx_save and the header, plus regression tests. D34-REOPEN-07 (Path B) is the only behavior change requiring code restructuring.

## 5. Required-action items from part-06 (Manager gate)

1. Widen I-34-01 to cover any residency on `find_equivalent_entry` hit. Folded into Step 1 (comment wording at both branches) and Step 4 (T-34-IDEM-03 exercises the cold branch).
2. Add T-34-IDEM-03 cold-residency re-materialize test. Folded into Step 4.
3. Carry corrected line ranges: re-materialize case L4865-L4882; admit case L4886-L4923. Used in Section 4 and Step 2; verified by Select-String on 2026-07-05.
4. Carry corrected branch_forest_index lock mapping if implementation touches forest lookups: graph `lock_guard` lines L122 (`create_node`), L152 (`remove_node`), L188 (`get_node`), L194 (`get_node const`), L203 (`find_nodes_by_token_span`), L225 (`find_nodes_by_checksum_span`), L244 (`get_children`). Path B does NOT add new forest calls, so this is informational for the implementer; verified by Select-String.
5. Cite `evict_until_within_budget` (cpp L3094 inside `materialize_entry_payload`, L3195 inside `admit_entry_with_payload`) as the budget recheck inside the second critical section. Folded into Step 2 acceptance criteria.
6. State explicitly that no iterator or pointer captured before lock release survives to the second critical section; the second-pass re-lookup is iterator-invalidation-safe. Folded into Step 2 acceptance criteria.
7. Make the residency qualifier on I-34-02 explicit: the second-pass dedupe uses `find_equivalent_entry` then routes by residency, same as the first pass; it does NOT require hot residency to dedupe. Folded into Section 8 risk wording.
8. Restructure tx_save into the SPLIT pattern. Folded into Step 2.

## 6. Ordered implementation steps

Step 1 (D34-REOPEN-06 documentation). Add code comments to tx_save. At L4819-L4826 (hot dedupe branch) state: the cache dedupes by token-span and namespace; an equivalent payload-bearing entry causes `use_count` to increment via `mark_used` instead of creating a duplicate. At L4863-L4883 (cold re-materialize branch) state: the same is true here regardless of residency; `materialize_entry_payload` calls `mark_used`. Reference new invariant I-34-01 in both comments. NO production code change, only comments.

Step 2 (D34-REOPEN-07 Path B). Restructure tx_save from one critical section into the SPLIT pattern that matches OQ-25-01.

First critical section. Reuse the existing `lock_guard<recursive_mutex> lock(cache_state_mutex_)` and `reentrancy_guard`. Validate slot.prompt.tokens non-empty (L4758 minus). Compute `state_size_tgt` (L4770), `state_size_dft` (L4771), `total_size`. Reject empty target (L4789) and empty draft (L4794). Run the budget check against `total_size` at L4800 (the size probe via `llama_state_seq_get_size_ext` is fast and stays in this section). Reject null task (L4813). Clone `entry_tokens` (L4817). Run the D34-REOPEN-06 dedupe lookup `find_equivalent_entry(entry_tokens, namespace_id)` at L4819: on a hit with `entry_has_payload_for_restore(*existing)` true, take the existing hot-dedupe branch (refresh, acquire, return true at L4826 equivalent) and never reach the slow read. On a miss (or hot-but-no-payload), snapshot the read-only inputs the slow read needs into function locals: `slot.id`, `ctx_tgt`, `slot.ctx_dft`, `state_size_tgt`, `state_size_dft`, `entry_tokens`, `metadata`, `namespace_id`, `runtime_has_draft`, `protected_root`. Release the lock.

Between sections. Run the slow reads `llama_state_seq_get_data_ext(ctx_tgt, ...)` and `llama_state_seq_get_data_ext(ctx_dft, ...)` into function-local `std::vector<uint8_t>` buffers. No lock held. Apply the existing error paths (n_tgt != state_size_tgt, n_dft != state_size_dft) by returning false without cache mutation.

Second critical section. Re-acquire `cache_state_mutex_` and re-install the reentrancy guard. Re-run `find_equivalent_entry(entry_tokens, namespace_id)`. If it returns non-end and `entry_has_payload_for_restore(*existing)` is true, take the D34-REOPEN-06 dedupe path (refresh, acquire, discard local buffers via scope exit, return true). If it returns non-end at any residency, take the cold re-materialize branch (L4863-L4883 equivalent, including `materialize_entry_payload` at the L4865 site and `sync_branch_node_from_entry`). Otherwise take the new-entry admit branch (L4886-L4923 equivalent, including `admit_entry_with_payload` and `select_mismatch_parent_for_admission`). Release the lock at scope exit.

Step 2 acceptance criteria: `evict_until_within_budget` is reachable from both admit and re-materialize inside the second section (cpp L3094 and L3195), so budget is re-enforced there. No iterator or pointer captured before the first lock release survives to the second section; the implementer will re-look-up rather than hold an iterator. The second-pass dedupe uses `find_equivalent_entry` and NOT a stricter hot-only predicate, so a cold-residency hit on the second pass reuses the existing entry rather than admitting a duplicate; this satisfies i-34-02 redundancy wording.

Step 3 (instrumentation hook). Add a debug counter, gated behind the existing `LLAMA_CACHE_DEBUG` (or equivalent preprocessor guard already used in `server-cache-hybrid.cpp`), that counts slow-read invocations per `slot.id` while the lock is NOT held. This lets T-34-IDEM-02 assert that the dedupe path took zero slow reads.

Step 4 (C++ regression tests in `tests/test-cache-controller.cpp`).

- T-34-IDEM-01: two slots with the same prompt token-span and namespace. Save the first; save the second. Assert `entries.size() == 1` after both return and the single entry's `use_count >= 2`. Asserts I-34-01 (hot-residency).
- T-34-IDEM-02: save slot A. After A returns, save slot B (same prompt). Assert B's `tx_save` returns true and the Step 3 slow-read counter for slot B's id reads zero. Asserts the first-pass dedupe skips the slow read.
- T-34-IDEM-03: pre-load slot A's entry, demote its payload to cold so `entry_has_payload_for_restore` is false but the entry still exists. Save slot B with the same prompt. Assert one entry exists afterward and `use_count` incremented. Asserts the cold-residency re-materialize branch (i-34-01 widened per required-action 1).
- T-34-PATHB-01: a slot in tx_save plus a second slot attempting tx_restore for an unrelated prompt. Assert the restore completes during the slow-read window without blocking for the slow-read duration (lock-wait time below the configured threshold). Asserts I-34-02.

Per the developer memory rule on Release tests, use explicit `if (!cond) { fprintf(stderr, ...); std::abort(); }` for required negative checks; do not rely on `assert` side effects.

Step 5 (header invariant comments). In `server-cache-hybrid.h`, near the `reentrancy_depth_limit_` declaration at L696, add one-line descriptions for I-34-01 and I-34-02. Keep wording tight per AGENTS.md comment guidance.

Step 6 (test-plan updates, delegated to QA in the next gate). The plan recommends QA add rows for T-34-IDEM-01, T-34-IDEM-02, T-34-IDEM-03, T-34-PATHB-01 to the hybrid test plan and the corresponding harness cases. This is enumerated for QA, NOT authored here.

Step 7 (test plan reclassification note for TP-34-CC). The exact label for QA to apply to TP-34-CC is: `EXPECTED-BEHAVIOR dispatch-ordering race (Stage 33 precedent)`. Rationale and precedent live in design part-04 and the Stage 33 closure report. No code change.

## 7. Affected files

- `tools/server/server-cache-hybrid.cpp`: Step 1 comments; Step 2 restructure; Step 3 debug counter.
- `tools/server/server-cache-hybrid.h`: Step 5 invariant comments.
- `tests/test-cache-controller.cpp`: Step 4 new tests.

No Python harness, no scripts, no fixtures planned in this step set.

## 8. Risks

Path B risk: the snapshot fields captured in the first section must stay stable across the slow read. Per Stage 25 lock granularity, the slot thread owns its `slot.id`, `ctx_tgt`, `slot.ctx_dft`, size values, and metadata for the duration of tx_save; the slot is not running inference during tx_save, so no other thread mutates these inputs. Stable snapshot holds.

Path B risk (recorded for the implementer): a parallel tx_save for the same prompt also buffers its own target and draft payloads before its second-pass dedupe discards one set. Transient memory pressure is bounded by `n_parallel * payload_size`; the first-section budget check still rejects a payload exceeding `limit_size`, and `evict_until_within_budget` re-enforces budget in the second section.

D34-REOPEN-06 risk: a parallel slot could evict the matched existing entry between the dedupe check and the use_count increment. Mitigation: in the current single-section code the check and increment are inside one lock, so the residency cannot change. Under Path B, the second-pass re-lookup is iterator-invalidation-safe because the implementer re-runs `find_equivalent_entry` rather than holding an iterator across the release; eviction during the read window only turns a would-be dedupe into a legitimate new entry.

## 9. Evidence plan

The implementer session will capture (this session does NOT run them):

- Clean Release build command (Windows MSVC, the build-x64-windows-msvc-release preset or CMake target the workspace already uses).
- Direct test-cache-controller run for T-34-IDEM-01, T-34-IDEM-02, T-34-IDEM-03, T-34-PATHB-01, with per-test pass counts.
- `ctest -R cache` aggregate run.
- Hygiene: `git diff --check` on the changed files; LF only, no BOM, no non-ASCII, no trailing whitespace on new docs; `[regex]::Matches` non-ASCII scan; byte-level CR count equals zero on new docs.

## 10. No-code-yet boundaries

This gate is planning only. It does NOT edit production code, tests, scripts, or fixtures. It does NOT run live replay, builds, or tests. It does NOT commit or push. The only durable artefact produced is this file.

## 11. Out of scope

Path C (optimistic commit before slow read) is rejected: it would publish a transient descriptor-hot-without-bytes state forbidden by the I-25-02 implementation contract.

Path D (test driver pre-warm delay) is rejected: it contradicts the Stage 34 acceptance criterion of concurrent dispatch.

Path E (delay slot recycling until predecessor tx_save commits) is rejected: it merges slot lifecycle with cache lifecycle. Path E is the only option that fully fixes the dispatch-ordering race, but it is a separate-stage design and is not pursued in this cycle.

A fix for the Bob-actual dispatch-ordering miss itself remains out of scope; the miss stays EXPECTED-BEHAVIOR under D34-REOPEN-05.

## 12. Open questions

None expected. If one surfaces during implementation, record it as OQ-34-05 onward in the implementation log and resolve it via design before continuing.

## 13. Files NOT modified

- No production code modified.
- No tests, fixtures, or scripts modified.
- No `document-index.md`, `cache-handling-stage-tracker.md`, manager-input file, design parts, or prior implementation logs modified.
- No `git add`, `git commit`, or `git push` performed.

This planning-only session created exactly one new durable file: this document.

## 14. Final hygiene

- LF line endings only; no BOM; no non-ASCII; no trailing whitespace.
- Line count target: well under 300 with buffer, measured by `(Get-Content -LiteralPath '<this file>').Count`.
- `git diff --check` exit code on the new file: reported in the final reply.
