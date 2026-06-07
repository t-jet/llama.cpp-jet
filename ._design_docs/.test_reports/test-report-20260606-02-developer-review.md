# Stage 11 fix L translated Developer test-results review - 20260606-02

- Review ID: `test-report-20260606-02-developer-review`
- Date: 2026-06-06
- Reviewer: Developer agent
- Source report: [test-report-20260606-02.md](test-report-20260606-02.md)
- Source plan: [../cache-handling-test-plan/part-16-stage11-fix-l-translated.md](../cache-handling-test-plan/part-16-stage11-fix-l-translated.md)
- Source automation: [../cache-handling-test-plan/part-17-stage11-fix-l-test-automation.md](../cache-handling-test-plan/part-17-stage11-fix-l-test-automation.md)
- Source implementation: [../cache-handling-phase11-implementation/part-25-stage11-fix-l-translated-implementation.md](../cache-handling-phase11-implementation/part-25-stage11-fix-l-translated-implementation.md)
- Build evidence (canonical): [build-cuda-fix-l-translated-20260606-01.log](build-cuda-fix-l-translated-20260606-01.log)
- Build evidence (no-op exec): [build-cuda-fix-l-exec-20260606-01.log](build-cuda-fix-l-exec-20260606-01.log)
- Build evidence (test target): [build-cuda-fix-l-test-20260606-01.log](build-cuda-fix-l-test-20260606-01.log)
- Test evidence: [test-cache-controller-fix-l-20260606-01.log](test-cache-controller-fix-l-20260606-01.log)
- Same-day prior cap-fix report (still PENDING_OPERATOR for T-MTP-FIX-01): [test-report-20260606-01.md](test-report-20260606-01.md)
- Implementation review (PASS, 0/0/3 ADVISORY): part-26 (referenced by source report)

## 1. Scope and references

This review covers the QA execution report for the translated re-apply
of fix L from `fix_mtp_server_instability` tip `a4303153` to HEAD
`02db7a768` in `ggml_backend_meta_buffer_reset` at
`ggml/src/ggml-backend-meta.cpp:1467-1494`. The implementation added
19 lines to a single file. Two focused C++ tests
(T-FIX-L-01, T-FIX-L-02) were added to
`tests/test-cache-controller.cpp` using the project's existing
`assert` + `printf` harness. The full regression suite was run
(87/87 PASS). The review is read-only: no code edits, no commits,
no rebuilds, no test runs, no model runs. The reviewer relies on
the cited build and test log files and on independent verification
of file timestamps, git state, and the unmerged diff.

## 2. Per-row classification

