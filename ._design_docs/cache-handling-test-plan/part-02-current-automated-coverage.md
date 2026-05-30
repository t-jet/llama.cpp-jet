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

For Stage 5, focused controller or fault-injection tests may be cited as supplemental evidence for internal failure preconditions that public HTTP cannot create. Report them as focused evidence, not as model-backed integration coverage.

## Integration coverage needed

Model-backed integration tests must cover behavior that depends on real `llama_context` state and the server scheduler:

- target-only save/load round trip
- repeated hybrid restore from the same cached entry
- target/draft paired save/load when a normal separate draft model is configured
- draft context mode namespace isolation for no draft, normal separate draft model, target-derived `draft-mtp`, and separate-model `draft-mtp`
- restore failure after target or draft restore begins
- idle-slot save/load through the scheduler path
- metrics changing after real cache save, hit, miss, eviction, and restore failure
- resident payload byte pressure from `--cache-ram`
- deterministic LRU ordering after successful restore and equivalent-entry refresh
- no recency refresh after failed restore
- protected-root priority, protected fallback eviction, and protected admission rejection
- Stage 4 metrics for payload eviction and protected-root decisions
- descriptor-owned exact blob payload save/load shape
- descriptor validation for version, kind, size, checksum, store reference, owner, residency, and target/draft pair state
- pair-state/runtime mismatch rejection
- paired target/draft eviction and byte accounting
- transactional restore failure behavior: no hit, no usage or recency refresh, fallback counted, and pre-restore state restored
- exact empty-preimage rollback and unsupported clear preflight
- Stage 5 metrics for descriptor validation failures, pairing violations, fallback restores, hot descriptors, and evicted descriptors
- stable public HTTP surface: `/health`, `/metrics`, and missing `/cache/stats`
- cold store opt-in behavior (server works identically to Stage 5 when `--cache-cold-path` is absent)
- demotion: hot payloads are demoted to cold when `--cache-cold-path` is configured and `--cache-ram` budget is exceeded
- promotion: cold payloads are promoted back to hot on cache hit; current request falls back
- startup validation: invalid `--cache-cold-path` terminates server with error
- cold layer metrics: demotion/promotion counters, cold payload bytes, cold payload count, hot payload count, cold restore latency, eviction exclusion of demoted payloads
- fault tolerance: cold file corruption, cold store read failure, queue-full fallback
- protected root demotion warning
- target/draft pair demotion and promotion as a unit
- Stage 4 and Stage 5 regression with cold store configured

Some Stage 5 rows need focused controller evidence or another fault-injection harness. Public HTTP can prove normal model-backed save, hit, metrics shape, budget pressure, and legacy compatibility, but it cannot directly corrupt a descriptor, change a hot-store reference, force a draft apply failure after target apply, or make the memory clear primitive unsupported.

The current public runner still treats draft-model rows as placeholders unless a session adds a draft-capable command path. Public HTTP evidence can pass a draft-mode row only when the server actually starts in that runtime mode and the repeated request proves a restore with `timings.cache_n > 0`. If code inspection shows that the compatibility key does not include a runtime discriminator for MTP versus non-MTP draft contexts, report the cross-mode isolation rows as `BLOCKED` and hand the gap to Developer.

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
