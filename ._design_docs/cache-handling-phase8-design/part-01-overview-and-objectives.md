# Stage 8 design: metadata-only nodes and re-materialization -- Part 1: overview and objectives

Source: [../cache-handling-phase8-design.md](../cache-handling-phase8-design.md)

## Goal

Stage 8 makes the branch forest durable as metadata even when payload bytes are evicted. A branch node can stay in the graph as metadata-only when removing it would break descendant discovery, lookup, or traversal. If that node later becomes the selected restore or branching point, the controller validates the request tokens against the retained metadata and re-materializes the node from the nearest retained payload-bearing ancestor or from the root.

## Design objectives

- Treat payload eviction and branch pruning as separate lifecycle events.
- Preserve parent-child topology for retained descendants through metadata-only ancestors.
- Validate every metadata-only re-materialization before replay.
- Convert validation mismatch into prompt divergence, not unsafe cache reuse.
- Select mismatch parents with deterministic tie-breaking.
- Deduplicate equivalent branches when requests converge on the same validated prompt path.
- Clean up cold payloads only when no retained branch or descendant owns them.
- Enforce branch-metadata budget with pruning rules that do not break correctness.
- Expose metrics and diagnostics for all new lifecycle decisions.

## Stage 7 baseline carried forward

Stage 7 closed with a shared `BranchForestIndex`, strict namespace validation, per-node token spans, checksum spans, usage counters, slot references, protected-root behavior, and branch-metadata accounting. It also left these known limitations for later stages:

- `is_metadata_only` exists but remains false.
- Production metadata pressure does not prune or reparent nodes.
- Equivalent branch paths may duplicate.
- Re-materialization from a payload-bearing ancestor is not implemented.
- Cold cleanup triggered by branch pruning is not implemented.

Stage 8 addresses those limitations except checkpoint-first restore, which remains Stage 9 work.

## Definitions

| Term | Meaning |
| --- | --- |
| Payload eviction | Removes a node's hot or cold payload bytes and clears the owned descriptor reference. The branch node can remain in the graph. |
| Branch pruning | Removes a branch node and its metadata from the graph. This is allowed only after descendant reachability, active references, protection, ownership, and cleanup checks pass. |
| Metadata-only node | A retained branch node with no owned payload descriptor, kept because its metadata is still useful for lookup, ranking, traversal, or descendant reachability. |
| Payload-bearing ancestor | The nearest ancestor on the selected path that still owns a valid payload descriptor. |
| Re-materialization | Rebuilds a payload for the selected metadata-only node or equivalent restore point after validating the request tokens against retained branch metadata. |
| Mismatch parent | The deepest validated ancestor chosen as the parent for a new branch after validation finds prompt divergence. |
| Equivalent branch | A node in the same namespace with the same validated path identity as another candidate. |

## Requirement coverage summary

| Requirement group | Stage 8 intent |
| --- | --- |
| R36a-R36d, R123a | Reject mismatched re-materialization, choose mismatch parent deterministically, and log the decision. |
| R38a-R38c, R55a | Keep payload eviction separate from pruning and make cold cleanup ownership-safe. |
| R57a-R57e, R8b, R21a | Enforce hot payload, branch metadata, and cold storage budgets while preferring payload demotion before metadata pruning. |
| R71a-R71e, R76a, R79a-R79b | Preserve metadata-only topology and ensure newly materialized payloads belong to the correct branch. |
| R83a | Reuse an equivalent validated branch instead of creating a duplicate. |

## Exclusions

Stage 8 does not change how model checkpoints are chosen as canonical branch points. It can re-materialize exact full-state payloads for selected nodes and exact-restore equivalents, but checkpoint-first selection and checkpoint-specific restore ranking remain Stage 9 scope.
