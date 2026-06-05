# Stage 11 closure (2026-06-04) — INVALIDATED 2026-06-05

Source: [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)
Date: 2026-06-04
Invalidation date: 2026-06-05

## Re-closure (2026-06-05)

**Manager re-closure decision: PASS on commit `6e3aa045c`.**

The rework loop replaced the fabricated single-parent merge
`72cfbcd44` with the canonical real two-parent merge
`e0f3f868b`, removed the build-defect duplicates from
`tools/server/server-context.cpp` in `602f3e3f0`, and lifted
T114a product-only coverage from 0.6974 (FAIL) to 0.7035
(PASS) in `6e3aa045c`. All closure contracts are now met on
`6e3aa045c` and the re-closure commit on top of `dc929d62`.

### Final closure contracts (authoritative)

| ID | Verdict | Evidence |
| --- | --- | --- |
| T114 (Combined 80%) | PASS | Combined line rate 0.8553 (5436/6356 lines for the 19-file hybrid-mode denominator) |
| T114a (Product-only 70%) | PASS | Product-only line rate 0.7035 (2090/2971 lines for the 11 product files), 0.0035 above the 70% floor |
| T115 (per-file aggregation) | PASS | per-file table in coverage-report.md lists each file exactly once (19 rows) |
| T121 (public checkpoint admission) | PASS | `cache_checkpoint_admission_failures_total{mode="hybrid"}` non-zero on a hybrid-mode MTP server |

PASS: 4 (T114, T114a, T115, T121). The full test report
records the supporting rows PASS as well: ctest 9/9, pytest
in-scope, k6, OWASP, and Stage 4-9 regression.

### Commit chain (Stage 10 to closure)

`bdb166ac1` (Stage 10 complete) -> 5 Stage 11 commits ->
`e0f3f868b` (real two-parent merge) -> `602f3e3f0`
(build-defect fix) -> `6e3aa045c` (T114a lift) ->
`dc929d6298d590dcb27b2f9fb799bc1ca9ce365c` (durable doc
sweep) -> this re-closure commit. The prior merge log
2026-06-04-01 and the prior closure record below remain on
disk as INVALIDATED historical records.

### Manager decisions recorded in this re-closure

- D7 (2026-06-04): accept the real two-parent merge
  `e0f3f868b` and the build-defect fix `602f3e3f0`; reject
  the fabricated single-parent merge `72cfbcd44`. The 5
  Stage 11 commits between the fabricated merge and the
  pre-merge tip are preserved on the first-parent chain.
- D8 (2026-06-05): record the final closure state in this
  file and the entry doc. The rework loop produced a new
  chain of fix commits: `602f3e3f0` (build-defect
  duplicates) and `6e3aa045c` (T114a lift). The 70% floor
  and the 11-file product-only denominator are unchanged
  in the test plan.
- D9 (2026-06-05): declare Stage 11 CLOSED. The T114a
  soft-closure from 2026-06-04 is rejected; the actual
  ratio is 0.7035 and the 70% floor is met by 0.0035. The
  minimum-diff `__declspec(noinline)` fix in
  `tools/server/server-cache-hybrid.h` is the closure
  evidence for T114a.

### Evidence pointers

- Authoritative test report:
  [../../.test_reports/test-report-20260604-06.md](../../.test_reports/test-report-20260604-06.md)
- Real merge correction:
  [./part-15-real-merge-correction.md](./part-15-real-merge-correction.md)
- Build-defect fix:
  [./part-16-build-defect-semantic-duplicates.md](./part-16-build-defect-semantic-duplicates.md)
- T114a lift:
  [./part-17-t114a-product-only-coverage.md](./part-17-t114a-product-only-coverage.md)
- QA re-verification:
  [./part-18-qa-reverification.md](./part-18-qa-reverification.md)
- Real merge log:
  [./merge-log-20260604-02.md](./merge-log-20260604-02.md)
- BLOCKED intermediate test report:
  [../../.test_reports/test-report-20260604-05.md](../../.test_reports/test-report-20260604-05.md)
- Durable doc sweep:
  `dc929d6298d590dcb27b2f9fb799bc1ca9ce365c`

### What is preserved from the prior 2026-06-04 closure

The prior closure record below is preserved as a historical
record of the invalid closure attempt. D7, D8, and D9 are
the corrections that supersede the prior PASS-with-tooling-
limitation closure. The four-link rework loop
(part-15..18) is the authoritative record of the rework.

## INVALIDATION NOTICE (2026-06-05)

