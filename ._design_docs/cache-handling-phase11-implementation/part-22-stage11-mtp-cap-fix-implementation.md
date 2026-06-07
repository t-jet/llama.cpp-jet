# Stage 11 follow-up: n_outputs_max cap fix - implementation

Source plan: `part-20-stage11-mtp-cap-fix-implementation-plan.md` (PASS in plan review).
Source plan review: `part-21-stage11-mtp-cap-fix-plan-review-gate-01.md` (PASS, 0 BLOCKER / 3 NON-BLOCKER / 2 ADVISORY).
Design baseline: `cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md`.
Architecture invariant: `cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md`.
Investigation (trusted): `part-19-stage11-mtp-crash-investigation.md`.
Head commit: `02db7a768`. Build dir: `build-cuda` (Visual Studio 17 2022, x64, Release, GGML_CUDA=ON, GGML_NATIVE=OFF, BUILD_SHARED_LIBS=OFF).

## 1. Scope and references

Single-file change. Code edits only in `tools/server/server-context.cpp` at the three sites specified in the plan:

- `:3750` (chunked-decode bound, per-context cap, bounded `SRV_DBG` line).
- `:1175` (draft MTP cap-bump, two-branch assignment).
- `:1308` (MTP cparams cap-bump, symmetric formula with clamp).

No commits, no pushes, no model runs, no coverage, no k6, no test plan edits. Three F-21 corrections from the plan review applied in-place.

## 2. Step-by-step implementation record

### Step 1 - chunked-decode bound at `:3750`

Before:

```cpp
        for (int32_t i = 0; i < batch.n_tokens; i = i_next) {
            const int32_t n_tokens = std::min(n_batch, batch.n_tokens - i);

            llama_batch batch_view = {
                n_tokens,
                batch.token    + i,
                nullptr,
                batch.pos      + i,
                batch.n_seq_id + i,
                batch.seq_id   + i,
                batch.logits   + i,
            };

            const int ret = llama_decode(ctx_tgt, batch_view);
```

After:

```cpp
        for (int32_t i = 0; i < batch.n_tokens; i = i_next) {
            const int32_t n_tokens = std::min({
                n_batch,
                batch.n_tokens - i,
                (int32_t) params_base.n_outputs_max
            });

            llama_batch batch_view = {
                n_tokens,
                batch.token    + i,
                nullptr,
                batch.pos      + i,
                batch.n_seq_id + i,
                batch.seq_id   + i,
                batch.logits   + i,
            };

            SRV_DBG("srv  update_slots: speculative chunked decode, chunk=%d n_tokens=%d cap=%d\n",
                    i / std::max<int32_t>(1, n_batch), n_tokens, (int32_t) params_base.n_outputs_max);

            const int ret = llama_decode(ctx_tgt, batch_view);
```

Diff hunk header: `@@ -3747,5 +3755,9 @@` (5 old, 9 new; +4 net).

F-21 correction applied: F-21-01 - `%u` to `%d` for the `int32_t` cap argument in the new `SRV_DBG` line. `params_base.n_outputs_max` is `int32_t` (common/common.h:441); `%u` would be undefined behavior on negative values under the C standard.

### Step 2 - draft MTP cap-bump at `:1175`

Before:

```cpp
                params_dft.n_outputs_max = params_base.n_parallel;
```

After:

```cpp
                if (spec_mtp) {
                    params_dft.n_outputs_max = std::min<uint32_t>(
                        static_cast<uint32_t>(params_base.n_batch),
                        static_cast<uint32_t>(params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative))));
                } else {
                    params_dft.n_outputs_max = params_base.n_parallel;
                }
```

Diff hunk header: `@@ -1173,5 +1173,11 @@` (5 old, 11 new; +6 net).

F-21 correction applied: F-21-02 - replaced `std::min<uint64_t>(...)` with `std::min<uint32_t>(...)` and added `static_cast<uint32_t>(...)` on both arguments to match upstream `server_n_outputs_max` cast style and to suppress the implicit-narrowing warning when assigning to `uint32_t` (`llama_context_params::n_outputs_max`, include/llama.h:342). F-09-01 `min(n_batch, ...)` clamp retained.

### Step 3 - MTP cparams cap-bump at `:1308`

Before:

```cpp
            cparams_mtp.n_outputs_max = params_base.n_parallel;
```

After:

```cpp
            cparams_mtp.n_outputs_max = std::min<uint32_t>(
                static_cast<uint32_t>(params_base.n_batch),
                static_cast<uint32_t>(params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative))));
```

Diff hunk header: `@@ -1306,5 +1312,7 @@` (5 old, 7 new; +2 net).

F-21 correction applied: F-21-02 - same as Step 2. Symmetric formula with the `min(n_batch, ...)` clamp per F-09-01.

## 3. F-21 corrections table

