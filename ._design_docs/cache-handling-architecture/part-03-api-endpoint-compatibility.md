# Software Architecture: Alternate Hybrid Cache Mode for llama-server - Part 3: API Endpoint Compatibility

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

### API Endpoint Compatibility

The cache architecture should not change request or response compatibility for existing clients.

| Endpoint surface | Compatibility rule |
| --- | --- |
| OpenAI-compatible chat, responses, and embeddings routes | No cache-specific request fields in the initial upstream target. Cache behavior is selected by server CLI flags and internal task metadata. |
| Non-OAI `/completion` and `/embedding` routes | Preserve the documented prompt shapes, including token arrays, mixed token/string prompts, and multimodal prompt objects. Attach only internal metadata derived during parsing/tokenization. |
| Multimodal requests | Preserve the existing media marker and base64/file handling rules. Include multimodal projector identity, marker layout, and media token spans in compatibility keys before reusing state. Reject unsupported multimodal restore candidates rather than guessing. |
| `/slots` | Keep save/restore semantics and gating unchanged. Hybrid cache internals must not leak through `/slots`, and slot save paths remain separate from any cold payload store. |
| `/metrics` | Use the existing Prometheus endpoint when `--metrics` is enabled. Add hybrid cache counters there instead of adding a new cache stats endpoint. |
| `/props`, `/models`, `/v1/models` | Do not add mutable cache controls here in the initial design. Model capability reporting may remain unchanged unless a later UI requirement needs a read-only cache capability flag. |
| `/health` | Keep health response shape unchanged. Cache failures should surface through logs, metrics, and normal request fallback, not by changing health semantics. |

Any future cache-inspection endpoint should be treated as a separate proposal. It must be disabled by default, avoid exposing serialized model state or prompt contents, and follow the server's existing endpoint-gating style.

### Cold Layer Contract

The cold layer stores payload bytes, never the authoritative branch metadata.

Required properties:

- versioned descriptor format
- strong integrity checksum per payload pair
- atomic write/rename semantics for persistence
- explicit pairing between target and draft payloads
- deterministic restore and error paths suitable for tests
- cold-layer cleanup triggered by branch pruning must verify that deleted descriptors and payload bytes are not owned by any retained branch or retained descendant before deletion proceeds

The recommended implementation is a local filesystem store rooted at a configured directory, with all paths derived from internal identifiers rather than request-provided strings.

### Failure and Fallback Rules

Hybrid mode must fail safe.

- Missing cold payload: record diagnostics, invalidate the descriptor, and recompute.
- Checksum or version mismatch: reject restore and recompute.
- Partial target/draft availability: reject paired restore and recompute.
- Unsupported multimodal combination: reject explicitly instead of silently degrading.
- Restore application failure: leave the slot in a known-empty or known-valid state and restart prompt processing.

## ADRs

The alternatives below were evaluated against the current implementation in `tools/server/server-context.cpp`, `tools/server/server-task.cpp`, `tools/server/README-dev.md`, and the local design notes in `cache-handling.md` and `cache-ideas.md`.

### ADR-001: Keep the Alternate Behavior Behind Explicit Cache Mode Dispatch

Status: Proposed  
Requirement support: R1-R4, R107-R111

Context:

The current cache behavior is the default server behavior and already interacts with slot scheduling, prompt loading, checkpoint trimming, and idle-slot caching. The requirements explicitly forbid changing default behavior when the alternate mode is disabled.

Decision:

Introduce an explicit cache mode switch such as `--cache-mode legacy|hybrid` and a `server_cache_controller` interface. `legacy` wraps the current prompt-cache/checkpoint behavior with no semantic change. `hybrid` is a new implementation.

Alternatives considered:

- Replace the legacy path in place. Rejected because it risks behavioral regressions in the default mode and conflicts with the compatibility requirements.
- Scatter `if (hybrid_mode)` checks through `server_context`, `server_task`, and route handlers. Rejected because it creates invasive patching and weak extension boundaries.
- Ship a separate binary or server variant. Rejected because it duplicates runtime behavior and increases operational cost.

Consequences:

- The legacy implementation remains structurally intact and easy to test.
- The hybrid design has a clear seam for isolated tests.
- Some adapter code is necessary, but the trade is favorable because it localizes risk.

