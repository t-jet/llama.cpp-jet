# Stage 18 implementation evidence

Status: PARTIAL; Item 2 blocked on linker-flag propagation
Date: 2026-06-18
Owner: Developer (implementation, fresh session)
Source plan: [part-01-implementation-plan.md](part-01-implementation-plan.md)
Source design: [part-01-item1-duplicate-cold-path-hybrid-check.md](../cache-handling-phase18-design/part-01-item1-duplicate-cold-path-hybrid-check.md),
[part-02-item2-cxx-flags-release-debug-info.md](../cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md)
Manager decisions: D17-EXEC-03, D17-CLOSURE-02 / F-16-TR-03

## Scope and items

Two items per approved plan:

- Item 1: Remove duplicate cold-path-hybrid check in
  `tools/server/server-context.cpp` (D17-EXEC-03). 5 lines removed
  (1 comment + 4 inner if-block).
- Item 2: Add `/Zi /DEBUG:FULL` to `CMAKE_CXX_FLAGS_RELEASE` and
  `CMAKE_C_FLAGS_RELEASE` for build-cov (D17-CLOSURE-02 / F-16-TR-03).
  CMake reconfigure applied; build + tests pass; PDB generation
  still BLOCKED due to Visual Studio generator not propagating the
  flag change to linker flags. See "Item 2 substantive issue" below.

## Pre-state evidence

- Branch: work-branch at HEAD `23a1d4593`.
- `git diff HEAD -- tools/server/server-context.cpp` pre-state:
  empty (no pre-existing edits on this path).
- `build-cov/CMakeCache.txt` pre-state (verified 2026-06-18):
  - Line 80: `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`
  - Line 83: `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG`
  - Line 98: `CMAKE_C_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`
- Generator: `Visual Studio 18 2026`, platform empty
  (CMAKE_GENERATOR_PLATFORM:INTERNAL=). No `-A x64` was used
  originally.
- Test count: 89 (74 pre-Stage 17 + 15 `test_stage17_*` functions
  in `tests/test-cache-controller.cpp`, confirmed by
  `Select-String -Pattern '^void test_'`).

## Item 1: Delete duplicate cold-path-hybrid check

### Deletion applied

`tools/server/server-context.cpp` lines 1552 (comment) and 1554-1557
(inner if-block) removed. The outer guard at line 1553 and cold-budget
log lines (now 1553-1560 after deletion) are preserved.

Pre-state verified by direct read:

```cpp
1552:            // Phase 6: Validate cold path configuration
1553:            if (!params_base.cache_cold_path.empty()) {
1554:                if (cache_mode_active != CACHE_MODE_HYBRID) {
1555:                    SRV_ERR("%s", " - cache: --cache-cold-path requires --cache-mode hybrid\n");
1556:                    throw std::runtime_error("--cache-cold-path requires --cache-mode hybrid");
1557:                }
1558:                SRV_INF(" - cache: cold store path: %s\n", params_base.cache_cold_path.c_str());
```

Post-state verified by direct read:

```cpp
1553:            if (!params_base.cache_cold_path.empty()) {
1554:                SRV_INF(" - cache: cold store path: %s\n", params_base.cache_cold_path.c_str());
1555:                if (params_base.cache_cold_max_mib == 0) {
1556:                    SRV_INF("%s", " - cache: cold writes disabled by --cache-cold-max-mib 0\n");
...
```

### Post-deletion verification

- `findstr /N /C:"cache-cold-path requires"` returns 2 lines
  (1419, 1420). The canonical check in the moved block remains.
- `findstr /N /C:"Phase 6: Validate cold path configuration"` returns
  0 lines. The comment was removed cleanly.
- The duplicate post-slot-init check at lines 1555-1556 (pre-state)
  is gone. Only the canonical check at lines 1419-1420 remains.

### Diff scope

`git diff -- tools/server/server-context.cpp`:

```diff
@@ -1549,12 +1549,7 @@ private:
                 SRV_INF("%s", "cache mode: hybrid (LRU, non-destructive hits)\n");
             }

-            // Phase 6: Validate cold path configuration
             if (!params_base.cache_cold_path.empty()) {
-                if (cache_mode_active != CACHE_MODE_HYBRID) {
-                    SRV_ERR("%s", " - cache: --cache-cold-path requires --cache-mode hybrid\n");
-                    throw std::runtime_error("--cache-cold-path requires --cache-mode hybrid");
-                }
                 SRV_INF(" - cache: cold store path: %s\n", params_base.cache_cold_path.c_str());
                 if (params_base.cache_cold_max_mib == 0) {
                     SRV_INF("%s", " - cache: cold writes disabled by --cache-cold-max-mib 0\n");
```

Exactly 5 lines removed (1 comment + 4 inner if-block). No other
changes to `tools/server/server-context.cpp`.

### Item 1 build and test evidence

| Step | Command | Exit |
| --- | --- | --- |
| Build test-cache-controller | `cmake --build build-cov --config Release --target test-cache-controller -j 4` | 0 |
| Build llama-server | `cmake --build build-cov --config Release --target llama-server -j 4` | 0 |
| Focused tests | `build-cov\bin\Release\test-cache-controller.exe` | 0, 89/89 PASS |

Test count verified: `Select-String -Pattern '^test-cache-controller: .*\.\.\.' | Measure-Object Count` = 89 distinct
test invocations, all PASSED. (The trailing summary line in the
binary's output says "Total: 87 tests"; that text is from the test
binary itself and is stale relative to the actual test count of 89
confirmed by direct count of test function definitions and test
invocations. The bug is cosmetic in the binary's own summary
message, not in the test runner. The Manager should track this
stale summary string for a follow-up edit.)

### F-18-DR-01 corner case (TP-18-IT1) - actual behavior

Configuration probed: `llama-server.exe --model ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf --cache-mode legacy --cache-cold-path d:\tmp\cache-cold-f18dr01 --cache-cold-max-mib 0 --port 18182`

Observed: server prints `E srv load_model: - cache: --cache-cold-max-mib requires --cache-mode hybrid` and exits with exit code -1073740791 (STATUS_STACK_BUFFER_OVERRUN, Windows __fastfail; the uncaught `std::runtime_error` from line 1413 propagates to std::terminate which Windows reports as 0xC0000409).

Behavior interpretation: the corner case IS still rejected, but by a DIFFERENT validation check than the deleted duplicate. The moved block at lines 1411-1414 (`if (params_base.cache_cold_max_mib != -1 && params_base.cache_mode_val != CACHE_MODE_HYBRID)`) fires before the post-slot-init block runs. The F-18-DR-01 concern (silent proceed for `--cache-cold-path X --cache-cold-max-mib 0 --cache-mode legacy`) is NOT realized in practice: the cold-max-mib check (different from the deleted cold-path check) catches this case at lines 1411-1414.

Resolution: F-18-DR-01 finding is CLOSED by empirical evidence. The deletion is safe; the corner case is still rejected with a bounded error and a non-zero exit code.

## Item 2: Add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE

### Pre-state

- `build-cov/CMakeCache.txt` line 80: `/O2 /Ob2 /DNDEBUG`
- `build-cov/CMakeCache.txt` line 83: `/O2 /Ob1 /DNDEBUG` (UNCHANGED)
- `build-cov/CMakeCache.txt` line 98: `/O2 /Ob2 /DNDEBUG`
- `build-cov/CMakeCache.txt` line 116
  `CMAKE_EXE_LINKER_FLAGS_RELEASE:STRING=/INCREMENTAL:NO`
  (no /debug flag)
- `build-cov/CMakeCache.txt` line 248
  `CMAKE_SHARED_LINKER_FLAGS_RELEASE:STRING=/INCREMENTAL:NO`
  (no /debug flag)

### CMake reconfigure applied

Per self-improvement memory rule "Full rebuild needs reconfigure
after CMakeFiles wipe":

