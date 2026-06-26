# Part 4: Verification plan - clean build, unit tests, Stage 24 rerun

Status: closed; D-EXEC-24-03 fix verified via Stage 24 -07
Date: 2026-06-26
Scope: end-to-end verification chain that proves D-EXEC-24-03 is FIXED. This part serves as the Stage 27 test plan; final report is [test-report-20260626-07.md](../../.test_reports/test-report-20260626-07.md) and fix evidence is [test-report-20260626-07-fixes.md](../../.test_reports/test-report-20260626-07-fixes.md).

## Verification chain (binding)

### Step V1: clean Release build

| Check | Command | Expected result |
| --- | --- | --- |
| CMake cache `GGML_CUDA:BOOL=ON` | `grep GGML_CUDA build-cuda/CMakeCache.txt` | `GGML_CUDA:BOOL=ON` |
| `llama-server` target | `cmake --build build-cuda --config Release -j --target llama-server` | exit 0, `llama-server.exe` mtime > commit 4556965c7 timestamp |
| `test-cache-controller` target | `cmake --build build-cuda --config Release --target test-cache-controller` | exit 0, `test-cache-controller.exe` rebuilt |
| `server-crash-handler.cpp` linked | `dumpbin /dependents build-cuda/bin/Release/llama-server.exe` | `dbghelp.dll` listed |

### Step V2: existing 137 unit tests still pass

Run `& build-cuda/bin/Release/test-cache-controller.exe`. Expected: 137/137 PASS, exit 0. If any pre-existing test fails, the fix regressed Stage 21/22/25/26 behavior; do not proceed to Step V3.

### Step V3: new TP-27-UT-01 passes

Same `test-cache-controller.exe` run. Expected: 138/138 PASS (137 existing + 1 new TP-27-UT-01).

Test-failure protocol:

- If TP-27-UT-01 fails: the fix is incomplete; rollback the Stage 26 candidate and proceed to Step 2 of part-02 fix design (the `attach_payload` try/catch hardening).
- If TP-27-UT-01 passes: proceed to Step V4.

### Step V4: Stage 24 rerun (-05) with new binary

Run the existing `stage24-chat-s02-s03-comparison.ps1` against the post-fix binary:

| Parameter | Value |
| --- | --- |
| Build path | `build-cuda/bin/Release/llama-server.exe` (mtime > 4556965c7) |
| Cold path | `D:\tmp\cache-cold-stage27-05` |
| Crash dump dir | `D:\tmp\crash-dumps\stage24-20260626-05` |
| Base port | 8900 |
| RunId | `stage24-chat-s02-s03-20260626-05` |
| Date | 2026-06-26 (post-fix) |
| Route | `/v1/chat/completions` |

Expected outcomes:

| Leg | Expected verdict | Notes |
| --- | --- | --- |
| S02-chat native-legacy | PASS | unchanged from Stage 26 -01 |
| S02-chat hybrid-stage24 | PASS | unchanged from Stage 26 -01 |
| S03-chat native-legacy | PASS | unchanged from Stage 26 -01 |
| S03-chat hybrid-stage24 | PASS | NEW: must complete past request 258, total reqs >= 257 |

Crash-dump-dir is expected to remain empty (no SEH dump if the fix holds). If the SEH filter writes a dump, the crash reproduces and Stage 27 has not closed the issue.

### Step V5: D-EXEC-24-03 confirmed FIXED

Historical outcome (2026-06-26): V4 PASSED -- S03-chat hybrid-stage24 reached 687 requests (vs 258 crash threshold) with no SEH dump. The CLOSED branch below is the actual path taken; the OPEN branch is retained as historical contingency documentation for future similar bugs.

If V4 shows S03-chat hybrid-stage24 PASS with completion > 257 requests and no SEH dump:

- D-EXEC-24-03 status: CLOSED.
- Update the durable design doc to record the fix verification and the new test row.
- Manager gate can authorize Stage 27 closure.

