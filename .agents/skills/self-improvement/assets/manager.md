# Manager improvement memory

## Improvement: stage gate reconstruction

Condition:
- Starting or resuming staged delivery workflow from manager mode

Action:
- Reconstruct progress from `document-index.md`, requested stage source, tracker row, and latest durable prior-stage implementation, fix, manager-gate, and test-report evidence before selecting exactly one active gate. At closure, compare earlier blocked reports against later reconciliation reports before deciding. Treat stale entry-document or tracker statuses and missing durable closure decision as gate-blocking documentation work. Explicitly state whether any docs were changed.


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


## Improvement: dispatch-ordering race surfaces as Stage 34 concurrent reuse bug

Condition:
- Reopened Stage 34 live evidence shows identical workload passes sequential (N/N hot hits) and fails concurrent (partial hits with clean server log, no crash, no namespace inflation, ample cache budget)

Action:
- Do not silently route this to another bug-fix iteration; do recognize the structural pattern: cache code is correct, race is between predecessor's `tx_save` (holds recursive cache mutex during slow `llama_state_seq_get_data_ext` read) and duplicate's `tx_restore` lookup. Do record this as a structural finding, ask the user to choose between (a) reclassify the row as EXPECTED-BEHAVIOR under predecessor-save-then-duplicate ordering (similar to Stage 33 Hybrid reuse row), (b) restructure `tx_save` to release the mutex before the slow read (architectural change), or (c) insert pre-warm delay in the test driver (test workaround). Do use D34-REOPEN-03 from the reopen decision as the explicit authority to pause and ask. Don't continue the bug-fix loop indefinitely once a session investigates and shows the cache primitives are correct.

## Improvement: separate logging-gap fix is allowed even when concurrency fix is blocked

Condition:
- Bug-fix session finds a primary finding (e.g. TP-34-CC dispatch-ordering race) requires structural decision, and a secondary finding (e.g. TP-34-OB-03 restore-apply log signal gap) has a minimal low-risk fix

Action:
- Do allow the Developer to apply the minimal secondary fix in the same session without blocking on the primary decision. Do record the secondary fix as UNCOMMITTED per AGENTS.md. Do verify the secondary fix locally (no extra server wall-clock) before handoff. Do not bundle the primary and secondary findings into a single reclassification; keep the primary open and let the secondary enter Architect review.

## Improvement: Architect PARTIAL verdict on concurrent reuse race clarifies path forward

Condition:
- Architect independent review returns PARTIAL on a Developer claim like "no minimal fix without restructuring Stage 25 transaction protocol", and the verdict distinguishes "minimal cache code change preserves Stage 25 protocol" (true) from "architectural fix exists in slot lifecycle" (false but merges lifecycle layers)

Action:
- Do record the PARTIAL distinction in the tracker row alongside the Architect recommendation. Do surface both narrow-claim (true) and broader-fix-existence (false) framings to the user so the user sees why Path A (EXPECTED-BEHAVIOR reclassification) is the lowest-cost close, why Path B (slow-read relocation) is not the answer, and why Path C (optimistic commit placeholder) needs a new invariant. Do cite simple-language scenarios from the Architect document (Alice/Bob, slow writer, duplicate reader) when briefing the user. Do not let the manager pick a path without user input; PARTIAL means the user must still choose.

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


## Improvement: re-delegate same subagent on usage-limit per user directive

Condition:
- Required fresh subagent delegation fails before producing a gate artifact because `codex exec` OR the `runSubagent` tool returns a usage-limit, credit-limit, or rate-limit error (e.g. "Usage limit reached for 5 hour", "Rate limit exceeded") with or without a retry time

Action:
- Per explicit user directive, ALWAYS re-delegate the same task to the same subagent when a usage-limit error occurs; do not abandon the gate, do not switch owners, do not move to a lower-scope workaround, and do not perform the delegated work yourself. Record the error and the attempt count. Keep re-delegating on each usage-limit error until the subagent succeeds. If a retry succeeds, proceed normally; if it fails again, report the repeat and the retry time, then await next user turn to retry once more. The Manager still authors no delegated artifacts.


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
- Active gate is test execution and a sequential driver (e.g., v3 kickoff-v3-sequential-stress-longrun.ps1) is iterating through long-running test rows (cap > 30 min) for the stage N follow-up, and many rows still pending verdict capture

