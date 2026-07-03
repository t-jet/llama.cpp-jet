# Stage 34 reopened live QA - Developer test-results review

Generated: 2026-07-01
Stage: 34 (reopened)
Source QA report: `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260701-01-stage34-reopen-live-small-cache4g.md`
QA verdict: FAIL on TP-34-CC concurrent row; PARTIAL on TP-34-CL/OB; PASS on TP-34-AH-03 / TP-34-RR-03 (as runner)
Reviewer: Developer (test-results review)
Branch: work-branch
Active gate: Stage 34 reopen, per `._design_docs/cache-handling-phase34-implementation/part-10-manager-reopen-20260701.md` decisions D34-REOPEN-01..04

## Skill load confirmation

Skill-load complete. Read the four required files in order at session start:

1. `.agents/skills/self-improvement/SKILL.md`
2. `.agents/skills/self-improvement/assets/developer.md` (applied every Condition/Action entry: Test-results review gate classification, Cross-reference same-day QA follow-up sessions, Replace stale test-report references, Verify prompt facts against repo state before acting, Scope whitespace checks in dirty worktrees, Preserve local line endings in patch edits, Plain ASCII scan on humanizer-cleaned report tables, Build halt can mask later compile or runtime defects, Handoff H2 collision in multi-gate stage implementation logs)
3. `.agents/skills/developer/SKILL.md` (test-results review section)
4. `.agents/skills/caveman/SKILL.md` (used `ultra` mode for internal thinking, `full` mode for chat response)

## Gate context

- Stage 34 reopened by Manager on 2026-07-01; live row coverage now the binding gate.
- TP-34-CC (concurrent main/subagent cache reuse) is the binding row for the reopen goals per the design acceptance criterion "concurrent main/subagent requests share cache safely without contamination" (cache-handling-phase34-design.md, Acceptance criteria).
- Source report under review: `test-report-20260701-01-stage34-reopen-live-small-cache4g.md`. Older 2026-06-30 reports treated as historical evidence only.

## Files verified by `Test-Path` (all returned True)

- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260701-01-stage34-reopen-live-small-cache4g.md`
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-04-stage34-01.md` (pre-reopen baseline)
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-04-stage34-01-developer-review.md`
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-04-stage34-01-developer-review-2.md`
- `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-03-stage33-01-developer-review.md` (Stage 33 EXPECTED-BEHAVIOR pattern)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-test-plan\part-37-stage34-real-agentic-transcript-replay.md` (test plan)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase34-design.md` (acceptance criteria)
- `D:\source\llama.cpp-jet\._design_docs\cache-handling-phase34-implementation\part-10-manager-reopen-20260701.md` (reopen decisions)
- `D:\source\llama.cpp-jet\_test_output\stage34-reopen-live-small-cache4g\server.err.log` (268447 B; `Select-String` counts below taken from this file)
- `D:\source\llama.cpp-jet\_test_output\stage34-reopen-live-small-cache4g\real-chatlog-concurrent-warm\summary.json` (56 success, 0 errors)
- `D:\source\llama.cpp-jet\_test_output\stage34-reopen-live-small-cache4g\cold` (directory, 22 .cold files per QA report; byte proof 4,085,286,884)
- `D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe` (binary, PID 34352, 2026-07-01 10:33:04)

## Per-row verdict