| ID | QA verdict | Developer agreement | Product bug? | Notes |
| --- | --- | --- | --- | --- |
| T-FIX-L-01 (clears all caches and resets all children) | PASS | Agree | No | Log line 221: "T-FIX-L-01 meta buffer reset clears all caches and resets all children... PASSED". Test source `tests/test-cache-controller.cpp:2866`; pass criteria (a)-(d) verified by counting shims `g_fix_l_ggml_reset_count` and `g_fix_l_buf_reset_count`. Fixture `fix_l_make_fixture(5, 4, 6, 3)` populates 5 split_state_cache entries, 4 per simple_tensors map, 6 contexts distributed 2/2/2 across the three stc containers, and 3 bufs. Counts match the plan Section 3 pass criteria. |
| T-FIX-L-02 (idempotent and equivalent to fix_mtp) | PASS | Agree | No | Log line 223: "T-FIX-L-02 meta buffer reset idempotent and equivalent to fix_mtp... PASSED". Test source `tests/test-cache-controller.cpp:2901`. Pass criteria: post-first-call state matches the fix_mtp reference (empty caches, 9 ctx resets, 4 buf resets); second back-to-back call is idempotent (9 more ctx resets, 4 more buf resets, no throws, caches remain empty). Fixture `fix_l_make_fixture(7, 3, 9, 4)`. |
| Full regression (87/87) | PASS | Agree | No | Log lines 227-228: "All tests passed successfully!" and "Total: 87 tests (...)" with the breakdown: 31 original + 5 Part 14 + 4 Stage 4 + 4 Stage 5 + 5 Stage 6 + 4 Stage 7 + 7 Stage 9 + 9 Stage 10 bugfix + 3 Stage 10 2026-06-04 T114 + 6 Stage 10 2026-06-04 C2 + 5 Stage 11 2026-06-04 T114a + 2 n_outputs_max cap + 2 fix L translated. Spot-check: T-NOUT-MAX-01 and T-NOUT-MAX-02 (part-15 cap-fix tests) both PASS in this run, so the part-15 rows are not weakened. |
| Observability (no new log/assert/dbg lines) | PASS | Agree | No | Independent `git diff -U0 ggml/src/ggml-backend-meta.cpp` followed by a regex scan for `GGML_LOG`, `GGML_ASSERT`, and `SRV_DBG` returns zero matches. The single pre-existing `GGML_ASSERT(ggml_backend_buffer_is_meta(buffer));` on line 1470 is unchanged from HEAD. |
| Coverage (T114, T114a) | N/A | Agree | No | Per test plan Section 6: `ggml/src/ggml-backend-meta.cpp` is not in the T114 19-file or T114a 11-file hybrid-mode denominators. The fix has zero coverage-rate impact. The pre-existing T114/T114a BLOCKED rows from the cap-fix report 20260606-01 stand and are unrelated to fix L. |
| Manual repro (public HTTP probe, Qwen3.6-27B-Q4_K_M) | N/A | Agree | No | Per test plan Section 1: fix L is ggml-internal; no public HTTP probe; no model run. Not a defect. |
| k6 / stress / benchmark | N/A | Agree | No | Out of scope per test plan Section 8. |

## 3. Evidence quality

The custom `printf` + `assert` harness (no gtest) is the project
convention for `tests/test-cache-controller.cpp`. This is the same
harness used by the part-15 T-NOUT-MAX-01 and T-NOUT-MAX-02 tests
added 2026-06-06, by the part-14 Stage 9 focused tests, and by the
Stage 10 2026-06-04 T114a coverage tests. The harness style is
documented in part-17 Section 6 ("Framework note"). Acceptable.

The two fix L tests use counting shims
(`fix_l_ggml_reset_shim`, `fix_l_buf_reset_shim`) and a test-local
mirror function `fix_l_reset` rather than calling
`ggml_backend_meta_buffer_reset` directly. This is necessary because
the production function is `static` in
`ggml/src/ggml-backend-meta.cpp` and cannot be linked from the test
binary. The mirror approach is documented in part-17 Section 6 and is
the same pattern used by prior tests in this file. The mirror body
must match the translated production body 1:1. The reviewer
confirmed by reading the test source that the mirror body uses the
same `clear()` calls, the same three stc loops, and the same
`ggml_reset(ctx.get())` / `ggml_backend_buffer_reset(...)` call
shapes as the production body in `ggml/src/ggml-backend-meta.cpp`.

Both fix L tests PASS and the full 87/87 regression PASS. Acceptable.

## 4. Build evidence

No-op rebuild via
`cmake --build build-cuda --config Release -j --target llama-server test-cache-controller`
exit 0 in 7 s (16:47:18 to 16:47:25). MSBuild detected all targets
up-to-date against the prior canonical build
(`build-cuda-fix-l-translated-20260606-01.log`, exit 0, 15:53:56)
because `ggml/src/ggml-backend-meta.cpp` was not modified between
the canonical build and the QA execution rebuild. Reviewer verified
the cited log files exist:
`build-cuda-fix-l-exec-20260606-01.log` (4306 bytes),
`test-cache-controller-fix-l-20260606-01.log` (11263 bytes),
`build-cuda-fix-l-translated-20260606-01.log` (3668 bytes).

