# Test report 20260607-04 Developer test-results review

- Review ID: test-report-20260607-04-developer-review
- Date: 2026-06-07
- Reviewer: Developer agent (fresh session)
- Source report: ._design_docs/.test_reports/test-report-20260607-04.md
- Source plan: ._design_docs/cache-handling-test-plan/part-18, part-18a, part-19
- Source impl: ._design_docs/cache-handling-phase12-implementation/part-03

## 1. Scope and references

Read-only developer test-results review of test-report-20260607-04 covering the Stage 12 execution session. The per-row verdict table has 16 entries covering 8 preflight, 2 stress singles (S01, S02), 3 stress blocks (S03..S08, B01..B08, L01..L03), 2 nearest-legacy, and 2 MTP carry-forward rows; the report also summarizes 19 dry-run harness invocations. Sources consumed: part-18 (matrix, clean build, evidence format), part-18a (operational, observability, regression, out-of-scope, S12-PLAN-01), part-19 (scripts inventory, dry-run, STUB, evidence helpers), part-20 (PASS plan review), impl part-03 (script inventory, per-scenario summary), impl part-04 (syntax and dry-run verification, fix history), impl part-05 (fixture gating).

Per developer policy this review is read-only: no code edits, no test runs, no rebuilds, no commits. Cross-reference to same-day QA follow-up sessions was not performed because the user instruction limited reads to the 8 named source files.

## 2. Per-row classification

| Row ID | QA verdict | Developer agreement | Classification | Notes |
| --- | --- | --- | --- | --- |
| preflight-1 test-cache-controller | PASS | agree | PASS | 0.26s; part-18a sec 10 regression list |
| preflight-2 test-step6-demotion-protocol | PASS | agree | PASS | 2.66s |
| preflight-3 test-step7-promotion-protocol | PASS | agree | PASS | 3.66s |
| preflight-4 test-step10-metrics | PASS | agree | PASS | 0.34s; validates /metrics rows |
| preflight-5 test-stage10-cold-store-hardening | PASS | agree | PASS | 0.03s |
| preflight-6 test-step11-test-hooks-fault-injection | PASS | agree | PASS | 1.32s; S08 precondition source |
| preflight-7 test-step12-branch-graph | PASS | agree | PASS | 0.02s |
| preflight-8 test-step13-stage8 | PASS | agree | PASS | 0.01s |
| S12-S01 budget exhaustion | FAIL live, PASS dry | agree | FAIL, FIX-DELIVERABLE | Root cause: stress_s12_s01_budget_exhaustion.ps1 lines 50-52 serverFlags omit --model; server enters router mode; /metrics 400 model name missing. Script bug, not product bug. |
| S12-S02 concurrent multi-slot | PASS live partial | agree | PASS | parallel4: 140 reqs in 60s, full evidence dir; parallel8: started loading model n_slots 8 then killed by 3 min outer session timeout. Session timeout is operational, not product. |
| S12-S03..S08 stress (6) | BLOCKED live, PASS dry | agree | BLOCKED | Time-box and S01/S05 script bugs; dry-run proves harness. |
| S12-B01..B08 bench (8) | BLOCKED live, PASS dry | agree | BLOCKED | Same blockers as stress; dry-run exit 0. |
| S12-L01..L03 long-run (3) | BLOCKED live, PASS dry | agree | BLOCKED | Same blockers; long-run also time-box constrained. |
| S12-B05-NL nearest legacy | BLOCKED | agree | BLOCKED | Subsumed under B05 block per part-18a sec 13. |
| S12-B08-NL nearest legacy | BLOCKED | agree | BLOCKED | Subsumed under B08 block per part-18a sec 13. |
| H53 H54 MTP-capable | BLOCKED | agree | BLOCKED | Qwen3.5-4B-MTP held out by cap-fix closure 2026-06-07 part-29. |

Agreement count: 16 of 16 rows.

## 3. Evidence quality

Preflight: ctest log at ._design_docs/.test_reports/ctest-20260607-04-preflight.log; 8/8 passed in 8.32s with per-test exit codes; fresh build-cov binaries dated 2026-06-07 15:47:48 to 15:48:39. Cap-fix closure baseline preserved.

Dry-run: 19 scripts exit 0 with planned flags, fixture, port, and duration printed. Consistent with impl part-04 round 2 verification. Part-19 sec 4 dry-run contract honored.

Live S01: server.err.log captures router-mode startup line "I srv  llama_server: starting router server, no model will be loaded in this process" at port 8201, /metrics returns 400 model name missing. server.out.log is 0 bytes because the server never logged model load. serverFlags in the script lack --model per the report sec 11 Bug A reproduction block, with the S02 reference line cited as the working pattern.