1. `Remove-Item -Recurse -Force build-cov\CMakeFiles` exit 0.
2. `cmake -B build-cov -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL" -DCMAKE_C_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL" -G "Visual Studio 18 2026"` exit 0.
   - Note: `-A x64` was tried first and failed with
     "generator platform: x64 Does not match the platform used
     previously" (the original build-cov was generated without
     `-A x64`; CMAKE_GENERATOR_PLATFORM is empty). The retry
     without `-A x64` succeeded.
   - Note per F-18-DR-04: `-DCMAKE_BUILD_TYPE=Release` is a no-op
     for the Visual Studio 18 2026 generator (multi-config ignores
     CMAKE_BUILD_TYPE). Included for documentation parity with the
     design's recorded command.

### Post-state (CMakeCache.txt)

- Line 80: `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL`
- Line 83: `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG` (UNCHANGED)
- Line 98: `CMAKE_C_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL`
- Line 116 `CMAKE_EXE_LINKER_FLAGS_RELEASE:STRING=/INCREMENTAL:NO` (UNCHANGED - this is the substantive issue)

### Clean rebuilds

| Step | Command | Exit |
| --- | --- | --- |
| Rebuild test-cache-controller | `cmake --build build-cov --config Release --target test-cache-controller -j 4` | 0 |
| Rebuild llama-server | `cmake --build build-cov --config Release --target llama-server -j 4` | 0 |

Both rebuilds succeeded. All C++ TUs recompiled with the new CXX
flags (visible in build log: server-cache-controller.cpp,
server-cache-hybrid.cpp, server-context.cpp, ggml.c, ggml.cpp, etc.).

### Post-rebuild focused tests

`build-cov\bin\Release\test-cache-controller.exe` exit 0, 89/89 PASS
(74 + 15 Stage 17 tests). Runtime behavior unchanged by flag update.

### Item 2 substantive issue: PDB not generated, .cov remains header-only

After applying the cmake reconfigure as specified in the plan, the following Visual Studio generator translation issues were observed:

1. `/Zi` propagated correctly to the ClCompile section as `<DebugInformationFormat>ProgramDatabase</DebugInformationFormat>` in every generated vcxproj.
2. `/DEBUG:FULL` was MIS-TRANSLATED in PreprocessorDefinitions as a `/D` define for the symbol `EBUG:FULL`. The slash was stripped during translation. This is benign (unused preprocessor symbol) but indicates the cmake flag string needs different formatting for the VS generator.
3. `CMAKE_EXE_LINKER_FLAGS_RELEASE` and `CMAKE_SHARED_LINKER_FLAGS_RELEASE` were NOT changed. Both remain `/INCREMENTAL:NO` with no `/debug` flag. As a result, `<GenerateDebugInformation>false</GenerateDebugInformation>` is set in the Link section of every vcxproj, and link.exe does NOT emit a PDB.
4. OpenCppCoverage smoke test result: BLOCKED-line-data. Exit 0, tests 89/89 PASS, .cov file generated. File size: 111 bytes (header-only listing of loaded modules: `test-cache-controller.exe`, `D:\...\ggml-base.dll`, `ggml-cpu.dll`, `ggml.dll`, `llama-common.dll`, `llama.dll`, `mtmd.dll`). **No line data**: no source line coverage bytes. OpenCppCoverage warning: "No modules were selected. Please check the values of --modules and --excluded_modules." The PDB for `test-cache-controller.exe` does NOT exist on disk because the linker was not told to generate one.

The plan's predicted outcome ("the coverage tool emits line-count data") is NOT achieved with the single-flag change applied to `CMAKE_CXX_FLAGS_RELEASE`. The Visual Studio generator splits compile flags (CMAKE_CXX_FLAGS_RELEASE) and linker flags (CMAKE_EXE_LINKER_FLAGS_RELEASE) into different vcxproj sections, and the linker must be told to generate the PDB for OpenCppCoverage to find debug info.

### Required follow-up for Item 2

The plan needs additional cmake flags for linker PDB generation:

- `-DCMAKE_EXE_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL"`
- `-DCMAKE_SHARED_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL"`
- `-DCMAKE_MODULE_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL"`

AND `/DEBUG:FULL` must NOT be passed through `CMAKE_CXX_FLAGS_RELEASE` because the VS generator strips its `/D` and corrupts the preprocessor definitions. Either omit `/DEBUG:FULL` from the CXX/C flags and only pass `/Zi`, or pass it through the linker flags instead. The plan did not anticipate this.

