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

| ID | Scenario | Mode | Coverage status | Expected result |
| --- | --- | --- | --- | --- |
| C01 | Default cache mode | no `--cache-mode` | Covered by Python test | Server starts; `/metrics` has `llamacpp_cache_*{mode="legacy"}`; `/health` is `{"status":"ok"}`. |
| C02 | Explicit legacy mode | `legacy` | Covered by mode and metrics checks | Server starts; cache metrics use `mode="legacy"`. |
| C03 | Explicit hybrid mode | `hybrid` | Covered by Python xfail setup and shell smoke test | Server starts; cache metrics use `mode="hybrid"`. |
| C04 | Invalid cache mode | invalid value | Covered by Python test | Process exits nonzero and prints `invalid cache mode`. |
| C05 | `/cache/stats` absent | both modes | Covered by Python and shell tests | `GET /cache/stats` returns 404. |
| C06 | Metrics disabled | hybrid, no `--metrics` | Planned | `/metrics` returns the server's not-supported error. Cache behavior should still work. |
| C07 | Target-only hybrid restore | hybrid | Open gap, currently xfailed | Save a prompt from slot 0, displace or erase the slot, request a continuation with the saved prompt as prefix, and assert `timings.cache_n > 0`. |
| C08 | Repeated non-destructive restore | hybrid | Open gap, currently xfailed | Run C07 twice against the same saved prefix. Both restores report `cache_n > 0`; cache entry count remains nonzero after both hits. |
| C09 | Hybrid miss on divergent prefix | hybrid | Planned model-backed test | Save prompt A, request prompt B with a similar but divergent prefix, and assert miss metrics increase while response still succeeds. |
| C10 | Legacy compatibility smoke | legacy | Keep as integration regression | Same prompt reuse succeeds and existing `cache_prompt` behavior remains valid. Do not require hybrid hit counters. |
| C11 | Idle-slot save/load path | hybrid with `--cache-idle-slots` | Planned model-backed test | A completed idle slot is saved through `cache_ctrl`; a later compatible request can restore from cache. |
| C12 | Multi-slot parallel requests | hybrid | Planned model-backed test | Two slots run different prompts without corrupting each other's cache state. Both responses succeed and metrics remain parseable. |
| C13 | Metadata transport for chat | hybrid | Integration hook planned | Chat request with system and user messages produces a successful response; server logs, metrics, or an integration-only debug build show degraded metadata reaches the task and saved entry. |
| C14 | Minimal metadata for completion | hybrid | Code path present; integration assertion planned | `/completion` request succeeds with fallback/minimal metadata and does not require chat boundaries. |
| C15 | Metrics counters change | hybrid | Partly covered for endpoint shape; runtime counter movement planned | Save, miss, hit, and eviction scenarios move the matching `llamacpp_cache_*` counters in the expected direction. |

## Notes on observable assertions

Prefer stable signals:

- HTTP status codes.
- `timings.cache_n`.
- Prometheus cache counters.
- Log messages for cache mode, hit, miss, eviction, and restore failure.

Avoid assertions on exact generated text. Cache tests only need successful generation and cache state evidence.

## Current xfail target

Promote the existing xfailed Python test to a normal test only after C07 and C08 pass reliably with a local model. Until then, keep the xfail as a visible runtime gap.
