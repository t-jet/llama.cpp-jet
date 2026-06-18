# Test plan part 28: Stage 18 Stage 17 closure trivial follow-ups

Status: authored; pending QA test-plan review
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Branch: work-branch
Owner: QA (test plan authoring, fresh session)
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: Stage 18 test plan only. Not re-review of design, plan, implementation, or any other stage.

## References

Design:

- [Stage 18 design](../../cache-handling-phase18-design.md)
- [Part 1: Item 1 - remove duplicate cold-path-hybrid check](../../cache-handling-phase18-design/part-01-item1-duplicate-cold-path-hybrid-check.md)
- [Part 2: Item 2 - add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE](../../cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md)
- [Part 3: test plan rows, traceability, risks, handoff](../../cache-handling-phase18-design/part-03-test-plan-traceability-risks-handoff.md) (13-row proposal)
- [Part 4: design review gate 01](../../cache-handling-phase18-design/part-04-design-review-gate-01.md) (PASS, 0 BLOCKING, 3 non-blocking, 1 INFO)

Implementation:

- [Stage 18 implementation](../../cache-handling-phase18-implementation.md) (D18-IMPL-01 amendment)
- [Part 1: implementation plan](../../cache-handling-phase18-implementation/part-01-implementation-plan.md)
- [Part 3-revised: iter 2 evidence](../../cache-handling-phase18-implementation/part-03-revised-implementation-evidence.md)
- [Part 5: implementation review iter 2](../../cache-handling-phase18-implementation/part-05-architect-implementation-review-iteration-2.md) (PASS, 0 BLOCKING, 2 non-blocking, 5 INFO)

Prior test plan parts:

- [Part 7: test report quality and templates](./part-07-test-report-quality-and-templates.md) (evidence and report format)
- [Part 25: Stage 15 full test suite validation](./part-25-stage15-full-test-suite-validation.md) (full-suite and bug-fix loop)
- [Part 26: Stage 16 chat-path prompt-span boundary](./part-26-stage16-chat-path-prompt-boundary.md) (most recent per-stage plan)
- [Part 27: Stage 17 agentic cache reuse](./part-27-stage17-agentic-cache-reuse.md) (previous stage plan)

## Manager decisions (binding)

- D17-EXEC-03: remove the duplicate cold-path-hybrid check at `tools/server/server-context.cpp` lines 1554-1557 in the post-slot-init block. Source: Stage 17 closure 2026-06-17.
- D17-CLOSURE-02 / F-16-TR-03: add `/Zi /DEBUG:FULL` to `CMAKE_CXX_FLAGS_RELEASE` for the `build-cov` build so OpenCppCoverage produces line-count coverage data. Source: Stage 17 closure 2026-06-17 (inherited from Stage 16 closure).

## Manager plan-amendment gate decision (binding)

- D18-IMPL-01: per Manager plan-amendment gate 2026-06-18. The Visual Studio 18 2026 generator does not propagate `/Zi /DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` to the linker; `/DEBUG:FULL` in the compile flag is mis-translated by the VS generator into a `/D EBUG:FULL` preprocessor define (leading slash stripped), and no PDB is generated. The amendment is:
  1. Remove `/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` and `CMAKE_C_FLAGS_RELEASE`. Keep only `/Zi` (Program Database is the correct compile format).
  2. Add `/debug /DEBUG:FULL` to `CMAKE_EXE_LINKER_FLAGS_RELEASE` for executable PDB generation.
  3. Add `/debug /DEBUG:FULL` to `CMAKE_MODULE_LINKER_FLAGS_RELEASE` for static library PDB generation.
  4. Add `/debug /DEBUG:FULL` to `CMAKE_SHARED_LINKER_FLAGS_RELEASE` for shared library PDB generation.

This test plan reflects the post-D18-IMPL-01 state. The 13-row proposal from design part 3 is expanded to 14 rows (8 focused + 6 integration) to cover the three linker flags as well as the two compile flags.

## Scope and exclusions

In scope for Stage 18 test plan:

- Item 1 focused and integration rows: deletion of duplicate cold-path-hybrid check, regression on F-17-EXEC-01 fix, F-18-DR-01 corner case
- Item 2 focused and integration rows: cmake flag state (CXX, C, and three linker flags), rebuild, OpenCppCoverage line-data contract, MTP fixture regression
- Clean-build verification of `test-cache-controller.exe` and `llama-server.exe` with the D18-IMPL-01 flag set
- Coverage setup contract: PDB files present; `.cov` file > 1 KB with line coverage records; Cobertura `.xml` with per-line entries

