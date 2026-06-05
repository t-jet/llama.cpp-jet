# Stage 9 design: checkpoint payload lifecycle and interfaces -- Part 2

Source: [../cache-handling-phase9-design.md](../cache-handling-phase9-design.md)

## Checkpoint as a branch-node payload

A checkpoint payload is a descriptor-owned payload on a branch node. It has the
same ownership, integrity, residency, and target/draft pairing rules as an
exact full-state blob. The branch node remains the canonical metadata object.

A node can be in one of these payload states:

| State | Meaning |
| --- | --- |
| Metadata-only | The node has no owned payload descriptor. It can still preserve topology and support lookup. |
| Exact-only | The node owns an exact full-state blob descriptor. |
| Checkpoint-only | The node owns a checkpoint descriptor. |
| Exact plus checkpoint | The node owns separate exact and checkpoint descriptors. Each descriptor has a different payload ID. |

Payload ownership remains singular. A checkpoint descriptor belongs to exactly
one branch node. A retained descendant that must restore independently needs
its own descriptor.

## Descriptor contract

Stage 9 extends the descriptor contract with checkpoint payloads but does not
change its integrity rules.

Required descriptor fields:

- payload ID
- payload kind: `exact_blob` or `checkpoint`
- pair state: `target_only` or `target_and_draft`
- format version
- byte size
- checksum or equivalent integrity value
- store reference for hot or cold residency
- namespace and compatibility fingerprint
- residency state

Checkpoint descriptors must also record enough restore metadata to verify that
the checkpoint is applicable to the selected branch node, such as token span,
position range, context mode, and boundary ID when admitted from a prepared
boundary.

## Admission lifecycle

Checkpoint admission happens after the runtime emits a checkpoint that the
cache controller can attach to a branch node.

Admission steps:

1. Confirm hybrid mode is active.
2. Resolve the task namespace and workload profile.
3. Identify the branch node that represents the checkpoint span.
4. Validate prepared-prompt boundary metadata when the checkpoint claims a
   boundary attachment.
5. Serialize target and draft state as the active pair state requires.
6. Create a versioned checkpoint descriptor with checksum and size accounting.
7. Attach the descriptor to the branch node only after serialization and
   descriptor validation have succeeded.
8. Update usage and residency policy state.

If admission fails before the descriptor is attached, the graph remains
unchanged. If a descriptor is attached and a later hot-store step fails, the
controller must remove the descriptor and emit an admission failure diagnostic.

## Replacement and coexistence

Exact blobs and checkpoint payloads can coexist on the same branch node. They
serve different restore strategies:

- exact blob: fastest exact restore when the full serialized state is valid
- checkpoint: canonical continuity point for checkpoint-dependent profiles

If a new checkpoint supersedes an older checkpoint for the same node, the
controller must validate ownership, detach the old descriptor, and schedule the
old payload for normal cleanup. It must not overwrite descriptor fields in
place after another subsystem can observe the descriptor.

## Payload eviction and metadata-only behavior

Evicting a checkpoint payload removes the descriptor and payload bytes from the
node. It does not prune the branch node by itself. The node may remain
metadata-only or may still own an exact blob descriptor.

If a checkpoint-dependent restore selects a metadata-only checkpoint node, the
planner follows the Stage 8 re-materialization rules:

1. find the nearest retained payload-bearing ancestor or root
2. validate the selected path segment against branch metadata
3. replay from the ancestor or root
4. materialize a new checkpoint payload for the selected node when policy
   admits it
5. on mismatch, create a new branch from the latest validated ancestor

The new payload belongs to the new or selected node according to the Stage 8
mismatch rules. It must never be written onto a mismatched metadata-only node.

## Interface ownership

`server_context` should not rank checkpoint candidates or inspect descriptor
formats directly. It should call the cache controller for:

- profile detection result
- restore plan selection
- checkpoint admission
- payload promotion requests
- post-decode checkpoint lifecycle updates

The cache controller owns:

- graph lookup and traversal
- descriptor admission and validation
- workload-profile ranking
- target/draft pair enforcement
- residency and metric updates

The serializer or restore applier remains the only component that turns a
descriptor into live target or draft state.