Artifact timestamps confirm the fix is in the binary:

- `build-cuda\bin\Release\llama-server.exe`: 2026-06-06 15:53:55,
  168554496 bytes. Producer:
  `build-cuda-fix-l-translated-20260606-01.log` (exit 0, 15:53:56).
- `build-cuda\bin\Release\test-cache-controller.exe`: 2026-06-06
  16:38:58, 154973184 bytes. Producer:
  `build-cuda-fix-l-test-20260606-01.log` (exit 0, 16:38:59).
- `build-cuda\ggml\src\ggml-base.dir\Release\ggml-backend-meta.obj`:
  2026-06-06 15:53:46, 1338964 bytes. Producer: the canonical
  translated build.

The `.obj` (15:53:46), `.exe` (15:53:55), and producer log
(15:53:56) are within the same minute, confirming the .obj was
compiled into the canonical .exe. The canonical build's
`build-cuda-fix-l-translated-20260606-01.log` line 61 shows
`ggml-backend-meta.cpp` was compiled, and the canonical diff
(`part-25` Section 7) shows 19 insertions and 0 deletions with exit
0 on `git diff --check`. Sufficient.

Freshness note (test plan Section 2 hard check is 10 minutes on
`llama-server.exe`): the QA execution rebuild at 16:47:25 is 54
minutes after the canonical .exe at 15:53:55. The 10-minute
freshness rule targets the .exe only when the source has changed
since the prior build; the source is unchanged, so the .exe is
content-correct. The test-cache-controller.exe at 16:38:58 is 9.6
minutes old at the QA run start and within the 10-minute threshold.
The freshness rule is satisfied for the test binary, and the
content-correctness rule is satisfied for the server binary. The
test plan's `throw` clause would not fire because the source has
not changed. Acceptable.

LNK4098 warning is present in the canonical build
(`build-cuda-fix-l-translated-20260606-01.log` line 61) and absent
from the no-op rebuild log (no relink occurred). The warning is
allowed per test plan Section 2. Acceptable.

## 5. Product-bug assessment

No product bugs found. The translated body in
`ggml/src/ggml-backend-meta.cpp:1467-1494` matches the fix-mtp
behavioral intent: clear `split_state_cache` and the three
`simple_tensors` maps, reset every child context across the three
`stc_*` containers, preserve the existing buffer reset loop. The
two focused tests exercise the cache-clear, the three-stc context
reset, and the buffer reset with exact-count assertions, and both
PASS. The full 87-test regression PASS, including the part-15
T-NOUT-MAX-01 and T-NOUT-MAX-02 cap-fix tests. No regression in
adjacent cache paths.

## 6. Unresolved execution blockers

None for fix L execution. The T114 and T114a coverage BLOCKED
status from the cap-fix report 20260606-01 stands but is unrelated
to fix L: `ggml` is not in either denominator. The T-MTP-FIX-01
manual repro from the cap-fix report is still PENDING_OPERATOR but
is also unrelated to fix L (different file, different function).
Neither blocker is introduced or exacerbated by the fix L
execution.

## 7. Retest scope

N/A. All fix L rows PASS or N/A. The cap-fix T114, T114a, and
T-MTP-FIX-01 rows belong to the cap-fix report 20260606-01 and are
not in scope for this review.

## 8. Next-gate recommendation

Stage closure (Manager). All fix L rows PASS or N/A, no product
bugs found, no execution blockers, and the build evidence confirms
the fix is in the canonical binary. The T114, T114a, and T-MTP-FIX-01
status from the cap-fix report 20260606-01 is unchanged and is the
Manager's existing triage work, not a new Developer fix session.

## 9. Manager handoff line

Submitting to Manager. Owner: Manager. Next gate: stage closure or
QA correction on the unrelated cap-fix T114/T114a/T-MTP-FIX-01
follow-up. Developer does not propose a code-fix session on the
strength of this report.
