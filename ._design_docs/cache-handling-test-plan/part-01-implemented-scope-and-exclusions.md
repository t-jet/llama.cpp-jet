# Cache handling test plan - Part 1: implemented scope and exclusions

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Implemented scope

The test plan covers the implementation status described in the design documents listed in [document-index.md](../document-index.md). Check these documents to understand what features are currently available:

- `cache-handling-phase1-implementation.md`
- `cache-handling-phase1-verification.md`
- `cache-handling-phase2-implementation.md`
- `cache-handling-phase3-implementation.md` (Phase 3: Non-Destructive Exact Blob Cache - **COMPLETE**)
- `cache-handling-phase4-implementation.md` (Stage 4: LRU eviction policy with protected roots - closed)
- `cache-handling-phase5-implementation.md` (Stage 5: descriptor separation and target/draft transactional restore - closed)
- `cache-handling-phase6-implementation.md` (Stage 6: cold payload storage and asynchronous I/O - implementation review PASS)
- `cache-handling-phase7-implementation.md` (Stage 7: branch graph foundation - closed)
- `cache-handling-phase8-implementation.md` (Stage 8: metadata-only nodes and re-materialization - Architect implementation re-review PASS)
- `cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md` (Stage 5 draft context mode compatibility)
- `cache-handling-phase-1-and-2-adjustments.md`
- `cache-handling-phases-1-and-2-implementation-gaps.md`

Stage 5 is closed. Stage 6 and Stage 7 are closed. Stage 8 has passed Architect implementation re-review and is ready for QA planning. Phase 3 remains the base cache behavior; Stage 4 adds byte-accounted LRU policy behavior and protected-root budget semantics. Stage 5 adds descriptor-owned payloads, hot payload records, pair-state validation, transactional target/draft restore behavior, and draft context mode compatibility. Stage 6 adds cold payload storage, an asynchronous I/O worker, hot-to-cold demotion, cold-to-hot promotion, startup validation for `--cache-cold-path`, and cold layer metrics. Stage 7 adds the branch forest, strict namespace validation, slot references, metadata accounting, and global hot-payload LRU. Stage 8 adds metadata-only retention, re-materialization validation, mismatch-parent handling, equivalent-branch deduplication, branch-metadata admission rejection, and cold cleanup ownership checks.

- Non-destructive exact blob cache with LRU eviction
- Comprehensive namespace isolation (14/14 fields populated)
- State serialization and deserialization
- Usage tracking through deterministic recency and hit counts
- Multi-slot reuse capability
- Resident payload byte budget enforcement through `--cache-ram`
- Protected-root retention priority, fallback eviction, and protected admission rejection
- Payload descriptor separation from cache entries
- Descriptor and hot-store validation before admission and restore
- Target-only and target-plus-draft pair enforcement
- Compatibility isolation across no-draft, normal separate draft model, target-derived `draft-mtp`, and separate-model `draft-mtp` runtimes
- Transactional restore rollback for target and draft apply failures
- Cold payload storage via `--cache-cold-path` (opt-in; when unconfigured, behavior is identical to Stage 5)
- Hot-to-cold demotion when `--cache-ram` budget pressure selects a hot payload for eviction
- Cold-to-hot promotion on cache hit; current request falls back, subsequent requests benefit
- Startup validation for `--cache-cold-path` (empty, non-existent, not a directory, non-writable, requires hybrid mode)
- Asynchronous I/O worker for demotion writes and promotion reads without blocking `server_context`
- Atomic write-and-rename for cold file creation
- Cold file integrity validation on promotion (magic, format version, header checksum, payload checksums, payload ID, pair state, sizes)
- Target and draft sides demote and promote as one unit
- Protected root demotion emits a warning diagnostic
- Demotion and promotion counters, cold payload bytes, cold payload count, hot payload count, cold restore latency histogram, and eviction exclusion of demoted payloads in `/metrics`
- Fault injection for cold file corruption, cold store read failure, and queue-full fallback
- Branch graph nodes, namespace validation, slot references, metadata accounting, checksum-assisted lookup, and global hot-payload LRU selection
- Metadata-only retention after payload eviction without automatic branch pruning
- Re-materialization planning that validates token or checksum spans before replay
- Mismatch handling that leaves the mismatched metadata-only node unchanged and admits divergence under the deepest validated ancestor
- Equivalent same-namespace branch reuse or canonicalization without descriptor sharing
- Branch metadata admission rejection when safe pruning cannot satisfy the soft metadata budget
- Cold cleanup ownership checks for evicted or pruned branch payloads
- Stage 8 metrics for retention, re-materialization, validation mismatch, mismatch parent selection, deduplication, pruning, cold cleanup, and admission rejection

## Report cross-check

