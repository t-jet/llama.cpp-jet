# Cache handling test plan - Part 17: Stage 11 fix L translated test automation

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

- Date: 2026-06-06
- Owner: QA
- Source of action: Stage 11 follow-up test plan
  [part-16-stage11-fix-l-translated.md](./part-16-stage11-fix-l-translated.md)
  Sections 3 and 4, implementation log
  [../cache-handling-phase11-implementation/part-25-stage11-fix-l-translated-implementation.md](../cache-handling-phase11-implementation/part-25-stage11-fix-l-translated-implementation.md)
  (PASS), and implementation review
  [../cache-handling-phase11-implementation/part-26-stage11-fix-l-implementation-review.md](../cache-handling-phase11-implementation/part-26-stage11-fix-l-implementation-review.md)
  (PASS, 0/0/3 ADVISORY).

## 1. Scope and references

Scope: add focused C++ tests T-FIX-L-01 and T-FIX-L-02 to
`tests/test-cache-controller.cpp` that verify the translated
re-apply of fix L from `fix_mtp_server_instability` tip `a4303153`
in `ggml_backend_meta_buffer_reset` at
`ggml/src/ggml-backend-meta.cpp:1467-1494`. Tests are self-contained,
require no model fixture, and use counting shims over `ggml_reset`
and `ggml_backend_buffer_reset`.

References:

- Plan: `part-16-stage11-fix-l-translated.md` Sections 3 and 4.
- Implementation: `part-25-stage11-fix-l-translated-implementation.md`
  Section 4 (after body) and Section 5 (field-name notes).
- Translation mapping: `part-25` Section 3 (fix-mtp -> current struct).
- Function: `ggml_backend_meta_buffer_reset` at
  `ggml/src/ggml-backend-meta.cpp:1467-1494` (translated body, 19-line
  addition).
- Smart-pointer types: `ggml-cpp.h` (ggml_context_ptr,
  ggml_backend_buffer_ptr, ggml_init_params).
- Build: `build-cuda` (CUDA 13.2, MSVC 17.14, GGML_CUDA=ON,
  GGML_NATIVE=OFF, BUILD_SHARED_LIBS=OFF), config Release.

## 2. Test file path

- File: `tests/test-cache-controller.cpp`
- Build target: `test-cache-controller`
- Build log: `._design_docs/.test_reports/build-cuda-fix-l-test-20260606-01.log`
- Test binary: `build-cuda/bin/Release/test-cache-controller.exe`
- New tests added: 2 (T-FIX-L-01, T-FIX-L-02).
- Total tests in file: 87 (was 85, +2 for fix L).
- New include: `#include "ggml-cpp.h"` at the top of the file.
- New test function calls: appended to `main()` after
  `test_mtp_cap_matches_symmetric_formula_with_clamp()`.

## 3. T-FIX-L-01 record

- Test name:
  `test_ggml_backend_meta_buffer_reset_clears_all_caches_and_resets_all_children`.
- Source location: `tests/test-cache-controller.cpp`, function
  `test_ggml_backend_meta_buffer_reset_clears_all_caches_and_resets_all_children`.
- Pass criteria copied from plan Section 3:
  - (a) `buf_ctx->split_state_cache.empty()` true after the call.
  - (b) all three `simple_tensors` maps empty.
  - (c) `ggml_reset` call count equals non-null ctxs across the three
    stc containers.
  - (d) `ggml_backend_buffer_reset` call count equals
    `buf_ctx->bufs.size()`.
- Implementation: test fixture built by
  `fix_l_make_fixture(5, 4, 6, 3)` (5 split_state_cache entries, 4
  entries per simple_tensors map, 6 contexts distributed 2/2/2 across
  the three stc containers, 3 bufs). Counting shims
  `fix_l_ggml_reset_shim` and `fix_l_buf_reset_shim` increment
  globals `g_fix_l_ggml_reset_count` and `g_fix_l_buf_reset_count`.
  Test-local reset `fix_l_reset` mirrors the translated production
  body 1:1 and routes calls through the shims. After the call,
  asserts (a)-(d) and the exact shim counts.
