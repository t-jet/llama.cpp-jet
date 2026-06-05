# Prompt Cache and Context Checkpoint Compression - Part 3: Phase 1: Params and documentation surface

Source: [../prompt-compression-implementation.md](../prompt-compression-implementation.md)

### Phase 1: Params and documentation surface

Files:

- `common/common.h`
- `common/arg.cpp`
- `tools/server/README.md`

Changes:

1. Add new `common_params` fields:
   - `bool prompt_cache_compress = false;`
   - `int32_t prompt_cache_compress_threshold_mib = 128;`
   - `bool ctx_checkpoints_compress = false;`
   - `int32_t ctx_checkpoints_compress_threshold_mib = 64;`
   - `common_state_compression_codec state_compression_codec = AUTO;`
   - `common_state_compression_level state_compression_level = BALANCED;`
2. Add new CLI options and env vars.
3. Add README entries next to `--cache-ram`, `--ctx-checkpoints`, and `--checkpoint-every-n-tokens`.
4. Add short warnings in init logs when users enable compression while the corresponding feature is effectively disabled:
   - prompt-cache compression with `--cache-ram 0`
   - checkpoint compression with `--ctx-checkpoints 0`
5. Add startup validation for explicit codec requests that are not available in the current build.
6. Add documentation text clarifying that compression is orthogonal to SWA/cache-reuse capability and does not by itself avoid full re-prompting on unsupported backends.

Acceptance criteria:

- help text renders correctly
- README table documents the new flags
- invalid explicit codec choices are rejected clearly
- default behavior is unchanged
- the docs clearly distinguish RAM reduction from backend reuse capability

### Phase 2: Introduce reusable state-blob support

Files:

- `common/common.h`
- `common/common.cpp`
- possibly a new small helper file if `common.h` becomes too large

Changes:

1. Introduce a small blob abstraction for stored state bytes.
2. Extend `common_prompt_checkpoint` to carry raw-size and encoding metadata while preserving raw default behavior.
3. Update `size()`, `clear()`, `load_tgt()`, and `load_dft()` to understand raw vs compressed data.
4. Keep `update_tgt()` and `update_dft()` defaulting to raw unless a caller explicitly compresses afterward.
5. Add a small codec-dispatch layer that resolves `auto` to an actual codec before compression.

Acceptance criteria:

- existing non-server users of `common_prompt_checkpoint` still work without enabling compression
- raw checkpoint behavior remains unchanged
- `fast`, `balanced`, and `best` map correctly for each compiled-in codec

### Phase 3: Prompt cache compression

Files:

- `tools/server/server-task.h`
- `tools/server/server-task.cpp`
- `tools/server/server-context.cpp`

Changes:

1. Replace raw prompt data storage with blob-aware storage.
2. Update `server_prompt::size()` to mean resident stored bytes.
3. Add raw-size helpers for diagnostics.
4. Update `prompt_save()` to serialize and optionally compress `main` and `drft` immediately.
5. Update `prompt_load()` / `server_prompt_cache::load()` to decompress on demand.
6. Adjust `server_prompt_cache::alloc()` raw-size early-skip behavior so compressed entries are not rejected incorrectly.
7. Keep the token-LCP selection logic unchanged.
8. Keep `prompt_clear()` and post-restore clearing behavior unchanged.

Acceptance criteria:

- prompt cache reuse correctness unchanged
- when compression is enabled and threshold is met, resident prompt-cache bytes drop
- when compression is disabled, behavior matches baseline

### Phase 4: Context checkpoint compression

Files:

- `tools/server/server-context.cpp`
- `common/common.h`
- `common/common.cpp`

Changes:

1. Apply checkpoint compression policy inside `checkpoint_update_tgt()` and `checkpoint_update_dft()`.
2. Preserve checkpoint selection logic exactly as today.
3. Restore compressed checkpoints by decompressing just before `llama_state_seq_set_data_ext()`.
4. Keep `spec_ckpt` uncompressed in v1.
5. Keep pre-allocation trimming based on raw reserve sizes so transient allocation pressure stays bounded.

Acceptance criteria:

- checkpoint restore correctness unchanged
- resident checkpoint bytes drop when enabled
- no regression when compression is disabled

### Phase 5: Build integration

Files:

- `tools/server/CMakeLists.txt`
- possibly top-level CMake glue depending on the chosen codec library

Changes:

1. Add explicit build/link wiring for the chosen codec in `server-context`.
2. Keep the compression wrapper hidden from most of the server code.
3. Avoid coupling prompt-cache compression to the HTTP compression path.
4. Add a deliberate build story for multiple codec backends:
   - baseline support for `zlib`
   - optional support for `zstd`
   - compile-time capability reporting for runtime validation and `auto` resolution

Non-goal for this phase:

- do not bake backend capability policy into the codec layer; build integration should provide codecs, while backend reuse limits remain determined by the existing server and memory-backend logic

Recommended rule:

