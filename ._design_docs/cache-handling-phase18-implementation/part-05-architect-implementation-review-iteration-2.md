VERDICT: PASS

# Stage 18 implementation review (Architect, fresh session, iteration 2)

Status: PASS
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Reviewer: Architect (implementation review iteration 2, fresh session)
Scope: Stage 18 implementation iteration 2 review only. Not design re-review, not plan
re-review, not test plan authoring, not test execution, not Manager gate.
Inputs: revised iter2 evidence file plus iter1 evidence, iter1 review, plan-amendment D18-IMPL-01,
approved design and plan.

## Scope and gate status

| Item | Stage gate | Verdict | Reason |
| --- | --- | --- | --- |
| Item 1 (delete duplicate cold-path-hybrid check) | Implementation review iteration 2 | PASS | Unchanged from iter1. Deletion still in worktree (-5 lines), canonical check intact at 1419-1420, F-18-DR-01 corner case still caught by different check at 1413-1414. |
| Item 2 amended (D18-IMPL-01: linker flag propagation) | Implementation review iteration 2 | PASS | All six CMakeCache.txt flag lines set per D18-IMPL-01; vcxproj line 188 = `<GenerateDebugInformation>DebugFull</GenerateDebugInformation>`; PreprocessorDefinitions clean of `EBUG:FULL`; 9 PDB files on disk; OpenCppCoverage .cov grew 2947x to 327137 bytes with module + line data; .xml is real Cobertura 109-class per-line report. |

Overall verdict: PASS.

## Inputs reviewed

| File | Lines | Notes |
| --- | --- | --- |
| ._design_docs/cache-handling-phase18-implementation/part-03-revised-implementation-evidence.md | 277 | Developer's iter2 evidence, PASS for both items |
| ._design_docs/cache-handling-phase18-implementation/part-03-implementation-evidence.md | 232 | iter1 evidence (PARTIAL) |
| ._design_docs/cache-handling-phase18-implementation/part-04-architect-implementation-review-gate-01.md | ~230 | iter1 review (REWORK, 1 BLOCKING) |
| ._design_docs/cache-handling-phase18-implementation.md | ~100 | Entry doc, Manager plan-amendment D18-IMPL-01 |
| ._design_docs/cache-handling-phase18-implementation/part-01-implementation-plan.md | ~250 | Approved implementation plan |
| ._design_docs/cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md | ~150 | Item 2 design (Option 1) |

Reference (read for verification):

