# Phase 6 design: cold layer and asynchronous I/O - Part 5: Validation, diagnostics, and observability

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Startup validation

The following checks must run at startup, before the server accepts requests, when cold store configuration is present.

| Check | Failure behavior |
| --- | --- |
| Cold store root path is provided and non-empty | Log diagnostic and abort server startup |
| Cold store root path exists as a directory | Log diagnostic and abort server startup |
| Cold store root directory is writable by the server process | Log diagnostic and abort server startup |
| Worker thread creation succeeds | Log diagnostic and abort server startup |
| `--cache-ram` is set to a positive value when hybrid mode is enabled | Log diagnostic and abort server startup (inherited from Stage 4, revalidated here) |

Startup failures must emit a message that identifies the specific check that failed and the configured value that caused the failure. The message must be sufficient for an operator to correct the configuration without consulting source code.

If cold store configuration is absent, none of the cold-specific startup checks run. The server starts in Stage 5 behavior with no cold layer.

## Checksum mismatch handling

Checksum mismatch is detected during promotion validation in the I/O worker.

Required behavior:

- Log a diagnostic at error severity that includes `payload_id`, `cold_ref`, which side failed (`header`, `target`, or `draft`), and the failure reason.
- Mark the descriptor `evicted` in the completion callback.
- Do not return partial payload bytes to the controller.
- Do not attempt to repair or re-derive checksums from file content.
- Increment `cache_payload_promotions_total` with a `failure_reason=checksum_mismatch` label or equivalent structured attribute.
- Cold file disposition: retain for operator inspection by default; the implementation may provide an option to delete on mismatch, but deletion must not be the default.

## Version mismatch handling

Format version mismatch is detected when the cold file header's `format_version` field is not a value the current implementation supports.

Required behavior:

- Log a diagnostic at error severity that includes the file's `format_version` and the range of supported versions.
- Mark the descriptor `evicted`.
- Do not attempt to parse a header or payload layout from an unsupported version.
- If the format version is newer than all supported versions, the diagnostic must note that the file was likely created by a newer server build.
- If the format version is zero or invalid, the diagnostic must note that the file may be corrupt or not a cold cache payload.

## Demotion failure handling

| Failure mode | Required behavior |
| --- | --- |
| Cold store not writable at write time | Emit diagnostic with path and OS error; revert or evict; increment demotion failure counter |
| Insufficient disk space | Emit diagnostic; evict without cold write; increment demotion failure counter |
| Atomic rename fails | Remove staging file; emit diagnostic; revert or evict |
| Work queue full at enqueue | Emit diagnostic; apply immediate eviction if hot budget requires it |
| Descriptor already in `demoting` state | Do not enqueue again; log diagnostic and skip |

Demotion failures must never leave a descriptor in an ambiguous state. The descriptor must be either `hot` (bytes retained) or `evicted` (bytes gone) after any failure path.

## Promotion failure handling

| Failure mode | Required behavior |
| --- | --- |
| Cold file not found | Mark `evicted`; emit diagnostic with `cold_ref`; increment promotion failure counter |
| Header checksum mismatch | Mark `evicted`; emit diagnostic; retain cold file for inspection |
| Payload checksum mismatch | Mark `evicted`; emit diagnostic; retain cold file for inspection |
| format_version unsupported | Mark `evicted`; emit diagnostic |
| `payload_id` mismatch in file | Mark `evicted`; emit diagnostic noting possible file collision or corruption |
| `pair_state` mismatch in file | Mark `evicted`; emit diagnostic |
| Work queue full at enqueue | Leave descriptor `cold`; fall back current request; emit diagnostic |

## Metrics

Stage 6 must add or extend the following metrics. Metric naming follows the established pattern from Stage 4 and Stage 5.

### Counters

| Metric | Description |
| --- | --- |
| `cache_payload_demotions_total` | Number of demotion operations completed (including failed). A `result` label distinguishes `success` from `failure`. |
| `cache_payload_promotions_total` | Number of promotion operations completed (including failed). A `result` label and a `failure_reason` label provide detail for failures. |
| `cache_payload_cold_evictions_total` | Number of cold descriptors moved to `evicted` state (cold file deleted or invalidated without a promotion). |

### Histograms or gauges

| Metric | Description |
| --- | --- |
| `cache_cold_restore_latency_seconds` | Latency from promotion enqueue to hot descriptor available. Measured as a histogram with implementation-defined buckets. |
| `cache_cold_payload_bytes` | Current total bytes of demoted payloads resident in cold storage. Updated when demotion succeeds or a cold descriptor is evicted. |
| `cache_hot_payload_count` | Count of descriptors with `residency_state == hot`. Extended from Stage 5 to reflect Stage 6 transitions accurately. |
| `cache_cold_payload_count` | Count of descriptors with `residency_state == cold`. New in Stage 6. |

### Existing metrics extended by Stage 6

- `cache_payload_evictions_total` from Stage 4 continues to count hot payloads removed without demotion. It must not count payloads that are demoted to cold rather than discarded.
- `cache_descriptor_validation_failures_total` from Stage 5 must be incremented on cold file integrity failures during promotion.

## Diagnostic log messages

All log messages must follow the server logging style and must not include serialized payload bytes, full filesystem paths beyond the configured root, or user-supplied request content.

Recommended fields per log message:

- severity level
- cache mode
- `payload_id`
- `residency_state` before and after the transition
- `pair_state`
- task type (`demotion` or `promotion`)
- failure reason when applicable
- worker thread identifier if the implementation logs worker-side events

Diagnostic severity levels:

- `error`: any integrity failure, startup validation failure, or state transition that results in a lost payload
- `warning`: demotion of a protected root, work queue full, cold file retained after failure
- `debug`: normal demotion enqueue, promotion enqueue, successful transition

Do not log diagnostic messages at `error` for normal promotion fallback. A promotion that fails because the descriptor was legitimately evicted (cold file already deleted by cleanup) is a warning, not an error, if the controller detects the eviction before enqueuing.
