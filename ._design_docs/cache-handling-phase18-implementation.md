# Stage 18 implementation: Stage 17 closure trivial follow-ups

Status: closed
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Design baseline: [cache-handling-phase18-design.md](cache-handling-phase18-design.md)
Current gate: closed (Manager closure 2026-06-18)

## Scope

This implementation log covers Stage 18 planning and implementation evidence.
No commits, PR text, or reviewer responses are approved by this file.

Stage 18 implementation scope:

- Remove duplicate cold-path-hybrid check at server-context.cpp:1554-1557 (D17-EXEC-03)
- Add `/Zi /DEBUG:FULL` to `CMAKE_CXX_FLAGS_RELEASE` for build-cov (D17-CLOSURE-02 / F-16-TR-03)

Both items map to Manager decisions recorded in the Stage 17 closure
on 2026-06-17.

## Contents

- [Part 1: implementation plan](cache-handling-phase18-implementation/part-01-implementation-plan.md)
- [Part 2: Architect implementation-plan review gate 01](cache-handling-phase18-implementation/part-02-architect-implementation-plan-review-gate-01.md)

Part 3 (implementation evidence) and Part 4 (implementation review)
will be added as the implementation progresses.

## Gate status

| Gate | Status |
| --- | --- |
| Stage 18 design authoring | PASS (see [design entry](cache-handling-phase18-design.md) and parts 1-3) |
| Stage 18 design review | PASS (see [design part 4](cache-handling-phase18-design/part-04-design-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 1 INFO) |
| Stage 18 Manager design gate | PASS (Manager decision 2026-06-18) |
| Stage 18 implementation planning | PASS (see [part 1](cache-handling-phase18-implementation/part-01-implementation-plan.md), 232 lines) |
| Stage 18 implementation-plan review | PASS (see [part 2](cache-handling-phase18-implementation/part-02-architect-implementation-plan-review-gate-01.md), 0 BLOCKING, 1 non-blocking, 0 INFO) |
| Stage 18 Manager implementation-plan gate | PASS (Manager decision 2026-06-18, see below) |
| Stage 18 implementation iteration 1 | PARTIAL: Item 1 PASS, Item 2 BLOCKED on linker propagation (see [part 3](cache-handling-phase18-implementation/part-03-implementation-evidence.md)) |
| Stage 18 implementation review iteration 1 | REWORK (see [part 4](cache-handling-phase18-implementation/part-04-architect-implementation-review-gate-01.md), 1 BLOCKING, 2 non-blocking, 1 INFO) |
| Stage 18 Manager plan-amendment gate | PASS (see D18-IMPL-01 below, 2026-06-18) |
| Stage 18 implementation iteration 2 | PASS (see [part 3-revised](cache-handling-phase18-implementation/part-03-revised-implementation-evidence.md)) |
| Stage 18 implementation review iteration 2 | PASS (see [part 5](cache-handling-phase18-implementation/part-05-architect-implementation-review-iteration-2.md), 0 BLOCKING, 2 non-blocking, 5 INFO) |
| Stage 18 test planning | PASS (see [test plan part 28](../cache-handling-test-plan/part-28-stage18-stage17-closure-trivial-followups.md), 14 rows: 8 focused, 6 integration) |
| Stage 18 test-plan review | PASS (see [review 20260618](../cache-handling-test-plan/stage-18-test-plan-review-20260618.md), 0 BLOCKING, 2 non-blocking, 5 INFO) |
| Stage 18 Manager test-plan gate | PASS (see [gate 20260618](../cache-handling-test-plan/stage-18-manager-test-plan-gate-20260618.md)) |
| Stage 18 QA execution | FAIL (see [test-report-20260618-01](../.test_reports/test-report-20260618-01.md), 12 PASS / 2 FAIL; F-18-EXEC-01 IT1 corner case crash, F-18-EXEC-02 IT3 raw evidence regression) |
| Stage 18 bug-fix iteration 1 | PASS (see [test-report-20260618-01-fixes](../.test_reports/test-report-20260618-01-fixes.md)) |
| Stage 18 bug-fix review iter 1 | REWORK then PASS (see [architect fix review iter 2](../.test_reports/test-report-20260618-01-architect-fix-review-iteration-2.md), 0 BLOCKING, 3 non-blocking, 2 INFO; B-18-ARCH-01 CRLF fix applied, source unchanged verified) |
| Stage 18 Manager bug-fix gate | PASS (Manager decision 2026-06-18, see below) |
| Stage 18 QA re-execution | BLOCKED-rerun-rate-limit (HTTP 429 from subagent at 2026-06-18; no rerun artifact on disk; Manager stop per improvement memory) |
| Stage 18 test-results review iter 2 | PASS (see [rerun developer review](../.test_reports/test-report-20260618-01-rerun-developer-review.md), 14 PASS / 0 FAIL / 0 BLOCKED / 0 SKIP, no product bugs) |
| Stage 18 closure | PASS (Manager closure 2026-06-18, see D18-CLOSURE-01 below) |

## Manager implementation-plan gate decision

Date: 2026-06-18
Verdict: PASS

The Stage 18 implementation plan is approved. Architect implementation-plan
review ([part 2](cache-handling-phase18-implementation/part-02-architect-implementation-plan-review-gate-01.md)) returned PASS with 0 BLOCKING, 1 non-blocking, 0 INFO
findings. The one non-blocking finding (F-18-IPR-01: CRLF line endings in
the plan file) has been resolved by converting the plan file to LF-only
(verified CR=0, LF=274 at conversion time).

The plan covers both items:

- Item 1: deletion of duplicate cold-path-hybrid check at server-context.cpp
  lines 1554-1557 plus comment disposition at line 1552. Verification of
  F-18-DR-01 corner case (`cache_cold_max_mib=0` + legacy mode) is committed
  to evidence at step 1.6 and TP-18-IT1.
- Item 2: cmake reconfigure of build-cov with `/Zi /DEBUG:FULL` added to
  `CMAKE_CXX_FLAGS_RELEASE` and `CMAKE_C_FLAGS_RELEASE`. `CMAKE_CXX_FLAGS_RELWITHDEBINFO`
  at line 83 explicitly preserved unchanged. OpenCppCoverage smoke test
  in step 2.8.

## Manager plan-amendment gate decision (D18-IMPL-01)

Date: 2026-06-18
Verdict: PASS

Architect implementation review iteration 1 (part 4) returned REWORK
with 1 BLOCKING finding (F-18-IMPL-04: Visual Studio generator does not
propagate `/Zi /DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` to linker flags;
`/DEBUG:FULL` in `CMAKE_CXX_FLAGS_RELEASE` is mis-translated by the VS
generator into a `/D EBUG:FULL` preprocessor define with the leading slash
stripped; no PDB on disk; OpenCppCoverage .cov remains header-only).

The plan is amended as follows for implementation iteration 2:

1. Remove `/DEBUG:FULL` from `CMAKE_CXX_FLAGS_RELEASE` and `CMAKE_C_FLAGS_RELEASE`.
   Keep only `/Zi` in these flags (Program Database format is correct for
   the compile step).
2. Add `/debug /DEBUG:FULL` to `CMAKE_EXE_LINKER_FLAGS_RELEASE` so the
   executable binary gets a PDB.
3. Add `/debug /DEBUG:FULL` to `CMAKE_MODULE_LINKER_FLAGS_RELEASE` so
   static library TUs (if any) get PDB.
4. Add `/debug /DEBUG:FULL` to `CMAKE_SHARED_LINKER_FLAGS_RELEASE` so
   `llama-server-impl.dll` (or whatever the shared lib is named) gets PDB.

These three linker flags are required because the VS generator does not
auto-derive linker flags from compile flags. The design's Option 1 (add
to `CMAKE_CXX_FLAGS_RELEASE` only) was incomplete for the VS generator.