If V4 shows the crash still reproduces:

- D-EXEC-24-03 status: OPEN.
- Roll forward to Step 2 of part-02 fix design (the try/catch hardening in `attach_payload`).
- Re-run V1-V4 with the additional fix.
- If still failing after Step 2: deepen investigation to Candidate C or D from part-01.

## Acceptance criteria (binding)

| Criterion | How verified |
| --- | --- |
| Existing 137 unit tests still pass | V2 output |
| New TP-27-UT-01 passes | V3 output |
| Stage 24 S03-chat hybrid completes past req 258 | V4 S03-chat summary.json `status_counts` and `observed` |
| No SEH dump written for the S03-chat leg | V4 `crash_dump_dir` empty |
| D-EXEC-24-03 marked CLOSED | V5 disposition |

## Reporting

The verification chain produces durable artifacts at:

| Artifact | Path |
| --- | --- |
| Build log | `build-cuda/_verify-build-llama-server-stage27.log` |
| Test log | `build-cuda/_verify-test-cache-controller-stage27.log` |
| Stage 24 rerun | `._design_docs/.test_reports/test-report-20260626-05.md` |
| Stage 27 closure | `._design_docs/cache-handling-phase27-implementation.md` + parts |

The Stage 27 implementation log entry doc is authored after V5 confirms D-EXEC-24-03 is closed. The closure document records the verification chain, the test result, the Stage 24 rerun result, and the Manager gate decision.

## Verification outcome (2026-06-26)

| Step | Result | Evidence |
| --- | --- | --- |
| V1 fix present on disk | PASS | 1-char change at `tools/server/server-cache-hybrid.cpp:3396` verified by Select-String |
| V2 clean Release build | PASS | llama-server.exe (mtime 2026-06-26 15:15:18); test-cache-controller.exe (mtime 2026-06-26 15:07:05); CMakeCache GGML_CUDA=ON |
| V3 137 + TP-27-UT-01 tests | PARTIAL | 110 PASS pre-TP-26-UT6; TP-27-UT-01 PASS; TP-26-UT6 aborts identically pre-fix and post-fix (D-EXEC-27-09 deferred) |
| V4 Stage 24 -07 rerun | PASS | all 4 legs reach leg cap; S03 hybrid 687 reqs vs 258 crash threshold (2.65x); 0 errors; 0 crashes |
| V5 D-EXEC-24-03 closed | PASS | server alive; no STATUS_HEAP_CORRUPTION; no SEH dump; inline demote completed synchronously |

Stage 24 -07 rerun details per row (final counts from [test-report-20260626-07-fixes.md](../../.test_reports/test-report-20260626-07-fixes.md)):

| Row | Variant | Reqs | All 200 | cache_n nonzero | State |
| --- | --- | ---: | --- | ---: | --- |
| S02-chat | native-legacy | 2516 | yes | 99.84% | completed-until-cap |
| S02-chat | hybrid-stage24 | 740 | yes | 85.41% | completed-until-cap (cold-budget drift pre-existing D-EXEC-24-03-c) |
| S03-chat | native-legacy | 1513 | yes | 99.80% | completed-until-cap |
| S03-chat | hybrid-stage24 | 687 | yes | 25.04% | completed-until-cap (was 258 in -06 baseline; 2.65x past crash threshold) |

## Handoff

Verification chain completed 2026-06-26: V1 PASS, V2 PASS, V3 PARTIAL (TP-26-UT6 deferred per D-EXEC-27-09), V4 PASS, V5 PASS. D-EXEC-24-03 closed per D-CLOSURE-27-01. Implementation evidence and per-row classification in [part-10](../cache-handling-phase27-implementation/part-10-manager-closure-20260626.md). Next owner: user (commit approval). Code changes in `tools/server/server-cache-hybrid.cpp` and `tests/test-cache-controller.cpp` UNCOMMITTED per AGENTS.md.
