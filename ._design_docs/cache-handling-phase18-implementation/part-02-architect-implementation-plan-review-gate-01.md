VERDICT: PASS

# Stage 18 implementation plan review (Architect, fresh session)

Status: PASS
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Reviewer: Architect (implementation-plan review, fresh session)
Scope: Stage 18 implementation-plan review only. Not design re-review, not
implementation, not test plan authoring, not test execution.

## Inputs reviewed

| File | Lines | Notes |
| --- | --- | --- |
| _design_docs/cache-handling-phase18-implementation.md | 274 | Plan under review |
| _design_docs/cache-handling-phase18-design.md | 130 | Design entry (PASS at Manager design gate 2026-06-18) |
| _design_docs/cache-handling-phase18-design/part-01-item1-duplicate-cold-path-hybrid-check.md | 120 | Item 1 design |
| _design_docs/cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md | 164 | Item 2 design |
| _design_docs/cache-handling-phase18-design/part-03-test-plan-traceability-risks-handoff.md | 76 | Test plan rows proposed |
| _design_docs/cache-handling-phase18-design/part-04-design-review-gate-01.md | 99 | Design review (Architect PASS, 0 BLOCKING, 3 non-blocking, 1 INFO) |

Reference (read for context):

- _design_docs/cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md (N17-BUGFIX-01)
- _design_docs/.test_reports/test-report-20260617-01.md (Coverage BLOCKED-coverage-setup section)
- tools/server/server-context.cpp lines 1384-1600 (verified plan line numbers)
- build-cov/CMakeCache.txt (verified plan cmake flag line numbers)
- tests/test-cache-controller.cpp (verified 89 test functions)

Verification commands executed:

- `Get-Content ... | ForEach-Object { $line++; if (...) ... }` confirmed two matches of the duplicate cold-path-hybrid text at lines 1419-1420 (moved block) and 1555-1556 (post-slot-init duplicate). Inner if at 1554, closing brace at 1557. `// Phase 6: Validate cold path configuration` at line 1552.
- `Get-Content build-cov/CMakeCache.txt | ForEach-Object { $line++ }` confirmed: line 80 `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`, line 83 `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG`, line 98 `CMAKE_C_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`. Line 83 is the canonical RelWithDebInfo line and stays unchanged.
- `(Get-Content tests/test-cache-controller.cpp | Select-String -Pattern '^void test_').Count` returned 89 (74 pre-Stage 17 + 15 Stage 17 functions). Plan's 89/89 figure is correct.
- `git check-ignore build-cov/CMakeCache.txt build-cov` returned both paths, confirming build-cov is gitignored.
- `git log --oneline -3 -- tools/server/server-context.cpp build-cov/CMakeCache.txt` shows HEAD is 23a1d4593 on work-branch.
- `git status --short -- _design_docs/cache-handling-phase18-implementation.md` shows `??` (untracked, freshly authored by Developer planning session).
- Byte-level inspection of plan file: CR=274, LF=274 (CRLF format); design files CR=0, LF matches line count (LF-only).

## Verification checklist

### Plan structure

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Approved design baseline referenced explicitly | PASS | Plan lines 11-25 hyperlink the entry doc, all 4 design parts, the 2 Manager decisions, architecture, requirements, and test plan |
| 2 | Manager decisions D17-EXEC-03 and D17-CLOSURE-02 / F-16-TR-03 referenced as binding | PASS | Plan lines 21-25 cite both decisions verbatim with file and line references |
| 3 | Design-review non-blocking findings F-18-DR-01..04 addressed in plan | PASS | Plan "Design-review findings to address in plan" table covers all 4 findings with explicit resolution text and where the resolution lands in plan steps or evidence |
| 4 | Code surfaces (files affected) named correctly | PASS | Plan "Code surfaces" section names server-context.cpp, build-cov/CMakeCache.txt, tests/test-cache-controller.cpp, and both rebuilt .exe binaries; all paths verified to exist |
| 5 | Affected files map to planned steps | PASS | Item 1 steps 1.1-1.9 reference server-context.cpp paths; Item 2 steps 2.1-2.9 reference build-cov/CMakeCache.txt and the two .exe paths |
| 6 | Test plan rows referenced from design part 3 | PASS | Plan "Test plan reference" table lists 13 rows (7 focused + 6 integration) with the same IDs and brief descriptions as design part 3; total matches |

