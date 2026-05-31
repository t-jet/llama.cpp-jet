# Stage 7 Design: Branch Graph Foundation -- Part 5: Metrics and Observability

## New Metrics

All metrics are exposed through the existing Prometheus `/metrics` endpoint when `--metrics` is enabled.

### Branch Graph Operations

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cache_branch_nodes_created_total` | Counter | namespace | Total branch nodes created |
| `cache_branch_lookups_total` | Counter | namespace, method | Total branch lookup operations (token_span, checksum_span) |
| `cache_branch_lookup_hits_total` | Counter | namespace | Total successful branch lookups |
| `cache_branch_traversals_total` | Counter | operation | Total traversal operations (path_to_root, descendants, children) |

### Namespace Activity

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cache_namespace_count` | Gauge | - | Number of active namespaces |
| `cache_namespace_nodes` | Gauge | namespace | Number of branch nodes per namespace |
| `cache_namespace_roots` | Gauge | namespace | Number of root nodes per namespace |
| `cache_namespace_metadata_bytes` | Gauge | namespace | Branch-metadata RAM bytes per namespace |

### Budget Usage

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cache_budget_branch_metadata_bytes` | Gauge | - | Current branch-metadata RAM usage |
| `cache_budget_branch_metadata_soft_max_bytes` | Gauge | - | Internal/test-only branch-metadata RAM soft limit |
| `cache_budget_branch_metadata_ratio` | Gauge | - | Usage / max ratio (0.0 to 1.0+) |
| `cache_budget_branch_metadata_over_limit` | Gauge | - | 1 when metadata usage exceeds the soft limit, otherwise 0 |

### Eviction Across Namespaces

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cache_eviction_payloads_total` | Counter | namespace, action | Payloads evicted or demoted per namespace |
| `cache_eviction_payload_bytes_total` | Counter | namespace, action | Payload bytes evicted or demoted per namespace |
| `cache_eviction_payload_blocked_refs_total` | Counter | - | Payload eviction attempts blocked by active slot refs |
| `cache_protected_root_payload_decisions_total` | Counter | decision | Protected-root payload decisions (`skipped_unprotected_available`, `demoted_over_budget`, `evicted_over_budget`, `admission_rejected_oversize`) |
| `cache_protected_root_payload_bytes` | Gauge | residency | Protected-root payload bytes by residency (`hot`, `cold`) |

### Slot Reference Activity

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cache_slot_ref_acquires_total` | Counter | - | Total slot reference acquires |
| `cache_slot_ref_releases_total` | Counter | - | Total slot reference releases |
| `cache_slot_ref_concurrent_peak` | Gauge | - | Peak concurrent slot references across all nodes |

### Forest Lock Activity

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cache_forest_lock_acquires_total` | Counter | - | Total mutex acquire attempts |
| `cache_forest_lock_retries_total` | Counter | - | Mutex acquire attempts that had to retry (contention indicator) |

The lock contention ratio can be derived as `cache_forest_lock_retries_total / cache_forest_lock_acquires_total`. These counters replace the earlier underspecified `cache_branch_forest_lock_contention` ratio gauge, which was not directly measurable without profiling hooks.

### Namespace Validation

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `cache_namespace_validations_total` | Counter | result | Total namespace validation checks (pass, fail) |
| `cache_namespace_validation_failures_total` | Counter | - | Total namespace validation failures (cross-model restore attempts) |

## Logging

Structured log messages for branch graph operations:

- `branch_node_created` -- node_id, namespace_id, parent_id, n_tokens, protected_root
- `branch_metadata_over_budget` -- current_bytes, soft_max_bytes, ratio, top_namespaces
- `payload_evicted` -- node_id, namespace_id, payload_bytes, action (evict|demote), reason (budget|shutdown)
- `branch_lookup` -- namespace_id, method, n_candidates, hit
- `branch_traversal` -- operation, node_id, depth
- `namespace_validation` -- slot_namespace, branch_namespace, result (pass|fail)
- `slot_ref_acquire` -- node_id, slot_id, new_count
- `slot_ref_release` -- node_id, slot_id, new_count
- `budget_branch_metadata` -- current_bytes, soft_max_bytes, ratio, over_limit
- `eviction_blocked_refs` -- node_id, ref_count
- `protected_root_payload_decision` -- node_id, namespace_id, decision, payload_bytes, hot_payload_budget_bytes, protected_hot_bytes

## Diagnostics Endpoint

The existing `/cache` diagnostics endpoint is extended with:

```json
{
    "branch_forest": {
    "total_nodes": 150,
    "total_metadata_bytes": 524288,
    "metadata_soft_limit_bytes": 67108864,
    "metadata_ratio": 0.0078,
    "metadata_over_limit": false,
    "namespaces": {
      "model_a_hash": {
        "nodes": 80,
        "roots": 3,
        "metadata_bytes": 262144
      },
      "model_b_hash": {
        "nodes": 70,
        "roots": 2,
        "metadata_bytes": 262144
      }
    },
    "protected_roots": 5,
    "active_slot_refs": 12,
    "peak_concurrent_refs": 18
  }
}
```

## Recommended Metric Names (Prometheus)

- `cache_branch_nodes_created_total`
- `cache_branch_lookups_total`
- `cache_branch_lookup_hits_total`
- `cache_namespace_count`
- `cache_namespace_nodes`
- `cache_namespace_metadata_bytes`
- `cache_budget_branch_metadata_bytes`
- `cache_budget_branch_metadata_soft_max_bytes`
- `cache_budget_branch_metadata_over_limit`
- `cache_eviction_payloads_total`
- `cache_eviction_payload_bytes_total`
- `cache_eviction_payload_blocked_refs_total`
- `cache_protected_root_payload_decisions_total`
- `cache_protected_root_payload_bytes`
- `cache_slot_ref_acquires_total`
- `cache_slot_ref_releases_total`
- `cache_forest_lock_acquires_total`
- `cache_forest_lock_retries_total`
- `cache_namespace_validation_failures_total`
