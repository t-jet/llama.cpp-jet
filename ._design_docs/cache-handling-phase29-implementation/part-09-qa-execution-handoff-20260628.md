# Stage 29 QA execution handoff: driver cold-path flag bug

Status: QA execution PASS=1 PARTIAL=1 BLOCKED=12 of 14 rows on
2026-06-28. Driver BLOCKING bug discovered at Phase 0.5 (cold-path
flag name mismatch). One-line Developer fix required before re-run.
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison)
Owner: QA session (this handoff); Developer (next, for one-line fix)
Source execution report: [../../../_design_docs/.test_reports/test-report-20260628-01-stage29-01.md](../../../_design_docs/.test_reports/test-report-20260628-01-stage29-01.md)

## Background

QA session 2026-06-28-01 executed the Stage 29 test plan in
[../../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md)
post Manager test-plan gate PASS. Setup-env captured at
[../../../_test_output/stage29-cache-modes-20260628-01/setup-env.json](../../../_test_output/stage29-cache-modes-20260628-01/setup-env.json).
Driver
[../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1)
invoked under `-DryRun`, `-OutputEquivalenceOnly`, and full path.

## BLOCKING finding F-29-EXEC-01

Driver line 88 in `Start-Stage29Server` constructs the server
argument list and includes the literal string `--cache-cold-dir`.
The actual server flag registered in `common/arg.cpp:1366` and
validated in `tools/server/server-context.cpp:617` is
`--cache-cold-path`. The server rejects the unknown flag at boot
with stderr `error: invalid argument: --cache-cold-dir` and exits
without binding the port. Phase 0.5 tokenize helper therefore never
reaches `/health`, and the driver throws
`BLOCKED-workload-build: tokenize helper failed /health` at line 140
before any Phase 1 / Phase 2 / Phase 3 evidence can be produced.

Direct server smoke test (independent of driver) confirmed the
binary boots healthy with the correct flag and serves a chat
completion request with cache_checkpoint_admissions_total=1, 0
admission failures. The binary, model fixture, CUDA path, and
hybrid cache mode are all functional on this host. Driver bug is
the sole blocker.

## One-line Developer fix

Change line 88 of
[../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1):

- Before: `--cache-cold-dir $CacheColdPath`
- After: `--cache-cold-path $CacheColdPath`

Same parameter name `$CacheColdPath`; only the flag literal changes.
No other code or test changes required.

## Per-row outcome (14 rows)

| Row | Status |
| --- | --- |
| TP-29-CC-01..04 | BLOCKED-driver-bug |
| TP-29-PR-01..03 | BLOCKED-driver-bug |
| TP-29-AG-01..04 | BLOCKED-driver-bug |
| TP-29-RG-01 | PARTIAL (142/142 focused tests PASS; pytest BLOCKED-env) |
| TP-29-RG-02 | PASS (zero tools/server/ modifications) |
| TP-29-CV-01 | BLOCKED-Release-without-/Zi |

Final counts: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12. Of 12 BLOCKED:
11 driver-bug (one-line Developer fix); 1 Release-without-/Zi
coverage tooling gap (Developer handoff for cov-config /Zi add and
OpenCppCoverage install on QA host).

## Re-execution plan after Developer fix

After the one-line driver fix lands:

1. Re-run driver with `-DryRun` to confirm preflight PASS unchanged.
2. Re-run driver with full path (`-Cycles 3`) for fresh evidence.
3. Wall-clock target ~80 min per design part-09 R29-05.
4. Per-leg artifacts under `._test_output/stage29-cache-modes-20260628-NN/`.
5. Fresh durable report at
   `._design_docs/.test_reports/test-report-20260628-NN-stage29-01.md`.

## Next owner and gate

Developer (driver line 88 fix + Architect review). After fix
verified: Manager re-execution gate. QA session re-runs full path
and produces 14-row evidence with concrete per-leg classifications.
After QA re-run: Developer test-results review. After Developer
PASS: Manager closure per D-CLOSURE-29-NN.

## Handoff discipline note

This part file records the test execution handoff without exceeding
the entry-doc 300-line cap (entry doc stays at 300 LF; this part
file holds the post-execution disposition). Future QA execution
results should append to a new `-NN` part file rather than
modifying the entry doc body.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
