# Stage 8 design: metadata-only nodes and re-materialization -- Part 5: observability, testability, and review readiness

Source: [../cache-handling-phase8-design.md](../cache-handling-phase8-design.md)

## Metrics

Stage 8 uses the existing Prometheus endpoint when metrics are enabled.

| Metric | Type | Labels | Meaning |
| --- | --- | --- | --- |
| `cache_metadata_only_retentions_total` | Counter | namespace, reason | Nodes retained after payload eviction. |
| `cache_node_rematerializations_total` | Counter | namespace, result | Re-materialization attempts and outcomes. |
| `cache_node_rematerialization_bytes_total` | Counter | namespace | Payload bytes recreated for metadata-only nodes. |
| `cache_validation_mismatches_total` | Counter | namespace, method | Token or checksum validation mismatches. |
| `cache_mismatch_parent_selections_total` | Counter | namespace, source | New-branch parent selections after mismatch. |
| `cache_equivalent_branch_deduplications_total` | Counter | namespace, action | Equivalent branch reuse or canonicalization. |
| `cache_branch_pruning_total` | Counter | namespace, result, reason | Branch metadata pruning attempts and outcomes. |
| `cache_branch_pruned_metadata_bytes_total` | Counter | namespace | Metadata bytes freed by pruning. |
| `cache_cold_cleanup_total` | Counter | namespace, result | Cold cleanup attempts after eviction or pruning. |
| `cache_branch_metadata_admission_rejections_total` | Counter | namespace, reason | Metadata admissions refused because safe pruning could not satisfy budget. |

Stage 7 metrics for metadata bytes, protected-root payload decisions, payload evictions, namespace activity, and slot refs remain in use.

## Diagnostics

Structured logs should use the existing server logging path. Required event names:

- `metadata_only_retained`
- `rematerialization_plan`
- `rematerialization_validation_mismatch`
- `rematerialization_committed`
- `rematerialization_fallback`
- `mismatch_parent_selected`
- `equivalent_branch_reused`
- `equivalent_branch_canonicalized`
- `branch_prune_candidate_rejected`
- `branch_pruned`
- `cold_cleanup_committed`
- `cold_cleanup_blocked`
- `branch_metadata_admission_rejected`

Logs must include namespace, node IDs, selected parent, validation method, result, and reason where applicable. They must not include raw prompt text.

## Testability

Stage 8 behavior must be testable without model-backed inference for core decisions.

| Area | Required evidence |
| --- | --- |
| Metadata-only transition | Focused graph/controller tests for payload eviction that preserves topology. |
| Re-materialization validation | Tests for full match, checksum mismatch, token mismatch, missing ancestor payload, and atomic save failure. |
| Mismatch-parent selection | Deterministic tests covering partial validation, equal-length ties, and unordered candidate insertion. |
| Equivalent-branch deduplication | Concurrent and sequential admission tests that prove equivalent branches reuse one canonical node. |
| Cold cleanup safety | Fake cold store tests proving descriptors owned by retained descendants are not deleted. |
| Metadata-budget pruning | Tests for safe leaf pruning, protected-root exclusion, active-ref exclusion, and admission rejection when no safe candidate exists. |
| Metrics and diagnostics | Counter/gauge shape tests plus focused assertions for result and reason labels. |
| Regression | Stage 1-7 cache tests continue to pass. |

Tests should use injected clocks, deterministic ID generation, fake stores, and controlled candidate ordering.

## Requirement traceability

| Requirement | Stage 8 design coverage |
| --- | --- |
| R8b | Branch-metadata budget is enforced for the explicit branch metadata model. |
| R21a | Branch pruning uses metadata RAM accounting and safe prune candidates. |
| R36a-R36d | Mismatched metadata-only paths are rejected and new branches use deterministic mismatch-parent selection. |
| R38a-R38c | Payload eviction and branch pruning are separate; metadata-only nodes preserve needed topology. |
| R55a | Cold cleanup proves descriptor ownership before deletion. |
| R57a-R57e | Budget handling covers hot payload, metadata, and cold storage, with startup and admission diagnostics expected from implementation planning. |
| R71a-R71e | Descriptor ownership is singular, metadata-only nodes can re-materialize, and mismatched payloads attach only to the new branch. |
| R76a | Parent-child topology stays valid through metadata-only ancestors. |
| R79a-R79b | Branch pruning considers reachability, protection, and reuse value instead of following payload eviction automatically. |
| R83a | Equivalent validated branches are reused or canonicalized with deterministic tie-breaking. |
| R123a | Branch lookup, mismatch-parent selection, and deduplication use explicit deterministic ordering. |

## Risks

- Re-materialization can be expensive when the nearest payload-bearing ancestor is far from the selected node. Metrics must expose this cost.
- Conservative pruning may leave metadata over budget when only protected or topology-required nodes remain. The correct outcome is admission rejection or explicit over-budget diagnostics.
- Equivalent-branch canonicalization can race under concurrent requests. Admission must be atomic with lookup.
- Cold cleanup bugs can delete restorable payloads. Ownership checks are blocking, not advisory.
- Token-span storage can grow metadata quickly. Budget tests need realistic long-branch cases.

## Review readiness

The design is ready for independent design review when reviewers can verify these points:

- Stage 8 does not depend on Stage 9 checkpoint-first restore.
- Payload eviction, branch pruning, and cold cleanup have separate contracts.
- Re-materialization has pre-apply validation and clear fallback behavior.
- Mismatch-parent selection and deduplication have deterministic tie-breakers.
- Branch-metadata pruning cannot break retained descendant traversal.
- Metrics and test seams expose the new behavior without requiring public endpoints.

Current verdict: READY FOR INDEPENDENT DESIGN REVIEW. No implementation gate is approved by this document.
