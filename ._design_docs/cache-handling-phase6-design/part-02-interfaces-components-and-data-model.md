# Phase 6 design: cold layer and asynchronous I/O - Part 2: Interfaces, components, and data model

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Component boundaries

Stage 6 adds two new components to the Stage 5 boundary set.

| Component | Responsibility |
| --- | --- |
| Hybrid cache controller | Owns cache entries, indexes, save/restore flow, policy calls, and descriptor lifecycle. Unchanged from Stage 5 in responsibility, extended to initiate demotion and promotion. |
| Payload descriptor registry | Stores descriptor records, validates descriptor invariants, manages residency state transitions. Extended in Stage 6 to accept the `cold` residency state. |
| Hot payload store | Owns resident serialized payload bytes in RAM. Unchanged from Stage 5. |
| Cold payload store (`server_cache_store_cold`) | Owns versioned filesystem files for demoted payloads. Reads, writes, validates, and removes cold files. Disabled unless a root path is configured. |
| Async I/O worker (`server_cache_io_worker`) | Background thread that executes demotion writes and promotion reads on behalf of the controller. Does not own descriptors. Reports completion or failure through a notification channel. |
| Residency policy | Decides which hot payloads are candidates for demotion, and which cold payloads should be promoted on access. In Stage 6 the policy is the existing Stage 4 LRU policy extended with cold residency awareness. |
| Pairing validator | Unchanged from Stage 5. Applied before any cold transition to confirm that both target and draft sides will move together. |
| Restore applier | Unchanged from Stage 5. Applied only after a promoted payload passes validation and the descriptor is confirmed hot. |
| Metrics and diagnostics | Extended with promotion and demotion counters and cold restore latency. |

The controller must not combine cold-file I/O, descriptor lifecycle, and restore application into one code path. `server_cache_store_cold` handles only file operations. The controller coordinates between the descriptor registry, the store, and the worker.

## `server_cache_store_cold` interface

Required operations:

- `configure(root_path, format_version)` — validate and open the cold store root; fail at startup if the path is unusable
- `write(payload_id, target_bytes, draft_bytes, descriptor_snapshot) -> cold_ref` — write a cold file for the given payload and return a cold file reference
- `read(cold_ref) -> (target_bytes, draft_bytes, descriptor_snapshot)` — read and validate a cold file; return failure if checksum, version, or size does not match
- `remove(cold_ref)` — delete a cold file; called when the owning descriptor is deleted or the cold layer is cleared
- `is_configured() -> bool` — return true only when a valid root path is set
- `cold_ref_for(payload_id) -> cold_ref` — resolve an active cold file reference for a given payload id

Cold file references (`cold_ref`) are opaque handles internal to `server_cache_store_cold`. The descriptor stores a `cold_ref` in `store_ref` after demotion. The controller must not construct or inspect file paths directly.

## `server_cache_io_worker` interface

Required operations:

- `start()` — start the worker thread and the work queue
- `stop()` — drain pending work, signal the thread to exit, and join
- `enqueue_demotion(payload_id, completion_callback)` — add a demotion task to the work queue
- `enqueue_promotion(payload_id, completion_callback)` — add a promotion task to the work queue

Completion callbacks carry a success flag and, on failure, a failure reason. The controller dispatches the callback from a thread-safe context. The callback must not call back into the I/O worker.

The worker queue is bounded. If the queue is full when the controller tries to enqueue, the controller must treat the enqueue as a failure and fall back rather than blocking the `server_context` thread.

## Cold store descriptor format

Each cold file stores a self-describing header followed by the payload bytes.

