# Part 1: Root cause analysis - D-EXEC-24-03 heap corruption

Status: design approved; Manager gate closed per D-CLOSURE-27-01 2026-06-26
Date: 2026-06-26
Scope: map the 0xC0000374 crash signature to a specific code path; rank candidate root causes by likelihood and identify the verification steps needed to confirm.
Historical note: Candidate A (wasteful alloc+free in `admit_latest_checkpoint_and_store_metadata`) was applied in Stage 26 commit `4556965c7` and confirmed INSUFFICIENT by Stage 24 -05 rerun. The actual root cause was found in Stage 27 iter 4: enqueue-only demotion leak via `demote_payload` to the retired Stage 25 `io_worker` thread. See implementation log [part-10](../cache-handling-phase27-implementation/part-10-manager-closure-20260626.md) for the verified root cause and fix.

## Crash signature (binding)

| Field | Value |
| --- | --- |
| Exit code | 0xC0000374 (STATUS_HEAP_CORRUPTION) |
| Stage 24 rerun | `-03` (post D-EXEC-26-02 fix), `-01` (pre-fix) |
| Leg | S03-chat hybrid-stage24 |
| Last OK request | `s03-exact-0-0` (request 257), cache_n=15 |
| First failed | `s03-exact-0-1` (request 258), `request-error` |
| Cache state at death | 10 entries, 502.506 MiB payload / 502.508 MiB total / 637 tokens (within budget) |
| Last OK req state size | 52.315 MiB at cache_n=15 (3.49 MiB/token, unusually large) |
| server.err.log ends at | `srv params_from_: Chat format: peg-native` |
| SEH dump captured | none (filter installed but not invoked) |
| Cache hit rate at death | 5/257 = 1.95% (low; cold-promotion traffic high) |

Source: [test-report-20260626-03.md](../.test_reports/test-report-20260626-03.md) D-EXEC-24-03 reproduction status table.

## Crash anatomy

`STATUS_HEAP_CORRUPTION` is the Windows heap manager's detection signal. It fires when the heap detects metadata corruption (e.g., a free-list pointer overrun) during a subsequent allocation, free, or validation pass. The actual corruption-producing write happened EARLIER on a different code path or different allocation; the crash is detected LATER when the heap touches the corrupted metadata.

Implications for this signature:

- The crashing allocation site (the call site that detected the corruption) is NOT necessarily the code that produced the corruption.
- The earlier corruption-producing write may be silent and leave no diagnostic until the next heap operation on a related free list.
- The `server.err.log` ending mid-`Chat format: peg-native` means the corruption detector fired BEFORE the next request body was even parsed; the previous save path was the last mutating heap operation.
- The 52 MiB last-OK-req state size (3.49 MiB/token) is consistent with the MTP-fixture checkpoint payload shape; checkpoints on the MTP fixture carry ~50 MiB of `data_tgt`/`data_dft` each.

## Candidate root causes (priority order)

### Candidate A (highest likelihood): wasteful alloc+free in `admit_latest_checkpoint_and_store_metadata`

Location: `tools/server/server-cache-hybrid.cpp:3879-3895` (post-Stage-26 fix).

Pre-Stage-26 code path:

```cpp
entry.checkpoints = checkpoints;            // deep copy of list<common_prompt_checkpoint>
                                            // each checkpoint carries data_tgt + data_dft of ~50 MiB
                                            // source checkpoints ALREADY had data_tgt moved into hot_payloads
                                            // so this is a wasted allocation of ~50 MiB * N
for (auto & checkpoint : entry.checkpoints) {
    checkpoint.data_tgt.clear();            // immediate free of the wasted allocation
    checkpoint.data_dft.clear();
}
```

This allocates a full ~50 MiB buffer for every save (the destination `entry.checkpoints` list), then immediately clears it. Under sustained checkpoint admission on the MTP fixture, this generates ~50 MiB of heap pressure per save. With hybrid cache hit rate at 1.95% during the failing leg, the per-second allocation churn is high.

Stage 26 commit (4556965c7) replaced this pattern with a metadata-only copy:

```cpp
entry.checkpoints.clear();
for (const auto & src : checkpoints) {
    common_prompt_checkpoint meta_only;
    meta_only.n_tokens = src.n_tokens;
    meta_only.pos_min = src.pos_min;
    meta_only.pos_max = src.pos_max;
    // data_tgt and data_dft remain empty; the actual bytes are owned
    // by hot_payloads[checkpoint_payload_id].target/draft.
    entry.checkpoints.push_back(std::move(meta_only));
}
```

The Stage 26 fix avoids the wasted ~50 MiB allocation per save. The Stage 24 test reports that showed D-EXEC-24-03 reproducing were generated against binaries built BEFORE commit 4556965c7 (the binary mtime in report -03 is 2026-06-26 04:53:41; commit timestamp is 10:22:48). The fix has not yet been verified against the failure signature.

Evidence in favor of Candidate A:

1. The pre-fix code is the only place in `tx_save` that allocates ~50 MiB and immediately frees it.
2. The Stage 26 commit explicitly cites this exact pattern as the D-EXEC-24-03 fix in the source comment.
3. The `3.49 MiB/token` last-OK state size matches the MTP-fixture checkpoint data_tgt size exactly.
4. The crash is detected on the next heap operation after the save (consistent with heap metadata corruption that manifests on the subsequent allocation).

