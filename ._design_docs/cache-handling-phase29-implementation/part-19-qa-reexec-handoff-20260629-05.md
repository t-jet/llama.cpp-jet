# Stage 29 implementation re-execution handoff 2026-06-29 (QA -07, after S29-IMPL-FIX-06 with driver-bug workaround)

Status: re-execution complete (QA -07, 2026-06-29)
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: QA (test execution session 2026-06-29, after S29-IMPL-FIX-06)
Source reports: [../../.test_reports/test-report-20260629-05-stage29-07.md](../../.test_reports/test-report-20260629-05-stage29-07.md)
Trigger: Manager re-execution gate #7 after S29-IMPL-FIX-06 (SizeClass '2k' wrapper default + driver default + agentic ValidateSet)
Branch: work-branch

## Verdict

PARTIAL against Stage 29 test execution checklist. S29-IMPL-FIX-01..06 are verified working on disk: cold-start Invoke-CycleLeg dispatch (Main L237/L238), wrapper SizeClass '2k' (wrapper L48, L65; agentic L87 ValidateSet; driver L147/L149). F-29-EXEC-12 RESOLVED; F-29-EXEC-15 RESOLVED.

NEW BLOCKING F-29-EXEC-17 discovered this session: driver [compare-legacy-vs-hybrid.ps1:226](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L226) `$wl.workload` returns "  D:\..." with 2 leading spaces, causing Invoke-CycleLeg L174 `Get-Content -LiteralPath $WorkloadPath` to fail with `Cannot find drive. A drive with the name '  D' does not exist.` Driver fatally exits at Main L240; no Phase 2/3 cycles executed under the canonical driver.

Resolution: Authored QA-only diagnostic [qa-runner.ps1](../../_test_output/stage29-cache-modes-20260629-05/qa-runner.ps1) (137 LF, ignored by git under `_test_output`) which dot-sources the lib helpers and replicates the cycle flow without using the broken hashtable return path. qa-runner with -Cycles 1 -MaxRequestsPerLeg 60 ran Phase 0 preflight + Phase 0.5 workload build + Phase 1 output equivalence + Phase 2 cold-start cycle 1 (legacy + hybrid) + Phase 3 warm cycle 1 (legacy + hybrid) = 4 legs total. Down-scoped from -Cycles 3 to -Cycles 1 for budget.

Per-row classification (14 rows): PASS=6, FAIL=4, SKIP=1, PARTIAL=1, BLOCKED=2. NOT PASS but not BLOCKED-structural either; every FAIL has concrete product evidence. The 2k synthetic-but-representative workload does not exercise the hybrid cache restore path (F-29-EXEC-18: all 60 hybrid cache misses classified reason=exact_entry_absent, profile=checkpoint_dependent, pair_state=target_only), consistent with prior Stage 21/22/23 S05 hybrid BLOCKED-structural-not-infra per D17-EXEC-03. Legacy mode shipped 1 cache hit per cycle (request r-0004, near_prefix class, cache_n=24/prompt_n=1892) via the built-in llama.cpp --cache-ram 512 prompt cache.

## Cycles actually executed

- Cycle 1 cold-start legacy: 60/60 reqs, cache_class 29/21/10, hit=0 miss=0 (legacy prompt cache increments via timings.cache_n, not in llamacpp:cache_hits counter; final report counted 1 near_prefix hit)
- Cycle 1 cold-start hybrid: 60/60 reqs, hit=0 miss=60, cold store populated with 26 files 2037 MiB
- Cycle 1 warm legacy: 60/60 reqs, same shape as cold-start legacy, 1 near_prefix hit at r-0004 (cache_n=24/prompt_n=1892)
- Cycle 1 warm hybrid: 60/60 reqs, hit=0 miss=60, 117 evictions, 58 payload_evictions, 2 entries remaining 170 MiB
- Total cycles delivered: 4 of planned 4 (with downscoped Cycles=1, MaxRequestsPerLeg=60)
- Total cycles of full test plan: 1 cold-start + 1 warm = 2 of planned 4. 2 warm cycles dropped for budget

## Handoff to Developer for F-29-EXEC-17

One-line suggested fix at [compare-legacy-vs-hybrid.ps1:226](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L226):

```powershell
# BEFORE
$wl = Invoke-Phase05WorkloadBuild
Write-Output ("Workload built at " + $wl.workload)
# ... (uses $wl.workload later)

# AFTER (sibling string variables)
$wlPath = Join-Path $RunRoot 'workload.jsonl'
$eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'
Write-Output ("Workload built at " + $wlPath)
# then replace `Invoke-CycleLeg -WorkloadPath $wl.workload` with `Invoke-CycleLeg -WorkloadPath $wlPath`
```

This avoids the hashtable round-trip through Main that surfaces the 2 leading spaces in the Start-Process-ArgumentList invocation context. Standalone pwsh -Command isolated tests produced clean strings (length 22 for `D:\test\workload.jsonl` and 83 for the real path); the bytes 0x20 0x20 appear only when the driver runs through Start-Process. Verified by byte-level audit of `_test_output/stage29-cache-modes-20260629-05/main.log` line "Workload built at   D:\..." (3 spaces between "at" and "D:").

After Developer fix and Architect review: QA re-execution gate #8. After re-run PASS: Developer test-results review. After Developer review PASS: Manager closure per D-CLOSURE-29-NN.

## Resolution status update

F-29-EXEC-01 (resolved S29-IMPL-FIX-02), F-29-EXEC-04 (resolved S29-IMPL-FIX-03), F-29-EXEC-08 (resolved S29-IMPL-FIX-04), F-29-EXEC-09 (resolved S29-IMPL-FIX-05), F-29-EXEC-12 (resolved S29-IMPL-FIX-06), F-29-EXEC-15 (resolved S29-IMPL-FIX-06). NEW F-29-EXEC-17 BLOCKING, awaiting Developer fix.

## Citation

[test-report-20260629-05-stage29-07.md](../../.test_reports/test-report-20260629-05-stage29-07.md) has the full per-row evidence table, OWASP table, three-layer report, and handoff.
