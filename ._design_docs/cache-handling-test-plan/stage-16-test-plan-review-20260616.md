# Stage 16 test plan review

Status: PASS
Date: 2026-06-16
Stage: 16
Branch: work-branch
Reviewer: QA (fresh session)
Source: [part-26-stage16-chat-path-prompt-boundary.md](./part-26-stage16-chat-path-prompt-boundary.md)

## Review checklist

10 items, each PASS/FAIL with one-line evidence. Evidence source is the
test plan itself plus cross-references to the cited design, implementation,
and benchmark docs.

1. **Scope alignment**: PASS. Test plan table lists exactly 9 rows
   TP-15-PC1..PC7 (7 operational) plus TP-15-UT1, TP-15-UT2 (2 unit). No
   extras. Matches implementation part-01 Tests section (9 rows) and
   design part-09 Test plan rows proposed section (7 rows; UT1/UT2 added
   per F-16-02).
2. **Evidence-source limits**: PASS. Durable paths under
   `._design_docs/.test_reports/`. Non-durable under `._test_output/` is
   gitignored and is supplemental, never used as closure source.
3. **Future-stage exclusions**: PASS. Stage 4-9 regression rows
   (R10..R23, H30..H74) excluded. S01..S08 and L01..L03 deferred per
   Stage 15 Manager decision 2. B02/B05/B06 NOT-IN-SCOPE for MTP fixture
   per Stage 15 Manager decision 1; revisit is post-QA per Manager
   decision A, not in this plan.
4. **Clean-build rules**: PASS. Plan cites
   `cmake --build build-cov --config Release --target llama-server` and
   the binary-freshness check, exit 0 required, matching the user brief.
5. **Report format**: PASS. Plan mandates Markdown only, no unicode
   icons, plain ASCII labels (PASS, FAIL, BLOCKED, SKIP), per-row
   verdict table with required columns. Header fields per part-07
   template.
6. **Windows preload workaround limits**: PARTIAL. Part-12 (Stage 10)
   forbids LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD for model-backed
   save/restore/checkpoint rows; the Stage 16 plan does not restate
   this rule. The Stage 16 rows PC1..PC3 and PC4..PC6 are
   model-backed and would be invalid under the preload skip. Logged
   as non-blocking F-26-02.
7. **Coverage targets**: PASS. Plan requires 100% line+branch on
   server-context.cpp:4486-4498 plus the `!messages.empty()` conditional
   (both branches), 100% unit on TP-15-UT1/UT2, 20+ existing tests in
   test-cache-controller.cpp unaffected (74 test functions confirmed
   in source), OpenCppCoverage on build-cov with per-file aggregation,
   T114>=0.80, T114a>=0.70, T115 dedup, missing coverage = FAIL not
   BLOCKED.
8. **Test automation scripts**: PASS. Three new wrapper scripts
   (stage16-chat-path-benchmark.ps1, stage16-completion-regression.ps1,
   stage16-multi-turn.ps1) for operational rows PC4, PC5, PC6. New test
   cases in test-cache-controller.cpp for UT1, UT2. Existing
   run_coverage.ps1 reused for coverage closure. The gtest filter
   note correctly cites qa.md improvement memory.
9. **Pass/fail criteria**: PASS. Operational rows required for PASS;
   unit rows non-blocking; 100% coverage on new path required;
   regression rows (PC6, PC7) required; T114/T114a/T115 closure
   required.
10. **Handoff**: PASS. Plan routes PASS to QA fresh-session test-plan
    review (this review), then Manager test-plan gate, then test
    execution, then Developer test-results review, then Manager
    reclassification per decision A. REWORK routes to QA in new fresh
    session. Matches the user brief.

## Findings table

| ID | Severity | Title | Evidence | Action |
| --- | --- | --- | --- | --- |
| F-26-01 | non-blocking | Clean-build target list omits `test-cache-controller` for UT1/UT2 | Plan Prerequisites and clean-build rule builds only `llama-server` (line 53-54); plan notes at line 62 that `test-cache-controller` must be rebuilt for UT1/UT2 but defers the explicit command to the test report | Test-execution session rebuilds both targets; record the new target list in the test report per plan line 62 |
| F-26-02 | non-blocking | No preload workaround limits stated for model-backed rows | Plan rows PC1..PC3 and PC4..PC6 require MTP fixture (model-backed); plan does not restate part-12 rule that LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD is forbidden for save/restore/hit/miss/checkpoint rows | Test-execution session uses real model load; do not set the skip env var for these rows |
| F-26-03 | INFO | Line numbers 4486-4498 match implementation review F-16-IR-01 stated range | Implementation review Verification checklist item 1 cites the new block at server-context.cpp:4486-4498; design part-09 and implementation part-08 cite 4483-4500 or 4483-4504 for the function range | None; cited range is the inserted block, consistent with implementation review |
| F-26-04 | INFO | V2 driver body is at gitignored path; test plan references the durable benchmark report instead | Plan line 96: driver at `._test_output/bench-stage15-20260613-b56-fix/` (gitignored); line 98: "Stage 16 driver body differs by endpoint URL and request payload only"; line 97-99 directs reader to the durable V2 driver body in stage15-benchmark-20260613-03.md Per-request results table | None; plan correctly treats the durable benchmark report as the source of truth, not the gitignored driver directory |
| F-26-05 | INFO | Manager decision A (B02/B05/B06 reclassification) revisit is post-QA and out of this plan's scope | Plan Exclusions section explicitly defers B02/B05/B06; plan Handoff section routes the revisit to Manager after QA verification of TP-15-PC1..PC7 | None; scope rule consistent with implementation part-01 Manager decisions A |
| F-26-06 | INFO | Unit-test rows are non-blocking by design, even though coverage of the unit test target itself is required for PASS | Plan Pass/fail criteria: "Unit rows TP-15-UT1, TP-15-UT2 recommended but non-blocking for PASS"; Plan Coverage measurement: "Unit test coverage target: 100% on TP-15-UT1 ... and TP-15-UT2" | None; the two rules are consistent: the row can be BLOCKED-pending-test-code and the stage can still PASS on operational rows + coverage, provided the coverage section explicitly notes the missing UT coverage as an open item |