Item 1 remains PASS per iteration 1 evidence (no change required).

Next gate: implementation iteration 2 (Developer, fresh session). The
Developer applies the amended Item 2 with the four linker flags above,
re-wipes CMakeFiles, reconfigures, rebuilds, re-tests, and re-runs
OpenCppCoverage until the line-data contract is satisfied (cov file > 1 KB
with non-zero source line counts).

## Manager bug-fix gate decision (D18-EXEC-01)

Date: 2026-06-18
Verdict: PASS

The Stage 18 bug-fix iteration 1 is approved for closure. Architect bug-fix
review iteration 2 returned PASS with 0 BLOCKING (1 closed), 3 non-blocking,
2 INFO. The fix moves the validation block from `server-context.cpp`
lines 1381-1427 to 1242-1291 (BEFORE `common_init_from_params` at
line 1292, i.e., before model load), replaces 8 `throw std::runtime_error`
calls with `return false` so `load_model()` exits with code 1 instead of
crashing, and adds 2 new focused regression tests. Both F-18-EXEC-01 and
F-18-EXEC-02 share the root cause and the single fix resolves both.

This bug-fix is also the Stage 17 F-17-EXEC-01 fix verification that
was deferred (Architect Option B). The Stage 17 fix was incomplete:
it moved the validation block to "before slot init" but NOT before
model load. The Stage 18 fix completes the Stage 17 intent.

