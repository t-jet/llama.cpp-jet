# Cache stage tracker

This tracker summarizes every stage of the alternate hybrid cache mode in one table. New tasks and future stages are appended as additional rows; existing rows are updated as the work advances. It is the single source of truth for the current state of the cache architecture work.

## Contents

This document is a single page under the 300-line cap. No part files are needed.

## How to use this tracker

Each row is one stage or task. The Manager owns row updates. The table is the single source of truth for the current state of the cache architecture work. Adding a new row does not require changing the architecture or design docs.

## Workflow rule

All development work happens on the `work-branch` branch. The Manager will not merge to `master` without explicit user request.

Current branch detection result from `git branch --show-current`:

````text
work-branch
````

## Stage summary

| Stage | Title | Status | Design doc | Implementation log | Latest test report | Manager gate decision | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Mode Gate and Controller Interface | closed | [cache-handling-phase1-design.md](cache-handling-phase1-design.md) | [cache-handling-phase1-implementation.md](cache-handling-phase1-implementation.md) | - | 2026-05-24 | Architecture Part 4 baseline; treated as closed by Stage 4 prerequisites |
| 2 | Prepared-Prompt Boundary Metadata | closed | [cache-handling-phase1-design.md](cache-handling-phase1-design.md) | [cache-handling-phase1-implementation.md](cache-handling-phase1-implementation.md) | - | 2026-05-24 | Boundary capture completed under Phase 1 and Phase 2 boundary-metadata pass |
| 3 | Non-Destructive Exact Blob Cache | closed | [cache-handling-phase3-design.md](cache-handling-phase3-design.md) | [cache-handling-phase3-implementation.md](cache-handling-phase3-implementation.md) | - | 2026-05-26 | Production integration addendum in design Part 3 and implementation Part 15 |
| 4 | LRU Eviction Policy with Protected Roots | closed | [cache-handling-phase4-design.md](cache-handling-phase4-design.md) | [cache-handling-phase4-implementation.md](cache-handling-phase4-implementation.md) | [.test_reports/test-report-20260527-08.md](.test_reports/test-report-20260527-08.md) | 2026-05-27 | H30-H39 accepted; no product bug |
| 5 | Payload-Metadata Separation and Target/Draft Pairing | closed | [cache-handling-phase5-design.md](cache-handling-phase5-design.md) | [cache-handling-phase5-implementation.md](cache-handling-phase5-implementation.md) | [.test_reports/test-report-20260528-09.md](.test_reports/test-report-20260528-09.md) | 2026-05-28 | BUG-002 restore timing QA confirmation 2026-05-28 with Qwen3.5 MTP fixture |
| 6 | Cold Layer and Asynchronous I/O | closed | [cache-handling-phase6-design.md](cache-handling-phase6-design.md) | [cache-handling-phase6-implementation.md](cache-handling-phase6-implementation.md) | [.test_reports/test-report-20260530-03.md](.test_reports/test-report-20260530-03.md) | 2026-05-30 | All 10 test steps PASS |
| 7 | Branch Graph Foundation | closed | [cache-handling-phase7-design.md](cache-handling-phase7-design.md) | [cache-handling-phase7-implementation.md](cache-handling-phase7-implementation.md) | [.test_reports/test-report-20260531-01.md](.test_reports/test-report-20260531-01.md) | 2026-05-31 | PASS 20, FAIL 0, SKIP 0, BLOCKED 0 |
| 8 | Metadata-Only Nodes and Re-Materialization | closed | [cache-handling-phase8-design.md](cache-handling-phase8-design.md) | [cache-handling-phase8-implementation.md](cache-handling-phase8-implementation.md) | [.test_reports/test-report-20260601-04.md](.test_reports/test-report-20260601-04.md) | 2026-06-01 | S8-IMPL-01..03 correction pass 2026-06-01 |
| 9 | Checkpoint Integration and Workload Profiles | closed | [cache-handling-phase9-design.md](cache-handling-phase9-design.md) | [cache-handling-phase9-implementation.md](cache-handling-phase9-implementation.md) | [.test_reports/test-report-20260602-01.md](.test_reports/test-report-20260602-01.md) | 2026-06-02 | Q112 bug-fix loop closed; public Q102/Q103 checkpoint evidence closed |
| 10 | Observability, Security Review, and Hardening | closed | [cache-handling-phase10-design.md](cache-handling-phase10-design.md) | [cache-handling-phase10-implementation.md](cache-handling-phase10-implementation.md) | [.test_reports/test-report-20260603-05.md](.test_reports/test-report-20260603-05.md) | 2026-06-04 | T114 0.8521 PASS, T121 MTP probe PASS after S10-IMPL-01 |
| 11 | Upstream Merge Integration | closed | [cache-handling-phase11-design.md](cache-handling-phase11-design.md) | [cache-handling-phase11-implementation.md](cache-handling-phase11-implementation.md) | [.test_reports/test-report-20260607-02.md](.test_reports/test-report-20260607-02.md) | 2026-06-07 | Cap-fix cycle CLOSED 2026-06-07; invariant in architecture Part 7 |
| 12 | Stress Testing and Benchmarking | closed | [cache-handling-phase12-design.md](cache-handling-phase12-design.md) | [cache-handling-phase12-implementation.md](cache-handling-phase12-implementation.md) | [.test_reports/test-report-20260609-02-V2-bench.md](.test_reports/test-report-20260609-02-V2-bench.md) | 2026-06-07 | Operational stage; synthetic matrix stopped 2026-06-09 by Manager decision |
| 13 | Endpoint Compatibility Corrections | closed | [cache-handling-phase13-design.md](cache-handling-phase13-design.md) | [cache-handling-phase13-implementation.md](cache-handling-phase13-implementation.md) | [.test_reports/test-report-20260610-04.md](.test_reports/test-report-20260610-04.md) | 2026-06-10 | E13-14 bounded diagnostic and E13-16 clean-build gate met |
| 14 | Post-Stage-12/13 Upstream Integration | closed | [cache-handling-phase14-design.md](cache-handling-phase14-design.md) | [cache-handling-phase14-implementation.md](cache-handling-phase14-implementation.md) | - | 2026-06-12 | Manager closure 2026-06-12 by user direction. Target: upstream integration done. Stale header status in implementation log and missing closing test report retained per user instruction "without any other modification" |
| 15 | Full Test Suite Validation, Bug-Fix Loop, and Benchmark Report | closed | [cache-handling-phase15-design.md](cache-handling-phase15-design.md) | [cache-handling-phase15-implementation.md](cache-handling-phase15-implementation.md) | [.test_reports/stage15-benchmark-20260613-03.md](.test_reports/stage15-benchmark-20260613-03.md) | 2026-06-13 | Manager closure 2026-06-13. All 8 benchmark rows PASS. B05/B06 fixed: checkpoint boundary search relaxed (V2 fixture 29/29 restores, p50=913ms p99=981ms, see stage15-benchmark-20260613-03.md). B02 PASS-observed-zero (4 checkpoint metrics exposed). T114 0.8992 T114a 0.8284 T115 T121 PASS. S01..S08 and L01..L03 DEFERRED-OUT-OF-SCOPE-FOR-SESSION. Code change: tools/server/server-cache-hybrid.cpp. Architect fix review PASS (part-07). |
| 16 | Post-Closure Chat-Path Prompt-Span Boundary Fix | closed | [cache-handling-phase15-design/part-09](cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md) | [cache-handling-phase15-implementation/part-08](cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md) | [.test_reports/test-report-20260616-03.md](.test_reports/test-report-20260616-03.md) | 2026-06-16 (closure) | Stage 15 post-closure follow-up (2026-06-16), third-diff extension for the Stage 15 B05/B06 fix (chat-path boundary coverage gap; MTP /v1/chat/completions path). Test plan part-26 created and reviewed PASS 2026-06-16. Test execution FAIL iter 1 (F-16-TR-02), PASS after iter 1 bug fix (per-checkpoint boundaries). Test execution FAIL iter 2 (F-16-TR-06 matching loop), PASS after iter 2 bug fix (matching loop relaxation for `metadata == "prompt"` boundaries; [part-05](cache-handling-phase16-implementation/part-05-bugfix-iteration-2-mtp-matching.md)) + iter 3 compile fix ([part-07](cache-handling-phase16-implementation/part-07-bugfix-iteration-3-compile-fix.md)). Test execution rerun 2 PASS 2026-06-16 ([test-report-20260616-03](.test_reports/test-report-20260616-03.md)). All 7 operational rows PASS (TP-15-PC1..PC7). 30/30 cache_n=11 on MTP chat-completion (was 0/30 pre-fix). 0 admission_skipped warnings (was 10/10 pre-fix). 1 cache_checkpoint_admissions_total (was 0). Manager decision D-16-1 preemptive (not invoked). Developer test-results review PASS ([test-report-20260616-03-developer-review](.test_reports/test-report-20260616-03-developer-review.md), 0 product bugs, retest scope none). Manager decision A APPLIED: reclassify B02/B05/B06 to IN-SCOPE for MTP fixture (TP-15-PC1..PC4 PASS confirms structural root cause fixed on MTP). Manager decision B RESOLVED: test plan part-26 created. Manager decision C RESOLVED: benchmark data captured in test-report-20260616-03.md (no separate benchmark file needed). Code changes UNCOMMITTED (user approval required per AGENTS.md): commit `ae2df9657` (Option A fix) + uncommitted changes (per-checkpoint boundaries + matching loop relaxation + compile fix). Deferred non-blocking: F-16-TR-03 (coverage /Zi), F-16-TR-01 (UT1/UT2 test code), F-16-BF-01 (trailing whitespace in developer.md), F-16-BF-09 (design part-09 at 354 lines, over 300 cap). Architect/Developer follow-up for deferred items. |
| 17 | Agentic Cache Reuse, Cold Budget, and Checkpoint Policy | closed | [cache-handling-phase17-design.md](cache-handling-phase17-design.md) | [cache-handling-phase17-implementation.md](cache-handling-phase17-implementation.md) | [.test_reports/test-report-20260617-01.md](.test_reports/test-report-20260617-01.md) | 2026-06-17 (closure) | Manager closure 2026-06-17. All design/plan/implementation/test gates PASS. Test execution FAIL on F-17-EXEC-01 (STATUS_STACK_BUFFER_OVERRUN, validation order bug) and F-17-EXEC-02 (13 missing unit tests); both resolved by bug-fix loop iteration 1 with verification deferred per Architect Option B. Test-results review PASS 2026-06-17 ([test-report-20260617-01-developer-review](.test_reports/test-report-20260617-01-developer-review.md), 12 PASS / 14 RESOLVED / 14 BLOCKED-acceptable / 0 FAIL). Code changes UNCOMMITTED (user approval required per AGENTS.md): tools/server/server-context.cpp (validation block move +40 lines), tests/test-cache-controller.cpp (13 new unit tests +389 lines). Implemented `--cache-cold-max-mib`, `--cache-prompt-evidence`, `--cache-prompt-evidence-dir`, JSONL redacted evidence, bounded restore-miss accounting, unsafe prefix rejection without prefix restore, cold budget skip-before-write/accounting, and bounded metrics. Follow-ups: D17-EXEC-02 system-level model warmup crash (separate stage), D17-EXEC-03 remove duplicate cold-path-hybrid check, F-16-TR-03 add /Zi /DEBUG to CMAKE_CXX_FLAGS_RELEASE, add agentic prompt generator for synthetic tier, add Qwen3.6-27B-MTP fixture for heavy tier, re-invoke S01..S08 / L01..L03 framework for stress-longrun tier.

## Future stages and new tasks

Use this template when the Manager adds a new row. Keep column order, header text, and cell content style the same as the table above.

````markdown
| Stage | Title | Status | Design doc | Implementation log | Latest test report | Manager gate decision | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| N+1 | Short stage title here | pending | - | - | - | pending | One short line of context |
````

### How to add a new row

1. Append a row to the "Stage summary" table in the same order, using the template above.
2. Update `document-index.md` if a new entry document is created.
3. Reference the new row in the next Manager status handoff.
