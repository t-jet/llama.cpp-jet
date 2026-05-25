# Requirements for Alternate Hybrid Cache Mode in `llama-server` - Part 1: Status

Source: [../cache-handling-requirements.md](../cache-handling-requirements.md)

## Status

Draft.

## Purpose

This document defines implementation requirements for an alternate cache mode in `llama-server` aimed at branch-heavy and checkpoint-dependent workloads.

The intended end state is a hybrid cache architecture with these properties:

- full-state prompt-cache blobs remain available as exact-restore objects
- checkpoints become the canonical branch structure where rollback is limited
- both full-state blob payloads and checkpoint payloads can be kept hot in RAM or demoted to a cold layer based on usage
- lightweight branch metadata remains resident in RAM

The numbered requirements in this document define the target end-state architecture and behavior for the alternate cache mode. The Implementation Phases section describes an incremental path toward that end state and does not replace the overall acceptance criteria defined by the full set of requirements.

## Scope

This work includes:

- an explicit CLI-selected alternate cache mode
- non-destructive prompt-cache hits
- reuse-aware eviction and protected roots
- prepared-prompt boundary metadata for cache and checkpoint placement
- usage-based hot or cold residency for full-state blobs and checkpoint payloads
- checkpoint-first branch traversal for checkpoint-dependent models
- a shared branch graph or tree model for multi-slot reuse

This work does not include generated-output replay.

## Non-Goals

- Replacing the current cache implementation as the default behavior
- Changing default semantics for plain-transformer workloads when the alternate mode is disabled
- Implementing output memoization or replay of model-generated text
- Requiring multimodal parity in the first deliverable if correctness can be preserved by explicitly rejecting unsupported paths
- Providing cold-layer restore guarantees across server restarts
- Introducing a distributed cache service or cross-process cache coherence in the first implementation

## Current Constraints

The requirements below assume the current server architecture:

- the HTTP layer applies chat templates and tokenization before work reaches `server_context`
- `server_context` operates on flattened `server_tokens`
- the current prompt cache stores token sequences plus full serialized target and optional draft state blobs
- checkpoints are currently lineage-local and attached to `server_prompt`
- the server runs core scheduling logic inside a single-threaded `server_context`

## Definitions

- Full-state blob: the serialized target and optional draft state stored in a prompt-cache entry and sufficient for exact restore of that entry.
- Checkpoint payload: the serialized partial target and optional draft state stored in a checkpoint.
- Branch metadata: the lightweight in-RAM metadata used to locate, rank, and restore branches. This includes token or checksum spans, topology, position ranges, usage data, and residency information.
- Hot residency: payload bytes currently resident in RAM.
- Cold residency: payload bytes demoted from RAM and recoverable from the cold layer during the lifetime of the current server process.
- Branch-metadata budget: the configurable RAM limit for reusable branch metadata and related topology structures.
- Payload ownership: each payload descriptor belongs to exactly one branch node or equivalent interim reusable-branch entry. Descendants that remain independently restorable after ancestor pruning must own separate payload descriptors.
- Metadata-only branch node: a retained branch node that preserves topology, lookup, or traversal semantics even though it currently owns no payload descriptor.
- Payload eviction: removal of payload bytes from cache-managed storage so that the evicted payload is no longer restorable from cache without recomputation.
- Branch pruning: removal of reusable branch metadata or branch nodes from the shared graph or any equivalent interim reusable-branch structure when they are no longer retained for reuse.
- Checkpoint-dependent model: a model or context mode where useful reuse is constrained by rollback limits, SWA, RS limits, recurrent behavior, or equivalent context restrictions.

## Global Requirements

### Activation and Compatibility

- R1. The implementation must be gated by an explicit CLI flag that selects the alternate cache mode.
- R2. When that flag is not enabled, the current cache implementation must remain behaviorally unchanged.
- R3. The alternate mode must work as an opt-in path for both target-only and target-plus-draft setups.
- R4. When the alternate mode is disabled, the current prompt-cache save and restore behavior for exact hits must remain available and behaviorally unchanged.
- R4a. In the alternate mode, exact restore from full-state blobs must remain available as a supported restore path.

