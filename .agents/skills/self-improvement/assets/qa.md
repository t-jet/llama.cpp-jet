# QA improvement memory

## Improvement: scan split-plan siblings

Condition:
- When updating a split QA plan with part files

Action:
- Do scan the whole part directory for stale duplicate or unlinked files, not only the files linked by the entry document; remove obsolete duplicates rather than leaving conflicting test guidance beside the active plan.

## Improvement: verify automation coverage claims

Condition:
- When reviewing a QA plan that claims scripted coverage for named test IDs, broad scenario ranges, or negative-test ranges

Action:
- Do search the runner scripts and focused test sources for those exact IDs or required behaviors, compare the implemented assertions with the plan, and split public-harness coverage from acceptance rows that need focused, draft-fixture, stats-capable, or fault-injection evidence; map every PASS claim to specific test names or source lines, and update runner PASS/BLOCKED logic only when the current task requires automation changes.

## Improvement: reconcile runner summaries with evidence

Condition:
- When a test runner emits conflicting console output, exit codes, generated reports, skip/fail summaries, blank/UNKNOWN rows, or inflated totals

Action:
- Do inspect the generated report and raw logs, rerun narrow direct checks for disputed cases or truncated startup logs when possible, count only real test rows, and base final PASS/FAIL/SKIP/BLOCKED counts on verified evidence rather than the runner exit code or summary alone.

## Improvement: suppress PowerShell helper output

Condition:
- When adding or editing PowerShell QA harness functions that build result arrays or markdown reports

Action:
- Do suppress non-result command output from cleanup helpers and HTTP request helpers with assignment, filtering, or `[void]`; otherwise stray return values can become blank or malformed report rows.

## Improvement: validate generated markdown reports

Condition:
- When a PowerShell QA runner generates markdown with fenced command or evidence blocks

Action:
- Do inspect the generated report before accepting the run, and use markdown fences that PowerShell will not escape inside expandable strings, such as tildes or doubled backticks.

## Improvement: keep report suffixes chronological

Condition:
- When creating a fresh per-session QA report in a directory that already has same-day reports

Action:
- Do assign the next suffix after the highest existing same-day report, not the first missing gap, so the newest report is also the lexically latest handoff artifact.

## Improvement: check async test timing after fixing disabled assertions

Condition:
- When a TEST_ASSERT or similar fix re-enables previously disabled assertions in async tests that call process_completions after demote_payload or promote_payload

Action:
- Do verify that each async test includes a sleep_for before process_completions; previously masked race conditions become visible when assertions start working; run both Debug and Release to confirm the failure is not configuration-specific; classify the failure as a test bug, not a product bug, and hand off to Developer for a targeted sleep_for addition.

## Improvement: reserve report artifacts under final suffix

Condition:
- When a QA execution session will create ad hoc artifact directories and may also run scripts that generate their own reports

Action:
- Do decide the final session report suffix before collecting ad hoc artifacts, and store those artifacts under a path named for that final report so evidence links do not point at a different report number.

## Improvement: separate plan updates from product handoffs

Condition:
- When a QA planning task uncovers a product-code prerequisite or incompatibility that would block planned rows

Action:
- Do leave product code untouched, make the planned expectation explicit, and record a Developer handoff with the verified source evidence instead of weakening or omitting the blocked QA scenario.

## Improvement: classify startup-only mode failures

Condition:
- When a public model-mode QA row cannot reach `/health` before cache behavior is observable

Action:
- Do classify the row as `BLOCKED` for cache acceptance, preserve startup logs and exit codes, and create a separate bug handoff when the process crashes or exits without a clear unsupported-mode diagnostic.

## Improvement: discard stale harness flag failures

Condition:
- When a QA execution uses plan default server flags and startup fails before model loading with an invalid-argument error

Action:
- Do treat that attempt as a harness setup error, remove or correct only the unsupported flag, rerun the same row, and base the row outcome on the rerun rather than the stale default failure.

## Improvement: avoid automatic-variable names in PowerShell harnesses

Condition:
- When writing or running inline PowerShell QA helpers that pass CLI arguments to a server process

Action:
- Don't use parameter or variable names that collide with PowerShell automatic variables such as `Args`; use explicit names like `ServerArgs`, preserve the discarded harness logs if a collision starts the wrong mode, and rerun before classifying product behavior.

## Improvement: verify Release-mode assertions in focused C++ tests

Condition:

- When running focused C++ tests in Release configuration where `NDEBUG` is defined

Action:

- Do check that `#undef NDEBUG` appears before `#include <cassert>` in every test file, not after; if assertions are silently disabled, a Release-only crash may mask a real product bug or test infrastructure bug; run the Debug build as a cross-check and classify Release-only crashes as test infrastructure defects requiring Developer investigation before marking the test step as PASS.

## Improvement: verify markdown constraints after QA doc edits

Condition:
- When editing reusable QA markdown that must stay under repository line-count, ASCII, and whitespace rules

Action:
- Do check initial line counts before editing near-limit QA docs, keep additions within the remaining line budget, then rerun line-count, ASCII-byte, whitespace, link, and diff-shape checks on every touched markdown file before final handoff, including new untracked part files that `git diff --check` will not inspect; preserve existing line endings where practical, and if a tool changes them, normalize deliberately and rerun `git diff --check`.

## Improvement: separate own QA edits from dirty sources

Condition:
- When a QA review task uses or indexes documents that are already modified or untracked in the working tree

Action:
- Do check `git status --short` for the reviewed and edited paths, distinguish pre-existing plan/source changes from files changed in the review, and report only the review-owned edits as your own handoff changes.

## Improvement: wait for model-specific readiness in public probes

Condition:
- When a public HTTP harness starts `llama-server` with secondary model resources such as draft, MTP, multimodal, or adapter fixtures

Action:
- Do treat `/health` as process readiness only; wait for a model-specific log marker when the build emits one, or make the first behavior request a guarded readiness/admission probe and require direct secondary-resource evidence such as `draft_n > 0` before accepting later restore or hit claims; preserve marker-less setup attempts separately from product evidence, and keep startup log verbosity low unless diagnostics require it.

## Improvement: classify available fixture no-evidence runs

Condition:
- When a suitable model-backed fixture is available and the public probe starts successfully but the expected cache-specific counters, timings, or checkpoint rows remain at zero or placeholder values

Action:
- Do classify the fixture row as FAIL rather than fixture-unavailable BLOCKED/SKIP, preserve request, response, metrics, and startup artifacts, and separately note any focused substitute evidence that still passed.

## Improvement: prove public checkpoint admission before restore claims

Condition:
- When a public checkpoint-dependent probe needs a long prompt, small batch size, or boundary metadata to exercise checkpoint restore or public checkpoint metrics

Action:
- Do first prove the request fits the context and increments accepted checkpoint admission; if the run only creates live checkpoints, fails admission, or returns a request-shape error, preserve it as setup or blocker evidence and classify restore/hit rows as BLOCKED/SKIP unless model-backed checkpoint restore evidence is captured.

## Improvement: load required memory before status updates

Condition:
- When a task requires self-improvement memory to be read before any other action

Action:
- Do read the skill and agent memory before sending any acknowledgement, skill announcement, status update, task analysis, or parallel tool call; treat every user-visible reply and all task-specific file inspection as task action.
