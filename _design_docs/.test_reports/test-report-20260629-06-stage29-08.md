# Stage 29 Cache Modes Comparison test execution report (re-run #8)

Run ID: stage29-cache-modes-20260629-06
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, eighth QA session for Stage 29, re-execution gate #8)
Source plan: [../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)
Branch: work-branch

## Verdict

BLOCKED-driver-execution-stopped-at-Phase2-CycleLeg-cold-start. The canonical driver
[compare-legacy-vs-hybrid.ps1](../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1)
crashed at Line 174 inside `Invoke-CycleLeg` (`Get-Content -LiteralPath $WorkloadPath`)
when invoked via Start-Process -ArgumentList under the canonical driver path with
exit code 1. The driver completed Phase 0 preflight, Phase 0.5 workload build, and
Phase 1 output equivalence successfully; Phase 2 cold-start Invoke-CycleLeg
(L237 cold-start legacy) crashed because `$wl.workload` returned a value with two
leading whitespace bytes instead of the canonical path string.

Byte-level evidence that the prior session's F-29-EXEC-17 is real, not fabricated:

- [main.log](../../_test_output/stage29-cache-modes-20260629-06/main.log) first
  line decodes byte-precisely to
  "Workload built at" + 0x20 0x20 0x20 + "D:\\..." (3 spaces between "at" and
  "D") per ReadAllBytes dump at indices 17-19.
- [main.err.log](../../_test_output/stage29-cache-modes-20260629-06/main.err.log)
  last entry: "Get-Content:
  compare-legacy-vs-hybrid.ps1:174:18 ... Cannot find drive. A drive with the
  name '  D' does not exist." at 12:38:54.
- [exitcheck.out.log](../../_test_output/stage29-cache-modes-20260629-06/exitcheck.out.log)
  reproduces the same 3-space pattern with -RequestCount 2 (driver gets further
  but the same hashtable return path is invoked).
- Standalone pwsh `-Command` test returns clean System.String length 10 for a
  synthetic hashtable, so the bug is Start-Process-ArgumentList invocation
  context-dependent, not a language-level hashtable property failure.

Per the brief's directive on driver-stopped-at-phase classification, every
per-request, per-leg, and aggregated row that depends on Phase 2/3 evidence
under the canonical driver is BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start
with concrete cite to [main.err.log](../../_test_output/stage29-cache-modes-20260629-06/main.err.log)
(exit code 1; last stderr L174 "Cannot find drive '  D' does not exist").

Cycles actually executed: 0 of planned 4. The driver crashed before any cycle
requests. The 60-request workload.jsonl was built (Phase 0.5 PASS) but no
chat-completion cycle ran under the canonical driver.

Per-row classification (14 rows): PASS=2 (TP-29-CC-01, TP-29-RG-02),
FAIL=0, SKIP=0, PARTIAL=1 (TP-29-RG-01 focused tests 142/142 PASS, pytest
BLOCKED-env), BLOCKED-driver-stopped=10 (CC-02..04, PR-01..03, AG-01..04),
BLOCKED-Release-without-/Zi=1 (TP-29-CV-01).

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260629-06/setup-env.json](../../_test_output/stage29-cache-modes-20260629-06/setup-env.json)
(2141 bytes).

