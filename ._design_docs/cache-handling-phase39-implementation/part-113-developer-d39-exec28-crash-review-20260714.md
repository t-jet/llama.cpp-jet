# Part 113: Developer D39-EXEC-28 crash review

Date: 2026-07-14
Verdict: REWORK; RELEASE TEST-SEAM BUG
Scope: read-only diagnosis of the D39-EXEC-28 controller access violation

## Evidence reviewed

The incremental Release build passed and rebuilt `server-cache-hybrid.cpp` for
both authorized targets. Guarded source hashes stayed unchanged. The controller
then passed all seven Stage 39 observation probes and both common-epilogue fault
tests before exiting with `0xC0000005`.

The final line names
`test_stage23_demotion_budget_fallback_stale_completion_checkpoint_attach`.
Only its controller construction ran far enough to emit another record. The
next operations are two payload attaches wrapped in `assert`, followed by
`std::next(stage22_entries(ctrl).begin())` and `front()`.

`tests/test-cache-controller.cpp` includes `<cassert>` at line 9 and undefines
`NDEBUG` at line 26. That order is ineffective: `<cassert>` has already defined
`assert` as a no-op for the Release translation unit. The same file documents
this Release behavior in the Stage 28 regression beside this test.

Both payload attaches therefore disappear. The entry list remains empty, and
the next iterator/front access has undefined behavior. This directly explains
the immediate access violation before a test verdict. Later setup operations
in the same test, including both evictions, are also hidden inside `assert` and
would not execute after the first crash is fixed.

## Classification

F39-TEST-01 is a test-seam bug. It is not a product bug, model issue, build
failure, or insufficient-evidence blocker. The fresh build and the completed
Stage 39 cases remain valid evidence, but the full controller-suite gate remains
blocked because the process did not finish.

No Stage 39 product path caused this crash. After controller construction, the
Release test skipped both attach calls and reached invalid test-container
access before the intended demotion and checkpoint-admission path could run.

## Bounded fix

Change only
`test_stage23_demotion_budget_fallback_stale_completion_checkpoint_attach` in
`tests/test-cache-controller.cpp`:

1. Replace every binding `assert` with `require_or_abort` or an equivalent
   explicit abort check so setup and eviction calls execute in Release.
2. Require exactly two entries before taking `next()` or `front()`.
3. Keep the existing expected residency, map absence, metric-reason, rejected
   checkpoint admission, and populated failure-reason checks unchanged in
   meaning.

Do not change production cache code, the Stage 39 seam, route helper, model
fixture, budgets, defaults, or test scope.

## Retest proposal

After review of the test-only patch, authorize one incremental Release seam
build of `test-cache-controller` and one complete controller-suite run. Record
the test source hash across the window, build exit, controller exit, this Stage
23 verdict, both Stage 39 fault verdicts, all seven observation-probe verdicts,
and the suite completion line. Stop on build or test failure.

The current fresh `llama-server` evidence remains usable because this fix does
not touch server or product inputs. Pure tests, model route nodes, default and
canonical builds, coverage, and full QA remain blocked until the corrected
controller run passes and receives fresh review.

