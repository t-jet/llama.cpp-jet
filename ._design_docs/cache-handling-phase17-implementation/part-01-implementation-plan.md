# Stage 17 implementation plan -- Part 1

Source: [../cache-handling-phase17-implementation.md](../cache-handling-phase17-implementation.md)
Date: 2026-06-17
Status: authored; pending Architect implementation-plan review

## Approved baseline

Implementation must follow the approved Stage 17 design:

- [Stage 17 design entry](../cache-handling-phase17-design.md)
- [Part 1: restore diagnostics and prompt evidence](../cache-handling-phase17-design/part-01-restore-diagnostics-and-prompt-evidence.md)
- [Part 2: agentic reuse and checkpoint policy](../cache-handling-phase17-design/part-02-agentic-reuse-and-checkpoint-policy.md)
- [Part 3: cold storage budget and eviction](../cache-handling-phase17-design/part-03-cold-storage-budget-and-eviction.md)
- [Part 4: observability, QA, acceptance, and traceability](../cache-handling-phase17-design/part-04-observability-qa-acceptance-traceability.md)
- [Part 5: design review PASS](../cache-handling-phase17-design/part-05-design-review-gate-01.md)
- [Part 6: Manager design gate PASS](../cache-handling-phase17-design/part-06-manager-design-gate.md)

Manager decisions from part 6 are binding:

- D17-01: use `--cache-cold-max-mib`.
- D17-02: prompt evidence defaults to JSONL, one record per restore lookup.
- D17-03: prefix restore is deferred. Stage 17 may detect prefix candidates and classify them as `unsafe_prefix_rejected`, but it must not apply prefix restore.

Architecture and requirement inputs remain binding: requirements R4a-R133;
architecture restore order (part 2), payload/pruning distinction (part 4),
byte-accounted LRU (part 5), and chat-path prompt-span invariant (part 9).

## Code surfaces

Planned implementation files:

- `common/arg.cpp` and common params storage: parse and store `--cache-cold-max-mib`.
- `tools/server/server-context.cpp`: startup validation, cache controller construction, Prometheus export, task restore entry point.
- `tools/server/server-task.h` and `.cpp`: add or pass prompt-evidence config only if the existing task/params path needs it.
- `tools/server/server-cache-hybrid.h` and `.cpp`: restore miss classification, prompt evidence writer, prefix-candidate classification, cold budget accounting, checkpoint-density policy, stats.
- `tools/server/server-cache-store-cold.h` and `.cpp`: startup scan, staging cleanup, owned-byte scan helpers, bounded cleanup results.
- `tools/server/server-cache-io-worker.h` and `.cpp`: demotion skip path and completion accounting if cold budget blocks queued writes.
- `tools/server/server-cache-policy-lru.*`: reuse existing LRU candidate ordering for cold eviction; extend only if cold-specific candidate metadata is missing.
- `tests/test-cache-controller.cpp`, cold-store focused tests, startup validation tests, metrics tests, and server pytest hooks under `tools/server/tests` as needed.

## Ordered implementation steps

1. Add config and startup validation.
   Add `cache_cold_max_mib` to common params, parse `--cache-cold-max-mib` in `common/arg.cpp`, and validate in `server-context.cpp` before requests are accepted. Reject values less than `-1`. Require hybrid mode and configured cold path for enabled cold writes unless existing cold-path behavior is kept as an explicit no-op warning. Log configured mode: disabled, limited, or unlimited.

2. Add bounded restore-miss reason model.
   Add `cache_restore_miss_reason` in `server-cache-hybrid.h` with exact mapping to `namespace_mismatch`, `token_count_mismatch`, `checksum_mismatch`, `exact_entry_absent`, `unsafe_prefix_rejected`, `payload_unavailable`, and `unsupported_route_or_profile`. Add helpers to map narrower internal causes into this set. Update `try_restore_from_cache` and `load_slot` miss exits to record one primary reason per lookup.

