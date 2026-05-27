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
