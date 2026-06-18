VERDICT: REWORK

# Stage 18 implementation review (Architect, fresh session)

Status: REWORK
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Reviewer: Architect (implementation review, fresh session)
Scope: Stage 18 implementation review only. Not design re-review, not plan
re-review, not test plan authoring, not test execution, not Manager gate.
Inputs: [part 3 implementation evidence](part-03-implementation-evidence.md)
PARTIAL (Item 1 PASS, Item 2 BLOCKED on linker-flag propagation).

## Scope and gate status

| Item | Stage gate | Verdict | Reason |
| --- | --- | --- | --- |
| Item 1 (delete duplicate cold-path-hybrid check) | Implementation review | PASS | Deletion scope matches plan; surrounding code preserved; 89/89 tests pass; F-18-DR-01 corner case empirically closed by a different check at server-context.cpp:1411-1414. |
| Item 2 (add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE for build-cov) | Implementation review | BLOCKED | Implementation was correct per the approved plan, but the plan itself is incomplete for the Visual Studio generator. The single-flag change in `CMAKE_CXX_FLAGS_RELEASE` does not propagate to linker flags; PDB is not generated; OpenCppCoverage produces header-only `.cov` with no line data. T114, T114a, T115 closure contracts remain BLOCKED-coverage-setup. |

Overall verdict: **REWORK** with Option A (plan amendment + Developer
re-iteration). Item 1 is accepted; Item 2 requires a plan amendment that
adds the three linker flag variables and removes (or relocates) the
mis-translated `/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE`, followed by
a follow-up Developer session to apply the amendment and re-verify the
OpenCppCoverage line-data contract.

## Inputs reviewed

| File | Lines | Notes |
| --- | --- | --- |
| _design_docs/cache-handling-phase18-implementation/part-03-implementation-evidence.md | 232 | Developer's evidence file, PARTIAL |
| _design_docs/cache-handling-phase18-implementation/part-01-implementation-plan.md | 274 | Approved plan |
| _design_docs/cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md | 164 | Item 2 design (Option 1 chosen) |
| _design_docs/cache-handling-phase18-design/part-04-design-review-gate-01.md | 99 | Design review (PASS, 0 BLOCKING, 3 non-blocking, 1 INFO) |

Reference (read for context):

- tools/server/server-context.cpp lines 1378-1570 (verified post-Item 1 state)
- build-cov/CMakeCache.txt (verified post-Item 2 state)
- build-cov/tests/test-cache-controller.vcxproj (verified VS generator translation)
- _design_docs/.test_reports/test-report-20260617-01.md (Coverage BLOCKED-coverage-setup section)
- _design_docs/cache-handling-stage-tracker.md (Stage 18 row)
- _design_docs/cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md (N17-BUGFIX-01)

Verification commands executed:

