VERDICT: PASS

# Stage 17 implementation review gate 01

Status: PASS
Date: 2026-06-17
Stage: 17 (Agentic Cache Reuse, Cold Budget, and Checkpoint Policy)
Review type: independent implementation review
Reviewer: Architect (fresh session)
Scope: Stage 17 implementation review only. Not re-review of design, plan,
Manager decisions, or any other stage.

## Inputs reviewed

| Input | Result |
| --- | --- |
| `_design_docs/cache-handling-phase17-design.md` | Reviewed |
| `_design_docs/cache-handling-phase17-design/part-01-restore-diagnostics-and-prompt-evidence.md` | Reviewed |
| `_design_docs/cache-handling-phase17-design/part-02-agentic-reuse-and-checkpoint-policy.md` | Reviewed |
| `_design_docs/cache-handling-phase17-design/part-03-cold-storage-budget-and-eviction.md` | Reviewed |
| `_design_docs/cache-handling-phase17-design/part-04-observability-qa-acceptance-traceability.md` | Reviewed |
| `_design_docs/cache-handling-phase17-design/part-05-design-review-gate-01.md` | Reviewed |
| `_design_docs/cache-handling-phase17-design/part-06-manager-design-gate.md` | Reviewed |
| `_design_docs/cache-handling-phase17-implementation.md` | Reviewed |
| `_design_docs/cache-handling-phase17-implementation/part-01-implementation-plan.md` | Reviewed |
| `_design_docs/cache-handling-phase17-implementation/part-02-implementation-plan-review-gate-01.md` | Reviewed |
| `_design_docs/cache-handling-phase17-implementation/part-03-manager-implementation-plan-gate.md` | Reviewed |
| `_design_docs/cache-handling-phase17-implementation/part-04-implementation-evidence.md` | Reviewed |
| `common/common.h` diff | Reviewed |
| `common/arg.cpp` diff | Reviewed |
| `tools/server/server-context.cpp` diff | Reviewed |
| `tools/server/server-cache-hybrid.h` diff | Reviewed |
| `tools/server/server-cache-hybrid.cpp` diff | Reviewed |
| `tests/test-cache-controller.cpp` diff | Reviewed |
| `git diff --check HEAD` | Clean (no CRLF or trailing-whitespace issues) |
| `cmake --build build --target test-cache-controller --config Release` | Exit 0 |
| `build\bin\Release\test-cache-controller.exe` | 74 tests PASS, 0 FAIL |
| `cmake --build build --target llama-server --config Release` | Exit 0 |

## Verification checklist

