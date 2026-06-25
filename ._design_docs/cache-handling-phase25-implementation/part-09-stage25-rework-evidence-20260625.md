# Stage 25 implementation REWORK evidence

Status: REWORK COMPLETE
Date: 2026-06-25
Stage: 25 (Atomic Transactional Cache Writes)
Author: Developer (rework iteration)
Source review: [./part-08-architect-implementation-review-20260625.md](./part-08-architect-implementation-review-20260625.md)
Source plan: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)
Manager gate: D25-EXEC-01 still pending; this iteration addresses
Architect REWORK findings B-1 (BLOCKING) and NB-1 (non-blocking).

## Verdict

COMPLETE. B-1 slot lifecycle routing fixed: save_slot, try_restore_from_cache,
and load_slot now delegate to tx_save / tx_restore + tx_apply_restore /
tx_load respectively. tx_save and tx_load are now real implementations
(previously stubs returning false). NB-1 tx_assert_mutex_held guard now
called on 10 private mutator entry points.

To make server_slot accessible from server-cache-hybrid.cpp (where tx_*
methods are defined), the struct was extracted from server-context.cpp
into a new header `tools/server/server-slot.h`. The slot_state enum
was also moved into the header so server_slot can use it as a member
type. server-context.cpp's inline definition was removed; the test
stub struct (id + ctx_tgt + ctx_dft) was removed in favor of the full
struct from the header.

## B-1 fix (BLOCKING)

### tx_save: stub -> real

`tx_save(server_slot & slot, const prepared_prompt_metadata & metadata)`
in server-cache-hybrid.cpp acquired `cache_state_mutex_` via
`std::lock_guard<std::recursive_mutex>` and `reentrancy_guard` for the
reentrancy counter, then ran the full save body inline (extracted
verbatim from server-context.cpp save_slot). Returns `true` on
admission, `false` on rejection (empty slot, target/draft empty,
budget exceeded, descriptor validation failed). Includes the
re-materialization path (existing entry with payload), the new-entry
admission path, and the checkpoint admission path via
`admit_latest_checkpoint_and_store_metadata`.

### tx_restore + tx_apply_restore: real, slot lifecycle delegates

`tx_restore` was already implemented in the previous iteration and
acquired the lock for planning. The slot lifecycle
`try_restore_from_cache` was refactored to:

1. Call `tx_restore(slot, task)` to get a `cache_response plan` (under
   lock, with `entry_tokens` / `entry_checkpoints` / `entry_metadata`
   captured for apply outside the lock).
2. If `plan.found` is false, return false (miss path handled by
   `tx_restore` already, including `n_misses++`, `n_fallback_restores++`,
   `record_restore_miss`, etc.).
3. Apply step OUTSIDE `cache_state_mutex_` per OQ-25-01 SPLIT:

   - Snapshot pre-state via `llama_state_seq_get_data_ext` (reads
     llama_context, no lock needed).
   - Clear live state via `llama_memory_seq_rm` (mutates
     llama_context, not cache state).
   - Apply target/draft state via `llama_state_seq_set_data_ext`
     using `plan.target_bytes` / `plan.draft_bytes` / `plan.restore_flags`.
   - On apply failure: rollback via the captured `target_before` /
     `draft_before` / `prompt_before`, then call
     `tx_apply_restore(slot, plan, false)` to record the failure in
     cache state metrics.
   - Update slot prompt state (`slot.prompt.tokens`,
     `slot.prompt.checkpoints`, `slot.n_prompt_tokens_cache`,
     `slot.n_prompt_tokens_processed`, `slot.hybrid_cache_restored`,
     `slot.prompt_metadata`) from the captured entry state in the plan.
4. Finalize via `tx_apply_restore(slot, plan, true)` to update cache
   state owner-view sync and metrics (`mark_used`,
   `sync_branch_node_from_entry`, `update_lru_index`, `n_hits++`,
   `record_prompt_evidence`).

