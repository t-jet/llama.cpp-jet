# Phase 3 Design: Non-Destructive Exact Blob Cache - Part 5: Metrics and Observability

Source: [../cache-handling-phase3-design.md](../cache-handling-phase3-design.md)

## Metrics Strategy

Stage 3 implements the foundation for cache observability by exposing metrics through the existing `/metrics` endpoint (when `--metrics` is enabled) and the `/cache/stats` endpoint added in Stage 2.

## Core Metrics

### 1. Exact Blob Hits and Misses

**Metric**: `cache_exact_blob_hits_total`

- **Type**: Counter
- **Description**: Total number of successful exact full-state blob cache hits
- **Incremented**: When `load_slot()` finds an exact match and successfully restores state
- **Stage 3 semantics**: Counts only exact matches; partial matches are rejected

**Metric**: `cache_exact_blob_misses_total`

- **Type**: Counter
- **Description**: Total number of cache lookup attempts that did not find a suitable match
- **Incremented**: When `load_slot()` returns false due to no match or partial match rejected
- **Includes**: Both "no candidate found" and "candidate found but rejected" cases

### 2. Restore Failures

**Metric**: `cache_restore_failures_total`

- **Type**: Counter
- **Description**: Total number of failed state restoration attempts
- **Incremented**: When state deserialization returns wrong byte count or other error
- **Critical**: High values indicate data integrity issues or context compatibility problems

### 3. Cache Entry Count

**Metric**: `cache_entries_current`

- **Type**: Gauge
- **Description**: Current number of entries in the cache
- **Updated**: On every save (increment) and eviction (decrement)

### 4. Cache Size Metrics

**Metric**: `cache_size_bytes_current`

- **Type**: Gauge
- **Description**: Current cache size in bytes (sum of all entry sizes)
- **Calculated**: By summing `entry.size()` for all entries

**Metric**: `cache_size_mib_current`

- **Type**: Gauge (derived)
- **Description**: Current cache size in MiB (bytes / 1048576)
- **Useful for**: Human-readable capacity monitoring

### 5. Eviction Counter

**Metric**: `cache_evictions_total`

- **Type**: Counter
- **Description**: Total number of entries evicted due to memory pressure
- **Incremented**: When `evict_lru()` removes an entry
- **Note**: Protected roots are not evicted, so this only counts non-protected entries

## Prometheus Metrics Export Format

When `--metrics` is enabled, expose metrics in Prometheus text format via `/metrics` endpoint:

```prometheus
# HELP cache_exact_blob_hits_total Number of exact full-state blob cache hits
# TYPE cache_exact_blob_hits_total counter
cache_exact_blob_hits_total 127

# HELP cache_exact_blob_misses_total Number of cache lookup misses
# TYPE cache_exact_blob_misses_total counter
cache_exact_blob_misses_total 23

# HELP cache_restore_failures_total Number of failed state restoration attempts
# TYPE cache_restore_failures_total counter
cache_restore_failures_total 2

# HELP cache_entries_current Current number of cache entries
# TYPE cache_entries_current gauge
cache_entries_current 15

# HELP cache_size_bytes_current Current cache size in bytes
# TYPE cache_size_bytes_current gauge
cache_size_bytes_current 52428800

# HELP cache_evictions_total Number of entries evicted due to memory pressure
# TYPE cache_evictions_total counter
cache_evictions_total 8
```

## JSON Stats via `/cache/stats`

The `/cache/stats` endpoint (added in Stage 2) returns detailed statistics in JSON format:

```json
{
  "type": "hybrid",
  "size_bytes": 52428800,
  "size_mib": 50.0,
  "n_tokens": 12500,
  "n_entries": 15,
  "n_hits": 127,
  "n_misses": 23,
  "n_evictions": 8,
  "n_restore_failures": 2,
  "namespaces": {
    "model_v1_config_abc": 10,
    "model_v1_config_xyz": 5
  }
}
```

**Field descriptions**:

- `type`: Always "hybrid" for hybrid cache controller
- `size_bytes`: Total size of all cached entries in bytes
- `size_mib`: Total size in MiB (for readability)
- `n_tokens`: Total number of tokens across all cached entries
- `n_entries`: Number of cache entries currently stored
- `n_hits`: Total cache hits since server start
- `n_misses`: Total cache misses since server start
- `n_evictions`: Total evictions since server start
- `n_restore_failures`: Total restore failures since server start
- `namespaces`: Per-namespace entry counts (for multi-model scenarios)

## Diagnostic Logging

### Log Levels and Events

**DEBUG level** (`SRV_DBG`):

- Cache lookups: "hybrid cache: no matching entry found"
- Successful saves: "hybrid cache: saved entry with N tokens (X KiB)"
- Successful loads: "hybrid cache: restored N tokens from cache (use_count=X)"
- Deduplication: "hybrid cache: updated existing entry with N tokens"
- Evictions: "hybrid cache: evicted entry with N tokens (LRU, last_used=X)"

**WARNING level** (`SRV_WRN`):

- Rejected empty slots: "hybrid cache: cannot save empty slot"
- Partial match rejections: "hybrid cache: partial match rejected (N vs M tokens)"

**ERROR level** (`SRV_ERR`):

- Restore failures: "hybrid cache: target state restore failed (X bytes restored, Y expected)"
- Missing state data: "hybrid cache: entry has no target state data"
- Integrity violations: "hybrid cache: state checksum mismatch"

### Log Output Examples

```
[2026-05-25 14:32:15] DEBUG - hybrid cache: no matching entry found
[2026-05-25 14:32:16] DEBUG - hybrid cache: saved entry with 128 tokens (24.5 KiB)
[2026-05-25 14:32:17] DEBUG - hybrid cache: restored 128 tokens from cache (use_count=2)
[2026-05-25 14:32:18] WARN  - hybrid cache: partial match rejected (64 vs 128 tokens)
[2026-05-25 14:32:19] ERROR - hybrid cache: target state restore failed (4096 bytes restored, 8192 expected)
```

## Monitoring and Alerting Guidance

### Key Performance Indicators

**Cache Hit Rate**:

```
hit_rate = cache_exact_blob_hits_total / (cache_exact_blob_hits_total + cache_exact_blob_misses_total)
```

- **Target**: ≥50% for repeated prompt scenarios
- **Degradation threshold**: <20% may indicate ineffective caching

**Restore Success Rate**:

```
restore_success_rate = 1 - (cache_restore_failures_total / cache_exact_blob_hits_total)
```

- **Target**: ≥99% (failures should be rare)
- **Critical threshold**: <95% indicates data integrity or compatibility issues

**Cache Utilization**:

```
utilization = cache_size_bytes_current / cache_size_limit_bytes
```

- **Healthy range**: 60-90% (cache is well-used but not thrashing)
- **Over-pressure**: >95% may cause excessive evictions

### Recommended Alerts

1. **High restore failure rate**: Alert if `restore_success_rate < 95%` over 5-minute window
2. **Cache thrashing**: Alert if `cache_evictions_total` increases by >10 per minute
3. **Zero hit rate**: Alert if `hit_rate = 0%` after 100+ lookups (cache ineffective)
4. **Memory leak**: Alert if `cache_size_bytes_current` exceeds configured limit by >10%

## Implementation Notes

### Metrics Collection in Code

All metrics are updated within the `hybrid_cache_controller` class methods:

- `n_hits++` in `load_slot()` on successful match
- `n_misses++` in `load_slot()` on no match or rejected match
- `n_restore_failures++` in `load_slot()` on deserialization error
- `n_evictions++` in `evict_lru()` after removing entry

Statistics are exposed via `get_stats()` method, which is called by:

- `/cache/stats` HTTP endpoint handler
- `/metrics` Prometheus exporter (if enabled)

### Thread Safety Considerations

Stage 3 does not add explicit locking because:

- llama-server's existing task queue serializes cache operations
- All cache mutations happen on the main server thread
- Stage 3 focuses on correctness; performance optimization deferred to later stages

If future stages introduce concurrent cache access, mutex protection must be added around:

- `entries` list modifications
- `lru_index` updates
- `prefix_index` updates
- Statistics counters

---

**Next**: [Part 6: Acceptance Criteria](./part-06-acceptance-criteria.md)