| Field | Position | Meaning |
| --- | --- | --- |
| `magic` | header bytes 0-3 | Fixed four-byte marker. Identifies the file as a cold cache payload. Rejects unrelated files. |
| `format_version` | header byte 4 | Schema version. Stage 6 starts at version 1. Any file with an unrecognized version is rejected. |
| `checksum_algorithm` | header byte 5 | Identifier for the checksum algorithm in use. Stored so future algorithm changes do not silently validate old files. |
| `payload_id` | header bytes 6-13 | Stable payload ID matching the in-memory descriptor. Used to confirm the file belongs to the expected descriptor after read. |
| `pair_state` | header byte 14 | `target_only` or `target_and_draft`. Must match the descriptor pair state on read. |
| `target_size_bytes` | header bytes 15-22 | Serialized target payload length in bytes. |
| `draft_size_bytes` | header bytes 23-30 | Serialized draft payload length in bytes, or zero for `target_only`. |
| `target_checksum` | header bytes 31-46 | Checksum of target payload bytes. Algorithm chosen per `checksum_algorithm`. |
| `draft_checksum` | header bytes 47-62 | Checksum of draft payload bytes. Zero-filled for `target_only`. |
| `header_checksum` | header bytes 63-78 | Checksum of all preceding header bytes. Protects against partial header writes. |
| `payload_bytes` | after header | Target bytes followed immediately by draft bytes (in that order). No padding between them. |

Header size is fixed for a given format version. A future format version may extend the header, but the `magic`, `format_version`, and `header_checksum` fields remain at fixed positions so readers can detect an incompatible header before attempting to parse it.

## Residency state transitions

`PayloadDescriptor.residency_state` has three values in Stage 6.

| State | Meaning |
| --- | --- |
| `hot` | Payload bytes are resident in the hot payload store. `store_ref` points to a hot payload record. |
| `cold` | Payload bytes have been written to the cold store. `store_ref` holds a `cold_ref` pointing to the cold file. The hot record has been released. |
| `evicted` | Payload bytes are gone. No cold file exists. The descriptor may be retained for diagnostics but must not be selected as a restore candidate. |

Valid transitions:

- `hot` -> `cold`: demotion by the residency policy. Requires a successful cold write before the hot record is released.
- `cold` -> `hot`: promotion on restore request. Requires a successful cold read and validation before the descriptor moves to `hot` and the cold file is optionally retained or removed.
- `hot` -> `evicted`: hot eviction when cold store is not configured or demotion fails and the policy decides to discard.
- `cold` -> `evicted`: cold file deleted by explicit cleanup, budget enforcement on cold storage, or branch pruning in a later stage.

No transition is allowed from `evicted` back to `hot` or `cold` within the same descriptor lifetime. An evicted descriptor is a dead record.

## Configuration

Cold store configuration is added only when the cold layer is implemented. It must not change the upstream CLI surface until that implementation exists.

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| `--cache-cold-path PATH` | string | none | Root directory for cold store files. If not set, cold storage is disabled entirely. The path must exist and be writable at startup. |

No separate cold payload budget is defined in Stage 6. The operator manages cold store size through filesystem quota or by monitoring cold file accumulation. If implementation evidence later shows that operators need a configurable cold-layer byte limit, a `--cache-cold-budget BYTES` option may be added in a later revision. Stage 6 does not add it.

`--cache-ram` remains the hot payload budget as established in Stage 4. It is not extended or changed by Stage 6.

## Relationship to Stage 5 `PayloadDescriptor`

Stage 6 does not change the `PayloadDescriptor` schema if `store_ref` and `residency_state` can already represent cold references and the `cold` state. If the Stage 5 implementation used a concrete hot-RAM pointer type for `store_ref` that cannot hold a cold file reference without a schema change, the descriptor format version must be incremented and the new `store_ref` type must be documented.

Cold store descriptor format fields (`payload_id`, `pair_state`, `target_size_bytes`, `draft_size_bytes`, `target_checksum`, `draft_checksum`) are derived from the in-memory `PayloadDescriptor` at demotion time. They serve as the on-disk snapshot of the descriptor's integrity state. On promotion, the cold file fields are validated against the in-memory descriptor before payload bytes are loaded into the hot store.
