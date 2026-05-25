# Cache Requirements QA - Part 1: Q1. What counts as satisfying this document?

Source: [../cache-requirements-qa.md](../cache-requirements-qa.md)

## Q1. What counts as satisfying this document?

Affected requirements: Scope, R84-R85, Minimum Deliverable Boundary.

Answer: Open. The draft mixes end-state architecture requirements with minimum deliverable requirements, so it is not yet clear whether document satisfaction means the first shippable milestone or the eventual full architecture.

Why this is open:

- The Scope section says the work includes checkpoint-first traversal and a shared multi-slot branch graph.
- Phase 3 turns those ideas into hard architectural requirements.
- The Minimum Deliverable Boundary requires only a long-term architectural path to shared branch nodes and does not require shipping checkpoint-first traversal.

Options to resolve in the requirements document:

1. Split end-state requirements from minimum deliverable requirements explicitly. Add language near Purpose or Scope saying the document defines both the final architecture and a smaller required first milestone, then rename the minimum section to make that distinction explicit.
2. Narrow Scope to the first deliverable. Remove checkpoint-first traversal and shared graph reuse from Scope, and move them into a future-architecture or later-phase scope statement.
3. Raise the Minimum Deliverable Boundary. Add checkpoint-first traversal for checkpoint-dependent models and shared branch graph or tree support to the minimum deliverable list.

## A1. What counts as satisfying this document?

Requirements cover the final architecture and a way to get there, and document should clearly state that acceptance criteria is the final architecture, not the minimum deliverable. The minimum deliverable is a stepping stone, not the end goal. The document should be modified to clearly state that the requirements define the final architecture, and separate proposed implementation steps from the requirements itself.

## Q2. What is the alternate-mode contract for `/completion` when prepared boundaries are unavailable?

Affected requirements: R27-R33.

Answer: Open. The document does not clearly choose between full support, degraded support, or explicit rejection for `/completion` requests in alternate mode.

Why this is open:

- R27-R31 make prepared-prompt boundary metadata the primary mechanism.
- R32 allows token-based or position-based fallback when metadata does not exist.
- R33 only requires an equivalent boundary path for `/completion` if the alternate mode "wants" equivalent boundaries there.

Options to resolve in the requirements document:

1. Make `/completion` fully supported. Rewrite R33 to require an equivalent prepared-prompt boundary path for `/completion` in alternate mode, and keep R32 only as a failure fallback when metadata extraction unexpectedly fails.
2. Make `/completion` supported with reduced semantics. State that `/completion` may run in alternate mode with token-based or position-based fallback only, and require explicit diagnostics that message-aware boundary behavior is unavailable.
3. Exclude `/completion` from boundary-aware behavior for now. Add a non-goal or explicit unsupported-path requirement stating that alternate mode rejects `/completion` requests that need prepared boundary semantics until a dedicated wrapper exists.

## A2. What is the alternate-mode contract for `/completion` when prepared boundaries are unavailable?

Choose the Option 2. The alternate mode should support `/completion` with degraded semantics when prepared boundary metadata is unavailable, and the implementation must emit explicit diagnostics to indicate that message-aware boundary behavior is not available for those requests. This approach allows the alternate mode to be used in a wider range of scenarios while still providing clear feedback to users about the limitations of the current implementation.

## Q3. What does R4 require the implementation to preserve?

Affected requirements: R4, R5, R17.

Answer: Open. R4 can be read either as a behavioral requirement to preserve exact restore capability or as a structural requirement to preserve the current exact-hit code path itself.

Why this is open:

- The rest of the document treats full-state blobs as one tier inside a new hybrid design.
- The phrase "must not break the current prompt-cache save and restore path" can describe behavior, implementation structure, or both.
- That ambiguity affects how much refactoring is allowed around exact blob restore.

Options to resolve in the requirements document:

1. Clarify R4 as a behavior-only requirement. Rewrite it to say the implementation must preserve exact-restore capability for full-state blobs and exact hits.
2. Clarify R4 as a legacy-path preservation requirement. Rewrite it to say the current save and restore path must remain available and behaviorally unchanged when the alternate mode is disabled.
3. Split R4 into two requirements. One requirement should preserve legacy-mode behavior when the alternate mode is off, and the other should preserve exact-blob restore semantics inside the alternate mode.

## A3. What does R4 require the implementation to preserve?

Choose the Option 3. Split R4 into two requirements: one that preserves legacy-mode behavior when the alternate mode is disabled, and another that preserves exact-blob restore semantics inside the alternate mode. This approach provides clear guidance for both maintaining existing functionality and ensuring that the new architecture continues to support the critical capability of exact-blob restoration.