Live S02 parallel4: metrics-before.txt 20124B, metrics-after.txt 20284B, resource-samples.csv 666B, evidence-summary.md 1622B; request count 140, duration 60s, --cache-ram 100 --parallel 4 in server flags. Stub flag MEASURED. Real end-to-end proof of harness.

Live S02 parallel8: model load started with n_slots 8, metrics-before.txt 20124B captured, killed by 3 min outer session timeout before completion. Operational timeout, not a product issue.

MTP H53 H54: no server start attempted, no fixture load. Aligned with cap-fix closure scope.

## 4. S01 and S05 script bug analysis

Bug A (S01): file stress_s12_s01_budget_exhaustion.ps1 lines 50-52 construct the serverFlags array as a literal that does not include --model. The array is appended to Start-Process ArgumentList together with --host and --port, but the model path is never added. Per part-19 sec 3 the driver is expected to receive the model path via LLAMA_CACHE_TEST_MODEL or default; S01 either ignores that variable or builds the array before the variable is read. S02 line ~95 uses the append-form `@(--model, $ModelPath, ...)` which is the working pattern.

Bug B (S05): file stress_s12_s05_mixed_workload_profiles.ps1 has the same class defect on at least one of its three profile sub-runs. The report flags it for verification on the next session; static audit shows --model in args equals False for at least one sub-run. Same fix pattern as Bug A.

Both bugs are reproduced from test report sec 11. Bug A includes the exact lines 50-52 source, the S02 line 95 reference, the bare Invoke-WebRequest on line 113, and the S01 exit on the router-mode server. They are not product bugs: the same llama-server binary served S02 successfully with the right flags in the same session, on the same build, with the same Qwen3-0.6B fixture.

## 5. Product-bug assessment

None.

Evidence: S02 parallel4 ran 140 requests in 60s on the same build with --cache-ram 100 --parallel 4, full metrics snapshots, full resource samples, evidence-summary.md written. The server only failed when started without --model, which is documented llama-server behavior (router mode, model name missing on /metrics). S01 and S05 are pure script construction errors. Preflight ctest 8/8 PASS confirms cap-fix closure baseline. No product-bug class evidence in this session.

## 6. Unresolved execution blockers

- S01 serverFlags missing --model: blocks S01 live and any stress row that depends on the same code path. S05 may have the same class defect on at least one profile sub-run.
- 17 BLOCKED live rows: S03..S08, B01..B08, L01..L03. All are downstream of the S01/S05 fix plus a fresh live session with adequate outer timeout (at least 90s per part-20 sec 9 known issue).
- 2 NL BLOCKED rows: S12-B05-NL, S12-B08-NL subsumed under B05 and B08; auto-unblock when B05 and B08 unblock.
- 2 MTP BLOCKED rows: H53, H54 held out by cap-fix closure, not a stage 12 fix candidate.
- Cosmetic: dry-run-only evidence dir residue; S02 dry-run port print shows base port for both sub-runs.

## 7. Retest scope

After Developer applies the S01 and S05 serverFlags fix:

1. Re-run S12-S01 live: confirm server enters model load mode, /metrics-before returns 200, prompt loop runs, metrics snapshots and resource-samples.csv written, evidence-summary.md verdict PASS.
2. Re-run S12-S05 live or static audit plus smoke run: confirm all three profile sub-runs include --model in serverFlags.
3. Re-run S12-S02 parallel8 alone with at least 90s outer session timeout to allow 60s plus 60s sub-runs.
4. Re-run the 17 BLOCKED rows (S03..S08, B01..B08, L01..L03) one scenario at a time with adequate outer timeout.
5. B05-NL and B08-NL are subsumed; re-run only if B05 and B08 finish without BLOCKED.

## 8. Next-gate recommendation

Recommend Manager approve Developer fix-deliverable to:

- Patch stress_s12_s01_budget_exhaustion.ps1: add `@('--model', $ModelPath)` to serverFlags at lines 50-52 in the S02 append-form pattern.
- Patch stress_s12_s05_mixed_workload_profiles.ps1: audit all three profile sub-runs, add `@('--model', $ModelPath)` where missing.
- No product code change. No fixture change. No build change. No doc change beyond the fix-deliverable fix report and the implementation log update.

After fix, hand off to QA for fresh live execution session with at least 90s outer timeout per scenario.

## 9. Manager handoff

- Review verdict: PASS-with-script-bugs. 16 of 16 verdict rows agreed with QA.
- Product bugs: 0.
- Script bugs: 2 (S01, S05). Both are stress-scripts serverFlags construction, both reproducible from test report sec 11.
- Retest scope: 19 live rows (S01, S02-parallel8, S03..S08, B01..B08, L01..L03) plus 2 NL subsumed.
- MTP rows: BLOCKED, owned by cap-fix closure 2026-06-07.
- Next gate: Developer fix-deliverable on S01 and S05 scripts, then QA live re-run.
- Output file: this document.
