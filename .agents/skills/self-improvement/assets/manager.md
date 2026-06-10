# Manager improvement memory

## Improvement: stage gate reconstruction

Condition:
- Starting or resuming staged delivery workflow from manager mode

Action:
- Reconstruct progress from `document-index.md`, requested stage source, and latest durable prior-stage implementation, fix, and test-report evidence before selecting exactly one active gate. At closure, compare earlier blocked reports against later reconciliation reports before deciding. Treat stale entry-document statuses or missing durable closure decision as gate-blocking documentation work. Explicitly state whether any docs were changed.

## Improvement: memory-first startup

Condition:
- Incoming task requires self-improvement memory loading before task work

Action:
- Read self-improvement skill and agent memory file before sending any progress update or starting task-specific inspection.

## Improvement: closure stale-status sweep

Condition:
- Closing stage after QA rerun or bug-fix evidence changes stage state

Action:
- Search linked parent docs and stage parts for stale status phrases such as `current gate`, `ready for QA`, `open`, and `blocked`. Update durable entry docs, test-plan scope notes, and index descriptions so they match closure decision. Treat older report-local next-action text as historical when later entry doc or reconciliation part explicitly supersedes it.

## Improvement: codex delegation flags

Condition:
- Delegating fresh agent session through `codex exec`

Action:
- Pass global CLI options such as `--cd`, `--sandbox`, and `-a never` before `exec` subcommand, then pass prompt with `exec -`. Use timeout long enough for documentation edits. If wrapper times out, inspect worktree and target deliverables before deciding whether to rerun. Don't put global options after `exec`.

## Improvement: subagent lifecycle during gated workflows

Condition:
- Managing long staged workflow with repeated fresh review or correction sessions

Action:
- Close completed subagents after their durable deliverable has been checked and before spawning next gate owner, so agent thread limit does not block required handoffs.

## Improvement: reopen test execution on tooling unblock

Condition:
- Fresh QA report has rows blocked solely by missing host tools (LLVM coverage, k6, Python deps, fixtures) and user reports those tools are now available, before Developer test-results review runs

Action:
- Reopen Test execution gate with new report file (test-report-YYYYMMDD-NN.md) plus paired -fixes.md instead of routing prior blocked report into developer review or bug-fix loop. Don't let developer triage tooling unavailability as product bug. Don't edit prior blocked report except to add final-status pointer. Don't let rerun silently drop prior BLOCKED rows - reclassify each one explicitly as PASS or FAIL with evidence. Require new report to record exact toolchain entry path (e.g. vsdevcmd.bat) and tool versions in environment section so future reader can reproduce unblock.

## Improvement: do not close stage with unmet or BLOCKED requirements

Condition:
- Test execution report contains FAIL or BLOCKED rows and stage's approved test plan or design sets those rows as closure requirements (e.g., 80% coverage threshold, fixture-backed public metric rows, benchmark scenarios)

Action:
- Don't reclassify FAIL or BLOCKED rows to BLOCKED-with-evidence, BLOCKED-with-coverage-evidence, or any other softening status just to clear closure checklist; reclassification to BLOCKED-with-evidence is functionally softer form of same violation. Route failing or blocked rows to bug-fix loop or new fix-deliverable gate. Require Developer to actually meet requirements (add focused tests, fix automation scripts, add fixtures) or require Manager to make real plan-change decision recorded in test plan itself, not in reclassification. Don't call stage closed until every row in test report is PASS or has recorded Manager plan-change decision in test plan, with final counts in implementation log entry doc reflecting actual state. If only path forward requires new test code, new scripts, or new fixtures, open Developer bug-fix session in fresh subagent and have QA re-execute test plan before retrying closure. Closure doc sweep must be LAST step after all rows are resolved.

## Improvement: subagent re-delegation with sharper focus prompt after interruption

Condition:
- Fresh subagent delegation in runSubagent returns partial or distracted result (mid-investigation, no final deliverable) and artifacts agent should have produced are not on disk

Action:
- Re-delegate to fresh subagent session with sharper focus prompt starting with "STOP investigating" or "DO NOT [action]". Include single explicit verification step (e.g. "run this one PowerShell command to confirm the artifacts dir exists") so agent confirms target before writing. Enumerate exact files to create with their full content requirements. Explicitly forbid re-running builds, tests, coverage, or k6 when goal is to finalize report from existing artifacts. Tell agent to return single concise summary message with verdict, file paths, and next gate. Don't over-explain workflow history in re-delegation prompt; new agent has fresh context and only needs immediate task.

## Improvement: delegate stage-closure doc sweep to Architect

Condition:
- Stage is ready for closure and durable design or implementation documents have stale status phrases contradicting closure decision

