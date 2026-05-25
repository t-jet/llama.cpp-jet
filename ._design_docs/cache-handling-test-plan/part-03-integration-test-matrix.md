# Cache handling test plan - Part 3: integration test matrix

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Server defaults for integration tests

Use a helper that starts `llama-server` with these defaults unless a test overrides them:

```powershell
--model <resolved model path>
--host 127.0.0.1
--port <free port>
--ctx-size 512
--parallel 2
--cont-batching
--kv-unified
--server-slots
--cache-ram 100
--temp 0
--seed 42
--metrics
```

Each test should stop the server in `finally` cleanup and collect stderr, stdout, `/metrics`, and the final response JSON.

## Matrix

| ID | Scenario | Mode | Expected result |
| --- | --- | --- | --- |
| C01 | Default cache mode | no `--cache-mode` | Server starts; `/metrics` has `llamacpp_cache_*{mode="legacy"}`; `/health` is `{"status":"ok"}`. |
| C02 | Explicit legacy mode | `legacy` | Server starts; cache metrics use `mode="legacy"`. |
| C03 | Explicit hybrid mode | `hybrid` | Server starts; cache metrics use `mode="hybrid"`. |
| C04 | Invalid cache mode | invalid value | Process exits nonzero and prints `invalid cache mode`. |
| C05 | `/cache/stats` absent | both modes | `GET /cache/stats` returns 404. |
| C06 | Metrics disabled | hybrid, no `--metrics` | `/metrics` returns the server's not-supported error. Cache behavior should still work. |
| C10 | Legacy compatibility smoke | legacy | Same prompt reuse succeeds and existing `cache_prompt` behavior remains valid. Do not require hybrid hit counters. |

## Notes on observable assertions

Prefer stable signals:

- HTTP status codes.
- `timings.cache_n`.
- Prometheus cache counters.
- Log messages for cache mode, hit, miss, eviction, and restore failure.

Avoid assertions on exact generated text. Cache tests only need successful generation and cache state evidence.
