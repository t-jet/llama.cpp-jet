# Part 24 - Stage 11 fix L re-apply attempt: structural blocker

## 1. Scope and references

**Scope:** re-apply fix L (GGML meta-buffer reset path) from `fix_mtp_server_instability` tip `a4303153` to current HEAD `02db7a768`. Three code changes scoped to `ggml/src/ggml-backend-meta.cpp:1469-1475` (`ggml_backend_meta_buffer_reset`).

**References:**

- `._design_docs/cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md` Section 3 row L: fix L status **MISSING**. Current upstream body (taken at `e0f3f868b`) loops over `buf_ctx->bufs` and calls `ggml_backend_buffer_reset` per child; it does NOT clear `split_state_cache`, does NOT clear `simple_tensors`, and does NOT call `ggml_reset(ctx)` per child context. Fix-mtp body in `a4303153` actively clears `split_state_cache` and `simple_tensors` and iterates `buf_ctx->buf_configs` calling `ggml_reset(ctx)` per child.
- Same part-19 Section 7 R3: "the fix L (meta-buffer reset) is MISSING... Re-apply from `a4303153` in a future implementation gate per the user preservation policy."
- User preservation policy: keep `fix_mtp_server_instability` fixes until upstream has same or equivalent. Upstream does not have equivalent for fix L. Re-apply is required.
- `git show a4303153:ggml/src/ggml-backend-meta.cpp` is the approved source (full function body shown in Section 2).

**Outcome of this attempt: BLOCKED by structural divergence. No code changes applied. See Section 3 for field-level evidence.**

## 2. Approved source

From `git show a4303153:ggml/src/ggml-backend-meta.cpp`, the `ggml_backend_meta_buffer_reset` body to apply:

```cpp
static void ggml_backend_meta_buffer_reset(ggml_backend_buffer_t buffer) {
    GGML_ASSERT(ggml_backend_buffer_is_meta(buffer));

    auto * buf_ctx = (ggml_backend_meta_buffer_context *) buffer->context;

    // These caches reference per-reset tensor/context state and must not survive
    // into the next graph allocation cycle.
    buf_ctx->split_state_cache.clear();
    buf_ctx->simple_tensors.clear();

    for (auto & [ctx, buf] : buf_ctx->buf_configs) {
        ggml_reset(ctx);
        ggml_backend_buffer_reset(buf);
    }
}
```

## 3. Step-by-step implementation record (BLOCKED)

### Pre-check: current struct layout

`ggml_backend_meta_buffer_context` in `ggml/src/ggml-backend-meta.cpp` (lines 410-431, HEAD `02db7a768`):

```cpp
struct ggml_backend_meta_buffer_context {
    ggml_backend_meta_simple_tensor_container stc_static;
    ggml_backend_meta_simple_tensor_container stc_compute[2];
    int stc_compute_index      = 0;
    int stc_compute_index_next = 0;
    std::vector<ggml_backend_buffer_ptr> bufs;
    static constexpr size_t nbtc = GGML_TENSOR_SIZE - sizeof(ggml_tensor::padding);
    std::map<std::pair<const ggml_tensor *, bool>,
             std::pair<ggml_backend_meta_split_state, char[nbtc]>> split_state_cache;
    int debug;
    // ... constructor that takes stc_static, stc_compute_0, stc_compute_1, bufs ...
};
```

The current struct does NOT have a `buf_configs` field. The current struct does NOT have a `simple_tensors` field directly. The `simple_tensors` map lives inside `ggml_backend_meta_simple_tensor_container` (line 399), which is a separate struct embedded as `stc_static` and `stc_compute[2]`.

### Change 1: clear `buf_ctx->simple_tensors` - BLOCKED

**Before (current, lines 1469-1475):**

```cpp
static void ggml_backend_meta_buffer_reset(ggml_backend_buffer_t buffer) {
    GGML_ASSERT(ggml_backend_buffer_is_meta(buffer));
    ggml_backend_meta_buffer_context * buf_ctx = (ggml_backend_meta_buffer_context *) buffer->context;
    for (size_t i = 0; i < buf_ctx->bufs.size(); i++) {
        ggml_backend_buffer_reset(ggml_backend_meta_buffer_simple_buffer(buffer, i));
    }
}
```

**Intended after (from fix-mtp):**

```cpp
    buf_ctx->split_state_cache.clear();
    buf_ctx->simple_tensors.clear();
```

**Field-name notes:** `buf_ctx->split_state_cache` exists in current struct - safe. `buf_ctx->simple_tensors` does NOT exist in current struct. The closest equivalents are `buf_ctx->stc_static.simple_tensors`, `buf_ctx->stc_compute[0].simple_tensors`, and `buf_ctx->stc_compute[1].simple_tensors`. **The fix-mtp field does not compile against the current struct.** Direct application is not possible without first adding the `simple_tensors` field to `ggml_backend_meta_buffer_context` (structural change out of scope for the 3-line edit the task described). Build not run; this change is BLOCKED.

### Change 2: iterate `buf_ctx->buf_configs` - BLOCKED

**Intended after (from fix-mtp):**

```cpp
    for (auto & [ctx, buf] : buf_ctx->buf_configs) {
        ggml_reset(ctx);
        ggml_backend_buffer_reset(buf);
    }
```

