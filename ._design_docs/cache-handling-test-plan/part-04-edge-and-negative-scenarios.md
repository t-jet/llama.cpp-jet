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
