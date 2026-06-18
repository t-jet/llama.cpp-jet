# Part 4: Stage 18 design review (Architect, fresh session)

Status: PASS
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Reviewer: Architect (design review, fresh session)
Scope: Stage 18 design review only. Not re-review of Stage 17 or any
other stage.

## Inputs reviewed

| File | Lines | Notes |
| --- | --- | --- |
| _design_docs/cache-handling-phase18-design.md | 84 | Entry doc |
| _design_docs/cache-handling-phase18-design/part-01-item1-duplicate-cold-path-hybrid-check.md | 120 | Item 1 design |
| _design_docs/cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md | 164 | Item 2 design |
| _design_docs/cache-handling-phase18-design/part-03-test-plan-traceability-risks-handoff.md | 76 | Test plan rows, traceability, risks, handoff |

Reference (read for context):

- _design_docs/cache-handling-phase17-implementation.md (Manager decisions D17-EXEC-03, D17-CLOSURE-02)
- _design_docs/cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md (N17-BUGFIX-01)
- _design_docs/.test_reports/test-report-20260617-01.md (Coverage BLOCKED-coverage-setup section)
- _design_docs/cache-handling-stage-tracker.md (Stage 18 row)

Verification commands executed:

- `Select-String -Path tools/server/server-context.cpp -Pattern 'cache-cold-path requires --cache-mode hybrid'` confirmed two matches at lines 1419-1420 (canonical moved block) and 1555-1556 (duplicate in post-slot-init block). Surrounding if-block at lines 1553 (outer guard), 1554-1557 (inner if-block including SRV_ERR/throw/closing brace) verified by direct read.
- `Test-Path build-cov/CMakeCache.txt` returned True. `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` at line 80 confirmed. `CMAKE_C_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` at line 98. `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG` at line 83.
- `git check-ignore build-cov/CMakeCache.txt build-cov` returned both paths, confirming build-cov is gitignored.
- `Select-String` against _design_docs/cache-handling-test-scripts/*.ps1 found build-cov referenced as the build directory by run-stage15-bench-batch.ps1, run-v1-bench-batch.ps1, run-v2-bench-batch.ps1, run-v2-stress-longrun-sequential.ps1, kickoff-v2-bench.ps1, kickoff-v2-stress-longrun.ps1, kickoff-v3-sequential-stress-longrun.ps1. Existing scripts use the build-cov/bin/Release/ paths unchanged.
- `(Get-Content tests/test-cache-controller.cpp | Select-String -Pattern '^void test_').Count` = 89 (74 pre-Stage 17 + 15 Stage 17 test_stage17_* functions).

## Verification checklist

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Item 1 scope of deletion: lines identified correctly | PASS | Design cites lines 1554-1557 for the inner if-block. Select-String and read_file confirm lines 1554 (inner if), 1555 (SRV_ERR), 1556 (throw), 1557 (closing brace). The design correctly notes drift from the older N17-BUGFIX-01 citation (1548-1551) and D17-EXEC-03 closure decision (1548-1551), which were accurate when those documents were authored. |
| 2 | Item 1 surrounding code preserved | PASS | Outer `if (!params_base.cache_cold_path.empty())` at line 1553 stays. Cold-budget log lines 1558-1565 stay. The `// Phase 6: Validate cold path configuration` comment at line 1552 is explicitly addressed in the Comment disposition subsection; the design recommends removing or rewriting it (Developer choice, not a design blocker). |
| 3 | Item 1 behavior change analysis | NON-BLOCKING | Safe path analysis is correct. The unsafe-path claim that the duplicate is "unreachable in practice" is technically imprecise. The moved block at lines 1419-1420 rejects only when `cache_cold_max_mib != 0 && !cache_cold_path.empty() && cache_mode_val != CACHE_MODE_HYBRID`. The duplicate check at lines 1555-1556 (inside `if (!params_base.cache_cold_path.empty())`) catches the case where `cache_cold_path` is set and `cache_mode_active != HYBRID` regardless of `cache_cold_max_mib`. After deletion, the narrow edge case `--cache-cold-path set, --cache-cold-max-mib 0, --cache-mode legacy` would silently proceed rather than erroring. This is a minor behavioral change for an unusual configuration; deletion is still reasonable for the common case. |
| 4 | Item 1 tests proposed | PASS | TP-18-FT1 (build + run test-cache-controller), TP-18-FT2 (git diff --check), TP-18-FT3 (Select-String count of the duplicate string), TP-18-IT1 (server start with cold-path + legacy mode), TP-18-IT2 (server start with hybrid mode), TP-18-IT3 (re-run Stage 17 IT5). 6 rows total (3 focused + 3 integration). The "byte-identical" wording in the design is slightly imprecise (the moved block has additional conditions on `cache_cold_max_mib != 0` and `!cache_cold_path.empty()` that the duplicate does not have); the SRV_ERR and throw messages are byte-identical. |
| 5 | Item 1 risk analysis | PASS | Risks table covers the comment disposition and the build-cov reconfigure cache. No open questions. The corner case described in finding #3 is not explicitly raised; the design's claim of "unreachable in practice" obscures it. Recommend the Developer re-verify the corner case during implementation and update the test plan row TP-18-IT1 evidence if behavior changes. |
| 6 | Item 2 option chosen and rationale | PASS | Option 1 (cmake -DCMAKE_CXX_FLAGS_RELEASE addition) selected. Rationale covers minimum scope, minimum script change, max optimization retention, clean separation, reversibility, and lowest risk profile. Options 2, 3, 4 evaluated with explicit impact and risk notes. |
| 7 | Item 2 Release build performance and binary size | PASS | Design notes /Zi and /DEBUG:FULL are compatible with /O2; runtime performance unaffected; PDB and binary grow modestly. |
| 8 | Item 2 existing test regression risk | PASS | Design states tests still pass; debug info does not change runtime behavior. Coverage scripts use build-cov/bin/Release/ paths unchanged. Confirmed by Select-String against cache-handling-test-scripts/*.ps1. |
| 9 | Item 2 OpenCppCoverage output | PASS | Will produce line counts in .cov files instead of header-only .cov. T114, T114a, T115 contracts become measurable. test-report-20260617-01.md Coverage section confirms the BLOCKED-coverage-setup state. |
| 10 | Item 2 CI/build configuration impact | PASS | One cmake reconfigure of build-cov with the new flags. Other build directories (build, build-cuda) are unaffected. build-cov is gitignored (verified by `git check-ignore`), so the cmake invocation is the durable record. |
| 11 | Item 2 tests proposed | PASS | TP-18-FT4 (CMakeCache.txt CMAKE_CXX_FLAGS_RELEASE), TP-18-FT5 (CMakeCache.txt CMAKE_FLAGS_RELEASE for C), TP-18-FT6 (rebuild test-cache-controller), TP-18-FT7 (rebuild llama-server + /health), TP-18-IT4 (re-run OpenCppCoverage), TP-18-IT5 (run coverage-manual end-to-end), TP-18-IT6 (chat completion with MTP fixture). 7 rows total (4 focused + 3 integration). |
| 12 | Scope alignment with Manager decisions | PASS | Item 1 maps to D17-EXEC-03 (remove duplicate cold-path-hybrid check). Item 2 maps to D17-CLOSURE-02 / F-16-TR-03 (add /Zi /DEBUG to CMAKE_CXX_FLAGS_RELEASE for coverage). Both decisions are from the Stage 17 closure (2026-06-17). |
| 13 | Non-goals explicit | PASS | D17-EXEC-02 (system-level model warmup crash) and Stage 17 test infrastructure additions are explicitly out of scope, deferred to Stage 19 and Stage 20 respectively per the tracker row. |
| 14 | Prerequisites documented | PASS | Stage 17 closure on 2026-06-17, F-17-EXEC-01 validation block move (part-06 review), build-cov/CMakeCache.txt:80, and existing test scripts using build-cov are all referenced. |
| 15 | Test plan rows coverage adequate | PASS | 13 rows proposed (7 focused + 6 integration) covering both items. The focus vs integration split is reasonable. TP-18-IT3 explicitly carries forward Stage 17 IT5 evidence, providing regression coverage. |
| 16 | Traceability maps each item to source decision | PASS | Traceability table in part-03 maps Item 1 to D17-EXEC-03 and Item 2 to D17-CLOSURE-02 / F-16-TR-03, with source-evidence citations. |
| 17 | Risks and open questions owners specific | PASS | Five risks in part-03 (comment disposition, reconfigure cache, PDB artifact budget, coverage script path, downstream agents, gitignore for build-cov). Mitigation specified for each. One open question requiring Manager input: none. |
| 18 | Document quality under 300 lines per part | PASS | Entry doc 84 lines, part-01 120 lines, part-02 164 lines, part-03 76 lines. All under the 300-line cap. |
| 19 | Document quality LF only, no CRLF | PASS | byte-level inspection of all four files: CR count = 0, LF count matches Get-Content count. No CRLF. |
| 20 | Document quality no UTF-8 BOM | PASS | First 3 bytes of each file are 0x23 0x20 (start of title line), no UTF-8 BOM. |
| 21 | Document quality no unicode icons | PASS | Em-dash count 0, en-dash count 0, ellipsis count 0, smart quotes 0, total non-ASCII count 0 in all four files. |

## Findings

| # | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-18-DR-01 | NON-BLOCKING | Duplicate check reachable when cache_cold_max_mib is 0 | Item 1 design Behavior change analysis subsection; moved block at server-context.cpp:1419-1420 checks `cache_cold_max_mib != 0 && !cache_cold_path.empty() && cache_mode_val != CACHE_MODE_HYBRID`; duplicate at lines 1554-1557 checks only `cache_mode_active != CACHE_MODE_HYBRID` inside `if (!params_base.cache_cold_path.empty())`. After deletion, `--cache-cold-path X --cache-cold-max-mib 0 --cache-mode legacy` would not error. | Developer confirms via focused test or post-impl evidence whether the corner case is intentionally suppressed (cold writes disabled makes the cold-path config dead anyway) or whether the behavior change should be documented. No design change required; this is a Developer verification item. |
| F-18-DR-02 | NON-BLOCKING | Test count claim off by 2 | Item 2 design Coverage-build behavior change analysis claims "All 87 tests pass (74 existing + 13 Stage 17)." Actual count is 89 (74 pre-Stage 17 + 15 Stage 17 test_stage17_* functions in tests/test-cache-controller.cpp). | Developer updates TP-18-FT1 and TP-18-FT6 expected outcomes to "89/89 PASS (74 + 15)" or whatever count the implementation evidence reports. No design change required. |
| F-18-DR-03 | NON-BLOCKING | "Byte-identical" wording imprecise | Item 1 design Current state subsection says "byte-identical check that runs BEFORE slot init." The SRV_ERR message and throw string are byte-identical, but the moved block has additional conditions on `cache_cold_max_mib != 0` and `!cache_cold_path.empty()` that the duplicate does not have. | Developer rewords to "same SRV_ERR message and same throw string" during implementation; no design change required. |
| F-18-DR-04 | INFO | CMAKE_BUILD_TYPE flag is no-op for Visual Studio generator | Item 2 cmake invocation includes `-DCMAKE_BUILD_TYPE=Release`, but build-cov uses Visual Studio 18 2026 generator (multi-config, ignores CMAKE_BUILD_TYPE). The flag is harmless but redundant. | No change required; the cmake invocation remains functionally correct. Developer notes this in implementation evidence. |

## Counts

- BLOCKING: 0
- Non-blocking: 3
- INFO: 1

## Verdict

**PASS.** Both items in the Stage 18 design are correctly scoped to the
source Manager decisions (D17-EXEC-03 and D17-CLOSURE-02 / F-16-TR-03),
both code-change scopes are accurate against the current state of
server-context.cpp and build-cov/CMakeCache.txt, both options analyses
are sound (Option 1 is the minimum-scope choice), and the proposed test
plan rows (13 total, 7 focused + 6 integration) provide adequate
focused and regression coverage. The four findings are all
non-blocking or INFO and represent wording imprecision or facts the
Developer should verify during implementation, not design defects. The
design is reviewable, the document set is under the 300-line cap, all
files are LF-only UTF-8 without BOM, and there are no unicode icons or
hidden assumptions.

## Handoff

Next owner: **Manager** for the design gate in a fresh session.

If Manager design gate PASS, the design advances to Developer for
implementation planning and implementation. The Stage 17 implementation
log, tracker, document-index, and any other durable doc are NOT
modified by this review. The four non-blocking findings are tracked
above as Developer verification items; they do not block Manager gate
review or implementation authorization.
