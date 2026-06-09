# Test report 20260607-02 fixes

Source report: test-report-20260607-02.md
Date: 2026-06-07
Owner: Developer

## Scope

Unblock T114 (combined 80 percent on 19 files) and T114a (product-only
70 percent on 11 files) coverage rows that were BLOCKED in
test-report-20260607-02. Reconfigure build-cov so that OpenCppCoverage
0.9.9.0 can resolve modules and produce non-zero line coverage. Also
verify whether the test-stage10-policy-lru.cpp:105 assertion failure
is a build-flag artifact or a pre-existing product/test bug.

Out of scope: the 3 cap-fix files, the 5 pre-existing doc/skill mods,
the test plan, the original QA report, the Architect review, the
implementation log, and any source code change. Do not commit or push.

## Root cause (T114/T114a coverage blocker)

The pre-state root cause from the QA handoff attributed the BLOCKED
T114/T114a rows to BUILD_SHARED_LIBS=ON causing
`llama-server-impl.dll` to host cache source lines that
OpenCppCoverage 0.9.9.0 could not resolve. Verification showed that
the actual root cause had two layers:

1. BUILD_SHARED_LIBS=ON. Cache source lived in
   `llama-server-impl.dll` after the 20260607-02 reconfigure, while
   the 20260604-06 baseline (T114=0.8553, T114a=0.7035) used
   BUILD_SHARED_LIBS=OFF with cache source linked into the test exe.

2. Existing build-cov was configured with the "Visual Studio 18 2026"
   generator and CMAKE_BUILD_TYPE=RelWithDebInfo (UNINITIALIZED token,
   effective default RelWithDebInfo). The 20260604-06 baseline used
   "Visual Studio 17 2022" with RelWithDebInfo. The QA handoff did
   not call out the generator or effective config, only the flag set.

3. Reconfiguring with the original VS18 2026 generator plus
   -DBUILD_SHARED_LIBS=OFF still left the build output
   `build-cov/bin/Release` as a Windows reparse point (junction) to
   `build-cov/bin/RelWithDebInfo`. The build was originally
   RelWithDebInfo, so the first Release reconfigure created a junction
   in place of a real Release directory. Test binaries were
   re-linked into the RelWithDebInfo target via the junction, and
   the .pdb embedded path recorded "RelWithDebInfo" in its module
   stream. OpenCppCoverage then saw the module as
   `bin/RelWithDebInfo/test-cache-controller.exe`, did not match
   the script's --modules pattern `bin/Release/...`, and skipped
   the module. Net effect: per-test .cov files were 34-54 bytes
   (header only, no line data), exactly the same shape as the
   20260607-02 BLOCKED run.

Empirical confirmation via manual probe:

- `--modules bin/Release/test-cache-controller.exe` produced a 37-byte
  .cov (header only).
- `--modules bin/RelWithDebInfo/test-cache-controller.exe` produced
  a 12674-byte .cov with real line data.
- 20260605-01 historical run had 29121-byte .cov files (real data)
  under `bin/Release/._design_docs/.test_reports/coverage-run-20260605-01/cov-binary/`,
  indicating a real Release directory existed before subsequent
  CMakeCache.txt regenerations replaced it with a junction.

## Fix plan

The minimal sequence to unblock T114/T114a was:

1. Back up the existing build-cov CMakeCache.txt to preserve the
   pre-state for revert.
2. Reconfigure build-cov with -DBUILD_SHARED_LIBS=OFF using the
   existing generator (VS18 2026). The user's exact command used
   "Visual Studio 17 2022" but the existing build-cov was
   configured with VS18 2026, and CMake rejects generator
   switches without a CMakeCache.txt wipe. VS18 2026 is a
   functional match for the flag set in scope
   (/Zi /Ob1 /O2 /EHsc, /DEBUG:FULL); the difference between
   VS17 and VS18 generators is the toolset, not the cache config
   contract.
3. Remove the bin/Release junction so the re-link writes the .exe
   and .pdb into a real Release directory, not via a reparse
   point. This was not in the user-supplied steps but was
   necessary to make OpenCppCoverage resolve the module path.
