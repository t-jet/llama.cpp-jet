# Part 114: Architect D39-EXEC-28 crash-plan review

Date: 2026-07-14
Verdict: PASS; BOUNDED TEST-ONLY FIX READY FOR MANAGER GATE
Scope: Part 112 crash evidence and Part 113 diagnosis

## Review result

Part 113 identifies the crash correctly. `tests/test-cache-controller.cpp`
includes `<cassert>` while the Release definition of `NDEBUG` is active, then
undefines `NDEBUG` after the header has defined `assert`. The later undef does
not restore the macro. Release therefore removes expressions inside `assert`.

The failing Stage 23 test puts both payload attaches inside `assert`. Neither
attach runs, the entry list stays empty, and the next `std::next(begin())` and
`front()` accesses have undefined behavior. This explains the immediate
`0xC0000005` after the test banner. The later eviction calls are hidden by the
same pattern and would also disappear after the first crash was removed.

This is F39-TEST-01, a Release test-seam bug. It is not a cache product defect,
Stage 39 seam defect, model failure, or build-freshness failure. Part 112's
completed Stage 39 probe and fault results remain valid, but the controller
gate stays incomplete until the full suite exits zero.

## Exact fix contract

Change only
`test_stage23_demotion_budget_fallback_stale_completion_checkpoint_attach` in
`tests/test-cache-controller.cpp`. Do not move `NDEBUG`, change production
code, or broaden this correction to other tests.

Before taking `next()` or `front()`, require exactly two entries. Convert all
12 `assert` calls in this test to `require_or_abort` or equivalent explicit
abort checks:

- both payload attaches and both evictions, so all four side effects execute;
- both nonzero payload-ID checks;
- the first cold and second evicted residency checks after eviction;
- second-payload hot-map absence;
- the `demotion_budget_pressure` metric-reason check; and
- both final residency checks.

Keep the explicit rejected checkpoint-admission and nonempty failure-reason
checks unchanged. This preserves test meaning while making every setup action
and result check active in Release. No cardinality check may rely on `assert`.

## Retest gate

After the patch receives review, Manager may authorize:

1. one incremental Release seam build of `test-cache-controller` only; and
2. one complete controller-suite run.

Record the test-source hash across the window, build and controller exits, the
Stage 23 verdict, both Stage 39 common-epilogue fault verdicts, all seven
forbidden-effect probe verdicts, and the suite completion line. Stop on build
or test failure.

The fresh `llama-server` evidence from Part 112 remains usable because this
fix changes no server or product input. Pure tests, route nodes, default and
canonical builds, coverage, and full QA remain blocked until the corrected
controller result passes Architect review.

No Design Part 54 is needed. The correction changes only Release-safe test
execution and assertions, not architecture or product behavior. Next owner is
Manager for the bounded test-fix gate.
