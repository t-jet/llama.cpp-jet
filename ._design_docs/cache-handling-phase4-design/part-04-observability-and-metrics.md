# Phase 4 Design: LRU Eviction Policy with Protected Roots - Part 4: Observability and metrics

Source: [../cache-handling-phase4-design.md](../cache-handling-phase4-design.md)

## Metrics

Phase 4 adds the metrics required by the Stage 4 architecture:

| Metric | Type | Description |
| --- | --- | --- |
| `cache_payload_evictions_total` | counter | Number of hot payload entries evicted by the LRU policy. |
| `cache_protected_root_decisions_total` | counter | Number of policy decisions that considered protected-root state. |

The Prometheus exporter may keep existing `llamacpp_` naming conventions if the server already prefixes cache metrics. In that case the exported names should be:

- `llamacpp_cache_payload_evictions_total`
- `llamacpp_cache_protected_root_decisions_total`

The JSON stats endpoint should use the unprefixed field names because existing cache stats already expose internal names such as `n_evictions`.

## Suggested labels or fields

If the current metrics exporter does not support labels for cache counters, expose separate JSON fields first and keep Prometheus counters unlabelled. Do not add a custom label system only for Phase 4.

Useful JSON fields:

- `resident_payload_bytes`
- `hot_payload_budget_bytes`
- `n_payload_evictions`
- `n_protected_root_decisions`
- `n_protected_root_evictions`
- `n_protected_root_admission_rejections`
- `protected_payload_bytes`
- `unprotected_payload_bytes`
- `n_protected_entries`

If labels are already practical, `cache_protected_root_decisions_total` can use a low-cardinality `decision` label with values such as `skip`, `evict`, `reject`, and `pressure`.

## Log events

Required diagnostic events:

- save rejected because payload bytes exceed the hot budget
- LRU eviction selected an unprotected entry
- protected entry skipped while unprotected entries are available
- protected-root budget pressure detected
- protected entry evicted because protected bytes exceed the budget
- eviction could not satisfy budget because no legal candidates remain

Logs should include namespace id, token count, resident payload bytes, budget bytes, protected state, and use sequence when those fields are available.

## Operator interpretation

High payload eviction counts mean the hot budget is too small for the working set or the workload has little prompt reuse. High protected-root pressure means configured protection is too broad for the budget.

The server should not claim protected roots are pinned. Documentation and logs should use "protected" or "higher retention priority", not "pinned forever".

## Compatibility with existing metrics

Existing cache hit, miss, restore failure, entry count, and size metrics remain valid. Phase 4 should not rename them.

If an existing `cache_evictions_total` counter already exists, keep it for compatibility and define it as a broader cache eviction count. `cache_payload_evictions_total` becomes the Stage 4-specific counter for hot payload eviction.

