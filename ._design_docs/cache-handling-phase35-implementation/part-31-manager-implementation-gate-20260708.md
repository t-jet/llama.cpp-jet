# Stage 35 Manager implementation gate 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Verdict

PASS. Stage 35 implementation is accepted for the current no-commit merge
state.

## Evidence reviewed

- Part 27 source-fix evidence: focused build passed, direct
  `test-cache-controller` passed 149 tests, `ctest -C Release -R cache` passed
  1/1, and `test_router_props` passed.
- Part 28 implementation review: REWORK on F35-IMPL-01.
- Part 29 rework evidence: callback composition fix, focused build passed,
  direct `test-cache-controller` passed 150 tests, and `ctest -C Release -R
  cache` passed 1/1.
- Part 30 implementation re-review: PASS. Architect verified local sleep
  destroy/reload behavior, router notification ordering, guarded test hooks,
  and Stage 25/34 invariant preservation.
- Source refs remain aligned: `MERGE_HEAD` and `origin/upstream_master` both
  equal `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.
- No unresolved conflict paths are present.

## Gate decision

Implementation review is closed. No blocking implementation findings remain for
the focused Stage 35 merge-resolution scope.

The next gate is test planning. The shared cache handling test plan is current
through Stage 34 and does not yet contain a Stage 35 upstream-merge regression
part. QA must add or correct a Stage 35 test plan before any full Stage 35 test
execution report can count as valid gate evidence.

## Required QA test-planning scope

The Stage 35 test plan must cover the merge/rework plan's regression matrix:

- clean build rules and stale-binary checks;
- cache core focused evidence;
- MTP, KV, speculative, and target/draft pair-state checks;
- route/session lifecycle and router child state checks;
- checkpoint placement and message-span boundary checks;
- metrics bounded-label and HELP/TYPE checks;
- cold-store/filesystem checks when touched;
- Stage 34 replay or synthetic agentic rows for branch/session, stream resume,
  `tx_save`, save/restore, or slow-read paths;
- focused coverage expectations if feature-mode source files changed.

## Next owner

QA.

Next gate: Stage 35 test planning.