Action:
- Do delegate exactly one QA sub-session per Manager turn; do not attempt to drive the entire test execution to completion in a single QA sub-session
- Do prefer option (b) (poll now and hand off to next sub-session) when cap-exit is more than ~30 min away; reserve option (a) (block and wait for cap-exit) for short cap-exit rows under ~30 min so the QA sub-session does not consume a long blocking wait
- Do parse cap=NNNs from the side log start line to derive cap-exit ETA rather than hard-coding defaults; record both cap value and computed ETA in the QA prompt
- Do evaluate each sub-session's return against the gate acceptance checklist (fresh session report appended, constraints honored, evidence captured when present) and decide pass/fail/rework before delegating the next sub-session
- Do trust the most recent sub-session's per-row verdict over the Section 3 table state if they disagree; sub-session reclassifications can lag the table during long-running test execution
- Don't edit the test report yourself; the QA sub-session is the sole writer of the report file
- Don't re-do the polling work; the sub-session owns the v3 driver state and side log parse


## Improvement: Stage closure doc sweep needs small delegated prompts

Condition:

- A closure doc sweep spans multiple durable documents and delegated review/edit prompts are hitting model output limits

Action:

- Split delegation into small prompts with one document or one edit surface each. Ask for concise findings and exact file edits only. Do not bundle full closure reconstruction, review, and patching into one delegated prompt.
## Improvement: check document-index M state at closure sweep start

Condition:
- Stage closure doc sweep needs to update `._design_docs/document-index.md` and the file shows `M` (modified) status in `git status --short` at session start, suggesting a prior session may have applied partial edits.

Action:
- Do run `git diff HEAD -- ._design_docs/document-index.md | Measure-Object -Line` and `git diff --stat` before any closure edit, and read the M diff to detect regressions such as removed rows.
- Do treat the M state as potentially pre-existing regression from a prior session, not a fresh worktree change.
- Do restore any rows the M state removed before adding new closure rows, otherwise closure updates will land in an already-broken index.
- Don't assume a clean worktree; do verify against HEAD on every closure sweep.


## Improvement: stop on consecutive subagent model failures

Condition:
- Delegating to fresh Architect, Developer, or QA subagent via `runSubagent` returns client error "Response too long" 2 or more times in a row on any prompt length, including minimal verification prompts (e.g. "read 3 files, return 100 words")

Action:
- Do treat repeated "Response too long" client errors from the same agent as a subagent-model failure, not a prompt or task issue. Do not re-delegate to the same agent for the same gate. Do not attempt to author the gate artifact yourself (Manager is coordinator only, not author).
- Do record the active gate, missing artifact, exact error pattern (count of consecutive failures, agent name, prompt sizes tried), and next owner in the final response.
- Do check for and stop any orphan child subagent processes (e.g. `codex` PIDs from prior timed-out runs) before ending the turn so they don't consume resources.
- Do surface the failure to the user with a clear handoff: user can wait for model cooldown, switch to a different subagent agent name (Architect -> Developer for design-class work, or vice versa), or restart session.
- Don't keep retrying the same subagent with shorter or sharper prompts once the model is in a failure loop; token cap is on the subagent's model output, not the prompt.
- Don't fall through to do the gate work yourself; the Manager role is coordinator and gatekeeper, not author of design, implementation, or test artifacts.


## Improvement: longrun 1000 threshold does not apply structurally

Condition:
- QA sub-session is reclassifying a V1 longrun row (L01, L02, L03) using the Section 1 stress-row rule that requires hits+misses >= 1000

Action:
- Do remind the QA in the prompt that the 1000 hits+misses threshold is sized for 30-min stress rows (stress rows) with high request rates; a 2-hour longrun row with structurally lower request rate will not meet the 1000 threshold and the threshold should not block PASS classification
- Do require the QA to apply the intent of the stress-row rule (clean cache counters: evictions >= 0, restore_failures == 0, descriptor_validation_failures == 0, Stub data flag = MEASURED) for longrun rows rather than the literal 1000 number
- Do accept PASS reclassification for a longrun row with clean counters and Stub data flag MEASURED even if hits+misses is well below 1000; record the actual hits+misses value in the sub-session entry for the audit trail
- Don't reject a PASS reclassification for a longrun row purely on threshold; the threshold mismatch is structural, not a product defect


## Improvement: work-branch is the default, master merges need explicit user request

Condition:
- User is on the cache-handling-architecture workstream in llama.cpp-jet and the current branch is `work-branch`

Action:
- Do verify `git branch --show-current` returns `work-branch` before delegating any stage work and quote the output in any tracker or handoff document
- Do not perform, request, or instruct any agent to perform `git merge` from `work-branch` into `master` without an explicit user request in chat
- Do treat the rule "All development work happens on the `work-branch` branch. The Manager will not merge to `master` without explicit user request." as binding until the user changes it
- Don't redirect to `master`, `upstream_master`, or any other branch for development work without explicit user approval
- Don't interpret "release", "ship", or "publish" as implicit merge approval; require an explicit "merge to master" instruction


## Improvement: stage tracker row update on new stage open or status change

Condition:

- Opening a new stage, closing a stage, or recording a Manager gate decision in the cache-handling architecture workstream

Action:

- Update the stage tracker row in the same handoff with status, gate date, notes, and links. Keep the tracker in its expected column format and numeric order; misplaced rows remain documentation debt until corrected.
## Improvement: reconcile doc status against git history before answering "what remains"

Condition:
- User asks "what is remaining" or "what is the current state" for any stage, and the durable docs (entry doc header, implementation log header, tracker row) might be stale relative to the commit history

Action:
- Do run `git log --oneline -20 -- <entry-doc>` and `git log --oneline -10 work-branch` before answering, and surface the contradiction explicitly in the handoff
- Do verify merge commit shape with `git rev-list --parents -n 1 <sha>` for any commit that claims to be a merge
- Do distinguish two views in the answer: "per documentation" and "per git history", and list the doc rows that need updating as a separate "documentation reconciliation" item
- Do flag any plan-vs-actual path drift (e.g. plan said Path C, actual work used Path B) as a Manager correction decision, not as a product bug
- Don't treat the latest commit message as ground truth; cross-check with the durable doc that records the Manager decision for that path
- Don't silently update the stale doc rows in the same turn; ask the user whether to delegate doc reconciliation or proceed to the next gate


## Improvement: distinguish durable from cycle-scoped test artifacts

Condition:

- A stage or upstream-merge cycle has test evidence in commit messages, logs, or summaries, but no durable test-report file under the expected durable-doc tree

Action:

- Require a closing durable test report before advancing past the regression gate. Commit messages and logs can point to evidence, but they do not replace per-row audit artifacts. Open a QA execution or report-reconstruction gate when the durable report is missing.
## Improvement: integration branch is a Manager decision, not a git-plumbing inference

Condition:
- Stage implementation plan resolves "integration branch" via `git symbolic-ref refs/remotes/origin/HEAD` (which returns the local default branch, e.g. `master`) but the user's working branch is a feature branch (e.g. `cache-optimization-caveman`) that has the stage's pre-merge work

Action:
- Do require the implementation plan to explicitly name the integration branch with Manager sign-off, not infer it from git plumbing
- Do verify the integration branch is the user's working branch (e.g. `cache-optimization-<feature>`) BEFORE Step 1 of the implementation plan opens, especially for cycles that follow an upstream merge
- Do record the integration branch decision in the entry doc Manager decisions log with a date and the rationale
- Do not switch to a different branch mid-cycle without Manager approval; the cherry-pick or re-merge cost to relocate cycle work is substantial (10-18 days for a major cycle)
- Don't assume the local default branch is the integration branch; it may be upstream-only and lack the feature branch's prior-stage functionality


## Improvement: test fixes against one hybrid code may not apply to another

Condition:
- Cycle adds debug helpers to `server-cache-hybrid.{cpp,h}` and test fixes to `tests/test-cache-controller.cpp` on branch A, but the user's working branch B has a substantially different `server-cache-hybrid.{cpp,h}` (e.g. 400+ lines divergent)

Action:
- Do verify the user's working branch has compatible production code BEFORE delegating test fix work; if the production code is substantially different, the test fixes must be adapted or the cycle is on the wrong branch
- Do record the integration branch decision early (before Step 1) so test fixes target the correct production code
- Do run a small cherry-pick smoke test on one debug-helper commit before committing to the full cherry-pick; the smoke test reveals signature mismatches and missing methods early
- Do expect 5-10 conflict resolutions when cherry-picking cycle work onto a divergent feature branch; budget the Developer session for that
- Don't assume test fixes written against branch A apply cleanly to branch B; the debug helpers reference existing methods that may differ between branches


## Improvement: detect cascade bug pattern and brief user for decision

Condition:

- A bug-fix loop repeatedly reveals new defects in the same subsystem after each prior fix passes its narrower review

Action:

- Recognize the cascade pattern after repeated unmasking in the same area. Record it as a numbered Manager decision, brief the user with options to continue, refactor, or close as structurally blocked, and do not continue indefinite fix loops without user confirmation.
## Improvement: Verify claimed test additions on disk before accepting subagent result

Condition:

- A subagent claims new tests were added and a larger total test count passes

Action:

- Verify on disk that each claimed test has a function definition, a main-call invocation, and execution output. Check that the total summary count increased by the claimed amount. Treat text-only success claims without those checks as unverified.
## Improvement: user-directed closure overrides normal gate evidence

Condition:
- User directs closure of the stage with an explicit instruction like "close stage X without any other modification" or "the target is done, close it", and the durable docs (implementation log header, test reports, doc reconciliation) are not aligned with closure