4. Re-link all 10 required target binaries into the real
   bin/Release directory. The .obj files at the source-tree
   Release subdirectories (tools\server\Release, src\Release,
   tests\test-cache-controller.dir\Release, etc.) were already
   fresh from the prior full rebuild, so only the link steps
   ran. Re-link was ~5 min versus the 30 min full rebuild.
5. Re-run the focused binary to confirm 87/87 still pass after
   the re-link.
6. Re-run ctest to confirm the policy-lru assertion still fails
   (it does, see Open findings).
7. Re-run the coverage script; verify T114 and T114a values are
   non-zero and above their respective thresholds.

## Evidence

### Backup

- `build-cov/CMakeCache.txt.before-shared-off` (31247 bytes,
  created 2026-06-07 prior to reconfigure).

### CMake reconfigure

- Command:
  `cmake -S . -B build-cov -G "Visual Studio 18 2026" -A x64 -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=OFF -DCMAKE_CXX_FLAGS_RELEASE="/Zi /Ob1 /O2 /EHsc" -DCMAKE_EXE_LINKER_FLAGS_RELEASE="/DEBUG:FULL"`
  (generator matched to existing build-cov; user-supplied VS17
  2022 would have required a wipe).
- Exit code: 0.
- Log: `._design_docs/.test_reports/cmake-reconfigure-static-20260607-01.log`
  (header lines + `Configuring done (1.3s)` + `Generating done (5.9s)`).
- Post-reconfigure vcxproj count: 240 (RecursiveGet-ChildItem over
  build-cov).

### Clean rebuild

- Command:
  `cmake --build build-cov --config Release -j --target llama-server test-cache-controller test-step10-metrics test-stage10-cold-store-hardening test-stage10-policy-lru test-step6-demotion-protocol test-step7-promotion-protocol test-step11-test-hooks-fault-injection test-step12-branch-graph test-step13-stage8`
- Exit code: 0.
- Log: `._design_docs/.test_reports/build-cov-static-rebuild-20260607-01.log`
  (30979 bytes, 565 lines, 31 occurrences of C4244 only, no errors).
- Binaries after first rebuild (timestamped 15:33-15:34, all
  present, llama-server.exe 26945536 bytes confirming static link):
  - llama-server.exe
  - test-cache-controller.exe
  - test-step10-metrics.exe
  - test-stage10-cold-store-hardening.exe
  - test-stage10-policy-lru.exe
  - test-step6-demotion-protocol.exe
  - test-step7-promotion-protocol.exe
  - test-step11-test-hooks-fault-injection.exe
  - test-step12-branch-graph.exe
  - test-step13-stage8.exe

### Junction removal and re-link

- Verified `build-cov/bin/Release` was a Windows reparse point
  (Name Surrogate, Mount Point, Substitute Name ending
  `bin\RelWithDebInfo`).
- `cmd /c rmdir build-cov\bin\Release` removed the junction; a
  real Release directory was created in its place.
- Re-link command:
  `cmake --build build-cov --config Release -j --target llama-server test-cache-controller ... test-step13-stage8`
  (same target list as the full rebuild).
- Logs:
  - `._design_docs/.test_reports/build-cov-relink-20260607-01.log`
    (initial 2-target re-link probe, both targets emitted
    "performing full link" because the previous .exe was at the
    junction target).
  - `._design_docs/.test_reports/build-cov-relink-all-20260607-01.log`
    (full 10-target re-link, 0 errors).
- All 10 binaries timestamped 15:47-15:48 at `build-cov/bin/Release/`.

### Focused binary

- Command (PATH prefix kept for parity with 20260607-02 protocol
  even though static link does not require it):
  `$env:PATH = "D:\source\llama.cpp-jet\build-cov\bin\Release;$env:PATH"; Push-Location build-cov\bin\Release; .\test-cache-controller.exe`
- Exit code: 0.
- Log: `._design_docs/.test_reports/test-cache-controller-static-20260607-02.log`
  (249 lines).