| ID | Location | Before | After | Reason |
| --- | --- | --- | --- | --- |
| F-21-01 | `tools/server/server-context.cpp:3774` (new `SRV_DBG` line) | `cap=%u` (plan snippet) | `cap=%d` (applied) | `params_base.n_outputs_max` is `int32_t` (common/common.h:441); `%u` is undefined behavior for `int32_t` values that are negative. F-21 review suggested change to `%d`. |
| F-21-02 | `tools/server/server-context.cpp:1175` and `:1308` (cap-bump formulas) | `std::min<uint64_t>(params_base.n_batch, ...)` (plan snippet) | `std::min<uint32_t>(static_cast<uint32_t>(params_base.n_batch), static_cast<uint32_t>(...))` (applied) | Target fields are `uint32_t`; implicit narrowing from `int32_t` arithmetic to `uint32_t` triggers `/W4` warnings. Explicit `static_cast<uint32_t>(...)` matches the surrounding code's cast discipline and is symmetric with upstream `server_n_outputs_max` at `:204`. |
| F-21-03 | Plan-only (not a code change) | Architecture `part-07` per-context vs per-sequence wording drift is recorded as a tracked risk row in the plan's Section 6; tracked as a separate Architect follow-up correction pass, not a code risk. | n/a | F-21-03 is a documentation/owner note. The plan already captures it in the "Known risks" section and the implementation plan does not edit `part-07`. The Architect follow-up correction is out of scope for this Developer implementation gate. |

F-21-04 (ADVISORY) and F-21-05 (ADVISORY) from the plan review are non-blocking style notes for future plans; F-21-05 (C-style cast vs `static_cast`) is not a F-21 correction and is not applied.

## 4. F-09-04 disposition

The plan review (F-09-04 verification row, `part-21` Section 3) confirms that the test plan rows H53/H54/H57 in `cache-handling-test-plan/part-03-integration-test-matrix.md` (lines 137, 138, 141) do not reference `cparams_mtp.n_outputs_max == n_parallel`. Therefore the test plan follow-up sub-task is moot. The test plan is not edited in this gate. T-NOUT-MAX-01 and T-NOUT-MAX-02 rows in the plan's Section 3 remain plan-only proposals for a future test-plan follow-up gate.

## 5. Build evidence

Command: `cmake --build build-cuda --config Release -j --target llama-server`.

Last 50 lines of build log (`build/build-capfix.log`):

```text
  is newer than 'D:/source/llama.cpp-jet/build-cuda/common/CMakeFiles/generate.stamp.depend'
  result='-1'
-- Selecting Windows SDK version 10.0.26100.0 to target Windows 10.0.26200.
CMAKE_BUILD_TYPE=
-- Warning: ccache not found - consider installing it for faster compilation or disable this warning with GGML_CCACHE=OFF
-- CMAKE_SYSTEM_PROCESSOR: AMD64
-- CMAKE_GENERATOR_PLATFORM: x64
-- GGML_SYSTEM_ARCH: x86
-- Including CPU backend
-- x86 detected
-- Adding CPU backend variant ggml-cpu: /arch:AVX2 GGML_AVX2;GGML_FMA;GGML_F16C;__BMI2__;GGML_BMI2
-- CUDA Toolkit found
-- Replacing 120-real in CMAKE_CUDA_ARCHITECTURES_NATIVE with 120a-real
-- Using CMAKE_CUDA_ARCHITECTURES=75-virtual;80-virtual;86-real;89-real;90-virtual;120a-real;121a-real CMAKE_CUDA_ARCHITECTURES_NATIVE=120a-real
-- Could NOT find NCCL (missing: NCCL_LIBRARY NCCL_INCLUDE_DIR)
-- Warning: NCCL not found, performance for multiple CUDA GPUs will be suboptimal
-- Including CUDA backend
-- ggml version: 0.13.1
-- ggml commit:  02db7a768
-- Could NOT find OpenSSL, try to set the path to OpenSSL root folder in the system variable OPENSSL_ROOT_DIR (missing: OPENSSL_CRYPTO_LIBRARY OPENSSL_INCLUDE_DIR)
CMake Warning at vendor/cpp-httplib/CMakeLists.txt:152 (message):
  OpenSSL not found, HTTPS support disabled


-- Generating embedded license file for target: llama-app
-- Configuring done (2.4s)
-- Generating done (9.0s)
-- Build files have been written to: D:/source/llama.cpp-jet/build-cuda
MSBuild version 17.14.40+3e7442088 for .NET Framework

  1>Checking Build System
  llama-common-base.vcxproj -> D:\source\llama.cpp-jet\build-cuda\common\Release\llama-common-base.lib
  llama-ui-embed.vcxproj -> D:\source\llama.cpp-jet\build-cuda\tools\ui\Release\llama-ui-embed.exe
  ggml-base.vcxproj -> D:\source\llama.cpp-jet\build-cuda\ggml\src\Release\ggml-base.lib
  cpp-httplib.vcxproj -> D:\source\llama.cpp-jet\build-cuda\vendor\cpp-httplib\Release\cpp-httplib.lib
  1>Provisioning UI assets
  Building Custom Rule D:/source/llama.cpp-jet/ggml/src/ggml-cuda/CMakeLists.txt
  -- UI: npm output up-to-date, skipping build
  ggml-cpu.vcxproj -> D:\source\llama.cpp-jet\build-cuda\ggml\src\Release\ggml-cpu.lib
  llama-ui.vcxproj -> D:\source\llama.cpp-jet\build-cuda\tools\ui\Release\llama-ui.lib
  ggml-cuda.vcxproj -> D:\source\llama.cpp-jet\ggml\src\ggml-cuda\Release\ggml-cuda.lib
  ggml.vcxproj -> D:\source\llama.cpp-jet\ggml\src\Release\ggml.lib
  llama.vcxproj -> D:\source\llama.cpp-jet\src\Release\llama.lib
  llama-common.vcxproj -> D:\source\llama.cpp-jet\common\Release\llama-common.lib
  mtmd.vcxproj -> D:\source\llama.cpp-jet\tools\mtmd\Release\mtmd.lib
  server-context.cpp
  server-context.vcxproj -> D:\source\llama.cpp-jet\build-cuda\tools\server\Release\server-context.lib
  llama-server-impl.vcxproj -> D:\source\llama.cpp-jet\tools\server\Release\llama-server-impl.lib
LINK : warning LNK4098: defaultlib 'LIBCMT' conflicts with use of other libs; use /NODEFAULTLIB:library [D:\source\llama.cpp-jet\build-cuda\tools\server\llama-server.vcxproj]
  llama-server.vcxproj -> D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe
```