- the `server-context` static library should directly link the codec dependency it uses

Acceptance criteria:

- server builds with compression enabled in the selected build configurations
- disabling the feature at runtime does not require a separate binary

### Phase 6: Tests

#### Prompt-cache tests

Extend or add Python server tests under `tools/server/tests/unit/`:

- reuse baseline with compression disabled
- reuse with prompt-cache compression enabled and threshold forced low
- threshold behavior: high threshold keeps raw path
- compression failure fallback if a test hook or injected helper is available

Good candidates to extend:

- `test_kv_keep_only_active.py`
- `test_slot_save.py` for ensuring slot save/restore behavior remains unaffected
- add at least one backend-capability-oriented test case or test note covering SWA-style behavior with and without full-cache mode, so the feature is not accidentally described or validated as if compression restored unsupported reuse semantics

#### Checkpoint tests

Recommended coverage split:

- C++ coverage in `tests/test-recurrent-state-rollback.cpp` for raw-vs-compressed checkpoint round-trip
- server-level integration once a suitable recurrent/SWA test setup is available

Reason:

- checkpoint behavior is model/memory-backend specific
- the existing C++ recurrent rollback test already exercises the low-level checkpoint object

#### Logging/assertion support

Recommended test hooks:

- log markers for compressed prompt-cache store/restore
- log markers for compressed checkpoint create/restore

### Phase 7: Benchmark and tune

Before enabling any defaults, measure:

1. Prompt-cache resident bytes before/after compression
2. Checkpoint resident bytes before/after compression
3. Prompt-cache restore latency before/after compression
4. Prompt-processing latency impact when checkpoint compression is enabled
5. Reuse success rate under fixed `--cache-ram` budgets

Minimum benchmark scenarios:

- one long prompt reused many times
- branching prompt trees with small suffix differences
- recurrent/SWA checkpoint-heavy prefill

## File-by-File Change Map

| File | Planned change |
| --- | --- |
| `common/common.h` | Add new params; add blob metadata and checkpoint support helpers |
| `common/common.cpp` | Implement blob helper behavior and compressed checkpoint restore/load support |
| `common/arg.cpp` | Add new CLI flags and env vars |
| `tools/server/server-task.h` | Make prompt-cache state blob-aware; add raw/stored size helpers |
| `tools/server/server-task.cpp` | Update prompt cache allocation, load, update, and logging to understand compressed storage |
| `tools/server/server-context.cpp` | Apply prompt-cache compression policy in save/load path; apply checkpoint compression policy in create/restore path |
| `tools/server/CMakeLists.txt` | Link codec dependency into `server-context` |
| `tools/server/README.md` | Document the new options and their semantics |
| `tools/server/tests/unit/test_kv_keep_only_active.py` | Extend reuse tests for prompt-cache compression |
| `tools/server/tests/unit/test_slot_save.py` | Guard against regressions in slot save/restore behavior |
| `tests/test-recurrent-state-rollback.cpp` | Add compressed checkpoint round-trip coverage |

## Recommended Defaults for v1

Recommended first shipped behavior:

- `--prompt-cache-compress`: disabled by default
- `--prompt-cache-compress-threshold`: `128 MiB`
- `--ctx-checkpoints-compress`: disabled by default
- `--ctx-checkpoints-compress-threshold`: `64 MiB`
- `--state-compression-codec`: `auto`
- `--state-compression-level`: `balanced`

Rationale:

- the feature reduces RAM, but both save and restore happen on the server thread
- defaults should not change latency characteristics until benchmarked
- thresholds should prevent pointless work on small blobs
- `auto + balanced` gives a stable default once users enable either compression feature

## Open Questions

1. Should `zstd` be an optional build feature or a required dependency for server builds that enable state compression?
2. Should prompt-cache entries that exceed `--cache-ram` in raw form but fit after compression always be attempted, even if that increases temporary peak memory during save?
3. Should `/metrics` expose raw-vs-stored cache and checkpoint bytes in v1, or should that wait until after core correctness lands?
4. Should checkpoint compression remain byte-threshold-only in v1, or should a token-saved heuristic be added later as a separate optimization policy?
5. Should `balanced` map to a single fixed numeric level per codec, or should it be tuned per platform after benchmarks?

## Recommended Decision Set

For the first implementation, the least risky decision set is:

1. Keep compression runtime-configurable and disabled by default.
2. Expose shared global state-compression options with feasible user-visible variants:
   - codec: `auto`, `zlib`, `zstd`
   - level: `fast`, `balanced`, `best`
3. Keep per-feature enable/disable and threshold controls separate, but do not add per-feature codec/level overrides in v1.
4. Treat compression strictly as a RAM-usage optimization layered on top of existing backend capability rules.
5. Compress only prompt-cache full-state blobs and host-resident context checkpoints.
6. Leave speculative rollback checkpoints, token arrays, and on-disk session files unchanged.
7. Measure resident-memory reduction and restore latency before considering broader defaults or additional knobs.