Out of scope for Stage 18 (deferred or excluded):

- D17-EXEC-02 (system-level model warmup crash, STATUS_STACK_BUFFER_OVERRUN): separate stage (Stage 19) per the tracker row
- Stage 17 test infrastructure additions (agentic prompt generator, Qwen3.6-27B-MTP fixture, S/L framework re-invocation): separate stage (Stage 20) per the tracker row
- Stage 4-9 regression rows (covered by prior stage test plan parts)
- Stage 12/15 S01..S08 and L01..L03 stress-longrun rows (re-uses S/L framework; full re-run deferred)
- Stage 15 B01..B08 benchmark rows (re-uses bench framework; full re-run deferred)
- Stage 16 regression on F-17-EXEC-01 verification deferred path: NOT included in this plan; deferred to Stage 19 or follow-up QA
- Re-review of Stage 17 design, implementation, or any other closed stage
- Changes to other build directories (`build`, `build-cuda`, etc.)
- Modifications to `CMakePresets.json` or root `CMakeLists.txt`

## Test plan rows

### Focused tests

Fixture: `none` for build and diff rows; `build-cov/CMakeCache.txt` for
flag rows. Preconditions: `build-cov` configured with D18-IMPL-01 flag
set; `tests/test-cache-controller.cpp` contains 89 test functions
(74 pre-Stage 17 + 15 Stage 17 `test_stage17_*`); focused test binary
rebuilt cleanly.