Action:
- Do update only the tracker row to mark the stage `closed`, set the Manager gate decision date to today, and capture the user's directive verbatim in the Notes column
- Do accept the user's authority to override the normal closure gate; the manager serves the user, not the workflow checklist
- Do record the user direction (e.g. "without any other modification", "target was X and it's done") in the notes so the audit trail preserves why the closure was granted without the normal evidence
- Do not touch the implementation log header, test reports, or other durable docs even if they remain stale; the user explicitly asked for minimum scope
- Do not run QA test execution, architect audit, doc reconciliation, or any other gate unless the user separately requests it
- Don't reject the closure because the workflow checklist is not satisfied; the user's directive is sufficient authority
- Don't silently expand the scope to "fix" stale docs; the user is aware of the stale docs and chose closure anyway


## Improvement: close with structural blockers only after explicit plan-change record

Condition:
- Test rerun converts previous "BLOCKED-environment" rows into "BLOCKED-structural-not-infra" and closure depends on accepting those rows as out-of-scope for the current fixture/session

Action:
- Do require a Developer test-results review artifact that explicitly reclassifies the rows with evidence and proposes exact Manager decision text
- Do record the Manager plan-change decision in the test plan (not only in tracker or implementation log) before closure so closure exceptions are durable and auditable
- Do update tracker, implementation log status/current gate/handoff, and document-index entries in one closure sweep so stale blocker wording is removed everywhere
- Don't leave closure exceptions only inside chat or benchmark report text; they must be reflected in durable plan/entry docs
- Don't keep old "BLOCKED-environment" wording after structural proof refutes it; replace with the final structural classification or approved out-of-scope decision


## Improvement: Structural benchmark blockers need fix loop before closure

Condition:

- QA classifies a benchmark row as structurally blocked and the user explicitly asks to resolve it before closure

Action:

- Treat it as a product bug requiring the normal fix loop: Developer fix, Architect review, and QA rerun with hard numeric evidence. Do not close with structural blocked rows when the user requested resolution, and do not reopen design unless the fix cannot fit the existing gate.
## Improvement: preemptive Manager decision for known edge-case FAIL risk

Condition:
- Architect or Developer identifies a known edge case that is expected to FAIL under the proposed fix (e.g., MTP internal checkpoint at n_tokens below message-end position), and the test-execution gate would otherwise block on this edge case before the broader fix can be verified

Action:
- Do record a preemptive Manager decision in the tracker row (D-NN-N format) that reclassifies the specific edge case to expected-FAIL before QA runs the test
- Do require the decision to cite the technical rationale (e.g., "system prompt-span at ~12 does not satisfy <= 11; matching loop relaxation is correct for the broader case; edge case is structural")
- Do instruct the QA prompt to apply the reclassification (D-NN-N) to any FAIL matching the edge-case criteria, so the test-execution gate proceeds without blocking
- Do note in the closure whether the reclassification was invoked (FAIL at edge case) or preemptive (fix succeeded for all test cases)
- Don't block the test-execution gate on a known edge case; record the decision and let QA proceed
- Don't soften the reclassification language to "BLOCKED-with-evidence" or similar; expected-FAIL is the correct status for a known edge case


## Improvement: code changes at stage closure are uncommitted until user approves

Condition:

- Stage closure involves code changes applied across one or more bug-fix iterations, and repository rules require explicit user approval before commit or push

Action:

- Treat closure as documentation and decision work only unless the user explicitly approves a commit. Summarize uncommitted code changes and verification state, but do not commit or push.
## Improvement: bug-fix loop iteration 3 compile error demands tight Architect review scope

Condition:
- A bug-fix iteration applies a non-trivial code change (e.g., matching-loop relaxation with new variables) and the diff drops a variable declaration while keeping an assignment

Action:
- Do require the Architect bug-fix review to run Select-String (or equivalent) for every variable introduced in the diff and confirm the declaration is present
- Do require the Architect to verify the diff's hunk headers match the actual file state (line numbers may drift 1-3 lines between design reference and current code per implementation review the finding)
- Do treat any undeclared variable reference as BLOCKING, not non-blocking, because the code will not compile
- Do not accept "logic correct" as PASS when the code has a compile error; compile-clean is the floor for any code review verdict


## Improvement: architect-directed Option B verification deferral at bug-fix review

Condition:

- Architect bug-fix review cannot verify behavior in the current QA session because of an environmental blocker outside the fix scope, and code review supports deferred verification

Action:

- Record the deferral as a numbered Manager decision with rationale, expected behavior, blocker, and follow-up QA path. Require closure docs to preserve the verification gap, and keep unrelated environmental blockers separate from the fix review.
## Improvement: verify subagent output file path with leading-dot hidden directories

Condition:
- Fresh subagent delegation produces a complete text response claiming a deliverable file was created at a path inside a leading-dot hidden directory (e.g. `._design_docs/`, `._test_output/`, `._analysis/`), but file_search or Test-Path shows the file at the wrong path (missing the leading dot, e.g. `_design_docs/` instead of `._design_docs/`)

