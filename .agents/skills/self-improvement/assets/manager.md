# Manager improvement memory

## Improvement: stage gate reconstruction

Condition:

- When starting or resuming a staged delivery workflow from manager mode

Action:

- Do reconstruct progress from `document-index.md`, the requested stage source, and the latest durable prior-stage implementation, fix, and test-report evidence before selecting exactly one active gate; at closure, compare earlier blocked reports against later reconciliation reports before deciding, treat stale entry-document statuses or a missing durable closure decision as gate-blocking documentation work, and explicitly state whether any docs were changed.

## Improvement: memory-first startup

Condition:

- When an incoming task requires self-improvement memory loading before task work

Action:

- Do read the self-improvement skill and agent memory file before sending any progress update or starting task-specific inspection.

## Improvement: closure stale-status sweep

Condition:

- When closing a stage after QA rerun or bug-fix evidence changes the stage state

Action:

- Do search linked parent docs and stage parts for stale status phrases such as `current gate`, `ready for QA`, `open`, and `blocked`; update durable entry docs, test-plan scope notes, and index descriptions so they match the closure decision, but treat older report-local next-action text as historical when a later entry doc or reconciliation part explicitly supersedes it.

## Improvement: codex delegation flags

Condition:

- When delegating a fresh agent session through `codex exec`

Action:

- Do pass global CLI options such as `--cd`, `--sandbox`, and `-a never` before the `exec` subcommand, then pass the prompt with `exec -`; use a timeout long enough for documentation edits and, if the wrapper times out, inspect the worktree and target deliverables before deciding whether to rerun; don't put global options after `exec`.

## Improvement: subagent lifecycle during gated workflows

Condition:

- When managing a long staged workflow with repeated fresh review or correction sessions

Action:

- Do close completed subagents after their durable deliverable has been checked and before spawning the next gate owner, so the agent thread limit does not block required handoffs.

## Improvement: reopen test execution on tooling unblock

Condition:

- When a fresh QA report has rows blocked solely by missing host tools (LLVM coverage, k6, Python deps, fixtures) and the user reports those tools are now available, before the Developer test-results review runs

Action:

- Do reopen the Test execution gate with a new report file (test-report-YYYYMMDD-NN.md) plus a paired -fixes.md instead of routing the prior blocked report into the developer review or the bug-fix loop; do not let the developer triage tooling unavailability as a product bug; do not edit the prior blocked report except to add a final-status pointer, and do not let the rerun silently drop prior BLOCKED rows - reclassify each one explicitly as PASS or FAIL with evidence; require the new report to record the exact toolchain entry path (for example vsdevcmd.bat) and tool versions in the environment section so a future reader can reproduce the unblock.

## Improvement: do not close a stage with unmet or BLOCKED requirements

Condition:

- When a test execution report contains FAIL or BLOCKED rows and the stage's approved test plan or design sets those rows as closure requirements (e.g., 80% coverage threshold, fixture-backed public metric rows, benchmark scenarios)

Action:

- Don't reclassify FAIL or BLOCKED rows to BLOCKED-with-evidence, BLOCKED-with-coverage-evidence, or any other softening status just to clear the closure checklist; the test plan rule against recording missing tools, dependencies, model fixtures, coverage output, or benchmark output as accepted skips applies to closure too, and reclassification to BLOCKED-with-evidence is functionally a softer form of the same violation; do route the failing or blocked rows to the bug-fix loop or a new fix-deliverable gate and require Developer to actually meet the requirements (add focused tests, fix automation scripts, add fixtures) or require Manager to make a real plan-change decision recorded in the test plan itself, not in a reclassification; do not call the stage closed until every row in the test report is PASS or has a recorded Manager plan-change decision in the test plan, with the final counts in the implementation log entry doc reflecting the actual state; if the only path forward requires new test code, new scripts, or new fixtures, open a Developer bug-fix session in a fresh subagent and have QA re-execute the test plan with the new evidence before retrying closure; the closure doc sweep must be the LAST step after all rows are resolved, not a step that papers over the open ones.

## Improvement: subagent re-delegation with a sharper focus prompt after interruption

Condition:

- When a fresh subagent delegation in runSubagent returns a partial or distracted result (mid-investigation, no final deliverable) and the artifacts the agent should have produced are not on disk

Action:

