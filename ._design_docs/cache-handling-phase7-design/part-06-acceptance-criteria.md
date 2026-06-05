# Stage 7 Design: Branch Graph Foundation -- Part 6: Acceptance Criteria

## Exit Criteria Mapping

Each exit criterion from the architecture is mapped to a specific test or verification.

| # | Exit Criterion | Verification | Status |
|---|---------------|-------------|--------|
| EC1 | Branch nodes are first-class reusable objects in a shared forest | QA rows G70-G71 and implementation Part 10 | PASS |
| EC2 | Slots hold transient references, not ownership | QA rows G74-G75 and implementation Part 10 | PASS |
| EC3 | Namespace prevents unsafe cross-model/cross-config restores | QA rows G76 and G82 | PASS |
| EC4 | Shared roots are preserved across sessions | QA row G86 and implementation Part 10 | PASS |
| EC5 | Multiple slots can traverse the same branch structure | QA rows G71 and G74 | PASS |
| EC6 | Multiple namespaces can coexist and share budgets without cross-namespace restore | QA rows G77-G78 | PASS |
| EC7 | Global hot-payload LRU eviction works correctly across namespace boundaries while graph metadata remains intact | QA rows G78-G79 and G86-G87 | PASS |

## Requirement Pass/Fail Criteria

| Requirement | Pass Condition | Fail Condition |
|-------------|---------------|---------------|
| R8 (branch metadata resident in RAM) | `branch_forest_index::total_metadata_ram_bytes()` > 0 after node creation; nodes survive payload eviction | Metadata is lost when payload is evicted |
| R38a-R38c (payload demotion independent of branch pruning) | Branch node remains in forest after payload demotion; metadata soft-limit pressure does not prune or reparent nodes | Node is removed when payload is demoted or metadata pressure changes topology |
| R23-R26 (protected roots) | Protected root graph metadata/topology is not removed by ordinary pressure; protected-root payloads are skipped while unprotected candidates can satisfy budget, but demoted or evicted with diagnostics when protected bytes alone exceed the hot payload budget | Protected root payload bytes are pinned outside accounting, or protected root graph nodes are removed by payload eviction |
| R80 (slots reference without ownership) | Multiple slots can acquire refs on same node; node survives any single slot's release | Node is destroyed when one slot releases |
| R81 (restore doesn't consume for others) | After slot A loads from node, slot B can also load from same node | Node is consumed/marked after first load |
| R82 (not one-shot entries) | Node persists across multiple save/load cycles | Node is destroyed after first load |
| R83 (multiple slots traverse same graph) | Two slots can independently traverse parent-child relationships of same node | Traversal is slot-scoped |
| R90 (correctness over hit rate) | Namespace validation rejects unsafe restores; explicit error returned | Unsafe restore succeeds silently |
| R91 (equivalent valid state) | After restore, slot state matches saved state for the matched namespace | State mismatch after restore |
| R92 (explicit failure) | Cross-namespace restore attempt returns cache miss, not undefined behavior | Cross-namespace restore produces undefined behavior |
| R93 (configurable budget controls) | Hot payload RAM remains controlled by `--cache-ram`; branch-metadata RAM has internal/test-only soft-limit configuration with metrics and diagnostics; public metadata CLI remains deferred | Metadata usage is not accounted or cannot be exercised in tests |

## Test Coverage Requirements

| Area | Minimum Coverage | Verification Method |
|------|-----------------|-------------------|
| BranchNode creation and properties | 100% of fields | Unit test assertions |
| NamespaceKey computation | 100% of components | Unit test hash comparison |
| BranchForestIndex node lifecycle | All public methods | Unit test scenarios |
| Branch lookup (token span) | Prefix match, no match, min_tokens filter | Unit test scenarios |
| Branch lookup (checksum span) | Length-qualified prefix checksum match, no match, wrong-length rejection | Unit test scenarios |
| Parent-child traversal | path_to_root, children, descendants | Unit test scenarios |
| Slot reference counting | Acquire, release, concurrent, block payload eviction | Unit + concurrency tests |
| Shared root preservation | Protected root graph node survives payload eviction; protected-root payload skip and protected-over-budget demotion/eviction paths are covered separately | Unit test |
| Namespace validation | Same ns pass, different ns fail | Unit + integration tests |
| Multi-namespace coexistence | Independent topology, shared hot payload budget, metadata soft-limit diagnostics | Integration test |
| Global LRU eviction | Cross-namespace hot payload ordering with unprotected candidates before protected-root payload candidates | Integration test |
| Metadata budget accounting | Under/over soft limit, diagnostics, no topology change | Unit + integration tests |
| Regression | All existing Stage 1-6 tests pass | Full test suite |

## Quality Gates

| Gate | Criteria | Evidence |
|------|----------|---------|
| Design Review | All part files reviewed, findings resolved | Review document with PASS verdict |
| Implementation | All steps 7.1-7.9 implemented with evidence | Implementation Part 5 and corrections Parts 7 and 9 |
| Unit Tests | All Test 7.4.x scenarios pass | QA report 20260531-01 |
| Integration Tests | Multi-namespace, multi-slot, global hot-payload eviction scenarios pass | QA report 20260531-01 |
| Regression | Stage 1-6 regression rows pass | QA report 20260531-01 |
| QA | Independent QA execution of all test scenarios | QA report 20260531-01, PASS 20 |
| Manager Gate | All exit criteria met, no blocking findings | Implementation Part 12 closure decision |

## Known Limitations (Stage 7)

- No metadata-only nodes: all nodes carry payload references (Stage 8)
- No equivalent-branch deduplication: duplicate branches may exist (Stage 8)
- No checkpoint-first restore: only exact-blob restore (Stage 9)
- No branch pruning as distinct lifecycle: production metadata pressure does not remove, orphan, or reparent graph nodes (Stage 8+)
- No public metadata-budget CLI flag: Stage 7 uses internal/test-only metadata soft-limit configuration and exposes accounting/diagnostics only. The public `--cache-budget-metadata-ram` surface remains deferred by the architecture.
- No re-materialization from nearest payload-bearing ancestor (Stage 8)
- Namespace validation is strict equality only (future stages may add tolerance)
