# QA improvement memory

## Improvement: scan split-plan siblings

Condition:
- When updating a split QA plan with part files

Action:
- Do scan the whole part directory for stale duplicate or unlinked files, not only the files linked by the entry document; remove obsolete duplicates rather than leaving conflicting test guidance beside the active plan.

## Improvement: verify automation coverage claims

Condition:
- When reviewing a QA plan that claims scripted coverage for named test IDs or scenario ranges

Action:
- Do search the runner scripts and focused test sources for those exact IDs or required behaviors, compare the implemented assertions with the plan, and map every PASS claim to specific test names or source lines; when a public harness cannot create a required precondition, update the plan, README, and runner PASS/BLOCKED logic so the invalid path cannot be reported as pass-capable evidence.

## Improvement: reconcile runner summaries with evidence

Condition:
- When a test runner emits conflicting console output, exit codes, generated reports, or skip/fail summaries

Action:
- Do inspect the generated report and raw logs, rerun narrow direct checks for disputed cases when possible, and base final PASS/FAIL/SKIP/BLOCKED counts on verified evidence rather than the runner exit code or summary alone.

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