- Do re-delegate to a fresh subagent session with a sharper focus prompt that starts with "STOP investigating" or "DO NOT [action]"; include a single explicit verification step (such as "run this one PowerShell command to confirm the artifacts dir exists") so the agent confirms the target before writing; enumerate the exact files to create with their full content requirements; explicitly forbid re-running builds, tests, coverage, or k6 when the goal is to finalize a report from existing artifacts; tell the agent to return a single concise summary message with the verdict, file paths, and next gate; do not over-explain the workflow history in the re-delegation prompt - the new agent has fresh context and only needs the immediate task.

## Improvement: delegate stage-closure doc sweep to Architect

Condition:

- When a stage is ready for closure and the durable design or implementation documents have stale status phrases that contradict the closure decision

Action:

- Do delegate the closure doc sweep to the Architect in a fresh session, with explicit Manager decisions on each open item; have the Architect update the stage entry doc (status line, current-gate sentence, new closure section with final counts and Manager reclassifications and follow-up tasks), the document-index.md (entry description, new test-report rows), and any test-plan scope notes that record run-specific outcomes; require the Architect to run `git diff --check` on every touched file and report clean exit; tell the Architect explicitly not to edit the test plan to record coverage gaps, fixture limitations, or benchmark-scope gaps as accepted skips, and not to edit the final test report, paired fixes, or developer review files; have the Architect return a list of modified files, the git diff --check result, the stale-phrase grep result, and any deviations from the Manager decisions with justification.

## Improvement: verify artifacts on disk before re-delegating after truncated subagent text

Condition:

- When a fresh subagent delegation in runSubagent returns a partial or truncated text response but the worktree shows that the expected files for the gate have been created or modified

Action:

- Do not re-delegate; instead, read each expected artifact directly (file_search, read_file, grep_search scoped to the gate's expected files, git status --short scoped to the gate, git diff --check on the same scope) and decide based on artifact quality, not on the completeness of the text response; treat a truncated text response with complete on-disk artifacts as a successful gate and proceed to the next handoff; do re-delegate only when the artifacts are missing, incomplete, or fail the verification step; this is the complement of the "subagent re-delegation with a sharper focus prompt after interruption" entry, which assumes artifacts are missing.

## Improvement: verify script edits with whitespace-ignoring diff and raw byte count

Condition:

- When a Developer in a fresh subagent session edits a script file (PowerShell, shell, or any text file with line endings) on Windows and the full `git diff --stat` shows an unexpectedly large insertion or deletion count

Action:

- Do run `git diff -w --stat` and `git diff -w` to see the content-only changes; do read the worktree file as raw bytes and count CR (0x0D) and LF (0x0A) to confirm the file is LF-only (CR=0) or CRLF (CR>0 and matches HEAD) before declaring the work ready for review; do not rely on the full `git diff --stat` for content review, because the Windows edit tool's CRLF handling can rewrite line endings throughout the file and produce a noisy diff (for example, 439 insertions and 399 deletions for a 40-line content addition); do record the noise as a non-blocking observation in the Architect review report rather than rejecting the work, because the content is correct and the file state is correct.

## Improvement: confirm external prerequisites before delegating a main implementation gate

Condition:

- When a stage design or plan commits to an external reference (upstream remote URL, third-party service endpoint, hosted environment, or shared infrastructure) and the local repo or worktree does not have that reference configured

Action:

- Do not delegate the main implementation gate; instead, surface the missing reference as a Manager decision point with the local-repo state and the design assumption side by side; do not let the Developer add the remote, pick a fallback branch, or redefine the reference strategy, because that decision belongs to the Manager and may have credential, rate-limit, security, or contract implications; do offer the user the specific resolution paths (add the configured remote, use an existing tracking branch, or pause and revise the design) and wait for the explicit choice before continuing.

## Improvement: re-delegate with explicit word cap when a subagent response exceeds the model limit

Condition:

- When a fresh subagent delegation in runSubagent returns the client error "Response too long" (or an equivalent provider-side token or output length error) and the subagent did not produce a usable return message

Action:

- Do not treat the error as a subagent failure; do re-delegate to a fresh subagent session with a tighter prompt that names an explicit return-message cap (for example "MAX 500 words" or "under 600 words") and lists the exact fields the return must include in that order; do shorten the source-document list to the essential 4-6 files and explicitly tell the agent to skip reading large source files unless absolutely required; do keep the work instructions specific (exact commands, exact paths, exact commit SHAs) so the subagent can execute without inventing structure; do not ask the subagent to summarize files it has not read.
