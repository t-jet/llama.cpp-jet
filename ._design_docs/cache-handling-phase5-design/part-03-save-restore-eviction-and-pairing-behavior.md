# Phase 5 design: payload-metadata separation and target/draft pairing - Part 3: Save, restore, eviction, and pairing behavior

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Save behavior

On exact-blob save in hybrid mode:

1. Serialize target state.
2. Serialize draft state when the active runtime has a draft context.
3. Build a descriptor from the serialized byte records.
4. Validate descriptor fields before adding the entry to cache indexes.
5. Reject the save if required target or draft bytes are missing.
6. Reject the save if the descriptor pair state does not match the runtime.
7. Reject the save if resident bytes exceed the configured hot payload budget, unless the budget is unlimited.
8. Admit the descriptor and payload bytes as one cache object.
9. Run the existing Stage 4 eviction policy if the cache is over budget.

Failed descriptor creation must leave the existing cache state unchanged. A failed refresh of an equivalent entry must not delete the previous valid descriptor until the replacement has passed validation.

## Restore behavior

On exact-blob restore in hybrid mode:

1. Select the candidate by existing Stage 3 and Stage 4 lookup rules.
2. Validate namespace and runtime compatibility.
3. Validate descriptor version, pair state, sizes, checksums, and hot residency.
4. Resolve hot payload bytes from `store_ref`.
5. Build a restore transaction for the selected descriptor.
6. Stage target bytes in restore scratch state.
7. Stage draft bytes in the same transaction when `pair_state` is `target_and_draft`.
8. Commit staged target and draft state to the live slot only after every required side has applied successfully.
9. Treat any target or draft restore failure as a failure of the whole restore.
10. Refresh usage and recency only after the transaction commits.

If any validation or restore step fails, the controller must leave the slot in a valid state and fall back to the slower path already used by hybrid cache misses. It must not apply draft bytes after target failure, and it must not report a hit when the full pair failed.

## Transactional restore contract

`target_and_draft` restore is one transaction. The live slot must not expose a restored target side unless the matching draft side has also restored and the transaction has committed.

Required pre-apply validation:

- descriptor ownership, version, payload kind, pair state, residency, byte sizes, and checksums pass before staging begins
- runtime target/draft shape matches the descriptor pair state
- hot payload bytes for every required side are present before staging begins
- the restore applier can provide either scratch staging or an equivalent pre-restore slot snapshot before any live mutation

Required apply behavior:

- The preferred path stages target and draft state outside the live slot, then commits both sides to the live slot in one controller operation.
- If the implementation cannot stage outside the live slot, it must snapshot the pre-restore live target and draft state before applying either side. A failed target or draft apply must restore that snapshot before fallback begins.
- A draft apply failure after target apply success must leave the live slot in the exact pre-restore state, not in a target-restored and draft-old state.
- A commit failure must also leave the live slot in the exact pre-restore state. If an implementation cannot guarantee that, it must use scratch staging instead of live apply plus rollback.
- A reset-to-empty slot is not an acceptable fallback unless that was the pre-restore slot state or a later design proves that the reset is the normal slower-path starting state for this request.
- A transaction that rolls back or restores a snapshot must not refresh recency, update usage, increment exact-hit metrics, or leave a candidate marked as successfully restored.

`target_only` restore uses the same transaction boundary with only the target side required. A target apply failure must leave the live slot in the pre-restore state and fall back without reporting a hit.

## Eviction behavior

Stage 5 eviction remains hot payload eviction for exact blobs. It does not branch-prune because no branch graph exists in this stage.

Eviction rules:

- The LRU policy selects entries using Stage 4 resident-byte and protection rules.
- The controller executes eviction by removing target and draft bytes together.
- A `target_and_draft` descriptor must never lose only one side.
- After eviction, the entry is no longer restorable from cache.
- If the implementation keeps the descriptor after byte removal for diagnostics, `residency_state` must become `evicted` and lookup must reject it as a restore candidate.
- Descriptor removal must update resident byte accounting exactly once.

Protected-root behavior does not change. Protection may delay eviction, but it cannot split target and draft state and cannot bypass budget accounting.

## Pairing enforcement

The pairing validator must enforce these invariants:

- `target_size_bytes > 0` for every descriptor.
- `target_only` descriptors have no draft bytes and no draft checksum.
- `target_and_draft` descriptors have draft bytes and a draft checksum.
- Runtime without a draft context accepts only `target_only`.
- Runtime with a draft context accepts only `target_and_draft`.
- Save, restore, eviction, and future offload operations use the same pair state.

Pairing failures are correctness failures, not cache misses caused by ordinary lookup. They must emit explicit diagnostics and then fall back safely.

## Future cold-layer compatibility

Stage 5 descriptors must leave room for Stage 6 cold storage:

- `store_ref` must be abstract enough to represent a hot in-memory handle now and a cold-store handle later.
- `residency_state` must reject `cold` in Stage 5 unless Stage 6 has been implemented.
- checksum and version fields must be usable before future cold promotion mutates live slot state.
- target/draft pairing rules must be identical for hot, cold, and evicted payload states.

No Stage 5 implementation should write payload bytes to disk or add cold-store CLI flags.
