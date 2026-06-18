# Part 4: Stage 19 implementation review (Architect, fresh session)

Status: PASS
Date: 2026-06-18
Reviewer: Architect (implementation review, fresh session)
Scope: Stage 19 implementation review (Branch C path) only. Not design re-review, not Manager closure, not Stage 20, not implementation log modification, not tracker modification, not document-index modification.
Source plan: [cache-handling-phase19-implementation.md](../cache-handling-phase19-implementation.md) (298 LF, Manager implementation-plan gate PASS 2026-06-18)
Source design: [cache-handling-phase19-design.md](../cache-handling-phase19-design.md) + parts 1-6 (Manager design gate PASS 2026-06-18)

## Verdict

PASS. Branch C (no reproduction) is supported by direct, byte-verified evidence. 5 successive baseline launches (no cache flags) all reach /health HTTP 200 with stable peak working set (5156.7-5157.0 MiB, delta 0.3 MiB, far below the 10% Branch B threshold). 3 port-shift launches clean. Process watcher reaches idle state. Validation gate at line 1249 verified at HEAD; controller-creation gate at line 1528 verified. fit_params projection 5150 MiB, system free memory ~33 GB (ample, growing not accumulating). Cache-flag regression smoke (cache-mode hybrid + cache-cold-path + cache-cold-max-mib 100) reaches /health HTTP 200 with cold store configured. No code change applied (git diff HEAD for tools/server/server-context.cpp and tests/test-cache-controller.cpp is empty; binary timestamp 2026-06-18 02:17:04 unchanged from Stage 18 closure). Stage 18 fix (D18-CLOSURE-01) is sufficient as-is.

## Inputs reviewed

| File | LF lines | Notes |
| --- | --- | --- |
| _design_docs/cache-handling-phase19-implementation/part-03-branch-C-implementation-evidence.md | 299 | Branch C implementation evidence; 299 LF, CR=0, BOM=False, NonAscii=0, under 300-line cap |
| _design_docs/cache-handling-phase19-implementation.md | 298 | Plan under review (PASS at Manager implementation-plan gate 2026-06-18) |
| _design_docs/cache-handling-phase19-design/part-01-question-disposition-and-reproduction.md | 88 | Three-branch disposition; reproduction plan; run matrix |
| _design_docs/cache-handling-phase19-design/part-02-root-cause-analysis-and-fix-proposal.md | 114 | Root cause analysis Step 1-3; 6 candidate crash-site ranges |
| _design_docs/cache-handling-phase19-design/part-03-test-plan-closure-traceability.md | 48 | 4 test plan rows; 5 closure criteria; traceability table |
| _design_docs/cache-handling-phase18-implementation.md | - | D18-CLOSURE-01 substantive finding, 2026-06-18 |
| _design_docs/cache-handling-phase17-implementation.md | - | D17-EXEC-02 baseline crash context, 2026-06-17 |

Reference (read for context):

- _design_docs/cache-handling-stage-tracker.md (Stage 19 row status "implementation", 2026-06-18)
- _design_docs/cache-handling-phase19-implementation/part-01-architect-implementation-plan-review-gate-01.md (plan review PASS, 0 BLOCKING, 2 non-blocking, 1 INFO)
- _design_docs/cache-handling-phase19-implementation/part-02-manager-implementation-plan-gate.md (Manager gate PASS, 2026-06-18)

Verification commands executed (read-only):

