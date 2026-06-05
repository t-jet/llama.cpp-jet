# Cache handling test plan - Part 4: edge and negative scenarios

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Input and mode validation

| ID | Scenario | Expected result |
| --- | --- | --- |
| N01 | `--cache-mode` value is not `legacy` or `hybrid` | Startup fails with a clear error. |
| N02 | Cache disabled with `--cache-ram 0` | No cache controller is active; requests still succeed. |
| N03 | `--cache-idle-slots` without `--kv-unified` | Server disables idle-slot caching or rejects the combination according to existing server behavior. |
| N04 | Missing model path | Startup fails before cache setup can be treated as valid. |

## HTTP surface

| ID | Scenario | Expected result |
| --- | --- | --- |
| N05 | `GET /cache/stats` | 404. This is the expected upstream target. |
| N06 | `GET /health` | Response is exactly `{"status":"ok"}`. Do not add cache fields. |
| N07 | `GET /metrics` without metrics enabled | The endpoint returns a not-supported error; cache tests that need counters must enable metrics explicitly. |

## State Serialization and Restore Failures

| ID | Scenario | Expected result |
| --- | --- | --- |
| N08 | Corrupted state data | Requires fault injection or a code-level harness that can make restore fail after cache lookup. Verify `llamacpp_cache_restore_failures_total{mode="hybrid"}` increments. Slot state resets. Request continues without cache. Log the restore failure. |
| N09 | Oversized entry rejection | Hybrid mode, entry size exceeds `--cache-ram` budget. Verify entry rejected with WARNING log. No cache entry created. `/metrics` shows no change in entry count. |
| N10 | Zero-token slot save (duplicate) | Same as H09. Attempt to save slot with 0 tokens. Log warning, no entry created. Verify idempotent: multiple attempts don't corrupt cache state. |
| N11 | Invalid compatibility key | Hybrid mode with mismatched namespace on load attempt. Should never happen in correct implementation. Document assumption: namespace validation prevents this. |
| N12 | Metrics counter overflow | Not practical to test. Document assumption: 64-bit counters sufficient for production lifetime. Counters may wrap after 2^64 operations. |
| N13 | Cache controller factory failure | Invalid `--cache-mode` value (covered by N01). Document other factory failure modes: nullptr contexts, invalid limits. |
| N14 | Protected oversized admission | Requires a trusted protected entry that reaches cache admission with serialized target plus draft payload larger than the configured resident byte budget. HTTP/parser rejection before admission is `BLOCKED`. Save is rejected; protection does not override `--cache-ram`. Capture warning diagnostics and protected admission rejection evidence from stats or logs. |
| N15 | Failed restore recency | Requires fault injection or a code-level harness unless an existing safe mechanism can make restore fail after lookup. Restore failure counter increments, request falls back safely, and the candidate's recency is not refreshed before the next eviction. |

## Stage 5 Descriptor and Transaction Failures

| ID | Scenario | Expected result |
| --- | --- | --- |
| N16 | Unsupported descriptor version or payload kind | Requires focused harness. Restore validation rejects the descriptor, increments descriptor validation failure and fallback metrics, and does not report a hit. |
| N17 | Store reference, hot record, or owner mismatch | Requires focused harness. Mismatched `store_ref`, missing hot payload record, payload record ID mismatch, or descriptor owner mismatch is rejected before live mutation. |
| N18 | Size, checksum, or target presence mismatch | Requires focused harness. Target size zero, target size mismatch, target checksum mismatch, draft size mismatch, or draft checksum mismatch is rejected. |
| N19 | Invalid draft presence | Requires focused harness. `target_only` with draft bytes or draft checksum is rejected; `target_and_draft` without draft bytes or draft checksum is rejected. |
| N20 | Runtime pair-state mismatch | Requires focused harness or draft fixture. Runtime and descriptor pair state must match. A mismatch increments pairing violation and fallback counters, with no hit or recency refresh. |
| N21 | Evicted or cold residency | Requires focused harness. `evicted` and Stage 5 unsupported `cold` descriptors are not restorable. If the descriptor remains for diagnostics, lookup still rejects it. |
| N22 | Draft apply failure after target apply | Requires fault injection. Rollback restores the exact pre-restore state, including clearing target or draft sides that were empty before restore. No hit, usage refresh, or recency refresh is recorded. |
| N23 | Unsupported empty-side clear | Requires fault injection. The clear capability is checked before applying cached target bytes; if unsupported, restore fails closed and leaves live state untouched. |
| N24 | Target-only entry reused under draft runtime | Requires focused harness or cross-run cache persistence. A no-draft `target_only` entry must not restore under normal separate draft mode or either `draft-mtp` mode. |
| N25 | Normal draft entry reused under MTP runtime | Requires focused harness or cross-run cache persistence. A normal separate draft-model `target_and_draft` entry must not restore under target-derived or separate-model `draft-mtp`, even when draft model dimensions match. |
| N26 | MTP entry reused under normal draft runtime | Requires focused harness or cross-run cache persistence. A `draft-mtp` entry must not restore under normal separate draft model mode. |
| N27 | Draft alias spelling changes namespace | Hybrid with the same target and draft files. `--model-draft` and `--spec-draft-model` must resolve to the same normal separate draft mode namespace; alias spelling alone must not force a miss. |
| N28 | Legacy path altered by draft flags | Legacy mode with draft flags should preserve legacy prompt-cache behavior and public HTTP shape. Do not require descriptor-owned hybrid payload evidence in this mode. |
