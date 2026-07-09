# Stage 35 independent test-plan re-review 2026-07-08

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewed plan part: [part-40-stage35-upstream-merge-regression.md](part-40-stage35-upstream-merge-regression.md)

## Verdict

PASS.

F35-TP-01 is corrected. Part 40 now uses one project-root artifact root,
`_test_output/stage35-upstream-merge-YYYYMMDD-NN/`, across active prose and
command examples. No new blocking issue was introduced by the correction.

## Scope reviewed

- [document-index.md](../document-index.md)
- [cache-handling-test-plan.md](../cache-handling-test-plan.md)
- [part-40-stage35-upstream-merge-regression.md](part-40-stage35-upstream-merge-regression.md)
- [stage-35-test-plan-review-20260708.md](stage-35-test-plan-review-20260708.md)
- [part-31-manager-implementation-gate-20260708.md](../cache-handling-phase35-implementation/part-31-manager-implementation-gate-20260708.md)

No test execution was run. This is a fresh plan re-review only. The earlier
`stage-35-test-plan-re-review-20260708.md` was not used as authority.

## F35-TP-01 correction check

Status: PASS

Evidence:

- Correction note names `_test_output/stage35-upstream-merge-YYYYMMDD-NN/` at
  Part 40 lines 10-12.
- Execution preconditions put non-durable logs and artifacts under the same
  root at lines 60-62.
- Stage 34 synthetic command writes to
  `_test_output\stage35-upstream-merge-YYYYMMDD-NN\stage34-synthetic` at lines
  214-217.
- Coverage command writes to
  `_test_output\stage35-upstream-merge-YYYYMMDD-NN\coverage` at lines 222-225.
- Evidence format still requires the execution report to include the test run
  id and artifact root at line 167.

The remaining `._design_docs/cache-handling-test-scripts/._test_output/`
string at line 154 is a forbidden-placement check for Stage 34 synthetic rows,
not an alternate Stage 35 artifact root.

## Other review checks

- Part 40 remains generic planning. It does not cite Part 27, Part 29, or Part
  30 focused evidence as QA execution evidence.
- Required Manager scope is still represented: clean build, source state, cache
  core, MTP/KV/speculative pair state, route/session/router child state,
  checkpoint spans, metrics, conditional cold-store checks, conditional Stage
  34 replay/synthetic checks, and focused coverage.
- Command checklist uses the same `build-stage35-qa` build root as the clean
  build precondition and keeps `-OutputDir`/`-OutDir` under the corrected
  `_test_output/stage35-upstream-merge-YYYYMMDD-NN/` root.
- PASS, FAIL, BLOCKED, and SKIP criteria remain generic and not tied to a
  specific run result.
- Local links in Part 40 and the parent test-plan entry resolve from their own
  directories.

## Hygiene

- `document-index.md`: 249 lines, ASCII, LF, no BOM, no trailing whitespace.
- `cache-handling-test-plan.md`: 299 lines before this link update.
- `part-40-stage35-upstream-merge-regression.md`: 232 lines, ASCII, LF, no BOM,
  no trailing whitespace.
- `stage-35-test-plan-review-20260708.md`: 92 lines, ASCII, LF, no BOM, no
  trailing whitespace.
- Manager implementation gate part: 55 lines, ASCII, LF, no BOM, no trailing
  whitespace.
- `git diff --check` reported no whitespace errors for the reviewed tracked
  document diffs. Untracked review and part files were checked directly.
- No unicode status icons were found in the reviewed plan files.

## Handoff

Next owner: Manager.

Next gate: Stage 35 Manager test-plan gate or QA execution opening decision.