The bug-fix report has been converted from CRLF to LF-only (CR=0, LF=184)
to satisfy B-18-ARCH-01. Source code is unchanged from iteration 1
review (verified by `git diff -w --numstat HEAD`).

Non-blocking findings accepted:

- NB-18-ARCH-01: test count prose says "91" but binary summary shows 89. Actual test count is 89 (74 pre-Stage 17 + 15 Stage 17). Cosmetic only.
- NB-18-ARCH-02: validation check count prose says "7" but actual is 8. Cosmetic only.
- NB-18-ARCH-03: self-description "~110 lines" but actual LF count is 184. Non-empty count is 127, under 300-line cap. Cosmetic only.

Next gate: QA test re-execution in a fresh session. The QA re-runs the
parent test plan focusing on IT1 (F-18-EXEC-01) and IT3 (F-18-EXEC-02)
plus the previously-passing 12 rows as regression check. If IT1 and IT3
now PASS, Stage 18 is ready for closure.

## Handoff

Next owner: QA for test re-execution in a fresh session. The QA produces
a new test report (test-report-20260618-01-rerun.md or similar) focused
on IT1 and IT3. If both rows PASS, Stage 18 advances to Developer
test-results review (iteration 2) and then Manager closure.

## Manager closure decision (D18-CLOSURE-01)

Date: 2026-06-18
Verdict: PASS

Stage 18 is closed. All gates advanced successfully:

- Design authoring PASS (parts 1-3)
- Design review PASS (part 4, 0 BLOCKING, 3 non-blocking, 1 INFO)
- Manager design gate PASS (2026-06-18)
- Implementation planning PASS (part 1, 232 lines)
- Implementation-plan review PASS (part 2, 0 BLOCKING, 1 non-blocking; CRLF fixed)
- Manager implementation-plan gate PASS (2026-06-18)
- Implementation iter 1 PARTIAL (Item 1 PASS, Item 2 BLOCKED on linker propagation)
- Implementation review iter 1 REWORK (1 BLOCKING F-18-IMPL-04)
- Manager plan-amendment D18-IMPL-01 PASS (2026-06-18): removed /DEBUG:FULL from CXX/C flags; added /debug /DEBUG:FULL to all three CMAKE_*_LINKER_FLAGS_RELEASE
- Implementation iter 2 PASS (part 3-revised, 89/89 focused tests, 9 PDBs, OpenCppCoverage .cov 327137 bytes with line data)
- Implementation review iter 2 PASS (part 5, 0 BLOCKING, 2 non-blocking, 5 INFO)
- Test plan authoring PASS (part 28, 14 rows: 8 focused, 6 integration)
- Test-plan review PASS (review 20260618, 0 BLOCKING, 2 non-blocking, 5 INFO)
- Manager test-plan gate PASS (2026-06-18)
- Test execution iter 1 FAIL (test-report-20260618-01, 12 PASS / 2 FAIL; F-18-EXEC-01 + F-18-EXEC-02 product bugs)
- Bug-fix iter 1 PASS (test-report-20260618-01-fixes; validation block moved from 1381-1427 to 1242-1291 BEFORE common_init_from_params at 1292; 8 throws replaced with return false)
- Bug-fix review iter 1 REWORK (B-18-ARCH-01 CRLF in bug-fix report); CRLF fix applied
- Bug-fix review iter 2 PASS (architect fix review iter 2, 0 BLOCKING, 3 non-blocking, 2 INFO)
- Manager bug-fix gate PASS (D18-EXEC-01, 2026-06-18)
- Test re-execution PASS (test-report-20260618-01-rerun, 14 PASS / 0 FAIL / 0 BLOCKED / 0 SKIP)
- Test-results review iter 2 PASS (rerun developer review, 14 PASS / 0 FAIL / 0 BLOCKED, no product bugs)

