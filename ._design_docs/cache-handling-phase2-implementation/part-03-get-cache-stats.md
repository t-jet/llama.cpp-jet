# Phase 2 Implementation Log - Part 3: GET /cache/stats

Source: [../cache-handling-phase2-implementation.md](../cache-handling-phase2-implementation.md)

#### GET /cache/stats

Status: superseded by the 2026-05-25 upstream-scope adjustment.

The initial upstream target must not add a public `/cache/stats` endpoint and must not add cache fields to `/health`. Cache counters now belong in the existing Prometheus `/metrics` endpoint when `--metrics` is enabled. The notes below describe the earlier phase 2 implementation idea and should not be used as current acceptance criteria.

**Response:**
- Historical design only. Current code should return 404 for `/cache/stats`.
- Current cache observability is exposed through `/metrics` when `--metrics` is enabled.

**Statistics Fields:**
- `type`: Cache type ("legacy", "hybrid", or "none")
- `size_mib`: Total size in MiB
- `n_tokens`: Total number of cached tokens
- `n_entries`: Number of cache entries
- `n_hits`: Cache hit count
- `n_misses`: Cache miss count
- `n_evictions`: Number of evicted entries
- `namespaces`: Entries per namespace (object)

### Current testing requirements

- [x] `GET /health` returns the upstream shape: `{"status":"ok"}`.
- [x] `GET /cache/stats` is not registered.
- [x] `GET /metrics` includes cache counters when `--metrics` is enabled.
- [ ] Model-backed save/load restore behavior still needs broader coverage.

### Next Steps

1. Keep endpoint tests focused on stable `/health`, missing `/cache/stats`, and cache metrics in `/metrics`.
2. Add model-backed restore tests before claiming hybrid runtime readiness.
3. Keep any richer JSON cache inspection endpoint private-fork only, if it is needed for local debugging.

---

## Step 6: Refactor Slot Architecture

**Status**: Completed for the upstream-scope pass

### Objectives

- Route prompt cache save/load through `cache_controller` instead of keeping direct `server_prompt_cache` calls in the scheduler path.
- Preserve the default legacy cache behavior behind the controller interface.
- Carry prompt metadata on `server_task` and `server_slot` as native C++ state.
- Keep cache-specific request parsing out of `server_context`.

### Result

The slot path now uses `cache_ctrl->save_slot()` and `cache_ctrl->load_slot()` for cache-enabled completion tasks. `server_task::prompt_metadata` is assigned before enqueue, then copied to the slot when the task starts. `server_context` still owns the scheduling flow, but it no longer has to know which cache implementation is active.

Remaining work: the legacy controller implementation still depends on `server_slot` internals because save/load state APIs live there. That is acceptable for this stage. A deeper split would be larger than the upstream-scope adjustment.

---

## Step 7: Optimize Performance

**Status**: Completed for current scope

### Objectives

- Keep exact-blob restore non-destructive.
- Use LRU eviction with `--cache-ram` accounting.
- Keep prefix lookup correct for entries shorter than the prefix index length.
- Avoid adding public cache policy or budget flags.

### Result

Hybrid cache lookup uses a prefix index to reduce candidate scans, then rejects anything except a full cached-entry prefix match. LRU bookkeeping is maintained on save, load, and eviction. Protected entries still count against the cache budget and can be evicted as a fallback when all entries are protected.

No new performance CLI flags were added. Cold storage, checkpoint-first restore, and policy selectors stay out of the upstream target.

---

## Step 8: Create Comprehensive Tests

**Status**: Partially complete

### Objectives

- Cover the controller interface and hybrid lookup/index behavior in focused unit tests.
- Cover the public HTTP surface change: stable `/health`, no `/cache/stats`, cache metrics under `/metrics`.
- Cover namespace misses for synthetic compatibility-key differences.
- Keep the known model-backed restore gap visible.

### Result

Added or updated:

- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- `tools/server/tests/test_cache_phase2_integration.sh`
- `tools/server/tests/verify_cache_phase2.ps1`

The focused unit test now covers partial exact-blob rejection, short-prefix lookup, LRU eviction, protected eviction fallback, and compatibility-key misses. The Python cache-mode tests check the HTTP behavior expected by the updated architecture.

Still missing: a model-backed test that forces a real target/draft restore failure after one side applies. That path needs a small reliable model fixture and a deterministic way to exercise `llama_state_seq_set_data_ext()` failure.

---

## Step 9: Verify Test Coverage

**Status**: Measured for focused tests; full coverage not claimed

### Objectives

- Replace estimated coverage claims with command output and exact scope.
- Separate focused structural tests from model-backed runtime coverage.
- Avoid claiming production readiness for hybrid restore until real restore paths are tested.

### Result

Current evidence:

- `cmake --build build-test --target test-cache-controller --config Release -j 4` passed.
- `ctest --test-dir build-test -C Release -R test-cache-controller --output-on-failure` passed.
- `cmake --build build-test --target llama-server --config Release -j 4` passed.
- `pytest tools/server/tests/unit/test_cache_modes.py -q` passed with `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`: 2 passed, 1 xfailed.

No line coverage percentage is claimed here. The old 85% figure was historical and estimated. The focused C++ and Python tests are useful, but they do not prove real `llama_state_seq_*` restore behavior.

