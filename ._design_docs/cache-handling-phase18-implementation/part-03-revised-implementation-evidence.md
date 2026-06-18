# Stage 18 implementation evidence - iteration 2 (D18-IMPL-01)

Status: Item 1 PASS (unchanged from iter1); Item 2 PASS (line-data
contract unblocked); implementation iteration 2 complete
Date: 2026-06-18
Owner: Developer (implementation iteration 2, fresh session)
Supersedes: [part-03-implementation-evidence.md](part-03-implementation-evidence.md) for
Item 2 (that file remains as the iter1 record)
Source plan-amendment: D18-IMPL-01
(see [cache-handling-phase18-implementation.md](../cache-handling-phase18-implementation.md))
Source design: [part-02-item2-cxx-flags-release-debug-info.md](../cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md)
Architect review iter1: [part-04-architect-implementation-review-gate-01.md](part-04-architect-implementation-review-gate-01.md)
(REWORK, F-18-IMPL-04 / F-18-IR-01)

## Scope

Implementation iteration 2 applies Manager plan-amendment D18-IMPL-01
to fix the linker-flag propagation issue identified in iter1 review:

1. Remove `/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` and
   `CMAKE_C_FLAGS_RELEASE`. Keep only `/Zi` (Program Database is the
   correct compile format).
2. Add `/debug /DEBUG:FULL` to `CMAKE_EXE_LINKER_FLAGS_RELEASE` for
   executable PDB generation.
3. Add `/debug /DEBUG:FULL` to `CMAKE_MODULE_LINKER_FLAGS_RELEASE` for
   static library PDB generation.
4. Add `/debug /DEBUG:FULL` to `CMAKE_SHARED_LINKER_FLAGS_RELEASE` for
   shared library PDB generation (`llama-server-impl.dll`,
   `llama.dll`, etc.).

Item 1 (delete duplicate cold-path-hybrid check) remains PASS per
iter1 evidence. No change required for Item 1.

## Pre-state evidence (iter1 end state)

- Branch: work-branch at HEAD `23a1d4593` (unchanged).
- `build-cov/CMakeCache.txt` lines 80/98 contained
  `/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL`; lines 116/192/248
  `*_LINKER_FLAGS_RELEASE` remained `/INCREMENTAL:NO` (no /debug).
- `build-cov/tests/test-cache-controller.vcxproj` line 167 contained
  `EBUG:FULL` in `PreprocessorDefinitions` (mis-translation);
  line 188 `<GenerateDebugInformation>false</GenerateDebugInformation>`
  (linker not told to generate PDB).
- No .pdb on disk in `build-cov/bin/Release/`.
- `tools/server/server-context.cpp` Item 1 deletion already applied
  (5 lines removed at 1552, 1554-1557; verified iter1).

## Item 2 amended: linker flag propagation

### CMakeFiles wipe