### Substantive finding

Stage 17 F-17-EXEC-01 fix was incomplete. Architect Option B in Stage 17
had deferred the fix verification to a future clean-state session. Stage 18
test execution exposed that the validation block was positioned AFTER
the model warmup step (line 1292 `common_init_from_params`), so the
warmup-path STATUS_STACK_BUFFER_OVERRUN fired before any validation
could throw. Stage 18 bug-fix iter 1 completes the Stage 17 intent by
moving the validation block to BEFORE the model warmup and replacing
`throw std::runtime_error` with `return false` so `load_model()` exits
with code 1 instead of crashing. This is the F-17-EXEC-01 verification
that was deferred under Architect Option B; it is now resolved.

### Optional follow-ups (non-blocking)

- R-18-RUN-01 (IT6 cache_n=0 with 17-token haiku prompt): Stage 17 prefix
  policy correctly classifies the entry=56/task=17 ratio as
  `unsafe_prefix_rejected`. Test plan part-28 documents IT6 as a smoke
  check, not a deferred-path validation. Optional follow-up: document
  the required prompt length and entry token count in the test plan.
- NB-18-ARCH-01 (test count prose says "91" but binary summary shows 89).
- NB-18-ARCH-02 (validation check count prose says "7" but actual is 8).
- NB-18-ARCH-03 (self-description "~110 lines" but actual LF count is 184).

### Code changes (UNCOMMITTED, awaiting user approval per AGENTS.md)

- `tools/server/server-context.cpp`: -5 lines (Item 1 duplicate check
  deletion) + validation block moved from 1381-1427 to 1242-1291 + 8
  `throw std::runtime_error` replaced with `return false`. Total: ~+50
  insertions, ~-57 deletions.
- `tests/test-cache-controller.cpp`: +53 lines, -1 line (2 new Stage 18
  regression tests).
- `build-cov/CMakeCache.txt` (gitignored): +6 flag lines (CXX, C,
  EXE_LINKER, MODULE_LINKER, SHARED_LINKER, with /Zi or /debug
  /DEBUG:FULL).
- 9 new `.pdb` files in `build-cov/bin/Release/` (gitignored).

### Next owner

User. Stage 18 closed. Code changes remain UNCOMMITTED pending user
approval for commit/push/merge per AGENTS.md.

Stages 19 and 20 are the remaining Stage 17 closure follow-ups, not
yet started:

- Stage 19: System-level model warmup crash investigation (D17-EXEC-02).
  Note: the Stage 18 bug-fix moves the validation block before warmup,
  which addresses the F-18-EXEC-01 / F-18-EXEC-02 specific crashes.
  Stage 19 may now be reduced scope or may be fully closed if the
  root cause of those crashes was solely the validation-block-after-warmup
  ordering. The Stage 17 closure rationale for D17-EXEC-02 should be
  revisited: D17-EXEC-02 was originally classified as OUT OF SCOPE for
  the F-17-EXEC-01 fix because it was deemed environmental, but the
  Stage 18 finding shows the crash was code-related (validation order).
- Stage 20: Stage 17 test infrastructure additions (agentic prompt
  generator, Qwen3.6-27B-MTP fixture, S/L framework re-invocation).

## Handoff

Stage 18 closed. Code changes remain UNCOMMITTED per AGENTS.md. User
approval required for commit/push/merge.

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable doc cap.

## Closure handoff

Stage 18 is closed as of 2026-06-18. The Manager has recorded the
closure decision (D18-CLOSURE-01) and updated the tracker row to
status `closed`. The implementation log entry (this file) reflects the
final state with all 13 gates advanced.

User approval is required for commit/push/merge per AGENTS.md. The
uncommitted changes are summarized in the Manager closure decision
section above.

Stages 19 and 20 remain pending:

- Stage 19: System-level model warmup crash investigation (D17-EXEC-02).
  May be reduced scope after Stage 18 fix demonstrated that the crash
  was code-related (validation ordering) rather than purely environmental.
- Stage 20: Stage 17 test infrastructure additions (agentic prompt
  generator, Qwen3.6-27B-MTP fixture, S/L framework re-invocation).
