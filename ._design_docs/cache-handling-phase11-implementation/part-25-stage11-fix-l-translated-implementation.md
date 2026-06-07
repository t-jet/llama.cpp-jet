# Part 25 - Stage 11 fix L translated re-apply (Path 2)

## 1. Scope and references

**Scope:** re-apply fix L (GGML meta-buffer reset path) from `fix_mtp_server_instability` tip `a4303153` to current HEAD `02db7a768` using the **translated** body (Path 2), preserving the fix-mtp behavioral intent within the current `ggml_backend_meta_buffer_context` struct shape. Single-file change: `ggml/src/ggml-backend-meta.cpp`, function `ggml_backend_meta_buffer_reset` (lines 1467-1473 in HEAD). No struct refactor. No other files touched.

**References:**

- `._design_docs/cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md` Section 3 row L: fix L status **MISSING**. Section 7 R3: "Re-apply from `a4303153` in a future implementation gate per the user preservation policy."
- `._design_docs/cache-handling-phase11-implementation/part-24-stage11-fix-l-reapply-implementation.md`: BLOCKED. Documented three paths (struct refactor, translated fix, defer). **User chose Path 2: translated fix.**
- User preservation policy: keep `fix_mtp_server_instability` fixes until upstream has same or equivalent. Upstream does not have an equivalent for fix L. Re-apply required.
- Approved source body: `git show a4303153:ggml/src/ggml-backend-meta.cpp` (full function body reproduced in Section 2 below; also in part-24 Section 2).
- Pairing source of truth: `ggml_backend_meta_buffer_init_tensor_impl` at `ggml/src/ggml-backend-meta.cpp:1205-1206` pairs `stc.ctxs[j]` with `buf_ctx->bufs[j]` by index `j`. This pairing rule is used implicitly by the translation (each `stc_*` container's contexts pair with `buf_ctx->bufs` slots that were allocated in the same ordering during `alloc_buffer`).

## 2. Approved behavior source

From `git show a4303153:ggml/src/ggml-backend-meta.cpp`, the `ggml_backend_meta_buffer_reset` body:

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

Behavioral intent:

1. Clear all per-reset caches (`split_state_cache`, `simple_tensors`).
2. For every child context, call `ggml_reset(ctx)`.
3. For every child buffer, call `ggml_backend_buffer_reset(buf)`.

## 3. Translation mapping table

| fix-mtp construct | current struct equivalent |
| --- | --- |
| `buf_ctx->split_state_cache.clear()` | `buf_ctx->split_state_cache.clear()` (identical) |
| `buf_ctx->simple_tensors.clear()` | three calls: `buf_ctx->stc_static.simple_tensors.clear()`, `buf_ctx->stc_compute[0].simple_tensors.clear()`, `buf_ctx->stc_compute[1].simple_tensors.clear()` |
| iterate `buf_ctx->buf_configs` | no aggregate. Iterate the contexts across `stc_static.ctxs`, `stc_compute[0].ctxs`, `stc_compute[1].ctxs` (3 loops) and call `ggml_reset(ctx.get())` per element. Buffers are reset via the existing `for (size_t i = 0; i < buf_ctx->bufs.size(); i++)` loop using `ggml_backend_meta_buffer_simple_buffer(buffer, i)`. |
| `ggml_reset(ctx)` | `ggml_reset(ctx.get())` (current field is `std::unique_ptr<ggml_context, ggml_context_deleter>`; matches the existing pattern at `ggml_backend_meta.cpp:1808`) |
| `ggml_backend_buffer_reset(buf)` | `ggml_backend_buffer_reset(ggml_backend_meta_buffer_simple_buffer(buffer, i))` (existing helper, same call shape as the pre-edit body) |

## 4. Step-by-step implementation record

### Before (HEAD `02db7a768`, lines 1467-1473)

```cpp
static void ggml_backend_meta_buffer_reset(ggml_backend_buffer_t buffer) {
    GGML_ASSERT(ggml_backend_buffer_is_meta(buffer));
    ggml_backend_meta_buffer_context * buf_ctx = (ggml_backend_meta_buffer_context *) buffer->context;
    for (size_t i = 0; i < buf_ctx->bufs.size(); i++) {
        ggml_backend_buffer_reset(ggml_backend_meta_buffer_simple_buffer(buffer, i));
    }
}
```

### After

```cpp
static void ggml_backend_meta_buffer_reset(ggml_backend_buffer_t buffer) {
    GGML_ASSERT(ggml_backend_buffer_is_meta(buffer));
    ggml_backend_meta_buffer_context * buf_ctx = (ggml_backend_meta_buffer_context *) buffer->context;

    // Clear per-reset caches that must not survive into the next graph allocation cycle.
    buf_ctx->split_state_cache.clear();
    buf_ctx->stc_static.simple_tensors.clear();
    buf_ctx->stc_compute[0].simple_tensors.clear();
    buf_ctx->stc_compute[1].simple_tensors.clear();

    // Reset every child buffer.
    for (size_t i = 0; i < buf_ctx->bufs.size(); i++) {
        ggml_backend_buffer_reset(ggml_backend_meta_buffer_simple_buffer(buffer, i));
    }

    // Reset every child context across the rotating stc containers.
    for (ggml_context_ptr & ctx : buf_ctx->stc_static.ctxs) {
        ggml_reset(ctx.get());
    }
    for (ggml_context_ptr & ctx : buf_ctx->stc_compute[0].ctxs) {
        ggml_reset(ctx.get());
    }
    for (ggml_context_ptr & ctx : buf_ctx->stc_compute[1].ctxs) {
        ggml_reset(ctx.get());
    }
}
```

### Diff hunk

```text
@@ -1470,7 +1470,26 @@ static void ggml_backend_meta_buffer_reset(ggml_backend_buffer_t buffer) {
     GGML_ASSERT(ggml_backend_buffer_is_meta(buffer));
     ggml_backend_meta_buffer_context * buf_ctx = (ggml_backend_meta_buffer_context *) buffer->context;
+
+    // Clear per-reset caches that must not survive into the next graph allocation cycle.
+    buf_ctx->split_state_cache.clear();
+    buf_ctx->stc_static.simple_tensors.clear();
+    buf_ctx->stc_compute[0].simple_tensors.clear();
+    buf_ctx->stc_compute[1].simple_tensors.clear();
+
+    // Reset every child buffer.
     for (size_t i = 0; i < buf_ctx->bufs.size(); i++) {
         ggml_backend_buffer_reset(ggml_backend_meta_buffer_simple_buffer(buffer, i));
     }
+
+    // Reset every child context across the rotating stc containers.
+    for (ggml_context_ptr & ctx : buf_ctx->stc_static.ctxs) {
+        ggml_reset(ctx.get());
+    }
+    for (ggml_context_ptr & ctx : buf_ctx->stc_compute[0].ctxs) {
+        ggml_reset(ctx.get());
+    }
+    for (ggml_context_ptr & ctx : buf_ctx->stc_compute[1].ctxs) {
+        ggml_reset(ctx.get());
+    }
 }
```

## 5. Field-name notes

All fields used by the translation were verified against the current source tree before writing the code.

- `buf_ctx->split_state_cache` - exists at `ggml/src/ggml-backend-meta.cpp:425`. Same type as in fix-mtp (`std::map<std::pair<const ggml_tensor *, bool>, std::pair<ggml_backend_meta_split_state, char[nbtc]>>`). Unchanged.
- `buf_ctx->stc_static.simple_tensors`, `buf_ctx->stc_compute[0].simple_tensors`, `buf_ctx->stc_compute[1].simple_tensors` - exist inside `ggml_backend_meta_simple_tensor_container` at `ggml/src/ggml-backend-meta.cpp:399`. Type: `std::map<const ggml_tensor *, std::vector<ggml_tensor *>>`. Used in `ggml_backend_meta_buffer_init_tensor_impl` at line 1210 and in `ggml_backend_meta_graph_compute` at line 1810.
- `buf_ctx->stc_static.ctxs`, `buf_ctx->stc_compute[0].ctxs`, `buf_ctx->stc_compute[1].ctxs` - exist at `ggml/src/ggml-backend-meta.cpp:398`. Type: `std::vector<ggml_context_ptr>` where `ggml_context_ptr` is `std::unique_ptr<ggml_context, ggml_context_deleter>` (defined in `ggml/include/ggml-cpp.h:20`). Used in `ggml_backend_meta_graph_compute` at line 1808: `for (ggml_context_ptr & ctx : stc.ctxs) { ggml_reset(ctx.get()); }`. The translation reuses this exact idiom.
- `buf_ctx->bufs` - exists at `ggml/src/ggml-backend-meta.cpp:420`. Type: `std::vector<ggml_backend_buffer_ptr>`. Unchanged from the pre-edit body.
- `ggml_backend_meta_buffer_simple_buffer(buffer, i)` - the existing helper used in the pre-edit body; same call shape in the post-edit body.

No field name required adaptation (no `ctxs` vs `contexts`, no `ctx_up` vs `ctx_ptr` mismatch).

## 6. Build evidence

Build command: `cmake --build build-cuda --config Release -j --target llama-server`.

Build log: `._design_docs/.test_reports/build-cuda-fix-l-translated-20260606-01.log`.

Exit code: **0** (build succeeded).

Build timestamp: started 2026-06-06 15:53 (approximate), finished 2026-06-06 15:53:56. Incremental build: only the touched translation unit and downstream lib/server components recompiled.

Last 50 lines of build log:

```text
-- Adding CPU backend variant ggml-cpu: /arch:AVX2 GGML_AVX2;GGML_FMA;GGML_F16C;__BMI2__;GGML_BMI2
-- CUDA Toolkit found
-- Replacing 120-real in CMAKE_CUDA_ARCHITECTURES_NATIVE with 120a-real
-- Using CMAKE_CUDA_ARCHITECTURES=75-virtual;80-virtual;86-real;89-real;90-virtual;120a-real;121a-real CMAKE_CUDA_ARCHITECTURES_NATIVE=120a-real
-- Could NOT find NCCL (missing: NCCL_LIBRARY NCCL_INCLUDE_DIR)
-- Warning: NCCL not found, performance for multiple CUDA GPUs will be suboptimal
-- Including CUDA backend
-- ggml version: 0.13.1
-- ggml commit:  02db7a768-dirty
-- Could NOT find OpenSSL, try the path to OpenSSL root folder in the system variable OPENSSL_ROOT_DIR (missing: OPENSSL_CRYPTO_LIBRARY OPENSSL_INCLUDE_DIR)
CMake Warning at vendor/cpp-httplib/CMakeLists.txt:152 (message):
  OpenSSL not found, HTTPS support disabled


-- Generating embedded license file for target: llama-app
-- Configuring done (1.5s)
-- Generating done (6.6s)
-- Build files have been written to: D:/source/llama.cpp-jet/build-cuda
MSBuild version 17.14.40+3e7442088 for .NET Framework

  1>Checking Build System
  cpp-httplib.vcxproj -> D:\source\llama.cpp-jet\build-cuda\vendor\cpp-httplib\Release\cpp-httplib.lib
  llama-common-base.vcxproj -> D:\source\llama.cpp-jet\build-cuda\common\Release\llama-common-base.lib
  ggml-quants.c
  ggml-backend-meta.cpp
  gguf.cpp
  ggml-opt.cpp
  llama-ui-embed.vcxproj -> D:\source\llama.cpp-jet\build-cuda\tools\ui\Release\llama-ui-embed.exe
  ggml.cpp
  ggml-alloc.c
  ggml-threading.cpp
  ggml.c
  ggml-backend.cpp
  1>Provisioning UI assets
  -- UI: npm output up-to-date, skipping build
  llama-ui.vcxproj -> D:\source\llama.cpp-jet\build-cuda\tools\ui\Release\llama-ui.lib
  ggml-base.vcxproj -> D:\source\llama.cpp-jet\ggml\src\Release\ggml-base.lib
  ggml-cpu.vcxproj -> D:\source\llama.cpp-jet\ggml\src\Release\ggml-cpu.lib
  Building Custom Rule D:/source/llama.cpp-jet/ggml/src/ggml-cuda/CMakeLists.txt
  ggml-cuda.vcxproj -> D:\source\llama.cpp-jet\ggml\src\ggml-cuda\Release\ggml-cuda.lib
  ggml.vcxproj -> D:\source\llama.cpp-jet\ggml\src\Release\ggml.lib
  llama.vcxproj -> D:\source\llama.cpp-jet\src\Release\llama.lib
  llama-common.vcxproj -> D:\source\llama.cpp-jet\common\Release\llama-common.lib
  mtmd.vcxproj -> D:\source\llama.cpp-jet\tools\mtmd\Release\mtmd.lib
  server-context.cpp
  server-context.vcxproj -> D:\source\llama.cpp-jet\tools\server\Release\server-context.lib
  llama-server-impl.vcxproj -> D:\source\llama.cpp-jet\tools\server\Release\llama-server-impl.lib
LINK : warning LNK4098: defaultlib 'LIBCMT' conflicts with use of other libs; use /NODEFAULTLIB:library [D:\source\llama.cpp-jet\build-cuda\tools\server\llama-server.vcxproj]
  llama-server.vcxproj -> D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe
=== Build exit: 0 06/06/2026 15:53:56 ===
```

`ggml-backend-meta.cpp` compiled cleanly. `llama-server.exe` was relinked. No new errors or warnings. The `LIBCMT` LNK4098 warning is pre-existing in the linker step and is unrelated to the fix.

## 7. Diff evidence

`git diff -U2 ggml/src/ggml-backend-meta.cpp`:

```text
diff --git a/ggml/src/ggml-backend-meta.cpp b/ggml/src/ggml-backend-meta.cpp
index 8c44c3e44..27954d2ea 100644
--- a/ggml/src/ggml-backend-meta.cpp
+++ b/ggml/src/ggml-backend-meta.cpp
@@ -1470,7 +1470,26 @@ static void ggml_backend_meta_buffer_reset(ggml_backend_buffer_t buffer) {
     GGML_ASSERT(ggml_backend_buffer_is_meta(buffer));
     ggml_backend_meta_buffer_context * buf_ctx = (ggml_backend_meta_buffer_context *) buffer->context;
+
+    // Clear per-reset caches that must not survive into the next graph allocation cycle.
+    buf_ctx->split_state_cache.clear();
+    buf_ctx->stc_static.simple_tensors.clear();
+    buf_ctx->stc_compute[0].simple_tensors.clear();
+    buf_ctx->stc_compute[1].simple_tensors.clear();
+
+    // Reset every child buffer.
     for (size_t i = 0; i < buf_ctx->bufs.size(); i++) {
         ggml_backend_buffer_reset(ggml_backend_meta_buffer_simple_buffer(buffer, i));
     }
+
+    // Reset every child context across the rotating stc containers.
+    for (ggml_context_ptr & ctx : buf_ctx->stc_static.ctxs) {
+        ggml_reset(ctx.get());
+    }
+    for (ggml_context_ptr & ctx : buf_ctx->stc_compute[0].ctxs) {
+        ggml_reset(ctx.get());
+    }
+    for (ggml_context_ptr & ctx : buf_ctx->stc_compute[1].ctxs) {
+        ggml_reset(ctx.get());
+    }
 }
```

`git diff --stat ggml/src/ggml-backend-meta.cpp`: 1 file changed, 19 insertions(+), 0 deletions(-).

`git diff --check HEAD -- ggml/src/ggml-backend-meta.cpp`: exit code 0 (clean).

## 8. Manager handoff

Submitting for independent Architect implementation review. Owner: Manager. Next gate: Implementation review (Architect) or Developer correction.
