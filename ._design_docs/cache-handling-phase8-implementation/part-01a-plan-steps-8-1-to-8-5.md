# Stage 8 implementation plan - Part 1A

Source: [part-01-implementation-plan.md](part-01-implementation-plan.md)

## Step 8.1: payload eviction with metadata-only retention

Goal: add safe payload eviction to `branch_forest_index`. Payload eviction
clears payload descriptor references and marks the node metadata-only instead
of removing it. Slot refs block eviction. Protected roots keep metadata.

Affected files:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`

Focused tests:

- Evict an unreferenced node and verify `is_metadata_only`.
- Verify topology, tokens, namespace, and protection survive eviction.
- Verify slot refs block eviction.
- Verify paired target/draft payload flags clear together.

## Step 8.2: branch pruning with safety checks

Goal: add safe metadata pruning after payload eviction. Pruning removes only
metadata nodes that have no active refs, are not protected roots, and have no
retained descendants.

Affected files:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`

Focused tests:

- Prune an unprotected metadata-only leaf.
- Reject active refs, protected roots, and nodes with retained descendants.
- Verify metadata byte accounting decreases after prune.

## Step 8.3: equivalent-branch lookup and deduplication

Goal: find equivalent nodes by namespace, token path, token count,
position span, checksum span, pair state, and protection semantics. Payload
residency does not decide equivalence.

Affected files:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`

Focused tests:

- Equivalent nodes are found by token path.
- Payload-bearing nodes are preferred over metadata-only nodes for canonical
  selection.
- Cross-namespace equivalence is rejected.

## Step 8.4: deterministic branch lookup and mismatch-parent selection

Goal: rank candidates using the design tie-breakers: longest token match,
checksum confidence, payload-bearing before metadata-only, protected-root
ancestry, use sequence, insertion sequence, and node ID.

Affected files:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`

Focused tests:

- Ranking by token match length.
- Payload-bearing before metadata-only.
- Mismatch-parent selection with partial validation.

## Step 8.5: re-materialization planning and validation protocol

Goal: build a re-materialization plan from the nearest payload-bearing
ancestor to a selected metadata-only node. Validate retained token and
checksum spans against the request and record the deepest validated node.

Affected files:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`

Focused tests:

- Full-path validation succeeds.
- Token/checksum mismatch records the mismatched node.
- Missing payload-bearing ancestor falls back.
- Controller integration triggers planning when branch lookup selects a
  metadata-only node.