## Q4. What persistence lifetime does the cold layer guarantee?

Affected requirements: R8, R38, R49-R56.

Answer: Open. The document requires a versioned and integrity-checked cold layer, but it does not say whether cold payloads are process-local spill files or restart-persistent cache artifacts.

Why this is open:

- R53 requires integrity for as long as the implementation claims a payload is restorable.
- R54-R56 define format, integrity handling, and I/O model, but not restart semantics.
- Branch metadata stays in RAM, so restart behavior, metadata reconstruction, and orphan cleanup are still unspecified.

Options to resolve in the requirements document:

1. Define the cold layer as process-local only. State that cold payloads are valid only for the lifetime of the current server process and that no restart restore guarantee exists.
2. Define the cold layer as restart-persistent. Add requirements for startup scanning, metadata reconstruction or descriptor recovery, orphan cleanup, and compatibility validation across restart.
3. Support both modes explicitly. Add a configured persistence mode such as ephemeral or persistent and define restore, cleanup, and validation requirements for each mode.

## A4. What persistence lifetime does the cold layer guarantee?

Choose the Option 1. Define the cold layer as process-local only, stating that cold payloads are valid only for the lifetime of the current server process and that no restart restore guarantee exists. This approach simplifies the implementation and avoids the complexities associated with managing persistent cache artifacts across server restarts, while still providing a clear contract for the expected behavior of the cold layer.

## Q5. Who is allowed to mark a branch root as protected?

Affected requirements: R23-R26, R132-R133.

Answer: Open. The draft allows request metadata, server policy, or both, but it does not define trust, precedence, or abuse controls for protection requests.

Why this is open:

- R24 allows protection to be driven by explicit request metadata.
- R26 defines over-budget behavior but not who has authority to request protection.
- The security review requirements imply that request-driven cache markers need a clear trust model.

Options to resolve in the requirements document:

1. Make protection server-owned only. Rewrite R24 so that protection decisions come only from trusted server policy and configured rules.
2. Treat request metadata as a hint only. Keep request metadata in R24, but add requirements that server policy may accept, downgrade, ignore, or cap request-driven protection and must emit diagnostics for the decision.
3. Allow privileged request control. Keep request-driven protection, but require authenticated or otherwise authorized callers, explicit quotas or limits, and abuse-oriented logging or metrics.

## A5. Who is allowed to mark a branch root as protected?

Choose the Option 1. Make protection server-owned only by rewriting R24 so that protection decisions come only from trusted server policy and configured rules. This approach centralizes control over protected branch roots, reducing the risk of abuse or misconfiguration by clients, and allows the server to enforce consistent policies based on its understanding of workload patterns and resource constraints.

## Q6. What must remain stable when eviction policy evolves beyond LRU?

Affected requirements: R19-R22.

Answer: Open. The document says the policy may evolve from LRU to SLRU or 2Q without changing public semantics, but it does not define which semantics are actually stable.

Why this is open:

- Different policies will change hit rates, demotion timing, and eviction order.
- Without a narrower contract, "public semantics" is too broad to test or review consistently.
- The stable contract is likely correctness and operator-facing behavior, not identical cache decisions.

Options to resolve in the requirements document:

1. Narrow the stable contract. Replace "without changing public semantics" with language such as "without changing external API behavior or correctness guarantees."
2. Define explicit policy invariants. List the invariants that must hold across future policies, such as non-destructive hits, resident-byte accounting, protected-root integration, paired target or draft handling, and fail-safe fallback.
3. Make policy choice explicit. Add a named policy selector and state that semantics are stable within a selected policy mode, while different policies may legitimately change hit rate and residency behavior.

## A6. What must remain stable when eviction policy evolves beyond LRU?

Modify requirement to mention that exact option to choose eviction policy should be provided as a CLI option and parameters for that policy should be configurable. This way, the implementation can evolve to support different eviction policies while still providing a clear and consistent interface for users to select and configure the desired policy. Additionally, the requirement should specify that the implementation must maintain correctness guarantees and operator-facing behavior regardless of the chosen eviction policy, ensuring that changes in policy do not negatively impact the overall functionality or reliability of the cache system.

## Q7. When may branch metadata itself be evicted or deleted?

Affected requirements: R8, R38, R61-R66, R74-R83.

Answer: Open. The document keeps branch metadata resident in RAM for hot or cold payload separation, but it still refers to eviction of metadata without defining whether that means branch deletion, garbage collection, or budget-driven pruning.