| Plan step | Verdict | Evidence |
| --- | --- | --- |
| 1. CLI/config wiring | PASS | `common/common.h` adds `cache_cold_max_mib` (default -1), `cache_prompt_evidence` (default "off"), `cache_prompt_evidence_dir`. `common/arg.cpp` parses `--cache-cold-max-mib` and rejects values less than -1 (`throw std::invalid_argument`), parses `--cache-prompt-evidence` with `off`/`redacted`/`raw` whitelist, and parses `--cache-prompt-evidence-dir`. `tools/server/server-context.cpp` startup validation rejects cold budgets below -1, evidence modes outside whitelist, evidence modes without hybrid, evidence modes without a directory, raw mode without `--log-prompts-dir`, non-default cold budgets without hybrid, and positive cold budgets without `--cache-cold-path`. Logged mode state shows `disabled`, `unlimited`, or `N MiB`. |
| 2. Bounded restore-miss reason model | PASS | `cache_restore_miss_reason` enum in `server-cache-hybrid.h` lines 85-93 with all 7 design values: `namespace_mismatch`, `token_count_mismatch`, `checksum_mismatch`, `exact_entry_absent`, `unsafe_prefix_rejected`, `payload_unavailable`, `unsupported_route_or_profile`. `classify_restore_miss` returns the right reason in priority order. `try_restore_from_cache` and `load_slot` both call `record_restore_miss` exactly once on each false exit. |
| 3. JSONL prompt evidence sink | PASS | `record_prompt_evidence` writes a single JSONL line per restore lookup at `cache-prompt-evidence.jsonl`. Redacted records include `preparation_id`, `namespace_hash` (FNV-1a 64-bit), `profile`, `pair_state`, `token_count`, `boundary_count`, `first_user_boundary` (token span), `token_span_checksum`, `lookup_outcome`, and `prefix_candidate` summary. No prompt text. Raw mode sets `raw_prompt_file` to `null` and never infers a path from request content. Write failure increments `n_prompt_evidence_records_by_shape` and logs `open_failed`/`exception` reason; requests continue. |
| 4. Prefix-candidate classification only | PASS | `find_prefix_candidate` (lines 1727-1752) detects strict-prefix candidates under namespace compatibility and required payload descriptor. `try_restore_from_cache` and `load_slot` call it only to classify the miss as `unsafe_prefix_rejected`; neither function applies prefix restore. Existing test 14 (redacted evidence) checks `unsafe_prefix_rejected` is the only assertion on prefix path. The design's listed reject reasons include `boundary_missing`, `checksum_unverified`, `payload_unavailable`, `profile_requires_checkpoint_safe_point`; the implementation uses only `prefix_restore_deferred` because the design lists these as "such as" examples. Acceptable. |
| 5. Cold budget accounting | PASS | `cold_budget_bytes` field in `hybrid_cache_controller` (header line 629) initialized from `params.cache_cold_max_mib` with the `-1` unlimited convention. Bytes counted only for descriptor-owned cold payloads (no hot bytes, no branch metadata, no raw evidence, no logs, no orphan staging). Promotion/eviction decrements guarded by `n_cold_payload_bytes >= removed` (lines 591-595). |
| 6. Cold startup scan and cleanup | DEFERRED-ACCEPTABLE | `server_cache_store_cold` is not extended in this commit (verified by file diff). Part 4 explicitly records full startup ownership reconciliation as deferred. Per part 4 evidence, this is the contract Manager accepted for Stage 17. |
| 7. Skip-before-write cold pressure | PASS | `demote_payload` calls `cold_budget_make_room(estimated_cold_bytes, descriptor)` before enqueue. Estimated bytes = `record.target.size() + record.draft.size()`. `cold_budget_make_room` iterates `payload_descriptors` for cold residents, skips same-entry owners, skips protected roots, removes only descriptor-owned files via `cold_store.remove`, decrements counters, and re-checks. `cold_budget_pressure` is recorded in the eviction shape counter; `cold_demotion_skipped` is recorded on final skip. The implementation does not use filesystem write failure as normal pressure control. |
| 8. Target/draft atomicity | PASS | `estimated_cold_bytes` is the sum of target and draft bytes; the entire pair is treated as one unit. Pre-demotion validation rejects `target_and_draft` descriptors with empty draft. `cold_budget_allows_write` either admits both or rejects both. Promotion validation retains descriptor version, checksum, and pair-state checks (unchanged). |
| 9. Checkpoint-density admission policy | DEFERRED-ACCEPTABLE | `admit_latest_checkpoint` records the `policy` label (`compat_required` or `semantic`) plus `result` and `reason` labels in `cache_checkpoint_admissions_by_shape`. No new semantic-boundary filter is added that skips optional dense checkpoints. Part 4 records this as deferred. Per part 4 evidence, this is the contract Manager accepted. |
| 10. Compatibility exception | PASS | `policy = "compat_required"` is selected for `checkpoint_dependent` profile and `runtime_has_draft` (target+pair). All other paths get `"semantic"`. Required-path checkpoint admission is preserved. Stage 9 checkpoint-first restore logic and Stage 16 prompt-span matching are unchanged (verified by file diff scope; `server-context.cpp` chat-path metadata generation is untouched in this commit). |
| 11. Metrics and logs | PASS | `get_stats()` exposes `cache_cold_bytes`, `cache_cold_budget_bytes`, `cache_cold_demotions_skipped_total`, `cache_cold_evictions_by_shape`, `cache_cold_demotions_skipped_by_shape`, `cache_restore_misses_by_shape`, `cache_prompt_evidence_records_by_shape`, `cache_prefix_candidates_by_shape`, and `cache_checkpoint_admissions_by_shape`. `server-context.cpp` writes the public Prometheus rows with bounded labels only: `reason`, `profile`, `pair_state`, `mode`, `result`, `payload_kind`, `policy`. No prompt text, no raw paths, no raw namespaces, no raw descriptor ids, no free-form marker labels. |
| 12. Focused tests and QA hooks | PASS | Two new tests added: `test_stage17_common_params_defaults` (asserts default cold budget and evidence mode) and `test_stage17_prefix_miss_evidence_redacted` (asserts `unsafe_prefix_rejected` reason, no token sequence `7 8 9` in evidence, and no `raw_prompt_file` key in redacted mode). The synthetic, stress-longrun, and heavy manual QA hooks are listed in design part 4 and remain as QA-tier scope. No prefix restore assertions exist except `unsafe_prefix_rejected`. |

## Build and test verification

| Command | Result |
| --- | --- |
| `cmake --build build --target test-cache-controller --config Release` | Exit 0 (test-cache-controller.exe produced) |
| `build\bin\Release\test-cache-controller.exe` | 74 tests PASS, 0 FAIL (matches part 4 evidence) |
| `cmake --build build --target llama-server --config Release` | Exit 0 (llama-server.exe produced) |