3. Add prompt evidence JSONL sink.
   Implement an internal sink in `server-cache-hybrid.*` or a small companion module if the file grows too much. Redacted mode writes namespace hash, profile, pair state, token count, boundary count, first-user boundary, token-span checksum, lookup outcome, and redacted prefix-candidate summary. Raw mode may include `raw_prompt_file` by relative file name only and must require explicit prompt logging directory config. Evidence write failures increment bounded counters and do not fail requests.

4. Add prefix-candidate classification only.
   Extend restore lookup to detect strict-prefix candidates under the same namespace and pair state. Do not restore them. Classify candidates that are not exact-safe as `unsafe_prefix_rejected` with a bounded reject reason such as `prefix_restore_deferred`, `boundary_missing`, `checksum_unverified`, `payload_unavailable`, or `profile_requires_checkpoint_safe_point`.

5. Add cold budget accounting.
   Track `cold_budget_bytes`, `cold_budget_unlimited`, and `cold_budget_disabled` in `hybrid_cache_controller`. Count only descriptor-owned cold payload bytes after atomic write and descriptor ownership attach. Exclude hot bytes, branch metadata, raw evidence files, logs, and orphan staging files. On promotion or cold eviction, decrement bytes with underflow guards.

6. Add cold startup scan and cleanup.
   Extend `server_cache_store_cold` to scan the normalized cold root, count owned `.cold` files when descriptors claim them, remove internal staging files, and report orphan files without following symlinks. Startup must record starting cold bytes before new demotions. Cleanup must stay under the cold root and log bounded failures.

7. Enforce skip-before-write cold pressure.
   Before `demote_payload` queues a write, estimate target plus draft bytes. If the limited cold budget would be exceeded, ask LRU policy for unprotected cold eviction candidates, delete only descriptor-owned files after ownership checks, then re-check budget. If still over budget, skip demotion and let hot-budget logic keep or evict hot bytes. Record `cold_budget_exceeded` or `cold_demotion_skipped`. Do not use filesystem write failure as normal pressure control.

8. Preserve target/draft atomicity.
   Treat paired target/draft payloads as one budget unit. If budget allows only one side, skip demotion for both sides. Failed demotion must not attach cold residency. Promotion validation keeps existing descriptor version, checksum, and pair-state checks.

9. Add checkpoint-density admission policy.
   Keep `--ctx-checkpoints 0` as disable. Treat positive `--ctx-checkpoints` as the upper bound on runtime checkpoints considered for admission. Keep `--checkpoint-min-step` as hard spacing for optional non-semantic admissions. Prefer semantic branch points: shared setup/tool-definition end, first-user branch point, and final prompt state. Skip dense optional checkpoints with bounded reasons.

10. Apply compatibility exception.
    Preserve required checkpoint admission for checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP-heavy profiles. The policy filters optional extras only. Stage 9 checkpoint-first restore and Stage 16 prompt-span matching must remain intact.

11. Add metrics and logs.
    Extend `get_stats()` and `server-context.cpp` Prometheus rows for `cache_restore_misses_total`, `cache_prompt_evidence_records_total`, `cache_prefix_candidates_total`, `cache_checkpoint_admissions_total` label extensions, `cache_cold_bytes`, `cache_cold_budget_bytes`, `cache_cold_evictions_total`, and `cache_cold_demotions_skipped_total`. Labels must be bounded: reason, profile, pair_state, mode, result, policy, state, and payload_kind only. No prompt text, raw paths, raw namespaces, raw descriptor ids, or free-form marker labels.

12. Add focused tests and QA hooks.
    Add unit tests for the enum mapping, evidence redaction, prefix rejection, cold budget values, startup cleanup, skip-before-write behavior, target/draft budget atomicity, checkpoint-density policy, compatibility exception, and metric label allowlist. Add integration/QA hooks for synthetic agentic prompts, stress-longrun cold pressure, and heavy manual/nightly MTP runs. Do not add prefix restore assertions except `unsafe_prefix_rejected`.