- `git diff HEAD --stat -- tools/server/server-context.cpp` -> `5 deletions(-)`, exactly the comment at line 1552 plus the inner if-block at lines 1554-1557.
- `git diff HEAD -- tools/server/server-context.cpp` -> hunk @@ -1549,12 +1549,7 @@ with 5 lines removed and 0 lines added; no other changes to this path.
- `git diff --check HEAD -- tools/server/server-context.cpp` -> exit 0, empty output (no CRLF, no trailing whitespace).
- `Select-String -Path tools/server/server-context.cpp -Pattern 'cache-cold-path requires --cache-mode hybrid'` -> 2 matches at lines 1419-1420 (canonical moved block). 0 matches outside that range.
- `Select-String -Path tools/server/server-context.cpp -Pattern 'Phase 6: Validate cold path configuration'` -> 0 matches. Comment removed cleanly.
- `Select-String -Path tools/server/server-context.cpp -Pattern 'cache-cold-max-mib requires --cache-mode hybrid'` -> 2 matches at lines 1413-1414. Confirms the different validation check that catches the F-18-DR-01 corner case.
- `Get-Content build-cov/CMakeCache.txt | Select-String -Pattern 'CMAKE.*FLAGS_RELEASE|CMAKE.*FLAGS_RELWITHDEBINFO|CMAKE.*LINKER_FLAGS'` -> 20+ matches. Line 80 `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL` (correct), line 83 `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG` (unchanged, correct), line 98 `CMAKE_C_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL` (correct), line 116 `CMAKE_EXE_LINKER_FLAGS_RELEASE:STRING=/INCREMENTAL:NO` (unchanged, this is the substantive gap), line 192 `CMAKE_MODULE_LINKER_FLAGS_RELEASE:STRING=/INCREMENTAL:NO` (unchanged, gap), line 248 `CMAKE_SHARED_LINKER_FLAGS_RELEASE:STRING=/INCREMENTAL:NO` (unchanged, gap).
- `Select-String -Path build-cov/tests/test-cache-controller.vcxproj -Pattern 'DEBUG:FULL|PreprocessorDefinitions|DebugInformationFormat|GenerateDebugInformation'` -> confirms VS generator split: Release ClCompile has `<DebugInformationFormat>ProgramDatabase</DebugInformationFormat>` (line 153, /Zi propagated) and `<PreprocessorDefinitions>...NDEBUG;EBUG:FULL;...` (line 167, leading slash stripped, define corrupted); Release Link has `<GenerateDebugInformation>false</GenerateDebugInformation>` (line 188, linker not told to generate PDB) and `<ProgramDataBaseFile>...test-cache-controller.pdb</ProgramDataBaseFile>` (line 193, path set but not written).
- `Get-ChildItem -Recurse -Path build-cov/bin/Release -Filter 'test-cache-controller*'` -> 1 file: test-cache-controller.exe (907776 bytes). No .pdb on disk.
- `(Get-Content tests/test-cache-controller.cpp | Select-String -Pattern '^void test_').Count` -> 89 (74 pre-Stage 17 + 15 test_stage17_*). `(Get-Content tests/test-cache-controller.cpp | Select-String -Pattern '^void test_stage17_').Count` -> 15.
- `git check-ignore -v build-cov build-cov/CMakeCache.txt` -> `.gitignore:46:/build* build-cov` and `.gitignore:46:/build* build-cov/CMakeCache.txt`. Both paths gitignored; the cmake invocation is the durable record.

## Verification checklist

### Item 1 (delete duplicate cold-path-hybrid check)

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Deletion scope matches plan: lines 1552 (comment) and 1554-1557 (inner if-block) | PASS | `git diff --stat` shows 5 deletions, exactly the comment + 4-line inner if-block. No additions. No other lines changed on this path. |
| 2 | Surrounding code preserved: outer guard at 1553, log lines 1558-1565 (post-state), moved block at 1419-1420 | PASS | Direct read confirms line 1553 `if (!params_base.cache_cold_path.empty()) {` retained, log lines for cold store path and cold budget retained, moved block at 1419-1420 (the canonical SRV_ERR + throw) retained. |
| 3 | `git diff --check` clean (no CRLF, no trailing whitespace) | PASS | `git diff --check HEAD -- tools/server/server-context.cpp` exit 0, empty output. |
| 4 | Focused tests 89/89 PASS | PASS | Developer's evidence records `build-cov\bin\Release\test-cache-controller.exe` exit 0, 89 PASSED, 0 FAILED. The 89 count is independently verified by `Select-String -Pattern '^void test_'` = 89. |
| 5 | Build exit codes 0/0 for test-cache-controller and llama-server | PASS | Developer's evidence records both rebuilds exit 0 with log evidence. |
| 6 | F-18-DR-01 corner case empirically closed (rejected by different check at 1411-1414) | PASS | Developer's evidence includes the empirical probe: `llama-server --model Qwen3-0.6B-Q8_0.gguf --cache-mode legacy --cache-cold-path ... --cache-cold-max-mib 0 --port 18182` produced `E srv load_model: - cache: --cache-cold-max-mib requires --cache-mode hybrid` and exit code -1073740791 (Windows __fastfail from uncaught std::runtime_error at lines 1413-1414). The corner case IS still rejected with a bounded error and non-zero exit code. The acceptance criterion for F-18-DR-01 (cold-path set, cold-max-mib 0, mode legacy) is met. |
| 7 | No regression in test-cache-controller or llama-server | PASS | 89/89 tests pass post-deletion. No new warnings in rebuild log. The corner case is still caught (item 6). |