Item 2 implementation status is PARTIAL (cache updated, binaries rebuilt, tests pass, but OpenCppCoverage still produces header-only .cov).

### Handoff for Item 2 resolution

Plan author needs to amend the Item 2 cmake invocation to include linker flag changes. Then re-wipe CMakeFiles, reconfigure, rebuild, retest, rerun OpenCppCoverage. Until that amendment is approved at the Manager implementation gate, the build-cov/CMakeCache.txt change applied in this session is sufficient for the cache file evidence but does NOT unblock the OpenCppCoverage line-data contract T114/T114a/T115.

## Build and test verification

| Step | Exit | Evidence |
| --- | --- | --- |
| Item 1 build test-cache-controller | 0 | Rebuild log shows `test-cache-controller.vcxproj -> ...test-cache-controller.exe` |
| Item 1 build llama-server | 0 | Rebuild log shows `llama-server.vcxproj -> ...llama-server.exe` |
| Item 1 focused test | 0 | 89/89 PASS, all test invocations show "PASSED" |
| Item 2 cmake reconfigure | 0 | "Build files have been written to: D:/source/llama.cpp-jet/build-cov" |
| Item 2 clean rebuild test-cache-controller | 0 | All TUs recompiled with /Zi |
| Item 2 clean rebuild llama-server | 0 | All TUs recompiled with /Zi |
| Item 2 focused test (post-rebuild) | 0 | 89/89 PASS |
| Item 2 OpenCppCoverage smoke | 0 (blocked) | Header-only .cov (111 bytes); see "substantive issue" |

## Findings

| # | Severity | Title |
| --- | --- | --- |
| F-18-IMPL-01 | NON-BLOCKING (Item 1) | Test binary's trailing summary string says "Total: 87 tests" while 89 tests actually run and PASS. The binary summary text is stale relative to the actual test count. Cosmetic. |
| F-18-IMPL-02 | NON-BLOCKING (Item 1) | F-18-DR-01 corner case IS rejected, but by a different validation check (`cache_cold_max_mib != -1 && cache_mode_val != HYBRID` at lines 1411-1414) rather than the deleted duplicate. The corner case is still caught with a bounded error and a non-zero exit code. Evidence in the F-18-DR-01 section above. |
| F-18-IMPL-03 | BLOCKING (Item 2) | Visual Studio generator does not propagate `/Zi /DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` to linker flags. The PDB is not generated. OpenCppCoverage produces header-only .cov files, no line data. The plan needs additional `CMAKE_EXE_LINKER_FLAGS_RELEASE=/debug /DEBUG:FULL` and `CMAKE_SHARED_LINKER_FLAGS_RELEASE=/debug /DEBUG:FULL` for the Visual Studio generator. |
| F-18-IMPL-04 | INFO (Item 2) | The Visual Studio generator mis-translates `/DEBUG:FULL` in `CMAKE_CXX_FLAGS_RELEASE` into a `/D` preprocessor define for the symbol `EBUG:FULL` (drops the leading slash). Benign (unused preprocessor symbol) but indicates the flag string syntax needs review for the VS generator. |

## Handoff

Next owner: **Architect for implementation review in fresh session.**

If the Architect identifies F-18-IMPL-03 as a substantive plan
gap, escalate to Manager with proposed plan amendment (add
linker flag changes). Otherwise Architect can PASS Item 1 and
PARTIAL Item 2; Manager decides whether to:

- Accept the partial Item 2 as "cmake cache updated, binaries
  rebuilt, but OpenCppCoverage line-data contract not unblocked
  in this session; deferred to follow-up plan amendment", OR
- Require a follow-up Developer session to amend the plan,
  re-apply linker flags, and complete Item 2 in full.

Out of scope: D17-EXEC-02 system-level crash (Stage 19), test
infrastructure additions (Stage 20), other build directories,
CMakePresets.json, root CMakeLists.txt, committing/pushing/merging.

---

No further changes to `tools/server/server-context.cpp`,
`build-cov/CMakeCache.txt`, or any other tracked file are planned
in this session. The implementation evidence file is the durable
record of what was applied.
