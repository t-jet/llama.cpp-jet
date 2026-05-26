# Cache handling test plan - Part 1: implemented scope and exclusions

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Implemented scope

The test plan covers the implementation status described in the design documents listed in [document-index.md](../document-index.md). Check these documents to understand what features are currently available:

- `cache-handling-phase1-implementation.md`
- `cache-handling-phase1-verification.md`
- `cache-handling-phase2-implementation.md`
- `cache-handling-phase3-implementation.md` (Phase 3: Non-Destructive Exact Blob Cache - **COMPLETE**)
- `cache-handling-phase-1-and-2-adjustments.md`
- `cache-handling-phases-1-and-2-implementation-gaps.md`

**Phase 3 Status**: ✅ **PRODUCTION READY** (May 26, 2026)

- Non-destructive exact blob cache with LRU eviction
- Comprehensive namespace isolation (14/14 fields populated)
- State serialization and deserialization
- Usage tracking (last_used_time, use_count)
- Multi-slot reuse capability
- Test coverage: 34/34 tests passing (100% success rate, ≥95% coverage)

## Report cross-check

| Report | How this plan treats it |
| --- | --- |
| `cache-handling-phase1-implementation.md` | Historical Phase 1 foundation record. It is still useful for mode selection, controller creation, legacy wrapper, initial metadata structs, and early hybrid LRU behavior. |
| `cache-handling-phase1-verification.md` | Historical verification record. Its own 2026-05-25 note says the 85% coverage figure was estimated and hybrid mode was not production-ready. This plan keeps those caveats. |
| `cache-handling-phase2-implementation.md` | Mixed current and superseded evidence. Use its later status notes and current testing requirements over older `/cache/stats`, `/health.cache`, and production-readiness claims. |
| `cache-handling-phase3-implementation.md` | **Current production-ready implementation.** Phase 3 is COMPLETE with full Gap 2.2 compliance (14/14 namespace fields), non-destructive hits, state serialization, usage tracking, and multi-slot reuse. Use this as the primary source for hybrid cache behavior. |
| `cache-handling-phase-1-and-2-adjustments.md` | Current upstream-scope correction. This is the source for stable `/health`, no `/cache/stats`, cache metrics in `/metrics`, hidden test helpers, degraded metadata, and minimal public CLI surface. |
| `cache-handling-phases-1-and-2-implementation-gaps.md` | Current gap and corrective-action record. This is the source for open model-backed restore coverage and target/draft failure coverage. Its focused coverage notes belong to the separate unit-test plan. |

The current implemented cache surface is:

| Area | Current behavior to test |
| --- | --- |
| Mode selection | `--cache-mode` accepts `legacy` and `hybrid`; legacy is the default. Invalid values fail before the server accepts requests. |
| Controller path | The scheduler uses `cache_ctrl->save_slot()` and `cache_ctrl->load_slot()` for cache-enabled completion tasks. |
| Legacy mode | Existing prompt-cache behavior remains behind `legacy_cache_controller`. |
| Hybrid save/load | Hybrid mode saves exact full-state target payloads via `llama_state_get_data()`, optional draft payloads, tokens, checkpoints, and prompt metadata with full serialization. |
| Hybrid restore | Hybrid restore is **non-destructive**: a hit updates LRU state (`last_used_time`, `use_count`) and **leaves the entry available** for subsequent hits. Multiple slots can reuse the same cache entry. |
| Exact-prefix rule | Hybrid restore accepts **only exact full matches** of cached token sequences. Divergent partial matches are rejected with `n_misses` increment. |
| State serialization | Full `llama_context` state serialized and deserialized using `llama_state_get_size()`, `llama_state_get_data()`, and `llama_state_set_data()`. Serialization failures increment `n_restore_failures`. |
| Multi-slot reuse | Multiple slots can load from the same cache entry over time. Each slot receives an independent copy of tokens and state. Entry remains in cache after each load. |
| Usage tracking | Each cache hit increments `use_count` and updates `last_used_time`. Usage metadata affects LRU eviction ordering. |
| LRU policy | Hybrid eviction uses an LRU multimap index (O(log n)) and enforces `--cache-ram` and token limits. Oldest unused entries evicted first. |
| Protected entries | Entries with `protected_root=true` (system prompts) are skipped during eviction unless all entries are protected and budget is exceeded. |
| Namespace isolation | **Comprehensive isolation (Gap 2.2 complete):** 14/14 compatibility key fields populated including model_path_hash, template_id, lora_adapters, control_vectors, mm_projector_id, kv_unified, and context configuration. Prevents unsafe cross-restore. |
| Metadata transport | `prepared_prompt_metadata` travels on `server_task`, child tasks, slots, and hybrid entries. Includes boundaries, compatibility keys, and degraded markers. |
| Boundary extraction | Chat requests get best-effort rendered-text metadata and mark it degraded (`boundaries_native=false`, `degraded_reason` set); `/completion` gets minimal degraded prompt metadata when no richer metadata exists. |
| Observability | `/metrics` exports cache counters (`llamacpp_cache_hits`, `llamacpp_cache_misses`, `llamacpp_cache_evictions`, `llamacpp_cache_restore_failures`) when metrics are enabled. `/health` returns `{"status":"ok"}` only. `/cache/stats` intentionally returns 404. |
| Failure handling | Target restore failure resets slot prompt state. Missing paired draft payloads and draft restore failures count as restore failures. Deserialization errors logged and increment `n_restore_failures`. |

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