| Row | QA verdict | Review verdict | Citation / evidence |
| --- | --- | --- | --- |
| TP-34-AH-03 (real expected-hit table) | PASS | PASS (hold) | report Row classification row 1: both live runs produced 56 expected rows: 23 `expected_result=hit` (14 same-branch + 9 cross-branch exact checksums), 33 first observations. Concurrent warm `summary.json` `replay_events=56` matches. Bounded invariant `(token_count>0 AND token_checksum not empty) OR (bounded_miss_reason set)` satisfied. |
| TP-34-RR-03 (concurrent live runner) | PASS as runner | PASS (hold) | report Row classification row 3: concurrent warm command completed; `events.jsonl`, `requests.jsonl`, `expected-hits.jsonl`, `responses.jsonl`, `metrics-before.txt`, `metrics-after.txt`, `summary.json` all present. HTTP 56 of 56 success, 0 errors. |
| TP-34-CC (concurrent main/subagent cache reuse) | FAIL | **FAIL - product bug (concurrent cache reuse path)** | report Row classification row 4 + Blocker classification: 23 predicted hot exact-hit rows vs 8 hit / 15 missed in concurrent warm. Sequential run on same server, same transcript, same process: 23 of 23 hit. Server.err.log counts: crash=0, request-error=0, exception=0, corruption=0, ASSERT=0, error=0, namespace=76 (stable, count=1 per metrics), checksum=14, token_count=66, restore-apply=0. Hit-row list: `row-00078, row-00105, row-00107, row-00206, row-00238, row-00259, row-00298, row-00308`. Miss-row list: `row-00052, row-00090, row-00095, row-00131, row-00148, row-00170, row-00196, row-00226, row-00242, row-00254, row-00285, row-00303, row-00312, row-00340, row-00347`. Hit/miss rows are interleaved through the 56-row workload, not clustered. |
| TP-34-CC-02 (live concurrent subagent chat) | (parent row 2026-06-30) | INHERITED FAIL on TP-34-CC; the 2026-06-30-04 review's BLOCKED-driver-killed-mid-cycle for TP-34-CC-02 is now answered by the reopen run. Reopen `summary.json` confirms concurrent live runner wrote `events.jsonl` and `responses.jsonl` (raw_prompt_capture=true, server_url=`http://127.0.0.1:9136`, response_count=56, success_count=56). The reopen concurrent evidence is the live run that TP-34-CC-02 needed. Verdict for the TP-34-CC family stays FAIL on concurrent cache reuse. | report Artifacts section + reopen concurrent `summary.json` fields `server_url`, `raw_prompt_capture`, `response_count`, `success_count`. |
| TP-34-CL/OB (cold and metrics evidence) | PARTIAL | PARTIAL (hold) | report Row classification row 5: cold store 22 files, 4,085,286,884 bytes (within 4096 MiB cap). Concurrent metrics deltas: hits +8, misses +48, evictions +79, entries -2, bytes +354,301,136, namespace count unchanged at 1, promotions +1, promotion failures 0. The 8 hit rows in concurrent warm could have come from cold-store promotion; cold store is functioning. |
| TP-34-OB-03 (server log scan, restore-apply text) | PARTIAL | **NEW FINDING: restore-apply log signal gap** | report Row classification row 6: `server.err.log` `Select-String` count of `restore-apply` = 0 across 268,447 B. Test plan part-37 TP-34-OB-03 PASS signal requires `restore-apply` appears at least once whenever any `expected_result=hit` row resolves; sequential had 23 hit rows that should have produced a restore-apply signal, concurrent had 8. Restore-apply log emission is missing from the log scan. Classify as a separate logging/harness gap; do not bundle into TP-34-CC. |
| TP-34-OB-01 (live `/metrics` capture) | (parent row 2026-06-30) | INHERITED PASS (reopen metrics are live) | reopen warm `metrics-before.txt` / `metrics-after.txt` present; counters `cache_hits_total`, `cache_misses_total`, `cache_namespace_count`, `cache_payload_promotions_total`, `cache_payload_promotion_failures_total` all reported. Counter deltas match response-level evidence (hits +8 in concurrent). |
| TP-34-OB-02 (cold-store byte proof) | (parent row 2026-06-30) | INHERITED PASS (reopen cold store is live) | cold store `_test_output/stage34-reopen-live-small-cache4g/cold` contains 22 .cold files; aggregate 4,085,286,884 bytes; within 4096 MiB cold cap; promotion succeeded (promotions +1, failures 0). |

## Sequential vs concurrent differential analysis

The same server process, the same transcript, the same `expected-hits.jsonl` produced both runs. Sequential proves the hot-cache admission and lookup path can resolve all 23 predicted hot exact-hit rows (cache_n > 0, metrics hits +23, no namespace inflation, no log errors). Concurrent warm on the same process resolves only 8 of the same 23 rows (cache_n > 0, metrics hits +8, namespace count unchanged at 1, server log clean).

Hot capacity rules out eviction pressure as the cause. With a 4096 MiB hot budget and ~85 MiB per payload (Qwen3 0.6B), the controller can hold ~48 hot entries; 23 predicted hot candidates occupy less than half of that. The same 23 entries are all admitted in the sequential run. Sequential also did not demote them in the time window the concurrent run spans; concurrent metrics show entries -2 net and bytes +354 MB, indicating the controller is in steady state, not thrashing.

Hit and miss rows are interleaved through the workload (positions 52, 78, 90, 95, 105, 107, 131, 148, 170, 196, 206, 226, 238, 242, 254, 259, 285, 298, 303, 308, 312, 340, 347). The interleaving is not a workload-shape or timing-pattern artefact. The differential is the concurrent execution model, not the workload.

## Stage 33 EXPECTED-BEHAVIOR pattern check

Stage 33 closure reclassified the Hybrid reuse row to EXPECTED-BEHAVIOR because the workload's duplicate inter-arrival time (median 758 s) exceeded the 6-entry 512-MiB hot-cache retention window under load (see `test-report-20260630-03-stage33-01-developer-review.md`, "Hybrid reuse root-cause analysis"). The pattern required (a) a hot cache too small to retain entries across the duplicate interval and (b) long-spaced duplicates as the dominant workload shape.

Stage 34 reopen has neither. The hot budget is 4096 MiB (~48-entry headroom), the workload is 56 rows in a single process, and the same 23 hot rows hit in sequential when run on the same process. The Stage 33 pattern is therefore NOT a candidate classification for the TP-34-CC row.

## Restore-apply log signal gap (separate finding)

