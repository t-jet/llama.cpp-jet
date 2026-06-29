# Stage 29 implementation re-execution handoff 2026-06-29 (QA -09)

Status: re-execution BLOCKED-driver-stopped-at-Phase2-CycleLeg-cold-start
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: QA (test execution session 2026-06-29, after S29-IMPL-FIX-01..06 verified; no Developer activity this gate)
Source reports: [../.test_reports/test-report-20260629-09-stage29-09.md](../.test_reports/test-report-20260629-09-stage29-09.md) (also mirrored to [../../_design_docs/.test_reports/test-report-20260629-09-stage29-09.md](../../_design_docs/.test_reports/test-report-20260629-09-stage29-09.md))
Trigger: Manager re-execution gate #9 after S29-IMPL-FIX-01..06 verified by Manager byte-level audit
Branch: work-branch
Source report path: `D:\source\llama.cpp-jet\_design_docs\.test_reports\test-report-20260629-09-stage29-09.md`
Run root: `D:\source\llama.cpp-jet\_test_output\stage29-cache-modes-20260629-09\` (also mirrored to `D:\source\llama.cpp-jet\._test_output\stage29-cache-modes-20260629-09\`)

## Verdict

BLOCKED against the Stage 29 test execution checklist at Phase 2 cold-start cycle 1. F-29-EXEC-17 RE-OPENED with byte-level evidence in this fresh session.

S29-IMPL-FIX-01..06 verified working on disk via byte-level audit (per test report):

- Driver L237-L238 invoke cold-start Invoke-CycleLeg (S29-IMPL-FIX-01)
- Driver L91 uses --cache-cold-path not --cache-cold-dir (S29-IMPL-FIX-02)
- Driver L90-L92 branch --cache-cold-* flags on $Mode -eq 'hybrid' (S29-IMPL-FIX-03)
- Driver L44 dot-sources agentic-prompt-generator.ps1 (S29-IMPL-FIX-04)
- Driver L147/L149 both pass -MaxIterations 200 (S29-IMPL-FIX-05 + 06)
- Wrapper L48 has 2k entry; L65 default is 2k; agentic L87 ValidateSet has 2k; driver L147/L149 both pass -SizeClass '2k' (S29-IMPL-FIX-06)

F-29-EXEC-17 RE-OPENED with byte-level evidence at `main.stdout.log` line 1 indices 17-19 = 0x20 0x20 0x20. Driver fatally exits at L174 Invoke-CycleLeg with `Cannot find drive. A drive with the name '  D' does not exist.` Exit 1.

NEW F-29-EXEC-19 (this session): driver does not pre-create `$CacheColdPath` before passing `--cache-cold-path` to llama-server. First main attempt failed at "hybrid failed /health within 30s" with server stderr `cold store: configure failed: root path does not exist`. Pre-created `D:\tmp\cache-cold-stage29-09` manually before re-launching driver; second attempt completed Phase 0 + Phase 0.5 + Phase 1 then died at F-29-EXEC-17.

Per-row classification (15 rows): PASS=2 (CC-01, RG-02 carry-forward), FAIL=0, SKIP=0, PARTIAL=1 (AG-03 cold-path-P1-only), BLOCKED=11 (CC-02..04, PR-01..03, AG-01/02/04), NOT-RUN=1 (RG-01).

Cycles actually executed: 0 of planned 4. Driver died before any Phase 2/3 leg evidence was produced under the canonical driver.

## Driver state at handoff

This session reproduced F-29-EXEC-17 exactly as prior session -07 reported:

- Byte-level signature at `main.stdout.log` line 1: `Workload built at   D:\...` (indices 17-19 = 0x20 0x20 0x20).
- Crash at [compare-legacy-vs-hybrid.ps1:174](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L174) `Get-Content -LiteralPath $WorkloadPath` with `Cannot find drive. A drive with the name '  D' does not exist.`
- Phase 1 output equivalence PASS confirmed (status=PASS mismatch=0; legacy-decoded.txt 4 bytes; hybrid-decoded.txt 4 bytes; diff.txt 0 bytes).
- Legacy server in cold-start-cycle-1 started successfully (`server.err.log` L29: `srv  llama_server: model loaded` at 0.03.024.837; L30: `server is listening on http://127.0.0.1:8900`), captured `cold-start-cycle-1/legacy/metrics-before.txt` (23802 bytes Prometheus snapshot), then driver died before any chat completion was issued.
- Phase 1 hybrid equivalence server wrote 6 cold-store files (511 MiB total) to `D:\tmp\cache-cold-stage29-09\1.cold` through `6.cold`.

## Suggested Developer fixes (one line each)

F-29-EXEC-17 at [compare-legacy-vs-hybrid.ps1:226-227](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L226-L227):

```powershell
# BEFORE
$wl = Invoke-Phase05WorkloadBuild
Write-Output ("Workload built at " + $wl.workload)
# (uses $wl.workload later at L237-241)

# AFTER (sibling string variables)
$wlPath = Join-Path $RunRoot 'workload.jsonl'
$eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'
Write-Output ("Workload built at " + $wlPath)
# then replace Invoke-CycleLeg -WorkloadPath $wl.workload with Invoke-CycleLeg -WorkloadPath $wlPath
```

F-29-EXEC-19 (cold-path pre-creation): add at top of `Invoke-Preflight` (after CUDA proof line) or in `Start-Stage29Server` before the Start-Process call:

```powershell
if ($Mode -eq 'hybrid' -and -not (Test-Path $CacheColdPath)) {
    New-Item -ItemType Directory -Force -Path $CacheColdPath | Out-Null
}
```

After Developer fix F-29-EXEC-17 and review, next QA execution gate is re-execution gate #10 with the canonical driver. After re-run PASS: Developer test-results review. After Developer review: Manager closure per D-CLOSURE-29-NN.

F-29-EXEC-13 (carry-forward): Release build lacks /Zi; OpenCppCoverage unusable. Affects TP-29-CV-01 only; non-blocking.

F-29-EXEC-14 (carry-forward): huggingface-hub==1.16.1 does not satisfy transformers constraint. Affects TP-29-RG-01 pytest sub-check only; non-blocking.

## Handoff index for prior blockers

- F-29-EXEC-01 (resolved S29-IMPL-FIX-02), F-29-EXEC-04 (resolved S29-IMPL-FIX-03), F-29-EXEC-08 (resolved S29-IMPL-FIX-04), F-29-EXEC-09 (resolved S29-IMPL-FIX-05), F-29-EXEC-12 (resolved S29-IMPL-FIX-06), F-29-EXEC-15 (resolved S29-IMPL-FIX-06). F-29-EXEC-17 RE-OPENED in this session. F-29-EXEC-19 NEW in this session.
