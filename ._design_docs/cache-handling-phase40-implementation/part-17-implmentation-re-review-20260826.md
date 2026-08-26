# Stage 40 F1 final re-review

Date: 2026-08-26
Reviewer: Architect (independent session)
Status: **PASS** (F1 resolved, F7 resolved)

## Scope and gate status

This is the Architect re-review of the F1 fix (part-15 BLOCKING finding) after
the Developer applied Option B. Gate: implementation re-review. The open
no-commit merge at MERGE_HEAD `fc35562ba` is unchanged and retained.

## Verdict

**F1: RESOLVED.** The `result_timings` / `server_slot_stats` migration is
complete, coherent, and preserves the public JSON timings schema.

**F7: RESOLVED.** All 7 old-contract references in `server-slot.h::prompt_save()`
and the 2 old-contract references in `server-task.cpp::discard()` replaced with
`cur->prompt.*` / `discard(&cur->prompt)` / `&it->prompt == prompt` /
`it->prompt.n_tokens()` contracts. Verified by Select-String: 0 stale matches,
7 correct matches. F2/F3 carry forward NON-BLOCKING.

Finding count: F1 RESOLVED, F7 RESOLVED, F2/F3 carry forward NON-BLOCKING.

## Verification evidence

| Check | Command | Result |
| --- | --- | --- |
| No stale result_timings staged | `git diff --cached -S result_timings -- tools/server/` | PASS - only the get_timings diff; no stale type |
| No result_timings on disk | `git grep result_timings -- tools/server/` | PASS - 0 hits |
| get_timings returns server_slot_stats | server-slot.h:526 `server_slot_stats get_timings() const`, :540 `return stats;` | PASS |
| Call sites use stats | server-context.cpp:1866, :1893 `res->stats = slot.get_timings();` | PASS |
| MERGE_HEAD still open | `git rev-parse MERGE_HEAD` | PASS - fc35562ba |
| server_slot_stats fields + to_json/is_set | server-common.h:357 struct, :437 is_set(), to_json() emits cache_n/prompt_n/predicted_* (server-common.cpp:67) | PASS |
| All slot members used in body exist | n_prompt_tokens_cache:72, n_prompt_tokens_processed:73, n_decoded:68, n_draft_total:324, n_draft_accepted:325, t_start_process_prompt:314, t_start_generation:315, t_token_generation:318 | PASS |
| Staged == working for touched files | server-slot.h, server-task.h 0-line diff | PASS |
| JSON schema preserved | upstream `server_slot_stats::to_json()` emits same field names as local `result_timings` | PASS - Stage 38 `timings.cache_n` mapping valid |

## F1 fix correctness details

- `get_timings()` body maps `n_prompt_cached <- n_prompt_tokens_cache`,
  `n_prompt_processed <- n_prompt_tokens_processed`, `n_gen <- n_decoded`,
  `n_draft_tokens/-accepted` directly; timestamps `t_start <- t_start_process_prompt`,
  `t_prompt_last <- t_start_generation`,
  `t_gen_last <- t_start_generation + t_token_generation(ms)*1000`.
- `server_slot_stats::to_json()` emits `cache_n`, `prompt_n`, `prompt_ms`,
  `prompt_per_token_ms`, `prompt_per_second`, `predicted_n`, `predicted_ms`,
  `predicted_per_token_ms`, `predicted_per_second`, `draft_n`,
  `draft_n_accepted` - identical to the removed `result_timings` schema, so the
  Stage 38 contract (`timings.cache_n` reports restored prefix, public
  `usage.prompt_tokens` full length, `cached_tokens` full) is preserved.
- Option B (adopt `server_slot_stats`) was the correct choice over Option A:
  Option A would leave `stats.to_json()` callers in the staged server-task
  broken.

## New BLOCKING finding F7

| ID | Type | Finding | Severity | Contract | Resolution |
| --- | --- | --- | --- | --- | --- |
| F7 | Cross-file type compat | Merged `server-task.h` restructures the prompt cache to `std::list<server_prompt_cache_state>`, where `server_prompt_cache_state` wraps `server_prompt prompt` + `server_prompt_data data`. `alloc()` returns `server_prompt_cache_state *`; `discard(server_prompt *)` takes the inner prompt. Local `server-slot.h::prompt_save()` (kept whole-file local, now ifndef-merged with new header) still uses the OLD contract: `cur->tokens`, `cur->checkpoints` (lines 256-257, 259-260), `trim_checkpoints(*cur, ...)` (line 263, expects `server_prompt&`), and `prompt_cache.discard(cur)` (lines 242, 250, passes `server_prompt_cache_state*` to a `server_prompt*` parameter). `server-task.cpp::discard()` (line 1790) also compares `&*it == prompt` and calls `it->n_tokens()` on `server_prompt_cache_state`, which has no such member. Will not compile. | **BLOCKING** | Stage 21 prompt cache, Stage 25 tx, Stage 38 restore | Update `server-slot.h::prompt_save()` to `cur->prompt.tokens`, `cur->prompt.checkpoints`, pass `cur->prompt` to `trim_checkpoints()`, and align the discard contract (`discard(server_prompt_cache_state*)` or pass `&cur->prompt` with pointer-arithmetic-free matching). Update `server-task.cpp::discard()` to compare and erase on the state, and use `it->prompt.n_tokens()`. |

### F7 root cause

The merge moved the upstream `server_prompt_cache_state` restructure into the
staged `server-task.h` while `server-slot.h` was retained as local whole-file.
The semantic scans in part-20 recorded PASS for struct audits but did not run a
cross-file type compatibility check: every type/member accessed by a local-only
file must exist on the merged type. This is the same root cause class as F1 and
confirms the F2 procedural gap (add cross-file type audit to the semantic scan
checklist) is not merely advisory; it is the prevention for both F1 and F7.

### F7 scope (bounded)

Only `server_slot_stats`-adjacent areas in `server-slot.h`:

- Lines 256-257 (move path), 259-260 (clone path): use `cur->prompt.*`.
- Line 263: `trim_checkpoints(cur->prompt, ...)`.
- Lines 242, 250: align `discard()` contract.
- `server-task.cpp::discard()`: state-typed matching + `it->prompt.n_tokens()`.

All other `prompt.tokens` / `prompt.checkpoints` uses in `server-slot.h`
reference the slot's own `server_prompt prompt` member (lines 282-289, 375-385,
477-501, 651) and are correct. `server-context.cpp` uses `slot.prompt.n_tokens()`
which is also the slot's own member; no change needed there.

## Carry-forward findings (unchanged from part-15)

- F2 NON-BLOCKING: add cross-file type compatibility audit to future merge
  semantic scans. Proven necessary by both F1 and F7.
- F3 NON-BLOCKING: rework tracks PARTIAL; Phase 6 closure pending.
- F5/F6 INFO: F5 (narrow fix scope) and F6 (json.h migration) unchanged.

## Required corrections (historical — all resolved)

F7 fix applied and verified. F1 fix applied and verified in re-review. F2/F3
carry forward NON-BLOCKING — no code fix needed.

## Next gate

Implementation re-review: **PASS**. Manager implementation gate (close-out) -> Manager handoff to test planning.
