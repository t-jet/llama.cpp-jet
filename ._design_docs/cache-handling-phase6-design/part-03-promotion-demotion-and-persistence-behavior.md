# Phase 6 design: cold layer and asynchronous I/O - Part 3: Promotion, demotion, and persistence behavior

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Demotion trigger

Demotion is triggered by the hot payload residency policy when the hot store is over the configured `--cache-ram` budget and colder candidates exist. The residency policy selects a demotable descriptor using the LRU ordering inherited from Stage 4.

A descriptor is eligible for demotion when all of these conditions are true:

- `residency_state == hot`
- The cold store is configured and accessible.
- The descriptor is not currently involved in an active restore transaction.
- A demotion for this `payload_id` is not already queued or in progress in the worker.

A descriptor that satisfies protection markers may still be nominated for demotion if the hot budget is exhausted and no unprotected candidates remain, consistent with the Stage 4 protected-root behavior. Demotion of a protected root must emit an explicit diagnostic.

## Demotion protocol

1. The controller selects a demotable descriptor using the residency policy.
2. The controller validates the pairing invariant: for `target_and_draft`, both target and draft bytes must be present and intact.
3. The controller transitions the descriptor to `demoting` (an internal transient state not visible outside the controller). This prevents concurrent restore attempts on the same descriptor while the cold write is in progress.
4. The controller enqueues a demotion task in `server_cache_io_worker` with the payload bytes and a descriptor snapshot.
5. The `server_context` thread returns to its normal work. It must not block on cold I/O.
6. The worker serializes the payload to a staging file in the cold store root using the cold file format defined in Part 2.
7. The worker renames the staging file to its final path atomically. The final path is derived from `payload_id` in a deterministic, path-safe encoding. Rename is the only operation that makes the file visible to future reads.
8. The worker calls the completion callback with a success result.
9. The controller sets `store_ref` to the `cold_ref` returned from the store, sets `residency_state = cold`, and releases the hot payload bytes from the hot store.

If the worker fails at any step before the atomic rename:

- The staging file is removed.
- The completion callback carries a failure result.
- The controller sets the descriptor to `residency_state = evicted` if the hot bytes have already been released, or reverts the descriptor to `residency_state = hot` if the hot bytes are still held.
- A diagnostic is emitted with the failure reason.

If the hot bytes are released before the cold write confirms, the implementation must detect the missing hot record on completion failure and mark the descriptor as `evicted`, not `hot`. This ordering constraint must be explicit in the implementation contract.

## Atomic write and rename

The cold file creation process uses a two-step write:

1. Write the complete file to a staging path in the cold store root. The staging path is temporary and not the final indexed path.
2. Rename the staging file to the final path.

The final path must not be used for reading until the rename completes. If the process crashes between write and rename, the staging file is orphaned and will not be indexed. Orphaned staging files may be cleaned up at startup or left for operator cleanup; the design does not require automatic staging cleanup, but the implementation must not treat orphaned staging files as valid cold payloads.

File naming for final paths is derived from `payload_id` with path-safe encoding (hex or base64url). No user-supplied or model-supplied input is used to construct file paths. The cold store root path comes from operator configuration only.

## Promotion trigger

Promotion is triggered when the controller selects a candidate for restore and the candidate descriptor has `residency_state == cold`. This typically happens during a restore miss: the lookup finds a descriptor with the correct token match, but the payload is not hot.

A descriptor is eligible for promotion when all of these conditions are true:

- `residency_state == cold`
- The cold store is configured and the `cold_ref` in `store_ref` is valid.
- A promotion for this `payload_id` is not already queued or in progress.

## Promotion protocol

1. The controller selects a cold descriptor as the restore candidate.
2. The controller transitions the descriptor to an internal `promoting` transient state.
3. The controller enqueues a promotion task in `server_cache_io_worker`.
4. The `server_context` thread may proceed to the fallback slower path for the current request. It does not block. The request that triggered promotion will not benefit from it in the same request turn unless the implementation provides an optional wait mechanism documented separately.
5. The worker opens the cold file identified by `cold_ref`.
6. The worker reads and validates the header checksum, magic, format version, checksum algorithm, and payload checksums.
7. The worker reads target and draft bytes.
8. The worker validates that the file's `payload_id`, `pair_state`, byte sizes, and checksums all match the in-memory descriptor snapshot it was given at enqueue time.
9. The worker places the promoted bytes into a completed-promotion record and calls the completion callback with a success result.
10. The controller receives the callback, inserts the promoted bytes into the hot store, updates `store_ref` to the new hot record, and sets `residency_state = hot`.
11. Future restore requests for this descriptor will find it hot and follow the Stage 5 restore protocol.

If the worker fails at any validation step:

- The completion callback carries a failure result and the validation failure reason.
- The controller sets `residency_state = evicted` and emits a diagnostic.
- The cold file may be retained for operator inspection or removed; the design requires emitting a diagnostic but leaves the file disposition to the implementation, provided that a failed promotion does not leave the descriptor in a state that would attempt the same failing validation again.

## Residency policy rules

The residency policy must follow these rules when deciding which payloads are eligible for demotion or promotion.

For demotion candidates:

- Select from hot descriptors in LRU order.
- Do not select a descriptor that is currently being used in an active restore or a pending demotion.
- Prefer unprotected roots over protected roots; emit a diagnostic if a protected root must be demoted.
- Demote target and draft sides as a unit: never demote one side of a `target_and_draft` descriptor.

For promotion candidates:

- A cold descriptor may be promoted on access when the hot store has room, or the controller may demote another hot payload to create room before promoting.
- Do not promote a descriptor with a `cold_ref` that fails initial accessibility checks.
- Promotion of one cold payload may require demotion of another hot payload to stay within `--cache-ram`. The controller must handle this sequencing without holding any lock that blocks `server_context` for the full I/O duration.

## Target/draft pair handling across cold transitions

Pairing invariants from Stage 5 apply without modification for cold transitions.

Demotion rules:

- `target_only` descriptors write one contiguous section of target bytes to the cold file.
- `target_and_draft` descriptors write target bytes followed by draft bytes in the same cold file, both checksummed separately.
- It is never correct to demote only the target side of a `target_and_draft` descriptor.

Promotion rules:

- On promotion of a `target_and_draft` descriptor, both target and draft bytes must pass validation before the descriptor moves to `hot`.
- A promotion failure on the draft side after target bytes have been read but not yet committed to the hot store must leave the descriptor in `cold` or `evicted` state, not partially hot.
- The restore applier from Stage 5 still applies the transactional restore contract: both sides must commit to the live slot together after promotion completes.

## Integrity validation on load

When the worker reads a cold file on promotion, it must perform the following checks in order before returning payload bytes to the controller:

1. Confirm the file begins with the expected magic bytes.
2. Confirm `format_version` is a supported value.
3. Validate `header_checksum` over all preceding header bytes.
4. Confirm `checksum_algorithm` is a known value.
5. Confirm `payload_id` matches the descriptor's `payload_id`.
6. Confirm `pair_state` matches the descriptor's `pair_state`.
7. Confirm `target_size_bytes` matches the descriptor's `target_size_bytes`.
8. Confirm `draft_size_bytes` matches the descriptor's `draft_size_bytes`.
9. Read exactly `target_size_bytes` bytes and validate against `target_checksum`.
10. For `target_and_draft`, read exactly `draft_size_bytes` bytes and validate against `draft_checksum`.

Any check failure is a hard failure. The worker must not return partial payload bytes. The controller must treat any promotion failure as a descriptor integrity loss and transition the descriptor to `evicted`.