| Report | How this plan treats it |
| --- | --- |
| `cache-handling-phase1-implementation.md` | Historical Phase 1 foundation record. It is still useful for mode selection, controller creation, legacy wrapper, initial metadata structs, and early hybrid LRU behavior. |
| `cache-handling-phase1-verification.md` | Historical verification record. Its own 2026-05-25 note says the 85% coverage figure was estimated and hybrid mode was not production-ready. This plan keeps those caveats. |
| `cache-handling-phase2-implementation.md` | Mixed current and superseded evidence. Use its later status notes and current testing requirements over older `/cache/stats`, `/health.cache`, and production-readiness claims. |
| `cache-handling-phase3-implementation.md` | Current base hybrid cache behavior. Use it for non-destructive hits, state serialization, namespace isolation, and multi-slot reuse. |
| `cache-handling-phase4-implementation.md` | Current Stage 4 implementation record. Use Parts 6 and 7 for the review-fix evidence that equivalent-entry refresh enforces budget and protected eviction decisions are counted. |
| `cache-handling-phase5-implementation.md` | Closed Stage 5 implementation record. Use Parts 6, 8, 9, 10, and 11 for descriptor validation, pair-state checks, Stage 5 metrics, accepted exact empty-side rollback behavior, focused QA evidence closure, and manager closure. |
| `cache-handling-phase6-implementation.md` | Closed Stage 6 implementation record. Use it for cold payload storage, asynchronous I/O, demotion, promotion, startup validation, fault injection, and cold metrics. |
| `cache-handling-phase7-implementation.md` | Closed Stage 7 implementation record. Use it for branch graph foundation, slot refs, namespace validation, metadata accounting, global payload LRU, Stage 7 metrics, and Stage 1-6 regression status. |
| `cache-handling-phase8-implementation.md` | Current Stage 8 implementation record. Use it for metadata-only retention, re-materialization, mismatch handling, equivalent deduplication, cold cleanup ownership, Prometheus metrics labels, and branch-metadata admission rejection. |
| `cache-handling-phase-1-and-2-adjustments.md` | Current upstream-scope correction. This is the source for stable `/health`, no `/cache/stats`, cache metrics in `/metrics`, hidden test helpers, degraded metadata, and minimal public CLI surface. |
| `cache-handling-phases-1-and-2-implementation-gaps.md` | Current gap and corrective-action record. This is the source for open model-backed restore coverage and target/draft failure coverage. Its focused coverage notes belong to the separate unit-test plan. |

The current implemented cache surface is:

