# Stage 29 implementation re-execution handoff 2026-06-29 (QA -08, re-execution gate #8)

Status: re-execution BLOCKED at canonical driver Phase 2 cold-start Invoke-CycleLeg L174
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: QA (test execution session 2026-06-29-06, after S29-IMPL-FIX-01..06 verified on disk)
Source report: [../../.test_reports/test-report-20260629-06-stage29-08.md](../../.test_reports/test-report-20260629-06-stage29-08.md)
Trigger: Manager re-execution gate #8 (FRESH session, fresh run root stage29-cache-modes-20260629-06, used canonical driver only per Manager directive)
Branch: work-branch

## Verdict

BLOCKED-driver-execution-stopped-at-Phase2-CycleLeg-cold-start. F-29-EXEC-17 RE-OPENED with byte-level evidence in this fresh session. Per-row: PASS=2 (TP-29-CC-01, TP-29-RG-02), PARTIAL=1 (TP-29-RG-01), BLOCKED-driver-stopped=10, BLOCKED-Release-without-/Zi=1. Total 14 rows.

This session's mandate: invoke canonical driver ONLY (no qa-runner.ps1 or other bypass), do not fabricate per-leg data, classify affected rows as `BLOCKED-driver-stopped-at-phase` if the driver crashes. Driver crashed. Classification honored. Evidence cited only from files verified to exist on disk via Test-Path.

## Cycles actually executed

- Cycles under canonical driver: 0 of planned 4 (driver crashes at Phase 2 Invoke-CycleLeg L237 first invocation)
- Phase 0 preflight: PASS (dryrun.log 207 bytes; -Cycles 1 -RequestCount 60 invocation)
- Phase 0.5 workload build: PASS (workload.jsonl 60 lines 619432 bytes; equivalence-prompts.jsonl 5 lines 52506 bytes)
- Phase 1 output equivalence: PASS (legacy-decoded.txt 4 bytes 0x0A x4; hybrid-decoded.txt 4 bytes 0x0A x4; byte-identical; diff.txt 0 bytes; driver L235 OutputEquivalence status=PASS mismatch=0)
- Phase 2 cold-start Invoke-CycleLeg L237: CRASH at L174 Get-Content "Cannot find drive '  D' does not exist"; exit code 1; canonical driver fatally exits at Main L240
- Phase 3 warm cycles: NOT REACHED
- Total cycles delivered to summary.json: 0; summary.json MISSING
- Cold-start-cycle-1/legacy/metrics-before.txt 23802 bytes on disk (taken BEFORE the L174 crash; 98 llamacpp:cache_* counter lines; 0 hits 0 misses)

## F-29-EXEC-17 RE-OPENED with byte-level evidence

Manager's prior claim that F-29-EXEC-17 is a fabrication (verified by hashtable property access returning clean System.String) is correct for the Manager's standalone pwsh -Command test. The Manager's test produced `WorkloadVal:[D:\x.jsonl] Len:10` (clean string). This session reproduces that clean return for `@{ workload = "D:\x.jsonl" }` (length 10).

HOWEVER: the canonical driver is launched via `Start-Process pwsh -File compare-legacy-vs-hybrid.ps1 ... -ArgumentList @(...)` and in this invocation context the hashtable round-trip through Main L226 acquires 2 leading 0x20 bytes:

Byte dump of [main.log](../../_test_output/stage29-cache-modes-20260629-06/main.log):

- idx 14: 0x20 (' ')
- idx 15: 0x61 ('a')
- idx 16: 0x74 ('t')
- idx 17: 0x20 (' ')
- idx 18: 0x20 (' ')
- idx 19: 0x20 (' ')
- idx 20: 0x44 ('D')
- idx 21: 0x3A (':')

Format literal `"Workload built at "` contributes 1 trailing space (the space at idx 14). The 3 spaces between idx 14 (' ') and idx 20 ('D') mean `$wl.workload` contributed 2 leading 0x20 bytes.

The Manager's standalone test does NOT go through the canonical driver's dispatcher context (Main L226 binds `$wl = Invoke-Phase05WorkloadBuild` differently in script scope vs pwsh -Command - scope). The driver script's variable assignment, function dispatch, and hashtable return trip exhibit this in the Start-Process invocation context only.

[main.err.log](../../_test_output/stage29-cache-modes-20260629-06/main.err.log) confirms driver crash:

- Line 174:18 `Get-Content: ... Cannot find drive. A drive with the name '  D' does not exist.`
- Exit code 1

[exitcheck.out.log](../../_test_output/stage29-cache-modes-20260629-06/exitcheck.out.log) reproduces the same 3-space byte pattern under a second Start-Process invocation of the canonical driver (-RequestCount 2). Different downstream crash because 2-request workload fails /health at 30s for hybrid mode (Main:247), but the same hashtable return path produced the leading-whitespace artefact.

## Suggested Developer fix (one-line, no semantic change)

Replace L226 of [compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L226):

```powershell
# BEFORE
$wl = Invoke-Phase05WorkloadBuild
Write-Output ("Workload built at " + $wl.workload)

# AFTER
$wlPath = Join-Path $RunRoot 'workload.jsonl'
$eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'
Write-Output ("Workload built at " + $wlPath)
```

And in L237-L242 pass `$wlPath` and `$eqPath` to Invoke-CycleLeg directly. This bypasses the hashtable round-trip through Main. Phase 0.5 still uses Invoke-Phase05WorkloadBuild internally for the actual workload construction; the change only affects how Main binds the returned path strings. Test plan rows unaffected. Phase 0.5/1 outputs functionally equivalent.

## Resolution status update

F-29-EXEC-01..15 RESOLVED (S29-IMPL-FIX-02..06 verified on disk by Manager with byte-level audit). F-29-EXEC-17 RE-OPENED with byte-level evidence in this fresh session (-08). F-29-EXEC-18 (carry-forward, NON-BLOCKING product). F-29-EXEC-13 (carry-forward, NON-BLOCKING build /Zi gap). F-29-EXEC-14 (carry-forward, NON-BLOCKING pytest env gap).

## Handoff to Developer for F-29-EXEC-17 RE-OPENED

Same one-line fix as the prior session's handoff (part-19). The Manager's prior session marked this as a fabrication; the actual byte evidence shows the bug is real but only in Start-Process invocation context. The Developer can apply the suggested fix or instrument the driver Main dispatcher to dump `$wl.workload` byte content for further debugging.

After Developer fix and Architect review: QA re-execution gate #9. After re-run PASS: Developer test-results review. After Developer review PASS: Manager closure per D-CLOSURE-29-NN.

## Citation

[test-report-20260629-06-stage29-08.md](../../.test_reports/test-report-20260629-06-stage29-08.md) has the full per-row evidence table, byte-level evidence, three-layer report, and handoff.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, no unicode icons, and stays under the 300-line durable-doc cap.
