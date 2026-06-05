# Stage 9 design: pairing, cold store, metrics, and diagnostics -- Part 4

Source: [../cache-handling-phase9-design.md](../cache-handling-phase9-design.md)

## Target/draft pairing

Stage 9 inherits the Stage 5 pair-state contract.

| Runtime shape | Descriptor pair state | Stage 9 behavior |
| --- | --- | --- |
| No draft context | `target_only` | Checkpoint and exact descriptors contain only target state. Draft descriptors are rejected. |
| Separate draft model | `target_and_draft` | Checkpoint and exact descriptors serialize, promote, restore, demote, and evict target plus draft together. |
| MTP from target model | `target_and_draft` | Namespace records target-derived MTP context. Reuse from normal separate-draft entries is forbidden. |
| MTP from separate draft model | `target_and_draft` | Namespace records draft model identity and MTP context discriminator. Reuse from non-MTP draft entries is forbidden. |

The descriptor pair state remains binary. The namespace carries the richer
speculative-mode identity.

## Cold store interaction

Checkpoint payloads use the same hot and cold residency machinery as exact
blob payloads.

Required behavior:

- exact blobs and checkpoint payloads share the hot-payload budget
- checkpoint payloads are eligible for usage-based cold demotion
- cold promotion validates descriptor version and checksum before restore
- cold demotion writes versioned payloads through the Stage 6 atomic write and
  rename path
- cleanup deletes checkpoint payloads only after descriptor ownership checks
  prove no retained branch or descendant owns them
- `server_context` does not perform synchronous disk reads or writes for
  checkpoint promotion or demotion

If the cold layer is disabled or unavailable, the controller can still keep hot
checkpoint payloads and evict them under pressure. It must not claim a cold
restore path exists.

## Residency policy

The residency policy ranks exact blobs and checkpoint payloads together under
the hot-payload budget. For checkpoint-dependent profiles, policy weighting may
favor checkpoint payloads because they preserve branch continuity. Protection
raises retention priority but does not bypass byte accounting.

Policy decisions must preserve:

- target/draft pair integrity
- metadata-only topology after payload eviction
- prepared-boundary placement metadata
- explicit diagnostics when protected or checkpoint-dependent working sets
  exceed budget

Branch pruning remains Stage 8 behavior. Stage 9 does not add a new pruning
policy.

## Metrics

Stage 9 adds these required metrics to the existing Prometheus endpoint when
metrics are enabled:

| Metric | Type | Labels | Meaning |
| --- | --- | --- | --- |
| `cache_checkpoint_restores_total` | Counter | `profile`, `payload_residency`, `pair_state`, `result` | Restore attempts that selected a checkpoint path. |
| `cache_checkpoint_hits_total` | Counter | `profile`, `payload_residency`, `pair_state` | Valid checkpoint candidates accepted as cache hits. |

Stage 9 also updates existing metrics from earlier stages:

- `cache_payload_promotions_total` for checkpoint cold-to-hot promotion
- `cache_payload_demotions_total` for checkpoint hot-to-cold demotion
- `cache_payload_evictions_total` for checkpoint payload eviction
- `cache_restore_failures_total` for checkpoint restore failures by reason
- `cache_fallback_restores_total` for checkpoint fallback by reason
- `cache_validation_mismatches_total` for boundary or token validation mismatch
- `cache_node_rematerializations_total` when a metadata-only checkpoint node is rebuilt

Metrics must avoid prompt text, marker labels, file paths, or serialized state
contents.

## Diagnostics

Required diagnostic events:

- workload profile selected
- profile detection failure or unsupported runtime shape
- checkpoint admission accepted or rejected
- boundary metadata absent, degraded, or invalid
- checkpoint candidate rejected by namespace, pair state, version, checksum, or
  boundary validation
- checkpoint restore selected, promoted, applied, or failed
- exact blob used as checkpoint-dependent accelerator or root
- cold promotion or demotion failed
- protected checkpoint working set exceeds budget
- fallback restore chosen with reason

Diagnostics should use existing server logging conventions. They must not add a
new cache-specific HTTP endpoint in Stage 9.

## Failure handling

Failure handling follows the existing fail-safe contract:

- reject unsafe checkpoint candidates before live state mutation
- promote cold paired payloads before applying either side
- invalidate corrupt descriptors without refreshing usage as a hit
- recompute when checkpoint restore is unavailable
- preserve legacy mode behavior when hybrid mode is disabled

When a failure happens after live restore begins, the restore applier must use
the Stage 5 transactional restore contract. A partial target/draft restore is a
blocking implementation defect.