### Item 2 (add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE for build-cov)

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 8 | CMakeCache.txt line 80: `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL` | PASS | Direct read: line 80 contains exactly this value. |
| 9 | CMakeCache.txt line 98: `CMAKE_C_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL` | PASS | Direct read: line 98 contains exactly this value. |
| 10 | CMakeCache.txt line 83: `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG` UNCHANGED | PASS | Direct read: line 83 still `/O2 /Ob1 /DNDEBUG`. RelWithDebInfo is not affected. |
| 11 | Build exit codes 0/0 for test-cache-controller and llama-server (post-rebuild) | PASS | Developer's evidence records both rebuilds exit 0; all C++ TUs recompiled with /Zi. |
| 12 | Focused tests 89/89 PASS post-rebuild | PASS | Developer's evidence records `build-cov\bin\Release\test-cache-controller.exe` exit 0, 89 PASSED, 0 FAILED. Runtime behavior unchanged by the flag update. |
| 13 | OpenCppCoverage smoke test result: .cov file is line-data, larger than header-only baseline | **BLOCKED** | Developer's evidence: .cov file 111 bytes, header-only listing of loaded modules, NO line data. OpenCppCoverage warning: "No modules were selected. Please check the values of --modules and --excluded_modules." PDB for test-cache-controller.exe does NOT exist on disk (verified by Get-ChildItem). The T114/T114a/T115 closure contracts remain BLOCKED-coverage-setup. |
| 14 | Root cause: Visual Studio generator does NOT propagate /Zi /DEBUG:FULL to linker flags; /DEBUG:FULL mis-translated as /D EBUG:FULL preprocessor define | **CONFIRMED** | Direct read of build-cov/tests/test-cache-controller.vcxproj Release config: (a) `<DebugInformationFormat>ProgramDatabase</DebugInformationFormat>` (line 153) confirms /Zi propagated to compile but not to link; (b) `<PreprocessorDefinitions>...NDEBUG;EBUG:FULL;...` (line 167) confirms /DEBUG:FULL mis-translated as preprocessor define with leading slash stripped; (c) `<GenerateDebugInformation>false</GenerateDebugInformation>` (line 188) confirms linker not told to generate PDB; (d) `<ProgramDataBaseFile>...test-cache-controller.pdb</ProgramDataBaseFile>` (line 193) is set but not written. CMAKE_EXE_LINKER_FLAGS_RELEASE (line 116), CMAKE_MODULE_LINKER_FLAGS_RELEASE (line 192), CMAKE_SHARED_LINKER_FLAGS_RELEASE (line 248) all unchanged at `/INCREMENTAL:NO` (no /debug). |

### Substantive findings

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 15 | Is the VS generator propagation issue a design gap or implementation gap? | DESIGN GAP | The design part 2 (Item 2) chose Option 1: add `/Zi /DEBUG:FULL` to `CMAKE_CXX_FLAGS_RELEASE` for build-cov. The plan followed the design exactly. The implementation followed the plan exactly. The implementation is correct per the plan; the plan (and the design) did not anticipate that the Visual Studio multi-config generator splits compile and link flag variables. The single-flag approach is fundamentally incomplete for the VS generator. |
| 16 | Should the plan be amended with linker flags (CMAKE_EXE_LINKER_FLAGS_RELEASE, CMAKE_SHARED_LINKER_FLAGS_RELEASE, CMAKE_MODULE_LINKER_FLAGS_RELEASE) and /DEBUG:FULL removed from CMAKE_CXX_FLAGS_RELEASE? | YES | The minimum-scope fix is: (a) append `/debug /DEBUG:FULL` to each of the three `*_LINKER_FLAGS_RELEASE` variables; (b) remove `/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` and `CMAKE_C_FLAGS_RELEASE` (keep only `/Zi`, since `/DEBUG:FULL` is a linker-only flag for the VS generator). This makes Option 1 work for the VS multi-config generator. |
| 17 | Or should Item 2 be deferred to a follow-up stage? | NO (not recommended) | T114, T114a, T115 are closure contracts carried forward from Stage 10. Deferral would leave these contracts BLOCKED-coverage-setup indefinitely, blocking full Stage 17 closure in the test-results view. A plan amendment is the right path because the fix is small (one cmake invocation expansion) and reversible. |
| 18 | What is the minimum fix to make OpenCppCoverage produce line data? | Add the three `*_LINKER_FLAGS_RELEASE` variables with `/debug /DEBUG:FULL`; remove `/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` and `CMAKE_C_FLAGS_RELEASE` (keep only `/Zi`). See corrected cmake invocation in F-18-IR-01 evidence. | See F-18-IR-01 evidence section; minimum scope is three linker flag lines. |