Counts: BLOCKING 0, non-blocking 2, INFO 4.

## Coverage adequacy

- 100% line on the 14-line insertion at server-context.cpp:4486-4498:
  required for PASS, FAIL not BLOCKED on miss.
- 100% branch on `!messages.empty()` (both arms): required for PASS.
- 100% unit coverage on TP-15-UT1 (3-message input) and TP-15-UT2
  (empty array): required for PASS. UT1/UT2 are non-blocking as rows
  but their coverage target is closure.
- 74 existing test functions in tests/test-cache-controller.cpp must
  continue to pass (count verified by grep; 20+ claim holds).
  Implementation review F-16-IR-01 verification item 5 confirms the
  chat path function is not referenced in the test file, so existing
  tests cannot regress from the source change.
- T114>=0.80, T114a>=0.70, T115 dedup: closure contract from Stage 10
  applies; coverage-run target list should be added to the test
  report (F-26-01 follow-up).
- Coverage gap handling: missing coverage is FAIL, not BLOCKED
  (consistent with qa.md improvement memory `classify available
  fixture no-evidence runs`). Setup gaps (Release without /Zi,
  Start-Process colon-prefix export bug) are BLOCKED, not FAIL
  (consistent with qa.md improvement memory `distinguish
  Release-build coverage gap from Start-Process bug`).
- Server HTTP probe included in coverage run when target files
  contain server integration paths: the new code is in
  server-context.cpp, which is server-side, so HTTP probe must be in
  the coverage run. Plan covers this in Coverage measurement
  methodology.

Coverage adequacy: PASS, with F-26-01 noted for the test-execution
session to add the explicit target list to the test report.

## Test automation adequacy

Operational rows TP-15-PC1..PC7:

- PC1..PC3: covered by stage16-chat-path-benchmark.ps1 (new wrapper).
  The wrapper must scrape /metrics before/after the warmup and assert
  the three counters. Plan does not name the wrapper output filenames
  but the Evidence section names `metrics-before.txt` and
  `metrics-after.txt`. Adequate.
- PC4: same wrapper with n=30 iterations, 1 warmup + 29 identical
  chat-completion requests. Mirrors V2 driver body 1:1. Adequate.
- PC5: stage16-multi-turn.ps1 with 3-message input (system, user,
  assistant-prefix). Mirrors PC4 with different request payload.
  Adequate.
- PC6: stage16-completion-regression.ps1 with the V2 native
  `/completion` driver unchanged. Regression check. Adequate.
- PC7: server start log captured as part of the per-row artifact
  directory; the 5 `n_ctx_seq` warnings counted. Adequate.

Unit rows TP-15-UT1, TP-15-UT2:

- New test cases in test-cache-controller.cpp. Plan does not
  pre-author the test code; this is Developer's job per the plan
  Handoff and the qa.md improvement memory rule on test plan vs
  test code ownership. Adequate for the plan; the test code
  existence check happens at test-execution time, not at this
  review.
- Custom runner, not gtest: plan cites qa.md improvement memory
  (`detect custom test framework before applying gtest filter`).
  Correct.

Coverage:

- run_coverage.ps1 reused. Per-file aggregation, T115 dedup, union
  by (file, line) taking max hits per duplicate `<class>` block per
  qa.md improvement memory. Adequate.

Test automation adequacy: PASS.

## Verdict

PASS. 0 BLOCKING findings. 2 non-blocking findings (F-26-01 build
target list, F-26-02 preload workaround limits) are scoped to the
test-execution session and do not require test plan correction.

The test plan correctly maps the Stage 16 design correction to 9
verifiable rows, defines the evidence paths, sets the pass/fail
criteria, and routes handoff through Manager test-plan gate on
PASS or back to QA on REWORK.

## Handoff

PASS routes to **Manager** for the test-plan gate. After Manager
approves, QA opens a fresh test-execution session per the plan's
Handoff section. REWORK routes to **QA** in a new fresh session
(no REWORK triggers identified at this gate; the 2 non-blocking
findings are scoped to the test-execution session, not the plan).
