# Cache handling test plan - Part 2: current integration coverage

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope boundary

This plan is for integration tests only. It assumes unit and focused C++ tests are handled by a separate test plan or by the normal project test suite.

Do not use this document to track:

- `tests/test-cache-controller.cpp`
- focused cache-controller line coverage
- pure prefix-index, LRU, metadata, or compatibility-key helper tests
- adopted Jinja fixture tests that do not start `llama-server`

Those tests are useful, but they are not integration coverage.

## Existing integration coverage

Current integration-level evidence from the implementation reports:

| Source | Current evidence |
| --- | --- |
| `tools/server/tests/unit/test_cache_modes.py` | Starts `llama-server`, checks invalid `--cache-mode`, stable `/health`, missing `/cache/stats`, cache metrics under `/metrics`, and keeps repeated hybrid restore as xfail. Despite the path name, this is server integration coverage. |
| `tools/server/tests/test_cache_phase2_integration.sh` | Manual smoke script against a running server for `/health`, missing `/cache/stats`, and cache metrics. It does not start the server itself and should not be treated as unattended coverage until wrapped by a runner. |
| Phase 2 implementation report | `pytest tools/server/tests/unit/test_cache_modes.py -q` passed with `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`: 2 passed, 1 xfailed. |

## Current integration gap

The repeated hybrid restore test is still marked `xfail`:

```text
Hybrid exact-blob restore is implemented below the controller, but server-slot reuse does not expose a cache hit yet.
```

Do not count hybrid runtime restore as covered until a model-backed server test passes without xfail.

## Integration coverage needed

Model-backed integration tests must cover behavior that depends on real `llama_context` state and the server scheduler:

- target-only save/load round trip
- repeated hybrid restore from the same cached entry
- target/draft paired save/load when a draft model is configured
- restore failure after target or draft restore begins
- idle-slot save/load through the scheduler path
- metrics changing after real cache save, hit, miss, eviction, and restore failure
- stable public HTTP surface: `/health`, `/metrics`, and missing `/cache/stats`

## Coverage reporting

Do not report unit-test line coverage in this integration plan.

The implementation reports mention an 85% historical estimate and a later 95.52% focused cache-controller run. Those numbers belong to focused/unit coverage. They do not prove server integration behavior or real `llama_state_seq_*` restore.

Integration reports should instead list:

- server binary path
- model path
- command line used to start the server
- HTTP requests sent
- response status and relevant response fields
- metrics before and after cache events
- pass, fail, skip, and xfail counts
