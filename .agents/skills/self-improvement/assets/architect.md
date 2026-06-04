# Architect improvement memory

## Improvement: Coverage denominator rate vs XML root rate

Condition:
- When reviewing a T114 (or similar coverage-threshold) verdict where the QA report cites a Cobertura XML root `line-rate` attribute as the combined rate for a filtered denominator

Action:
- Do verify that the cited rate is from the script's filtered-denominator output (e.g., the `coverage-report.md` combined result row), not the XML root attributes; the XML root rate covers all files the tool tracked and is almost always lower than the filtered-denominator rate; estimate the true denominator rate from the per-file table before deciding whether a bug-fix loop is warranted; don't open or validate a bug-fix loop based solely on a rate computed with the wrong denominator

## Improvement: Test-plan review evidence-source consistency

Condition:
- When reviewing a test plan that references both public HTTP observability and internal controller stats or focused C++ tests, and some scenario rows reference metrics that may not be exposed in the public Prometheus endpoint

Action:
- Do check each metric reference against the design observability section and the implementation review to confirm whether the metric is a Prometheus metric or an internal controller stat; flag any row that references an internal stat as requiring a stats-capable harness or focused C++ test in the evidence requirements section; don't assume all metric names in scenario rows are publicly observable

## Improvement: Memory load before acknowledgement

Condition:
- When task instructions require reading self-improvement memory before any other task action, including tasks that start with AGENTS.md content, repository instructions, a long delegated-agent brief, or multiple required skills

Action:
- Do make the first assistant action and first tool call a single-purpose memory read that reads only the self-improvement skill instructions and Architect memory before any acknowledgement, commentary update, one-line skill-use announcement, plan, analysis, other skill reads, or non-memory tool use; if a skill-use announcement is required, send it only after the memory read completes and the result is available; don't use `multi_tool_use.parallel` or any batched shell call to include architect, humanizer, repository docs, status checks, or other task reads in that first call, don't send a user-facing update first, and don't let AGENTS.md, environment context, a long user brief, efficiency concerns, a required skill list, or an urge to be efficient tempt you into batching memory reads with task reads.

## Improvement: Gate wording with open findings

Condition:
- When an architecture, design, implementation-plan, implementation evidence, or re-review deliverable changes a gate state or closes an earlier finding, or when current entry docs still carry stale limitation, owner, or handoff wording

Action:
- Do check the live entry documents, active fix reports, correction-evidence status lines, `document-index.md` summaries, top-level Status lines, current-status sections, handoff text, and linked gate-status part files before and after patching, distinguish historical quoted findings from current contradictions, then keep durable gate-status locations in the same state, such as reviewable, rework-required, manager-gate-ready, planning-open, approval-pending, approved, ready-for-QA, bug-fix-review-pass, implementation-re-review-pass, or blocked; don't leave stale limitation, review-pending, awaiting-review, re-review-ready, handoff-closed, ready-for-review, ready-for-implementation, ready-for-re-review, or not-started wording after a gate has advanced or while an open finding remains

## Improvement: Misconfigured-probe diagnosis vs product bug

Condition:
- When writing architectural fix instructions for a BLOCKED fixture-dependent row (e.g., public /metrics row that showed zero) where the fixture is capable but the probe was misconfigured

Action:
- Do trace the probe start command against the design-required flags (cache-mode, spec-type, cache-ram, etc.) and the server stdout/stderr to confirm whether the failure is a misconfiguration or a product bug; specify the corrected start command with exact flag names from the parser source (e.g., common_speculative_type_to_str values); include a focused-substitute evidence path with the specific test function names and assertion points that cover the public-row check via get_stats() or focused exporter tests, so the Developer can either fix the probe or fall back to substitute evidence; don't leave the row in a generic BLOCKED state without the corrected start command or the substitute evidence citation

## Improvement: Changed paths for untracked review docs

Condition:
- When adding or updating review part files in a document tree that is untracked or only partly tracked by git

Action:
- Do track the paths edited during the task, patch new review files, entry docs, and index rows as separate steps when the tree is dirty or untracked, verify their contents directly, separate task-local edits from pre-existing dirty paths, and report that task-local path list; don't rely on `git diff` or `git status` alone to prove what changed; in particular, before declaring that a referenced doc was "not edited" or "not touched", run `git status -- <path>` and read the file's current contents to confirm whether any pre-existing uncommitted changes are in the tree, and report them as pre-existing rather than as own work

## Improvement: Code-review findings tied to approved docs

Condition:
- When performing an implementation review against an approved staged design or implementation plan