## Restore miss diagnostics plan

Each restore lookup records one primary bounded reason:

| Internal condition | Bounded reason |
| --- | --- |
| Route/profile blocks restore before candidate ranking | `unsupported_route_or_profile` |
| Candidate evidence matches token shape or checksum but namespace differs | `namespace_mismatch` |
| Same namespace exists but nearest token counts do not match exactly | `token_count_mismatch` |
| Same namespace and token count but token-span checksum differs | `checksum_mismatch` |
| No exact candidate in namespace | `exact_entry_absent` |
| Prefix candidate exists but Stage 17 policy forbids restore | `unsafe_prefix_rejected` |
| Descriptor, hot payload, cold promotion, residency, or integrity blocks restore | `payload_unavailable` |

Implementation should collect nearest lower and higher token counts, namespace hash,
profile, pair state, and redacted candidate summaries for evidence records, but
Prometheus labels use only the bounded reason/profile/pair_state set.

## Prompt evidence plan

Default mode is off. Redacted mode writes JSONL records without prompt text.
Raw mode writes JSONL records plus a relative raw prompt file name only when an
operator explicitly configured raw prompt capture. Raw mode must not infer file
names from request content.

Privacy constraints:

- Prompt text never appears in metrics, normal bounded diagnostics, descriptor ids, or namespace labels.
- Raw prompt capture must be opt-in and tied to an operator-configured directory.
- Evidence file paths must stay under configured roots and use internal ids.
- Write failure is diagnostic-only and must not change cache behavior.

## Test and evidence plan

Focused C++ tests:

- restore miss reason enum and one-primary-reason accounting
- redacted evidence contains no prompt text and raw mode requires prompt dir
- exact repeat still restores through exact path
- prefix candidate is counted and rejected as `unsafe_prefix_rejected`
- `--cache-cold-max-mib` values `0`, positive, `-1`, and invalid negatives
- cold startup staging cleanup and owned-byte scan
- cold eviction before demotion write and skipped demotion when pressure remains
- target/draft pair demotion skipped when only one side fits
- semantic checkpoint policy skips optional dense checkpoints
- MTP/checkpoint-dependent exception keeps required checkpoints
- metrics emit bounded labels only

Integration and QA hooks:

- synthetic 12k, 24k, and 60k generated chat prompts with exact repeat, new user turn, same branch continuation, and same-prefix different agent
- Stage 12/15 stress-longrun extension with cold pressure and branch forest growth
- heavy manual/nightly Qwen3.6-27B-MTP run near 60k prompts, 8 GiB hot cache, bounded cold budget

Evidence expected at implementation handoff:

- focused build target names and commands actually run
- focused test logs with pass/fail counts
- Prometheus sample rows for new metric families
- JSONL evidence sample in redacted mode and raw-mode gating test
- explicit note that prefix restore was not implemented

## Risks and open questions

| ID | Risk or question | Plan state |
| --- | --- | --- |
| R17-01 | Final names for prompt evidence CLI/config are not fixed by Manager decision. | Implementation must choose the smallest local config surface and record it before code review. |
| R17-02 | Existing `server-cache-hybrid.cpp` is large. | Split evidence helpers into a companion module if the implementation would push the file toward less reviewable growth. |
| R17-03 | Cold startup scan cannot know descriptor ownership before controller state exists. | Use startup cleanup for staging files, then controller-owned byte accounting after descriptors are loaded or attached. Do not count unknown files as restorable. |
| R17-04 | Semantic boundary detection may be incomplete for synthetic or degraded metadata. | Fall back to exact restore, classify prefix candidates unsafe, and skip only optional dense checkpoints. |
| R17-05 | Metric family names overlap older `llamacpp_cache_*` rows. | Prefer design names for new families while leaving existing rows intact for compatibility. |
| R17-06 | Heavy MTP evidence is too expensive for normal gate runs. | Keep it as manual/nightly QA evidence; focused and synthetic tests are the normal implementation gate. |
