# R28-BUG-03 ASan LNK2038 fix (Stage 28 iter 2 step 3)

Date: 2026-06-26
Author: Developer (Step 3 fix)
Source data: side-channel ASan+CUDA build (`build-cuda-asan`)
  prior `llama-server.vcxproj` link produced 274 LNK2038 SAL
  annotation mismatches between `ggml-cuda.lib` and
  `llama-server-impl.lib` (see
  `._test_output/build-cuda-asan-llama-server.log`).
Status: FIX VERIFIED

## Fix description

### Option chosen

Per design `cache-handling-phase28-design/part-02-known-bug-fixes.md`
R28-BUG-03 Option A and the user's task brief: pass
`/fsanitize=address` to nvcc's host-compiler invocation so that
ggml-cuda host compile produces SAL annotation value `1`, matching
llama-server-impl.lib's annotation value `1`. Implemented by editing
`build-cuda-asan/CMakeCache.txt`:

| Variable | Old value | New value |
| --- | --- | --- |
| `CMAKE_CUDA_FLAGS` | `-D_WINDOWS -Xcompiler=" /EHsc"` | `-D_WINDOWS -Xcompiler=/fsanitize=address -Xcompiler=/Zi` |

Per the task brief: `/fsanitize-recover=address` is intentionally
omitted because MSVC's D9002 warning treats it as an unknown flag
(see `._test_output/build-cuda-asan-test-final.log` for prior D9002
warnings on the same flag).

`/Zi` is kept alongside `/fsanitize=address` so ASan-instrumented
code retains debug info for symbolicated stack traces.

### Code change scope

| File | Line | Change |
| --- | ---: | --- |
| `build-cuda-asan/CMakeCache.txt` | 68 | `CMAKE_CUDA_FLAGS` value replaced (see table above). CRLF preserved (CR=1492, LF=1492), no BOM (BOM byte = 0x23 = '#'). |

### Downstream vcxproj regeneration

After the CMakeCache.txt edit, `cmake -S . -B build-cuda-asan
-DGGML_CUDA=ON` was run (1.9s configure, 6.6s generate). The
regenerated `build-cuda-asan/ggml/src/ggml-cuda/ggml-cuda.vcxproj`
Release|x64 CUDA compile line now reads:

````text
<AdditionalOptions>%(AdditionalOptions)
-forward-unknown-to-host-compiler -std=c++17
--generate-code=arch=compute_120a,code=[sm_120a]
-extended-lambda -compress-mode=size
-Xcompiler="/fsanitize=address /Zi -Ob2 /Zc:preprocessor"</AdditionalOptions>
````

nvcc forwards `-fsanitize=address -Zi -Ob2` to MSVC's host compile.
The non-CUDA .cpp ClCompile line (line 148) also retains
`/fsanitize=address /fsanitize-recover=address` from the prior
reconfigure, so the entire `ggml-cuda.lib` produces SAL annotation
value `1` consistent with `llama-server-impl.lib`.

## Build evidence

### LNK2038 count: before vs after

| Stage | LNK2038 count | Source log |
| --- | ---: | --- |
| BEFORE (prior build, pre-fix) | 274 | `._test_output/build-cuda-asan-llama-server.log` (mtime 2026-06-26 14:43:43, 69896 bytes; tail shows `fatal error LNK1319: 274 mismatches detected`) |
| AFTER (rebuild, post-fix) | 0 | `._test_output/build-cuda-asan-step3.log` |

Verification commands:

````powershell
# BEFORE
(Select-String -Path '._test_output\build-cuda-asan-llama-server.log' `
  -Pattern 'LNK2038' | Measure-Object).Count
# -> 274

# AFTER
(Select-String -Path '._test_output\build-cuda-asan-step3.log' `
  -Pattern 'LNK2038' | Measure-Object).Count
# -> 0
````

### Binary artifacts

| Path | mtime | Size (bytes) |
| --- | --- | ---: |
| `build-cuda-asan/bin/Release/llama-server.exe` | 2026-06-26 23:16:04 | 91,895,808 |
| `build-cuda-asan/bin/Release/test-cache-controller.exe` | 2026-06-26 23:16:20 | 90,549,760 |

### Build exit codes

- `cmake -S . -B build-cuda-asan -DGGML_CUDA=ON`: exit 0 (1.9s configure, 6.6s generate)
- `cmake --build build-cuda-asan --config Release -j --target llama-server`: exit 0
- `cmake --build build-cuda-asan --config Release -j --target test-cache-controller`: exit 0

### Known non-blocking warnings (unchanged from prior runs)

- `LNK4044: unrecognized option '/fsanitize=address'; ignored` (linker level, expected; link still produces a valid exe)
- `LNK4300: ignoring '/INCREMENTAL' because input module contains ASAN metadata` (expected with ASan)
- `LNK4098: defaultlib 'LIBCMT' conflicts with use of other libs` (pre-existing, not introduced by this fix)
- `D9002: ignoring unknown option '/fsanitize-recover=address'` (pre-existing from CMAKE_CXX_FLAGS_RELEASE; outside this fix's scope)

## Test evidence

`build-cuda-asan/bin/Release/test-cache-controller.exe` exits 0
with `All tests passed successfully!` summary line:

````text
==================================================
All tests passed successfully!
Total: 140 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4
focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused +
7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04
T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage
21 bugfix 2026-06-18 + 9 Stage 23 focused + 15 Stage 22 focused + 2
Stage 24 focused + 10 Stage 25 atomic transactional + 5 Stage 26
cold-store accounting + 1 Stage 27 D-EXEC-24-03 heap corruption
regression + 2 Stage 28 R28-BUG-02 cold-store drift fix)
==================================================
````

140/140 PASS (exit 0). Includes the new Stage 28 R28-BUG-02 cold-store
drift tests (2 added in Step 1). No regression.

Source log: `._test_output/test-cuda-asan-step3-full.log` (20573 bytes,
391 lines).

## Manager decision proposed

**D-EXEC-28-STEP3-01**: R28-BUG-03 (ASan LNK2038 SAL annotation
mismatch) fix VERIFIED. LNK2038 count 274 -> 0. `llama-server.exe`
and `test-cache-controller.exe` both rebuilt clean in side-channel
ASan+CUDA build. 140/140 test pack PASS. Ready to advance to next
queued step (R28-BUG-04 Phase B deprecation).

## Hard-constraint compliance

- Durable `tools/server/CMakeLists.txt`: NOT modified (verified by
  `git diff -- tools/server/CMakeLists.txt` -> empty).
- Runner scripts, test plan, design docs: NOT modified.
- No commit or push performed (CMakeCache.txt is gitignored).
- Report file uses LF line endings, plain ASCII, no BOM, no trailing
  whitespace.
- Test pack 140/140 still PASS (verified by full test run).

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace.