`Remove-Item -Recurse -Force build-cov/CMakeFiles` exit 0.
Post-wipe count: 0 directories remaining. Required per developer
self-improvement memory ("Full rebuild needs reconfigure after
CMakeFiles wipe").

### CMake reconfigure (D18-IMPL-01 flag set)

Command executed (PowerShell):

```powershell
cmake -B build-cov `
  -DCMAKE_BUILD_TYPE=Release `
  -DCMAKE_CXX_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi" `
  -DCMAKE_C_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi" `
  -DCMAKE_EXE_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL" `
  -DCMAKE_MODULE_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL" `
  -DCMAKE_SHARED_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL" `
  -G "Visual Studio 18 2026"
```

Exit code: 0. First attempt with `-A x64` failed with
"generator platform: x64 Does not match the platform used
previously" (build-cov was originally generated without
`-A x64`; CMAKE_GENERATOR_PLATFORM is empty). Retry without
`-A x64` succeeded, matching the iter1 invocation pattern.

Per F-18-DR-04: `-DCMAKE_BUILD_TYPE=Release` is a no-op for the
Visual Studio 18 2026 multi-config generator. Included for
documentation parity with the design's recorded command.

### CMakeCache.txt post-reconfigure

| Line | Variable | Value | Status |
| --- | --- | --- | --- |
| 80 | CMAKE_CXX_FLAGS_RELEASE | `/O2 /Ob2 /DNDEBUG /Zi` | FIXED (no /DEBUG:FULL) |
| 83 | CMAKE_CXX_FLAGS_RELWITHDEBINFO | `/O2 /Ob1 /DNDEBUG` | UNCHANGED |
| 98 | CMAKE_C_FLAGS_RELEASE | `/O2 /Ob2 /DNDEBUG /Zi` | FIXED (no /DEBUG:FULL) |
| 101 | CMAKE_C_FLAGS_RELWITHDEBINFO | `/O2 /Ob1 /DNDEBUG` | UNCHANGED |
| 116 | CMAKE_EXE_LINKER_FLAGS_RELEASE | `/INCREMENTAL:NO /debug /DEBUG:FULL` | FIXED (NEW /debug) |
| 192 | CMAKE_MODULE_LINKER_FLAGS_RELEASE | `/INCREMENTAL:NO /debug /DEBUG:FULL` | FIXED (NEW /debug) |
| 248 | CMAKE_SHARED_LINKER_FLAGS_RELEASE | `/INCREMENTAL:NO /debug /DEBUG:FULL` | FIXED (NEW /debug) |

All six expected lines verified. CMAKE_*_FLAGS_RELWITHDEBINFO at
lines 83 and 101 UNCHANGED (RelWithDebInfo not affected by this
stage).

### vcxproj translation verification

`build-cov/tests/test-cache-controller.vcxproj` Release config
(verified by `Select-String`):

- Line 97 (Debug): `<DebugInformationFormat>ProgramDatabase</DebugInformationFormat>` (UNCHANGED).
- Line 153 (Release ClCompile): `<DebugInformationFormat>ProgramDatabase</DebugInformationFormat>` (UNCHANGED, /Zi propagated).
- Line 167 (Release PreprocessorDefinitions): now
  `...NDEBUG;LLAMA_SERVER_CACHE_TESTS;...` (no `EBUG:FULL`,
  FIXED). Previously contained `...NDEBUG;EBUG:FULL;...` from
  the iter1 mis-translation.
- Line 188 (Release Link): `<GenerateDebugInformation>DebugFull</GenerateDebugInformation>`
  (FIXED; was `false` in iter1). `DebugFull` is the MSVC
  recognized value for `/DEBUG:FULL` per the VS generator
  `GenerateDebugInformation` enum.
- Line 245 (MinSizeRel Link): `<GenerateDebugInformation>false</GenerateDebugInformation>` (UNCHANGED, MinSizeRel not affected).

`build-cov/tools/server/llama-server.vcxproj` Release config
(verified): same pattern, line 188 now
`<GenerateDebugInformation>DebugFull</GenerateDebugInformation>`.
PreprocessorDefinitions clean (no EBUG:FULL).

### Build and test verification

| Step | Command | Exit |
| --- | --- | --- |
| Wipe CMakeFiles | `Remove-Item -Recurse -Force build-cov/CMakeFiles` | 0 |
| Reconfigure | `cmake -B build-cov -DCMAKE_BUILD_TYPE=Release ...` (D18-IMPL-01) | 0 |
| Rebuild test-cache-controller | `cmake --build build-cov --config Release --target test-cache-controller -j 4` | 0 |
| Rebuild llama-server | `cmake --build build-cov --config Release --target llama-server -j 4` | 0 |
| Focused tests | `build-cov\bin\Release\test-cache-controller.exe` | 0, 89/89 PASS |

Build logs (summary): 32 warnings (all pre-existing, no new
warnings introduced by the flag change); 0 errors. Both rebuilds
emitted all expected .vcxproj targets and produced
`test-cache-controller.exe` (2800128 bytes) and
`llama-server.exe` (13312-byte launcher loading
`llama-server-impl.dll` at 14629888 bytes).

### Test count detail (89/89 PASS)

Test runner output: "All tests passed successfully!". Actual
`PASSED` result-line count: 89 (matches source definition
count). Binary's own summary text "Total: 87 tests" is the
stale cosmetic F-18-IMPL-01 / F-18-IR-03 finding, non-blocking
and accepted as-is for this gate.

### PDB files on disk

`Get-ChildItem build-cov/bin/Release/*.pdb`:

| Name | Length (bytes) |
| --- | --- |
| ggml-base.pdb | 6598656 |
| ggml-cpu.pdb | 6418432 |
| ggml.pdb | 4435968 |
| llama-common.pdb | 76050432 |
| llama-server-impl.pdb | 55111680 |
| llama-server.pdb | 495616 |
| llama.pdb | 38211584 |
| mtmd.pdb | 13242368 |
| test-cache-controller.pdb | 36597760 |

9 PDB files present. iter1 had 0 PDB files (the linker was not
told to generate them). Each binary (test-cache-controller.exe,
llama-server.exe launcher, llama-server-impl.dll, llama.dll,
llama-common.dll, ggml-base.dll, ggml-cpu.dll, ggml.dll,
mtmd.dll) has a co-located .pdb.

### OpenCppCoverage smoke test (KEY VERIFICATION)

Command executed (PowerShell):

```powershell
& 'D:\app\OpenCppCoverage\OpenCppCoverage.exe' `
  --sources 'D:\source\llama.cpp-jet\common\*' `
  --sources 'D:\source\llama.cpp-jet\tools\server\*' `
  --sources 'D:\source\llama.cpp-jet\ggml\src\*' `
  --modules 'D:\source\llama.cpp-jet\build-cov\bin\Release\*' `
  --cover_children `
  --working_dir 'D:\source\llama.cpp-jet' `
  --export_type 'binary:coverage-stage18-iter2.cov' `
  -- 'D:\source\llama.cpp-jet\build-cov\bin\Release\test-cache-controller.exe'
```

Exit code: 0. Selected modules: test-cache-controller.exe,
mtmd.dll, llama-common.dll, llama.dll, ggml.dll, ggml-base.dll,
ggml-cpu.dll (all 7 listed modules, all selected because they
match the `bin/Release/*` pattern; no "No modules were selected"
warning, unlike iter1).

Coverage output:

| File | Size (bytes) | iter1 size (bytes) | Multiple |
| --- | --- | --- | --- |
| coverage-stage18-iter2.cov (binary) | 327137 | 111 | 2947x |
| coverage-stage18-iter2.xml (cobertura) | 40697 | not produced | n/a |

The .cov file size increased 2947x relative to iter1's
header-only output. Converting to cobertura XML produces a
40 KB report containing 109 class entries (one per source
file) with per-line coverage entries such as
`<line number="739" hits="0"/>`. Report summary attributes:
`line-rate="0.0317"`, `lines-covered="1469"`,
`lines-valid="46338"`.

The 3.17% line-rate is expected for the test-cache-controller
smoke run: the test binary exercises a focused subset of the
codebase, so most ggml and server .cpp lines are not hit. The
contract T114/T114a/T115 is about whether line-data is
COLLECTED (which it now is), not about specific rate
thresholds (T114/T114a are measured in a separate
cache-targeted coverage run in Stage 17's
test-report-20260617-01 coverage work, not the smoke test).

### Files changed (this iteration)

- `build-cov/CMakeCache.txt`: 6 lines (80, 98, 116, 192, 248
  modified; 83, 101 unchanged). build-cov is gitignored per
  .gitignore:46, so the cmake invocation in this evidence
  file is the durable record.
- `build-cov/tests/test-cache-controller.vcxproj`: regenerated
  by cmake. Line 167 PreprocessorDefinitions clean; line 188
  GenerateDebugInformation now `DebugFull`.
- `build-cov/tools/server/llama-server.vcxproj`: regenerated
  by cmake. Line 188 GenerateDebugInformation now `DebugFull`.
- 9 .pdb files created in `build-cov/bin/Release/`.
- 2 coverage artifacts created at worktree root:
  `coverage-stage18-iter2.cov` (327137 bytes), `coverage-stage18-iter2.xml` (40697 bytes).
- Item 1 durable change: `tools/server/server-context.cpp`
  still -5 lines (unchanged from iter1).
- No changes to `tests/test-cache-controller.cpp`,
  `CMakeLists.txt`, `CMakePresets.json`, or any other tracked
  file.

### git status (post-iter2)

```text
M tools/server/server-context.cpp   (Item 1, -5 lines, unchanged)
?? coverage-stage18-iter2.cov       (new artifact, untracked)
?? coverage-stage18-iter2.xml       (new artifact, untracked)
```

`git diff --stat HEAD -- tools/server/server-context.cpp`:
"1 file changed, 5 deletions(-)". build-cov/ remains
gitignored. No new tracked file changes.

## Findings

| ID | Severity | Title | Evidence | Action |
| --- | --- | --- | --- | --- |
| F-18-IMPL-01 (carried) | NON-BLOCKING | Test binary's trailing summary string says "Total: 87 tests" while 89 tests actually run and PASS | 89 PASSED result lines vs 87 in stale binary summary | None for this gate. Cosmetic. Defer to follow-up. |
| F-18-IMPL-02 (carried) | NON-BLOCKING | F-18-DR-01 corner case IS rejected, by different check at server-context.cpp:1411-1414 | iter1 evidence has empirical proof | None. Closed by evidence. |
| F-18-IMPL-03 (CLOSED by iter2) | BLOCKING (iter1) | Visual Studio generator does not propagate /Zi /DEBUG:FULL to linker flags | iter1 evidence: PDB not generated, .cov 111 bytes | RESOLVED by D18-IMPL-01. CMakeCache.txt 116/192/248 set; vcxproj line 188 = `DebugFull`; 9 PDBs on disk; .cov 327137 bytes with line data. |
| F-18-IMPL-04 (CLOSED by iter2) | INFO (iter1) | /DEBUG:FULL mis-translated to /D EBUG:FULL preprocessor define | iter1 evidence: vcxproj line 167 | RESOLVED by D18-IMPL-01. /DEBUG:FULL removed from CXX/C flags; vcxproj line 167 no longer contains `EBUG:FULL`. |
| F-18-IMPL-05 | INFO | Coverage test invocation used --modules=build-cov/bin/Release/* (corrected from iter1's incorrect common;tools/server;ggml/src). iter1's command in the task brief was a path-pattern mismatch but produced a non-blocked result; iter2 corrected the module filter. | iter1 .cov (111 bytes, modules listed but no line data); iter2 .cov (327137 bytes, all 7 modules selected, line data). | None. Documentation note for future OpenCppCoverage invocations. |
| F-18-IMPL-06 | INFO | OpenCppCoverage v0.9.9.0 does not support `--build` or `--modules_by_dir` flags. The corrected invocation uses `--modules=build-path\*` and absolute Windows path separators. | This file's OpenCppCoverage section. | None. Use the corrected invocation form for all future OpenCppCoverage runs on this build. |

## Handoff

Next owner: **Architect for implementation review iteration 2 in a
fresh session.**

The Architect verifies:

- Item 1 still PASS (unchanged from iter1; 5 lines removed in
  server-context.cpp, 89/89 tests pass, F-18-DR-01 corner case
  empirically closed).
- Item 2 PASS: cmake flags applied per D18-IMPL-01; linker
  flags propagated to vcxproj (`GenerateDebugInformation=DebugFull`);
  9 PDB files on disk; OpenCppCoverage .cov grew 2947x to
  327137 bytes with line data; cobertura XML conversion
  confirms per-line entries.
- T114/T114a/T115 line-data contract UNBLOCKED: OpenCppCoverage
  can now find PDBs and emit per-line coverage records.

Out of scope: changes to durable planning docs (tracker, document-index, design, test plan), commits/pushes, other build directories, CMakePresets.json, root CMakeLists.txt.

This file uses LF line endings, plain ASCII status labels, and
stays under the 300-line durable doc cap (target < 250 lines).