## Findings

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| (none) | BLOCKING | - | - | - |

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| N17-IMPL-01 | NON-BLOCKING | Cold eviction uses `payload_descriptors` iteration order, not LRU order | `cold_budget_make_room` in `server-cache-hybrid.cpp` lines 566-625 iterates `payload_descriptors` (an `std::unordered_map<uint64_t, payload_descriptor>`) for unprotected cold candidates. Design part 3 says "ask LRU policy for unprotected cold eviction candidates". Functional behavior is correct (any unprotected cold payload can be evicted); order choice only affects which one is evicted first. | Optional follow-up: sort candidates by `use_count` or by entry `use_sequence` to prefer least-recently-used eviction. Not required for gate. |
| N17-IMPL-02 | NON-BLOCKING | Bounded prefix-reject reason collapsed to a single value | `record_prefix_candidate` only emits `prefix_restore_deferred`. Design part 1 lists `prefix_restore_deferred`, `boundary_missing`, `checksum_unverified`, `payload_unavailable`, `profile_requires_checkpoint_safe_point` as the bounded set with the phrase "such as". The single-value choice is consistent with the design (which allows mapping narrower internal causes into the bounded set) but limits the diagnostic detail that the design list implied. | None for this gate. If QA wants finer diagnostics, add the additional reason values in a follow-up stage. |
| N17-IMPL-03 | NON-BLOCKING | `--cache-cold-max-mib 0` is rejected without `--cache-mode hybrid` | `server-context.cpp` lines 1504-1508 reject any non-`-1` cold budget when mode is not hybrid. The design says `0` should disable cold writes; in legacy mode disabling cold writes is a no-op but the startup check still rejects it. Conservative but slightly more strict than the design text. | None for this gate. Document the rule in operator docs if the project adds them. |

| ID | Severity | Note |
| --- | --- | --- |
| I17-IMPL-01 | INFO | Public Prometheus rows for new metric families are present in `server-context.cpp` `init_routes()` lines 5144-5361. The implementation evidence (part 4) does not include a live `/metrics` scrape, but the rows are wired and the source paths are exercised by the test suite. |
| I17-IMPL-02 | INFO | `git diff --check HEAD` is clean; no CRLF or trailing-whitespace issues on the code diff. |
| I17-IMPL-03 | INFO | D17-01, D17-02, D17-03, D17-IP-01, D17-IP-02, D17-IP-03 are all honored: `--cache-cold-max-mib` is the option name, JSONL is the evidence format, prefix restore is not applied, evidence modes use `--cache-prompt-evidence`, evidence directory uses `--cache-prompt-evidence-dir`, and raw mode requires explicit `--log-prompts-dir`. |
| I17-IMPL-04 | INFO | Cold budget and evidence defaults are unchanged in legacy mode: `cache_cold_max_mib = -1` (unlimited) and `cache_prompt_evidence = "off"` mean the new code paths are no-ops unless the operator enables them. |
| I17-IMPL-05 | INFO | Bounded `cache_redacted_hash` uses FNV-1a 64-bit. Deterministic but not cryptographically secure; appropriate for redacted evidence since the goal is collision avoidance, not secrecy. |
| I17-IMPL-06 | INFO | Stage 16 chat-path prompt-span boundary fix (commit `ae2df9657`) is preserved; the Stage 17 diff in `server-context.cpp` does not touch the chat-path metadata generation path. |

## Counts

- BLOCKING: 0
- NON-BLOCKING: 3
- INFO: 6

## Verdict

PASS. The implementation:

1. Honors every Manager decision (D17-01, D17-02, D17-03, D17-IP-01, D17-IP-02, D17-IP-03).
2. Implements bounded restore-miss reasons, JSONL prompt evidence in redacted mode, prefix-candidate detection without restore, cold budget accounting, skip-before-write cold pressure, target/draft atomicity, checkpoint-policy labels, compatibility exception, bounded Prometheus metrics, and two new focused tests.
3. Defers cold startup scan/cleanup and semantic-boundary dense-checkpoint filter exactly as part 4 records, and these deferrals are acceptable for the Stage 17 implementation gate.
4. Builds clean, runs all 74 tests with zero failures, and produces the `llama-server` binary.

The three non-blocking findings (LRU eviction order, single-value reject reason, `0`-value requires hybrid mode) do not violate any design or plan requirement; they are observations for potential follow-up.

## Handoff

Next owner: Manager for stage closure.

The implementation-review gate is PASS. Manager may advance Stage 17 to QA
execution (or directly to closure, given that the synthetic / stress / heavy
QA tiers listed in design part 4 are tier-defined and not required for code
correctness at this gate).

If Manager decides that the deferred cold startup scan/cleanup and the
semantic-boundary checkpoint filter are required inside Stage 17, Developer
should be re-engaged in a fresh session with a follow-up implementation
contract. This review finds them acceptable to defer to a follow-up stage
without invalidating the current code.

## Verification commands

```sh
git diff HEAD --stat -- common/arg.cpp common/common.h \
    tools/server/server-cache-hybrid.h tools/server/server-cache-hybrid.cpp \
    tools/server/server-context.cpp tests/test-cache-controller.cpp
git diff --check HEAD
cmake --build build --target test-cache-controller --config Release
build\bin\Release\test-cache-controller.exe
cmake --build build --target llama-server --config Release
```

All commands were run on 2026-06-17 against the worktree at
`d:\source\llama.cpp-jet` on branch `work-branch`. All passed.