**Field-name notes:** `buf_ctx->buf_configs` does NOT exist in the current struct. The current struct stores contexts in `stc_static.ctxs[j]`, `stc_compute[0].ctxs[j]`, `stc_compute[1].ctxs[j]`, and buffers in `buf_ctx->bufs[j]`; these are paired by index `j` at the use site (e.g., `ggml_backend_meta_buffer_init_tensor_impl` at lines 1205-1206: `ggml_context * simple_ctx = stc.ctxs[j].get(); ggml_backend_buffer_t simple_buf = buf_ctx->bufs[j].get();`). The fix-mtp design pairs ctx+buf inside a single `buffer_config` struct; the current design splits them across the `stc_*` containers and `bufs` vector. **The fix-mtp iteration target does not compile against the current struct.** Direct application is not possible without first adding a `buf_configs` field and refactoring the constructor, `alloc_buffer`, `free_buffer`, `n_bufs`, and `ggml_backend_meta_buffer_simple_buffer` (structural changes out of scope for the 3-line edit the task described). Build not run; this change is BLOCKED.

### Change 3: call `ggml_reset(ctx)` per child - BLOCKED

This change is a consequence of Changes 1 and 2: it lives inside the `for (auto & [ctx, buf] : buf_ctx->buf_configs)` loop from Change 2. Since Change 2 is blocked, Change 3 is also blocked. No independent diff hunk is applicable.

**Field-name notes:** in fix-mtp, the per-child call is `ggml_reset(cfg.ctx); ggml_backend_buffer_reset(cfg.buf);`. In the current code, the analogous reset (if a translation were authorized) would have to iterate the contexts in `stc_static.ctxs` and `stc_compute[0..1].ctxs` and call `ggml_reset` on each, paired with the corresponding `buf_ctx->bufs[j]` reset. Such a translation is an architectural decision, not a mechanical rename, and is not within the 3-line scope authorized by the task.

## 4. Build evidence

**Build not run.** Rationale: the three intended changes reference struct fields that do not exist in the current source tree. A build attempt would fail at compile time on the very first modified line, producing no useful evidence. The terminal's most recent build poll (`Get-Process cl,nvcc,MSBuild`) returned 0 active processes - the prior CUDA build had already exited before this Developer session began. The build invocation authorized by the task (`cmake --build build-cuda --config Release -j --target llama-server`) was not run because there is no compilation unit to feed it.

The fix-mtp body, verbatim, against the current struct:

```
ggml/src/ggml-backend-meta.cpp:1470:16: error: no member named 'simple_tensors' in 'ggml_backend_meta_buffer_context'
ggml/src/ggml-backend-meta.cpp:1472:36: error: no member named 'buf_configs' in 'ggml_backend_meta_buffer_context'
```

(anticipated; not actually executed.)

## 5. Diff evidence

`git diff -U2 ggml/src/ggml-backend-meta.cpp` (current state vs HEAD `02db7a768`):

```text
(empty - no changes applied)
```

`git diff --stat ggml/src/ggml-backend-meta.cpp`:

```text
(empty - 0 files changed, 0 insertions, 0 deletions)
```

## 6. Manager handoff

**Decision required.** The fix L re-apply cannot be expressed as a 3-line edit scoped to `ggml_backend_meta_buffer_reset` because the fix-mtp body depends on `ggml_backend_meta_buffer_context` having `buf_configs` and `simple_tensors` fields, and the current struct uses a different layout (rotating `stc_static` + `stc_compute[2]` containers with paired `bufs` vector, no `buf_configs`). Three possible paths:

1. **Authorise a structural refactor** of `ggml_backend_meta_buffer_context` to add `buf_configs` (paired `ctx`+`buf`) and a top-level `simple_tensors` map, mirroring the fix-mtp design. This touches the struct definition, the constructor, `ggml_backend_meta_buffer_type_alloc_buffer`, `ggml_backend_meta_buffer_free_buffer`, `ggml_backend_meta_buffer_n_bufs`, `ggml_backend_meta_buffer_simple_buffer`, and `ggml_backend_meta_buffer_init_tensor_impl` (which currently derives context/buffer pairs from `stc.ctxs[j]` and `buf_ctx->bufs[j]`). Scope is well beyond the 3-line fix the task description assumed.
2. **Authorise a translated fix** that clears `buf_ctx->split_state_cache` plus `buf_ctx->stc_static.simple_tensors` and `buf_ctx->stc_compute[0..1].simple_tensors`, then iterates `buf_ctx->stc_static.ctxs` and `buf_ctx->stc_compute[0..1].ctxs` calling `ggml_reset` paired with the same-index `buf_ctx->bufs[j]` `ggml_backend_buffer_reset`. This preserves the fix-mtp intent (clear all per-reset caches, reset every child context, reset every child buffer) within the current struct shape. Behaviour should match the fix-mtp body, but the pairing logic in `ggml_backend_meta_buffer_init_tensor_impl` (lines 1205-1206) is the source of truth for which `stc_*` container is "active" for which tensor - the translation must use the same pairing rule, which is by `j` index across `stc.ctxs[j]` and `buf_ctx->bufs[j]`.
3. **Defer fix L re-apply** until upstream changes the struct shape to match the fix-mtp design, or until a future gate is opened for the structural refactor.

Owner: Manager. **Submitting for independent Architect implementation review.** Next gate: Manager decision (path 1, 2, or 3) or Developer correction after a binding decision.
