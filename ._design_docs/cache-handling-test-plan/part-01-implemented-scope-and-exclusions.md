# Cache handling test plan - Part 1: implemented scope and exclusions

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Implemented scope

The test plan covers the implementation status described in the design documents listed in [document-index.md](../document-index.md). Check these documents to understand what features are currently available:

- `cache-handling-phase1-implementation.md`
- `cache-handling-phase1-verification.md`
- `cache-handling-phase2-implementation.md`
- `cache-handling-phase-1-and-2-adjustments.md`
- `cache-handling-phases-1-and-2-implementation-gaps.md`

## Report cross-check

| Report | How this plan treats it |
| --- | --- |
| `cache-handling-phase1-implementation.md` | Historical Phase 1 foundation record. It is still useful for mode selection, controller creation, legacy wrapper, initial metadata structs, and early hybrid LRU behavior. |
| `cache-handling-phase1-verification.md` | Historical verification record. Its own 2026-05-25 note says the 85% coverage figure was estimated and hybrid mode was not production-ready. This plan keeps those caveats. |
| `cache-handling-phase2-implementation.md` | Mixed current and superseded evidence. Use its later status notes and current testing requirements over older `/cache/stats`, `/health.cache`, and production-readiness claims. |
| `cache-handling-phase-1-and-2-adjustments.md` | Current upstream-scope correction. This is the source for stable `/health`, no `/cache/stats`, cache metrics in `/metrics`, hidden test helpers, degraded metadata, and minimal public CLI surface. |
| `cache-handling-phases-1-and-2-implementation-gaps.md` | Current gap and corrective-action record. This is the source for open model-backed restore coverage and target/draft failure coverage. Its focused coverage notes belong to the separate unit-test plan. |

The current implemented cache surface is:

| Area | Current behavior to test |
| --- | --- |
| Mode selection | `--cache-mode` accepts `legacy` and `hybrid`; legacy is the default. Invalid values fail before the server accepts requests. |
| Controller path | The scheduler uses `cache_ctrl->save_slot()` and `cache_ctrl->load_slot()` for cache-enabled completion tasks. |
| Legacy mode | Existing prompt-cache behavior remains behind `legacy_cache_controller`. |
| Hybrid save/load | Hybrid mode saves exact full-state target payloads, optional draft payloads, tokens, checkpoints, and prompt metadata. |
| Hybrid restore | Hybrid restore is non-destructive: a hit updates LRU state and leaves the entry available for another hit. |
| Exact-prefix rule | Hybrid restore accepts only full cached-entry prefix matches. Divergent partial matches are rejected. |
| LRU policy | Hybrid eviction uses an LRU index and enforces `--cache-ram` and token limits. |
| Protected entries | Protected entries are skipped first, but may be evicted as a fallback when all entries are protected and the budget is exceeded. |
| Namespace isolation | Metadata compatibility keys and runtime-derived namespace IDs prevent cross-namespace hits. |
| Metadata transport | `prepared_prompt_metadata` travels on `server_task`, child tasks, slots, and hybrid entries. |
| Boundary extraction | Chat requests get best-effort rendered-text metadata and mark it degraded; `/completion` gets minimal degraded prompt metadata when no richer metadata exists. |
| Observability | `/metrics` exports cache counters when metrics are enabled. `/health` returns `{"status":"ok"}` only. `/cache/stats` intentionally returns 404. |
| Failure handling | Target restore failure resets slot prompt state. Missing paired draft payloads and draft restore failures count as restore failures. |

## Exclusions

Do not write acceptance tests for these features yet:

- Cold payload storage or `--cache-cold-dir`.
- Metadata-only branch nodes and re-materialization.
- Shared branch graph traversal.
- Checkpoint-first restore strategy.
- Native Jinja boundary capture as a production contract.
- A public JSON `/cache/stats` endpoint.
- Cache fields in `/health`.
- Separate hot, metadata, and cold budget flags.
- Cache policy selection such as `--cache-eviction-policy`.
- Namespace fairness or per-namespace quotas.

Tests may mention these as future work only when they verify that the current build does not expose the feature.

## Test model assumptions

Integration tests need a real GGUF model, not a vocabulary-only fixture. The default local path should be:

```text
._test_models/Qwen2.5-VL-3B-Instruct-GGUF/Qwen2.5-VL-3B-Instruct-Q6_K.gguf
```

Allow `LLAMA_CACHE_TEST_MODEL` to override this path. Keep tests small: `-np 2`, deterministic sampling, and short `n_predict` values are enough to prove cache behavior.

## Minimum build targets

Before running integration tests, perform a clean build:

```powershell
# Clean build (recommended)
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server -j 4

# Or use existing build directory with rebuild
cmake --build build --config Release --target llama-server --clean-first
```

Use the build directory that matches the local CMake configuration. CUDA builds may use `build-cuda`, but the plan should not require CUDA-only behavior.
