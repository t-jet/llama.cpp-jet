# Stage 28 implementation plan part 3A: evidence plan steps 1-5

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)
Companion: [part-03b-steps-6-10-evidence.md](./part-03b-steps-6-10-evidence.md)

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)

This part specifies, per implementation step, the build evidence,
test evidence, and Stage 24 -08 rerun evidence required. All
builds are NDEBUG plus Release plus CUDA enabled (build-cuda) or
ASan plus CUDA side-channel (build-cuda-asan). ASan plus Release
without CUDA is the build-cov variant for coverage; not in Stage
28 scope.


## Steps 1-5 evidence

## Step 1 evidence

### Step 1 build evidence (NDEBUG Release, CUDA enabled)

+ Check: test-cache-controller target builds.

  Command: `cmake --build build-cuda --config Release --target test-cache-controller -j 8`.

  Pass criterion: exit 0.

  Evidence path: `._test_output/build-r28-bug01.log`.

### Step 1 test evidence

+ Check: full unit test pack.

  Command: `build-cuda/bin/Release/test-cache-controller.exe`.

  Pass criterion: exits 0; prints "All tests passed successfully!"; no abort at 0xC0000409.

  Evidence path: `._test_output/test-r28-bug01.log`.

+ Check: TP-26-UT6 specific.

  Command: grep for "TP-26-UT6" or test label in test log.

  Pass criterion: "PASSED" appears in stdout.

  Evidence path: `._test_output/test-r28-bug01.log`.

+ Check: pre-fix regression check.

  Action: revert Step 1; rebuild; run test.

  Pass criterion: abort at 0xC0000409 reproduces at TP-26-UT6 line.

  Evidence path: transient, captured in implementation log.

+ Check: TP-27-UT-01 still PASS.

  Command: grep for "TP-27-UT-01" or "stage27_mark_payload" in test log.

  Pass criterion: "PASSED" appears in stdout.

  Evidence path: `._test_output/test-r28-bug01.log`.

## Step 2 evidence

### Step 2 build evidence (ASan + CUDA side-channel)

+ Check: llama-server ASan target builds.

  Command: `cmake --build build-cuda-asan --config Release --target llama-server -j 8`.

  Pass criterion: exit 0; zero LNK2038 errors.

  Evidence path: `._test_output/build-r28-bug03-asan.log`.

+ Check: ASan runtime DLL present.

  Command: `Get-ChildItem build-cuda-asan/bin/Release/clang_rt.asan_dynamic-x86_64.dll`.

  Pass criterion: file exists.

  Evidence path: PowerShell output.

+ Check: binary functional.

  Command: `build-cuda-asan/bin/Release/llama-server.exe --version`.

  Pass criterion: exit 0.

  Evidence path: `._test_output/version-r28-bug03.txt`.

### Step 2 test evidence

No new tests; this step unblocks future ASan reruns.

## Step 3 evidence (diagnosis)

### Step 3 empirical evidence

+ Check: diagnostic log captures cold_store.remove() returns.

  Action: rerun Stage 24 -07 S02 hybrid with diagnostic logging.

  Pass criterion: log shows N>0 remove() calls with return values matching map mutation.

  Evidence path: `._test_output/stage24-r28-bug02-diag.log`.

+ Check: diagnostic log captures cold_store.write() calls.

  Action: same rerun.

  Pass criterion: log shows N>0 write() calls with paired map insert.

  Evidence path: same file.

+ Check: filesystem count delta.

  Action: count *.cold files before/after rerun.

  Pass criterion: delta matches the per-id map delta.

  Evidence path: `D:\tmp\cache-cold-stage28-diag\`.

## Step 4 evidence (fix)

### Step 4 build evidence

+ Check: llama-server + test-cache-controller target builds.

  Command: `cmake --build build-cuda --config Release --target llama-server --target test-cache-controller -j 8`.

  Pass criterion: exit 0.

  Evidence path: `._test_output/build-r28-bug02.log`.

### Step 4 test evidence

+ Check: TP-28-UT-01 passes.

  Command: grep for "TP-28-UT-01" or test label in test log.

  Pass criterion: "PASSED" appears in stdout.

  Evidence path: `._test_output/test-r28-bug02-unit.log`.

+ Check: pre-fix regression check.

  Action: revert Step 4 fix; rebuild; run test.

  Pass criterion: TP-28-UT-01 aborts with FAIL message.

  Evidence path: transient, captured in implementation log.

### Step 4 Stage 24 -08 rerun evidence

+ Check: S02 hybrid filesystem bytes <= 512 MiB.

  Pass criterion: compare-cold-budget-fs <= 512 MiB.

  Evidence path: `._design_docs/.test_reports/test-report-20260627-01.md`.

+ Check: S03 hybrid filesystem within budget.

  Pass criterion: within rounding of per-id map sum.

  Evidence path: same report.

+ Check: D-EXEC-27-08 still verified.

  Pass criterion: S03 hybrid >= 258 reqs (D-EXEC-27-08 threshold).

  Evidence path: same report.

## Step 5 evidence (R28-BUG-04 Phase A)

### Step 5 build evidence

+ Check: llama-server target builds.

  Command: `cmake --build build-cuda --config Release --target llama-server -j 8`.

  Pass criterion: exit 0.

  Evidence path: `._test_output/build-r28-bug04-phase-a.log`.

### Step 5 test evidence

+ Check: 138 tests pass.

  Command: `build-cuda/bin/Release/test-cache-controller.exe`.

  Pass criterion: exits 0; 138 PASS.

  Evidence path: `._test_output/test-r28-bug04-phase-a.log`.

### Step 5 Stage 24 -08 rerun evidence (pre-fix regression check)

+ Check: pre-fix hang reproduces.

  Action: revert Step 5; rerun S03 hybrid cold checkpoint restore; observe 30 s burn.

  Pass criterion: captured in implementation log.

+ Check: post-fix hang closes.

  Action: re-apply Step 5; rerun; observe < 100 ms cold checkpoint restore.

  Evidence path: `._design_docs/.test_reports/test-report-20260627-01.md`.

+ Check: post-fix leak closes.

  Action: check hybrid-stage24 descriptor state log; no `promoting` descriptors stuck.

  Evidence path: same report.


## Handoff to part-03b

Steps 6-10 evidence and the Stage 24 -08 rerun contract are in
[part-03b](./part-03b-steps-6-10-evidence.md).

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