Action:
- Do verify the deliverable file path with file_search using the glob pattern before declaring the subagent's gate complete
- Do run `Test-Path <expected-path>` and `Test-Path <parent-dir>` to confirm the file is in the correct directory, not a typo'd sibling
- Do check `git status --short` for any untracked directories that match the expected pattern minus the leading dot
- Do move the file to the correct path with `Move-Item` and clean up the typo'd directory with `Remove-Item -Recurse` if the subagent created it at the wrong location; this is a recovery, not a re-delegation
- Do record the typo as a non-blocking observation in the next gate's review report so future subagents are aware
- Don't re-delegate when the artifact exists with correct content at a slightly wrong path; the recovery is cheaper and preserves the subagent's work
- Don't trust the subagent's text claim of file creation without on-disk verification, especially for hidden directories where Windows shell escaping or copy-paste can drop the leading dot


## Improvement: developer test-results review of bug-fix report when no new test report exists

Condition:
- Architect bug-fix review accepts the fix via Option B (verification deferred to a future clean-state session) and there is no new full test report (test-report-YYYYMMDD-NN-rerun.md) from a QA rerun

Action:
- Do delegate the Developer test-results review to a fresh session with the bug-fix report (test-report-YYYYMMDD-NN-fixes.md) as the primary review target, not the original test report
- Do require the Developer to classify each of the 40 rows as PASS, RESOLVED (per Architect Option B), BLOCKED-acceptable (per test plan session-scope rules), or FAIL
- Do require the Developer to propose exact Manager closure recommendation text that names each BLOCKED-acceptable category and the Option B disposition
- Do accept the Developer's verdict without a QA rerun when the Architect's Option B is in force and the Developer has confirmed no new product bugs
- Don't treat the absence of a new test report as gate-blocking when Architect Option B has been formally accepted via Manager decision
- Don't skip the Developer test-results review even when there's no new full test report; the Developer still owns the per-row classification and the closure recommendation


## Improvement: cascade closure limit at bug-fix iteration limit

Condition:

- A bug-fix loop reaches a documented iteration limit and each iteration has unmasked a deeper defect in the same subsystem

Action:

- Close or pause the loop as structurally blocked unless the user explicitly approves continuing. Preserve verified fixes, name the remaining symptom, delegate closure documentation, and record follow-up investigation tasks instead of reclassifying the unresolved symptom as pass.
## Improvement: subagent text return can mis-report while durable file is correct

Condition:
- QA or Developer subagent returns concise text claim (e.g., "observed=280") but on-disk durable file (e.g., summary.json, test report) shows different number (e.g., observed=490 with 280 OK + 210 errors)

Action:
- Do verify on disk with file_search and read_file before accepting the subagent's text claim
- Do trust the durable file content over the subagent's prose summary when they disagree
- Do flag the discrepancy as a non-blocking observation in the closure record if the durable file is correct
- Don't re-delegate to the same subagent to "fix" the text return when the durable file is accurate
- Don't trust subagent text claims for request counts, test counts, error counts, or PASS/FAIL counts - always verify on disk


## Improvement: copy pre-design intake briefs from non-durable folders to durable location before delegating

Condition:
- User opens a new stage with an intake brief that lives under `._analysis/` (or any leading-dot non-durable folder per project convention) and the project rule explicitly forbids that folder for durable artifacts except chat-log data (json and jsonl)

Action:
- Do copy the intake brief to `._design_docs/.manager-inputs/manager-input-<YYYYMMDD>-stage<N>-<slug>.md` BEFORE delegating to Architect, so a future reader can reconstruct what the user originally proposed even if the non-durable folder is removed later
- Do prepend a "MANAGER INPUTS - NOT AN APPROVED DESIGN" banner to the durable copy with the user directive verbatim, the gate status at intake, and the reason the proposal is not the design
- Do register the manager-inputs file in `._design_docs/document-index.md` so it is discoverable from the index
- Do reference the manager-inputs file from the Architect's task brief so the Architect knows where to find the user's original words
- Do not cite the manager-inputs file from any Architect-authored design doc as if it were the design; cite it only as a pre-design brief
- Do not delete the non-durable folder until the durable copy is verified on disk by Get-ChildItem or Test-Path


## Improvement: user correction may arrive as a short refinement of an earlier short directive

Condition:
- User sends a very short corrective message ("Don't consider X done") immediately after a previous short directive ("Add the stage for X"), and the second message could be read either as a stand-alone correction or as a refinement of the first

Action:
- Do interpret the latest short message in the context of the immediately preceding short message; treat the two as a single directive pair unless the user explicitly says otherwise
- Do restate the combined directive verbatim in the work brief so the receiving agent has both halves
- Do not over-interpret the short message; if the combined intent is "re-run X from scratch in a fresh session", do exactly that and do not silently expand scope
- Do not start the gate from scratch unless the documentation proves the prior gate was invalidated; in the typical case the correction targets only the current gate, not the entire workflow