- Exit code: 0 (build succeeded; LNK4098 is a pre-existing unrelated defaultlib warning).
- `server-context.cpp` recompiled (incremental); `llama-server.exe` relinked.
- Total build wall time observed: about 2 minutes 15 seconds (CUDA libs and CPU libs were rebuilt because of the configure stamp churn; the actual `server-context.cpp` compile to `llama-server.exe` link ran in seconds after the dependency libs were emitted).

## 6. Diff evidence

`git diff -U2 tools/server/server-context.cpp`:

```diff
diff --git a/tools/server/server-context.cpp b/tools/server/server-context.cpp
index f70f3a5c8..6d0780b46 100644
--- a/tools/server/server-context.cpp
+++ b/tools/server/server-context.cpp
@@ -1173,5 +1173,11 @@ private:
                 }

-                params_dft.n_outputs_max = params_base.n_parallel;
+                if (spec_mtp) {
+                    params_dft.n_outputs_max = std::min<uint32_t>(
+                        static_cast<uint32_t>(params_base.n_batch),
+                        static_cast<uint32_t>(params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative))));
+                } else {
+                    params_dft.n_outputs_max = params_base.n_parallel;
+                }

                 auto mparams_dft = common_model_params_to_llama(params_dft);
@@ -1306,5 +1312,7 @@ private:
             cparams_mtp.type_v        = params_base.speculative.draft.cache_type_v;
             cparams_mtp.n_rs_seq      = 0;
-            cparams_mtp.n_outputs_max = params_base.n_parallel;
+            cparams_mtp.n_outputs_max = std::min<uint32_t>(
+                static_cast<uint32_t>(params_base.n_batch),
+                static_cast<uint32_t>(params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative))));

             ctx_dft.reset(llama_init_from_model(model_tgt, cparams_mtp));
@@ -3747,5 +3755,9 @@ private:
         // process the created batch of tokens
         for (int32_t i = 0; i < batch.n_tokens; i = i_next) {
-            const int32_t n_tokens = std::min(n_batch, batch.n_tokens - i);
+            const int32_t n_tokens = std::min({
+                n_batch,
+                batch.n_tokens - i,
+                (int32_t) params_base.n_outputs_max
+            });

             llama_batch batch_view = {
@@ -3759,4 +3771,7 @@ private:
             };

+            SRV_DBG("srv  update_slots: speculative chunked decode, chunk=%d n_tokens=%d cap=%d\n",
+                    i / std::max<int32_t>(1, n_batch), n_tokens, (int32_t) params_base.n_outputs_max);
+
             const int ret = llama_decode(ctx_tgt, batch_view);
```

`git diff --check -- tools/server/server-context.cpp` exit code: 0.
`git status --short` for the file: `M tools/server/server-context.cpp` (one modified file).
`git diff --stat`: 1 file changed, 18 insertions(+), 3 deletions(-).

## 7. Manager handoff

Submitting for independent Architect implementation review. Owner: Manager. Next gate: Implementation review (Architect) or Developer correction.