| Area | Current behavior to test |
| --- | --- |
| Mode selection | `--cache-mode` accepts `legacy` and `hybrid`; legacy is the default. Invalid values fail before the server accepts requests. |
| Controller path | The scheduler uses `cache_ctrl->save_slot()` and `cache_ctrl->load_slot()` for cache-enabled completion tasks. |
| Legacy mode | Existing prompt-cache behavior remains behind `legacy_cache_controller`. |
| Hybrid save/load | Hybrid mode saves exact full-state target payloads via `llama_state_get_data()`, optional draft payloads, tokens, checkpoints, and prompt metadata with full serialization. |
| Hybrid restore | Hybrid restore is non-destructive: a successful hit updates recency and leaves the entry available for subsequent hits. Failed restore does not refresh recency. Multiple slots can reuse the same cache entry. |
| Exact-prefix rule | Hybrid restore accepts **only exact full matches** of cached token sequences. Divergent partial matches are rejected with `n_misses` increment. |
| State serialization | Full `llama_context` state serialized and deserialized using `llama_state_get_size()`, `llama_state_get_data()`, and `llama_state_set_data()`. Serialization failures increment `n_restore_failures`. |
| Multi-slot reuse | Multiple slots can load from the same cache entry over time. Each slot receives an independent copy of tokens and state. Entry remains in cache after each load. |
| Usage tracking | Each successful cache hit refreshes deterministic recency. Equivalent-entry save refreshes recency without duplicating the entry. |
| LRU policy | Hybrid eviction uses deterministic LRU ordering and enforces `--cache-ram` against resident serialized payload bytes. Oldest eligible entries evict first. |
| Budget enforcement | Resident payload bytes are target state bytes plus draft state bytes. Oversized entries are rejected, and refresh paths must also bring the cache back under budget. |
| Protected entries | Entries with `protected_root=true` have higher retention priority. Unprotected entries evict first, then protected entries evict oldest-first if protected bytes alone exceed the budget. |
| Namespace isolation | **Comprehensive isolation (Gap 2.2 complete):** 14/14 compatibility key fields populated including model_path_hash, template_id, lora_adapters, control_vectors, mm_projector_id, kv_unified, and context configuration. Prevents unsafe cross-restore. |
| Metadata transport | `prepared_prompt_metadata` travels on `server_task`, child tasks, slots, and hybrid entries. Includes boundaries, compatibility keys, and degraded markers. |
| Boundary extraction | Chat requests get best-effort rendered-text metadata and mark it degraded (`boundaries_native=false`, `degraded_reason` set); `/completion` gets minimal degraded prompt metadata when no richer metadata exists. Degraded public HTTP metadata is not a trusted protected-root creation path. |
| Observability | `/metrics` exports cache counters (`llamacpp_cache_hits_total`, `llamacpp_cache_misses_total`, `llamacpp_cache_evictions_total`, `llamacpp_cache_restore_failures_total`, `llamacpp_cache_payload_evictions_total`, `llamacpp_cache_protected_root_decisions_total`) when metrics are enabled. `/health` returns `{"status":"ok"}` only. `/cache/stats` intentionally returns 404. |
| Failure handling | Target restore failure resets slot prompt state. Missing paired draft payloads and draft restore failures count as restore failures. Deserialization errors logged and increment `n_restore_failures`. |
| Payload descriptors | Hybrid entries refer to descriptor-owned exact-blob payloads by `payload_id`. Descriptors track pair state, size, checksum, store reference, owner entry, and residency. |
| Descriptor validation | Admission and restore validation reject unsupported descriptor version or kind, target/draft pair mismatch, checksum mismatch, size mismatch, missing or mismatched store records, owner mismatch, non-hot residency, missing target bytes, and invalid draft presence. |
| Target/draft transactions | Target-only and target-plus-draft restore validate all descriptor and payload fields before live mutation. Failed validation, target apply, draft apply, commit, or rollback does not report a hit or refresh recency. |
| Draft runtime compatibility | Pair state remains binary: no draft context requires `target_only`; any active draft context requires `target_and_draft`. The compatibility namespace must still distinguish no draft, normal separate draft model through `--model-draft` or `--spec-draft-model`, target-derived `--spec-type draft-mtp`, and separate-model `--spec-type draft-mtp`. |
| Empty-preimage rollback | If a pre-restore target or draft side has no serialized bytes, rollback clears that sequence. Unsupported clear paths fail before target payload application. |
| Stage 5 observability | `/metrics` exports descriptor validation failures, pairing violations, fallback restores, hot descriptors, and evicted descriptors in addition to the Stage 4 counters. |
| Stage 6 cold layer | Cold payload storage is opt-in via `--cache-cold-path`. When unconfigured, the server behaves identically to Stage 5. When configured, hot payloads are demoted to cold files under budget pressure and promoted back to hot on cache hit. Startup validation rejects invalid `--cache-cold-path` configurations. `/metrics` exports demotion and promotion counters, cold payload bytes, cold payload count, hot payload count, cold restore latency, and eviction exclusion of demoted payloads. Target and draft sides demote and promote as one unit. Protected root demotion emits a warning. |
| Stage 7 branch graph | Hybrid saves create branch nodes in a namespace-aware forest. Slot references block unsafe payload eviction. Branch metadata bytes are accounted and exposed. Checksum and token-span lookup select same-namespace candidates. The hot payload LRU is global across namespaces. |
| Stage 8 metadata-only graph | Payload eviction can leave branch metadata in place. Selected metadata-only nodes require validation before replay. Mismatches become misses and divergence branches. Equivalent nodes are reused in the same namespace. Metadata admission can reject a new node when protected or referenced topology prevents safe pruning. Cold cleanup must prove descriptor ownership. |

## Exclusions

Do not write acceptance tests for these features yet:

- Checkpoint-first restore strategy.
- Native Jinja boundary capture as a production contract.
- Public request-controlled protected-root markers.
- A public JSON `/cache/stats` endpoint.
- Cache fields in `/health`.
- Separate hot, metadata, and cold budget flags. (Cold budget is deferred; `--cache-ram` remains the only budget flag.)
- Cache policy selection such as `--cache-eviction-policy`.
- Namespace fairness or per-namespace quotas.
- Cold residency or cold-store restore across server restarts. Cold files may persist on disk, but the design does not guarantee that a future server start will accept them as valid restore sources.
- Public metadata-budget CLI configuration. Stage 8 metadata-budget checks use internal or focused-test configuration unless a later stage opens public flags.

Tests may mention these as future work only when they verify that the current build does not expose the feature.

## Test model assumptions

Integration tests need a real GGUF model, not a vocabulary-only fixture. The default target-only local path should be:

```text
._test_models/Qwen2.5-VL-3B-Instruct-GGUF/Qwen2.5-VL-3B-Instruct-Q6_K.gguf
```

Allow `LLAMA_CACHE_TEST_MODEL` to override this path. Keep tests small: `-np 2`, deterministic sampling, and short `n_predict` values are enough to prove cache behavior.

The local Qwen3 model-suite paths available for draft-mode planning are:

```text
._test_models/Qwen3-8B-GGUF/Qwen3-8B-Q6_K.gguf
._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf
```

Use the Qwen3-8B file as the target and the Qwen3-0.6B file as the separate draft model for normal `--model-draft` or `--spec-draft-model` coverage. Treat `draft-mtp` rows as supported only after startup proves that the selected model or model pair can create an MTP draft context.

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