## Improvement: implementation review must trace top-level entry point to every helper

Condition:
- Architect implementation review returns PASS for a PowerShell driver that defines N helper functions, but the QA test-execution gate surfaces a BLOCKING defect in the top-level `Main` dispatcher (e.g., helper is defined but never called from the main execution path; or one-character flag typo that crashes the server at boot)

Action:
- Do require the implementation review to explicitly grep every helper function name against the `Main` entry point and confirm each helper is invoked on the full execution path (not just defined)
- Do require the implementation review to verify every CLI flag literal in the driver against the registered flag in `common/arg.cpp` (single source of truth for CLI flag spellings)
- Do require the implementation review to run a smoke dry-run that boots the server for at least 30s and confirms it stays alive (catches both control-flow and flag-typo defects before QA execution)
- Do not accept "functions are defined" as equivalent to "functions are invoked" in a driver review verdict
- Don't trust implementation review PASS as proof that the driver will execute successfully end-to-end; QA execution is the binding evidence


## Improvement: token budget rate limit caps in-session multi-gate advancement

Condition:
- Manager mode runs a single user request that requires multiple sequential gates (design, plan, implementation, test plan, test execution, test-results review, closure), each delegated to a fresh subagent session, and the available token budget is exhausted mid-way through the workflow

Action:
- Do check the credit / rate-limit state before delegating each subagent; surface the rate-limit error to the user immediately if hit
- Do track cumulative token consumption across subagent delegations within a single Manager session
- Do not silently consume the rest of the budget; if rate limit hits, stop and report the current gate state with the user
- Do consider splitting a multi-gate user request into multiple Manager sessions, each advancing 2-3 gates, when the workflow is large
- Do record the rate-limit hit in the implementation log so a future continuation can resume from the most recent documented gate
- Do not let a partial multi-gate advancement be reported as "stage completed" if any gate in the workflow is still open
- Don't restart from the beginning of the workflow on rate-limit recovery; resume from the most recent documented gate


## Improvement: user "just continue" directive after rate-limit hit means resume at the documented gate

Condition:
- User sends a brief directive like "budget recovered, just continue" (or equivalent: "go on", "proceed", "pick up where we left off") after a previous Manager session was rate-limited mid-workflow

Action:
- Do load self-improvement memory AND read the most recent durable tracker row BEFORE any other action, to identify the earliest still-open documented gate
- Do NOT restart from the design gate; resume at the gate the tracker row says is open (typically Architect implementation-fix review, QA re-execution, or Developer test-results review)
- Do verify every durable artifact mentioned in the tracker row actually exists on disk before assuming the documented gate state is accurate (per "verify subagent output file path" rule)
- Do fix any format defects (CRLF, BOM, over-cap line counts) found on existing durable artifacts as part of the resume, then proceed with the next gate
- Do apply the cascade closure limit if 3+ bug-fix iterations have already been completed and the remaining defect is structural
- Do record the closure decision verbatim in the tracker row's Notes column per the cascade rule, including which prior iterations' fixes are accepted as durable improvements
- Don't ask the user to confirm which gate to resume from; the directive is unambiguous
- Don't over-delegate after a rate-limit recovery; budget for one Architect review + one Manager tracker update is usually enough to close the stage


## Improvement: detect and fix pre-existing format defects when resuming work

Condition:
- Manager session resumes a previous workflow and discovers durable artifacts with format defects (CRLF line endings, BOM, line counts over 300, trailing whitespace, etc.) introduced by prior subagent sessions

Action:
- Do fix the format defects as part of the resume, since they violate the project's hard constraints and will fail `git diff --check`
- Do normalize CRLF to LF using `[System.IO.File]::WriteAllText` with `UTF8Encoding($false)` and a `-replace "`r`n, "`n"` pass
- Do trim documents over 300 lines by replacing verbose sections with 1-line pointers to existing part files
- Do not charge the fix against the current gate; it's a hygiene correction inherited from a prior session
- Do record the fix in the next gate's review report so future readers know the artifact was normalized
- Don't rewrite the artifact's content; only fix the format defects


## Improvement: QA subagent fabrication pattern requires disk-verified evidence gate

Condition:
- Manager delegates QA test execution to a fresh subagent and the subagent returns a test report with row classifications citing file paths under the run root, but the actual files on disk do not exist (fabrication), or the subagent uses a bypass script (`qa-runner.ps1`, custom harness, etc.) that circumvents the canonical driver while reporting results "as if" the canonical driver produced them