### Hybrid Model

- R5. The alternate mode must treat full-state blobs as an exact-restore tier rather than removing them from the design.
- R6. The alternate mode must treat checkpoints as the canonical branch structure for checkpoint-dependent models.
- R7. The alternate mode must support usage-based hot or cold residency for both full-state blobs and checkpoint payloads.
- R8. The alternate mode must keep branch metadata resident in RAM even when payload bytes are cold.
- R8a. Branch-pruning requirements apply to reusable branch metadata regardless of implementation form; in any interim structure the implementation must provide equivalent protection and observability semantics.
- R8b. The alternate mode must define a configurable branch-metadata budget for any phase that models reusable branch metadata explicitly.

### Target and Draft Coupling

- R9. All restore, offload, payload-eviction, and cold-layer operations must preserve target and draft coupling.
- R10. If a branch node has both target and draft payloads, the implementation must not allow only one side to be restored, payload-evicted, or demoted independently unless the model configuration explicitly has no draft side.

### Model-Family Awareness

- R11. The implementation must support plain-transformer workloads efficiently.
- R12. The implementation must support checkpoint-dependent workloads where the best branch points are checkpoints rather than arbitrary token offsets.
- R13. The implementation must preserve correct behavior for MTP-style target-plus-draft configurations.
- R14. The implementation must preserve correct fallback behavior when no suitable hot or cold cache object can be restored.

## Non-Functional Requirements

### Minimal-Intrusion Integration

- R107. The alternate cache mode must be implemented with minimal modifications to the current default cache path.
- R108. The implementation must prefer high-level switching gates, mode dispatch, or strategy-style integration points over widespread invasive patching of existing logic.
- R109. When the alternate mode is disabled, the current implementation path must remain structurally intact and easy to reason about.
- R110. New behavior should be introduced through well-defined extension points, wrappers, or new components where practical, rather than by scattering mode checks throughout unrelated code paths.
- R111. Refactoring of existing code is allowed only when it creates clearer extension boundaries, reduces duplication, or is required for correctness or testability.

### Code Structure

- R112. The implementation must keep policy, metadata management, payload storage, cold-layer logic, and branch-graph logic separated into coherent units with clear responsibilities.
- R113. The implementation should avoid combining cache policy decisions, serialization, storage residency management, and HTTP-layer boundary extraction into one monolithic component.
- R114. Public and internal interfaces introduced for the alternate mode must be explicit enough to support isolated testing of cache policy, residency policy, branch matching, and restore behavior.
- R115. Cross-layer responsibilities must remain consistent with the current architecture: prompt preparation belongs in the HTTP or prompt-preparation layer, while cache and restore decisions belong in `server_context` or dedicated cache components.

### Code Conventions and Maintainability

- R116. All new code must follow the existing repository coding style, naming style, logging style, and error-handling conventions used in the surrounding `llama-server` code.
- R117. The implementation must preserve current semantics and terminology where practical, especially around slot state, prompt cache, checkpoints, target and draft pairing, and task lifecycle.
- R118. The implementation should prefer incremental and reviewable changes over large-scale rewrites of existing files.
- R119. New abstractions must be documented close to their implementation or in companion design documentation so future maintainers can understand hot or cold residency, branch metadata, and restore behavior.
- R130. The implementation should follow common engineering best practices such as SOLID, KISS, DRY and YAGNI principles.
- R131. The implementation must avoid copy-pasted policy, serialization, residency, and restore logic unless duplication is clearly justified by correctness, isolation, or performance.

### Best Practices