### Item 1 plan quality

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 7 | Deletion scope lines 1554-1557 verified against current server-context.cpp | PASS | Direct read confirmed line 1554 is the inner `if (cache_mode_active != CACHE_MODE_HYBRID) {`, line 1555 is SRV_ERR, line 1556 is throw, line 1557 is closing brace. Plan correctly identifies the 4-line inner if-block |
| 8 | Surrounding code preservation: outer guard at 1553, log lines 1558-1565, moved block at 1417-1420 | PASS | Direct read confirmed line 1553 is `if (!params_base.cache_cold_path.empty()) {`, lines 1558-1565 are the cold-budget log block. The plan's "moved block at lines 1417-1420" is slightly imprecise: the if-condition is at 1416-1418, SRV_ERR at 1419, throw at 1420; the design part 1 uses "lines 1419-1420" (the SRV_ERR/throw lines). The imprecision is sub-line and does not affect deletion scope. Plan step 1.3 explicitly forbids touching 1410-1430 |
| 9 | Comment disposition at line 1552 addressed (remove or rewrite) | PASS | Plan step 1.4 specifies removal of the `// Phase 6: Validate cold path configuration` comment, citing the design's preference for removal. Line 1552 confirmed by direct read |
| 10 | Compile-clean guarantee (no new variables introduced; pure deletion) | PASS | Plan step 1.3 deletes only the inner if-block (4 lines); step 1.4 removes one comment. No new declarations, no new locals. The surrounding outer guard at 1553 and log block 1558-1565 stay as-is, preserving the existing block structure |
| 11 | Step ordering: deletion before tests | PASS | Plan Item 1 step 1.3 applies the deletion, step 1.4 removes the comment, steps 1.6-1.7 build test-cache-controller and llama-server, step 1.8 runs the test binary. Tests cannot run against a build that does not yet reflect the deletion |
| 12 | Evidence commands specified (build, test, git diff) | PASS | Plan steps 1.6, 1.7, 1.8, 1.9 specify cmake --build for both targets, direct binary invocation with expected 89/89, and `git diff HEAD -- tools/server/server-context.cpp` with expected 5-line removal scope |
| 13 | Corner case F-18-DR-01 verification (cache_cold_max_mib=0 path) handled | PASS | Plan "Post-implementation evidence (F-18-DR-01 resolution)" subsection and step 1.6 commit the corner case to evidence: actual server exit code and error message recorded; silent-proceed behavior is acceptable per the design (cold writes disabled makes the config dead); TP-18-IT1 verifies the corner case explicitly |

