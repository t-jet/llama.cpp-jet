# Hybrid cache operator notes

The hybrid prompt cache is an opt-in server mode:

```shell
llama-server --cache-mode hybrid --cache-ram 8192
```

Use `--cache-mode legacy` or omit `--cache-mode` to keep the default legacy
cache behavior. Use `--cache-ram 0` to disable prompt cache storage.

## Budgets

`--cache-ram N` sets the hot payload budget in MiB. `-1` means no hot payload
limit, and `0` disables the prompt cache. Very small budgets can force safe
recompute because protected roots, exact blobs, and checkpoints may not fit.

Branch metadata has an internal soft limit used by focused tests and future
tuning. When metadata pressure occurs, the cache prunes metadata-only leaves
that have no slot references and are not protected roots.

## Cold store

`--cache-cold-path PATH` enables cold payload storage for hybrid mode. The path
must be an existing writable directory. The server normalizes the root, rejects
root-directory use, keeps payload and staging files under that root, and derives
file names from internal payload IDs only.

The cold store validates the file magic, format version, payload ID, pair state,
payload sizes, and checksums before using bytes. Invalid or missing cold files
fall back to recompute and mark the descriptor invalid or evicted as appropriate.

The cold store does not guarantee cross-restart restore. Operators should treat
the directory as runtime cache data and may delete it when the server is stopped.

## Workload profiles

The server chooses the workload profile from the loaded runtime:

- `plain_transformer`: exact blob restore is preferred.
- `checkpoint_dependent`: checkpoint payloads are used when supported by the
  model and prompt boundary metadata.
- `unsupported`: hybrid reuse is avoided and the request recomputes.

Clients do not select the workload profile.

## Restore behavior

Exact blob restore reuses a full prompt state when the namespace, tokens, pair
state, and descriptor checks match. Checkpoint restore reuses checkpoint payloads
for checkpoint-dependent workloads. Target and draft payloads restore as a pair;
partial paired restore is a defect and must fall back transactionally.

Protected roots are driven by server policy and prompt metadata, not by raw
client-provided marker strings.

## Metrics and diagnostics

Use `--metrics` and scrape `/metrics`. Hybrid cache metrics use bounded labels
and escape Prometheus label values. Useful groups include:

- `llamacpp_cache_hits_total`, `llamacpp_cache_misses_total`, and
  `llamacpp_cache_fallback_restores_total`
- `cache_exact_blob_restores_total`,
  `cache_fallback_restores_by_shape_total`, and
  `cache_structured_diagnostics_total`
- `cache_checkpoint_hits_total` and `cache_checkpoint_restores_total`
- `llamacpp_cache_payload_demotions_total` and
  `llamacpp_cache_payload_promotions_total`
- `cache_payload_transitions_total`,
  `cache_payload_evictions_by_shape_total`, and
  `cache_protected_root_decisions_by_shape_total`
- `llamacpp_cache_cold_payload_bytes` and
  `llamacpp_cache_cold_payload_count`
- `cache_branch_pruning_total`,
  `cache_metadata_only_retentions_total`, and
  `cache_validation_mismatches_total`

The public Stage 10 rows keep bounded dimensions:

- `cache_exact_blob_restores_total`: `payload_kind`, `profile`, `pair_state`,
  `residency`, `result`, and `reason`.
- `cache_payload_transitions_total`: `operation`, `payload_kind`,
  `pair_state`, `result`, and `reason`.
- `cache_payload_evictions_by_shape_total`: `payload_kind`, `pair_state`,
  `result`, and `reason`.

Diagnostics use bounded reason values for unsupported configuration, descriptor
validation, cold-store failures, fallback, promotion, demotion, cleanup, and
branch metadata pressure. They must not include prompt text, payload bytes,
checksums, local model paths, or raw cold-store file paths.

## Benchmark evidence

Benchmark reports must classify measurements before execution:

- Public Prometheus: accepted exact/checkpoint hits, fallback count, resident
  bytes, cold transitions, queue pressure, cold latency, and re-materialization
  count.
- Structured log: restore strategy, fallback reason, and unsupported or degraded
  configuration reason.
- Direct stats: rejected candidates and internal restored-token accounting.
- Harness-only evidence: prompt-processing time saved and request latency before
  and after reuse.

Correctness evidence comes before performance claims. If checkpoint fixtures are
not available locally, report focused controller or metrics-exporter substitute
evidence instead of claiming public checkpoint-hit evidence.

## Security limits

Hybrid cache does not replay generated output, does not expose a public cache
inspection endpoint, does not provide a distributed cache, and does not promise
cross-process coherence. Unsafe cold roots, invalid descriptors, unsupported
runtime shapes, and integrity failures prefer recompute with diagnostics over
unsafe reuse.