Evidence against:

1. The crash reproduces at request 258 deterministically; pure heap pressure should be probabilistic.
2. STATUS_HEAP_CORRUPTION usually requires a specific bad write (buffer overrun), not just alloc+free churn.

### Candidate B (medium likelihood): double-free in `attach_checkpoint_payload` rollback

Location: `tools/server/server-cache-hybrid.cpp:3754-3805`.

`attach_checkpoint_payload` calls `attach_payload` (which moves `target` and `draft` into `hot_payloads`), then on `validate_checkpoint_descriptor_metadata` failure, calls `remove_payload(new_checkpoint_payload_id)`. If `attach_payload` partially succeeds (descriptor inserted but hot_payload insert fails), then `remove_payload` may attempt to free partially-initialized storage.

Looking at `attach_payload` (line 3532):

```cpp
hot_payload_record record;
record.payload_id = next_payload_id++;
record.target = std::move(target);
record.draft = std::move(draft);
...
payload_descriptors[descriptor.payload_id] = descriptor;
hot_payloads[record.payload_id] = std::move(record);  // <- throws bad_alloc on insertion?
```

If `hot_payloads` insert throws `bad_alloc` (or any other exception) AFTER the descriptor is inserted, `remove_payload` will be called on a descriptor whose hot_payload record is missing. `remove_payload` (line 3303) checks `hot_payloads.find(payload_id) == hot_payloads.end()` and skips the erase, but it does NOT skip the descriptor erase — so the descriptor is erased without erasing its hot_payload. This is asymmetric but not a double-free.

Mitigation already in place: `attach_payload` is called inside the mutex and uses try/catch where needed; `remove_payload` is exception-safe.

Evidence against: no exception path identified that leads to double-free.

### Candidate C (lower likelihood): use-after-free in `entry_tokens.clone()` after `materialize_entry_payload`

Location: `tools/server/server-cache-hybrid.cpp:4714-4782` (tx_save re-materialization branch).

In the existing-equivalent-entry branch:

```cpp
server_tokens entry_tokens = slot.task->tokens.clone();  // L4714
...
auto existing = find_equivalent_entry(entry_tokens, namespace_id);  // L4719
...
if (existing != entries.end()) {
    if (!materialize_entry_payload(existing, std::move(target_payload), std::move(draft_payload), ...)) {
        ...
    }
    existing->checkpoints.clear();
    existing->metadata = metadata;
    if (!slot.prompt.checkpoints.empty()) {
        ...
        admit_latest_checkpoint_and_store_metadata(*existing, slot.prompt.checkpoints, ...);
    }
}
```

`materialize_entry_payload` modifies `*existing` (refreshes LRU, sync_branch_node, updates index). If `existing` becomes invalidated (e.g., list iterator invalidated by insertion in `admit_entry_with_payload`), the subsequent `existing->checkpoints.clear()` writes through a stale iterator.

Looking at `materialize_entry_payload` (line 2975): it does NOT insert into `entries`; it only modifies the existing entry in place and may call `evict_until_within_budget` (which also does not insert). Iterator invalidation is unlikely in this branch.

Evidence against: list iterators are not invalidated by in-place mutation; only by insertion/erasure at that iterator's position.

### Candidate D (low likelihood): integer truncation in payload size

Location: `tools/server/server-cache-hybrid.cpp:4669-4675` (tx_save state size query).

```cpp
const size_t state_size_tgt = ctx_tgt ? llama_state_seq_get_size_ext(ctx_tgt, slot.id, LLAMA_STATE_SEQ_FLAGS_NONE) : 0;
const size_t state_size_dft = (ctx_dft && slot.ctx_dft) ? llama_state_seq_get_size_ext(ctx_dft, slot.id, LLAMA_STATE_SEQ_FLAGS_NONE) : 0;
const size_t total_size = state_size_tgt + state_size_dft;
```

`size_t` is 64-bit on x64 Windows. No truncation possible at 50 MiB. `total_size` is also 64-bit. `limit_size` (hot budget) is 512 MiB. All arithmetic is 64-bit-safe.

Evidence against: no integer overflow path at this magnitude.

## Verification path for Candidate A

The Stage 27 implementation MUST verify Candidate A before committing to it as the root cause. The verification chain:

1. Build clean Release binary from commit 4556965c7 (the Stage 26 commit with the candidate fix).
2. Run Stage 24 rerun (`-05` suffix) against the new binary.
3. Observe S03-chat hybrid leg completes past request 258 without crash.
4. If crash still occurs: Candidate A is insufficient; deepen to Candidates B/C/D (next-priority root cause investigation).

The Stage 27 fix design (part-02) covers BOTH the verification step AND the additional fix path needed if Candidate A is insufficient.

## Handoff

Candidate A is the working hypothesis. Verification chain is bounded: one clean build + one Stage 24 rerun. If Candidate A fails, the next-priority candidate is B (rollback path exception safety). The design documents the verification path so the Developer does not need to re-derive it during implementation.