---

## Step 10: Final Testing and Validation

**Status**: Completed for upstream-scope behavior; runtime restore validation remains open

### Objectives

- Verify the server target builds after route and metrics changes.
- Verify `/health` and `/metrics` behavior through automated tests.
- Keep unsupported endpoint behavior explicit.
- List remaining runtime risk plainly.

### Result

The upstream-scope behavior is validated:

- `/health` returns the original JSON shape.
- `/cache/stats` is not registered.
- `/metrics` includes cache counters when metrics are enabled.
- `--cache-mode` remains the only new public cache flag from this work.

Remaining validation:

- Real target-only restore round trip with a model.
- Target-plus-draft paired restore success.
- Target-plus-draft restore failure followed by slot recomputation.
- Protected and unprotected entries under real byte pressure.

---

## Notes and Issues

### Issue Tracker

(None yet)

### Questions for Human Review

(None yet)

---

## Summary of Changes

### Phase 2 Completion Status: Core Functionality Complete

**Date**: May 24, 2026

### Files Created

- None (all changes to existing files)

### Files Modified

1. **tools/server/server-cache-hybrid.cpp** - Implemented full save/load functionality
   - `save_slot()`: Lines 24-111 (88 lines of implementation)
   - `load_slot()`: Lines 113-188 (76 lines of implementation)
   - `find_best_match()`: Added diagnostic logging for missing metadata

2. **tools/server/server-context.h** - Cache stats endpoint declaration removed from the current target.

3. **tools/server/server-context.cpp** - Current target keeps `/health` unchanged and exports cache counters through `/metrics`.

4. **tools/server/server.cpp** - `/cache/stats` registration removed from the current target.

### Tests Added

**Testing Status**: Focused automated tests pass. Model-backed restore coverage is still open.

Current tests:

- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- `tools/server/tests/test_cache_phase2_integration.sh`
- `tools/server/tests/verify_cache_phase2.ps1`

### Completed Objectives

- Objective 1: Hybrid save/load implemented.
- Objective 2: Boundary metadata infrastructure is present; rendered-text inference is marked degraded.
- Objective 3: Metadata transport is native task/slot state, not hidden request JSON.
- Objective 4: Cache observability is integrated through `/metrics`.
- Objective 5: Slot architecture refactoring is complete for this scope.
- Objective 6: Lookup and eviction performance are complete for this scope.

### Build Status

**Current**: `build-test` Release targets build successfully.  
**Compilation Errors**: None in the focused cache/server builds.  
**Warnings**: The pytest run reports existing Python package/version warnings. They are not cache implementation failures.

### Next Actions Required

1. Add model-backed restore tests for target-only and target-plus-draft paths.
2. Add a deterministic restore-failure test that proves the slot is reset before recomputation.
3. Add measured line coverage only after the model-backed tests exist.

These are still listed here because the current automated evidence is structural and endpoint-focused. It builds the server, exercises the controller, and checks the HTTP surface. It does not yet prove real `llama_state_seq_*` restore behavior with a loaded model, especially the target-plus-draft failure path. Coverage should wait until those runtime paths exist; otherwise the number would look precise while missing the riskiest behavior.

### Completed scope guard

`/cache/stats` is already out of the upstream target. The route is not registered, `/health` keeps the upstream response shape, and cache counters are exported through `/metrics` when metrics are enabled. A JSON cache stats endpoint should only come back behind an explicit private-fork option.

### Deferred to Phase 3

1. Native boundary capture for templates that cannot be described by rendered-text fallback.
2. Rich JSON cache inspection endpoints, if wanted for private-fork debugging.
3. Cold storage, branch graph, and checkpoint-first restore.

### Risk Assessment

**Low Risk Items**:
- Focused cache and server targets compile.
- Public endpoint shape now matches the upstream target.
- Cache metrics are behind the existing `--metrics` flag.

**Medium Risk Items**:
- Model-backed target/draft restore paths still need tests.
- Rendered-text metadata inference is degraded fallback, not the final native boundary source.

**Success Criteria**:
- Code compiles in focused cache/server builds.
- No coverage percentage is claimed in this part.
- `/health` keeps the upstream response shape.
- `/cache/stats` is not registered.
- Cache counters are available through `/metrics` when enabled.

## Evidence of Implementation

### Code References

1. **Hybrid Save Implementation**: [server-cache-hybrid.cpp:24-111](../tools/server/server-cache-hybrid.cpp#L24-L111)
2. **Hybrid Load Implementation**: [server-cache-hybrid.cpp:113-188](../tools/server/server-cache-hybrid.cpp#L113-L188)
3. **Metrics Integration**: `tools/server/server-context.cpp`
4. **Removed Cache Stats Endpoint**: `tools/server/server.cpp`

### Build Log

Build initiated: May 24, 2026
Target: llama-server (Release build with CUDA support)
Status: ✅ **COMPLETED SUCCESSFULLY** (Exit code: 0)
Build time: ~5+ minutes (CUDA compilation intensive)
Output: `build-cuda\bin\Release\llama-server.exe`
Errors: 0 (Phase 2 code compiled cleanly)
Warnings: CUDA-related only (template instantiation warnings, not from Phase 2 code)