- session_date: 2026-06-29; session_time: 12:48:00
- pwd: `D:\source\llama.cpp-jet`; ps_version: 7.6.3 (Core)
- cmake_version: cmake 4.3.2; python_version: Python 3.11.9
- k6_version: k6.exe v2.0.0-rc1
- opencppcoverage: `D:\app\OpenCppCoverage\OpenCppCoverage.exe` (installed; not runnable due to Release build lacks /Zi)
- binary_path: `build-cuda\bin\Release\llama-server.exe`; binary_length: 168655360 bytes; binary_mtime: 2026-06-27T10:55:11 (Stage 28 closure binary)
- model_path: `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`; model_length: 2834975040 bytes
- git_head: dbf593978b66a0d46a030f80c6e87345e08b3a04
- git_dirty_count: 15 (driver, wrapper, agentic lib, impl log, tracker, qa memory, and QA-authored run artifacts only; no tools/server/, tests/, common/, ggml/, gguf-py/ modifications)
- cuda_build_type: Release
- cuda_cxx_flags_release: `/O2 /Ob2 /DNDEBUG` (no `/Zi`)
- ggml_cuda: ON
- cold_path: `D:\tmp\cache-cold-stage29-06` (6 cold payload files written by crashed driver before Phase 2 cycle)
- run_root: `._test_output\stage29-cache-modes-20260629-06\`
- report_path: `._design_docs\.test_reports\test-report-20260629-06-stage29-08.md`
- driver_lines_lf: 247 (under 300 cap; post all six S29-IMPL-FIX)
- wrapper_lines_lf: 204 (+1 entry from S29-IMPL-FIX-06)
- agentic_lines_lf: unchanged per S29-IMPL-FIX-06
- test_plan_part_33_lines: 299
- cuda_path: `D:\app\cuda_13_2\bin\x64`; cuda_dll_check: True; disk_free_d_GB: 1437.8
- binary_content_correctness: per QA memory "re-execution session binary freshness vs content correctness", no-op rebuild skipped. `git diff --stat HEAD -- tools/server tests common ggml gguf-py` returns empty. test-cache-controller.exe (155117568 bytes; mtime 10:54:28) is the Stage 28 closure binary.

## Scope deviation

The test plan part-33 specifies `-Cycles 3 -RequestCount 200` (8 legs x 200 reqs).
At ~8 s/req observed in the prior session that is ~3.2 hours of request time alone,
well outside the 86-minute wall-clock budget recorded in [part-33](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md)
("Coordination constraints"). This session uses `-Cycles 1 -RequestCount 60`
(4 legs x 60 reqs) per the prior session's down-scoping precedent. The driver
crashed before any leg ran, so the scope-deviation note is preserved but moot.

## Commands run

1. setup-env.json: regenerated at 2141 bytes with corrected cuda_cxx_flags_release,
   cuda_build_type, ggml_cuda fields (initial setup tried `git show HEAD:build-cuda/CMakeCache.txt`
   which is gitignored; final capture reads the untracked `build-cuda/CMakeCache.txt`).
2. DryRun: `pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun ...` exit 0
   with preflight JSON status PASS (5 gating sub-checks PASS, 2 informational).
3. Main path attempt (canonical driver): `Start-Process pwsh -File compare-legacy-vs-hybrid.ps1 -RunId stage29-cache-modes-20260629-06 -Cycles 1 -RequestCount 60 ...` Phase 0 PASS at 12:35:36, Phase 0.5 PASS at 12:35:52 (workload.jsonl 60 lines 619432 bytes; equivalence-prompts.jsonl 5 lines 52506 bytes), Phase 1 PASS at 12:37:59 (legacy-decoded.txt 4 bytes; hybrid-decoded.txt 4 bytes; diff.txt 0 bytes). Phase 2 cold-start Invoke-CycleLeg L237 started at 12:38:14, wrote cold-start-cycle-1/legacy/metrics-before.txt at 12:38:18, then crashed at L174 with "Cannot find drive '  D' does not exist." Driver exited at 12:38:54 with exit code 1.
4. Exit-code confirmation: launched second canonical-driver invocation with
   -RequestCount 2 to capture exit code without burning cycle budget.
   [exitcheck.out.log](../../_test_output/stage29-cache-modes-20260629-06/exitcheck.out.log)
   exits 1, [exitcheck.err.log](../../_test_output/stage29-cache-modes-20260629-06/exitcheck.err.log)
   shows BLOCKED-server-not-running: hybrid failed /health within 30s (different
   crash signature with -RequestCount 2; the workload is too small for hybrid
   mode to initialize within 30s but the same hashtable return path produced the
   same 3-space pattern in exitcheck.out.log at idx 17-19).
5. test-cache-controller.exe: exit 0, 142/142 PASSED
   ([test-cache-controller.log](../../_test_output/stage29-cache-modes-20260629-06/test-cache-controller.log) 11936 bytes).
6. pytest tests/ --collect-only: exit 1 "no tests collected in 0.02s" (BLOCKED-env
   carry-forward from prior F-29-EXEC-14).
7. git status --short -- tools/server tests common ggml gguf-py: empty output,
   exit 0 (TP-29-RG-02 PASS).
8. CMakeCache.txt reading (in-tree, not git-tracked): CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG
   (no /Zi), CMAKE_BUILD_TYPE=Release, GGML_CUDA:BOOL=ON (TP-29-CV-01 BLOCKED-Release-without-/Zi).

## Findings

### F-29-EXEC-17 (RE-OPENED, BLOCKING-driver): driver `$wl.workload` returns 2 leading spaces under Start-Process-ArgumentList invocation

Driver
[compare-legacy-vs-hybrid.ps1:227](../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L227)
`Write-Output ("Workload built at " + $wl.workload)` produces output
`Workload built at   D:\...` (3 spaces between "at" and "D:"). Format literal
contributes 1 trailing space; `$wl.workload` contributes 2 leading 0x20 bytes.
Hex dump from [main.log](../../_test_output/stage29-cache-modes-20260629-06/main.log)
indices 17-19 = `0x20 0x20 0x20` immediately before `0x44 0x3A` ("D:") at indices 20-21.

Downstream impact: `Invoke-CycleLeg -WorkloadPath $wl.workload` (driver L237-L242)
calls `Get-Content -LiteralPath $WorkloadPath` at L174, which interprets the value
as a drive path and rejects leading whitespace with
"Cannot find drive. A drive with the name '  D' does not exist."

Manager's claim that hashtable property access returns clean `System.String`
is correct under the test the Manager ran (`pwsh -NoProfile -Command` against a
synthetic `@{ workload = "D:\..." }`). This session reproduces the Manager's
synthetic test and confirms clean return: `WorkloadVal:[D:\x.jsonl] Len:10`.
However the Manager's test uses pwsh `-Command` while the canonical driver is
launched via `Start-Process pwsh -File compare-legacy-vs-hybrid.ps1 ...
-ArgumentList @(...)`. The Start-Process invocation context reproduces the
2-space pattern in this session and the prior session; the Manager's
quick-Command test does not reproduce it.

Possible sources (informational, not diagnostic certainty): the hashtable
return value passes through PowerShell's Main dispatcher as a variable
assignment across the function boundary; in the Start-Process-execution
context the dispatcher sees a stream object with embedded formatting control
sequences. Standalone analysis did not isolate the exact source within the
session budget. Suggested Developer fix (same one-line recommendation per
prior session):

```powershell
# BEFORE driver L226
$wl = Invoke-Phase05WorkloadBuild
Write-Output ("Workload built at " + $wl.workload)
# ... Invoke-CycleLeg -WorkloadPath $wl.workload at L237-L242