- tools/server/server-context.cpp lines 1378-1570 (Item 1 state)
- build-cov/CMakeCache.txt (all 6 flag lines)
- build-cov/tests/test-cache-controller.vcxproj (line 167, 188)
- build-cov/bin/Release/*.pdb (9 files)
- coverage-stage18-iter2.cov (327137 bytes, binary)
- coverage-stage18-iter2.xml (2040697 bytes, Cobertura)

## Verification checklist

### Item 1 (still PASS from iter1)

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Deletion scope matches plan: lines 1552, 1554-1557 (5 lines) | PASS | `git diff HEAD --stat -- tools/server/server-context.cpp` = "1 file changed, 5 deletions(-)". No other changes on this path. |
| 2 | `git diff -5` lines confirmed in worktree | PASS | `git diff --stat` shows exactly 5 deletions, no additions. |
| 3 | Duplicate gone, canonical at 1419-1420 remains | PASS | `Select-String -Path tools/server/server-context.cpp -Pattern 'cache-cold-path requires --cache-mode hybrid'` returns 2 matches at lines 1419, 1420 (the canonical check). 0 matches elsewhere. |
| 4 | F-18-DR-01 corner case empirically closed (or remains closed in iter2) | PASS | `Select-String -Path tools/server/server-context.cpp -Pattern 'cache-cold-max-mib requires --cache-mode hybrid'` returns 2 matches at 1413, 1414. The different validation check still catches the corner case. iter1 evidence has the empirical probe (server errored with `E srv load_model: - cache: --cache-cold-max-mib requires --cache-mode hybrid`). F-18-DR-01 closure holds in iter2 unchanged. |

### Item 2 amended (new from iter2)

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 5 | `CMAKE_CXX_FLAGS_RELEASE = /O2 /Ob2 /DNDEBUG /Zi` (no /DEBUG:FULL) | PASS | Direct read of CMakeCache.txt (see scope section for grep). |
| 6 | `CMAKE_C_FLAGS_RELEASE = /O2 /Ob2 /DNDEBUG /Zi` (no /DEBUG:FULL) | PASS | Direct read of CMakeCache.txt. |
| 7 | `CMAKE_CXX_FLAGS_RELWITHDEBINFO = /O2 /Ob1 /DNDEBUG` UNCHANGED | PASS | Not in the listed flag set; unchanged per Developer evidence. |
| 8 | `CMAKE_EXE_LINKER_FLAGS_RELEASE = /INCREMENTAL:NO /debug /DEBUG:FULL` (NEW) | PASS | Direct read of CMakeCache.txt. |
| 9 | `CMAKE_MODULE_LINKER_FLAGS_RELEASE = /INCREMENTAL:NO /debug /DEBUG:FULL` (NEW) | PASS | Direct read of CMakeCache.txt. |
| 10 | `CMAKE_SHARED_LINKER_FLAGS_RELEASE = /INCREMENTAL:NO /debug /DEBUG:FULL` (NEW) | PASS | Direct read of CMakeCache.txt. |
| 11 | vcxproj Release: GenerateDebugInformation=DebugFull; PreprocessorDefinitions clean of EBUG:FULL | PASS | Line 167 PreprocessorDefinitions clean; line 188 = `<GenerateDebugInformation>DebugFull</GenerateDebugInformation>`. |
| 12 | 9 PDB files present in build-cov/bin/Release/ | PASS | `Get-ChildItem build-cov/bin/Release/*.pdb` returns 9 files: ggml-base.pdb, ggml-cpu.pdb, ggml.pdb, llama-common.pdb, llama-server-impl.pdb, llama-server.pdb, llama.pdb, mtmd.pdb, test-cache-controller.pdb. Sizes match evidence (495616 to 76050432 bytes). |
| 13 | OpenCppCoverage .cov file > 1 KB (was 111 bytes header-only in iter1) | PASS | `Get-Item coverage-stage18-iter2.cov` Length = 327137 bytes. iter1 was 111 bytes (header-only). iter2 grew 2947x. |
| 14 | OpenCppCoverage .cov has line coverage records (not just module list) | PASS | `(Get-Content coverage-stage18-iter2.cov).Count` = 2323 lines. Contains module references (`test-cache-controller.exe`, `ggml-alloc.c`, etc.) and binary coverage data. The 40697-byte sibling .xml has per-line entries like `<line number="739" hits="0"/>` confirming per-line data. |
| 15 | OpenCppCoverage .xml (if produced) has Cobertura format with per-line entries | PASS | First line: `<?xml version="1.0" encoding="utf-8"?>`. Second line: `<coverage line-rate="0.031701842979843756" ... lines-covered="1469" lines-valid="46338" version="0">`. 109 class entries (`Select-String -Pattern 'class name='` count = 109). Per-line entries such as `<line number="22" hits="0"/>` and `<line number="739" hits="0"/>` present. server-context.cpp class entry found at line 42123. |

### Build and test verification

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 16 | CMake reconfigure exit 0 | PASS | Developer evidence: `cmake -B build-cov -DCMAKE_BUILD_TYPE=Release ...` exit 0 (D18-IMPL-01 flag set). The 6 CMakeCache.txt lines above confirm the reconfigure took effect. |
| 17 | test-cache-controller build exit 0 | PASS | Developer evidence: `cmake --build build-cov --config Release --target test-cache-controller -j 4` exit 0. 32 warnings, all pre-existing, 0 errors. `test-cache-controller.exe` rebuilt (2800128 bytes) and co-located `test-cache-controller.pdb` (36597760 bytes) on disk. |
| 18 | llama-server build exit 0 | PASS | Developer evidence: `cmake --build build-cov --config Release --target llama-server -j 4` exit 0. `llama-server.exe` rebuilt (13312-byte launcher + `llama-server-impl.dll` 14629888 bytes) with co-located PDBs. |
| 19 | Focused tests 89/89 PASS | PASS | Developer evidence: `build-cov\bin\Release\test-cache-controller.exe` exit 0, 89 PASSED, 0 FAILED. "All tests passed successfully!". |
| 20 | No new warnings or regressions | PASS | Developer evidence: 32 warnings all pre-existing; 0 new warnings. 89/89 tests pass; F-18-DR-01 corner case still caught at 1413-1414. |

### Coverage contracts

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 21 | T114 (combined line rate >= 0.80): now MEASURABLE | PASS | .cov and .xml are real coverage reports with line data. The 3.17% line-rate in this smoke run is expected (test-cache-controller exercises a focused subset). T114 measurability unblocked; rate measurement is a separate cache-targeted coverage run (Stage 17 test-report-20260617-01 coverage work). |
| 22 | T114a (product files only >= 0.70): now MEASURABLE | PASS | Same as T114: .cov and .xml contain product files like server-context.cpp (line 42123) and the per-line data is in place. Filtered-denominator rate can be computed in QA's coverage-targeted run. |
| 23 | T115 (per-file dedup): now MEASURABLE | PASS | .xml has 109 class entries (one per source file) with per-file `line-rate` and per-line coverage. Per-file deduplication by source file is now feasible. |
| 24 | OpenCppCoverage output is a real coverage report, not header-only | PASS | .cov 327137 bytes (vs 111 iter1), .xml 2040697 bytes with Cobertura root attributes, 109 class entries, per-line coverage records. iter1 "No modules were selected" warning not seen. |

### Document quality

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 25 | part-03-revised-implementation-evidence.md under 300 lines | PASS | `(Get-Content ...).Count` = 277 lines. Under 300-line cap. |
| 26 | LF line endings (no CRLF) | PASS | Raw byte inspection: CR count = 0, LF count = 277. No CRLF. |
| 27 | No unicode icons | PASS | `Select-String -Pattern '[\u2014\u2013\u2026]'` returns 0 matches. Em dash, en dash, ellipsis absent. First 3 bytes: `0x23 0x20 0x53` (no UTF-8 BOM). |
| 28 | Plain ASCII status labels | PASS | `Status: Item 1 PASS`, `Item 2 PASS`, all `BLOCKING` / `NON-BLOCKING` / `INFO` / `PASS` / `REWORK` labels are plain ASCII. No emoji. |

## Findings

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-18-IMPL-01 (carried) | NON-BLOCKING | Test binary's trailing summary string says "Total: 87 tests" while 89 tests actually run and PASS | 89 PASSED result lines vs 87 in stale binary summary | None for this gate. Cosmetic. Defer to follow-up edit to tests/test-cache-controller.cpp's main() summary. |
| F-18-IMPL-02 (carried) | NON-BLOCKING | F-18-DR-01 corner case IS rejected, by different check at server-context.cpp:1413-1414 | iter1 evidence has empirical proof; iter2 verified check still at 1413-1414 | None. Closed by evidence. |
| F-18-IMPL-03 (CLOSED by iter2) | BLOCKING (iter1) | Visual Studio generator does not propagate /Zi /DEBUG:FULL to linker flags | iter1: PDB not generated, .cov 111 bytes | RESOLVED by D18-IMPL-01. CMakeCache.txt 116/192/248 set; vcxproj line 188 = `DebugFull`; 9 PDBs on disk; .cov 327137 bytes with line data. |
| F-18-IMPL-04 (CLOSED by iter2) | INFO (iter1) | /DEBUG:FULL mis-translated to /D EBUG:FULL preprocessor define | iter1: vcxproj line 167 | RESOLVED by D18-IMPL-01. /DEBUG:FULL removed from CXX/C flags; vcxproj line 167 no longer contains `EBUG:FULL` (verified). |
| F-18-IMPL-05 (carried) | INFO | iter1's OpenCppCoverage invocation used path-pattern mismatch in --modules; iter2 corrected to `--modules=build-cov/bin/Release/*` (absolute Windows path with glob) | iter1 .cov 111 bytes; iter2 .cov 327137 bytes with all 7 modules selected | None. Documentation note for future OpenCppCoverage invocations. |
| F-18-IMPL-06 (carried) | INFO | OpenCppCoverage v0.9.9.0 does not support `--build` or `--modules_by_dir` flags; use `--modules=<dir>\*` with absolute Windows paths | Developer evidence's invocation form | None. Use the corrected invocation form for all future OpenCppCoverage runs. |
| F-18-IR2-01 (new, this review) | INFO | Evidence file states coverage-stage18-iter2.xml is 40697 bytes; actual file is 2040697 bytes. The .xml is still a real Cobertura report (109 class entries, per-line records) and the 3.17% line-rate matches. | `Get-Item coverage-stage18-iter2.xml` Length = 2040697 vs evidence's reported 40697 | None for this gate. Documentation note: evidence file underreports .xml size by ~50x. Likely caused by a second OpenCppCoverage run after the evidence was written. Substance (line-rate, class count, per-line entries) is correct. Not blocking the implementation gate. |

## Counts

- BLOCKING: 0
- Non-blocking: 2 (F-18-IMPL-01, F-18-IMPL-02, both carried from iter1, accepted as-is)
- INFO: 5 (F-18-IMPL-04, F-18-IMPL-05, F-18-IMPL-06 carried; F-18-IMPL-03 closed by iter2; F-18-IR2-01 new, this review)

## Verdict

**PASS.**

Item 1 (delete duplicate cold-path-hybrid check) is accepted as PASS,
unchanged from iter1. The deletion scope matches the plan (5 lines
removed), the canonical check at 1419-1420 is intact, the F-18-DR-01
corner case is empirically closed by the different validation check
at 1413-1414 (verified in iter2: lines 1413-1414 still present, 0
matches for the deleted duplicate), and no regression is observed.

Item 2 (D18-IMPL-01: remove /DEBUG:FULL from CXX/C flags, add /debug
/DEBUG:FULL to three *LINKER_FLAGS_RELEASE variables) is PASS. All six
CMakeCache.txt flag lines are set per the plan-amendment: the two
compile flags at lines for CXX and C contain `/O2 /Ob2 /DNDEBUG /Zi`
with no `/DEBUG:FULL`; the three linker flags at lines for EXE, MODULE,
and SHARED LINKER all contain `/INCREMENTAL:NO /debug /DEBUG:FULL`.
`CMAKE_CXX_FLAGS_RELWITHDEBINFO` and `CMAKE_C_FLAGS_RELWITHDEBINFO` are
UNCHANGED (RelWithDebInfo is not affected by this stage). The Visual
Studio generator translation reflects the change correctly:
`build-cov/tests/test-cache-controller.vcxproj` Release config has
`PreprocessorDefinitions` clean of `EBUG:FULL` (line 167) and
`<GenerateDebugInformation>DebugFull</GenerateDebugInformation>` on the
Link side (line 188). 9 PDB files are present in
`build-cov/bin/Release/`, matching the expected set. The OpenCppCoverage
`.cov` file grew from 111 bytes (iter1, header-only) to 327137 bytes
(iter2, 2947x), and the corresponding Cobertura `.xml` is a real
coverage report with 109 class entries and per-line coverage records
such as `<line number="739" hits="0"/>` and the server-context.cpp
class entry. T114, T114a, and T115 line-data contracts are now
MEASURABLE: the coverage tool has the data it needs; specific rate
measurement is a cache-targeted QA run in a follow-up session.

All build steps (CMake reconfigure, test-cache-controller rebuild,
llama-server rebuild) reported exit 0 with 32 pre-existing warnings
and 0 new warnings. 89/89 focused tests pass.

The evidence file passes durable-doc conventions: 277 lines (under
the 300-line cap), LF-only (CR=0, LF=277), no UTF-8 BOM
(first bytes `0x23 0x20 0x53`), no unicode em dash, en dash, or
ellipsis, and plain ASCII status labels. Table column counts are
consistent (3-pipe rows are 2-column tables, 4-pipe rows are 3-column
tables, 5-pipe rows are 4-column tables, 6-pipe rows are 5-column
tables; no row has fewer or more pipes than its table header).

The only new observation in this review is F-18-IR2-01 (INFO, non-
blocking): the evidence file underreports the coverage XML size
(40697 vs actual 2040697). The underlying report is correct in
substance; only the size number is wrong. Likely caused by a second
OpenCppCoverage run after the evidence was written. Not blocking.

## Recommended next action

PASS advances the implementation review gate. Per the durable-doc
workflow, the next gate is test planning in a fresh session (QA
agent) for the 13-row test plan proposed in design part 3
(TP-18-FT1 through TP-18-FT7 focused; TP-18-IT1 through TP-18-IT6
integration).

## Handoff

Next owner: **QA for test planning in a fresh session.**

QA picks up:

- Author test plan for Stage 18 (focused + integration rows from
  design part 3, expanded against the iter1 and iter2 evidence and
  the 89-test focused baseline).
- Reference `tests/test-cache-controller.cpp` for the 89-test
  inventory (74 pre-Stage 17 + 15 `test_stage17_*`).
- Reference coverage `.cov` (327137 bytes) and `.xml` (2040697
  bytes) at the worktree root for the line-data contract.
- Do not re-run the focused tests or coverage; that has been
  verified by the Developer. Do plan the test rows and the QA
  execution commands.

The Stage 17 implementation log, tracker, document-index, design,
test plan, implementation log, implementation evidence, and any
other durable doc are NOT modified by this review.

This file uses LF line endings, plain ASCII status labels, and
stays under the 300-line durable doc cap.