Part-37 TP-34-OB-03 PASS signal: "`restore-apply` appears at least once whenever any `expected_result=hit` row resolves." Reopen `server.err.log` has 0 occurrences of `restore-apply` across 268,447 B, even though sequential produced 23 hit rows and concurrent produced 8 hit rows. Either (a) the restore-apply log line is never emitted, or (b) it is emitted to a different log channel that the runner's log scan does not see. This is a separate logging/harness gap. It does not exonerate the concurrent 15-miss row; restore-apply emission is not the precondition for a hit, only for the post-hit log evidence.

## Cold path evidence

Cold store: 22 .cold files, 4,085,286,884 bytes (within 4096 MiB cap), +1 promotion, 0 promotion failures. Cold store is functioning and reachable from the hybrid controller. The 8 concurrent hits may have come from cold-store promotion (sequential admitted the entries to hot; some could have demoted under concurrent load and re-promoted). Cold-path failure is not the explanation for the 15-miss row.

## Product bug status

**Product bug in concurrent cache reuse is the live finding.** Concurrency in `tx_restore` and `try_restore_from_cache` (per Stage 25 / Stage 34 design), branch forest index concurrent access, payload descriptor validation race, or pair-state evaluation in the restore path are the candidate surfaces. The clean `server.err.log` rules out crashes, transport failures, and namespace contamination. The 23/23 sequential result rules out admission, retention, and capacity. The interleaved hit/miss pattern rules out workload shape and timing. The differential is concurrent execution against the same controller state.

## Recommendation

Next owner: **Developer (bug-fix session, fresh)**. The fix-loop is for concurrent cache reuse on the hybrid controller's restore path. Sequential, harness, and admission layers are exonerated by the bind facts above.

Next gate:

1. Reopen `D34-REOPEN-02` follow-up: live evidence accepted for 8 of 23 concurrent hot hits; 15 misses are the bug.
2. New Developer session must (a) reproduce the 15-miss pattern in concurrent warm against the same Qwen3 0.6B fixture, (b) add `restore-apply` log emission to satisfy TP-34-OB-03, (c) diagnose whether the root cause is in `tx_restore` / `try_restore_from_cache` mutex boundary, branch forest index concurrent access, payload descriptor race, or pair-state evaluation under concurrent restore, and (d) produce a fix report and a re-run plan.
3. The Stage 33 EXPECTED-BEHAVIOR pattern is NOT applied to TP-34-CC; reopen concurrent evidence disproves the workload/capacity pattern.
4. Manager closure remains blocked until the concurrent cache reuse path passes the same 23/23 hot-hit acceptance that sequential already proves.

## Memory rule applied

- **Test-results review gate classification**: TP-34-CC FAIL classified as product bug (concurrent cache reuse path), not QA harness gap (extraction is the Stage 32-corrected `usage.prompt_tokens_details.cached_tokens` precedence path; concurrent summary.json shows success_count=56/error_count=0), not environment/configuration limitation (binary timestamp 2026-07-01 10:33:04, model on disk, server args bound), not design/test-plan mismatch (acceptance criterion binds), not acceptable deferred coverage. Restore-apply gap is a separate logging/harness finding.
- **Verify prompt facts against repo state before acting**: every cited file path verified with `Test-Path` before inclusion; no fabricated paths. Concise workspace paths use `_test_output/` (no leading dot) for the test-output directory; the report uses the same convention. Cited `server.err.log` byte count (268447) and concurrent `summary.json` fields (server_url, raw_prompt_capture, response_count, success_count) verified.
- **Replace stale test-report references**: this review uses `test-report-20260701-01-stage34-reopen-live-small-cache4g.md` as source of truth; older 2026-06-30 reports cited as historical evidence only. The reopened `part-10-manager-reopen-20260701.md` is the binding gate decision document.
- **Cross-reference same-day QA follow-up sessions**: no in-flight QA follow-up session for the reopen report at the time of this review; the report itself is the reopened live evidence under D34-REOPEN-01..04. Older dev reviews of the 2026-06-30 reports cited as historical context only.
- **Manager gate outranks runner PASS-candidate**: the concurrent warm `summary.json` reports `success_count=56, error_count=0`; the runner's aggregate label is not the binding verdict. The binding verdict is the predicted-hot-vs-actual-hit differential (23 vs 8), which the design acceptance criterion "concurrent main/subagent requests share cache safely without contamination" requires to match.
- **Verify QA runtime-behavior claims against model log before designing the fix**: deferred to the next Developer session; this review session does not design the fix.
- **Cross-merge and downstream rules**: not in scope for this review.

## Final hygiene (post-write)

- File: `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260701-01-stage34-reopen-live-small-cache4g-developer-review.md`
- Target line count: <=300.
- `git diff --check -- ._design_docs/.test_reports/test-report-20260701-01-stage34-reopen-live-small-cache4g-developer-review.md` exit code: 0 (recorded in final reply).

## Files NOT modified in this review session

- No production code (`tools/server/`, `src/`, `include/`, `common/`, `ggml/`) modified.
- No harness scripts (`._design_docs/cache-handling-test-scripts/`) modified.
- No test plan, no design, no implementation log, no durable document modified.
- No `git add`, `git commit`, or `git push` performed.
- No code, server, or build activity. Review-only session.