### Item 2 plan quality

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 14 | CMake command syntax correct for Visual Studio generator | PASS | Plan step 2.3 uses `cmake -B build-cov -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_FLAGS_RELEASE=... -DCMAKE_C_FLAGS_RELEASE=...` which is correct syntax for VS multi-config. PowerShell backtick line continuation matches the design part 2 sample |
| 15 | CMAKE_CXX_FLAGS_RELEASE and CMAKE_C_FLAGS_RELEASE both updated | PASS | Plan step 2.3 sets both `-DCMAKE_CXX_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL"` and `-DCMAKE_C_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL"`. TP-18-FT4 and TP-18-FT5 verify each flag set separately |
| 16 | CMAKE_CXX_FLAGS_RELWITHDEBINFO at line 83 explicitly preserved unchanged | PASS | Plan "Code surfaces" section states "Line 83 `CMAKE_CXX_FLAGS_RELWITHDEBINFO` is NOT modified." Step 2.4 verification specifies line 83 unchanged. Line 83 confirmed by direct read |
| 17 | CMakeCache.txt line 80/98 verification specified | PASS | Plan step 2.4 reads lines 78-100 and asserts line 80 contains `/Zi /DEBUG:FULL` and line 98 contains the same for C flags. Both line numbers verified by direct read against current build-cov/CMakeCache.txt |
| 18 | Clean rebuild step specified (5-10 min compilation time acknowledged) | PASS | Plan "Build freshness" subsection and step 2.5 explicitly call out 5-10 minute compile time, CMakeFiles wipe prerequisite, and the role of step 2.3 reconfigure |
| 19 | OpenCppCoverage smoke test specified | PASS | Plan step 2.8: "Quick OpenCppCoverage smoke test: run OpenCppCoverage against test-cache-controller.exe with --export_type binary and confirm the .cov file is larger than the header-only baseline (>100 KB per binary) and contains line-count data." Falls back to TP-18-IT4 if OpenCppCoverage is unavailable |
| 20 | No changes to other build directories (build, build-cuda) | PASS | Plan "Out of scope" subsection lists "Any other build directory (build, build-cuda, etc.)" as not in scope. The cmake invocation targets only build-cov |
| 21 | No changes to CMakePresets.json or root CMakeLists.txt | PASS | Plan "Out of scope" subsection lists "CMakePresets.json or root CMakeLists.txt" as not in scope. The plan changes only the build-cov cmake invocation, not the project-level config |

### Evidence and test plan

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 22 | Test count uses 89/89 (corrected from F-18-DR-02) | PASS | Plan uses 89/89 throughout (steps 1.8, 2.7; TP-18-FT1, TP-18-FT6). Verified by direct count of test functions in tests/test-cache-controller.cpp = 89. The design's "87 tests pass (74 + 13)" wording is correctly replaced with "89 tests pass (74 + 15)" in the plan |
| 23 | Test plan rows 13 referenced (7 focused + 6 integration) | PASS | Plan "Test plan reference" table lists 13 rows; design part 3 also lists 13 rows; the IDs (TP-18-FT1..FT7, TP-18-IT1..IT6) match the design exactly |
| 24 | Build and test commands specified | PASS | Plan specifies `cmake --build build-cov --config Release --target test-cache-controller -j 4` (steps 1.6, 2.5), `cmake --build build-cov --config Release --target llama-server -j 4` (steps 1.7, 2.6), direct binary invocation (steps 1.8, 2.7) |
| 25 | Expected outcomes for each step | PASS | Each step in the plan has an explicit "Expect ..." line. Outcomes are concrete: exit code, line count, .cov size, /health response, or specific Select-String count |

### Risks and handoff

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 26 | Design-review findings F-18-DR-01..04 carried forward as Developer verification items | PASS | Plan "Design-review findings to address in plan" table maps each finding to a specific plan section, step, or evidence path. F-18-DR-01 lands in step 1.6 and TP-18-IT1; F-18-DR-02 lands in steps 1.8 and 2.7; F-18-DR-03 lands in plan phrasing; F-18-DR-04 lands in plan step 2.3 with no-op note |
| 27 | New risks identified (if any) with mitigations | PASS | Plan "Known risks" table lists 7 risks: corner-case behavior, reconfigure cache loss, PDB size, coverage script path, CMakeFiles wipe, gitignore, and step-sequencing dependency. Each has impact and mitigation. Trigger is implicit in the risk description; impact and mitigation are explicit |
| 28 | Handoff section names next owner | PASS | Plan "Handoff" section: "Next owner: Architect for implementation-plan review in a fresh session. If Architect implementation-plan review PASS, the plan advances to Manager for the implementation-plan gate. After Manager implementation gate PASS, the plan advances to implementation in this or a follow-up Developer session." |