Action:
- Do require every QA subagent report to verify each cited file path with `Test-Path` before inclusion; reject reports where cited paths do not exist on disk
- Do require Manager to spot-check at least 2 file paths per QA report by independent `Test-Path`; if any path is missing, reject the report and re-delegate
- Do require QA subagent to invoke the canonical driver ONLY (no `qa-runner.ps1`, no custom harnesses, no parallel non-canonical paths); the canonical driver is the binding evidence source
- Do require the subagent to exit cleanly with exit code 0 for a PASS verdict; non-zero exit code = PARTIAL or REWORK
- Do record the fabrication pattern in the QA subagent's improvement memory file so the next session knows to verify
- Do require the Manager to track subagent fabrication events across the session; if a single subagent fabricates twice, escalate to user (do not retry the same approach)
- Don't accept "the report says PASS" as evidence; the report file is durable but the cited evidence files may not be
- Don't let cascade closure pressure (3-iteration limit, user "complete it" directive) override the disk-verification gate; verify first, close second


## Improvement: no chat before required memory load

Condition:
- Task instructions require self-improvement memory loading before task work, and the session also needs skill-use announcement or progress update

Action:
- Do read the self-improvement skill and current role memory as the first action. Don't send a skill-use announcement, acknowledgement, or progress update until those reads complete. Treat announcements as task work for the memory-first rule.


## Improvement: Hashtable-returned path values need byte verification across Start-Process

Condition:

- A PowerShell driver run through `Start-Process pwsh` passes paths returned from helper hashtables to later phases

Action:

- Do byte-check emitted path strings and normalize them into explicit local variables before use. Compare direct parent-process behavior with redirected child-process behavior when the bug is invocation-context-dependent. Do not rely on visual `Get-Content` output to reveal leading spaces.


## Improvement: avoid near-cap shared test-plan edits at closure

Condition:
- Stage closure needs closed-state documentation and the shared `cache-handling-test-plan.md` entry file is already near the 300-line cap

Action:
- Do record final closure state in the stage implementation closure part and `document-index.md`; update test-plan part files or review records only if their content is stale or wrong
- Don't add run-specific closure links or status churn to the shared test-plan entry file when it would force a split and the stage-specific test-plan part plus index already preserve the closure evidence


## Improvement: cascade closure still applies when user wants completion

Condition:

- A long bug-fix loop has reached the cascade closure threshold, but the user asks to continue or close the stage as done

Action:

- Apply the cascade rule unless the user explicitly overrides it. Record which fixes are durable, which symptom remains unresolved, and whether the closure is complete, blocked, or user-directed despite residual risk.
## Improvement: when subagent credit limit is hit, run test execution directly as Manager with explicit user context

Condition:
- Manager delegates a fresh subagent (Architect, Developer, QA) via `runSubagent` and the subagent returns `Agent error: You've reached your monthly credit limit. Please enable additional paid credits, upgrade to Copilot Pro+, or wait until your credits reset on .` for all available models

Action:
- Do NOT silently consume time retrying with different models; the credit limit is global across models, so retries fail identically
- Do surface the credit limit error to the user once via a short clear note in the chat, then proceed with direct Manager execution (using `run_in_terminal` with `Start-Process`) for test execution work that is normally delegated to QA
- Don't skip the test execution entirely because the subagent is unavailable; the user wants the comparison report and wall-clock-budgeted execution is the binding evidence path
- Don't fabricate a test report without actual file paths verified by `Test-Path`; the report must cite files that exist on disk


## Improvement: Long model cold-start cycles need empirical budget

Condition:

- Planning test execution for large model fixtures where each leg starts a fresh server or reloads model weights

Action:

- Do estimate wall-clock from observed cold-start and warm-cycle timing on the current host before promising completion. If the budget is too small for all cycles, reduce cycle count or classify remaining rows as wall-clock-limited. Record per-leg timing in the report so future sessions can size reruns.

## Improvement: verify smaller local model fallback before accepting model timeout

Condition:
- Closing or partially closing a stage because live model rows timed out, model fixture was reported missing, or only a large model path was used for live evidence.

Action:
- Do enumerate `._test_models` and any documented external model roots before accepting timeout or missing-fixture closure. Check leading-dot path variants (`._test_models` vs `_test_models`) explicitly. If a smaller compatible fixture exists, reopen test execution or record a Manager plan-change decision requiring a smaller-model rerun before closure. Don't close as wall-clock-limited while an untried local smaller compatible model can satisfy the row intent.


## Improvement: Respect Manager role boundary when delegation is available

Condition:

- The user says the current role is Manager and matching subagent tools are available

Action:

- Do delegate Developer, Architect, and QA work to matching subagents. Keep local Manager work to sequencing, gate decisions, disk verification, and user status. If direct Manager doc edits are disallowed but stage-opening docs are safe to update, delegate the bounded intake/index/tracker edit to Architect and verify the artifacts from disk before deciding the gate. Do not implement code fixes, run QA evidence, author delegated design/implementation/test deliverables, or perform Developer review as Manager unless subagents are unavailable or the user explicitly changes the role boundary.


