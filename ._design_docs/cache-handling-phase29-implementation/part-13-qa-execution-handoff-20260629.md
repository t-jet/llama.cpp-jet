# Stage 29 QA execution handoff: driver dot-source gap

Status: QA execution PASS=1 PARTIAL=1 BLOCKED=12 of 14 rows on
2026-06-29. S29-IMPL-FIX-03 verified WORKING; NEW BLOCKING driver
dot-source defect discovered at Phase 0.5. One-line Developer fix
required.
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison)
Owner: QA session (this handoff); Developer (next, for one-line fix)
Source execution report: [../../../_design_docs/.test_reports/test-report-20260629-01-stage29-03.md](../../../_design_docs/.test_reports/test-report-20260629-01-stage29-03.md)

## Background

QA session 2026-06-29-01 (third QA session for Stage 29) executed
the Stage 29 test plan in
[../../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md)
post Manager test-plan gate PASS (2026-06-28) and post
S29-IMPL-FIX-03 implementation-fix gate PASS (2026-06-29).
Setup-env captured at
[../../../_test_output/stage29-cache-modes-20260629-01/setup-env.json](../../../_test_output/stage29-cache-modes-20260629-01/setup-env.json).
Driver
[../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1)
invoked under `-DryRun`, `-OutputEquivalenceOnly`, and full path.

## S29-IMPL-FIX-03 verified working (F-29-EXEC-09)

The cold-mode flag coupling defect from the prior session
(F-29-EXEC-04) is fully resolved. server.err.log from this session
shows a complete healthy legacy boot with no cold-path rejection:

- `I srv  llama_server: model loaded`
- `I srv  llama_server: server is listening on http://127.0.0.1:8900`
- `I srv  update_slots: all slots are idle`

The driver S29-IMPL-FIX-03 fix (cold-path flags gated on
`$Mode -eq 'hybrid'` at driver L86-93) is correctly applied: the
legacy boot succeeds without the
`--cache-cold-max-mib requires --cache-mode hybrid` rejection. Driver
L86-93 byte-verified at session start; on-disk LF count = 246.

## BLOCKING finding F-29-EXEC-08

Driver
[compare-legacy-vs-hybrid.ps1:42-46](../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L42)
dots five lib helpers but does NOT dot-source
[lib/agentic-prompt-generator.ps1](../../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1).
The Stage 29 wrapper
[lib/compare-legacy-vs-hybrid-workload.ps1:106](../../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L106)
and L142 calls `New-AgenticChatPrompt`, which is defined only in
[agentic-prompt-generator.ps1:82](../../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L82).
The wrapper's own header at L18-19 documents the expected dot-source
order (`agentic-prompt-generator.ps1` first, then the wrapper), but
the driver does not honour it.

When the driver reaches Phase 0.5 workload build at
[compare-legacy-vs-hybrid.ps1:146](../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L146),
`New-ComparisonWorkload` (defined in the wrapper) tries to call
`New-AgenticChatPrompt`, PowerShell cannot resolve the function name,
the inner try-block fails, the server is correctly stopped in the
finally block (port 8900 free after the run), and the exception
propagates with `The term 'New-AgenticChatPrompt' is not recognized
as a name of a cmdlet, function, script file, or executable program`.
Full exception trace at
[main.err.log](../../../_test_output/stage29-cache-modes-20260629-01/main.err.log).
Driver exit code: 1.

This is a NEW defect: the prior QA session (-02) never exercised this
path because the cold-mode flag coupling bug short-circuited the run
at server boot before Phase 0.5 ever started. The wrapper has called
`New-AgenticChatPrompt` since its design-correction authoring (per
the wrapper header), so the bug has been latent since the wrapper
existed but was hidden behind the prior BLOCKING failures.

## One-line Developer fix

Insert a new dot-source line at driver L42 (before the wrapper
dot-source) so `agentic-prompt-generator.ps1` loads first:

```text
. (Join-Path $libDir 'agentic-prompt-generator.ps1')
```

This restores the wrapper's documented dot-source order from
[compare-legacy-vs-hybrid-workload.ps1:18-19](../../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L18).
After the fix, the driver's `Invoke-Phase05WorkloadBuild` can
resolve `New-AgenticChatPrompt` and proceed to Phase 0.5 success.
No other code or test changes required. No design changes.

## Per-row outcome (14 rows)

| Row | Status |
| --- | --- |
| TP-29-CC-01..04 | BLOCKED-driver-dot-source |
| TP-29-PR-01..03 | BLOCKED-driver-dot-source |
| TP-29-AG-01..04 | BLOCKED-driver-dot-source |
| TP-29-RG-01 | PARTIAL (142/142 focused tests PASS; pytest BLOCKED-env) |
| TP-29-RG-02 | PASS (zero tools/server/ modifications) |
| TP-29-CV-01 | BLOCKED-Release-without-/Zi |

Final counts: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12. Of 12 BLOCKED:
11 driver-dot-source (one-line Developer fix at L42); 1 Release-without-/Zi
coverage tooling gap (Developer handoff for cov-config /Zi add and
OpenCppCoverage install on QA host).

## Cycles executed

0 of planned 4 cycles. The driver exits at Phase 0.5 L146 before any
Phase 1 / Phase 2 / Phase 3 evidence is produced. Per-cycle
artifacts under
`._test_output/stage29-cache-modes-20260629-01/` are absent because
no cycle ran. Server.err.log proves the legacy boot succeeded; this
is the deepest evidence the run produced.

## Re-execution plan after Developer fix

After the one-line dot-source fix lands:

1. Re-run driver with `-DryRun` to confirm preflight PASS unchanged.
2. Re-run driver with full path (`-Cycles 3`) for fresh evidence.
3. Wall-clock target ~80 min per design part-09 R29-05.
4. Per-leg artifacts under `._test_output/stage29-cache-modes-YYYYMMDD-NN/`.
5. Fresh durable report at
   `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`.

## Next owner and gate

Developer (driver L42 dot-source fix + Architect review). After fix
verified: Manager re-execution gate #4. QA session re-runs full path
and produces 14-row evidence with concrete per-leg classifications.
After QA re-run: Developer test-results review. After Developer
PASS: Manager closure per D-CLOSURE-29-NN.

## Handoff discipline note

This part file records the third test execution handoff for Stage
29 without exceeding the entry-doc 300-line cap (entry doc is at
297 LF as of session end; this part file holds the post-execution
disposition). Future QA execution results should append to a new
`-NN` part file rather than modifying the entry doc body.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace.
