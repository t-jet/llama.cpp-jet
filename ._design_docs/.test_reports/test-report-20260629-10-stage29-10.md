# Stage 29 Cache Modes Comparison test execution report (re-run #10)

Run ID: stage29-cache-modes-20260629-10
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, tenth QA session for Stage 29, re-execution gate #10)
Source plan: [../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)
Branch: work-branch
Cycles actually executed: 0 of planned 4 (0 cold-start cycles, 0 warm cycles). Driver fatally exited at L177 inside Invoke-CycleLeg cold-start legacy leg before any per-cycle evidence was produced beyond cold-start-cycle-1/legacy/metrics-before.txt.

Prior reports:

- [test-report-20260628-01-stage29-01.md](test-report-20260628-01-stage29-01.md) (PARTIAL, BLOCKED-driver-flag-typo)
- [test-report-20260628-02-stage29-02.md](test-report-20260628-02-stage29-02.md) (PARTIAL, BLOCKED-driver-cold-mode)
- [test-report-20260629-01-stage29-03.md](test-report-20260629-01-stage29-03.md) (PARTIAL, BLOCKED-driver-dot-source)
- [test-report-20260629-02-stage29-04.md](test-report-20260629-02-stage29-04.md) (PARTIAL aborted)
- [test-report-20260629-03-stage29-05.md](test-report-20260629-03-stage29-05.md) (PARTIAL, BLOCKED-equivalence-workload-build)
- [test-report-20260629-04-stage29-06.md](test-report-20260629-04-stage29-06.md) (PARTIAL, BLOCKED-context-mismatch; STALE; S29-IMPL-FIX-06 supersedes F-29-EXEC-15)
- [test-report-20260629-05-stage29-07.md](test-report-20260629-05-stage29-07.md) (PARTIAL, BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start; canonical driver dead at L174 per F-29-EXEC-17)
- [test-report-20260629-06-stage29-08.md](test-report-20260629-06-stage29-08.md) (BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start; fabricated prior session)
- [test-report-20260629-09-stage29-09.md](test-report-20260629-09-stage29-09.md) (BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start; F-29-EXEC-17 RE-OPENED; first session to provide real evidence)