### ADR-002: Use a Workload-Profile-Aware Hybrid Restore Model

Status: Proposed  
Requirement support: R5-R14, R84-R86

Context:

The requirements do not allow a blob-only design, because checkpoint-dependent workloads need safe reuse that respects rollback limits, SWA, RS constraints, recurrent behavior, or equivalent restrictions. They also do not allow a checkpoint-only design, because exact full-state restore must remain available.

Decision:

Use a hybrid restore model with explicit workload profiles:

- exact full-state blobs remain the fastest exact-restore tier
- checkpoint nodes become canonical branch structure for checkpoint-dependent workloads
- the restore planner ranks exact blobs and checkpoints differently depending on workload profile

Alternatives considered:

- Full-state blobs only. Rejected because it cannot express checkpoint-first reuse for constrained models and wastes branch structure.
- Checkpoints only. Rejected because it removes the current exact-restore capability and increases restore cost for plain-transformer workloads.
- One universal restore policy for all models. Rejected because it hides important correctness differences between plain and checkpoint-dependent runtimes.

Consequences:

- The planner becomes slightly more complex.
- The architecture satisfies both exact-hit efficiency and checkpoint-first safety.
- Plain-transformer performance can stay efficient without forcing all workloads into the same branch logic.

### ADR-003: Replace Flat Prompt Ownership with a Shared Branch Forest

Status: Proposed  
Requirement support: R69-R83

Context:

The current prompt cache is effectively a flat list of saved prompts, and prefix-elimination rules can remove shorter roots when a longer prompt is saved. That directly conflicts with the requirements for preserved shared roots and slot-independent reuse.

Decision:

Represent reusable cache state as a shared branch forest keyed by compatibility namespace. Slots keep transient references to nodes instead of owning the underlying cache object.

Alternatives considered:

- Keep a flat prompt list and improve ranking only. Rejected because flat storage cannot preserve shared branch topology or parent-child reuse semantics.
- Keep lineage-local checkpoints attached only to a slot prompt. Rejected because reuse remains slot-scoped and destructive.
- Build a fully general graph with arbitrary cycles. Rejected because the problem is naturally tree/forest-shaped and a cyclic model adds unnecessary complexity.

Consequences:

- Shared roots and shared descendants remain addressable over time.
- Multiple slots can reuse the same node without transfer of ownership.
- Node-level usage and protection become first-class policy inputs.
- Multiple compatibility namespaces (different models or workload profiles) can coexist in the same cache, sharing global budgets with cross-namespace isolation.

### ADR-004: Capture Boundaries in the HTTP Prompt-Preparation Layer

Status: Proposed  
Requirement support: R27-R33, R115

Context:

The current architecture already applies chat templates and tokenizes requests in the HTTP layer before work reaches `server_context`. The requirements forbid heuristic rescanning of the final prompt string as the primary boundary source.

Decision:

Introduce a prepared-prompt boundary path that runs alongside prompt preparation. The HTTP layer produces `PreparedPromptMetadata`, including boundary spans, protection hints, and stable matching keys, and passes it to `server_task`.

Alternatives considered:

- Reconstruct message boundaries by rescanning the flattened prompt string in `server_context`. Rejected because it is heuristic, brittle, and violates the layering requirements.
- Use only periodic token-count checkpoints. Rejected because it misses semantically important message boundaries and performs poorly for long messages.
- Put chat-template logic inside `server_context` so boundaries are available there. Rejected because it breaks the current separation of concerns and adds heavy prompt work to the single-threaded inference core.

Consequences:

- Boundary-aware caching becomes consistent with the existing architecture.
- `/completion` remains API-compatible and gets only minimal token-span metadata unless a separate API proposal is accepted.
- The hybrid mode can still fall back to token/position rules when metadata is absent.

### ADR-005: Use Byte-Accounted LRU with Protected Roots as the Initial Policy

Status: Proposed  
Requirement support: R18-R26, R57-R60

Context:

The first acceptable reuse-aware policy in the requirements is LRU. The policy must also support protected roots and future evolution to SLRU or 2Q.

Decision:

Use a resident-byte-accounted LRU as the initial policy surface, with protected-root weighting and explicit refusal behavior when protected data alone exceeds budget.

Alternatives considered:

- Keep FIFO. Rejected because it does not satisfy the reuse-aware eviction requirements.
- Treat protected roots as fully pinned and outside byte accounting. Rejected because it hides budget exhaustion and creates unbounded memory risk.
- Start immediately with a more complex policy such as 2Q or SLRU. Rejected because the extra complexity is not required for the first implementation and weakens reviewability.

Consequences:

- The first implementation stays simple and requirement-compliant.
- The policy interface can evolve without changing external semantics.
- The initial upstream target should not expose `--cache-eviction-policy`; add a selector only after there is more than one implemented policy.
- Protected roots remain explicit and auditable rather than magical.

### ADR-006: Separate Metadata from Payload Bytes and Treat Target/Draft as an Atomic Pair

Status: Proposed  
Requirement support: R9-R10, R37-R48, R52, R104

Context:

The current prompt-cache entry stores tokens, full-state bytes, and checkpoints together. The new requirements need metadata to remain resident while payload bytes move hot or cold. They also require target and draft state to remain synchronized.

Decision:

Store branch metadata and payload descriptors separately from payload bytes. A payload descriptor always represents a paired restore object:

- target-only when no draft context exists
- target-plus-draft when a draft context exists

Offload, restore, demotion, promotion, and eviction operate on the pair, never on only one side.

Alternatives considered:

- Keep one monolithic cache-entry object. Rejected because metadata cannot remain usable when bytes are cold.
- Manage target and draft payloads independently. Rejected because it can create half-valid restore states and violates the coupling requirements.
- Keep only metadata for checkpoints and full bytes for exact blobs. Rejected because both payload classes must support hot/cold transitions.

Consequences:

- The controller can rank and traverse branches without eagerly loading payload bytes.
- Pair integrity becomes explicit and testable.
- Serialization and storage contracts must carry pairing metadata and compatibility information.

### ADR-007: Use an Asynchronous Local Cold Store with Versioned Descriptors

Status: Proposed  
Requirement support: R49-R56, R122, R127

Context:

`server_context` runs on a dedicated single thread and already warns against heavy post-processing in that thread. A cold layer is required, but synchronous disk I/O in the scheduling thread would directly hurt multi-slot throughput.

Decision:

Use a local filesystem cold store with versioned payload descriptors and a dedicated cache I/O worker that performs promotion and demotion outside the `server_context` thread. `server_context` remains the policy owner, but not the disk-I/O executor.

Alternatives considered:

- Synchronous disk I/O inside `server_context`. Rejected because it makes cold restores and demotions block the entire inference scheduler.
- External distributed cache service. Rejected because the requirements explicitly exclude distributed cache/coherence in the first implementation.
- Keep everything hot in RAM. Rejected because the requirements explicitly require a cold layer and hot/cold residency.

Consequences:

- Throughput and tail latency are better protected.
- The design needs a small internal asynchronous protocol and a slot waiting state for pending promotion.
- Storage backends remain substitutable in tests through the cold-store abstraction.

### ADR-008: Make Diagnostics, Integrity Checks, and Deterministic Test Seams Mandatory

Status: Proposed  
Requirement support: R61-R68, R66a, R107, R121-R129, R130, R131, R132-R133

Context:

The alternate mode introduces new failure modes: missing payloads, checksum mismatches, unsupported configurations, target/draft pairing errors, and policy-induced demotion/promotion behavior. These must be observable and testable.

Decision:

Require all hybrid-cache operations to emit explicit diagnostics, versioned descriptors, integrity checks, and deterministic test seams:

- counters and logs for hits, restores, promotions, demotions, evictions, protection decisions, and fallback failures
- injected clock and usage-updater interfaces
- substitutable hot/cold stores and I/O executors for tests
- checksum verification and descriptor-version checks before restore

Alternatives considered:

- Rely on debug logs only. Rejected because it is insufficient for acceptance testing and operational diagnosis.
- Make integrity checks optional for performance. Rejected because correctness and recoverability have priority over hit rate.
- Use wall-clock behavior directly in policy tests. Rejected because it makes tests nondeterministic.

Consequences:

- The implementation is easier to benchmark and review.
- Some additional plumbing is necessary for clocks, stores, and metrics.
- Security and correctness regressions become much easier to detect.
- Test coverage target of 80% ensures the alternate mode behavior is well-validated.

