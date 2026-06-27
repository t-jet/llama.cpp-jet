# Stage 28 implementation plan part 3B: evidence plan steps 6-10 + Stage 24 -08 contract

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)
Companion: [part-03a-steps-1-5-evidence.md](./part-03a-steps-1-5-evidence.md)

Steps 6-10 evidence continue the Stage 28 evidence plan.
Steps 1-5 evidence are in [part-03a](./part-03a-steps-1-5-evidence.md).

## Step 6 + Step 7 evidence (R28-BUG-04 Phase B)

### Step 6 build evidence

+ Check: test-cache-controller target with deprecation warnings.

  Command: `cmake --build build-cuda --config Release --target test-cache-controller -j 8`.

  Pass criterion: exit 0; 41+ deprecation warnings visible in build log.

  Evidence path: `._test_output/build-r28-bug04-phase-b-step6.log`.

### Step 7 build evidence

+ Check: test-cache-controller target with zero deprecation warnings.

  Command: `cmake --build build-cuda --config Release --target test-cache-controller -j 8`.

  Pass criterion: exit 0; 0 deprecation warnings (or documented exception list).

  Evidence path: `._test_output/build-r28-bug04-phase-b-step7.log`.

### Step 6 + 7 test evidence

+ Check: 138 tests pass post-Step 7.

  Command: `build-cuda/bin/Release/test-cache-controller.exe`.

  Pass criterion: exits 0; 138 PASS (count unchanged after migration).

  Evidence path: `._test_output/test-r28-bug04-phase-b.log`.

## Step 8 evidence (iter 1 verification)

+ Check: build-cuda llama-server.

  Command: `cmake --build build-cuda --config Release --target llama-server`.

  Pass criterion: exit 0; mtime fresh.

  Evidence path: `._test_output/build-r28-iter1-llama-server.log`.

+ Check: build-cuda test-cache-controller.

  Command: `cmake --build build-cuda --config Release --target test-cache-controller`.

  Pass criterion: exit 0; mtime fresh.

  Evidence path: `._test_output/build-r28-iter1-test-cache.log`.

+ Check: build-cuda-asan llama-server.

  Command: `cmake --build build-cuda-asan --config Release --target llama-server`.

  Pass criterion: exit 0; mtime fresh.

  Evidence path: `._test_output/build-r28-iter1-asan-llama-server.log`.

+ Check: test-cache-controller full pack.

  Command: `build-cuda/bin/Release/test-cache-controller.exe`.

  Pass criterion: exits 0; 139 PASS.

  Evidence path: `._test_output/test-r28-iter1.log`.

+ Check: Stage 24 -08 rerun.

  Command: per binding contract below.

  Pass criterion: all 4 legs reach leg cap; S02 hybrid <= 512 MiB; S03 hybrid >= 687 reqs.

  Evidence path: `._design_docs/.test_reports/test-report-20260627-01.md`.

## Step 9 evidence (MEDIUM items)

+ Check: R28-TD-04 + R28-TD-07 runner exit.

  Command: `pwsh -NoProfile -File stage24-chat-s02-s03-comparison.ps1 -RunId stage28-r28-td04-dry-run ...`.

  Pass criterion: exit 0; no `leak_scan` property error.

  Evidence path: `._test_output/stage24-r28-td04-dry-run.log`.

+ Check: R28-TD-03 TP-28-UT-02 SEH smoke.

  Command: grep for "TP-28-UT-02" in test log.

  Pass criterion: "PASSED" appears; crash dump file created in test crash dir.

  Evidence path: `._test_output/test-r28-td03-seh.log`.

+ Check: R28-TD-02 TP-28-UT-03 demote queue saturation.

  Command: grep for "TP-28-UT-03" in test log.

  Pass criterion: "PASSED" appears; no abort.

  Evidence path: `._test_output/test-r28-td02-demote-sat.log`.

+ Check: doc link resolve.

  Action: open each updated doc in any editor.

  Pass criterion: link resolves to existing file.

  Evidence path: manual verify.

## Step 10 evidence (R28-TD-05 conditional)

+ Check: llama-server target builds post-deletion.

  Command: `cmake --build build-cuda --config Release --target llama-server`.

  Pass criterion: exit 0.

  Evidence path: `._test_output/build-r28-td05.log`.

+ Check: 141 tests pass post-deletion.

  Command: `build-cuda/bin/Release/test-cache-controller.exe`.

  Pass criterion: exits 0; 141 PASS.

  Evidence path: `._test_output/test-r28-td05.log`.

+ Check: Stage 24 -08 rerun post-deletion.

  Command: same as Step 8.

  Pass criterion: all 4 legs PASS; durable report at `test-report-20260627-02.md`.

  Evidence path: `._design_docs/.test_reports/test-report-20260627-02.md`.

## Stage 24 -08 rerun contract (binding for Steps 4, 5, 9.1, 10)

The rerun uses the existing Stage 24 runner:

```text
pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1 \
  -RunId stage28-iter<N>-20260627-<NN> \
  -RowsToRun S02-chat,S03-chat \
  -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf \
  -RunRoot ._test_output/stage28-iter<N>-20260627-<NN> \
  -ReportPath ._design_docs/.test_reports/test-report-20260627-<NN>.md \
  -CacheColdPath D:\tmp\cache-cold-stage28-iter<N> \
  -BasePort 8900 \
  -LegDurationMin 10 \
  -ColdBudgetMiB 512 \
  -LlamaServerPath build-cuda/bin/Release/llama-server.exe
```

Pass criteria (all 4 legs):

+ All legs reach leg cap (10 min) with all-200 responses.
+ S02 hybrid filesystem bytes <= 512 MiB (was 5.37 GiB).
+ S02 hybrid per-id map sum equals filesystem bytes (within rounding).
+ S03 hybrid still >= 687 reqs (was 258 pre-Stage-27-fix).
+ Cold-store metric path unchanged for S03 hybrid (PASS-filesystem-fallback).
+ Crash dump dir empty.
+ Runner exit code 0 (R28-TD-04 fix).

## Coverage evidence

Stage 28 fixes touch 3 locations (test file, production file, build
file). The hybrid cache code path is already covered by the 138-test
pack and the Stage 24 runner. No new coverage threshold required.

However, R28-BUG-02 introduces TP-28-UT-01 (1 new controller test).
R28-TD-02 introduces TP-28-UT-03 (1 new controller test). R28-TD-03
introduces TP-28-UT-02 (1 new SEH handler test). Total new tests: 3.

## Durable report naming

+ Stage 28 iter 1: `.test_reports/test-report-20260627-01.md`.
+ Stage 28 iter 2: `.test_reports/test-report-20260627-02.md`.

Each report cites the previous report's verdict table as evidence
continuity (e.g., test-report-20260627-02 cites test-report-20260627-01).

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
