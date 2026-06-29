# Stage 29 implementation handoff: QA re-execution #10 (F-29-EXEC-17 still reproduces)

Status: QA BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start (gate #10)
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison)
Owner: Developer (next fix iteration)
Source QA report: [../../.test_reports/test-report-20260629-10-stage29-10.md](../../.test_reports/test-report-20260629-10-stage29-10.md)
Driver path: `D:\\source\\llama.cpp-jet\\._design_docs\\cache-handling-test-scripts\\compare-legacy-vs-hybrid.ps1`

## Summary

S29-IMPL-FIX-07 verified PARTIAL. Edit 1 (cold-path pre-create at Start-Stage29Server L88-90) WORKS: Phase 1 hybrid equivalence server successfully created 6 .cold files (511 MiB total) in `D:\\tmp\\cache-cold-stage29-10` without F-29-EXEC-19 reproducing.

Edit 2 (Main dispatcher `$wlPath = [string]$wl.workload` + replace 4 `$wl.workload` references) is INSUFFICIENT. The bug reproduces: `$wlPath` still has 3 leading whitespace bytes (0x20 0x20 0x20) in this driver execution context. main.stdout.log line 1 hex bytes 18-20: `20 20 20` (3 spaces) between "at" and "D:" confirm the bug. Driver fatal exit at L177 `Get-Content -LiteralPath $WorkloadPath` with `Cannot find drive. A drive with the name '  D' does not exist.`

## S29-IMPL-FIX-08 (suggested, next Developer iteration)

Three options, in order of preference:

- Option A (defensive cast, smallest diff): `$wlPath = ([string]$wl.workload).TrimStart()` and `$eqPath = ([string]$wl.equivalence).TrimStart()` at Main L230-231. Keeps the S29-IMPL-FIX-07 fix intact; adds whitespace stripping.
- Option B (avoid hashtable round-trip): change `Invoke-Phase05WorkloadBuild` to return script-scoped variables or pass paths by reference; Main reads them directly. Eliminates the hashtable property access path that injects whitespace.
- Option C (rebuild paths in Main): in Main, build the paths directly: `$wlPath = Join-Path $RunRoot 'workload.jsonl'; $eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'`. Ignore the value returned from `Invoke-Phase05WorkloadBuild` for path purposes; trust the function only for side effects.

Recommended: Option A (smallest, most defensive). Option C also acceptable; matches the wrapper-local pattern already used inside `Invoke-Phase05WorkloadBuild` at L149.

## Verification commands for next QA re-execution

After S29-IMPL-FIX-08 lands:

```powershell
# Dry-run preflight
pwsh -NoProfile -File D:\\source\\llama.cpp-jet\\._design_docs\\cache-handling-test-scripts\\compare-legacy-vs-hybrid.ps1 -DryRun -LlamaServerPath D:\\source\\llama.cpp-jet\\build-cuda\\bin\\Release\\llama-server.exe -ModelPath D:\\source\\llama.cpp-jet\\._test_models\\Qwen3.5-4B-MTP-GGUF\\Qwen3.5-4B-Q4_K_M.gguf -RunRoot D:\\source\\llama.cpp-jet\\_test_output\\stage29-cache-modes-20260629-NN-dryrun -CacheColdPath D:\\tmp\\cache-cold-stage29-NN-dryrun
# Main run
pwsh -NoProfile -File D:\\source\\llama.cpp-jet\\._design_docs\\cache-handling-test-scripts\\compare-legacy-vs-hybrid.ps1 -RunId stage29-cache-modes-20260629-NN -ModelPath D:\\source\\llama.cpp-jet\\._test_models\\Qwen3.5-4B-MTP-GGUF\\Qwen3.5-4B-Q4_K_M.gguf -RunRoot D:\\source\\llama.cpp-jet\\_test_output\\stage29-cache-modes-20260629-NN -ReportPath D:\\source\\llama.cpp-jet\\._design_docs\\.test_reports\\test-report-20260629-NN-stage29-NN.md -LlamaServerPath D:\\source\\llama.cpp-jet\\build-cuda\\bin\\Release\\llama-server.exe -CacheColdPath D:\\tmp\\cache-cold-stage29-NN -BasePort 8900 -LegDurationMin 1 -ColdBudgetMiB 2048 -HotBudgetMiB 512 -Cycles 1 -ContextSize 4096 -Parallel 2 -Seed 42
```

Verify main.stdout.log line 1 hex bytes 18-20 are `20 44 3A` (one space + "D:"), not `20 20 20 44` (three spaces + "D:").

## Carry-forward (unchanged)

- F-29-EXEC-13: Release build lacks /Zi; OpenCppCoverage unusable. Non-blocking.
- F-29-EXEC-14: huggingface-hub==1.16.1 incompatible with transformers. Non-blocking pytest sub-check.
- F-29-EXEC-19: RESOLVED this session (S29-IMPL-FIX-07 Edit 1 verified).

## Handoff

Next owner: Developer (S29-IMPL-FIX-08 driver fix). After fix and Architect review, next gate is QA re-execution gate #11 with the canonical driver. After re-run PASS: Developer test-results review. After Developer review: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, no unicode icons, and stays under the 300-line durable-doc cap.