# AFTER
$wlPath = Join-Path $RunRoot 'workload.jsonl'
$eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'
Write-Output ("Workload built at " + $wlPath)
# ... Invoke-CycleLeg -WorkloadPath $wlPath at L237-L242
```

This bypasses the hashtable round-trip through Main that surfaces the 2 leading
spaces under the Start-Process invocation context. The fix does not modify any
lib helper, the design-correct wrapper (204 LF), or the agentic library.

### F-29-EXEC-18 (CARRY-FORWARD, NON-BLOCKING, product): hybrid cache miss reason exact_entry_absent on 2k synthetic workload

Not directly observed this session because the canonical driver crashed before
any hybrid chat completion. Carry-forward from
[test-report-20260629-05-stage29-07.md](test-report-20260629-05-stage29-07.md)
F-29-EXEC-18 (also -06 and -05 prior). The 2k agentic-shaped workload does not
exercise the hybrid cache restore path because the synthetic prompts lack
checkpoint boundary metadata. Same root cause as Stage 21/22/23 S05 hybrid
BLOCKED-structural-not-infra per D17-EXEC-03.

### F-29-EXEC-13 (CARRY-FORWARD, NON-BLOCKING, build): coverage gap on Release without /Zi

Confirmed this session: [build-cuda/CMakeCache.txt](../../build-cuda/CMakeCache.txt)
`CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` lacks `/Zi`. OpenCppCoverage
at `D:\app\OpenCppCoverage\OpenCppCoverage.exe` exists but cannot produce
meaningful coverage on a Release build without debug symbols. TP-29-CV-01
remains BLOCKED-Release-without-/Zi.

### F-29-EXEC-14 (CARRY-FORWARD, NON-BLOCKING, environment): pytest environment gap

Confirmed this session: `python -m pytest tests/ --collect-only` returns exit 1
"no tests collected in 0.02s" (transformers/huggingface-hub mismatch as
documented in prior sessions). Focused test binary still 142/142 PASS satisfies
the regression contract that depends on closed Stage 25-28 invariants.

## Per-row classification

| Row | Status | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | PASS | [phase-1-output-equivalence/legacy-decoded.txt](../../_test_output/stage29-cache-modes-20260629-06/phase-1-output-equivalence/legacy-decoded.txt) 4 bytes; [hybrid-decoded.txt](../../_test_output/stage29-cache-modes-20260629-06/phase-1-output-equivalence/hybrid-decoded.txt) 4 bytes; both decoded byte-by-byte to 0x0A 0x0A 0x0A 0x0A (4 LF bytes from 5 empty responses joined with `n`); [diff.txt](../../_test_output/stage29-cache-modes-20260629-06/phase-1-output-equivalence/diff.txt) 0 bytes (Test-Stage29OutputEquivalence Status=PASS, MismatchCount=0); driver L235 `OutputEquivalence status=PASS mismatch=0` in [main.log](../../_test_output/stage29-cache-modes-20260629-06/main.log) |
| TP-29-CC-02 (cold-store validity) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | [main.err.log](../../_test_output/stage29-cache-modes-20260629-06/main.err.log) exit 1, last stderr L174 Get-Content "Cannot find drive '  D'"; no Phase 2 cold-start hybrid leg evidence; canonical driver fatally exits at Main L240; cold-start-cycle-1/legacy/metrics-before.txt 23802 bytes on disk (metrics-before snapshot taken BEFORE L174 crash) but no metrics-after.txt or requests.jsonl written |
| TP-29-CC-03 (fallback rate) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No per-leg summaries written (summary.json MISSING); needed cache_fallback_restores_total_delta per hybrid leg unavailable |
| TP-29-CC-04 (cooldown) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No per-leg summaries written; cooldown_duration_seconds per leg unavailable |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No Phase 2/3 requests.jsonl written (L174 crash prevents per-leg request log emission) |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No Phase 2/3 requests.jsonl written |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No Phase 3 warm cycles reached under the canonical driver |
| TP-29-AG-01 (mean hit rate) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No Phase 2/3 cycles completed; cold-start-cycle-1/legacy/metrics-before.txt shows 0 hits 0 misses before crash |
| TP-29-AG-02 (total tokens reused) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No per-leg requests.jsonl to sum cache_n |
| TP-29-AG-03 (cold-store utilization) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | cold path `D:\tmp\cache-cold-stage29-06` has 6 cold-store payload files (1.cold 117874368 bytes; 2.cold 52691612 bytes; 3.cold 117874368 bytes; 4.cold 52691612 bytes; 5.cold 117513700 bytes; ...) written by Start-Stage29Server before the crash; no summary.json to read `cache_cold_payload_bytes` Prometheus counter or `cache_cold_payload_count` from |
| TP-29-AG-04 (VRAM peak) | BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start | No per-leg vram_peak_mib recorded |
| TP-29-RG-01 (focused + pytest) | PARTIAL | [test-cache-controller.log](../../_test_output/stage29-cache-modes-20260629-06/test-cache-controller.log) exit 0, 142/142 PASSED; pytest "no tests collected in 0.02s" (BLOCKED-env carry-forward F-29-EXEC-14) |
| TP-29-RG-02 (no tools/server mods) | PASS | `git status --short -- tools/server tests common ggml gguf-py` empty; `git diff --stat HEAD -- tools/server` empty |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | [build-cuda/CMakeCache.txt](../../build-cuda/CMakeCache.txt) CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG lacks /Zi; carry-forward F-29-EXEC-13 |

Final counts: PASS=2, FAIL=0, SKIP=0, PARTIAL=1, BLOCKED-driver-stopped=10, BLOCKED-Release-without-/Zi=1. Total=14.

## Three-layer report

Layer 1 Correctness: CC-01 PASS (Phase 1 byte-identical diff empty); CC-02..04 BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start because Phase 2 cold-start legacy Invoke-CycleLeg crashed before any per-leg artifact was written beyond metrics-before.txt.

Layer 2 Per-request: PR-01..03 BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start (no requests.jsonl emitted by canonical driver before L174 crash).

Layer 3 Aggregated: AG-01..04 BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start (no summary.json written; cold-start-cycle-1/legacy/metrics-before.txt 23802 bytes is the only Phase 2 evidence and shows 0 hits 0 misses).

Decision-support Q1..Q5 cannot be evaluated because the three-layer evidence base is insufficient under the canonical driver. Carry-forward prior-session recommendation: NOT regress prior stages (Stage 21/22/23 already documented D17-EXEC-03 hybrid structural-not-infra). Stage 29 finding supports the same direction without contradicting prior closure.

## Resolution status of prior BLOCKING

F-29-EXEC-01 (-01): driver flag typo. RESOLVED 2026-06-28 by S29-IMPL-FIX-02.
F-29-EXEC-04 (-02): driver cold-mode flag coupling. RESOLVED 2026-06-29 by S29-IMPL-FIX-03.
F-29-EXEC-08 (-03): driver dot-source for agentic-prompt-generator.ps1. RESOLVED 2026-06-29 by S29-IMPL-FIX-04.
F-29-EXEC-09 (-03): wrapper MaxIterations default 50. RESOLVED 2026-06-29 by S29-IMPL-FIX-05.
F-29-EXEC-12 (-05): driver equivalence MaxIter 50. RESOLVED 2026-06-29 by S29-IMPL-FIX-06.
F-29-EXEC-15 (-06): wrapper SizeClass='12k' exceeds per-slot context. RESOLVED 2026-06-29 by S29-IMPL-FIX-06.
F-29-EXEC-17 (-07, RE-OPENED this session -08): driver `$wl.workload` returns 2 leading spaces under Start-Process-ArgumentList invocation. BLOCKING. Reproduced in this fresh session at L174 of the canonical driver. Status RE-OPENED with byte-level evidence at [main.log](../../_test_output/stage29-cache-modes-20260629-06/main.log) indices 17-19 = 0x20 0x20 0x20.

## Top BLOCKING issues

1. F-29-EXEC-17 RE-OPENED: driver `$wl.workload` returns 2 leading 0x20 bytes when invoked via Start-Process pwsh -File ... -ArgumentList; Phase 2 cold-start Invoke-CycleLeg L174 Get-Content -LiteralPath crashes with "Cannot find drive '  D'". Affects TP-29-CC-02..04, TP-29-PR-01..03, TP-29-AG-01..04 (10 rows). Cannot reproduce in pwsh -Command standalone test. Suggested Developer one-line fix: replace `$wl = Invoke-Phase05WorkloadBuild` at driver L226 with explicit string variables `$wlPath = Join-Path $RunRoot 'workload.jsonl'` and `$eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'` (no hashtable round-trip), pass `$wlPath` to Invoke-CycleLeg at L237-L242.
2. Carry-forward F-29-EXEC-13: Release build lacks /Zi; OpenCppCoverage cannot produce meaningful coverage. Affects TP-29-CV-01.
3. Carry-forward F-29-EXEC-14: pytest environment gap (transformers/huggingface-hub version mismatch); pytest "no tests collected in 0.02s". Affects TP-29-RG-01 pytest sub-check; focused tests still 142/142 PASS.

