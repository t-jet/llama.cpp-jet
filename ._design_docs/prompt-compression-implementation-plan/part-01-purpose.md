# Prompt Cache and Context Checkpoint Compression - Part 1: Purpose

Source: [../prompt-compression-implementation-plan.md](../prompt-compression-implementation-plan.md)

## Purpose

This document captures the requirements, current architecture analysis, and a concrete implementation plan for adding in-memory compression for:

1. Prompt cache full-state entries stored in `server_prompt_cache`
2. Host-resident context checkpoints stored in `server_prompt::checkpoints`

The intent is to reduce host RAM pressure in reuse-heavy and agentic workloads without changing inference semantics. The two compression features must be controlled independently from the command line and must each support a configurable compression threshold. The user should also be able to choose a shared compression codec and a shared compression level/profile for the in-memory state compression path.

## Scope Summary

In scope:

- Compressing prompt cache full-state blobs kept in RAM
- Compressing context checkpoint blobs kept in RAM
- Separate CLI flags and thresholds for the two features
- User-facing codec and compression-level options for the RAM-resident state compression path
- Correctness-preserving restore paths
- Documentation, tests, and basic observability

Out of scope for v1:

- Compressing prompt token arrays or prompt text
- Changing on-disk slot/session file formats
- Compressing speculative short-lived rollback state (`spec_ckpt`)
- Background or asynchronous compression threads
- Per-feature codec overrides
- Raw codec-specific numeric level knobs in the user CLI

## Current Architecture Analysis

### Relevant code paths

| Area | Files | Notes |
| --- | --- | --- |
| Server params and CLI | `common/common.h`, `common/arg.cpp`, `tools/server/README.md` | Existing knobs include `--cache-ram`, `--ctx-checkpoints`, and `--checkpoint-every-n-tokens`. |
| Prompt cache data structures | `tools/server/server-task.h`, `tools/server/server-task.cpp` | `server_prompt_cache`, `server_prompt`, `server_prompt_data`. |
| Prompt cache lifecycle | `tools/server/server-context.cpp` | `prompt_save()`, `prompt_load()`, and cache update inside slot selection. |
| Context checkpoint data structure | `common/common.h`, `common/common.cpp` | `common_prompt_checkpoint` stores raw serialized target and draft state. |
| Checkpoint creation and restore | `tools/server/server-context.cpp` | `checkpoint_update_tgt()`, `checkpoint_update_dft()`, `create_checkpoint()`, restore logic in `update_slots()`. |
| Serialized state API | `src/llama-context.cpp` | `llama_state_seq_get_size_ext()`, `llama_state_seq_get_data_ext()`, `llama_state_seq_set_data_ext()`. |
| Memory backend behavior | `src/llama-memory-hybrid.cpp`, `src/llama-kv-cache-iswa.cpp`, `src/llama-memory-recurrent.cpp`, `src/llama-kv-cache.cpp` | `PARTIAL_ONLY` changes what is serialized for hybrid and recurrent models. |
| Existing server reuse tests | `tools/server/tests/unit/test_kv_keep_only_active.py`, `tools/server/tests/unit/test_slot_save.py` | Good starting points for prompt-cache regressions. |

### What is currently stored

#### Prompt cache entries

`server_prompt` currently holds:

- `tokens`: the token sequence
- `data.main`: full serialized target state
- `data.drft`: full serialized draft state
- `checkpoints`: a list of context checkpoints attached to the prompt

`server_prompt::size()` sums `data.main`, `data.drft`, and all checkpoint byte vectors. There is no distinction between raw size and stored size because everything is stored raw today.

#### Context checkpoints

`common_prompt_checkpoint` currently holds:

- `n_tokens`, `pos_min`, `pos_max`
- `data_tgt`: serialized target partial state
- `data_dft`: serialized draft partial state

The checkpoint list is searched by position metadata only. The actual state bytes are loaded later by `load_tgt()` and `load_dft()`.

### Prompt cache lifecycle today

The relevant flow is:

1. `server_context::get_available_slot()` decides whether it should update the prompt cache.
2. `server_slot::prompt_save()` computes raw serialized sizes with `llama_state_seq_get_size_ext()`.
3. `server_prompt_cache::alloc()` preallocates raw vectors inside a cache entry.
4. `llama_state_seq_get_data_ext()` writes full raw state into those vectors.
5. Metadata and checkpoints are copied or moved into the cache entry.
6. `server_prompt_cache::load()` finds the best cached prompt using token LCP only.
7. `llama_state_seq_set_data_ext()` restores the raw bytes.
8. The stored raw state is cleared after restore.