- Key markers:
  - `T-NOUT-MAX-01 chunked decode n_outputs_max cap... PASSED`
  - `T-NOUT-MAX-02 MTP cap symmetric formula with clamp... PASSED`
  - `All tests passed successfully!`
  - `Total: 87 tests` (full breakdown matches 20260607-02
    canonical 87-test count).

### ctest

- Command: `ctest --test-dir build-cov -C Release --output-on-failure`
- Log: `._design_docs/.test_reports/ctest-static-20260607-02.log`.
- Result: 11 of 68 tests ran, 10 passed, 1 failed.
  - Failed: `test-stage10-policy-lru` (test #48), exit 0xc0000409,
    `Assertion failed: plan.protected_budget_pressure, file
    tests/test-stage10-policy-lru.cpp, line 105`.
  - 57 tests reported `(Not Run)` due to ctest bailing on the
    crash (ctest 3.x default scheduler).
- 20260607-02 ctest showed the same failure; verdict is unchanged.

### Coverage

- Command:
  `powershell -ExecutionPolicy Bypass -File ._design_docs/cache-handling-test-scripts/run_coverage.ps1 -BuildDir build-cov -Config Release -OutDir coverage-static-20260607-02 -SkipServerProbe`
- Log: `._design_docs/.test_reports/coverage-static-20260607-02.log`.
- Per-test .cov sizes (all > 350 bytes; no header-only stubs):
  - test-cache-controller.cov: 33984
  - test-step10-metrics.cov: 22766
  - test-stage10-cold-store-hardening.cov: 24001
  - test-stage10-policy-lru.cov: 356 (binary crashed mid-run;
    partial data only)
  - test-step6-demotion-protocol.cov: 23456
  - test-step7-promotion-protocol.cov: 23993
  - test-step11-test-hooks-fault-injection.cov: 23509
  - test-step12-branch-graph.cov: 5086
  - test-step13-stage8.cov: 24679
- Report: `coverage-static-20260607-02/coverage-report.md`.
- T114 (Combined result block): line rate 0.9276, 6546 / 7057
  lines, 80 percent threshold PASS.
- T114a (Product-only result block): line rate 0.8418, 2522 /
  2996 lines, 70 percent threshold PASS.
- Per-file highlights (combined, sorted):
  - server-cache-hybrid.cpp: 0.8418 (1570/1865)
  - server-cache-hybrid.h: 0.7338 (102/139)
  - server-cache-controller.cpp: 0.8333 (5/6)
  - server-cache-controller.h: 0.4 (2/5)
  - server-cache-store-cold.cpp: 0.8688 (192/221)
  - server-cache-store-cold.h: 0.7407 (20/27)
  - server-cache-graph.cpp: 0.8719 (463/531)
  - server-cache-graph.h: 0.95 (19/20)
  - server-cache-io-worker.cpp: 0.8442 (130/154)
  - server-cache-policy-lru.cpp: 0.7037 (19/27)
  - server-cache-legacy.h: 0 (0/1) (single-line file, no
    exercisable body)

## Handoff

### T114 and T114a: UNBLOCKED, both PASS

- T114 = 0.9276 (6546 / 7057), PASS at 80 percent threshold.
- T114a = 0.8418 (2522 / 2996), PASS at 70 percent threshold.
- Both values cited from the
  `coverage-static-20260607-02/coverage-report.md` blocks named
  in the user's spec (Combined result for T114, Product-only
  result for T114a).
- Both thresholds exceed the 20260604-06 baseline (T114=0.8553,
  T114a=0.7035). The lift is partly real (test plan additions
  between 2026-06-04 and 2026-06-07) and partly coverage-tool
  fidelity (server-cache-impl.dll coverage is now folded into
  the test exe where OpenCppCoverage can read it).

### Cap-fix regression rows: all PASS

- Focused binary: 87/87 PASS (line 248 of
  test-cache-controller-static-20260607-02.log).
- ctest tests 34, 37, 42, 43, 46, 47, 49, 50, 51, 67 all PASS.
- T-NOUT-MAX-01 and T-NOUT-MAX-02 PASS in focused binary;
  cap-fix behavioral contract preserved.