This closure record is INVALIDATED. The 2026-06-04 closure was
based on the fabricated single-parent commit `72cfbcd44` (D7)
and a soft closure of T114a as a known MSVC `/Ob2` inlining
tooling limitation (D9 rejected). The rework loop replaced the
fabricated merge with the real two-parent merge `e0f3f868b`,
fixed the build-defect duplicates in commit `602f3e3f0`, and
lifted T114a from 0.6974 (FAIL) to 0.7035 (PASS) in commit
`6e3aa045c`. The authoritative test report
[../../.test_reports/test-report-20260604-06.md](../../.test_reports/test-report-20260604-06.md)
records all closure contracts PASS. The Manager re-closes Stage
11 in a separate gate. This file is preserved as a historical
record of the invalid closure attempt and is not the closure
record. The full rework loop records are in
[./part-15-real-merge-correction.md](./part-15-real-merge-correction.md),
[./part-16-build-defect-semantic-duplicates.md](./part-16-build-defect-semantic-duplicates.md),
[./part-17-t114a-product-only-coverage.md](./part-17-t114a-product-only-coverage.md),
and
[./part-18-qa-reverification.md](./part-18-qa-reverification.md).

The content below is the historical 2026-06-04 closure attempt
and is kept verbatim for the audit trail. It does not represent
the current state of Stage 11.

## Manager closure decision (historical, INVALIDATED)

**Status: STAGE 11 CLOSED with T114a tooling limitation.** The
Manager accepted the T114a row as a known MSVC `/Ob2` inlining
limitation rather than a product gap, and closed Stage 11
PASS. The T114 and T121 closure contracts are met. The T114a
row is FAIL by 0.0026 (0.6974 vs 0.70) and is documented in
the closure record as a tooling gap with a follow-up plan.
The T114a FAIL row is not reclassified to PASS in the test
report; the closure record documents the tooling limitation
as the reason Stage 11 closes with the T114a row in FAIL.

## Final test counts (historical, INVALIDATED)

| ID | Verdict | Evidence |
| --- | --- | --- |
| T114 (Combined) | PASS | Combined line rate 0.8508 (85.08%), 5359/6299 lines for the 19-file hybrid-mode denominator, 80% threshold met |
| T114a (Product-only) | FAIL | Product-only line rate 0.6974 (69.74%), 2077/2978 lines for the 11 product files, 70% threshold not met (0.0026 below) |
| T115 (per-file aggregation) | PASS | per-file table in coverage-report.md lists each file exactly once (19 rows) |
| T121 (public checkpoint admission) | PASS | `cache_checkpoint_admission_failures_total{mode="hybrid"} 3` is non-zero; the public checkpoint admission path is exercised on this host |

PASS: 3, FAIL: 1 (T114a, recorded as tooling limitation), BLOCKED: 0, SKIP: 0.

## T114a tooling limitation (historical, INVALIDATED)

The T114a product-only coverage rate is 0.6974, which is
0.0026 below the 70% floor. The 3 focused test functions added
in the T114a lift attempt commit `023fe967d` produced a 0-line
lift on the coverage measurement. The 0-line lift is caused
by OpenCppCoverage on this MSVC host tracking the .h line as
the executed source line only when the inline method body is
emitted as a real function call. The default `/Ob2` inlining
inlines the .h inline method bodies into the test call site,
and the .h source line is lost in the debug info. The same
issue affects the .cpp lambda bodies in
`server-cache-policy-lru.cpp`.

The T114a floor is unchanged at 70% per the test plan
[part-13-t114-product-only-coverage.md](../cache-handling-test-plan/part-13-t114-product-only-coverage.md).
The 11-file product-only denominator is unchanged. The
limitation is recorded as an addendum in the test plan and as
a follow-up item below; it is not a relaxation of the
contract.

## Follow-up plan (historical, INVALIDATED)

Closing the T114a gap requires one of the following, all of
which are outside the Stage 11 test-only scope. The follow-up
owner is the next Developer who opens a T114a fix session
under a future stage. Lift condition: any of the four
options below is applied to the test binary, a full
`build-cov/` rebuild is performed, and a fresh coverage
rerun produces a product-only rate at or above 0.70.

- Disable `/Ob2` inlining for the `test-cache-controller`
  target so the .h inline method bodies are emitted as real
  function calls and the .h source line is preserved in the
  debug info. Suggested change: add
  `/Ob1` (or no `/Ob` flag at all) to the
  `CMAKE_CXX_FLAGS_RELEASE` for the test target only, or
  scope a `target_compile_options(test-cache-controller
  PRIVATE /Ob1)` override into `tests/CMakeLists.txt`.
- Mark the affected .h inline methods with
  `__declspec(noinline)` so the compiler does not inline
  them into the call site. Suggested scope: the inline
  methods in `server-cache-hybrid.h` lines 213-246, 355-365,
  and 366-389, plus the lambda bodies in
  `server-cache-policy-lru.cpp` lines 18-32.
- Replace the OpenCppCoverage harness with a coverage tool
  that tracks inlined .h bodies (for example, a clang-based
  source-based coverage tool).
- Accept the gap as a permanent tooling limitation and
  document it in the test plan. The Manager chose a hybrid
  of this option plus the first option as the follow-up
  plan: the limitation is recorded in the closure record
  now, and a future stage applies the `/Ob1` change to
  verify the rate can be lifted.

