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

## Integration coverage needed

Model-backed integration tests must cover behavior that depends on real `llama_context` state and the server scheduler:

- target-only save/load round trip
- repeated hybrid restore from the same cached entry
- target/draft paired save/load when a draft model is configured
- restore failure after target or draft restore begins
- idle-slot save/load through the scheduler path
- metrics changing after real cache save, hit, miss, eviction, and restore failure
- resident payload byte pressure from `--cache-ram`
- deterministic LRU ordering after successful restore and equivalent-entry refresh
- no recency refresh after failed restore
- protected-root priority, protected fallback eviction, and protected admission rejection
- Stage 4 metrics for payload eviction and protected-root decisions
- stable public HTTP surface: `/health`, `/metrics`, and missing `/cache/stats`

## Coverage reporting

Do not report unit-test line coverage in this integration plan. Unit coverage belongs to focused/unit coverage reports and does not prove server integration behavior.

Integration reports should instead list:

- server binary path
- model path
- command line used to start the server
- HTTP requests sent
- response status and relevant response fields
- metrics before and after cache events
- pass, fail, skip counts