- R120. The implementation must fail safe: correctness and recoverability must take priority over cache hit rate or memory savings.
- R121. The implementation must include explicit diagnostics for unsupported configurations, restore failures, residency mismatches, and integrity problems.
- R122. All persistent formats, handles, and descriptors introduced for the cold layer or branch graph must be versioned and designed for forward evolution.
- R123. The implementation should prefer deterministic behavior where feasible so that cache decisions and restore paths can be reproduced in tests and debugging sessions.
- R123a. Branch lookup, mismatch-parent selection, and equivalent-branch deduplication must use deterministic tie-breaking.
- R124. The implementation must avoid hidden coupling between unrelated features and should keep alternate-mode behavior discoverable through explicit configuration, logs, and metrics.
- R132. The implementation must include a security review against the relevant OWASP Top 10 risk categories for the introduced functionality, with emphasis on file handling, integrity validation, serialization or deserialization, unsafe configuration combinations, and any externally influenced inputs.
- R133. Security-sensitive areas such as cold-layer persistence, payload handles, integrity checks, and protection markers or policy inputs must be reviewed for abuse cases, invalid input handling, and privilege-boundary assumptions before the implementation is considered complete.

### Testability and Verification

- R125. The implementation must be structured so that cache policy, residency policy, branch matching, and restore selection can be tested independently from full end-to-end inference.
- R126. Time, usage updates, and residency decisions should be testable without depending exclusively on wall-clock timing or uncontrolled background activity.
- R127. Storage-facing code for hot or cold payload movement should be designed so that tests can substitute controlled backends or fixtures.
- R128. The implementation must support deterministic integration tests for mode gating, protected roots, cold offload, cold restore, and checkpoint-first restore behavior.
- R129. The implementation must avoid making correctness depend on behavior that is difficult to observe or assert in tests.

## Functional Requirements

### Non-Destructive Prompt-Cache Hits

- R15. A prompt-cache hit in the alternate mode must not consume and remove the entry by default.
- R16. A cache hit must update usage metadata for the matched branch object.
- R17. Exact restore from a prompt-cache blob must continue to restore full serialized target and optional draft state directly from the stored payload.

### Reuse-Aware Eviction

- R18. FIFO eviction must be replaced in the alternate mode by a reuse-aware policy.
- R19. The alternate mode must support LRU as a reuse-aware eviction policy.
- R20. The design must support pluggable eviction policies including LRU, segmented LRU, and 2Q without changing correctness guarantees or operator-facing behavior.
- R20a. The alternate mode must define an explicit CLI option for selecting the reuse-aware eviction policy so additional policies can be introduced without changing the operator interface.
- R20b. Policy-specific parameters for the selected eviction policy must be configurable through explicit server settings.
- R21. Eviction decisions must use resident-byte accounting.
- R21a. Branch-pruning decisions must use explicit accounting for branch-metadata RAM usage against the configured branch-metadata budget.
- R22. Usage tracking must support at least recency and cold or hot residency state.

### Protected Roots and Cache Markers

- R23. The alternate mode must provide a way to protect important branch roots from ordinary payload eviction or branch pruning.
- R24. Protection must be driven by trusted server policy and configured rules.
- R25. Protection must integrate with the reuse-aware eviction policy and any branch-pruning rules rather than bypassing byte accounting entirely.
- R26. The implementation must define behavior when a protected root exceeds memory budgets or branch-retention limits and must prefer explicit diagnostics over silent corruption.

### Prepared-Prompt Boundary Metadata

- R27. The server must gain a prepared-prompt boundary interface that operates after prompt preparation, not before it.
- R28. The boundary interface must return boundary information together with the prepared prompt.
- R29. The boundary interface must be able to represent boundaries for prompts produced from chat templates.
- R30. The boundary interface must be carried through tokenization into task-level metadata visible to `server_context`.
- R31. The implementation must not rely on heuristic rescanning of the final prompt string as the primary boundary source.
- R32. If no prepared-prompt boundary metadata exists, the alternate mode must fall back to token-based or position-based rules and emit explicit diagnostics that boundary-aware behavior is degraded.
- R33. For `/completion` requests, the alternate mode may operate with token-based or position-based fallback when prepared-prompt boundary metadata is unavailable. The implementation must emit explicit diagnostics that message-aware boundary behavior is unavailable for those requests.

