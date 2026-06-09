# Software Architecture: Alternate Hybrid Cache Mode for llama-server - Part 5: Stage 4: LRU Eviction Policy with Protected Roots

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

### Stage 4: LRU Eviction Policy with Protected Roots

**Objective:** Replace FIFO eviction with byte-accounted LRU and support protected roots.

**Deliverables:**

- Implement `server_cache_policy_lru` module with resident-byte accounting
- Reuse `--cache-ram` as the configurable hot-payload RAM budget
- Implement LRU eviction based on usage recency and byte pressure
- Add protection markers to cache entries
- Implement protected-root weighting (raises priority but doesn't bypass accounting)
- Add explicit diagnostics when protected roots exceed budget
- Keep policy selection internal while LRU is the only implemented policy; defer `--cache-eviction-policy` until another policy exists
- Add metrics: `cache_payload_evictions_total`, `cache_protected_root_decisions_total`

**Exit criteria:**

- Eviction is usage-aware, not FIFO
- Protected roots have higher retention priority
- Budget exhaustion is detected and reported
- Eviction respects configured RAM limits
- Policy is pluggable for future extensions

**Test coverage:** LRU ordering under various access patterns, protected root behavior under pressure, budget enforcement, policy parameter configuration

---

### Stage 5: Payload-Metadata Separation

**Objective:** Separate payload descriptors from payload bytes and enforce target/draft pairing.

**Deliverables:**

- Define `PayloadDescriptor` structure: ID, kind, pair state, version, size, checksum, store reference, residency state
- Refactor cache entries to store descriptors separately from payload bytes
- Implement target/draft pairing enforcement: atomic save, restore, and eviction
- Add descriptor validation: version checks, checksum verification, pairing consistency
- Reject partial target/draft operations when both sides should exist
- Add explicit diagnostics for pairing violations or descriptor mismatches

**Exit criteria:**

- Descriptors exist as first-class objects distinct from payload bytes
- Target and draft payloads are always managed as an atomic pair
- Descriptor validation prevents corrupt or mismatched restores
- Pairing violations fail explicitly with clear diagnostics

**Test coverage:** Descriptor validation, target/draft pairing enforcement, mismatch rejection, atomic operations

---

### Stage 6: Cold Layer and Asynchronous I/O

**Objective:** Add cold storage for payload bytes and asynchronous promotion/demotion.

**Deliverables:**

- Implement `server_cache_store_cold` module: versioned filesystem-based store, disabled unless explicitly configured
- Define cold store descriptor format with integrity checksums and version metadata
- Implement atomic write/rename for persistence
- Create `server_cache_io_worker` for asynchronous promotion/demotion outside `server_context` thread
- Add hot/cold promotion protocol: request, validation, notification
- Add cold store root configuration only for the persistence stage; this is deferred from the initial upstream target
- Keep `--cache-ram` as the hot-payload budget; add separate metadata/cold budgets only if later implementation evidence shows operators need them
- Add budget validation at startup with explicit diagnostic failures
- Add residency policy that demotes less-used payloads to cold storage
- Add metrics: `cache_payload_promotions_total`, `cache_payload_demotions_total`, cold restore latency

**Exit criteria:**

- Payloads can be offloaded to disk and restored on demand
- Cold I/O happens asynchronously without blocking `server_context`
- Integrity checks (checksums, versions) protect against corruption
- Budgets are configurable and enforced without changing the initial upstream CLI surface unnecessarily
- Startup validation rejects invalid budget configurations
- Target/draft pairing preserved across cold transitions

**Test coverage:** Cold store persistence, promotion/demotion protocol, integrity validation, paired offload, budget validation at startup

---

### Stage 7: Branch Graph Foundation

**Objective:** Build the shared branch forest with compatibility namespaces and multi-slot reuse.

**Deliverables:**

- Define `BranchNode` structure: ID, namespace, parent, token span, checksum span, positions, usage, residency, protection, payload references
- Implement compatibility namespace keying: model identity, draft presence, tokenizer semantics, workload profile
- Build branch forest index with parent-child relationships
- Implement branch lookup by token/checksum spans
- Implement branch traversal without requiring hot payloads
- Allow multiple slots to reference the same branch node without ownership transfer
- Add namespace validation before restore
- Preserve shared roots even when longer descendants exist
- Implement shared-budget model across all namespaces with global eviction
- Support concurrent operation of multiple namespaces (different models or workload profiles)

**Exit criteria:**

- Branch nodes are first-class reusable objects in a shared forest
- Slots hold transient references, not ownership
- Namespace prevents unsafe cross-model/cross-config restores
- Shared roots are preserved across sessions
- Multiple slots can traverse the same branch structure
- Multiple namespaces can coexist and share budgets without cross-namespace restore
- Global LRU eviction works correctly across namespace boundaries

**Test coverage:** Branch lookup, namespace validation, parent-child traversal, multi-slot reference correctness, shared root preservation, multi-namespace concurrent operation with shared budgets

---

### Stage 8: Metadata-Only Nodes and Re-materialization

**Objective:** Distinguish payload eviction from branch pruning and support metadata-only nodes.

**Deliverables:**

- Implement payload eviction as distinct from branch pruning
- Add `is_metadata_only` flag to `BranchNode`
- Allow nodes to remain in graph after payload eviction if needed for descendant topology
- Implement re-materialization: validate supplied tokens against branch metadata, replay from nearest retained payload-bearing ancestor
- Add validation mismatch handling: reject mismatched path, create new branch from latest validated ancestor
- Implement deterministic mismatch-parent selection and tie-breaking (R36a-d, R123a)
- Implement equivalent-branch deduplication when requests converge (R83a)
- Add cold-layer cleanup safety: verify no retained descendants own deleted descriptors
- Add branch-metadata budget tracking and enforcement (R8b, R21a)
- Add metrics: `cache_branch_pruning_total`, `cache_metadata_only_retentions_total`, `cache_node_rematerializations_total`, `cache_validation_mismatches_total`

**Exit criteria:**

- Payload eviction and branch pruning are separate lifecycle events
- Metadata-only nodes preserve topology without RAM overhead for payloads
- Re-materialization works correctly with validation
- Validation mismatches trigger safe new-branch creation
- Cold-layer cleanup doesn't delete payloads owned by retained descendants
- Branch-metadata budget is enforced separately from payload budgets
- Equivalent branches are deduplicated deterministically

**Test coverage:** Metadata-only node retention, re-materialization from ancestors, validation mismatch handling, deterministic tie-breaking, equivalent-branch deduplication, cold cleanup safety, branch-metadata budget enforcement

---

### Stage 9: Checkpoint Integration and Workload Profiles

**Objective:** Promote checkpoints to first-class branch nodes and implement workload-aware restore strategies.

**Deliverables:**

- Add checkpoint payloads as first-class branch node references alongside exact blobs
- Define workload profiles: `plain_transformer`, `checkpoint_dependent`, `target_plus_draft`
- Implement workload profile detection from model capabilities and request config
- Implement checkpoint-first restore planner for checkpoint-dependent profiles
- For plain-transformer profiles, prefer exact blobs and fall back to checkpoints only when valid
- For checkpoint-dependent profiles, traverse checkpoint nodes first and use blobs as accelerators
- Attach checkpoints at prepared-prompt boundaries when metadata is available
- Add metrics: `cache_checkpoint_restores_total`, `cache_checkpoint_hits_total`

**Exit criteria:**

- Checkpoints are canonical branch structure for checkpoint-dependent models (SWA, RS-limited, recurrent)
- Exact blobs remain available for exact-restore efficiency
- Restore strategy adapts based on workload profile
- Plain-transformer workloads remain efficient
- Checkpoint placement respects prepared-prompt boundaries

**Test coverage:** Checkpoint-first restore for constrained models, exact-blob preference for plain transformers, workload profile detection, boundary-aware checkpoint placement

---

### Stage 10: Observability, Security Review, and Hardening

**Objective:** Complete production readiness with full observability, security review, and performance validation.

**Deliverables:**

- Complete all remaining metrics from observability requirements
- Add structured logs for all failure modes, fallback paths, and integrity violations
- Implement comprehensive diagnostics for unsupported configurations
- Perform focused OWASP Top 10 security review (A01, A03, A04, A05, A08, A09)
- Harden cold-store path normalization and root enforcement
- Add request-provided cache marker validation and sanitization
- Verify descriptor integrity and validation paths
- Add benchmark suite: exact-blob hit rate, checkpoint hit rate, cold transition frequency, end-to-end savings
- Add stress tests: budget exhaustion, concurrent multi-slot access, large branch forests
- Verify deterministic behavior in tests (injected clocks, fake stores)
- Ensure 80% test coverage for hybrid-mode code paths (R107)
- Add operator documentation: CLI flags, budget tuning, workload profiles, metrics interpretation

**Exit criteria:**

- All metrics and diagnostics implemented per requirements
- Security review completed with mitigations in place
- Benchmarks demonstrate performance improvements for target workloads
- Test coverage meets 80% threshold
- Operator documentation is clear and complete
- Production readiness checklist satisfied

**Test coverage:** Security edge cases, budget exhaustion scenarios, integrity failure paths, concurrent access patterns, deterministic test reproduction

---

### Stage 11: Upstream Merge Integration

**Objective:** Re-sync the fork with `upstream_master` and rework prior stages when upstream cache or checkpoint changes invalidate them.

**Deliverables:**

- Pre-merge analysis of upstream commits touching cache, checkpoint, speculative decoding, server context, slot, and HTTP layers
- Merge execution with conflict resolution that keeps `--cache-mode hybrid` and the legacy default path unchanged
- Rework assessment mapping upstream changes to affected Stages 1-10, with required code or design updates
- Regression test reruns for any behavior the upstream change touches
- Merge log: decisions, deferred upstream commits, and known gaps

**Exit criteria:**

- Merge complete with no unresolved conflicts
- All prior-stage tests pass on the merged tree
- Hybrid mode invariants from earlier stages hold
- Upstream cache-related changes are integrated or recorded as known gaps with a follow-up plan
- Legacy mode behavior is unchanged

**Test coverage:** Prior-stage regression reruns, focused conflict resolution tests, compatibility namespace preservation, CLI flag preservation

---

### Stage 12: Stress Testing and Benchmarking

**Objective:** Validate hybrid mode under sustained load and measure end-to-end performance against the legacy path.

**Deliverables:**

- Stress scenarios: budget exhaustion, concurrent multi-slot access, large branch forests, prompt storms, mixed workload profiles
- Benchmark scenarios: exact-blob hit rate, checkpoint hit rate, cold transition frequency, end-to-end token throughput, restore latency
- Configuration matrix: `--cache-ram`, slot count, model size, context length, draft presence, workload profile
- Long-run checks: memory stability, file descriptor usage, metric counter stability over multi-hour runs
- Baseline numbers for regression detection in later runs
- Bottleneck and tuning report for operators

**Exit criteria:**

- No crashes, leaks, or unbounded resource growth under stress
- Hybrid mode shows measurable gains on the configured benchmarks
- Baselines recorded for future comparison
- Bottlenecks and tuning notes are documented
- Legacy mode performance is unaffected

**Test coverage:** Stress scenarios, benchmark scenarios, configuration matrix, long-run stability, workload profile validation, regression checks against legacy mode

---

### Stage 13: Endpoint Compatibility Corrections
See [Part 8](part-08-stage-13-endpoint-compatibility-corrections.md).

## Implementation Notes

Each stage builds on the previous one and maintains these invariants:

- **Correctness first:** Every stage must preserve inference correctness
- **Runnable code:** Each stage produces compilable, testable, deployable code
- **Legacy mode protected:** The default cache path remains unchanged throughout
- **Incremental value:** Each stage adds measurable capability or reduces risk
- **Isolated testing:** Each stage's new behavior is testable in isolation
- **Explicit failures:** Unsupported paths fail explicitly, not silently
- **Upstream-aware:** Stage 11 re-runs the staged plan against the live upstream, since new cache, checkpoint, or speculative decoding work there can invalidate or require rework on any prior stage
- **Endpoint parity:** Stage 13 keeps compatible public endpoint schemas stable while applying all enabled cache behavior through internal metadata and command-line configuration

The staging allows for early feedback, risk reduction, and parallel workstream opportunities (e.g., cold store implementation can proceed independently once interfaces are defined in Stage 5). Stage 11 revisits prior stages after an `upstream_master` merge; Stage 12 closes the validation loop with stress and benchmark evidence at production-relevant scales, not just unit-scale tests. Stage 13 applies endpoint compatibility corrections found during Stage 12 so public compatible routes get the same command-line-enabled cache behavior without exposing cache-specific request fields.

## Requirement Traceability Matrix

| Requirement group | Covered by |
| --- | --- |
| Activation, compatibility, minimal intrusion (R1-R4, R107-R111) | Executive Summary, Target Architecture, ADR-001, Phased Delivery |
| Hybrid model and model-family awareness (R5-R14, R11-R14, R84-R86) | Workload Profiles, Runtime Semantics, ADR-002 |
| Non-destructive hits, reuse-aware eviction, protected roots (R15-R26) | Residency and Eviction Rules, ADR-005, Verification Strategy |
| Prepared-prompt boundaries (R27-R33) | Prepared-Prompt Boundary Model, ADR-004, Phase 1 |
| Correctness and fallback (R34-R36, R36a-R36d, R90-R92, R120-R124) | Failure and Fallback Rules, Restore Strategy Order, ADR-008, Security Review |
| Payload separation, cold layer, hot/cold residency (R37-R60, R93-R98) | Logical Model, Cold Layer Contract, ADR-006, ADR-007, Phase 2 |
| Observability (R61-R68) | Observability, ADR-008 |
| Shared branch graph and slot-independent reuse (R69-R83, R83a) | Branch Graph Semantics, ADR-003, ADR-009, Phase 3 |
| Metadata-only branch nodes and payload/pruning lifecycle (R38a-R38c, R71a-R71e, R76a, R79a-R79b, R55a) | Branch Graph Semantics, Residency and Eviction Rules, Cold Layer Contract, ADR-009 |
| Validation mismatch and mismatch-parent selection (R36a-R36d, R39a-R39c, R71e, R123a) | Restore Strategy Order, Branch Graph Semantics, ADR-009 |
| Budget accounting and pruning preference (R8a, R8b, R21a, R57a-R57e) | Residency and Eviction Rules, ADR-005 |
| Endpoint parity and compatible API surfaces | API Endpoint Compatibility, Prepared-Prompt Boundary Model, Stage 13 Endpoint Compatibility Corrections |
| Eviction policy evolution (R20a, R20b) | Residency and Eviction Rules, ADR-005 |
| Code quality and best practices (R130, R131) | ADR-008 |
| Multimodal safety (R87-R89) | Runtime Semantics, Failure and Fallback Rules, Phase 3 |
| Testability and verification (R99-R106, R125-R129) | Verification Strategy, ADR-008 |
| Security review and abuse handling (R121-R123, R132-R133) | Security Review, Cold Layer Contract, ADR-008 |

## Final Recommendation

Implement the alternate cache mode as a new hybrid controller behind an explicit mode gate. Keep exact full-state blobs, make checkpoints first-class reusable branch nodes, store branch metadata permanently in RAM, and move both full-state and checkpoint payloads through a paired hot/cold residency system. Preserve the current default path unchanged, keep prompt preparation in the HTTP layer, and make correctness, integrity, and explicit fallback behavior more important than hit rate.

That design is the smallest architecture that satisfies the requirements without forcing a rewrite of the current server.
