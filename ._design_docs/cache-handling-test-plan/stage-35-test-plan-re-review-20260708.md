# Stage 35 test-plan re-review 2026-07-08

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewed plan part: [part-40-stage35-upstream-merge-regression.md](part-40-stage35-upstream-merge-regression.md)

Prior review: [stage-35-test-plan-review-20260708.md](stage-35-test-plan-review-20260708.md)

## Verdict

PASS.

F35-TP-01 is fixed. The corrected plan uses the project-root
`_test_output/stage35-upstream-merge-YYYYMMDD-NN/` artifact root in both prose
and executable command examples, so the Stage 35 test execution gate can use
Part 40 as the regression plan after Manager opens execution.

## Scope reviewed

- [document-index.md](../document-index.md)
- [cache-handling-test-plan.md](../cache-handling-test-plan.md)
- [part-40-stage35-upstream-merge-regression.md](part-40-stage35-upstream-merge-regression.md)
- [stage-35-test-plan-review-20260708.md](stage-35-test-plan-review-20260708.md)
- [cache-handling-phase35-design.md](../cache-handling-phase35-design.md)
- [cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)
- [part-31-manager-implementation-gate-20260708.md](../cache-handling-phase35-implementation/part-31-manager-implementation-gate-20260708.md)

No tests were run. This is a fresh test-plan re-review only.

## Findings

No blocking, non-blocking, or informational findings remain.

## F35-TP-01 verification

Status: FIXED

Evidence:

- Part 40 now says non-durable artifacts go under
  `_test_output/stage35-upstream-merge-YYYYMMDD-NN/` at lines 60-62.
- The Stage 34 synthetic dry-run command writes to
  `_test_output\stage35-upstream-merge-YYYYMMDD-NN\stage34-synthetic` at
  lines 215-217.
- The coverage command writes to
  `_test_output\stage35-upstream-merge-YYYYMMDD-NN\coverage` at lines 223-225.

The prose and commands now agree on one project-root output tree. The remaining
negative check at line 150 correctly forbids the old nested durable-docs output
pattern and does not conflict with the selected root.

## Re-review checks

- Scope matches the Manager implementation gate: clean build, stale-binary
  checks, cache core, MTP/KV/speculative pair state, route/session/router child
  state, checkpoint message spans, bounded metrics, cold-store checks when
  touched, Stage 34 replay/synthetic rows when touched, and focused coverage.
- The plan stays generic. It does not turn Part 27, Part 29, Part 30, or
  implementation-review evidence into QA execution evidence.
- Clean-build and stale-binary rules are explicit, including a fresh
  `build-stage35-qa` build and binary mtime comparison against touched sources.
- Evidence format requires source refs, open-merge proof, clean-build logs,
  raw per-row logs, fixture blockers, HTTP snippets, metrics parser output,
  cold-store listings, replay paths, coverage paths, and bug handoff details.
- PASS, FAIL, BLOCKED, and SKIP criteria are concrete enough for execution.
- Conditional rows are tied to touched files, fixture availability, tooling, or
  Manager direction. Obsolete scenarios are not hidden behind exclusions.
- Commands are consistent with the selected build directory, server binary env
  var, router smoke, replay output root, and coverage output root.
- Links in Part 40 and this report resolve from their own directories.
- Reviewed files use ASCII status labels. No unicode status icons were found.

## Hygiene checks

- `cache-handling-test-plan.md`: 300 lines after the re-review link update.
- `part-40-stage35-upstream-merge-regression.md`: 232 lines.
- `stage-35-test-plan-review-20260708.md`: 92 lines.
- `cache-handling-phase35-design.md`: 237 lines.
- `cache-handling-phase35-implementation.md`: 140 lines.
- Manager implementation gate part: 55 lines.
- New re-review report: under the 300-line cap, ASCII-only, LF-only, no BOM,
  and no trailing whitespace.

## Handoff

Next owner: Manager.

Next gate: Manager may open Stage 35 test execution. Commit, push, PR, reviewer
response, and merge-abort actions remain blocked unless separately requested.