- `Test-Path '._design_docs/cache-handling-phase19-implementation/part-03-branch-C-implementation-evidence.md'` returned True.
- `[System.IO.File]::ReadAllBytes` on evidence file: Length 17310, CR count 0, First 3 bytes 35,32,80 (ASCII "# P"), LF count 299, line count 299.
- `git diff HEAD -- tools/server/server-context.cpp tests/test-cache-controller.cpp` returned empty (no source changes for Branch C).
- `git rev-parse HEAD` returned `cb93f3dbd1ff51428c1f8d2a238e5137fcea867c` (matches evidence claim of HEAD `cb93f3dbd`).
- `Get-Item 'build-cov/bin/Release/llama-server.exe'` returned LastWriteTime `2026-06-18 02:17:04` (binary unchanged from Stage 18 closure).
- `Select-String -Path tools/server/server-context.cpp -Pattern 'if \(params_base.cache_ram_mib != 0\)'` returned 2 matches at lines 1249 (validation gate) and 1528 (controller creation). Matches evidence Step 2.1 claim.
- `Get-ChildItem -Recurse -Force '._test_output/stage19-rerun-artifacts'` confirmed 41 artifact files under rt1/, rt2/, rt3/ including 5 launch logs, 3 portshift logs, watcher log, memory snapshots, and cache-flag smoke log.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt1/5x-results.json' -Raw` showed 5 launch records each with healthReached=true, peakWorkingSetMB 5156.7-5157.0, lastErrLine="update_slots: all slots are idle".
- `Get-Content '._test_output/stage19-rerun-artifacts/rt1/portshift-results.json' -Raw` showed 3 launch records each with healthReached=true, peakWorkingSetMB 5156.7-5157.1.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt1/process-metrics.json' -Raw` confirmed single-launch startTime 10:33:10, lifetime 2.09s, hasExited false, exitCode "still-running", healthReached true, peakWorkingSetMB 5156.9, port 18220.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt1/watcher-process-metrics.json' -Raw` confirmed watcher lastErrLine "update_slots: all slots are idle".
- `Get-Content '._test_output/stage19-rerun-artifacts/rt2/system-memory-before.json' -Raw` returned TotalVisibleMemorySize 64639164, FreePhysicalMemory 33751880. Matches evidence Step 2.4.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt2/system-memory-after.json' -Raw` returned TotalVisibleMemorySize 64639164, FreePhysicalMemory 33793736. Matches evidence Step 2.4.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt3/cache-hybrid-metrics.json' -Raw` confirmed cache-flag regression smoke with healthReached=true, cold store configured.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt1/health-response.log'` returned `{"status":"ok"}` confirming /health HTTP 200 success.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt1/5x-launch-1.health.log'` and `5x-launch-5.health.log` both returned `{"status":"ok"}`.
- `Get-Content '._test_output/stage19-rerun-artifacts/rt1/server.err.log' -Tail 5` showed `server is listening on http://127.0.0.1:18220` and `update_slots: all slots are idle` confirming post-init idle state.
- `Select-String` over evidence file for `_test_output` found 7 references without leading dot; actual artifacts use `._test_output` (see F-19-IR-01 below).
- `Select-String` over evidence file for unicode codepoints 4e00-9fff, 2600-27ff, 2190-21ff returned no matches. ASCII-only confirmed.
- `Get-Content` evidence file lines checked for trailing whitespace: 0 lines.
- `Select-String` over evidence file for cited numbers 1249, 1528, 1242, 1291, 5000, 5150, 63124, 33751, 33793 confirmed each appears with consistent context (see F-19-IR-02 below for MiB conversion inconsistency).
- `Select-String` over `._design_docs` for `D18-CLOSURE-01` confirmed in `cache-handling-phase18-implementation.md` line 155; `D17-EXEC-02` confirmed in `cache-handling-phase17-implementation.md` line 61. Decision IDs cross-referenced.

## Verification checklist

### Reproduction thoroughness

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Step 1.1 single baseline launch: command correct, no cache flags, default values; metrics complete | PASS | Evidence lines 36-77: command uses `--port 18220 --model ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf` only; no cache flags. process-metrics.json: lifetime 2.09s, hasExited false, exitCode "still-running", healthReached true, peakWorkingSetMB 5156.9, port 18220, last log line "update_slots: all slots are idle". Matches plan Step 1.1 reproduction command. |
| 2 | Step 1.2 5x repeat: all 5 launches captured; WS growth assessed; >10% threshold applied | PASS | Evidence lines 79-89: 5 launches on ports 18220-18224, all healthReached=true, peakWorkingSetMB 5156.7-5157.0, WS growth 0.3 MiB (far below 10% / 515.7 MiB Branch B threshold). 5x-results.json cross-checked: 5 launch records consistent. Detection rule from design part 1 applied. |
| 3 | Step 1.3 port-shift: 3 ports tested; port conflict ruled out | PASS | Evidence lines 91-100: 3 launches on ports 18220/18221/18222, all healthReached=true, peakWorkingSetMB 5156.7-5157.1. portshift-results.json cross-checked: 3 records consistent. Port conflict excluded. |
| 4 | Step 1.4 process watcher: StartTime/ExitTime/HasExited/ExitCode captured; last log line identified | PASS | Evidence lines 102-114: watcher-process-metrics.json cross-checked: pid 35420, startTime 10:34:38, lifetime 2.08s, hasExited false, exitCode "still-running", healthReached true, peakWorkingSetMB 5156.8, lastErrLine "update_slots: all slots are idle". Resolves F-19-DR-01 from design review. |

