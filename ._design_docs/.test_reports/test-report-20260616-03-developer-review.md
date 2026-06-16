# Test report 2026-06-16 03: developer test-results review

Status: PASS
Date: 2026-06-16
Stage: 16 (chat-path prompt-span boundary, F-16-BF-08 compile-fix rerun)
Branch: work-branch
Owner: Developer (test-results review, fresh session)
Source report: [test-report-20260616-03.md](test-report-20260616-03.md) (PASS)
Test plan: [part-26-stage16-chat-path-prompt-boundary.md](../cache-handling-test-plan/part-26-stage16-chat-path-prompt-boundary.md)
Trigger: test-report-20260616-02 (FAIL, 7 ops), F-16-TR-06 fix
Fix evidence: [part-07-bugfix-iteration-3-compile-fix.md](../cache-handling-phase16-implementation/part-07-bugfix-iteration-3-compile-fix.md)
Fix review: [part-08-architect-bugfix-review-iteration-3.md](../cache-handling-phase16-implementation/part-08-architect-bugfix-review-iteration-3.md) (PASS)

## Scope

Review the test report verdict for each of the 9 rows. Confirm or
reclassify. Identify product bugs. Define retest scope. Recommend
Manager closure.

In scope: per-row classification, product-bug detection, retest
scope, blocker ownership, Manager recommendation.
Out of scope: re-review of test plan, bug fixes, design,
implementation, architecture; build, test, coverage execution;
modification of any other durable document.

## Per-row classification