### Correctness and Fallback

- R34. Any cache-restore failure in the alternate mode must fail safe and preserve inference correctness.
- R35. If an exact blob restore fails, the server must fall back to a valid slower path rather than leaving the slot in an inconsistent state.
- R36. If branch metadata is available but the referenced payload is unavailable or invalid, the implementation must surface diagnostics and use a safe fallback path.
- R36a. If supplied prompt tokens fail validation against the selected metadata-only branch path, the implementation must reject re-materialization of that path, emit explicit diagnostics, and treat the request as prompt divergence rather than as cache reuse of the mismatched node.
- R36b. After a validation mismatch, the implementation must create a new branch whose parent is the latest validated matched ancestor, or the root path if no branch metadata segment validates.
- R36c. When multiple candidate paths partially validate, mismatch-parent selection must use the candidate path selected by branch lookup and must choose the deepest validated ancestor on that path as the parent for new-branch creation.
- R36d. If more than one candidate path remains eligible after stepwise validation, the implementation must prefer the candidate with the longest validated prompt match and must resolve any remaining tie with a deterministic rule.

### Payload and Metadata Separation

- R37. The implementation must separate payload descriptors from payload bytes for both full-state blobs and checkpoints.
- R38. Branch metadata must remain usable even when referenced payload bytes are not resident in RAM.
- R38a. Payload demotion or payload eviction must not by itself require branch pruning while the branch metadata remains useful for locating, ranking, or reaching reusable descendants or other restorable payloads.
- R38b. When branch pruning removes reusable branch metadata, any cold-layer payloads or payload descriptors exclusively owned by the pruned branch and not separately owned by retained descendants must be deleted from the cold layer.
- R38c. If removing an internal branch node would break discovery, lookup, or traversal for retained descendants, the implementation must be able to retain that node as a metadata-only branch node even when its owned payload has been deleted.
- R39. Branch metadata must include enough information to locate, rank, and restore branches without eagerly loading cold payloads.
- R39a. When a metadata-only branch node must be re-materialized, the implementation must rebuild it from the nearest retained ancestor that still has a valid payload, or from the root if no ancestor retains a payload.
- R39b. Re-materialization of a metadata-only branch node must use the supplied prompt tokens for the selected path segment, and the implementation must verify that segment against branch metadata using span length, token-range checks, checksums, or equivalent validation before replay.
- R39c. Validation mismatch between supplied prompt tokens and the selected metadata-only branch path must not overwrite or silently repurpose that existing branch metadata; it must cause new-branch creation from the latest validated ancestor or from the root.
- R40. At minimum, branch metadata must support these fields where applicable:
- R41. token or checksum span metadata.
- R42. branch or parent-child linkage.
- R43. `n_tokens`.
- R44. `pos_min`.
- R45. `pos_max`.
- R46. usage data.
- R47. hot or cold residency state.
- R48. handles or descriptors for payload storage.

### Cold Layer

- R49. The alternate mode must support a cold layer for usage-based payload offload.
- R50. Both less-used full-state blobs and less-used checkpoint payloads must be eligible for cold offload.
- R51. Cold offload must be based on usage and budget signals, not only on insertion order.
- R52. The implementation must preserve target and draft pairing when offloading payloads to the cold layer.
- R53. The cold layer must preserve integrity for as long as the current server process claims the payload is restorable, and the implementation must not claim restore guarantees across server restart.
- R54. The cold layer format must be versionable.
- R55. The cold layer must provide explicit integrity failure handling.
- R55a. Cold-layer cleanup triggered by branch pruning must be safe against deleting payloads or payload descriptors owned by retained branches or retained descendants.
- R56. The design must specify whether disk access occurs synchronously inside `server_context` or via an asynchronous mechanism, and that behavior must be testable.