### Analysis thoroughness

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 5 | Step 2.1 validation gate verification: 2 matches at 1249 + 1528 confirmed; baseline bypass documented | PASS | Evidence lines 130-135: Select-String pattern matches gate at 1249 and controller-creation at 1528. Direct verification on tools/server/server-context.cpp at HEAD confirmed same 2 matches at same lines. Plan Step 2.1 explicitly notes 2-match observation is gate + controller creation, not a duplicate. Baseline path with default cache_ram_mib=0 skips both; Stage 18 fix cannot affect baseline path. |
| 6 | Step 2.2 crash site localization: not needed for Branch C; candidate ranges noted | PASS (with F-19-IR-03) | Evidence lines 137-149: Step 2.2 correctly marked "Not applicable for Branch C. No crash occurred." Candidate site table at lines 144-149 lists 5 sites (common_init_from_params at 1292, model_dft at 1331, mctx at 1389, slots.emplace_back at 1455, slot.reset at 1500). Design part 2 lists 6 sites including ctx_dft at 1342-1366; evidence omits ctx_dft but Branch C does not require crash-site localization. See F-19-IR-03. |
| 7 | Step 2.3 fit_params projection: 5150 MiB captured; borderline vs 5000 MiB threshold; system memory ample | PASS | Evidence lines 156-163: log line "projected to use 5150 MiB of host memory vs. 63124 MiB of total host memory" reproduced verbatim from server.err.log. Branch B threshold 5000 MiB applied; 5150 MiB is 150 MiB above threshold but system has 63124 MiB total (32x headroom). Memory pressure not the trigger. |
| 8 | Step 2.4 system memory snapshot: before/after values; no accumulation | PASS (with F-19-IR-02) | Evidence lines 165-172: system-memory-before.json (TotalVisibleMemorySize 64639164, FreePhysicalMemory 33751880) and system-memory-after.json (TotalVisibleMemorySize 64639164, FreePhysicalMemory 33793736) cross-checked. Delta +41856 KB across 7 launches; free memory grew not accumulated. Branch B environmental trigger not present. See F-19-IR-02 for MiB conversion inconsistency in table. |
| 9 | Step 2.5 branch determination: Branch C correctly applied based on 5x clean + WS stable + system memory ample | PASS | Evidence lines 174-184: 3-row verdict table explicitly maps Branch A (no buffer overrun; no crash; NO), Branch B (fit_params 5150 MiB slightly above threshold but system free 32185 MiB ample; NO), Branch C (5/5 clean; WS stable delta 0.3 MiB; YES). Verdict Branch C. |

### Branch C criteria

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 10 | 5 successive successful launches documented | PASS | Evidence lines 79-89: 5 launch records in 5x-results.json all healthReached=true with consistent peak working set. Each launch recorded in dedicated log file (5x-launch-{1..5}.err.log) and health file (5x-launch-{1..5}.health.log = `{"status":"ok"}`). |
| 11 | Per-launch evidence (port, lifetime, hasExited, /health, peak WS) | PASS | 5x-results.json cross-checked: each launch record contains port, startTime, endTime, lifetimeSec, hasExited=false, exitCode "still-running", healthReached=true, peakWorkingSetMB. Single-launch (process-metrics.json) and watcher (watcher-process-metrics.json) records also complete. |
| 12 | No code change justified (baseline path independent of Stage 18 fix gate) | PASS | Evidence lines 188-191: git diff HEAD for tools/server/server-context.cpp and tests/test-cache-controller.cpp both empty. Binary timestamp 2026-06-18 02:17:04 unchanged from Stage 18 closure. Baseline path with cache_ram_mib=0 skips validation gate at 1249; baseline path is independent of Stage 18 fix. |