`cache_response` now carries `entry_tokens` (server_tokens captured
via `clone()` because server_tokens is non-copyable), `entry_checkpoints`
(std::list copy), and `entry_metadata` (struct copy) so the apply
step can update slot prompt state without re-locking the cache. Without
this capture, the apply step would race with concurrent eviction
between tx_restore lock release and apply start.

### tx_load: stub -> real

`tx_load(server_slot & slot, const server_task & task)` in
server-cache-hybrid.cpp acquired `cache_state_mutex_` via
`std::lock_guard<std::recursive_mutex>` and `reentrancy_guard`, then
ran the full legacy load body inline (extracted verbatim from
server-context.cpp load_slot). The legacy load uses the synchronous
`promote_payload` for cold residency; tx_load handles
`find_best_match`, residency checks, validation, pre-state
snapshot, live-state clear, apply, rollback on failure, and cache-state
finalize.

### slot lifecycle: lock_guard -> tx_* delegation

`hybrid_cache_controller::save_slot` in server-context.cpp is now:

```cpp
bool hybrid_cache_controller::save_slot(server_slot & slot, const prepared_prompt_metadata & metadata) {
    // Stage 25: route the slot lifecycle through the canonical transactional
    // entry point. tx_save acquires cache_state_mutex_ once and runs the
    // save body inline; this delegates atomicity ownership to the controller
    // per design Part 3 row 19.
    return tx_save(slot, metadata);
}
```

`hybrid_cache_controller::load_slot`:

```cpp
bool hybrid_cache_controller::load_slot(server_slot & slot, const server_task & task) {
    return tx_load(slot, task);
}
```

`hybrid_cache_controller::try_restore_from_cache`: see "tx_restore +
tx_apply_restore" above for the full delegation pattern.

## NB-1 fix (non-blocking)

`tx_assert_mutex_held()` calls added at the top of 10 private mutator
entry points (per the binding requirement that the guard is called on
"private mutators that mutate cache state"):

| Mutator | Line |
| --- | --- |
| `cold_budget_make_room` | L604 |
| `refresh_entry_payload_accounting` | L1718 |
| `materialize_entry_payload` | L2954 |
| `admit_entry_with_payload` | L3081 |
| `sync_branch_node_from_entry` | L3150 |
| `remove_payload` | L3281 |
| `mark_payload_kind_evicted` | L3330 |
| `mark_payload_evicted` | L3379 |
| `attach_payload` (no-kind overload) | L3500 |
| `attach_payload` (with-kind overload) | L3511 |

The guard is a `try_lock` + immediate `unlock` check that fails an
assert when the lock is not held. Compiles to a no-op in NDEBUG Release
builds, so production runtime cost is zero.

## Architectural change: server_slot moved to header

To make `server_slot` accessible from both `server-context.cpp` (where
the slot lifecycle delegates to tx_*) and `server-cache-hybrid.cpp`
(where tx_* bodies now reside and access `slot.id`, `slot.prompt.tokens`,
`slot.task`, `slot.ctx_dft`, `slot.prompt.checkpoints`,
`slot.hybrid_cache_restored`, etc.), the struct was extracted from
`server-context.cpp` (originally inline at L239..901) into a new header
`tools/server/server-slot.h`. The `slot_state` enum (originally inline
in server-context.cpp just before the struct) was also moved into the
header so the struct can use it as the type of its `state` member.

- New file: `tools/server/server-slot.h` (702 CRLF lines)
- Includes from: `tools/server/server-cache-hybrid.h` (line 8)
- Removed from: `tools/server/server-context.cpp` (inline struct and
  slot_state enum both gone; replaced with a comment block referring
  to the header)
- Test stub removed: `tests/test-cache-controller.cpp` previously
  declared its own minimal `struct server_slot { int id; ...; }`
  stub because the real struct was not in any header. Now that the
  full struct is in the header, the test gets the full type via
  `server-cache-hybrid.h -> server-slot.h` and the stub is removed.