Action:
- Do tie each blocking finding to both an exact code location and the specific approved design or plan requirement it violates; don't block sign-off on style or pre-existing behavior unless it affects the current stage gate

## Improvement: Debug-hook evidence is not production integration

Condition:
- When implementation evidence claims a runtime contract is covered by tests or diagnostics, but the code under review exposes the behavior through debug hooks, standalone helpers, or unit-only APIs

Action:
- Do verify that the production save, restore, eviction, metrics, or lifecycle path actually invokes the behavior; flag a blocker when tests only exercise debug hooks or standalone APIs for a contract that the approved design assigns to production flow

## Improvement: Skill path fallback

Condition:
- When a required repository skill is listed in the session but the first documented skill path cannot be read

Action:
- Do check the repository-local `.agents/skills/<skill>/SKILL.md` path before falling back to ad hoc behavior, and record the path issue only briefly

## Improvement: Scoped traceability for deferred requirements

Condition:
- When authoring a stage design for a subset of architecture requirements and the intake lists broad requirement ranges with later-stage subrequirements

Action:
- Do expand each named contiguous requirement range into an explicit checklist before finishing, then trace every relevant requirement or subrange as covered, constrained, or explicitly deferred in the persistent design; don't skip standalone requirements inside a range or leave deferred subrequirements implied only by the scope section

## Improvement: Atomic-operation design reviews

Condition:
- When reviewing or correcting a design or implementation that claims an operation is atomic but the described steps mutate live state in sequence, or when implementation evidence documents a limitation against an approved atomicity contract

Action:
- Do require an explicit pre-apply validation, scratch-apply or exact rollback contract, fallback live-state outcome, diagnostics or metrics, and failure-injection tests before marking the design or implementation ready; don't accept goal-level wording such as "leave state valid" or a documented production limitation unless the durable design has an approved exception

## Improvement: Handoff prerequisites in plan reviews

Condition:
- When reviewing an implementation plan whose approved design or prior gate says planning or code work must wait for a manager handoff, gate approval, or other prerequisite decision

Action:
- Do verify that the prerequisite decision is recorded or linked in durable docs before returning PASS; don't treat a technically sound plan as approved when the document set still says the handoff is closed

## Improvement: Cross-part protocol consistency in multi-part design reviews

Condition:

- When a multi-part design specifies a step-by-step protocol in one part and failure-mode handling for those same steps in a separate part, and the two parts can produce conflicting state outcomes (for example, a transient state set before an enqueue attempt but the failure table implies the prior state must be preserved on queue-full)

Action:

- Do read both the protocol steps and the failure-handling table together, identify any case where the protocol mutates state before a fallible step and the failure table implies that mutation must be reverted, and record that as a non-blocking observation with a concrete implementation contract requirement; don't flag it as a blocking finding if the correct outcome is unambiguous across both parts

## Improvement: Dependency graph completeness in implementation plan reviews

Condition:

- When reviewing an implementation plan where later steps add member variables to a class and earlier-numbered steps add methods that use those same variables, but the dependency list on those method-adding steps does not reference the member-adding step

Action:

- Do trace each step's code changes to check that every member variable, function, or type referenced in the step's changes exists at the point that step's dependencies are satisfied; flag any case where a referenced symbol is only introduced in a later step as a blocking missing-dependency finding; don't assume numerical step order implies the correct dependency graph

## Improvement: Coverage-method decisions in plan reviews

Condition:
- When reviewing an implementation plan whose approved design requires the coverage tool, metric type, command family, denominator, or exclusions to be defined before code work starts

Action:
- Do verify that the plan names the coverage tool and whether it provides branch or line coverage on the intended platform, not only the denominator or a later "select before implementation" placeholder; flag missing coverage-method selection as a blocking plan gap when the design made it a pre-code decision

## Improvement: Verify current state before applying review fixes

Condition:
- When fixing findings from a design review where the review report describes an older version of the design

Action:
- Do read the current file state first, compare against the review report's description of the problem, and only apply fixes for issues that still exist in the current files; don't blindly apply all review recommendations without verifying current state

## Improvement: Re-review corrected designs for new scope drift

Condition:
- When re-reviewing a design that was edited to close earlier architecture blockers

Action:
- Do verify that each correction is implementable from the documented data model and does not pull deferred-stage behavior into the current stage without its required safety contract; don't limit the re-review to confirming that the old finding text disappeared

## Improvement: Narrow re-reviews still update navigation state

Condition:
- When a task asks for a focused re-review of one prior finding and also says to update `document-index.md` only if materially needed

