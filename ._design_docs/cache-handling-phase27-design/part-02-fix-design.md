# Part 2: Fix design - minimal modification + verification path

Status: design approved; Manager gate closed per D-CLOSURE-27-01 2026-06-26
Date: 2026-06-26
Scope: ONE function modification (preferred); specifies exact lines to change; preserves Stage 21/22/25/26 invariants.
Historical note: the design budgeted 1-2 fix iterations with verification gating. Actual execution found Candidate A insufficient (Stage 24 -05 still crashed) and identified a different root cause in iter 4; the applied fix is a 1-character change at `tools/server/server-cache-hybrid.cpp:3396` (`demote_payload` -> `tx_demote_payload`) per implementation log [part-10](../cache-handling-phase27-implementation/part-10-manager-closure-20260626.md).

## Fix shape

The Stage 26 commit (4556965c7) already modified `admit_latest_checkpoint_and_store_metadata` to remove the wasteful alloc+free pattern. Stage 27 starts by VERIFYING that fix, then layers additional defenses if verification fails.

### Step 1 (verification): rebuild and rerun Stage 24

Build clean Release from `4556965c7`, then run `stage24-chat-s02-s03-comparison.ps1` with the `-CrashDumpDir` parameter and the post-fix binary. Observe whether S03-chat hybrid completes past request 258.

- If S03 hybrid leg completes (no crash, last req count >= 257): Candidate A is confirmed; D-EXEC-24-03 is FIXED. No further code change required for this stage.
- If S03 hybrid still crashes at request 258 with the same signature: Candidate A is insufficient. Proceed to Step 2.

### Step 2 (additional fix, only if Step 1 fails): harden `attach_checkpoint_payload` rollback

Only invoked if Step 1 fails. Defensive additions:

1. `attach_payload` (line 3532): wrap the `hot_payloads[record.payload_id] = std::move(record)` insert in try/catch to roll back the descriptor insert on exception. Pseudocode:

   ```cpp
   try {
       hot_payloads[record.payload_id] = std::move(record);
   } catch (...) {
       payload_descriptors.erase(descriptor.payload_id);
       throw;
   }
   ```

2. `remove_payload` (line 3303): confirm symmetric handling when descriptor exists but hot_payload is missing. Current code is correct; no change needed.

3. `attach_checkpoint_payload` (line 3681): on any rollback path that calls `remove_payload`, log the descriptor id and reason at SRV_DBG level so the next rerun has telemetry.

### Step 3 (telemetry, always applied): add bounded save-size diagnostic

Independent of which root cause is confirmed, add a SRV_DBG log line at the end of `tx_save` recording `total_size` and `cache_n` so future failures have a bounded diagnostic. Pseudocode:

```cpp
SRV_DBG(" - hybrid cache: tx_save done slot=%d tokens=%zu total_size=%.3fMiB cache_n=%zu\n",
        slot.id, entry_tokens.size(), total_size / (1024.0 * 1024.0), entries.size());
```

This is one SRV_DBG line; it does not change behavior, only observability.

## Exact lines to change (after Step 1 verification confirms Candidate A is insufficient)

| File | Line range | Change |
| --- | --- | --- |
| `tools/server/server-cache-hybrid.cpp` | 3532..3573 (`attach_payload`) | Wrap `hot_payloads[record.payload_id] = std::move(record)` in try/catch; on exception, erase the just-inserted descriptor entry and rethrow |
| `tools/server/server-cache-hybrid.cpp` | 3882..3895 (`admit_latest_checkpoint_and_store_metadata`) | Add one SRV_DBG log line after the metadata-only copy loop |
| `tools/server/server-cache-hybrid.cpp` | 4814 (end of `tx_save`) | Add one SRV_DBG log line recording slot id, token count, total_size, and entries.size() |

## Invariant preservation

| Invariant | How preserved |
| --- | --- |
| I-25-01 atomicity | All changes inside the recursive mutex; no new thread or background operation |
| I-25-02 isolation | No change to lock acquisition order |
| I-25-03 durability-within-transaction | No change to commit/abort semantics |
| F-21-EXEC-01 prompt-only save | No change to `entry_tokens = slot.task->tokens.clone()` line |
| F-21-RERUN-01 descriptor tracking | No change to `attach_payload` flow |
| F-22-DR-01 demotion coordination | No change to demotion paths |
| D-EXEC-26-02 argv function-scope vector | No change to `tools/server/server.cpp` |
| Stage 26 cold-store per-id accounting | No change to `cold_payload_bytes_by_id_` map usage |

## Why minimal

The Stage 27 hard constraint is "ONE function modification (preferred)". The verification step (Step 1) requires ZERO code changes if Candidate A holds. Step 2 is a minimal try/catch wrapper plus telemetry. Step 3 is bounded observability. Total impact: 0-3 file edits, 0-15 lines of code change.

## Non-goals

- Do NOT change the SEH filter (D-EXEC-26-01).
- Do NOT change the cold-store accounting (Stage 26 fix).
- Do NOT rename metrics.
- Do NOT modify the runner or test plan.
- Do NOT touch Stage 26 docs.

## Handoff

Step 1 verification is mandatory and gates Step 2. If Step 1 passes, Stage 27 produces only Step 3 (telemetry). If Step 1 fails, Stage 27 produces Steps 2 + 3. Either way, the fix is bounded to `tools/server/server-cache-hybrid.cpp`.