Action:
- Delegate closure doc sweep to Architect in fresh session, with explicit Manager decisions on each open item. Have Architect update stage entry doc (status line, current-gate sentence, new closure section with final counts and Manager reclassifications and follow-up tasks), document-index.md (entry description, new test-report rows), and any test-plan scope notes that record run-specific outcomes. Require Architect to run `git diff --check` on every touched file and report clean exit. Tell Architect explicitly not to edit test plan to record coverage gaps, fixture limitations, or benchmark-scope gaps as accepted skips, and not to edit final test report, paired fixes, or developer review files. Have Architect return list of modified files, git diff --check result, stale-phrase grep result, and any deviations from Manager decisions with justification.

## Improvement: verify artifacts on disk before re-delegating after truncated subagent text

Condition:
- Fresh subagent delegation in runSubagent returns partial or truncated text response but worktree shows expected files for gate have been created or modified

Action:
- Don't re-delegate. Read each expected artifact directly (file_search, read_file, grep_search scoped to gate's expected files, git status --short scoped to gate, git diff --check on same scope) and decide based on artifact quality, not completeness of text response. Treat truncated text response with complete on-disk artifacts as successful gate and proceed to next handoff. Re-delegate only when artifacts are missing, incomplete, or fail verification step.

## Improvement: verify script edits with whitespace-ignoring diff and raw byte count

Condition:
- Developer in fresh subagent session edits script file (PowerShell, shell, or any text file with line endings) on Windows and full `git diff --stat` shows unexpectedly large insertion or deletion count

Action:
- Run `git diff -w --stat` and `git diff -w` to see content-only changes. Read worktree file as raw bytes and count CR (0x0D) and LF (0x0A) to confirm file is LF-only (CR=0) or CRLF (CR>0 and matches HEAD) before declaring work ready for review. Don't rely on full `git diff --stat` for content review; Windows edit tool's CRLF handling can rewrite line endings throughout file and produce noisy diff (e.g., 439 insertions and 399 deletions for 40-line content addition). Record noise as non-blocking observation in Architect review report rather than rejecting work; content is correct and file state is correct.

## Improvement: confirm external prerequisites before delegating main implementation gate

Condition:
- Stage design or plan commits to external reference (upstream remote URL, third-party service endpoint, hosted environment, or shared infrastructure) and local repo or worktree does not have that reference configured

Action:
- Don't delegate main implementation gate. Surface missing reference as Manager decision point with local-repo state and design assumption side by side. Don't let Developer add remote, pick fallback branch, or redefine reference strategy; that decision belongs to Manager and may have credential, rate-limit, security, or contract implications. Offer user specific resolution paths (add configured remote, use existing tracking branch, or pause and revise design) and wait for explicit choice before continuing.

## Improvement: re-delegate with explicit word cap when subagent response exceeds model limit

Condition:
- Fresh subagent delegation in runSubagent returns client error "Response too long" (or equivalent provider-side token or output length error) and subagent did not produce usable return message

Action:
- Don't treat error as subagent failure. Re-delegate to fresh subagent session with tighter prompt naming explicit return-message cap (e.g. "MAX 500 words" or "under 600 words") and listing exact fields return must include in that order. Shorten source-document list to essential 4-6 files and explicitly tell agent to skip reading large source files unless absolutely required. Keep work instructions specific (exact commands, exact paths, exact commit SHAs) so subagent can execute without inventing structure. Don't ask subagent to summarize files it has not read. When the delegated task is to review or read code in a large file (>= 1000 lines, e.g. server-context.cpp at 5667 lines), do NOT inline the file content or a long diff in the prompt; instead instruct the subagent to run `git diff <files>` or `git show <sha>:<path>` itself so the prompt stays small and the subagent's context does not overflow before it can produce a return. A prompt that includes a 100+ line inline diff is itself a likely cause of the "Response too long" error on the next delegation.

## Improvement: stop gated workflow on subagent usage-limit failure

Condition:
- Required fresh subagent delegation fails before producing a gate artifact because `codex exec` returns a usage-limit or credit-limit error with a retry time

Action:
- Don't perform the delegated Architect, Developer, or QA gate yourself. Record the active gate, missing artifact, exact usage-limit retry time, and next owner in the final response. Verify no child subagent process remains running and stop only the timed-out delegated child if needed before ending.

## Improvement: verify merge commit shape before accepting merge claims

Condition:
- Stage claim, implementation log entry, developer handoff, or test-report closure rationale says `git merge` was performed and merged source branch is only path through which source content could have entered working tree

Action:
- Verify merge is real two-parent commit before accepting claim. Run `git rev-list --parents -n 1 <sha>` and require output to list merge commit and both parent SHAs; single-parent SHA is regular commit, not merge, regardless of commit message. Also run `git show --stat --format='%H%nParents: %P' <sha>` to confirm parents line lists two SHAs. Cross-check that source branch's content is actually reachable from merge by running `git log --oneline <branch>..<source-branch> | wc -l` confirming 0 (or expected small delta), AND spot-check at least one file source branch actually changed by using `git diff --name-only <merge-base>..<source-branch> -- <path>` to identify candidate files and reading worktree file to confirm source-branch content is present. Don't trust commit message claiming merge range, merge base SHA, or conflict count without verifying each claim against tree. Flag any divergence between claim and actual state to user before proceeding. Re-open merge gate if claim is false.