Why this is open:

- R8 says branch metadata must remain resident in RAM even when payload bytes are cold.
- R38 says branch metadata must remain usable even when payload bytes are not resident in RAM.
- R66 requires observability for eviction of metadata or payloads.
- No requirement defines when metadata may be removed from the branch graph, what preconditions apply, or how protection interacts with metadata removal.

Options to resolve in the requirements document:

1. Forbid standalone metadata eviction for reusable branch nodes. Rewrite R66 to refer to payload eviction or demotion and explicit branch-node deletion only when a branch is removed from the shared graph.
2. Define metadata eviction as branch deletion with explicit preconditions. Add requirements that say when nodes may be removed, how protected roots constrain removal, and what diagnostics must be emitted.
3. Separate terminology for payload movement and branch removal. Reserve eviction for payload bytes, use branch pruning or node deletion for metadata removal, and update the observability and policy requirements accordingly.

## A7. When may branch metadata itself be evicted or deleted?

Choose the Option 3. Separate terminology for payload movement and branch removal. Reserve eviction for payload bytes, use branch pruning or node deletion for metadata removal, and update the observability and policy requirements accordingly. Because branches aren't usable without their payloads, it makes sense to treat eviction as a payload-level event and use distinct terminology for branch-level events. This approach clarifies the different types of cache management actions and allows for more precise requirements around when and how branches can be removed from the shared graph, while still maintaining clear observability and policy controls for both payload eviction and branch pruning.
Theoretically it's possible that branches frequently reused not from the first checpoint, but always go to, for example, third chekpoint, and if the second checkpoint is evicted, then the branch metadata may still be useful, but the payload is not resident. In that case, the branch metadata should not be evicted until it's no longer reusable, even if its payload is evicted. This further supports the idea of separating terminology for payload eviction and branch pruning to ensure clear communication about the different types of cache management actions.

## Q8. When do branch-pruning requirements become mandatory?

Affected requirements: R23-R26, R38a, R66a, R79a-R79b, Minimum Deliverable Milestone.

Answer: Open. The document now references branch pruning in earlier-phase requirements, but it does not state whether pruning behavior is required only once the shared branch graph exists or whether an interim structure must implement equivalent pruning semantics earlier.

Why this is open:

- R23-R26 mention protection from branch pruning in the near-term section.
- R38a and R66a make pruning observable before the long-term graph is fully required.
- R79a-R79b define pruning semantics as part of the shared graph architecture in the long-term section.
- The minimum deliverable milestone does not require first-class shared branch nodes yet.

Options to resolve in the requirements document:

1. Make branch-pruning requirements apply only once the shared branch graph exists. Qualify the earlier pruning requirements so they become active only in the long-term architecture.
2. Define an early equivalent pruning model. State that before first-class shared nodes exist, branch pruning refers to deletion of reusable branch metadata in whatever interim structure the implementation uses, with equivalent protection and observability semantics.
3. Add a general applicability rule. State that pruning requirements apply whenever the implementation models reusable branch metadata explicitly, regardless of phase; otherwise only payload-eviction requirements apply.

## A8. When do branch-pruning requirements become mandatory?

Choose the Option 2. Branch pruning required on all stages because it prevents overflow of the cache memory.

## Q9. What budget model governs branch-metadata retention and pruning?

Affected requirements: R8, R8a, R21, R26, R38a, R93.

Answer: Open. The document now requires branch pruning in all stages that model reusable branch metadata, but it still does not define what budget, limit, or accounting model triggers pruning of metadata that stays resident in RAM.

Why this is open:

- R8 keeps branch metadata resident in RAM.
- R8a makes branch-pruning requirements apply in every phase that models reusable branch metadata.
- R21 requires resident-byte accounting for eviction decisions, but that language is centered on eviction rather than metadata pruning.
- R26 mentions branch-retention limits without defining what those limits are.
- R93 defines budget controls for RAM residency and cold-layer usage, but not explicit budget controls for branch metadata or shared-graph size.

Options to resolve in the requirements document:

1. Add an explicit branch-metadata budget. Require configurable limits for metadata RAM usage and define pruning behavior when that budget is exceeded.
2. Define pruning through structural limits. Require limits such as node count, branch count, or graph size, and specify how pruning is triggered when those limits are exceeded.
3. Tie pruning to a unified RAM budget with separate accounting. Require the implementation to account for metadata RAM separately from payload RAM within an overall cache budget and define pruning and demotion behavior accordingly.

## A9. What budget model governs branch-metadata retention and pruning?