Important details:

- Prompt cache storage is host RAM only.
- The current `alloc()` API is shaped around raw storage and a raw-size estimate.
- Cache eviction and accounting use `server_prompt::size()`, which currently means raw bytes.

### Context checkpoint lifecycle today

The relevant flow is:

1. `create_checkpoint()` computes a raw checkpoint budget using `llama_state_seq_get_size_ext()` with `LLAMA_STATE_SEQ_FLAGS_NONE` and a raw reserve using `LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY`.
2. `checkpoint_update_tgt()` and `checkpoint_update_dft()` allocate raw vectors and serialize partial state into them.
3. The checkpoint is appended to `slot.prompt.checkpoints`.
4. Later, `update_slots()` searches the checkpoint list by `pos_min` and `pos_max` and restores the chosen checkpoint with `load_tgt()` and `load_dft()`.

Important details:

- Checkpoint search uses position metadata only, not serialized bytes.
- Checkpoint restore is already separate from checkpoint selection.
- `checkpoints_size()` and trimming logic treat checkpoint bytes as raw bytes.

### Serializer constraints

The libllama serialization APIs currently require a contiguous caller-owned output buffer:

- `llama_state_seq_get_size_ext()` returns the exact serialized byte count.
- `llama_state_seq_get_data_ext()` writes the state into a caller-provided byte buffer.
- `llama_state_seq_set_data_ext()` reads from a caller-provided byte buffer.

This means v1 compression cannot avoid a temporary raw buffer unless the serializer is refactored to stream into a codec. That serializer refactor is out of scope here.

### Single-threaded server constraint

`tools/server/README-dev.md` documents that `server_context` runs on a dedicated single thread. Compression and decompression done inside `server_context` will therefore directly affect slot scheduling and prompt-processing throughput.

This is the main performance constraint for the design.

### Existing knobs and limits

The current server-side memory knobs are:

- `--cache-ram` / `params.cache_ram_mib`
- `--ctx-checkpoints` / `params.n_ctx_checkpoints`
- `--checkpoint-every-n-tokens` / `params.checkpoint_every_nt`
- `--cache-idle-slots`

There is currently no prompt-cache compression knob and no checkpoint-compression knob.

### Existing build/dependency picture

- `tools/server/server-context` is built in `tools/server/CMakeLists.txt` and links `llama-common`, `mtmd`, and threads.
- The HTTP executable links `cpp-httplib`, but `server-context` itself does not.
- `vendor/cpp-httplib` includes support for HTTP content compression, but that support is private to the HTTP layer and is not a reusable compression abstraction for prompt-cache state.

Conclusion: prompt-cache/checkpoint compression needs its own explicit helper and its own explicit build dependency decision.

### Observed memory profile from the provided log

The provided `._tmp/log2.txt` shows why both features matter:

- Full prompt-cache saves of about `1079 MiB`, `1230 MiB`, `1273 MiB`, `1314 MiB`, and `1369 MiB`
- Attached context checkpoints of about `166 MiB` to `220 MiB` each
- A cached prompt reaching about `2256 MiB` with `5` checkpoints attached

That means the dominant host-memory consumers are the serialized prompt state blobs first, then the checkpoint blobs. Token arrays are not the problem.

## Requirements

### Functional requirements

1. Prompt cache compression and context checkpoint compression must be independently controllable.
2. Each feature must have its own threshold option.
3. The feature must expose a shared state-compression codec option with 2-3 feasible user-visible variants.
4. The feature must expose a shared state-compression level/profile option with 2-3 feasible user-visible variants.
5. Thresholds must be evaluated using the uncompressed serialized payload size, not the compressed size.
6. When enabled and above threshold, data must be stored compressed while resident in RAM and decompressed only when needed for restore.
7. When compression is disabled, the current raw behavior must remain unchanged.
8. Restore behavior must remain bitwise equivalent to restoring the original raw serialized bytes.
9. Prompt selection and checkpoint selection semantics must remain unchanged.
10. Existing request/response APIs, including `timings.cache_n` and `timings.prompt_n`, must remain unchanged.
11. Existing slot/session file formats and `/slots?action=save|restore` semantics must remain unchanged.
12. The implementation must fail soft: compression failure must not break inference or prompt reuse; it should log and fall back to raw storage or skip storing the entry.

### Non-functional requirements