### Hot or Cold Residency Policy

- R57. The alternate mode must define a residency policy that can rank payloads for demotion and promotion.
- R57a. The alternate mode must define configurable budgets for hot payload RAM, branch-metadata RAM, and cold-layer storage usage.
- R57b. When configured limits are under pressure, the implementation must prefer payload demotion or cold-layer offload before branch pruning when doing so can satisfy the limits while preserving reusable branch structure.
- R57c. The pruning and eviction strategy must use the configured RAM-resident and disk-resident budgets together to balance hit rate and resource usage while preserving correctness.
- R57d. User should be able to define budgets separately or provide a single overall cache budget that the implementation can allocate between hot and cold layers based on heuristics and available resources.
- R57e. Budgets provided by the user should be checked at startup and application should fail with explicit diagnostics if the budgets are too low to be practical or if they exceed available resources.
- R58. The residency policy must work across both full-state blobs and checkpoints.
- R59. The residency policy must integrate with the reuse-aware eviction policy so that resident-byte budgeting and cold demotion are coherent.
- R60. The implementation must be able to pin or protect certain branch roots without making them permanently RAM-resident by default.

### Observability

- R61. The alternate mode must expose diagnostics or metrics for these events:
- R62. exact blob hits.
- R63. checkpoint-based restores.
- R64. payload promotions from cold to hot.
- R65. payload demotions from hot to cold.
- R66. payload evictions.
- R66a. branch pruning or node deletion.
- R67. protected-root decisions.
- R68. fallback restores and restore failures.

### Branch Graph

- R69. The alternate mode must use first-class branch nodes as the canonical branch structure rather than lineage-local checkpoint attachments.
- R70. A branch node must be able to represent at least one reusable restore point.
- R71. A branch node may reference a full-state blob, a checkpoint payload, or both.
- R71a. Each payload descriptor must belong to exactly one branch node. If a retained descendant must remain independently restorable after an ancestor is pruned, that descendant must reference its own separately owned payload descriptor.
- R71b. A retained branch node may exist without an owned payload descriptor when it is needed only as a metadata-only branch node to preserve valid topology, lookup, or traversal semantics.
- R71c. If a retained metadata-only branch node later becomes the selected branching or restore point and no retained descendant provides a valid match, the implementation must recompute and materialize a new payload for that node or an equivalent restore point.
- R71d. When several metadata-only ancestors exist in sequence, the implementation may recompute through them from the nearest retained payload-bearing ancestor or from the root, but it must materialize and store a new payload only for the selected node or equivalent restore point unless additional payloads are independently justified by policy.
- R71e. When validation mismatch causes prompt divergence, any newly materialized payload must belong to the new branch created from the latest validated ancestor or root, not to the mismatched metadata-only node.
- R72. The graph must support branch lookup through token spans, checksum spans, or both.
- R73. The graph must support branch traversal without requiring all payload bytes to be resident in RAM.

### Tree or Wood Model

- R74. The architecture must support an explicit shared branch graph or tree model rather than a flat list of prompts.
- R75. The graph must preserve shared roots rather than automatically treating shorter prefixes as obsolete when longer descendants exist.
- R76. The graph must support parent-child relationships between branch nodes.
- R76a. Parent-child topology must remain valid for retained descendants even when an intermediate ancestor is retained only as a metadata-only branch node.
- R77. The graph must support shared roots reused by multiple slots.
- R78. The graph must support usage tracking at the node level.
- R79. The graph must support node protection or pinning for selected roots.
- R79a. The architecture must distinguish payload eviction from branch pruning or node deletion rather than treating them as the same lifecycle event.
- R79b. Branch pruning rules must consider descendant reachability, protection state, and remaining reuse value rather than treating payload eviction as automatic branch deletion.

