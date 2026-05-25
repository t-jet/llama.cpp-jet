# Cache handling phase 1 and 2 adjustments

Date: 2026-05-24

This note compares the phase 1 and phase 2 design/implementation documents, the current implementation, and the updated architecture in `cache-handling-architecture.md`.

The updated architecture changes the target in one important way: the first upstreamable version should be smaller. It should keep the default cache path unchanged, add only the `--cache-mode` CLI flag, reuse existing cache/checkpoint flags, avoid new HTTP endpoints, keep prompt preparation in the HTTP layer, and treat cold storage plus extra budget/policy flags as later or private-fork work.

## Contents

This document is split into smaller part files. Read the parts in order when you need the full content.

- [Part 1: Current implementation state](./cache-handling-phase-1-and-2-adjustments/part-01-current-implementation-state.md)
- [Part 2: 8. Move test helpers out of the production public class surface](./cache-handling-phase-1-and-2-adjustments/part-02-8-move-test-helpers-out-of-the-production-public.md)

## Implementation plan

1. Remove the public cache stats endpoint and keep `/health` unchanged.
2. Export cache counters through `/metrics` when `--metrics` is enabled.
3. Stop passing cache metadata through hidden request JSON.
4. Build hybrid cache namespaces from runtime state plus prompt compatibility metadata.
5. Reset a slot after a failed target/draft restore apply.
6. Base protected-root status on prompt metadata, not checkpoint enablement.
7. Hide hybrid cache debug helpers from normal public headers.
8. Update focused tests and correct older phase documentation where it conflicts with this upstream target.

## Progress and evidence

### 2026-05-25 implementation pass

Changed code:

- Removed `GET /cache/stats` registration from `tools/server/server.cpp`.
- Restored `/health` to `{"status":"ok"}` in `tools/server/server-context.cpp`.
- Added Prometheus cache metrics in `tools/server/server-context.cpp`: `llamacpp_cache_entries`, `llamacpp_cache_bytes`, `llamacpp_cache_tokens`, `llamacpp_cache_hits_total`, `llamacpp_cache_misses_total`, `llamacpp_cache_evictions_total`, and `llamacpp_cache_restore_failures_total`.
- Removed `_cache_prompt_metadata_source` from `tools/server/server-common.cpp`.
- Passed chat messages directly from the HTTP route layer into prompt metadata preparation. Rendered-text boundary inference is now marked degraded.
- Changed hybrid cache namespace construction to include prompt compatibility metadata and span layout.
- Added target/draft restore failure cleanup through `slot.prompt_clear(false)` before recomputation.
- Changed protected-root assignment to use explicit prompt metadata protection hints.
- Hid `debug_*_for_tests()` helpers from normal `server-cache-hybrid.h` public surface and enabled them only for the focused cache test build.
- Updated `tools/server/tests/unit/test_cache_modes.py` to check `/metrics`, stable `/health`, and missing `/cache/stats`.
- Added focused compatibility-key miss coverage to `tests/test-cache-controller.cpp`.

Verification:

- `cmake --build build-test --target test-cache-controller --config Release -j 4` passed.
- `ctest --test-dir build-test -C Release -R test-cache-controller --output-on-failure` passed: 1/1 tests, 0 failures.
- `cmake --build build-test --target llama-server --config Release -j 4` passed.
- First `pytest tools/server/tests/unit/test_cache_modes.py -q` failed during suite preload because this build has HTTPS support disabled and the preload tried to fetch a Hugging Face preset.
- Rerun with `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` and `LLAMA_SERVER_BIN_PATH=D:\source\llama.cpp-jet\build-test\bin\Release\llama-server.exe` passed: 2 passed, 1 xfailed.