- Evidence: test source line, `## Build evidence` below, build log
  `._design_docs/.test_reports/build-cuda-fix-l-test-20260606-01.log`
  (exit 0, `test-cache-controller.cpp` compiles clean).

## 4. T-FIX-L-02 record

- Test name:
  `test_ggml_backend_meta_buffer_reset_idempotent_and_equivalent_to_fix_mtp`.
- Source location: `tests/test-cache-controller.cpp`, function
  `test_ggml_backend_meta_buffer_reset_idempotent_and_equivalent_to_fix_mtp`.
- Pass criteria copied from plan Section 4:
  - Post-reset state matches fix_mtp reference: every cache map is
    empty, every context was reset, every buffer was reset.
  - A second back-to-back call leaves the same reference state,
    does not throw, and does not double-count beyond the second pass.
- Implementation: test fixture built by
  `fix_l_make_fixture(7, 3, 9, 4)` (7 split_state_cache entries, 3
  per simple_tensors map, 9 contexts distributed 3/3/3, 4 bufs).
  Reset called once, asserts all cache sizes are 0 and shim counts
  match the expected 9/4. Captures the post-first-call counts, calls
  `fix_l_reset` a second time, asserts the deltas equal the second
  pass (9 ggml_reset, 4 buf_reset) and the cache maps are still
  empty. No exceptions are expected; the test relies on the no-throw
  guarantee of `clear()` and the real `ggml_reset` on a valid
  `ggml_context`.
- Evidence: test source line, `## Build evidence` below, build log
  `._design_docs/.test_reports/build-cuda-fix-l-test-20260606-01.log`
  (exit 0).

## 5. Build evidence

Build command:

```powershell
cmake --build build-cuda --config Release -j --target test-cache-controller
```

Build log:
`._design_docs/.test_reports/build-cuda-fix-l-test-20260606-01.log`.

Exit code: **0** (build succeeded).

Build timestamps: started 2026-06-06 16:38:33, finished 2026-06-06
16:38:59 (26 s wall clock, incremental rebuild after
`common/CMakeFiles/generate.stamp` refresh).

Binary timestamp: `test-cache-controller.exe` LastWriteTime
2026-06-06 16:38:58, size 154973184 bytes. Fresh, well under the
10-minute staleness threshold from the plan Section 2.

Last 50 lines of build log:

```text
=== Build started 06/06/2026 16:38:33 ===
CMake is re-running because D:/source/llama.cpp-jet/build-cuda/common/CMakeFiles/generate.stamp is out-of-date.
  the file 'D:/source/llama.cpp-jet/.git/index'
  is newer than 'D:/source/llama.cpp-jet/build-cuda/common/CMakeFiles/generate.stamp.depend'
  result='-1'
-- Selecting Windows SDK version 10.0.26100.0 to target Windows 10.0.26200.
CMAKE_BUILD_TYPE=Release
-- Warning: ccache not found - consider installing it for faster compilation or disable this warning with GGML_CCACHE=OFF
-- CMAKE_SYSTEM_PROCESSOR: AMD64
-- CMAKE_GENERATOR_PLATFORM: x64
-- GGML_SYSTEM_ARCH: x86
-- Including CPU backend
-- x86 detected
-- Adding CPU backend variant ggml-cpu: /arch:AVX2 GGML_AVX2;GGML_FMA;GGML_F16C;__BMI2__;GGML_BMI2
-- CUDA Toolkit found
-- Replacing 120-real in CMAKE_CUDA_ARCHITECTURES_NATIVE with 120a-real
-- Using CMAKE_CUDA_ARCHITECTURES=75-virtual;80-real;86-real;89-real;90-virtual;120a-real;121a-real CMAKE_CUDA_ARCHITECTURES_NATIVE=120a-real
-- Could NOT find NCCL (missing: NCCL_LIBRARY NCCL_INCLUDE_DIR)
-- Warning: NCCL not found, performance for multiple CUDA GPUs will be suboptimal
-- Including CUDA backend
-- ggml version: 0.13.1
-- ggml commit:  02db7a768-dirty
-- Could NOT find OpenSSL, try to set the path to OpenSSL root folder in the system variable OPENSSL_ROOT_DIR (missing: OPENSSL_CRYPTO_LIBRARY OPENSSL_INCLUDE_DIR)
CMake Warning at vendor/cpp-httplib/CMakeLists.txt:152 (message):
  OpenSSL not found, HTTPS support disabled


-- Generating embedded license file for target: llama-app
-- Configuring done (1.6s)
-- Generating done (7.7s)
-- Build files have been written to: D:/source/llama.cpp-jet/build-cuda
MSBuild version 17.14.40+3e7442088 for .NET Framework

  cpp-httplib.vcxproj -> D:\source\llama.cpp-jet\build-cuda\vendor\cpp-httplib\Release\cpp-httplib.lib
  llama-common-base.vcxproj -> D:\source\llama.cpp-jet\build-cuda\common\Release\llama-common-base.lib
  ggml-base.vcxproj -> D:\source\llama.cpp-jet\build-cuda\ggml\src\Release\ggml-base.lib
  ggml-cpu.vcxproj -> D:\source\llama.cpp-jet\ggml\src\Release\ggml-cpu.lib
  ggml-cuda.vcxproj -> D:\source\llama.cpp-jet\ggml\src\ggml-cuda\Release\ggml-cuda.lib
  ggml.vcxproj -> D:\source\llama.cpp-jet\ggml\src\Release\ggml.lib
  llama.vcxproj -> D:\source\llama.cpp-jet\src\Release\llama.lib
  llama-common.vcxproj -> D:\source\llama.cpp-jet\common\Release\llama-common.lib
  mtmd.vcxproj -> D:\source\llama.cpp-jet\tools\mtmd\Release\mtmd.lib
  server-context.vcxproj -> D:\source\llama.cpp-jet\tools\server\Release\server-context.lib
  test-cache-controller.cpp
LINK : warning LNK4098: defaultlib 'LIBCMT' conflicts with use of other libs; use /NODEFAULTLIB:library [D:\source\llama.cpp-jet\build-cuda\tests\test-cache-controller.vcxproj]
  test-cache-controller.vcxproj -> D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
=== cmake build exit: 0 06/06/2026 16:38:59 ===
```

The pre-existing `LNK4098` warning is allowed by the plan (Section 2)
and by the test build conventions for this project.

## 6. Framework note

The plan refers to "gtest" for the new tests, but
`tests/test-cache-controller.cpp` is a single self-contained
executable with its own `main()` and uses the project's existing
`assert` + `printf("  PASSED\n")` style. No gtest dependency is
added. The new tests follow the same style: `printf` banner at entry,
`assert` on every behavioral claim, `printf("  PASSED\n")` at the
end, and a one-line call from `main()`. This matches the part-15
T-NOUT-MAX-01 / T-NOUT-MAX-02 tests added on 2026-06-06.

The new include `#include "ggml-cpp.h"` is required for the
`ggml_context_ptr` and `ggml_backend_buffer_ptr` smart-pointer
typedefs used by the fixture struct. The header is in
`ggml/include/` and is on the include path of every executable that
links `llama` (which the test already does).

`ggml_backend_meta_buffer_reset` is `static` in
`ggml/src/ggml-backend-meta.cpp` and cannot be linked from the test
binary. The test mirrors the translated production body in a
test-local function `fix_l_reset`, identical in control flow, and
routes the `ggml_reset` / `ggml_backend_buffer_reset` calls through
counting shims. The mirror approach is the same pattern used by the
part-15 n_outputs_max cap tests (which mirror the chunked-decode
loop in `server-context.cpp:3750-3774`).

## 7. Manager handoff line

Ready for QA test execution. Build evidence captured, both new tests
compile clean against `ggml-cpp.h`, the fresh binary
`build-cuda\bin\Release\test-cache-controller.exe` is 154973184 bytes
with LastWriteTime 2026-06-06 16:38:58 (well under the 10-minute
staleness threshold from the plan Section 2). Open the next
per-session test report under
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`, run
`test-cache-controller.exe`, and log T-FIX-L-01 / T-FIX-L-02 PASS
with the count summary (87 tests including the 2 new fix L rows).