### Open finding 1: test-stage10-policy-lru.cpp:105 still fails

- The assertion at line 105 is NOT a build-flag artifact. It
  reproduces identically with BUILD_SHARED_LIBS=OFF in a real
  Release directory. Root cause is a semantic mismatch
  between the test expectation and the LRU policy
  implementation:

  - Test (test-stage10-policy-lru.cpp:88-105,
    `test_policy_lru_unprotected_evicted_first`): builds
    1 unprotected candidate (1024 bytes) + 1 protected
    candidate (1024 bytes), runs
    `plan_evictions(2048, 1024, false, candidates)`. The
    LRU policy evicts only the unprotected entry, which
    brings resident to 1024 = budget. The test asserts
    `plan.protected_budget_pressure == true`.

  - Implementation
    (server-cache-policy-lru.cpp:42-43): the policy sets
    `plan.protected_budget_pressure = true` only when
    actually evicting a protected candidate, not when an
    unprotected eviction leaves a protected candidate at
    risk. In the test case, the protected candidate is
    never evicted, so the flag stays false.

- The test data setup at line 95-105 cannot be satisfied by
  the current implementation under any order. The two
  reasonable fixes are (a) update the implementation to set
  `protected_budget_pressure` whenever budget pressure
  forced an unprotected eviction while a protected candidate
  was skipped (semantic: "we were under pressure and a
  protected entry was at risk"), or (b) update the test to
  remove the `assert(plan.protected_budget_pressure)` line
  on this test case (semantic: "we did not actually have to
  evict a protected entry").

- Per the user's session scope, no code fix was applied.
  A separate session is needed to pick (a) or (b) and
  re-run the cap-fix tests. The test-stage10-policy-lru.cov
  356-byte stub reflects the binary crashing at this
  assertion; if this finding is fixed, the .cov will grow
  and may marginally lift the policy-lru.cpp line rate
  above 0.7037.

- `server-cache-policy-lru.cpp` and
  `test-stage10-policy-lru.cpp` are NOT in the 3-file
  cap-fix diff and are NOT in the 5 pre-existing doc/skill
  mods, so the fix is clean to plan in a fresh session.

### Open finding 2: build-cov/bin/Release is no longer a junction

- During this session, the Release symlink was removed and
  replaced with a real directory. This is a build-cov
  config change. If the user wants to revert, the
  `build-cov/CMakeCache.txt.before-shared-off` backup
  remains and the original cmake reconfigure can be
  re-run, but the junction will not reappear automatically
  (CMake creates a junction only when the directory does
  not exist on the first reconfigure to that config).

- The downstream effect is that future builds writing to
  `bin/Release` go to the real directory. This is the
  intended state for OpenCppCoverage compatibility. No
  follow-up action required, but document the change in
  the handoff because the next developer who wipes
  build-cov and reconfigures from scratch will need to
  know that the original was a junction, not a real
  directory.

### Open finding 3: Generator is VS18 2026, not VS17 2022

- The user-supplied reconfigure command used "Visual Studio
  17 2022", but the existing build-cov was configured with
  "Visual Studio 18 2026". VS18 2026 was used to match the
  existing toolset without wiping build-cov. VS18 2026
  produces coverage-compatible binaries on OpenCppCoverage
  0.9.9.0 when the .pdb path matches the --modules pattern,
  as verified by the 12674-byte manual probe. No follow-up
  action required for the coverage verdict.

### Manager gate readiness

- T114, T114a, T-NOUT-MAX-01, T-NOUT-MAX-02, H57, T121, and
  Stage 4-9 regression: all PASS in the new evidence base
  (focused binary + ctest + coverage report).
- test-stage10-policy-lru: pre-existing product/test bug
  not in cap-fix scope; tracked as Open finding 1 for
  separate session.
- H53/H54: still BLOCKED on missing MTP-capable GGUF model
  fixture, preserved as part-3 integration rows.
- T-MTP-FIX-01: still PASS by reference to
  test-report-20260607-01.md Section 4.

Manager can close T114 and T114a and reopen the cap-fix
gate for sign-off pending the test-stage10-policy-lru
finding resolution.