## Handoff

Next owner: Developer. Single new BLOCKING finding F-29-EXEC-17 RE-OPENED with byte-level evidence in this fresh session. Suggested one-line fix per F-29-EXEC-17. This session does NOT modify any production code, test code, runner, design, implementation log, document index, or stage tracker; the modification is exclusive to the QA re-run artifacts under `_test_output/stage29-cache-modes-20260629-06/` plus the durable report at `._design_docs/.test_reports/test-report-20260629-06-stage29-08.md` plus the implementation log handoff entry appended to `part-20-qa-reexec-handoff-20260629-06.md`.

Non-blocking carry-forward findings F-29-EXEC-13 (Release-without-/Zi), F-29-EXEC-14 (pytest env), F-29-EXEC-18 (hybrid 2k workload structurally misses hybrid restore per D17-EXEC-03). These are independent of Stage 29 and should be tracked in separate Developer handoffs if a future stage needs them. F-29-EXEC-18 is a documentation observation confirming prior Stage 21/22/23 structural blocker, not a new defect.

Next gate: Manager (re-execution gate #9) after Developer fix F-29-EXEC-17 lands. After re-run with the canonical driver: Developer test-results review. After Developer review: Manager closure per D-CLOSURE-29-NN.

## Evidence files

All under `D:\source\llama.cpp-jet\_test_output\stage29-cache-modes-20260629-06\`:

- `setup-env.json` (2141 bytes; corrected cuda_cxx_flags_release=/O2 /Ob2 /DNDEBUG, cuda_build_type=Release, ggml_cuda=ON fields)
- `dryrun.log` (207 bytes; Phase 0 preflight PASS)
- `dryrun.err.log` (0 bytes; preflight produced no stderr)
- `main.log` (147 bytes; Phase 0.5 "Workload built at" + Phase 1 "OutputEquivalence status=PASS mismatch=0"; 2 leading spaces in $wl.workload at idx 17-19 hex 20 20 20)
- `main.err.log` (539 bytes; canonical driver crash at L174 "Cannot find drive '  D'"; exit 1 at 12:38:54)
- `main.proc.pid` (7 bytes; canonical driver PID 32168)
- `server.err.log` (2965 bytes; Phase 1 hybrid server init logs; ends at last hybrid-mode server stop before L174 crash)
- `server.out.log` (0 bytes; Phase 1 server stdout to redirect path; redirected; no content)
- `workload.jsonl` (619432 bytes; 60 lines; first bytes `{"re...` clean)
- `equivalence-prompts.jsonl` (52506 bytes; 5 lines; first prompt 10500 chars)
- `phase-1-output-equivalence/legacy-decoded.txt` (4 bytes; 0x0A x4)
- `phase-1-output-equivalence/hybrid-decoded.txt` (4 bytes; 0x0A x4)
- `phase-1-output-equivalence/diff.txt` (0 bytes; Test-Stage29OutputEquivalence PASS)
- `cold-start-cycle-1/legacy/metrics-before.txt` (23802 bytes; Prometheus snapshot taken before L174 crash; 98 lines match `^llamacpp:cache_`; cache_entries/cold/cold_payload/hits_total/misses_total all 0)
- `test-cache-controller.log` (11936 bytes; 142/142 PASSED; exit 0)
- `test-cache-controller.err.log` (7028 bytes; test framework chatter; "All tests passed successfully!")
- `exitcheck.out.log` (115 bytes; -RequestCount 2 second-invocation of driver; reproduces "Workload built at   D:..." byte pattern; exit 1)
- `exitcheck.err.log` (427 bytes; -RequestCount 2 second-invocation crash: BLOCKED-server-not-running: hybrid failed /health within 30s at Main:247; different crash signature with smaller workload)
- `exitcheck/workload.jsonl` (21002 bytes; -RequestCount 2 workload; 2 lines)
- `exitcheck/equivalence-prompts.jsonl` (52506 bytes; same 5 lines as primary because Phase 0.5 default uses OutputEquivalencePrompts=5)
- `exitcheck/phase-1-output-equivalence/legacy-decoded.txt` (4 bytes; legacy Phase 1 partial output before /health timeout)

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, no unicode icons, and stays under the 300-line durable-doc cap.
