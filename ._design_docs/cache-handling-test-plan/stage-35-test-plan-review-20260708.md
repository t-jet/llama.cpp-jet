# Stage 35 test-plan review 2026-07-08

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewed plan part: [part-40-stage35-upstream-merge-regression.md](part-40-stage35-upstream-merge-regression.md)

## Verdict

REWORK.

The Stage 35 plan is current and covers the Manager-required regression scope,
but one blocking command-consistency issue must be fixed before execution can
use it as the gate plan.

## Scope reviewed

- [document-index.md](../document-index.md)
- [cache-handling-test-plan.md](../cache-handling-test-plan.md)
- [part-40-stage35-upstream-merge-regression.md](part-40-stage35-upstream-merge-regression.md)
- [cache-handling-phase35-design.md](../cache-handling-phase35-design.md)
- [cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)
- [part-31-manager-implementation-gate-20260708.md](../cache-handling-phase35-implementation/part-31-manager-implementation-gate-20260708.md)

No test execution was run. This is a fresh test-plan review only.

## Blocking findings

### F35-TP-01: Artifact root is inconsistent between prose and commands

Status: BLOCKING

Evidence:

- Part 40 says non-durable logs and artifacts go under
  `._test_output/stage35-upstream-merge-YYYYMMDD-NN/` at lines 55-57.
- The Stage 34 synthetic dry-run command writes to
  `_test_output\stage35-upstream-merge-YYYYMMDD-NN\stage34-synthetic` at
  lines 210-212.
- The coverage command writes to
  `_test_output\stage35-upstream-merge-YYYYMMDD-NN\coverage` at lines 218-220.

Why this blocks:

The plan must give one artifact root so the execution report can prove row
evidence without ambiguity. With the current wording, an executor can follow
the prose and commands exactly and still split evidence across two root trees.
That breaks the "fresh per-session output root" rule and makes path validation
weaker than the plan intends.

Required correction:

Pick one project-root output convention for Stage 35 and make the prose,
commands, evidence-format bullets, and path checks use the same spelling. If
the intended root is `_test_output/`, update the line 57 prose. If the intended
root is `._test_output/`, update the command examples and any row text that
checks output placement.

## Non-blocking checks

- Scope is current for the open no-commit merge against
  `origin/upstream_master=47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.
- The plan does not reuse Part 27, Part 29, or Part 30 implementation-review
  evidence as QA execution evidence.
- Manager-required rows are present: clean build, source refs, cache core,
  MTP/KV/speculative pair state, route/session/router child state, checkpoint
  spans, metrics, cold-store conditionals, Stage 34 replay conditionals, and
  coverage conditionals.
- Clean build and stale-binary rules are explicit.
- PASS, FAIL, BLOCKED, and SKIP criteria are concrete enough for execution.
- Evidence format requires report ID, source proof, build logs, raw row logs,
  fixtures, HTTP snippets, metrics parser output, cold-store listings, replay
  paths, coverage paths, and bug handoff details.
- Links in Part 40 resolve from the part-file directory.
- Part 40 contains no stale specific-run test evidence; dated references are
  source documents, not execution evidence.

## Hygiene checks

- `cache-handling-test-plan.md`: 299 lines before this review link was added.
- `part-40-stage35-upstream-merge-regression.md`: 227 lines.
- `cache-handling-phase35-design.md`: 237 lines.
- `cache-handling-phase35-implementation.md`: 138 lines.
- Manager implementation gate part: 55 lines.
- Part 40 and the test-plan entry are ASCII-only, LF-only, no BOM, and no
  trailing whitespace.
- No unicode status icons were found in the reviewed plan files.

## Handoff

Next owner: QA plan author.

Next gate: Stage 35 test-plan re-review after F35-TP-01 is corrected.
