# Stage 8 design: metadata-only nodes and re-materialization -- Part 3: re-materialization and mismatch handling

Source: [../cache-handling-phase8-design.md](../cache-handling-phase8-design.md)

## Re-materialization trigger

The controller starts re-materialization when branch lookup selects a metadata-only node as the restore or branching point and no better payload-bearing equivalent node is available in the same namespace.

Before planning, the controller must validate namespace compatibility, target/draft pairing expectations, and descriptor availability for the nearest payload-bearing ancestor. If compatibility fails, the request falls back without replay.

## Planning interface

Stage 8 adds a planning result that is separate from immediate restore:

```cpp
struct rematerialization_plan {
    uint64_t selected_node_id;
    uint64_t source_payload_node_id;   // 0 means replay from root
    uint64_t materialize_node_id;      // selected node or equivalent target
    std::vector<uint64_t> path_node_ids;
    size_t validated_tokens;
    bool requires_new_branch;
    uint64_t new_branch_parent_id;
    cache_fallback_reason fallback_reason;
};
```

The exact names can change, but the implementation must keep these decisions visible to tests and diagnostics.

## Validation protocol

Validation uses the supplied prompt tokens for the selected path segment. It must not trust retained metadata alone.

1. Build the path from the nearest payload-bearing ancestor, or from root, to the selected metadata-only node.
2. For each path segment, compare expected span length and token range against the request tokens.
3. Validate checksum spans when present. Token comparison remains the final authority when checksum and token data disagree.
4. Stop at the first mismatch.
5. If every segment validates, replay from the source payload or root and materialize a new payload for the selected node or equivalent restore point.
6. Do not materialize intermediate metadata-only ancestors unless the residency policy independently chooses that action after the selected node is handled.

The validation result must record the deepest validated node, the mismatched node when present, the number of validated tokens, and the validation method.

## Successful re-materialization

On success:

- The new payload descriptor belongs only to the selected node or equivalent node.
- If the selected node was metadata-only, `is_metadata_only` becomes false only after the payload save succeeds.
- Target and draft payloads are materialized atomically when draft state exists.
- Usage metadata updates for the selected node and source payload-bearing ancestor.
- The controller emits `cache_node_rematerializations_total` and bytes materialized.
- If materialization fails, the node remains metadata-only and the request falls back to valid slower processing.

The controller must not modify live slot state until the selected plan is validated and any required payload promotion is complete.

## Validation mismatch handling

A mismatch means the request diverges from the selected metadata-only path. It is not a cache hit.

On mismatch:

1. Reject re-materialization for the mismatched metadata-only node.
2. Emit diagnostics with namespace, selected node, mismatched node, deepest validated ancestor, and validation method.
3. Choose the mismatch parent from the selected candidate path.
4. Create or find a new branch whose parent is the deepest validated ancestor. If no segment validates, use the namespace root.
5. Any newly materialized payload belongs to the new branch, not to the mismatched metadata-only node.
6. Leave the mismatched metadata-only node unchanged.

## Deterministic branch lookup and mismatch-parent selection

Branch lookup may return more than one candidate. The controller must rank candidates deterministically before validation:

1. Same namespace only.
2. Longest token match.
3. Highest checksum confidence for the same token length.
4. Payload-bearing candidate before metadata-only candidate when both represent the same path.
5. Higher protected-root ancestry score.
6. Newer `use_sequence`.
7. Lower `insertion_sequence`.
8. Lower `node_id`.

Mismatch-parent selection uses the candidate selected by that ranking. If validation leaves several candidates eligible, choose the one with the longest validated prompt match, then apply the same deterministic tie-breakers. This satisfies R36c, R36d, and R123a without depending on unordered-map iteration.

## Fallback behavior

The request must use a valid slower path when:

- no payload-bearing ancestor exists and replay from root cannot be planned
- namespace validation fails
- target/draft pair validation fails
- token or checksum validation mismatches
- materialization save fails
- cold promotion for the source payload fails

Every fallback records a reason. No fallback may partially update a branch node, descriptor ownership, or live slot state.