### Test plan execution

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 13 | TP-19-RT1 (5x baseline repeat): PASS | PASS | Evidence lines 198-200: Step 4.1 PASS, 5/5 clean, WS stable, no crash. Evidence files rt1/5x-results.json + 5x-launch-{1..5}.err.log + 5x-launch-{1..5}.health.log. |
| 14 | TP-19-RT2 (memory snapshot): PASS | PASS | Evidence lines 202-204: Step 4.2 PASS, system memory ample, no accumulation, free memory grew 41 MiB across 7 launches. Evidence files rt2/system-memory-before.json + rt2/system-memory-after.json. |
| 15 | TP-19-RT3 (Stage 18 regression smoke): PASS | PASS | Evidence lines 206-237: Step 4.3 PASS. cache-hybrid-metrics.json cross-checked: port 18210, lifetime 2.06s, healthReached true, peakWorkingSetMB 5156.9, cacheFlags including --cache-mode hybrid + --cache-cold-path + --cache-cold-max-mib 100. cache-hybrid.err.log lines 25-28 confirm cold store configured. Reused Stage 18 it01/it03 evidence for validation-block firing paths. |
| 16 | TP-19-FT1 (crash signature fixture): correctly no-op for Branch C | PASS | Evidence lines 239-243: Step 4.4 no-op with rationale "Branch C: no crash signature to capture. Baseline warmup does not reproduce on current system state at HEAD cb93f3dbd." Per plan Step 4.4 Branch B/C path explicitly no-op. |

### Closure criteria (5 points from design part 3)

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 17 | 5-point closure criteria check complete | PASS | Evidence lines 247-259: each of 5 criteria from design part 3 reproduced with evidence pointer and PASS verdict. Criterion 1 (reproduction in fresh Developer session): Steps 1.1-1.4 scripts under `._test_output/stage19-rerun-artifacts/rt1/` (note: evidence text says `_test_output` without leading dot, see F-19-IR-01). Criterion 2 (Branch verdict with evidence): Step 2.1-2.5 Branch C. Criterion 3 (fix proposal recorded): Branch C no-fix decision. Criterion 4 (test plan rows pass or no-op): TP-19-RT1/RT2/RT3 PASS, TP-19-FT1 no-op. Criterion 5 (Manager closure decision): handoff ready. |
| 18 | Recommendation (Branch C closure) consistent with evidence | PASS | Evidence lines 263-266 + 280: Recommendation "PASS Branch C. Stage 19 closes with no-reproduction evidence. The Stage 18 fix (D18-CLOSURE-01) is sufficient as-is." Handoff to Manager for closure decision in fresh session. Branch determination table at lines 174-184 confirms Branch C selected with explicit rule application. |

### Source code state

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 19 | git diff HEAD -- tools/server/server-context.cpp tests/test-cache-controller.cpp: empty | PASS | Direct git diff returned empty. Evidence Step 3 (line 187-191) records this verification. Branch C explicit "do not modify code" rule applied. |
| 20 | Binary unchanged | PASS | Get-Item build-cov/bin/Release/llama-server.exe LastWriteTime 2026-06-18 02:17:04 matches Stage 18 closure timestamp. No rebuild required for Branch C. |

### Document quality

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 21 | Under 300 lines (299 confirmed) | PASS | Byte-level LF count = 299, under 300-line cap. Task brief cited "209 LF" but actual is 299 (file grew between task authoring and review; same pattern as F-19-IPR-03 in plan review). |
| 22 | LF line endings (no CRLF) | PASS | Byte-level CR count = 0 on full file read. |
| 23 | No unicode icons | PASS | Byte-level non-ASCII count = 0; codepoint scan for 4e00-9fff / 2600-27ff / 2190-21ff returned no matches. |
| 24 | Plain ASCII status labels | PASS | All `Status:` lines are ASCII; no em dashes or decorative separators; `PASS` / `FAIL` / `BLOCKING` / `REWORK` plain ASCII. |

## Findings

| # | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-19-IR-01 | NON-BLOCKING | Artifact path references missing leading dot prefix in 6 places | Evidence file uses `_test_output/stage19-rerun-artifacts/...` (7 occurrences in lines 40, 81, 95, 107, 206, 231 partial, 249) but actual artifacts are at `._test_output/stage19-rerun-artifacts/...` (with leading dot, confirmed by directory listing). Plan file uses `._test_output/` consistently. Evidence manifest table at lines 274-282 also lists `rt1/server.err.log` etc. without the prefix. | Optional: when Manager records closure, normalize path references in evidence file to `._test_output/...`. Not required for PASS verdict since artifacts exist at correct path. |
| F-19-IR-02 | NON-BLOCKING | Free-memory MiB conversion uses three different conventions across the same evidence file | Table at lines 169-170 shows "Free (MiB) 32185" and "Free (MiB) 32196" derived as KB*1000/1048576 (binary MiB from decimal KB), while "Total (MiB) 63124" is KB/1024 (decimal MiB from binary KB). Verdict prose at lines 13, 25, 161 uses "33751 MiB" and "33793 MiB" derived as KB/1000 (decimal MiB from decimal KB). Direct calculation KB/1024 yields 32960 and 33000 MiB. Branch determination table at line 179 uses "32185 MiB" matching the table column. Three conventions in one file. | Optional: when Manager records closure, normalize Free (MiB) column to one convention. The conclusion (ample free memory) is unambiguous from raw KB values regardless of convention. |
| F-19-IR-03 | NON-BLOCKING | Step 2.2 candidate site table omits ctx_dft site present in design part 2 | Evidence lines 144-149 list 5 sites (common_init_from_params, model_dft reset, mctx, slots.emplace_back, slot.reset). Design part 2 (lines 60-67 of design part 2) lists 6 sites including `ctx_dft init (MTP path)` at 1342-1366. Implementation plan Step 2.2 lists 6 patterns with 5 unique sites (the 6th is a duplicate pattern for line 1292). | No action required for Branch C; ctx_dft site is not exercised on baseline path (no speculative flag) and Branch C explicitly does not require crash-site localization. |

## Counts

- BLOCKING: 0
- Non-blocking: 3 (F-19-IR-01 path prefix, F-19-IR-02 MiB conversion, F-19-IR-03 candidate table omission)
- INFO: 0

## Verdict (formal)

**PASS.** Stage 19 Branch C implementation evidence is complete and verified. The Developer correctly selected Branch C from the three-branch disposition: 5 successive baseline launches (no cache flags) all reach /health HTTP 200 with stable peak working set (5156.7-5157.0 MiB, delta 0.3 MiB, far below the 10% Branch B threshold of 515.7 MiB). 3 port-shift launches rule out port conflict. The process watcher confirms post-init idle state ("update_slots: all slots are idle"). The validation gate at line 1249 (and controller-creation gate at line 1528) are both verified at HEAD via direct Select-String, confirming baseline path with default cache_ram_mib=0 skips the Stage 18 fix's validation block. fit_params projection 5150 MiB is borderline vs the 5000 MiB Branch B threshold but system has 63124 MiB total and ~33 GB free (ample; growing not accumulating). The cache-flag regression smoke (cache-mode hybrid + cache-cold-path + cache-cold-max-mib 100) reaches /health HTTP 200 with cold store configured, confirming the Stage 18 fix is still effective on the cache-flag path. No code changes were made (`git diff HEAD` for tools/server/server-context.cpp and tests/test-cache-controller.cpp returns empty; binary timestamp 2026-06-18 02:17:04 unchanged from Stage 18 closure). The 5 closure criteria from design part 3 are satisfied. The 3 non-blocking findings (path prefix, MiB conversion, candidate table omission) are documentation hygiene issues that do not affect the Branch C verdict and may be addressed during Manager closure if convenient. The evidence file is 299 LF, CR=0, BOM=False, non-ASCII=0, under the 300-line cap, with LF-only line endings.

## Handoff

Next owner: **Manager** for closure decision in a fresh session. The Manager records the Branch C verdict in `cache-handling-stage-tracker.md` (advancing the Stage 19 row from "implementation" to "closed"), updates `document-index.md` if a new entry row is needed for the implementation log, and proposes any follow-up (e.g., Stage 20 environmental stability follow-up if the Stage 17 evidence session's different system conditions are worth re-investigating). The Manager may optionally address the three non-blocking findings (F-19-IR-01 path prefix normalization, F-19-IR-02 MiB conversion normalization, F-19-IR-03 candidate table context-row addition) during closure documentation sweep if desired; none are required for PASS. The design, Stage 18 implementation log, stage tracker (except the Manager closure row update), document-index, and any other durable doc are NOT modified by this review. The Branch B tracker follow-up row is a conditional Step 3.2 activity and was not triggered since Branch C was selected.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable doc cap.