Action:
- Do keep the review finding scope narrow, but still update entry-doc contents, current gate text, stage-gate text, and any index row that would otherwise describe the old review state; don't leave stale REWORK, awaiting-review, or correction-drafted wording in durable navigation docs after a PASS re-review

## Improvement: One-gate stage design authoring

Condition:
- When a task asks to advance exactly one architecture gate by creating a new stage design deliverable

Action:
- Do mark the authored design as ready for independent review while leaving design review, manager gate, implementation planning, implementation, and QA gates unstarted; don't use the new design document to approve later gates or imply implementation authorization

## Improvement: Multi-payload implementation reviews

Condition:
- When reviewing an implementation that adds a second payload kind, descriptor reference, or residency path to an existing cache entry or branch node

Action:
- Do trace admission, restore selection, pre-restore residency filtering, byte accounting, eviction, demotion, promotion, cleanup, metrics, and tests for each payload kind separately and together; verify cold or transient descriptors can still reach the intended promotion, fallback, or rejection path instead of being filtered out as absent; don't accept aggregate entry-level accounting or debug-only coverage as proof that all payload kinds participate in the production lifecycle

## Improvement: PASS with residual evidence limits

Condition:
- When an implementation re-review has focused substitute evidence for a design requirement but still lacks model-backed, public HTTP, or live Prometheus evidence requested for later QA closure

Action:
- Do decide the implementation gate from the approved code contract and available substitute evidence, then carry missing runtime evidence as an explicit QA risk or next-owner item when it is not required to prove code correctness; don't keep a REWORK verdict solely because QA still needs fixture-backed confirmation

## Improvement: Public exporter shape in observability reviews

Condition:
- When reviewing implementation evidence that claims metrics are complete through direct stats, JSON `get_stats()` rows, or focused controller tests, and the approved design requires public Prometheus or operator-visible metrics

Action:
- Do trace each claimed metric dimension through the public exporter and focused exporter tests; flag a blocker when the controller records required bounded labels but the public Prometheus row drops or renames them; don't accept direct stats as proof of public observability unless the approved evidence plan classifies that value as internal-only

## Improvement: Closure sweep keeps durable docs aligned without re-running the report

Condition:
- When the Manager has closed a stage with documented reclassifications, BLOCKED items, or follow-up tasks, and the task is to apply that closure to durable design and implementation docs (entry doc, document index) rather than rewrite the test report

Action:
- Do update the entry-doc top-level Status line, current-gate paragraph, and stage-gate section to describe the closed-with-limitations state, link the executed test report, fixes handoff, and developer review from the entry doc, list follow-up tasks as setup/evidence requirements rather than accepted skips, and update document-index.md rows to reflect the executed test report and the closure decision; don't modify the test report body, evidence sections, or the test plan to record the specific outcome, don't add a closure section to a one-time manager gate handoff doc, and when the Manager explicitly authorizes the closure, do change the top-level Verdict line in the final test report from FAIL to PASS to match the closed state; don't drift into rewriting evidence narratives or removing prior failure-section headings that are accurate historical records

## Improvement: Closure sweep preserves historical failure headings

Condition:
- When a closure sweep updates a stage implementation log that contains prior bug-fix loop or failed-attempt section headings dated earlier than the closure date

Action:
- Do keep those prior failure headings as-is when their body still accurately documents the earlier state, update only the most recent bug-fix loop heading that the closure actually closes, and add a new dated closure section after the loop that met the contracts; don't rewrite or remove historical failure headings to make the document look like the stage closed cleanly the first time, and don't rephrase prior closure-attempt headings to claim success when the user rejected them

## Improvement: Verify test-report counts before applying closure text

Condition:
- When applying a closure sweep to durable design or implementation docs based on a test report, or when reviewing a Manager closure decision that reclassifies FAIL or BLOCKED rows before the bug-fix loop is complete

Action:
- Do check the test report's final PASS, FAIL, BLOCKED, and SKIP counts and the test plan's closure contracts (for example, coverage thresholds such as the 80% hybrid-path coverage rule, or rules against recording missing coverage or benchmark evidence as accepted skips) before applying closure-claim text to durable docs; if any row is FAIL or the plan forbids reclassifying the missing evidence as accepted, refuse to apply closure-claim text, flag the closure as premature, and link the test report evidence without claiming the stage is closed; do keep the test report discoverable, link it from the entry doc and document index, and record the real final counts; don't apply closure-claim text to durable docs just because the test report exists or because the test counts are real measurements, and don't rely on a reclassification that converts FAIL into BLOCKED-with-evidence to make a closure contract disappear