### Test count correction (F-18-IMPL-01)

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 19 | Test binary's "Total: 87 tests" string is stale cosmetic text; actual count is 89 (74 + 15) | NON-BLOCKING, ACCEPT-AS-IS | Direct verification: 89 test function definitions in tests/test-cache-controller.cpp (74 pre-Stage 17 + 15 test_stage17_*), and 89 test invocations in main(). The test runner reports PASS for all 89. The "Total: 87 tests" string in the binary's own summary is a stale literal from before Stage 17 test additions. It is cosmetic text in the test binary itself, not in the test runner. The test binary functions correctly. The string should be corrected in a follow-up edit to tests/test-cache-controller.cpp's main() summary, but it does not block the gate. |

## Findings

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-18-IR-01 | BLOCKING | Visual Studio generator does not propagate /Zi /DEBUG:FULL to linker flags; PDB not generated; OpenCppCoverage line-data contract T114/T114a/T115 NOT unblocked | build-cov/tests/test-cache-controller.vcxproj Release config: `<DebugInformationFormat>ProgramDatabase</DebugInformationFormat>` (line 153, /Zi propagated to compile), `<PreprocessorDefinitions>...NDEBUG;EBUG:FULL;...` (line 167, /DEBUG:FULL mis-translated to preprocessor define with leading slash stripped), `<GenerateDebugInformation>false</GenerateDebugInformation>` (line 188, linker not told to generate PDB). CMakeCache.txt lines 116, 192, 248 (three `*_LINKER_FLAGS_RELEASE`) unchanged at `/INCREMENTAL:NO`. No .pdb on disk for test-cache-controller.exe. OpenCppCoverage .cov file is 111 bytes header-only with no line data. | Plan amendment: add `-DCMAKE_EXE_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL" -DCMAKE_SHARED_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL" -DCMAKE_MODULE_LINKER_FLAGS_RELEASE="/INCREMENTAL:NO /debug /DEBUG:FULL"` and remove `/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` and `CMAKE_C_FLAGS_RELEASE` (keep `/Zi`). Manager plan-amendment gate, then Developer re-iteration. |
| F-18-IR-02 | NON-BLOCKING (Item 1) | F-18-DR-01 corner case IS still rejected, but by a different validation check at server-context.cpp:1411-1414 | `cache_cold_max_mib != -1 && cache_mode_val != CACHE_MODE_HYBRID` (server-context.cpp:1411) fires before the post-slot-init block runs, producing `E srv load_model: - cache: --cache-cold-max-mib requires --cache-mode hybrid` and exit code -1073740791. The F-18-DR-01 finding is closed by empirical evidence, not by the deleted duplicate. | None. The deletion is safe; the corner case is still caught with a bounded error. Document this empirical closure in the design part 1 "Behavior change analysis" subsection for durable traceability. |
| F-18-IR-03 | NON-BLOCKING (Item 1) | Test binary's trailing summary string says "Total: 87 tests" while 89 tests actually run and PASS | tests/test-cache-controller.cpp: the binary's own summary line in main() is stale relative to the actual test count. Test runner correctly reports 89 PASS, 0 FAIL. | None for this gate. Cosmetic follow-up edit to main() summary string in tests/test-cache-controller.cpp. Defer to a follow-up Developer session. |
| F-18-IR-04 | INFO (Item 2) | /DEBUG:FULL mis-translated by VS generator into a /D preprocessor define for the symbol EBUG:FULL (leading slash dropped) | build-cov/tests/test-cache-controller.vcxproj line 167 Release config PreprocessorDefinitions. Benign (unused preprocessor symbol) but indicates flag-string syntax needs review. | None for this gate. Resolved automatically by F-18-IR-01 plan amendment (move /DEBUG:FULL out of CXX/C flags into linker flags). |

