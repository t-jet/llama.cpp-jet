# Phase 5 design: payload-metadata separation and target/draft pairing - Part 2: Interfaces, components, and data model

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Component boundaries

Phase 5 keeps the Stage 4 controller and policy split, then adds a descriptor boundary.

| Component | Responsibility |
| --- | --- |
| Hybrid cache controller | Owns cache entries, indexes, save/restore flow, policy calls, and descriptor ownership. |
| Payload descriptor registry | Stores descriptor records, validates descriptor invariants, and maps cache entries to payload records. |
| Hot payload store | Owns resident serialized payload bytes in RAM. Stage 5 has no cold store. |
| Pairing validator | Verifies target/draft presence rules for the active runtime and descriptor pair state. |
| Restore applier | Applies target and draft bytes to live contexts only after descriptor and payload validation succeed. |
| LRU policy | Receives resident byte and protection inputs. It does not inspect payload bytes or mutate descriptors. |
| Metrics and diagnostics | Reports descriptor validation failures, pairing failures, and payload eviction outcomes. |

The implementation may combine small classes where the code stays clear, but it must not collapse policy, serialization, storage, validation, and restore application into one opaque block.

## Interface contract

The controller should treat descriptor operations as explicit calls, even if the first implementation keeps the storage in the same source file.

Required operations:

- create descriptor from serialized target and optional draft bytes
- validate descriptor against runtime expectations
- resolve descriptor to hot payload bytes
- mark descriptor evicted when the owning payload bytes are removed
- remove descriptor when its owning exact-blob entry is deleted
- expose resident payload bytes to the eviction policy
- expose descriptor and pair status to diagnostics and tests

The policy sees only stable handles and accounting fields. It does not own the descriptor lifecycle.

## Data model

`PayloadDescriptor` is the metadata record for cache-managed payload bytes.

| Field | Meaning |
| --- | --- |
| `payload_id` | Stable internal ID unique within the hybrid cache controller. |
| `payload_kind` | `exact_blob` in Stage 5. `checkpoint` is reserved for a later stage. |
| `pair_state` | `target_only` or `target_and_draft`. |
| `format_version` | Descriptor schema version. Stage 5 starts at version 1. |
| `target_size_bytes` | Serialized target payload length. |
| `draft_size_bytes` | Serialized draft payload length, or zero for `target_only`. |
| `resident_payload_bytes` | `target_size_bytes + draft_size_bytes` while hot. |
| `target_checksum` | Integrity check for target bytes. |
| `draft_checksum` | Integrity check for draft bytes, empty for `target_only`. |
| `store_ref` | Internal hot-store reference in Stage 5. Future cold references must fit this field without changing descriptor ownership rules. |
| `residency_state` | `hot` or `evicted` in Stage 5. `cold` is reserved for Stage 6. |
| `owner_entry_id` | Cache entry that owns the descriptor. Ownership is singular. |
| `created_sequence` | Deterministic sequence useful for tests and diagnostics. |
| `last_validated_sequence` | Last successful validation sequence, if any. |

## Pair state

`pair_state` records what the payload is allowed to contain.

- `target_only`: target bytes must exist and draft bytes must not exist.
- `target_and_draft`: both target and draft bytes must exist, validate, and restore together.

The active runtime decides which pair state is legal. A target-plus-draft runtime must not restore a `target_only` descriptor unless a later approved design defines a safe downgrade path. Stage 5 has no such downgrade path.

## Ownership

Each descriptor belongs to exactly one cache entry in Stage 5. Later branch nodes inherit the same rule: one descriptor has one owner. Equivalent prompts may refresh or replace an entry, but they must not create shared mutable descriptor ownership.

If a cache entry is removed, its descriptor is removed with it. If payload bytes are evicted but the entry remains, the descriptor stays only long enough to report that the payload is no longer restorable from cache. Stage 8 may define longer-lived metadata-only branch behavior; Stage 5 does not.