## Code and test changes (this iteration only)

Files modified (git diff -w --numstat; CRLF for cpp/h, LF for h is OK):

| Path | Insertions | Deletions |
| --- | --- | --- |
| `tools/server/server-slot.h` | (new file, 702 lines) | n/a |
| `tools/server/server-cache-hybrid.h` | 145 | 1 |
| `tools/server/server-cache-hybrid.cpp` | 875 | 27 |
| `tools/server/server-context.cpp` | 59 | 1289 |
| `tests/test-cache-controller.cpp` | 257 | 1 |
| **Total tracked** | **1336** | **1318** |

server-cache-hybrid.cpp: the 875 insertions are tx_save (full save
body) + tx_load (full load body) + the entry-state capture additions
in tx_restore. The 27 deletions are the prior stub bodies (return false;
return false; and stub comments).

server-cache-hybrid.h: 145 insertions include the new fields on
`cache_response` (`entry_tokens`, `entry_checkpoints`, `entry_metadata`)
and the new `server-slot.h` include. The 1 deletion is the prior
forward declaration `struct server_slot;`.

server-context.cpp: 59 insertions are the delegation comments +
try_restore_from_cache apply step. 1289 deletions are the moved save
body (153 lines), try_restore_from_cache body (342 lines),
load_slot body (252 lines), and the inline server_slot + slot_state
definitions (~660 lines combined).

tests/test-cache-controller.cpp: 257 insertions are mostly unchanged
test bodies (the file diff includes some incidental changes from the
previous implementation iteration). The 1 deletion is the prior
minimal struct stub.

## Compile evidence

```powershell
cmake --build build-cuda --config Release -j --target llama-server
cmake --build build-cuda --config Release -j --target test-cache-controller
```

Both binaries built clean with NDEBUG Release. Pre-existing LNK4098
CRT linkage warning unchanged. No new warnings emitted. No errors.

## Test results

```powershell
& D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
```

Exit code: 0.

| Tier | Tests | Status |
| --- | --- | --- |
| Legacy + Part 14 + Stages 4..24 | 122 | PASS |
| Stage 25 atomic transactional | 10 (TP-25-UT1..UT10) | PASS |
| **Total** | **132** | **PASS** |

Printed total:
`Total: 132 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4
focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused +
7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04
T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21
bugfix 2026-06-18 + 9 Stage 23 focused + 15 Stage 22 focused + 2 Stage 24
focused + 10 Stage 25 atomic transactional)`

## Hygiene

- `git diff --check` on durable docs (`.md` files): clean.
- `server-cache-hybrid.cpp`: CRLF (CR=5233 LF=5233) per pre-existing
  repo convention.
- `server-context.cpp`: CRLF (CR=5911 LF=5911) per pre-existing repo
  convention.
- `server-cache-hybrid.h`: LF (CR=0 LF=1038) per pre-existing repo
  convention.
- `server-slot.h`: CRLF (CR=702 LF=702); the new header follows the
  .cpp file convention for consistency with the rest of the cache
  implementation (server-cache-hybrid.h is LF because it is a header
  consumed by LF .md docs and the test file).
- `test-cache-controller.cpp`: LF (CR=0 LF=4777).
- No trailing whitespace added; verified with byte-level scan.
- No BOM.
- ASCII only.

## Handoff state

- B-1 fixed: save_slot delegates to tx_save, try_restore_from_cache
  delegates to tx_restore + apply outside lock + tx_apply_restore,
  load_slot delegates to tx_load.
- NB-1 fixed: tx_assert_mutex_held() added on 10 private mutator
  entry points.
- server_slot moved to tools/server/server-slot.h (architectural fix
  required by B-1 routing).
- 132/132 tests pass.
- Both binaries build clean.
- Ready for Architect re-review.
- Next owner: Architect for re-review of B-1 + NB-1; Manager D25-EXEC-01
  gate decision after Architect PASS.