Choose the Option 1. Add an explicit branch-metadata budget by requiring configurable limits for metadata RAM usage and defining pruning behavior when that budget is exceeded. This approach provides a clear and direct mechanism for controlling the amount of RAM used for branch metadata, allowing operators to set appropriate limits based on their specific workload and resource constraints. Additionally, it enables the implementation to trigger pruning of branch metadata in a predictable manner when the defined budget is exceeded, helping to maintain overall cache performance and stability.
Budget model should take into account eviction to the cold layer first before pruning branch metadata, because eviction to the cold layer is a less destructive operation than pruning branch metadata, which can lead to loss of reusable branches and reduced cache efficiency. By prioritizing eviction to the cold layer, the implementation can preserve more of the shared branch graph and maintain higher hit rates, while still managing RAM usage effectively through the defined budget for branch metadata.
When pruning branch metadata, their payloads on the cold layer should be deleted as well.
Size of the RAM-residant cache and disk-residant cold layer should be configurable and pruning and eviction logic should take into account both parameters and implement a strategy that optimizes for hit rate and resource usage based on the configured limits.

## Q10. What ownership or reachability model determines when cold-layer payloads are safe to delete?

Affected requirements: R38b, R55a, R71, R80-R83.

Answer: Open. The document now requires deletion of cold-layer payloads that become unreferenced after branch pruning, but it still does not define whether payload descriptors may be shared across multiple branches or what bookkeeping proves that a payload is no longer reachable.

Why this is open:

- R38b requires deletion of payloads or descriptors that become unreferenced.
- R55a requires cleanup to be safe against deleting payloads still reachable from retained branches or descendants.
- R71 allows a branch node to reference a full-state blob, a checkpoint payload, or both, but does not define whether those references can be shared.
- R80-R83 establish shared branch reuse across slots, which increases the importance of precise ownership and reachability rules.

Options to resolve in the requirements document:

1. Require exclusive payload ownership per branch node. State that a payload descriptor belongs to exactly one branch node, so deleting that node makes the payload deletable unless descendants explicitly own separate payloads.
2. Require shared-reference bookkeeping. State that payload descriptors may be shared across branches and require reference counting, reachability analysis, or equivalent safe garbage-collection rules before cold-layer deletion.
3. Restrict sharing by phase. Allow simple exclusive ownership in interim structures, but require explicit shared-reference semantics once the long-term shared branch graph is introduced.

## A10. What ownership or reachability model determines when cold-layer payloads are safe to delete?

Choose the Option 1. Require exclusive payload ownership per branch node by stating that a payload descriptor belongs to exactly one branch node, so deleting that node makes the payload deletable unless descendants explicitly own separate payloads.

## Q11. How must graph topology be updated when an internal branch node is pruned but descendants are retained?

Affected requirements: R38a, R71a, R76, R79b, R80-R83.

Answer: Open. The document now allows retained descendants to own separate payload descriptors after an ancestor is pruned, but it still does not define how those descendants remain discoverable in the branch topology when their parent node is removed.

Why this is open:

- R38a and R79b preserve reusable descendants across pruning decisions.
- R71a allows a retained descendant to remain independently restorable with its own payload descriptor.
- R76 requires parent-child relationships between branch nodes.
- R80-R83 require continued shared traversal of the branch graph over time.

Options to resolve in the requirements document:

1. Require reparenting to the nearest retained ancestor. State that when an internal node is pruned, retained descendants must be reattached to the nearest retained ancestor that preserves valid traversal semantics.
2. Require promotion to a retained root or synthetic anchor. State that when pruning breaks a parent chain, retained descendants must be promoted to roots or attached to an explicit synthetic anchor that preserves lookup and traversal behavior.
3. Restrict pruning to leaf or whole-subtree removal. State that an internal node may not be pruned while any descendant is retained, avoiding the need for topology rewrites.

## A11. How must graph topology be updated when an internal branch node is pruned but descendants are retained?

Deleting payload doesn't mean that the branch node itself must be deleted. The branch node can still exist in the graph and maintain its relationships with its parent and child nodes, but it would simply no longer have an associated payload. This allows the retained descendants to remain discoverable in the branch topology even if their parent node's payload is pruned, while still maintaining the overall structure of the graph. Therefore, the implementation should allow for branch nodes to exist without payloads and ensure that traversal and lookup behavior remains consistent regardless of whether a node has an associated payload or not.
If at some time the branch with deleted payload becomes a branching point because all its childrn doesn't match a supplied prompt, then payload for that branch should be recalculated and stored in the cache again.