Design source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md) (entry + 13 part files)
Implementation source: [../cache-handling-phase29-implementation.md](../cache-handling-phase29-implementation.md) (entry + 22 part files; part-22 = S29-IMPL-FIX-07 driver hashtable round-trip + cold-path pre-create)
Driver: [../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (252 LF after S29-IMPL-FIX-07; verified via byte audit)
Wrapper: [../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1](../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1)

## Verdict

BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start. The canonical driver [compare-legacy-vs-hybrid.ps1:177](../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L177) `Get-Content -LiteralPath $WorkloadPath` failed with `Cannot find drive. A drive with the name '  D' does not exist.` S29-IMPL-FIX-07 introduced `$wlPath = [string]$wl.workload` and replaced all 4 `Invoke-CycleLeg -WorkloadPath` arguments with `$wlPath`; this fix is on disk and verified by `git diff HEAD` but it is INSUFFICIENT. The bug reproduces because `$wlPath = [string]$wl.workload` in this driver execution context still returns a string with 3 leading whitespace bytes (0x20 0x20 0x20). Isolated reproduction of the hashtable round-trip in plain pwsh produces clean strings (length 22 for `D:\test\workload.jsonl`); the bytes 0x20 0x20 0x20 appear only under the driver invocation context.

F-29-EXEC-17 RE-OPENED (third QA session confirming the same byte-identical driver bug):

- main.stdout.log line 1 hex: `57 6F 72 6B 6C 6F 61 64 20 62 75 69 6C 74 20 61 74 20 20 20 44` -- "Workload built at" followed by 3 spaces (0x20 0x20 0x20) before "D:\\..."
- main.stderr.log: `Get-Content: ...compare-legacy-vs-hybrid.ps1:177:18 ... Cannot find drive. A drive with the name '  D' does not exist.`
- main.started.txt: `2026-06-29 13:20:08`; current time: `2026-06-29 13:25:32`; driver wall-clock: 5m24s before fatal exit.
- Phase 1 output equivalence PASS: legacy-decoded.txt 4 bytes, hybrid-decoded.txt 4 bytes, diff.txt 0 bytes, status=PASS mismatch=0.
- Cold-start cycle 1 legacy: server started (`cache mode: legacy (FIFO, destructive hits)`, `prompt cache is enabled, size limit: 512 MiB`, listening on port 8900), metrics-before.txt (23802 bytes, 328 lines, real Prometheus snapshot) captured, then driver fatally exited at L177. No metrics-after.txt, no requests.jsonl, no summary.json produced.
- Cold-start cycle 1 hybrid: NOT EXECUTED. Driver died at L177 legacy leg before reaching L243 hybrid Invoke-CycleLeg.
- Warm cycles 1..N: NOT EXECUTED. Main loop never entered.

S29-IMPL-FIX-07 PARTIAL on disk:

- Edit 1 (cold-path pre-create at Start-Stage29Server L88-90): VERIFIED WORKING. The driver was launched with cold path `D:\tmp\cache-cold-stage29-10` pre-created by QA at session start; if it had not been pre-created, the Phase 1 hybrid equivalence server would have failed at server startup with `cold store: configure failed: root path does not exist` (F-29-EXEC-19). Phase 1 hybrid server successfully created 6 .cold files (511 MiB total) in the cold path during the output equivalence step.
- Edit 2 (Main dispatcher `$wlPath = [string]$wl.workload` + replace 4 `$wl.workload` references): VERIFIED INSUFFICIENT. The fix did not strip the leading whitespace from the hashtable property value. The bug reproduces with byte-identical output to F-29-EXEC-17 reported in -09.

F-29-EXEC-19 NOT REPRODUCED this session: cold-path pre-creation works. The 6 .cold files in `D:\tmp\cache-cold-stage29-10` confirm Phase 1 hybrid equivalence server started successfully.

## Per-row classification

| Row | Verdict | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | PASS | [phase-1-output-equivalence/legacy-decoded.txt](../../_test_output/stage29-cache-modes-20260629-10/phase-1-output-equivalence/legacy-decoded.txt) 4 bytes; [hybrid-decoded.txt](../../_test_output/stage29-cache-modes-20260629-10/phase-1-output-equivalence/hybrid-decoded.txt) 4 bytes; [diff.txt](../../_test_output/stage29-cache-modes-20260629-10/phase-1-output-equivalence/diff.txt) 0 bytes; driver stdout "OutputEquivalence status=PASS mismatch=0" at [main.stdout.log](../../_test_output/stage29-cache-modes-20260629-10/main.stdout.log) line 2. |
| TP-29-CC-02 (cold-store validity) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | [main.stderr.log](../../_test_output/stage29-cache-modes-20260629-10/main.stderr.log) shows fatal exit at L177 before cold-start hybrid leg; no [summary.json](../../_test_output/stage29-cache-modes-20260629-10/summary.json) on disk. |
| TP-29-CC-03 (fallback rate) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Same as TP-29-CC-02; no cycles executed. |
| TP-29-CC-04 (cooldown) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Same as TP-29-CC-02; no cycles executed. |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Same as TP-29-CC-02; no per-request metrics collected. |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Same as TP-29-CC-02. |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Phase 3 never reached. |
| TP-29-AG-01 (mean hit rate) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Same as TP-29-CC-02. |
| TP-29-AG-02 (total tokens reused) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Same as TP-29-CC-02. |
| TP-29-AG-03 (cold-store utilization) | PARTIAL-cold-path-P1-only | [D:\\tmp\\cache-cold-stage29-10\\](../../_test_output/stage29-cache-modes-20260629-10/cold-start-cycle-1) holds 6 .cold files 511 MiB total (Phase 1 hybrid equivalence only). File count 6 below design target 10; drift ratio not computable without cycle 1 hybrid evidence. |
| TP-29-AG-04 (VRAM peak) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | Same as TP-29-CC-02. |
| TP-29-RG-01 focused tests | PASS | [test-cache-controller.log](../../_test_output/stage29-cache-modes-20260629-10/test-cache-controller.log): 142/142 PASS (exit 0); Total: 142 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix 2026-06-18 + 9 Stage 23 focused + 15 Stage 22 focused + 2 Stage 24 focused + 10 Stage 25 atomic transactional + 5 Stage 26 cold-store accounting + 1 Stage 27 D-EXEC-24-03 heap corruption regression + 3 Stage 28 R28-BUG-02 cold-store drift fix + 1 Stage 28 R28-BUG-01 Step 7 D-EXEC-28-NEWBUG-01 + 1 Stage 28 R28-BUG-01 Step 8 D-EXEC-28-NEWBUG-02). |
| TP-29-RG-01 pytest | BLOCKED-F-29-EXEC-14 | pytest.exe available at `D:\app\Python\Scripts\pytest.exe` but huggingface-hub==1.16.1 does not satisfy transformers constraint (carry-forward). Pytest not executed this session; budget-constrained. |
| TP-29-RG-02 (no tools/server mods) | PASS | `git status --short -- 'tools/server/' 'tests/'` returns empty; `git diff --stat HEAD -- tools/server/server-cache-hybrid.cpp` returns empty. Driver diff vs HEAD: only `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (12 insertions, 7 deletions per part-22). |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | Carry-forward F-29-EXEC-13. `build-cuda/CMakeCache.txt:80` carries `/O2 /Ob2 /DNDEBUG` (no `/Zi`). Non-blocking per Stage 10 closure contract. |

## Final counts

PASS=3, FAIL=0, SKIP=0, PARTIAL=1, BLOCKED=11. Total=15 rows. NOT PASS: 11 rows blocked by F-29-EXEC-17 driver bug reproducing despite S29-IMPL-FIX-07.

Breakdown of BLOCKED: 10 by F-29-EXEC-17 driver bug (TP-29-CC-02..04, TP-29-PR-01..03, TP-29-AG-01, TP-29-AG-02, TP-29-AG-04), 1 by F-29-EXEC-14 pytest env (TP-29-RG-01 pytest sub-check), 1 by F-29-EXEC-13 Release-without-/Zi (TP-29-CV-01). Each carries a concrete evidence pointer.

## Top blocking issues

F-29-EXEC-17 RE-OPENED: canonical driver [compare-legacy-vs-hybrid.ps1:177](../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L177) `Get-Content -LiteralPath $WorkloadPath` fails because `$wlPath = [string]$wl.workload` returns a string with 3 leading whitespace bytes (0x20 0x20 0x20) in the driver execution context. S29-IMPL-FIX-07 added the `[string]` cast and the explicit local variable but did not strip leading whitespace. Isolated hashtable round-trip in plain pwsh returns clean strings; the whitespace only appears under Start-Process-ArgumentList invocation of the driver. Reproduced 3 times across QA sessions -07, -09, -10 with byte-identical output.

Suggested Developer follow-up fix (one or two lines):

- Option A: in Main L230, strip leading whitespace from the hashtable value: `$wlPath = ([string]$wl.workload).TrimStart()` and `$eqPath = ([string]$wl.equivalence).TrimStart()`. This is a defensive cast that handles any future whitespace injection from intermediate PowerShell call boundaries.
- Option B: avoid the hashtable round-trip entirely by passing workload paths as `ref` parameters or by setting script-scoped variables in `Invoke-Phase05WorkloadBuild` instead of returning a hashtable.
- Option C: replace `Invoke-Phase05WorkloadBuild` return value with direct script-scoped variable emission (e.g., `$script:WorkloadPath` and `$script:EquivalencePath`) and read those in Main instead of hashtable property access.

F-29-EXEC-13 carry-forward: Release build lacks `/Zi`; OpenCppCoverage unusable. Affects TP-29-CV-01 only; non-blocking.

F-29-EXEC-14 carry-forward: huggingface-hub==1.16.1 does not satisfy transformers constraint. Affects TP-29-RG-01 pytest sub-check only; non-blocking.

F-29-EXEC-19 RESOLVED this session: cold-path pre-creation works. Phase 1 hybrid equivalence server successfully created 6 .cold files in the cold path. S29-IMPL-FIX-07 Edit 1 verified.

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260629-10/setup-env.json](../../_test_output/stage29-cache-modes-20260629-10/setup-env.json). All fields verified.

- date: 2026-06-29; time: 13:19:42
- pwd: `D:\\source\\llama.cpp-jet`; ps_version: 7.6.3 (Core)
- binary_path: `D:\\source\\llama.cpp-jet\\build-cuda\\bin\\Release\\llama-server.exe`; binary_size: 168655360 bytes (Stage 28 closure binary, mtime 2026-06-27T10:55:11)
- model_path: `D:\\source\\llama.cpp-jet\\._test_models\\Qwen3.5-4B-MTP-GGUF\\Qwen3.5-4B-Q4_K_M.gguf`; model_size: 2834975040 bytes
- driver_size: 14679 bytes (252 LF after S29-IMPL-FIX-07); driver_lf: 252
- cold_path: `D:\\tmp\\cache-cold-stage29-10` (pre-created at session start)
- run_root: `D:\\source\\llama.cpp-jet\\_test_output\\stage29-cache-modes-20260629-10\\`
- cuda_proof: GGML_CUDA:BOOL=ON (PASS)
- git_head: dbf593978b66a0d46a030f80c6e87345e08b3a04 (work-branch, origin/work-branch); git_dirty_count: 19
- nvidia_smi: 0,0 (RTX 5060 Ti x2, idle)

## Cycles actually executed

Cycle 1 cold-start legacy: NOT EXECUTED. Server started (model loaded 0.03.058.325, cache mode: legacy FIFO destructive hits, prompt cache size 512 MiB, listening on port 8900), `cold-start-cycle-1/legacy/metrics-before.txt` (23802 bytes, 328-line Prometheus snapshot) captured at Main L236 inside Invoke-CycleLeg, then driver fatally exited at L177 before metrics-after.txt was written or any chat completion was issued. Driver error message `Cannot find drive. A drive with the name '  D' does not exist.`

Cycle 1 cold-start hybrid: NOT EXECUTED. Driver died at L177 legacy leg before reaching L243 hybrid Invoke-CycleLeg.

Cycle 1 warm legacy: NOT EXECUTED (Main L244 for loop never entered).

Cycle 1 warm hybrid: NOT EXECUTED.

Total cycles of full test plan: 0 of planned 4.

## Setup (Phase 0)

- DryRun preflight PASS (exit 0): `DryRun preflight: {"ps_version_ok":true,"binary_exists":true,"fixture_exists":true,"port_free":true,"cuda_proof":"PASS","git_head":"dbf593978b66a0d46a030f80c6e87345e08b3a04","git_dirty":19,"status":"PASS"}`. Evidence: [dry-run.stdout.log](../../_test_output/stage29-cache-modes-20260629-10-dryrun/dry-run.stdout.log) 207 bytes; [dry-run.exit.txt](../../_test_output/stage29-cache-modes-20260629-10-dryrun/dry-run.exit.txt)=0.
- OutputEquivalenceOnly pre-check: SKIPPED this session. Driver [compare-legacy-vs-hybrid.ps1:115](../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L115) requires `equivalence-prompts.jsonl` to pre-exist; the canonical driver Main bundles Phase 0.5 (workload build) and Phase 1 (output equivalence) together, so the standalone pre-check is redundant with the main run. Prior session -09 classified this as `BLOCKED-equivalence-prompts-missing` for the same reason; not a bug.
- Run root created at [D:\\source\\llama.cpp-jet\\_test_output\\stage29-cache-modes-20260629-10\\](../../_test_output/stage29-cache-modes-20260629-10).
- Cold path created at `D:\\tmp\\cache-cold-stage29-10` (pre-created at session start to satisfy S29-IMPL-FIX-07 Edit 1 precondition).
- setup-env.json written with all fields verified.

## Next owner and next gate

Next owner: Developer (F-29-EXEC-17 follow-up driver fix). The S29-IMPL-FIX-07 cast+local-var approach was insufficient; the Developer needs to either strip whitespace from the hashtable value or bypass the hashtable round-trip entirely (Options A/B/C above). After Developer fix and Architect review, next gate is QA re-execution gate #11 with the canonical driver. After canonical-driver re-run PASS: Developer test-results review. After Developer review: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, no unicode icons, and stays under the 300-line durable-doc cap.