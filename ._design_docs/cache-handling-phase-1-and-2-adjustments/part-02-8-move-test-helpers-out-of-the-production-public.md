# Cache handling phase 1 and 2 adjustments - Part 2: 8. Move test helpers out of the production public class surface

Source: [../cache-handling-phase-1-and-2-adjustments.md](../cache-handling-phase-1-and-2-adjustments.md)

### 8. Move test helpers out of the production public class surface

Status: recommended

Current mismatch:

- `hybrid_cache_controller` exposes `debug_*_for_tests()` methods in the production header.

Design:

- Prefer extracting pure lookup/index helpers that can be unit-tested directly.
- If the helpers must stay, guard them behind a test macro and keep them unavailable in normal builds.

Acceptance criteria:

- Production headers expose only behavior needed by the server.
- Cache lookup/index unit tests still cover short-prefix and namespace behavior.

### 9. Make coverage claims precise

Status: required documentation correction

Current mismatch:

- Phase 1 verification claims 85% estimated coverage.
- Later coverage evidence shows a real focused run, then an improved focused run, but still notes model-backed restore paths are uncovered.
- Phase 2 implementation logs claim completion and production readiness while also saying runtime testing requires a model.

Design:

- Replace estimated coverage claims with measured reports only.
- Split status into:
  - structural/unit coverage
  - model-backed runtime coverage
  - endpoint/API coverage
  - remaining untested risk
- Keep the 95.52% focused coverage result, but explicitly state it does not cover real `llama_state_seq_*` restore behavior.

Acceptance criteria:

- No document claims production readiness for hybrid mode until model-backed save/load tests pass.
- Coverage sections include exact commands, report paths, and uncovered runtime paths.

## Updated phase scope

### Phase 1 should mean architecture stages 1 and 2 only

Keep:

- `--cache-mode`
- cache controller interface and factory
- legacy adapter
- hybrid no-op or minimal stub that fails explicitly
- `prepared_prompt_metadata` data model
- task metadata transport

Do not count as required phase 1 completion:

- non-destructive exact blob restore
- LRU policy
- protected-root eviction behavior
- prefix index optimization
- `/cache/stats`

If those already exist, classify them as ahead-of-stage implementation, not phase 1 requirements.

### Phase 2 should harden early hybrid restore without expanding API surface

Keep or finish:

- non-destructive exact-blob restore only when the full cached entry is a prefix of the new request
- target/draft paired restore validation and recovery
- LRU implementation using `--cache-ram`
- prefix-index correctness
- metadata shape and propagation
- degraded metadata diagnostics
- focused unit coverage

Do not include:

- `/cache/stats`
- `/health` shape changes
- new budget flags
- eviction-policy CLI selector
- cold persistence
- branch graph
- checkpoint-first restore

## Required implementation order

1. Remove public `/cache/stats` and `/health.cache`; move cache observability to `/metrics`.
2. Move cache metadata preparation out of `server_context` and remove `_cache_prompt_metadata_source`.
3. Mark any fallback boundary inference as degraded and add fixture tests.
4. Expand compatibility key construction and reject mismatched candidates early.
5. Add a recovery path for partial target/draft apply failures.
6. Replace checkpoint-enabled protection with metadata-driven protection.
7. Move or hide `debug_*_for_tests()` helpers.
8. Update phase documents so they no longer claim endpoint additions, public marker contracts, or unmeasured production readiness.

## Files likely to change

| File | Change |
| --- | --- |
| `tools/server/server.cpp` | Remove `/cache/stats` registration for the upstream target. |
| `tools/server/server-context.h` | Remove public route handler for cache stats if no longer used. Keep private helper only if needed. |
| `tools/server/server-context.cpp` | Remove `/health.cache`, move metadata construction out of this file, add paired-restore recovery, adjust protected-root policy, add metrics export plumbing. |
| `tools/server/server-common.cpp` | Remove `_cache_prompt_metadata_source` from JSON plumbing. |
| `tools/server/server-task.h` | Add missing boundary kinds if needed: media and generation-prompt spans. Keep metadata as native task data. |
| `tools/server/server-cache-hybrid.*` | Use structured compatibility keys, hide test helpers, keep exact-blob full-prefix matching. |
| `tools/server/tests/unit/test_cache_modes.py` | Remove `/cache/stats` and `/health.cache` assertions; add `/metrics` coverage when enabled. |
| `tests/test-cache-controller.cpp` | Keep pure lookup tests; add compatibility-key and protection-policy tests. |
| Phase 1/2 design and implementation docs | Reclassify completed work by architecture stage; remove or defer endpoint and CLI expansion claims. |

## Open questions

1. Should `/cache/stats` remain in this private fork behind a fork-only build option, or should it be removed outright to track upstream?
2. What is the smallest reliable target model fixture for model-backed restore tests in this repository?
3. Can `llama_state_seq_set_data_ext()` failure be followed by a reliable sequence clear/reset path, or does the scheduler need to discard the slot and fully reinitialize context state?
4. Which prompt-preparation function is the least invasive place to produce native boundary spans for chat routes without changing template files?

## Summary

The current implementation has useful pieces that should stay: mode dispatch, cache-controller abstraction, span metadata, safer exact-blob matching, paired payload prevalidation, LRU/prefix indexes, and focused unit coverage.

The main adjustments are about upstream compatibility and correctness boundaries. Remove the new public cache endpoint surface, keep `/health` stable, move boundary work out of `server_context`, strengthen compatibility keys, make paired restore failure recover to a known-valid state, and stop treating test-only Jinja markers or estimated coverage as production contracts.
