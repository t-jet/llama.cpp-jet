# Prompt Cache and Context Checkpoint Compression - Part 2: Prompt cache design

Source: [../prompt-compression-implementation-plan.md](../prompt-compression-implementation-plan.md)

### Prompt cache design

#### Prompt cache data changes

`server_prompt_data` should stop being just two raw byte vectors and instead hold two state blobs:

- target full-state blob
- draft full-state blob

#### Prompt cache save path

`server_slot::prompt_save()` should:

1. Query raw serialized sizes as it already does.
2. Decide whether prompt-cache compression is eligible using the raw combined size of `main + drft` and the configured prompt-cache threshold.
3. Serialize `main` into a temporary raw buffer.
4. If eligible, try to compress `main` immediately and release the raw buffer.
5. Serialize `drft` into a temporary raw buffer.
6. If eligible, try to compress `drft` immediately and release the raw buffer.
7. Store the resulting blobs in the cache entry.

Compressing each component immediately after serialization is important because it reduces peak memory versus holding raw `main` and raw `drft` at the same time.

#### Load path

`server_prompt_cache::load()` should:

1. Select the best prompt using tokens only, exactly as today.
2. For each stored blob, either:
   - pass raw bytes directly to `llama_state_seq_set_data_ext()`, or
   - decompress into a temporary scratch buffer and then restore
3. Clear the stored blobs after successful restore, exactly as today.

#### Cache accounting and eviction

`server_prompt::size()` should become resident-size accounting, not raw-size accounting.

Recommended additional helpers:

- `server_prompt::size_raw()` for diagnostics
- `server_prompt_data::size_raw()`
- `server_prompt_data::size_stored()`

This lets cache eviction continue to use actual resident bytes while logs can still show raw-vs-stored ratios.

#### `server_prompt_cache::alloc()` problem

The current `alloc()` API assumes a raw final representation and performs an early raw-size limit check:

```text
estimated_size = prompt.size() + state_size_tgt + state_size_dft
```

That is wrong once compression exists because an entry that is too large in raw form may still fit after compression.

Recommended v1 change:

- keep the API shape if possible, but only apply the raw early-skip check when prompt-cache compression is disabled
- when prompt-cache compression is enabled, allow provisional allocation and enforce the final cache limit after compression via `update()`

Alternative cleaner refactor, if the code churn is acceptable:

- replace `alloc()`/`discard()` with a two-phase `prepare -> serialize/compress -> commit` flow

The first option is smaller. The second option is architecturally cleaner.

### Context checkpoint design

#### Checkpoint data changes

`common_prompt_checkpoint` should gain enough metadata to know whether `data_tgt` and `data_dft` are raw or compressed, plus the raw sizes needed for decompression.

Because the type is used outside the server, raw behavior must remain the default.

#### Checkpoint save path

The server already has custom wrappers:

- `checkpoint_update_tgt()`
- `checkpoint_update_dft()`

Those wrappers should:

1. Query raw serialized size.
2. Decide whether checkpoint compression is eligible using the combined raw size of `tgt + dft` and the checkpoint threshold.
3. Serialize raw bytes.
4. Compress immediately if eligible.
5. Store metadata needed for later restore.

#### Restore path

Checkpoint selection in `update_slots()` should remain unchanged.

Only the actual payload restore should change:

- raw checkpoint: current path
- compressed checkpoint: decompress temporary scratch buffer, then call `llama_state_seq_set_data_ext()`

#### Size accounting and trimming

`common_prompt_checkpoint::size()` should represent resident stored bytes.

Recommended extra helper:

- `common_prompt_checkpoint::size_raw()`

That makes existing trimming logic more useful because it will trim based on real resident memory, while `checkpoint_reserve` can continue using raw serializer sizes to avoid transient allocation spikes.

### Explicitly out of scope: speculative rollback state

`spec_ckpt` in `server_context.cpp` is short-lived, can use `LLAMA_STATE_SEQ_FLAGS_ON_DEVICE`, and is on the hot speculative path. It should remain uncompressed in v1.

Reason:

- it is not the primary host RAM pressure target
- it is restored very frequently
- it sits on a more latency-sensitive path

### Codec strategy

The code should hide the codec behind a tiny helper interface so the server logic does not depend on a particular compression library.

Recommended user-facing compression configuration:

- `--state-compression-codec auto`
- `--state-compression-codec zlib`
- `--state-compression-codec zstd`
- `--state-compression-level fast`
- `--state-compression-level balanced`
- `--state-compression-level best`

Recommended semantics:

- `auto` is the default codec choice and resolves to the best available compiled-in codec
- `fast`, `balanced`, and `best` are portable profiles, not raw numeric levels
- the profile is translated internally into codec-specific numeric levels

Illustrative mappings for benchmarking and tuning:

- `zlib`: `fast -> 1`, `balanced -> 6`, `best -> 9`
- `zstd`: `fast -> 1`, `balanced -> 3` or `5`, `best -> 9` or `12`

The exact numeric mapping should be benchmark-driven and may be adjusted without changing the CLI surface.

Recommended v1 practical implementation:

- implement a codec wrapper that supports more than one backend
- keep the wrapper narrow enough that prompt-cache/checkpoint call sites do not care whether the actual codec is `zlib` or `zstd`
- store the actual codec used in each blob; do not store `auto`

Trade-off analysis:

- `zlib` is the lowest-risk baseline because it is already present in the server toolchain through `cpp-httplib`, although `server-context` still needs its own explicit build wiring and should not rely on the HTTP library to carry that dependency implicitly.
- `zstd` is likely the better fit for large in-memory blobs because decompression speed matters more than peak ratio here, but it requires deliberate build support.
- `auto` gives users a stable default while still letting advanced users force a specific codec for benchmarking or troubleshooting.

Recommendation for this plan:

- expose a shared codec selector and a shared level/profile selector in v1
- make `zlib` the minimum supported implementation path
- add `zstd` as an optional but preferred high-performance path
- use `auto + balanced` as the default compression policy when compression is enabled
- do not expose raw numeric codec-specific levels in v1

### Failure handling

The feature should be fail-soft.

Required behavior:

- If compression is disabled: current raw behavior
- If compression is enabled but threshold not met: store raw
- If compression is enabled but compression fails: log and store raw if possible
- If compression output is not smaller than raw by a meaningful amount: keep raw
- If allocation fails while preparing cache storage: follow the current prompt-cache limit-reduction behavior and skip caching if needed
- If decompression fails: log, discard that cache/checkpoint object if appropriate, and fall back to normal recomputation behavior

### Logging and metrics

Recommended new log lines:

- prompt cache save: raw size, stored size, codec, ratio, compression time
- prompt cache restore: raw size, stored size, codec, decompression time
- checkpoint create: raw size, stored size, codec, ratio, compression time
- checkpoint restore: raw size, stored size, codec, decompression time

Recommended future metrics additions:

- total prompt-cache resident bytes vs raw logical bytes
- total checkpoint resident bytes vs raw logical bytes
- compression hit count and fallback count

## Implementation Plan

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

Acceptance criteria:

- help text renders correctly
- README table documents the new flags
- invalid explicit codec choices are rejected clearly
- default behavior is unchanged

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