| ID | Type | Preconditions | Command | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-18-FT1 | focused | D18-IMPL-01 flags applied; Item 1 deletion applied | `cmake --build build-cov --config Release --target test-cache-controller -j 4`; run `build-cov/bin/Release/test-cache-controller.exe` | build exit 0; binary runs 89/89 PASS (count actual `PASSED` result lines; binary's trailing "Total: 87 tests" summary string is stale cosmetic F-18-IMPL-01) | build log; test-cache-controller direct log | 89 of 89 PASS; any FAIL opens bug-fix loop |
| TP-18-FT2 | focused | Item 1 deletion applied | `git diff --check HEAD` on `tools/server/server-context.cpp` | clean exit 0; no trailing whitespace; no CRLF | git output empty | clean check exit 0 |
| TP-18-FT3 | focused | Item 1 deletion applied | `Select-String -Path tools/server/server-context.cpp -Pattern 'cache-cold-path requires --cache-mode hybrid'` | exactly 1 match at lines 1419-1420 (canonical moved block); 0 matches at the post-slot-init site | Select-String output | duplicate gone, canonical intact |
| TP-18-FT4 | focused | D18-IMPL-01 flags applied; cmake reconfigure complete | `Select-String -Path build-cov/CMakeCache.txt -Pattern 'CMAKE_CXX_FLAGS_RELEASE'`; inspect value | value contains `/O2 /Ob2 /DNDEBUG /Zi`; does NOT contain `/DEBUG:FULL` | Select-String output | CXX compile flag honors D18-IMPL-01 step 1 |
| TP-18-FT5 | focused | D18-IMPL-01 flags applied; cmake reconfigure complete | `Select-String -Path build-cov/CMakeCache.txt -Pattern 'CMAKE_C_FLAGS_RELEASE'`; inspect value | value contains `/O2 /Ob2 /DNDEBUG /Zi`; does NOT contain `/DEBUG:FULL` | Select-String output | C flag mirrors CXX flag |
| TP-18-FT6 | focused | FT4 and FT5 PASS | `cmake --build build-cov --config Release --target test-cache-controller -j 4`; run binary | build exit 0; binary runs 89/89 PASS with new flags | build log; test-cache-controller direct log | 89 of 89 PASS post-flag-change |
| TP-18-FT7 | focused | FT6 PASS | `cmake --build build-cov --config Release --target llama-server -j 4`; start server; hit `/health` | build exit 0; server starts; `/health` returns 200 OK | build log; server start log; `/health` response | server boots, health endpoint serves |
| TP-18-FT8 | focused | D18-IMPL-01 flags applied; cmake reconfigure complete | `Select-String -Path build-cov/CMakeCache.txt -Pattern 'CMAKE_EXE_LINKER_FLAGS_RELEASE\|CMAKE_MODULE_LINKER_FLAGS_RELEASE\|CMAKE_SHARED_LINKER_FLAGS_RELEASE'`; inspect three values | each of the three `*_LINKER_FLAGS_RELEASE` values contains `/INCREMENTAL:NO /debug /DEBUG:FULL` | Select-String output | three linker flags honor D18-IMPL-01 steps 2-4 |

### Integration tests (against llama-server binary)

Fixture: model-backed MTP fixture for rows that need it; cold path
directory prepared where required. Preconditions: clean build of
`llama-server.exe` with D18-IMPL-01 flag set; OpenCppCoverage
0.9.9.0+ at the canonical path; MTP fixture available for IT3 and
IT6.

| ID | Type | Preconditions | Command | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-18-IT1 | integration | cold-path directory prepared | start `llama-server.exe` with `--cache-cold-path <path> --cache-mode legacy --cache-cold-max-mib 0` | server exits with bounded error and the cold-path-hybrid-mismatch error message; non-zero exit code; no STATUS_STACK_BUFFER_OVERRUN (0xC0000409) | server.err.log + exit code | F-18-DR-01 corner case rejected (F-18-IMPL-02 empirical closure at 1413-1414) |
| TP-18-IT2 | integration | cold-path directory prepared; hybrid mode | start `llama-server.exe` with `--cache-cold-path <path> --cache-mode hybrid --cache-ram 1024 --cache-cold-max-mib 100` | server starts cleanly; logs cold store path; logs cold budget; reaches `/health` readiness | server.out.log + server.err.log + `/health` response | clean startup, hybrid mode accepted |
| TP-18-IT3 | integration | MTP fixture | re-run Stage 17 IT5 (start with `--cache-prompt-evidence raw` and no `--log-prompts-dir`) | server exits with bounded error (`raw mode requires --log-prompts-dir`); non-zero exit; no STATUS_STACK_BUFFER_OVERRUN | server.err.log + exit code | bounded-error exit; F-17-EXEC-01 fix not regressed |
| TP-18-IT4 | integration | FT6 PASS; OpenCppCoverage available | run OpenCppCoverage against `build-cov/bin/Release/test-cache-controller.exe` with `--export_type binary:<path>` and `--modules=build-cov/bin/Release/*` | `.cov` file produced; file size > 1 KB (header-only baseline was 111 bytes); contains line-count data | `.cov` file size + content | line-data contract unblocked; coverage setup ready |
| TP-18-IT5 | integration | IT4 PASS | convert `.cov` to Cobertura XML via `--export_type cobertura:<path>` or `coverage-manual-*.ps1` | valid Cobertura XML; per-line entries present; 100+ class entries | Cobertura `.xml` + grep for `class name=` | Cobertura format with per-line entries |
| TP-18-IT6 | integration | MTP fixture; FT7 PASS | start `llama-server.exe` with MTP fixture in hybrid mode; issue two identical `/v1/chat/completions` requests | server starts; first request saves; second request restores with `cache_n > 0` (Stage 17 IT8 regression preserved) | per-request response body + `/metrics` | Stage 17 IT8 regression intact; smoke check, not deferred-path validation |

## Pass/fail criteria

- Focused rows TP-18-FT1..FT8 must all PASS. Any FAIL opens the
  bug-fix loop per part-25 rules. A `BLOCKED` row requires a
  documented setup/harness reason, not a product bug.
- Integration rows TP-18-IT1..IT6 must all PASS or be BLOCKED with
  a documented harness/setup reason. Any FAIL opens the bug-fix
  loop. Rows that depend on a model-backed fixture (IT3, IT6)
  require a real model load.
- TP-18-FT1 and TP-18-FT6 expected count is 89/89 (74 pre-Stage 17
  tests plus 15 Stage 17 `test_stage17_*` functions). Count the
  actual `PASSED` result lines, not the binary's trailing summary
  string.
- TP-18-FT3 expects exactly 1 match (not 0, not 2). The
  F-18-DR-01 corner case is rejected by a different check at
  server-context.cpp:1413-1414, not by the deleted duplicate.
  TP-18-IT1 verifies the corner case empirically.
- TP-18-FT4 and TP-18-FT5 expect `/Zi` in the value but
  NOT `/DEBUG:FULL`. The pre-D18-IMPL-01 design proposed
  `/DEBUG:FULL` in CXX/C flags; the amendment moved that flag
  to the three linker flags covered by TP-18-FT8. A row that
  reports `/DEBUG:FULL` in CXX/C flags is FAIL (mis-translation
  pre-amendment, regression post-amendment).
- TP-18-FT8 expects `/debug /DEBUG:FULL` in each of the three
  `*_LINKER_FLAGS_RELEASE` values. Missing `/debug` means no PDB
  generation; missing `/DEBUG:FULL` means header-only `.cov`
  output. Either missing flag is FAIL.
- TP-18-IT4 expected size: > 1 KB. Any report < 1 KB is FAIL
  (coverage setup regression). The implementation iter2 evidence
  cites 327137 bytes as the post-D18-IMPL-01 reference; iter1 was
  111 bytes (header-only). The test plan uses 1 KB as the generic
  threshold; the executor records the actual size.
- TP-18-IT5 expects valid Cobertura format with per-line entries.
  The implementation iter2 evidence cites 109 class entries and
  per-line records such as `<line number="739" hits="0"/>`; the
  test plan uses 100+ class entries as the generic threshold; the
  executor records the actual count.
- Clean-build rule applies per part-26: full clean build of
  `llama-server.exe` and `test-cache-controller.exe` is
  mandatory before any test session. Binary freshness check
  within 10 minutes of session start.
- `build-cov` is gitignored; the durable record of the flag
  state is the cmake invocation, not the file diff. The
  implementation evidence records the full reconfigure command
  in
  [part-03-revised](../../cache-handling-phase18-implementation/part-03-revised-implementation-evidence.md)
  "CMakeCache.txt post-reconfigure" table.
- Test report and benchmark report use plain ASCII status
  labels (`PASS`, `FAIL`, `SKIP`, `BLOCKED`); no unicode icons.
- Coverage contracts T114, T114a, T115 from Stage 10 are now
  MEASURABLE (line data is collected). The 80% combined rate
  and 70% product-only rate are closure contracts for a
  follow-up cache-targeted coverage run, not for the Stage 18
  test session itself. Stage 18 is about unblocking the
  line-data contract, not about meeting the rate thresholds.

## Evidence

Each test session creates one durable QA test report at
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` and stores
non-durable artifacts under `._test_output/`. Per-tier capture:

- Focused: ctest-style log under
  `._test_output/ctest-YYYYMMDD-NN.log`; per-test PASS/FAIL counts;
  per-row `git diff` or `Select-String` output for FT2, FT3, FT4,
  FT5, FT8; per-row build log for FT1, FT6, FT7.
- Integration: per-row `server.out.log`, `server.err.log`,
  `/health` response body, exit code for IT1, IT2, IT3; per-row
  OpenCppCoverage `.cov` file size and content for IT4; per-row
  Cobertura `.xml` for IT5; per-row request/response body and
  `/metrics` snapshot for IT6. Evidence paths under
  `._test_output/stage18-int-YYYYMMDD-NN/<row>/`.

The durable record for the Item 2 cmake flag state is the
implementation evidence file at
[part-03-revised](../../cache-handling-phase18-implementation/part-03-revised-implementation-evidence.md)
"CMakeCache.txt post-reconfigure" table. The QA test report cites
this table as the source of the flag state and the verification
commands the executor ran.

The verification commands the executor runs are:

- `git diff HEAD --stat -- tools/server/server-context.cpp`
  (Item 1, expect -5 lines)
- `Get-Content build-cov/CMakeCache.txt | Select-String 'CMAKE.*FLAGS_RELEASE|CMAKE.*LINKER_FLAGS'`
  (Item 2 flag state, expect post-D18-IMPL-01 values per FT4,
  FT5, FT8)
- `Get-ChildItem build-cov/bin/Release/*.pdb | Select-Object Name, Length`
  (expect 9 PDB files co-located with the binaries)
- `Test-Path coverage-stage18-iter2.cov, coverage-stage18-iter2.xml`
  (expect both True; these are untracked worktree artifacts from
  the implementation session; the executor may regenerate them
  in a fresh test session)
- `(Get-Content tests/test-cache-controller.cpp | Select-String -Pattern '^void test_').Count`
  (expect 89; 74 pre-Stage 17 + 15 Stage 17 `test_stage17_*`)

## Risks and open questions

| ID | Risk or question | Owner | Mitigation |
| --- | --- | --- | --- |
| R18-TP-01 | TP-18-IT1 (F-18-DR-01 corner case) may not reach the same rejection path the design predicted. The design said the duplicate was unreachable; the iter1 review found the corner case is rejected by a different check at server-context.cpp:1413-1414 (F-18-IMPL-02). The row is the empirical proof. | Manager | If the server fails to reject the corner case, the row is FAIL; the F-18-DR-01 closure does not hold. Route to bug-fix loop. |
| R18-TP-02 | TP-18-IT3 is a regression smoke on the F-17-EXEC-01 fix. The verification of the F-17-EXEC-01 fix itself is deferred to Stage 19 or follow-up QA per the user brief. If the MTP fixture is unavailable, the row is `BLOCKED-mtp-fixture-missing`. | Manager | Document the BLOCKED state in the test report; do not soften to PASS. |
| R18-TP-03 | TP-18-IT6 requires the Qwen3.6-27B-MTP fixture and a hybrid-mode chat completion. If the fixture is unavailable in the test-execution session, the row is `BLOCKED-mtp-fixture-missing`. Per Stage 15 Manager decision 1, B02/B05/B06 are NOT-IN-SCOPE for the MTP fixture; this row is a regression smoke, not a benchmark. | Manager | Document the BLOCKED state with the fixture name and version. |
| R18-TP-04 | TP-18-IT4 and TP-18-IT5 require OpenCppCoverage 0.9.9.0+ at the canonical path. If the tool is missing or older, the rows are `BLOCKED-coverage-tool-missing`. The iter1 evidence reports a path-pattern mismatch in `--modules` that the iter2 invocation corrected; the executor should use the iter2 invocation form (`--modules=build-cov/bin/Release/*` with absolute Windows path and glob). | Developer | Test report records the BLOCKED state with the tool version. |
| R18-TP-05 | The `coverage-stage18-iter2.cov` and `.xml` files are untracked worktree artifacts. The durable record is the implementation evidence file, not these artifacts. The executor may regenerate them in a fresh test session; the .cov/.xml sizes from iter2 are reference points in the implementation evidence, not contract values in the test plan. | Manager | Test report cites the implementation evidence as the source of the contract; the artifacts are auxiliary evidence. |
| R18-TP-06 | The cmake reconfigure command depends on the original `build-cov` configure flags. The implementation evidence records the full flag set; the executor must capture the original flags before reconfigure and reapply them with the D18-IMPL-01 flag set. | Developer | Implementation evidence Step 2.2-2.3 records the procedure. |
| R18-TP-07 | The 14-row expansion (8 focused + 6 integration) deviates from the 13-row design proposal by one row (TP-18-FT8 for the three linker flags). The design proposal pre-dates D18-IMPL-01; the linker flag check is necessary to honor the amendment. | Manager | The test plan documents the deviation and the reason in the Manager plan-amendment gate decision section. |
| R18-TP-08 | The D18-IMPL-01 amendment relies on the Visual Studio 18 2026 generator's `<GenerateDebugInformation>DebugFull</GenerateDebugInformation>` vcxproj translation. If a different generator is used (Ninja, MinGW), the translation may differ and the linker flags may need adjustment. The current build is Visual Studio 18 2026. | Manager | The test plan applies to the current VS 18 2026 build only; cross-generator portability is out of Stage 18 scope. |

## Handoff

Status: `authored; pending QA test-plan review`. Next owner is **QA**
in a new fresh session for the test-plan review gate. The reviewer
verifies:

- 14 rows map to the implementation plan's Tests section and the
  D18-IMPL-01 amendment (8 focused + 6 integration).
- Manager decisions D17-EXEC-03 and D17-CLOSURE-02 / F-16-TR-03
  are honored verbatim.
- The D18-IMPL-01 amendment is applied (compile flags have `/Zi`
  only; linker flags have `/debug /DEBUG:FULL`).
- Out-of-scope items (D17-EXEC-02, Stage 17 test infrastructure,
  Stage 4-9 regression, S/L rows, B01..B08, F-17-EXEC-01
  verification deferred path) are excluded.
- Evidence and report format match the test plan's quality rules
  at [part-07](./part-07-test-report-quality-and-templates.md).

If the test-plan review PASSes, the next gate is Manager test-plan
gate, then QA test execution in a fresh session, then Developer
test-results review, then Manager closure. If REWORK, the next
owner is QA in a new fresh session. No source code, design,
implementation, architecture, or other durable docs are modified
by this plan; REWORK is a test-plan concern, not a product concern.

This file uses LF line endings, plain ASCII status labels, and
stays under the 300-line durable-doc cap. The
`document-index.md`, `cache-handling-stage-tracker.md`,
implementation log, design docs, and other durable docs are
unchanged by this session.