1. The feature must optimize resident host RAM, not necessarily transient serialization peak memory.
2. Compression must not require changes to model memory backends or the libllama serialized state format.
3. Compression must not add user-visible nondeterminism beyond the existing cache behavior.
4. The default setting should be conservative. Recommended v1 default: both compression features disabled by default.
5. Small blobs must avoid compression overhead via thresholds.
6. The codec and level surface should stay small and portable; users should not need to know codec-specific numeric tuning values.

### Compatibility requirements

1. `common_prompt_checkpoint` is used outside the server in `examples/speculative-simple` and `tests/test-recurrent-state-rollback.cpp`; any change must preserve raw default behavior there.
2. Compression metadata must be internal to RAM-resident structures and must not leak into file formats unless a separate file-format change is intentionally designed later.

### Observability requirements

At minimum, server logs should expose:

- whether a prompt-cache entry was stored raw or compressed
- whether a checkpoint was stored raw or compressed
- raw size, stored size, and compression ratio
- compression/decompression time in debug or info logs
- fallback cases where compression failed or was not beneficial

Optional but recommended for a follow-up:

- aggregate raw vs stored bytes in `/metrics`

### Recommended CLI surface

Recommended shared compression flags:

| Option | Variants | Env var | Notes |
| --- | --- | --- | --- |
| `--state-compression-codec CODEC` | `auto`, `zlib`, `zstd` | `LLAMA_ARG_STATE_COMPRESSION_CODEC` | `auto` prefers the best compiled-in codec, recommended order: `zstd` then `zlib`. Explicit `zstd` should fail fast if the binary was built without zstd support. |
| `--state-compression-level LEVEL` | `fast`, `balanced`, `best` | `LLAMA_ARG_STATE_COMPRESSION_LEVEL` | User-facing profiles that map to codec-specific numeric levels internally. |

Recommended design rule:

- codec and level should be shared across prompt-cache compression and checkpoint compression
- enable/disable and threshold remain per-feature
- v1 should not add prompt-cache-specific and checkpoint-specific codec/level overrides because that multiplies the tuning surface without first validating the simpler model

Recommended v1 flags:

| Feature | Enable/disable | Threshold | Env var |
| --- | --- | --- | --- |
| Prompt cache full-state compression | `--prompt-cache-compress`, `--no-prompt-cache-compress` | `--prompt-cache-compress-threshold N` | `LLAMA_ARG_PROMPT_CACHE_COMPRESS`, `LLAMA_ARG_PROMPT_CACHE_COMPRESS_THRESHOLD` |
| Context checkpoint compression | `--ctx-checkpoints-compress`, `--no-ctx-checkpoints-compress` | `--ctx-checkpoints-compress-threshold N` | `LLAMA_ARG_CTX_CHECKPOINTS_COMPRESS`, `LLAMA_ARG_CTX_CHECKPOINTS_COMPRESS_THRESHOLD` |

Recommended threshold semantics:

- unit: MiB of uncompressed serialized payload
- `0`: compress all eligible blobs when the feature is enabled
- default values if enabled: prompt cache `128 MiB`, checkpoints `64 MiB`

Notes:

- The prompt-cache threshold applies to the raw prompt-state payload (`main + drft`) only, not to the token vector.
- The checkpoint threshold applies to the raw checkpoint payload (`target + draft`) only.
- Prompt-cache and checkpoint compression remain independent even when both coexist inside the same cached prompt entry.
- Codec and level are shared so the user can reason about one compression policy while still enabling the two features separately.

## Proposed Architecture

### High-level approach

Add a small reusable state-blob abstraction that can hold either:

- raw serialized bytes, or
- compressed serialized bytes plus enough metadata to restore the original raw bytes

The feature should compress at rest in RAM only. Serialization and restore APIs remain unchanged:

- serialize raw bytes from libllama
- compress if policy says so
- keep compressed bytes in RAM
- decompress into a temporary scratch buffer only when restoring

### Recommended data model

Introduce a reusable blob helper, conceptually:

```text
enum codec { raw, zlib, zstd }  // actual stored encoding; `auto` resolves before storage

state_blob {
    codec encoding;
    uint32_t raw_size;
    std::vector<uint8_t> bytes;   // stored bytes: raw or compressed
}
```

Required helper behavior:

- `stored_size()` returns resident bytes in RAM
- `raw_size()` returns the original serialized size
- `is_compressed()` reports whether restore requires decompression
- `clear()` clears data and metadata
- `decompress_into(tmp)` materializes raw bytes for `llama_state_seq_set_data_ext()`

Recommended placement:

- put the generic blob helper in `common/` because `common_prompt_checkpoint` is not server-only
- keep server-specific compression policy and threshold handling in `tools/server/`