### Document quality

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 29 | Under 300 lines | PASS | True line count via `(Get-Content).Count` = 274. `Measure-Object -Line` = 232 (counts only non-empty lines). Both under the 300-line cap. The task brief quotes the Measure-Object value (232) which is the standard reporter output in this workspace |
| 30 | LF line endings (no CRLF) | FAIL | Plan has CR=274, LF=274 (CRLF format). The 5 design files in this stage are LF-only (CR=0, LF matches line count per the part-04 design review). The convention is enforced on the design tree; the plan does not follow it |
| 31 | No unicode icons | PASS | Byte-level scan: em-dash=0, en-dash=0, ellipsis=0, smart-quotes=0, total non-ASCII=0 |
| 32 | Plain ASCII status labels | PASS | Status line "Status: authored; pending Architect implementation-plan review" uses semicolons (ASCII) and plain English; reviewer line is plain text; section headings use standard `#` markdown |

## Findings

| # | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-18-IPR-01 | NON-BLOCKING | Plan has CRLF line endings instead of LF-only | Byte-level inspection: CR=274, LF=274 (CRLF). The 5 design files in this stage are LF-only (CR=0, LF matches line count per design review part 4). The durable-doc convention requires LF-only. CRLF is a known Windows tool-inserted artifact. | Developer converts the plan file to LF-only UTF-8 (no BOM) before commit, using `[System.IO.File]::ReadAllBytes` + filter `0x0D` + `[System.IO.File]::WriteAllBytes`. Verify with byte-level CR=0 check. Mechanical fix; no content change. Do not block the gate on this finding. |

## Counts

- BLOCKING: 0
- Non-blocking: 1
- INFO: 0

## Verdict

**PASS.** The Stage 18 implementation plan is correct, complete, and ready
for Manager implementation-plan gate review. All 32 checklist items are
satisfied except one Windows tool-inserted artifact (CRLF line endings,
F-18-IPR-01), which is a mechanical fix that does not require re-review.

The plan correctly maps both items to the source Manager decisions
(D17-EXEC-03 and D17-CLOSURE-02 / F-16-TR-03), verifies all code-change
scopes against the current state of server-context.cpp and build-cov/
CMakeCache.txt, addresses all four design-review non-blocking findings
(F-18-DR-01..04), and proposes the 13 test plan rows (7 focused + 6
integration) referenced from design part 3.

Item 1 (deletion of duplicate cold-path-hybrid check) is sound: the
4-line inner if-block (lines 1554-1557) is correctly identified, the
outer guard at 1553 and the cold-budget log block at 1558-1565 stay
intact, the moved validation block at 1416-1420 stays intact, the
`// Phase 6: Validate cold path configuration` comment at line 1552 is
dispositioned (remove), and the F-18-DR-01 corner case
(`--cache-cold-max-mib 0` + legacy mode) is committed to evidence
(TP-18-IT1 + step 1.6) with an explicit STOP-and-escalate if the server
errors.

Item 2 (`/Zi /DEBUG:FULL` flag addition for build-cov) is sound: the
cmake reconfigure command is correct for the Visual Studio 18 2026
multi-config generator, both CXX and C flag sets are updated, line 83
RelWithDebInfo is explicitly preserved unchanged, the 5-10 minute
rebuild time is acknowledged, the OpenCppCoverage smoke test is
specified, and the change is scoped to build-cov only with no impact on
build, build-cuda, CMakePresets.json, or root CMakeLists.txt.

The test plan row count is corrected from the design's 87/89
imprecision to 89/89 (verified by direct count of test functions in
tests/test-cache-controller.cpp = 89 = 74 pre-Stage 17 + 15 Stage 17).

The plan carries forward 7 risks with concrete mitigations, names the
next owner explicitly, and stays under the 300-line durable-doc cap
(274 lines via `(Get-Content).Count`).

## Required corrections

- F-18-IPR-01: convert plan file to LF-only UTF-8 (no BOM) before commit.
  Mechanical fix; not blocking the gate.

## Handoff

Next owner: **Manager for the implementation-plan gate in a fresh session.**

If Manager implementation-plan gate PASS, the plan advances to a
Developer implementation session (fresh session, work-branch). The
Developer session should fix F-18-IPR-01 (LF-only conversion) as part
of the first commit on this plan, before any code work.

The Stage 17 implementation log, tracker, document-index, design,
test plan, and any other durable doc are NOT modified by this review.
This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap.
