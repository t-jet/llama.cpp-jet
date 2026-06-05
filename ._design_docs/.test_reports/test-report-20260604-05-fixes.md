# Stage 11 test report 20260604-05 fixes handoff

Source report: [test-report-20260604-05.md](test-report-20260604-05.md)
Date: 2026-06-04
Owner: Stage 11 Developer (handoff)
Next owner: Stage 11 Developer (fixes session, separate from this session)
Verifier: Stage 11 Architect (fixes review)
Approver: Stage 11 Manager (closure decision)

## What needs a fix

The real merge tree `e0f3f868b` does not compile. The MSVC
compiler rejects `tools/server/server-context.cpp` at line 3653
with `C2086: redefinition of 'const bool near_prompt_end'`. Lines
3651 and 3653 of the merged file are byte-identical:

```text
3651:                    const bool near_prompt_end = slot.task->n_tokens() < slot.prompt.n_tokens() + n_ubatch;
3652:
3653:                    const bool near_prompt_end = slot.task->n_tokens() < slot.prompt.n_tokens() + n_ubatch;
```

Until this is fixed, no test in the Stage 11 plan can run.
Every closure contract row (T114, T114a, T115, T121) and every
other row (ctest, pytest, HTTP probe, OWASP, k6, Stage 4-9
regression) is BLOCKED with the build defect as the reason.

## Reproduction

Reproduction is straightforward. The clean build is
deterministic on this host:

```powershell
git checkout e0f3f868b
Remove-Item -Recurse -Force build-cov -ErrorAction SilentlyContinue
cmd /c '"C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul && cmake -B build-cov -S . -G "Visual Studio 18 2026" -A x64 -DCMAKE_BUILD_TYPE=RelWithDebInfo -DCMAKE_CXX_FLAGS_RELEASE="/Zi /Ob1 /O2 /EHsc" -DCMAKE_EXE_LINKER_FLAGS_RELEASE="/DEBUG:FULL" -DGGML_NATIVE=OFF -DGGML_OPENMP=OFF -DGGML_OPENCL=OFF -DGGML_CUDA=OFF -DGGML_VULKAN=OFF -DGGML_METAL=OFF -DGGML_SYCL=OFF -DGGML_CPU_ALL_VARIANTS=OFF -DGGML_LLAMAFILE=ON -DLLAMA_BUILD_TESTS=ON -DLLAMA_BUILD_SERVER=ON -DLLAMA_BUILD_TOOLS=ON -DLLAMA_CURL=OFF -DLLAMA_OPENSSL=OFF'
cmd /c '"C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat" -arch=x64 -host_arch=x64 >nul && cmake --build build-cov --config RelWithDebInfo --target llama-server test-cache-controller test-step10-metrics test-stage10-cold-store-hardening test-stage10-policy-lru test-step6-demotion-protocol test-step7-promotion-protocol test-step11-test-hooks-fault-injection test-step12-branch-graph test-step13-stage8 -j 4'
```

Captured failure (from
`._design_docs/.test_reports/build-cov-rebuild-20260604-05.log`,
lines 547-550):

```text
D:\source\llama.cpp-jet\tools\server\server-context.cpp(3653,32): error C2086: 'const bool near_prompt_end': redefinition [D:\source\llama.cpp-jet\build-cov\tools\server\server-context.vcxproj]
      D:\source\llama.cpp-jet\tools\server\server-context.cpp(3651,32):
      see declaration of 'near_prompt_end'
```

The build halts at this error. `llama-server.exe`,
`llama-server-impl.dll`, and all 9 focused test binaries are
not produced.

## Root cause

Both parents of the real merge added a `const bool
near_prompt_end` declaration in the same lexical scope of
`tools/server/server-context.cpp`:

| Parent | Source | Upstream line in the parent tree |
| --- | --- | --- |
| `6ddc9430b` (`upstream_master`) | upstream commit `e2ef8fe42` ("server: fix checkpoints creation", PR #22929) | 3058 |
| `3b9ed9712` (cache-optimization tip) | Stage 10 chain | 3636 |

Git's 3-way merge algorithm did not flag this as a textual
conflict because the two branches modified different
surrounding lines and the merge base did not contain the
declaration. The auto-resolved merge added both branches'
declarations at adjacent lines 3651 and 3653. The result is
a C++ redefinition error that any C++ compiler rejects.

The prior 2026-06-04 closure was based on the fabricated
single-parent commit `72cfbcd44` (a child of `bdb166ac1`,
the Stage 10 tip). That commit was not produced by `git merge`
and never received upstream's `server-context.cpp` changes.
It carries exactly one declaration at line 3600, builds
clean, and is the reason the prior closure passed. The
defect is specific to the real merge tree.

The three explicit textual conflicts in the real merge
(`common/fit.h`, `common/speculative.cpp`,
`ggml/src/ggml-backend-meta.cpp`) were resolved correctly
and contain no compile error. The defect is isolated to
`server-context.cpp`.

## Fix scope

The minimum fix is to remove one of the two duplicate
declarations. The two lines are byte-identical:

```text
                    const bool near_prompt_end = slot.task->n_tokens() < slot.prompt.n_tokens() + n_ubatch;
```

Suggested implementation:

1. Create a new branch off `e0f3f868b` (or off
   `cache-optimization-stage11-merge`):

   ```powershell
   git checkout e0f3f868b
   git switch -c stage11-merge-fix
   ```

2. Edit `tools/server/server-context.cpp` to remove the
   second `near_prompt_end` declaration. Keep the first
   occurrence (line 3651) and delete the second (line 3653).
   The exact deletion is:

   ```text
   -                    const bool near_prompt_end = slot.task->n_tokens() < slot.prompt.n_tokens() + n_ubatch;
   -
   ```

3. Commit the fix with a clear message:

   ```text
   Stage 11 merge fix: remove duplicate near_prompt_end declaration in server-context.cpp
   ```

4. Re-run the clean build of `build-cov/` to confirm the
   tree compiles end-to-end and the 9 test binaries plus
   `llama-server.exe` are produced.
5. Optionally: re-run the clean build of `build/` (Release)
   to confirm both build configurations succeed.

## After the build fix

Once the build compiles cleanly, the Developer should re-run
the QA session (a fresh
[test-report-20260604-06.md](test-report-20260604-06.md) or
later) which will:

1. Run the full ctest set on the 9 focused test binaries
   and confirm the prior 8-of-9 pass result on
   `test-step10-metrics` is still as expected (the row 1 fix
   in
   [test-report-20260604-04-fixes.md](test-report-20260604-04-fixes.md)
   must still be in place).
2. Run `pytest` (3+1xfail per prior reports).
3. Run the public HTTP probe for T121 and confirm
   `cache_checkpoint_admission_failures_total{mode="hybrid"}`
   is non-zero.
4. Run the OpenCppCoverage script and read the
   `## Combined result` and `## Product-only result` blocks
   from `coverage-report.md`. The T114 row is expected to
   PASS (0.8508 per the prior rerun, 0.8521 per Stage 10
   closure). The T114a row is expected to remain FAIL
   (0.6974 per the prior rerun) and is the separate product-
   only coverage gap tracked in
   [part-13-t114-product-only-coverage.md](../../cache-handling-test-plan/part-13-t114-product-only-coverage.md).
5. Run the k6 benchmark.
6. Run the Stage 4-9 regression scope.

The T114a row will be reclassified per the new measurement
on the real merge tree, not by reference to the prior
"tooling limitation" closure. If T114a is still FAIL on the
real merge tree, the next Developer gate will need to apply
the `/Ob1` or `__declspec(noinline)` follow-up recorded in
[part-14-t114a-tooling-limitation.md](../../cache-handling-test-plan/part-14-t114a-tooling-limitation.md)
to lift the rate above 0.70.

## Non-failures worth noting

- The 3 conflict-resolved files (`common/fit.h`,
  `common/speculative.cpp`, `ggml/src/ggml-backend-meta.cpp`)
  were re-verified in this session and contain no compile
  error. The merge resolution is correct on those files.
- The Stage 11 source-only changes (the new
  `server_write_stage10_cache_rows` rows, the
  `pre_norm` -> `nextn` rename, the focused test functions
  added in `test-cache-controller.cpp` for the T114a lift
  attempt) are not affected by this build defect. They are
  applied on top of the merge and are reachable once the
  duplicate declaration is removed.
- The coverage script (`run_coverage.ps1`) is correct as
  written. The Phase 3 merge fix from
  [test-report-20260604-04-fixes.md](test-report-20260604-04-fixes.md)
  (row 2) is in place and the script is ready to run once
  the build succeeds.

## Handoff

The real merge tree `e0f3f868b` is not in a state where
Stage 11 can close. The blocker is a single duplicate line
in `tools/server/server-context.cpp`. The fix is a one-line
deletion. The next Developer session applies the fix, runs
the clean build, and hands the resulting tree to QA for
re-execution.

The next QA session report name will be
`test-report-20260604-06.md` (or later) and will be a
complete re-run of the test plan on the fixed tree. This
report is closed as BLOCKED.
