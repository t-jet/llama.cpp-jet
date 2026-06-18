# Part 2: Item 2 design - add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Source: [entry doc](../cache-handling-phase18-design.md), Manager decision D17-CLOSURE-02 / F-16-TR-03

## Item 2: Add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE (F-16-TR-03)

### Coverage build context

The `build-cov` build configuration currently uses
`CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (verified at
`build-cov/CMakeCache.txt` line 80). This Release configuration produces
optimized binaries without debug info. OpenCppCoverage requires both
program-database generation (`/Zi`) and full debug info (`/DEBUG:FULL`) to
emit coverage data with line counts. Without these flags, the coverage tool
produces header-only `.cov` files with no line data, which blocks the
closure contracts T114 (>= 0.80 hybrid path coverage), T114a (>= 0.70
relaxed threshold), and T115 (per-file dedup) inherited from Stage 10.

Source: Stage 17 closure Manager decision D17-CLOSURE-02 / F-16-TR-03;
[test-report-20260617-01](../../.test_reports/test-report-20260617-01.md)
"Coverage" section.

### Options evaluated

Option 1: Add `/Zi /DEBUG:FULL` to `CMAKE_CXX_FLAGS_RELEASE` for build-cov
via the cmake configure command.

- Effect on Release build performance: `/Zi` and `/DEBUG:FULL` are compatible
  with `/O2`. The compiler still emits optimized code; only the PDB size
  grows. Runtime performance is unaffected.
- Effect on binary size: PDB grows (large, ~hundreds of MB for the full
  llama-server build). The binary itself grows modestly because of debug
  info embedded for `/DEBUG:FULL`.
- Effect on focused tests and integration tests: tests still pass; debug
  info does not change runtime behavior. Coverage script still uses the
  same `build-cov/bin/Release/` paths.
- Effect on OpenCppCoverage output: produces coverage data with line counts
  (not header-only), which is what the coverage tool needs.
- Effect on CI/build configuration: requires one cmake reconfigure of
  build-cov with the new flags, then a full rebuild. Other build
  directories (`build`, `build-cuda`, etc.) are unaffected.
- Risk to other build directories: zero. The change is scoped to the
  build-cov cmake invocation. Other build directories use their own
  CMakeCache.txt files with their own flag values.

Option 2: Create a separate RelWithDebInfo build target.

- Effect on Release build performance: RelWithDebInfo uses `/O2 /Ob1
  /DNDEBUG` (per `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG`
  at line 86 of build-cov/CMakeCache.txt). `/Ob1` is less aggressive than
  `/Ob2`, so optimized code may be slightly less inlined.
- Effect on binary size: similar to Option 1. PDB and binary grow.
- Effect on focused tests and integration tests: tests still pass; debug
  info does not change runtime behavior.
- Effect on OpenCppCoverage output: produces coverage data with line counts.
  RelWithDebInfo on MSVC includes `/Zi` and `/DEBUG:FULL` by default.
- Effect on CI/build configuration: requires a new build directory
  (e.g., `build-cov-rwdi`). All coverage scripts must update their
  `$BuildDir` parameter. Significant script maintenance.
- Risk to other build directories: zero. New directory is independent.

Option 3: Modify root CMakeLists.txt to set `/Zi /DEBUG:FULL` globally for
Release builds.

- Effect on Release build performance: applies to ALL Release builds
  including `build`, `build-cuda`, and any user Release build.
- Effect on binary size: PDB growth and binary growth affect every Release
  build.
- Effect on focused tests and integration tests: tests still pass.
- Effect on OpenCppCoverage output: not relevant outside build-cov.
- Effect on CI/build configuration: requires a single CMakeLists.txt edit
  but breaks the assumption that `Release` means "no debug info" for every
  consumer of the project. Upstream maintainers would object because
  Release binaries shipped to users would carry debug info.
- Risk to other build directories: high. Affects every Release build
  worldwide for the project. Inappropriate scope for a coverage-only
  concern.

Option 4: Use a CMake preset that sets these flags.

- Effect on Release build performance: same as Option 1.
- Effect on binary size: same as Option 1.
- Effect on focused tests and integration tests: tests still pass.
- Effect on OpenCppCoverage output: produces coverage data with line counts.
- Effect on CI/build configuration: requires a new entry in
  CMakePresets.json (e.g., `coverage-release`). Then user invokes
  `cmake --preset coverage-release`. The existing CMakePresets.json already
  has a `reldbg` preset family that uses `RelWithDebInfo`; adding a
  coverage-specific Release preset is redundant with Option 2.
- Risk to other build directories: zero for the preset itself, but the
  coverage scripts would need to switch from `cmake -B build-cov ...` to
  `cmake --preset coverage-release -B build-cov`. Significant script
  maintenance.

### Recommendation

**Adopt Option 1: Add `/Zi /DEBUG:FULL` to `CMAKE_CXX_FLAGS_RELEASE` for
build-cov via the cmake configure command.**

Recommendation rationale:

1. Minimum scope: only the build-cov build directory changes. Other
   Release builds remain unaffected.
2. Minimum script change: one cmake reconfigure of build-cov with
   `-DCMAKE_CXX_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL"`.
   Existing scripts use `build-cov/bin/Release/` paths unchanged.
3. Maximum optimization retention: keeps `/O2 /Ob2` (full optimization)
   rather than the RelWithDebInfo default of `/O2 /Ob1`.
4. Clean separation: Release semantics for build-cov become
   "Release with debug info" only inside the coverage build directory.
   `build` and `build-cuda` keep their strict-Release semantics.
5. Reversible: a single cmake reconfigure of build-cov without the flags
   reverts the change. No CMakeLists.txt or CMakePresets.json change to
   revert.
6. Lowest risk profile: zero impact on other build directories; no
   upstream or CI blast radius.

The cmake invocation to apply the change:

```powershell
cmake -B build-cov -DCMAKE_BUILD_TYPE=Release `
      -DCMAKE_CXX_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL" `
      <existing flags from the original build-cov configure>
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target llama-server -j 4
```

The Developer documents the full set of original build-cov flags used in
the implementation evidence so the reconfigure command is reproducible.

### Coverage-build behavior change analysis

Focused tests:

- Before: `build-cov/bin/Release/test-cache-controller.exe` runs with
  optimized Release flags. All 87 tests pass.
- After: same binary, rebuilt with `/Zi /DEBUG:FULL` added. All 87 tests
  still pass (verified by `cmake --build build-cov --config Release
  --target test-cache-controller` and direct binary invocation).

Integration tests / llama-server:

- Before: `build-cov/bin/Release/llama-server.exe` runs with optimized
  Release flags. Server starts, serves requests, runs integration tests.
- After: same binary, rebuilt with debug info. Server still starts, still
  serves requests, integration tests still pass.

Coverage output:

- Before: OpenCppCoverage emits `.cov` files that are header-only with no
  line counts. T114, T114a, T115 contracts BLOCKED-coverage-setup.
- After: OpenCppCoverage emits `.cov` files with line counts. Coverage
  contracts become measurable.

### Build freshness

The full build-cov rebuild is required because every C++ translation unit
needs to be recompiled with `/Zi`. Incremental rebuild alone (after just
editing CMakeCache.txt) would not produce the new PDB; the build system
relies on the compile flags to know which translation units are stale.
The Developer runs a clean rebuild per the clean-build rule in qa.md.
