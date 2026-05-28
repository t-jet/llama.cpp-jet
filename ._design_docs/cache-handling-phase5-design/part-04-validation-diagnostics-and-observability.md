# Phase 5 design: payload-metadata separation and target/draft pairing - Part 4: Validation, diagnostics, and observability

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Validation rules

Descriptor validation is mandatory before admission and before restore.

Admission validation checks:

- supported descriptor `format_version`
- `payload_kind == exact_blob`
- valid `pair_state`
- target payload exists and matches `target_size_bytes`
- draft payload presence matches `pair_state`
- checksum values match serialized bytes
- `resident_payload_bytes == target_size_bytes + draft_size_bytes`
- `store_ref` points to the hot payload record created for this descriptor
- `owner_entry_id` is set and unique

Restore validation checks:

- descriptor still belongs to the selected cache entry
- descriptor version is supported
- runtime target/draft shape matches `pair_state`
- descriptor is hot, not evicted
- payload bytes exist at `store_ref`
- stored byte sizes and checksums still match
- namespace compatibility already accepted by the controller

Eviction validation checks:

- selected entry owns the descriptor being evicted
- resident byte accounting matches the descriptor
- target and draft sides can be removed in the same controller operation
- post-eviction state cannot be selected as a restore hit

## Failure handling

Every descriptor or pairing failure must fail closed.

| Failure | Required behavior |
| --- | --- |
| unsupported descriptor version | reject descriptor, emit diagnostic, fall back or reject save |
| checksum mismatch | reject restore, mark candidate invalid for the attempt, fall back |
| missing target bytes | reject save or restore |
| missing draft bytes for `target_and_draft` | reject save or restore |
| unexpected draft bytes for `target_only` | reject descriptor as malformed |
| runtime pair mismatch | reject restore and fall back |
| stale or missing `store_ref` | reject restore and fall back |
| target apply failure | restore pre-restore live state if needed, reject restore, and fall back |
| draft apply failure after target apply success | restore pre-restore live state, reject the whole pair, and fall back |
| restore transaction commit failure | restore pre-restore live state, reject hit accounting, and fall back |
| accounting mismatch | block admission or eviction until accounting is corrected |

The controller must not repair malformed descriptors silently. Repair may be a later maintenance feature, but Stage 5 behavior is reject and diagnose.

## Diagnostics

Logs should use the existing server logging style and include enough context to debug without dumping payload bytes.

Recommended diagnostic fields:

- cache mode
- entry id
- payload id
- payload kind
- pair state
- runtime draft presence
- descriptor version
- residency state
- target and draft byte sizes
- validation failure reason
- restore transaction phase, such as validation, target_apply, draft_apply, commit, or rollback
- rollback or scratch-staging result
- fallback reason

Do not log serialized state bytes, checksums if they are treated as sensitive in the implementation, request text, or filesystem paths derived from future cold storage.

## Metrics

Stage 5 can extend the existing metrics path used by Stage 4. Metric naming should stay compatible with the architecture observability list.

Required counters or equivalent stats:

- `cache_descriptor_validation_failures_total`
- `cache_pairing_violations_total`
- `cache_restore_failures_total` with descriptor and pairing reasons included in labels or structured stats
- `cache_fallback_restores_total`
- `cache_payload_evictions_total`
- restore transaction staging, apply, or commit failures, either as a dedicated counter or as reasoned `cache_restore_failures_total` entries

Useful gauges or stats:

- hot payload descriptors
- hot payload bytes
- evicted descriptors retained for diagnostics, if the implementation keeps them
- target-only descriptor count
- target-plus-draft descriptor count

Metrics must not count a failed descriptor restore as a successful exact-blob hit. A failed draft apply after target apply success must increment restore failure and fallback metrics, and it must not refresh recency or usage for the failed candidate.

## Security notes

Stage 5 does not add filesystem persistence, but descriptors are still security-sensitive because they describe serialized runtime state. The security review for this stage must cover:

- malformed descriptor rejection
- version handling
- checksum integrity behavior
- target/draft mismatch handling
- unsafe configuration combinations
- accidental disclosure in logs or metrics

Cold-store path handling remains Stage 6 work, but Stage 5 must avoid descriptor shapes that would force unsafe path handling later.