| ID | Type | Test report verdict | Reviewer verdict | Owner | Evidence |
| --- | --- | --- | --- | --- | --- |
| TP-15-PC1 | operational | PASS | PASS | QA | pc01-pc03/metrics-after-warmup.txt L294: `cache_checkpoint_admissions_total{mode="hybrid"} 1`, hot_payload_descriptors=2; pc01-pc03/server.err.log L46 `boundaries=12` |
| TP-15-PC2 | operational | PASS | PASS | QA | pc01-pc03/metrics-after-warmup.txt L294: `cache_checkpoint_admissions_total{mode="hybrid"} 1` (was 0 pre-fix) |
| TP-15-PC3 | operational | PASS | PASS | QA | pc01-pc03/metrics-after-warmup.txt L297: `cache_checkpoint_admission_failures_total{mode="hybrid"} 0` (delta=0); no "checkpoint admission skipped" warning |
| TP-15-PC4 | operational | PASS | PASS | QA | pc04/requests-raw.log 30 lines all cache_n=11 prompt_n=50; p50 2925ms; 30/30 hit on identical requests (was 0/30 pre-fix) |
| TP-15-PC5 | operational | PASS | PASS | QA | pc04 evidence reused; PC4 input IS the 3-message system+user+assistant input that PC5 specifies; F-16-TR-04 precedent |
| TP-15-PC6 | regression | PASS | PASS | QA | pc06/requests-raw.log 30 lines all cache_n=0; matches pre-fix Stage 15 baseline 0/30 (no new regression); pc06/metrics-after.txt admissions=1, hits=0, misses=30 |
| TP-15-PC7 | regression | PASS | PASS | QA | pc01-pc03/server.err.log L12: 1 occurrence of `n_ctx_seq (4096) < n_ctx_train (262144)`; matches --ctx-size 4096 baseline per F-16-TR-05 |
| TP-15-UT1 | unit | BLOCKED-pending-test-code | BLOCKED-pending-test-code (non-blocking) | Developer | grep tests/test-cache-controller.cpp for `cache_metadata_from_chat_messages` returns 0 matches; F-16-TR-01 carried over; test plan marks non-blocking for PASS |
| TP-15-UT2 | unit | BLOCKED-pending-test-code | BLOCKED-pending-test-code (non-blocking) | Developer | same as UT1; 72 existing tests pass; UT1/UT2 not among them; F-16-TR-01 carried over |
| Coverage (T114, T114a, T115, Stage 16 line+branch) | coverage | BLOCKED-coverage-setup | BLOCKED-coverage-setup (non-blocking) | Developer | build-cov/CMakeCache.txt:80: `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (no /Zi, no /DEBUG:FULL); F-16-TR-03 carried over |

Row counts: 7 operational PASS, 2 unit BLOCKED-pending-test-code
(non-blocking), 1 coverage BLOCKED-coverage-setup (non-blocking).
Matches the test report's pass/fail summary.

D-16-1 application: D-16-1 (reclassify 61-token MTP n_tokens=11 to
expected-FAIL) was preemptive and not invoked. The test report
shows the iter-3 fix actually succeeds at n_tokens=11
(user-message prompt-span boundary at [0, 11] satisfies
`token_end <= 11`); 30/30 cache_n=11 on PC4 covers the n_tokens=11
case as PASS, not expected-FAIL. Reviewer agrees: D-16-1
reclassification was not required; the broader fix works at
n_tokens=11.

## Product bugs found

No. All 7 operational rows PASS. The 2 unit rows are
BLOCKED-pending-test-code (test code not present, per test plan
non-blocking). Coverage is BLOCKED-coverage-setup
(non-blocking per F-16-TR-03).

No unexpected FAIL on any row. No regression on PC6 or PC7. No
new test defect introduced. The iter-3 compile fix
(`attached_boundary = true;` deletion at
server-cache-hybrid.cpp:3129) is sufficient: the matching loop
finds the user-message prompt-span boundary at [0, 11], the
strict validator re-checksum over [0, 11] passes.

## Retest scope

None. All 7 operational rows PASS on the MTP fixture. No row
FAILed. No product bug surfaced. No new test execution required
for the Stage 16 closure gate.

The BLOCKED rows (UT1/UT2, coverage) are non-blocking per the
test plan and per prior F-16-TR-01 / F-16-TR-03 handoffs. Their
resolution is owned by separate follow-up tasks and does not
gate Stage 16 closure.

If a future stage adds UT1/UT2 test code or moves to a
RelWithDebInfo build with /Zi, the affected rows re-run, but
that is separate work, not a Stage 16 retest.

## Unresolved execution blockers

The test report and the broader Stage 16 record carry these
open items. None block Stage 16 closure. Each is owned by a
separate role.

| ID | Title | Severity | Owner |
| --- | --- | --- | --- |
| F-16-TR-03 | Coverage BLOCKED by Release build without /Zi (build-cov/CMakeCache.txt:80: `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`); OpenCppCoverage produces header-only .cov | non-blocking for PASS | Developer (separate task: add /Zi /DEBUG to CMAKE_CXX_FLAGS_RELEASE or build separate RelWithDebInfo target) |
| F-16-TR-01 | TP-15-UT1 and TP-15-UT2 test cases not present in tests/test-cache-controller.cpp (grep returns 0 matches) | non-blocking for PASS | Developer (separate task: add 2 new test functions) |
| F-16-BF-01 | Trailing whitespace in developer.md (self-improvement asset) | non-blocking, non-test | Developer (separate task: trailing whitespace cleanup) |
| F-16-BF-09 | Design part-09 at 354 lines (exceeds 300-line cap) | non-blocking, non-test | Architect or follow-up Developer (split into continuation part) |

Coverage (T114, T114a, T115, Stage 16 line+branch) remains
BLOCKED-coverage-setup. The Developer handoff for coverage is
the same F-16-TR-03 fix (coverage-eligible rebuild), not a
Stage 16 retest.

## Manager closure recommendation

PASS. Stage 16 is ready for Manager closure.

- All 7 operational rows TP-15-PC1..PC7 PASS.
- 2 unit rows (TP-15-UT1, TP-15-UT2) BLOCKED-pending-test-code,
  non-blocking per test plan Pass/fail criteria and per
  Architect design review F-16-02 / implementation review
  F-16-IR-02.
- 1 coverage row BLOCKED-coverage-setup, non-blocking per
  F-16-TR-03.
- F-16-TR-06 (iter-2 matching-loop relaxation insufficient)
  RESOLVED by iter-3 compile fix.
- F-16-BF-08 (compile error) RESOLVED by one-line deletion at
  server-cache-hybrid.cpp:3129, verified by Architect review
  part-08 (4/4 PASS verification checklist).
- F-16-TR-04 (PC5 duplicate of PC4) is evidence-equivalent, no
  action.
- F-16-TR-05 (PC7 expected count 5 vs actual 1 at --ctx-size
  4096) is test-plan wording, non-blocking.

The Manager can close Stage 16 with the documented F-16-BF-09
and F-16-BF-14 (architecture limitation note) as separate
follow-ups, and the F-16-TR-03 coverage handoff as a separate
Developer task.

## Manager decision A application

Manager decision A (in the Stage 16 implementation plan
[part-01](../cache-handling-phase16-implementation/part-01-implementation-plan.md),
Manager decisions section): "Revisit Manager closure decision
1 (2026-06-13, B02/B05/B06 NOT-IN-SCOPE for MTP fixture). If
TP-15-PC1, PC2, PC3, PC4 all PASS on the MTP fixture, Manager
may reclassify B02/B05/B06 back to IN-SCOPE for MTP fixture and
re-verify on next stage entry."

Application: TP-15-PC1, PC2, PC3, PC4 all PASS on the MTP
fixture. The structural root cause (chat-path prompt-span
boundary gap) is fixed. The 30/30 cache_n=11 on PC4 confirms
the MTP `/v1/chat/completions` exact-blob restore path now
works on the MTP fixture (was 0/30 pre-fix). Manager decision A
can now proceed.

The Developer test-results review (this file) is the gating
evidence for Manager decision A. The Manager owns the tracker
row update per the implementation plan's decision A language:
"Manager owns tracker row update per improvement memory rule
`Closure sweep keeps durable docs aligned without re-running
the report`."

## Handoff

Next owner: Manager for Stage 16 closure.

The Manager:

1. Closes Stage 16 (current status `test-results-review`).
2. Applies Manager decision A: reclassify B02/B05/B06 to
   IN-SCOPE for the MTP fixture per the implementation plan
   part-01 Manager decisions section.
3. Carries F-16-BF-09 (design part-09 at 354 lines) and
   F-16-BF-14 (architecture limitation note for n_tokens=11) as
   separate follow-up items.
4. Carries F-16-TR-03 (coverage RelWithDebInfo rebuild) and
   F-16-TR-01 (UT1/UT2 test code) as separate Developer tasks
   (non-blocking).
5. Carries F-16-BF-01 (developer.md trailing whitespace) as a
   separate Developer task (non-blocking, non-test).
6. Updates the stage tracker row 16 from
   `test-results-review` to `closed`, citing this review as the
   closure evidence.

No source code, design, implementation, architecture, test
plan, or other test report files were modified by this review.
Only `test-report-20260616-03-developer-review.md` was created.