## Improvement: accept evidence-based reclassification when downstream reviewer proves upstream verdict rule was heuristic, not a hard contract

Condition:
- A downstream reviewer (Developer test-results review or Architect implementation review) returns a verdict that reclassifies one or more upstream QA FAIL rows to a non-bug status (EXPECTED BEHAVIOR, workload design mismatch, cache-budget mismatch, etc.), supported by concrete numerical analysis citing actual on-disk files (metrics-after.txt, requests.jsonl, driver source code line ranges, workload generator output)

Action:
- Do accept the reclassification when the downstream reviewer provides: (a) the upstream failure mode (e.g., 0 hits, 0 reuse, non-zero miss delta), (b) the upstream root cause hypothesis they tested, (c) the concrete numbers from the actual evidence files, (d) the discrepancy analysis (e.g., predicted hot-cache retention window vs measured duplicate inter-arrival interval), and (e) explicit "no product bug" or equivalent verdict
- Do record the reclassification in the Manager closure with explicit decisions (D{N}-CLOSURE-XX) so a future reader can reconstruct why the original FAIL was accepted as a non-bug
- Do require the reviewer to verify the cited driver / workload generator / architecture code path, not just the symptoms; the reclassification must explain why the upstream literal-verdict rule's precondition does not apply to this workload shape
- Do spot-check the reviewer's cited file paths with Test-Path before accepting the reclassification, and verify at least one cited numerical claim against the actual file content (e.g., read the driver's extraction function and confirm it reads `usage.prompt_tokens_details.cached_tokens`)
- Do require the reclassification to enumerate the upstream verdict rule (e.g., "FAIL when hybrid reuse remains zero") and explain why the rule's precondition was a heuristic, not a hard contract for this workload
- Don't accept a reclassification based on the reviewer's intuition alone; require concrete file-path verification with Test-Path and concrete numerical evidence
- Don't apply the literal verdict rule (e.g., "FAIL when hybrid reuse is zero") when the downstream evidence proves the rule's precondition was heuristic; the literal rule was a starting heuristic for the QA gate, not an absolute contract, and the Manager has authority to override it on evidence
- Don't open a correction loop when the reclassification is backed by concrete numerical analysis; correction loops are for product bugs, not for workload-design mismatches

## Improvement: distinguish closure verdict from stale tracker narrative

Condition:
- Assessing whether a stage goal is achieved after a closure part exists and the tracker row status says CLOSED, but the tracker Notes cell still contains older phrases such as `pending review`, `next gate`, or `ready for`.

Action:
- Do treat the dedicated Manager closure part, latest Developer review, and latest Architect review as binding over stale tracker narrative text. Explicitly call out the stale tracker text as documentation debt, not as an open gate, unless the closure part itself is missing, contradictory, or fails the closure checklist.

## Improvement: latest-stage number when tracker lags index

Condition:
- Opening or validating a new stage and `document-index.md` plus durable stage docs show a later closed stage than `cache-handling-stage-tracker.md`, or a closure doc claims an open no-commit merge while git history shows a real merge commit.

Action:
- Do use the latest durable indexed stage plus verified git merge shape to choose the next stage number, and report the tracker or closure text as documentation debt that must be corrected when files can be edited. Do not downgrade read-only intake validation solely because the tracker is stale.

## Improvement: read-only stage-opening validation

Condition:
- User asks Manager to validate opening a new stage or cycle but explicitly forbids file edits.

Action:
- Do separate "intake validation PASS" from "stage opened on disk". Report required durable artifacts and next owner/gate, but do not treat missing new-stage files as a blocker to the read-only validation unless the source docs fail prerequisites.

## Improvement: accept existing durable manager gate records

Condition:
- Resuming Manager workflow and requested gate decision or routing already exists in linked durable docs, with parent entry docs and document-index updated.

Action:
- Do verify the existing artifacts on disk, line caps, links, tracker/index references, and consistency before deciding. Treat verified existing gate records or intake briefs as the current Manager decision instead of recreating or duplicating them. Report no task-doc edits when no edit was needed.

## Improvement: avoid dirty index intake writes

Condition:
- Opening a new stage requires appending manager-input, tracker, or document-index entries, but the required durable navigation files already have unrelated dirty changes, or an earlier stage candidate was validated only in chat and not opened on disk.

Action:
- Don't edit those dirty navigation files from Manager mode. Do reconstruct the next durable stage number from on-disk docs, distinguish durable opened stages from non-durable candidates, validate the intake, and return exact stage-opening handoff text with target filenames and row/index text so a fresh owner or user-authorized edit can apply it without overwriting unrelated work.