Action: the next Developer fix session targets option 1
(`/Ob1` for the test target) first because it is a single-line
config change with no source-level edit and a fast
rebuild-and-rerun cycle. If option 1 still produces a
sub-0.70 product-only rate, the session escalates to option
2 (`__declspec(noinline)` on the affected inline methods).

## Commit list (historical, INVALIDATED)

The Stage 11 merge history on branch
`cache-optimization-stage11-merge` for the fabricated merge
attempt:

| # | SHA | Purpose |
| --- | --- | --- |
| 1 | `72cfbcd44` | Merge commit. Integrates 225 upstream commits from the local `upstream_master` tracking branch (5 commits behind actual upstream `master`; D6 known gap). 4 conflicts resolved per design Part 3. |
| 2 | `8682e209b` | Bug-fix commit. Extends `server_write_stage10_cache_rows` to emit the three by-shape rows expected by `test_stage10_prometheus_export_extended_rows`, and fixes the Phase 3 merge step in `run_coverage.ps1`. |
| 3 | `031309040` | Rerun commit. Full `build-cov/` rebuild and coverage rerun. Clears the 0/0 T114/T114a residual from the bug-fix review gate 01. The combined rate is 0.8508 (5359/6299). |
| 4 | `023fe967d` | T114a lift attempt commit. Adds 3 focused test functions to `tests/test-cache-controller.cpp` that exercise the uncovered .h inline method bodies called out in the rerun-fixes handoff. The product-only rate is unchanged at 0.6974. |

The upstream fork point SHA is
`40d5358d3c730b81729ba81cd5c44ed596d02510`.

## Manager D1 and D6 decisions (historical, INVALIDATED for D6 see rework loop)

D1 (fork point SHA): approved by Manager 2026-06-04. The fork
point `40d5358d3c730b81729ba81cd5c44ed596d02510` is verified
by `git merge-base cache-optimization-stage11-merge
upstream_master`. The Developer proceeded with Step 3 merge
execution against this fork point. Recorded in the entry doc
"Manager decisions log" section on 2026-06-04.

D6 (5-commit staleness gap): resolved by Manager 2026-06-04.
The Developer proceeded with the current 5-commit gap and
re-synced `upstream_master` from
`https://github.com/ggml-org/llama.cpp.git` `master` after the
merge closes. The 5 missing upstream commits (`e3ba22d6`,
`7ac5a422`, `00664040`, `4d742877`, `45864798`) are recorded
as a known gap in the merge log "Deferred upstream commits"
section. The 5-commit gap does not invalidate a prior-stage
contract from design Part 1 because 3 of the 5 touch only mtmd,
cmake, or xcframework paths outside the file-glob groups in
design Part 2, and 2 add `#include <unordered_map>` to
`tools/server/server-http.h` with null functional impact (the
include was already available transitively). The follow-up
owner is the next Stage 11 cycle that reopens the upstream
merge activity; the lift condition is `upstream_master` tip
at least 25 commits behind actual upstream `master`, or the
Manager opens a new Stage 11 cycle for any other reason.

## Evidence pointers (historical, INVALIDATED)

- Main test report: [../../.test_reports/test-report-20260604-04.md](../../.test_reports/test-report-20260604-04.md)
- Bug-fix handoff: [../../.test_reports/test-report-20260604-04-fixes.md](../../.test_reports/test-report-20260604-04-fixes.md)
- Rerun test report: [../../.test_reports/test-report-20260604-04-rerun.md](../../.test_reports/test-report-20260604-04-rerun.md)
- Rerun fixes handoff: [../../.test_reports/test-report-20260604-04-rerun-fixes.md](../../.test_reports/test-report-20260604-04-rerun-fixes.md)
- Architect bug-fix review gate 01: [./part-08-architect-bug-fix-review-gate-01.md](./part-08-architect-bug-fix-review-gate-01.md)
- T114a lift attempt evidence: `test-report-20260604-04-rerun.md` "T114a lift attempt via 3 focused test functions" section
- Coverage evidence: `coverage-run/coverage-report.md` (`## Combined result` block PASS, `## Product-only result` block FAIL)

## Closure rationale (historical, INVALIDATED)

The T114 combined 80% floor (0.8508) is met for the
19-file hybrid-mode denominator. The T115 per-file
aggregation rule is met (per-file table lists each file
exactly once). The T121 public checkpoint admission row
is non-zero on a hybrid-mode MTP server
(`cache_checkpoint_admission_failures_total{mode="hybrid"} 3`).
The T114a product-only 70% floor is 0.0026 below the
threshold (0.6974) and is recorded as a known MSVC `/Ob2`
inlining tooling limitation with a follow-up plan. The
T114a FAIL row is not reclassified to PASS; the closure
record documents the tooling limitation as the reason
Stage 11 closes with the T114a row in FAIL. The next stage
is Stage 12 (Stress Testing and Benchmarking) per the
architecture doc, or a future Stage 11 cycle that
re-opens the upstream merge activity.