## Counts

- BLOCKING: 1
- Non-blocking: 2
- INFO: 1

## Verdict

**REWORK.**

Item 1 (delete duplicate cold-path-hybrid check) is accepted as PASS.
The deletion scope matches the plan (5 lines removed), surrounding code
is preserved, `git diff --check` is clean, 89/89 focused tests pass, the
F-18-DR-01 corner case is empirically closed by a different validation
check at server-context.cpp:1411-1414, and no regression is observed in
test-cache-controller or llama-server.

Item 2 (add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE for build-cov)
is BLOCKED. The implementation was correctly executed per the approved
plan: CMakeCache.txt lines 80, 83, 98 are in the correct state, both
binaries rebuilt and 89/89 tests pass. However, the design's Option 1
approach (add to CMAKE_CXX_FLAGS_RELEASE only) is fundamentally
incomplete for the Visual Studio multi-config generator, which splits
compile and link flag variables. The build-cov/tests/test-cache-controller.vcxproj
Release config shows: /Zi propagated to `<DebugInformationFormat>` (compile
side), /DEBUG:FULL mis-translated to a preprocessor define `EBUG:FULL`
(benign), and `<GenerateDebugInformation>false</GenerateDebugInformation>`
on the Link side (no PDB). The three `*_LINKER_FLAGS_RELEASE` variables
remain at `/INCREMENTAL:NO` with no `/debug` flag. The PDB is not
generated. The OpenCppCoverage .cov file is 111 bytes, header-only, with
no line data. T114, T114a, T115 closure contracts remain BLOCKED-coverage-setup.

This is a **design/plan gap**, not an implementation error. The
implementation correctly followed the approved plan; the plan itself
did not anticipate the VS generator split between compile and link
flags. The fix is small: amend the plan to add the three linker flag
variables with `/debug /DEBUG:FULL` and remove `/DEBUG:FULL` from the
compile flag variables, then a follow-up Developer session to apply
the amended plan and re-verify the OpenCppCoverage line-data contract.

The test count cosmetic text (F-18-IR-03) is non-blocking and accepted
as-is for this gate; it should be corrected in a follow-up edit to
tests/test-cache-controller.cpp's main() summary.

## Recommended next action

**Option A: REWORK with plan amendment (recommended).** Manager plan-amendment
gate to authorize a small change to the approved plan: add the three
`*_LINKER_FLAGS_RELEASE` variables with `/debug /DEBUG:FULL` and remove
`/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` and `CMAKE_C_FLAGS_RELEASE`.
Then a follow-up Developer session (fresh) to apply the amended plan:
remove CMakeFiles, reconfigure cmake with the expanded flag set, full
rebuild of test-cache-controller and llama-server, run focused tests
(89/89 PASS expected), run OpenCppCoverage smoke test, confirm .cov
file is larger than header-only baseline and contains line-count data.

Option B (REWORK with implementation re-do, same plan) is NOT
recommended: the implementation was correct per the plan; re-doing
with the same plan will produce the same result.

Option C (accept Item 2 as blocked, defer to follow-up stage) is NOT
recommended: T114, T114a, T115 closure contracts would remain
BLOCKED-coverage-setup indefinitely, blocking full Stage 17 closure.
A plan amendment is the right path because the fix is small and
reversible.

## Handoff

Next owner: **Manager** for the plan-amendment gate in a fresh session.

If Manager plan-amendment gate PASS, the amended plan advances to a
Developer implementation session (fresh session, work-branch) for
Item 2 re-iteration. Item 1 is closed. The amended plan must add the
three linker flag variables and remove `/DEBUG:FULL` from the compile
flag variables, then re-wipe CMakeFiles, reconfigure, rebuild,
re-test, and re-run OpenCppCoverage until the line-data contract is
satisfied (T114, T114a, T115 become measurable).

The Stage 17 implementation log, tracker, document-index, design, test
plan, and any other durable doc are NOT modified by this review. The
implementation evidence file (part 3) is not modified. The
F-18-IR-03 test count cosmetic text is a separate follow-up edit,
deferred to a Developer session in a different stage or to this
stage's closure.

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable doc cap.