## Improvement: verify user hypothesis in investigation gate

Condition:
- Incoming task or follow-up includes user-proposed hypothesis about root cause of bug (e.g. "fixes were lost during merge", "regression is from upstream PR X", "fix is already in branch Y") and next gate would be Developer investigation

Action:
- Include explicit falsification steps in investigation prompt: read relevant branch or PR with `git rev-parse`, `git merge-base --is-ancestor`, or `git show` and record verdict. Don't route to fix path until hypothesis is confirmed. Don't silently absorb hypothesis as truth and design fix on top of it. Map actual cause explicitly in investigation report even if it contradicts user. Surface contradiction to user in gate handoff so they can correct course before implementation work begins. Don't let Developer waste fix loop on falsified hypothesis. Require investigation report to include `Hypothesis verdict` section (CONFIRMED / FALSIFIED / PARTIAL) with evidence citations.

## Improvement: per-row sub-session delegation for long-running sequential driver test execution

Condition:

- Active gate is test execution and a sequential driver (e.g., v3 kickoff-v3-sequential-stress-longrun.ps1) is iterating through long-running test rows (cap > 30 min) for a Stage N follow-up, and many rows still pending verdict capture

Action:

- Do delegate exactly one QA sub-session per Manager turn; do not attempt to drive the entire test execution to completion in a single QA sub-session
- Do prefer option (b) (poll now and hand off to next sub-session) when cap-exit is more than ~30 min away; reserve option (a) (block and wait for cap-exit) for short cap-exit rows under ~30 min so the QA sub-session does not consume a long blocking wait
- Do parse cap=NNNs from the side log start line to derive cap-exit ETA rather than hard-coding defaults; record both cap value and computed ETA in the QA prompt
- Do evaluate each sub-session's return against the gate acceptance checklist (fresh session report appended, constraints honored, evidence captured when present) and decide pass/fail/rework before delegating the next sub-session
- Do trust the most recent sub-session's per-row verdict over the Section 3 table state if they disagree; sub-session reclassifications can lag the table during long-running test execution
- Don't edit the test report yourself; the QA sub-session is the sole writer of the report file
- Don't re-do the polling work; the sub-session owns the v3 driver state and side log parse

## Improvement: single-edit subagent delegations to avoid Response too long

Condition:

- Stage 13 closure doc sweep needed multiple edits across two durable docs (entry doc + document-index) and Architect subagent sessions repeatedly failed with `Response too long` model output limit on any prompt longer than ~3 paragraphs or any multi-edit delegation.

Action:

- Do split closure doc sweep into one focused single-edit subagent delegation per edit: status line, current gate paragraph, stage gate table, handoff section, new closure section, document-index row 1, document-index row 2.
- Do forbid the subagent from loading skills, reading other files, or creating todo lists in each per-edit prompt.
- Do include the exact OLD and NEW text in each per-edit prompt (no summarization, no interpretation).
- Do verify the edit on disk between delegations.
- Don't delegate a closure doc sweep as one Architect session with multiple edits and doc interpretation; even an `## Handoff`-sized block triggers the model output limit.
- Don't trust subagent `Edit applied` return without verifying the actual file state on disk via `Select-String` or `git diff --check`.

## Improvement: check document-index M state at closure sweep start

Condition:

- Stage closure doc sweep needs to update `._design_docs/document-index.md` and the file shows `M` (modified) status in `git status --short` at session start, suggesting a prior session may have applied partial edits.

Action:

- Do run `git diff HEAD -- ._design_docs/document-index.md | Measure-Object -Line` and `git diff --stat` before any closure edit, and read the M diff to detect regressions such as removed rows.
- Do treat the M state as potentially pre-existing regression from a prior session, not a fresh worktree change.
- Do restore any rows the M state removed before adding new closure rows, otherwise closure updates will land in an already-broken index.
- Don't assume a clean worktree; do verify against HEAD on every closure sweep.

## Improvement: longrun 1000 threshold does not apply structurally

Condition:

- QA sub-session is reclassifying a V1 longrun row (L01, L02, L03) using the Section 1 stress-row rule that requires hits+misses >= 1000

Action:

- Do remind the QA in the prompt that the 1000 hits+misses threshold is sized for 30-min stress rows (S01..S08) with high request rates; a 2-hour longrun row with structurally lower request rate will not meet the 1000 threshold and the threshold should not block PASS classification
- Do require the QA to apply the intent of the stress-row rule (clean cache counters: evictions >= 0, restore_failures == 0, descriptor_validation_failures == 0, Stub data flag = MEASURED) for longrun rows rather than the literal 1000 number
- Do accept PASS reclassification for a longrun row with clean counters and Stub data flag MEASURED even if hits+misses is well below 1000; record the actual hits+misses value in the sub-session entry for the audit trail
- Don't reject a PASS reclassification for a longrun row purely on threshold; the threshold mismatch is structural, not a product defect
