# Architect improvement memory

## Improvement: Hidden test_reports directory and path resolution

Condition:

- `file_search` returns no matches for paths under `.test_reports/` or other dot-prefixed dirs

Action:

- Do use `list_dir` on parent or `Get-ChildItem -Force` to discover real name. Do record actual parent path once, reuse across all rows. Don't waste turns calling `file_search` against hidden path.


## Improvement: Tracker template must be literal markdown block

Condition:

- Authoring governance doc (tracker, handoff, request log) where downstream agents append rows in fixed schema

Action:

- Do provide new-row template as fenced code block (4-backtick fence) consumer copies verbatim. Do use same column order, header text, pipe style as main table. Do verify by counting columns against header before commit. Don't describe template in prose; downstream mistype column names and schema drift. Do keep example row short: one short title, `pending` status, em-dash for empty cells, one short context line.


## Improvement: Coverage reports need matching denominator source

Condition:

- Reviewing a coverage verdict where the report contains both raw tool totals and a filtered project denominator

Action:

- Do verify the cited percentage from the same denominator the verdict uses. Do not mix a raw Cobertura root `line-rate` with a filtered project-only table. If both rates appear, cite the filtered result row for filtered acceptance and mention the raw root rate only as context.


## Improvement: Evidence-source consistency in test plan

Condition:

- Test plan scenario rows reference metrics not exposed in public Prometheus endpoint

Action:

- Do check each metric reference against design observability and implementation review. Don't assume metric names in rows are publicly observable. Do flag row referencing internal stat as requiring stats-capable harness or focused C++ test in evidence requirements.


## Improvement: Memory load before acknowledgement

Condition:

- Task instructions require reading self-improvement memory before any other action; multiple skills or long brief

Action:

- Do make first assistant action and first tool call single-purpose memory read of skill and memory before any ack, comment, plan, or non-memory tool use. Don't batch memory reads with task reads, status checks, or skill loads in `multi_tool_use.parallel`. Don't send user-facing update first. Don't let AGENTS.md, environment context, efficiency concerns, or long brief tempt batching.


## Improvement: Gate wording with open findings

Condition:

- Architecture, design, implementation, or re-review deliverable changes gate state or closes earlier finding; entry docs carry stale limitation, owner, or handoff wording

Action:

- Do check live entry docs, active fix reports, correction-evidence status lines, correction part handoff sections, downstream design handoff, index summaries, top-level Status lines, current-status sections, handoff text, parts lists, and linked gate-status part files before and after patching. When adding a new review or re-review part, link it from the parent entry and update any index summary whose handoff wording would otherwise stay on the old gate. Do distinguish historical quoted findings from current contradictions. When a re-review passes after an initial REWORK, label the initial findings as historical and put the PASS link/status on the re-review, not "PASS per" the earlier failing review. Do keep durable gate-status locations in same state: reviewable, rework-required, manager-gate-ready, planning-open, approval-pending, approved, ready-for-QA, bug-fix-review-pass, implementation-re-review-pass, or blocked. Don't leave stale limitation, review-pending, awaiting-review, re-review-ready, handoff-closed, ready-for-review, ready-for-implementation, ready-for-re-review, or not-started wording after gate advances or while finding remains. Do grep `git diff` output and the patched file content for stale-status phrases inside IF/ELSE contingency branches that the patch did not touch; an unchanged contingency branch can still hide a stale phrase. Do prefix retained contingency branches with an explicit `Historical outcome (<date>): ...` label that names the actual path taken when only one branch applied. Don't rely on a single status-line edit to clear all stale wording in a part file.


## Improvement: Contingency-branch stale wording hides after status-line fix

Condition:

- Closure sweep updates top-level Status line, handoff text, and gate sections but leaves IF/ELSE contingency-branch text in the same part file with stale wording (e.g., `decision status: OPEN` inside a failure branch after the actual rerun passed)

Action:

- Do grep the entire part file for stale phrases after editing the top-level status line; contingency branches and contingency tables (e.g., acceptance criteria with `if PASS / if FAIL` rows) are common hiding spots. Do prefix the entire contingency section with `Historical outcome (<date>): <which branch was taken>` so the contingency wording is clearly labeled as not-applicable. Do not delete the contingency text outright; it documents what the next engineer would do if the bug recurs. Don't trust a top-level status-line edit to clear all stale wording. Don't ship a part file with stale wording in a contingency branch without explicit historical-context labeling.


## Improvement: Misconfigured-probe diagnosis vs product bug

Condition:

- Architectural fix instructions for BLOCKED fixture-dependent row (e.g., public metrics row zero) where fixture capable but probe misconfigured

Action:

- Do trace probe start command against design-required flags and server stdout/stderr to confirm misconfiguration vs product bug. Do specify corrected start command with exact flag names from parser source. Do include focused-substitute evidence path with specific test names and assertion points. Don't leave row in generic BLOCKED state without corrected start command or substitute evidence citation.


## Improvement: Untracked or partly-tracked review doc paths

Condition:

- Adding or updating review part files in doc tree untracked or partly tracked by git

Action:

- Do track paths edited during task. Do verify contents directly with targeted reads, ripgrep, line counts, raw byte checks when `git diff` cannot show untracked content. If user requires `git diff --check`, still run it, but remember it ignores untracked files unless they are staged; pair it with a direct whitespace/byte check for the edited untracked doc. For new untracked durable docs, run a separate whitespace check such as `git diff --check --no-index` against an empty temp file and interpret no output as clean even though no-index exits 1 for content differences. Do separate task-local edits from pre-existing dirty paths and from older diffs inside the same index or tracker file before reporting. Do report task-local path list. Don't rely on `git diff` or `git status` alone to prove what changed. Before declaring referenced doc "not edited", do run `git status -- <path>` and read current contents; report as pre-existing rather than own work.


## Improvement: CRLF and trailing whitespace on Windows tool-inserted content

Condition:

- File-editing or content-creation tool on Windows inserts CRLF line endings or trailing whitespace while surrounding file is LF-only; `git diff --check` reports errors

Action:

- Do convert to LF-only by reading raw bytes, filtering out `0x0D`, and writing with `[System.IO.File]::WriteAllBytes` (or `[System.IO.File]::WriteAllText` with explicit UTF8-no-BOM but only AFTER a byte-level CR strip). Do NOT trust `ReadAllText` + `WriteAllText` alone; on Windows the read preserves CR and the write preserves CR. Do verify with raw byte inspection: no `0x0D` anywhere, no UTF-8 BOM, no trailing whitespace on any line. Do run `git diff --check` after conversion. Don't trust tool's default line endings. Don't use `Set-Content -NoNewline`; collapses file to single line. Don't trust `Measure-Object -Line` for line count; it counts only non-empty lines and can return a number much smaller than actual line count (e.g. 60 for an 86-line file). Do use `(Get-Content path).Count` or LF byte count for true line count. Don't claim EXITCODE alone proves cleanliness; report separately for new untracked, own entry-doc edits, pre-existing trailing whitespace user's edits didn't introduce. Don't use padded table-column style on new files if linter flags MD060; compact single-space padding satisfies rule.


## Improvement: Batch normalize LF and verify across multi-file durable design authoring

Condition:

- Authoring entry doc + N part files for a new stage design on Windows in one task; create_file inserts CRLF on every file; MD047 (trailing newline) and MD032 (blanks-around-lists) only surface after writing; risk of reporting "clean" when individual files have small whitespace defects that only lint catches

Action:

- Do write a small tmp-byte-scan script (drop 0x0D, ensure trailing LF, write back, verify CR=0, last=LF, no EF BB BF BOM) and run it over EVERY new file in one pass before the final git diff --check. Do not trust create_file's line endings on Windows; do not trust one normalize pass to fix every file (some tool edits may re-insert CRLF or strip trailing newline on a re-save). Do run the byte-scan loop and git diff --check --no-index per file in a loop, treating empty output as clean and exit code 1 as content-diff noise. Do not paste large inline PowerShell into a terminal call when the script tokenizes `$_` badly; do save the script to tmp and run via `-File`. Do not trust linter warning alone for MD047 (missing trailing newline) when --check exit code is also noisy; do verify last byte == LF in the byte-scan output. Do report each file's LF count, CR count, BOM status, and last-byte status in the post-task summary.


## Improvement: CRLF noise in git diff --check on cpp inserts

Condition:

- Re-reviewing fix on Windows where the touched cpp file is pre-existing CRLF (CR count == LF count), and git diff --check reports "trailing whitespace" on every `+` line of the insert

Action:

- Do not flag as defect until byte-level verification. Do read raw bytes, count CR, confirm CR==LF matches whole-file ratio. Do identify the CR character at end of the `+` line as the source of the warning. Do record as Windows CRLF diff noise when whole-file CRLF consistent and user hard constraint says "CRLF for cpp". Do not record as code defect, lint failure, or repeat finding.


## Improvement: Self-claim format verification in review subjects

Condition:

- Reviewing bug-fix report, fixes handoff, or any review subject that makes a self-claim about its own format properties (LF line endings, no unicode, under 300 lines, no trailing whitespace)

Action:

- Do verify each format claim with byte-level check (`[System.IO.File]::ReadAllBytes` + `0x0D` membership, BOM check, unicode scan) regardless of what the subject's own text says. Don't trust the subject's self-description; on Windows, `create_file` and `Set-Content` insert CRLF even when the author writes `\n` mentally and the file text claims "LF line endings". Do compare against a sibling durable doc in the same directory as a sanity reference (e.g., parent test report should be LF-only; if fixes file has CR=True and parent has CR=False, the deviation is real). Do flag as BLOCKING when a user-listed checklist item like "LF-only" is violated, even if the underlying code change is correct; documentation hygiene is a gate per repo documentation governance. Do record format-property violations as separate findings from code-correctness findings so re-review can fix just the doc.


## Improvement: Design correction vs new stage for post-closure follow-ups

Condition:

- Closed stage surfaces new design gap through investigation; task is to author correction, not rework or new stage

Action:

- Do add new part to closed stage's design directory (next available number) as primary deliverable. Do add separate architecture-level part if invariant applies beyond closed stage. Do record new part as post-closure follow-up in entry doc without re-opening closed stage's design gate. Do cite new test plan rows as proposals; test plan is separate durable doc, let test plan follow-up pick them up. Don't fold correction into closed stage's existing parts. Don't reopen closed stage's gate. Don't touch implementation log or test plan as part of correction.


## Improvement: Code-review findings tied to approved docs

Condition:

- Performing implementation review against approved staged design or implementation plan

Action:

- Do tie each blocking finding to exact code location and specific approved design or plan requirement it violates. Don't block sign-off on style or pre-existing behavior unless affects current stage gate.


## Improvement: Line-ending diff noise on Windows

Condition:

- Reviewing script, config, or text change applied on Windows where edit tool rewrites line endings; `git diff` shows large symmetric insert+delete while real content change small

Action:

- Do run `git diff -w --numstat` and `git diff -w` first to confirm whitespace-ignoring content change. Do run `git diff --check` on touched path. Do count raw CR/LF/size and read first three bytes for LF-only and no BOM. Do read full diff only for line context around hunks. Don't assess content from full `git diff` alone when stat shows large symmetric numbers; line-ending rewrite can hide or duplicate hunks.


## Improvement: Debug-hook evidence is not production integration

Condition:

- Implementation evidence claims runtime contract covered by tests or diagnostics, but code under review exposes behavior through debug hooks, standalone helpers, or unit-only APIs

Action:

- Do verify production save, restore, eviction, metrics, or lifecycle path actually invokes behavior. Don't accept debug-only coverage, mirrored helper commit paths, or synthetic sleep windows as proof of a production branch. Do flag blocker when tests only exercise debug hooks, standalone APIs, or helper-owned critical sections for a contract the approved design assigns to the production flow. Do name the exact production branch that remains unexercised and require a hook that pauses or observes that real branch.


## Improvement: Skill path fallback

Condition:

- Required repo skill listed in session but first documented skill path cannot be read

Action:

- Do check repo-local `.agents/skills/<skill>/SKILL.md` path before falling back to ad hoc behavior. Do record path issue only briefly.

## Improvement: Doc-only gate-alignment task with pre-existing dirty working tree

Condition:

- Doc-only edit task where instructions quote expected "current" Status/Date/row strings; same header file already carries pre-existing modifications from earlier sessions; long markdown tracker rows exceed 2000 chars and display-truncate; `git diff --stat` lumps pre-existing dirty paths with task-local edits

Action:

- Do run `git status --short` before editing to separate pre-existing dirty paths from task-local edits. Do read the live file content first; do not assume the instruction's "currently reads" string still matches when the path shows prior modifications. Do extract the exact long row with `Get-Content | Where-Object { $_ -like '| 34 |*' }` substring before crafting oldString. Do prefer narrow targeted `replace_string_in_file` calls (one per status cell, one per appended link) over pasting the full long row. Do report task-local path list separately in the report when `git diff --stat` mixes pre-existing edits with task edits.


## Improvement: Scoped traceability for deferred requirements

Condition:

- Authoring stage design for subset of architecture requirements; intake lists broad requirement ranges with later-stage subrequirements

Action:

- Do expand each named contiguous requirement range into explicit checklist before finishing. Do trace every relevant requirement or subrange as covered, constrained, or explicitly deferred in persistent design. Don't skip standalone requirements inside range. Don't leave deferred subrequirements implied only by scope section.


## Improvement: Atomic-operation design reviews

Condition:

- Reviewing or correcting design or implementation claiming operation atomic but described steps mutate live state in sequence; or implementation evidence documents limitation against approved atomicity contract

Action:

- Do require explicit pre-apply validation, scratch-apply or exact rollback contract, fallback live-state outcome, diagnostics or metrics, and failure-injection tests before marking design or implementation ready. Don't accept goal-level wording like "leave state valid" or documented production limitation unless durable design has approved exception.


## Improvement: Handoff prerequisites in plan reviews

Condition:

- Reviewing implementation plan whose approved design or prior gate says planning or code work must wait for manager handoff, gate approval, or other prerequisite decision

Action:

- Do verify prerequisite decision recorded or linked in durable docs before returning PASS. Don't treat technically sound plan as approved when doc set still says handoff closed.


## Improvement: Cross-part protocol consistency in multi-part design

Condition:

- Multi-part design specifies step-by-step protocol in one part and failure-mode handling for same steps in separate part; two parts can produce conflicting state outcomes (e.g., transient state set before enqueue attempt but failure table implies prior state preserved on queue-full)

Action:

- Do read both protocol steps and failure-handling table together. Do identify cases where protocol mutates state before fallible step and failure table implies that mutation reverted. Do record as non-blocking observation with concrete implementation contract requirement. Don't flag as blocking when correct outcome unambiguous across both parts.


## Improvement: Drift direction vs accounting-fix hypothesis

Condition:

- Reviewing cold-store / cache accounting fix plans where hypothesis says metric drifts UP (cleanup doesn't decrement) but observed evidence shows metric is LOWER than disk (e.g., 351 MiB metric vs 5.6 GiB disk, ~16x ratio per descriptor)

Action:

- Do verify drift direction by dividing observed filesystem bytes by observed metric bytes and comparing per-file/per-descriptor ratio. Do not accept hypothesis #N from design without checking observed direction matches. Do flag if per-id map uses descriptor-reported bytes (target_size + draft_size) when observed drift shows descriptor under-reports disk size; in that case per-id map alone will not close gap, exact bytes_written from io_completion_result is the actual fix. Do record as non-blocking observation when plan documents the limitation and provides residual-drift fallback. Do not block sign-off when plan provides explicit drift_ratio target and "explicit accounting-fix note" fallback in test report.


## Improvement: Unstated decrement paths in accounting-fix plans

Condition:

- Reviewing cache / counter accounting fix that lists specific decrement sites (cold_budget_make_room, mark_payload_evicted, cleanup loop) but code contains additional decrement sites not enumerated (e.g., promotion-success path that decrements cold bytes when a payload moves back to hot)

Action:

- Do grep for the counter name across the controller to enumerate all decrement sites before reviewing completeness. Do flag unstated decrement sites as non-blocking observation; plan should at minimum acknowledge them or explicitly say "all other sites use existing logic". Do not block sign-off when the unstated path uses the same formula being replaced (descriptor bytes), so behavior is unchanged.


## Improvement: Dependency graph completeness in plan reviews

Condition:

- Reviewing implementation plan where later steps add member variables to class and earlier-numbered steps add methods using those same variables, but dependency list on method-adding steps does not reference member-adding step

Action:

- Do trace each step's code changes to check that every member, function, or type referenced exists at point step's dependencies satisfied. Do flag any symbol introduced only in later step as blocking missing-dependency. Don't assume numerical step order implies correct dependency graph.


## Improvement: Plan-review precondition names later-numbered step

Condition:

- Reviewing implementation plan whose Step N precondition says "Step N+M is in place" or similar reference to a step numbered greater than N (e.g., Step 06 says "the cooldown gate (Step 07) is in place" while Step 07 follows Step 06 in numerical order)

Action:

- Do flag the forward step reference as non-blocking observation; the plan is reviewable as written. Do name three resolution paths the implementation session can pick: (a) author the referenced infrastructure inside Step N (collapse two steps into one), (b) renumber so the infrastructure step precedes its consumer, (c) document Step N as a basic version with the later step hardening it. Don't flag as blocking when the named step genuinely exists in the plan and the dependency is operationally satisfiable. Do record line number, referenced step number, and chosen resolution in the post-task improvement so the implementation session can act on it.


## Improvement: Metric count claims need source verification

Condition:

- Reviewing a design, implementation plan, or evidence report that states an exact metric count, rename count, or script reference count

Action:

- Do verify exact counts against source, not summary prose. Grep each named metric prefix or counter in the relevant source and script files, count unique callsites or table rows, and compare with the document claim. Record mismatches as non-blocking when the underlying contract still holds; block only when the wrong count changes required implementation or test scope.


## Improvement: Coverage-method decisions in plan reviews

Condition:

- Reviewing implementation plan whose approved design requires coverage tool, metric type, command family, denominator, or exclusions defined before code work starts

Action:

- Do verify plan names coverage tool and whether it provides branch or line coverage on intended platform, not only denominator or later "select before implementation" placeholder. Do flag missing coverage-method selection as blocking plan gap when design made it pre-code decision.


## Improvement: Verify current state before applying review fixes

Condition:

- Fixing findings from design review where review report describes older version of design

Action:

- Do read current file state first. Do compare against review report's description of problem. Do apply fixes only for issues still existing in current files. Don't blindly apply all review recommendations without verifying current state.


## Improvement: Re-review corrected designs for new scope drift

Condition:

- Re-reviewing design edited to close earlier architecture blockers

Action:

- Do verify each correction implementable from documented data model and does not pull deferred-stage behavior into current stage without required safety contract. Don't limit re-review to confirming old finding text disappeared.


## Improvement: Narrow re-reviews still update navigation state

Condition:

- Task asks for focused re-review of one prior finding and also says update index only if materially needed

Action:

- Do keep review finding scope narrow, but still update entry-doc contents, current gate text, stage-gate text, and any index row that would otherwise describe old review state. Don't leave stale REWORK, awaiting-review, or correction-drafted wording in durable navigation docs after PASS re-review.


## Improvement: One-gate stage design authoring

Condition:

- Task asks to advance exactly one architecture gate by creating new stage design deliverable

Action:

- Do mark authored design as ready for independent review while leaving design review, manager gate, implementation planning, implementation, and QA gates unstarted. Don't use new design doc to approve later gates or imply implementation authorization.


## Improvement: Design-review PASS with Manager gate pending

Condition:

- Independent design review passes and task asks to advance tracker or handoff toward implementation planning while Manager design gate is still pending

Action:

- Do record independent design review as PASS in the review report, entry doc, index, and tracker; do update every entry-doc gate field that still says `design`, `ready for design review`, or similar stale review-pending wording. Do keep Manager design gate explicitly pending and name Manager as next owner when that stage requires Manager approval before implementation planning. Do not imply code work is authorized until the required next gate passes, even if tracker status moves to implementation-planning per task instruction.


## Improvement: Operational stage design keeps architecture scope verbatim

Condition:

- Authoring stage design for stage whose architecture scope, deliverables, and exit criteria are fixed; stage is operational (upstream merge, stress validation, security review, benchmarking) rather than feature

Action:

- Do keep architecture scope, deliverables, and exit criteria as design baseline. Do write design around operational contract (preconditions, command family, evidence shape, rework workflow, log format) instead of redefining what stage produces. Don't invent new deliverables, new exit criteria, or new scope items. Don't split single architecture scope block into narrower design scope items. Don't relax architecture exit criterion even if test plan or evidence scope cannot meet it at first attempt.


## Improvement: Multi-payload implementation reviews

Condition:

- Reviewing implementation adding second payload kind, descriptor reference, or residency path to existing cache entry or branch node

Action:

- Do trace admission, restore selection, pre-restore residency filtering, byte accounting, eviction, demotion, promotion, cleanup, metrics, and tests for each payload kind separately and together. Do verify cold or transient descriptors can still reach intended promotion, fallback, or rejection path instead of being filtered out as absent. Don't accept aggregate entry-level accounting or debug-only coverage as proof all payload kinds participate in production lifecycle.


## Improvement: Plan-review code-snippet type and format check

Condition:

- Reviewing implementation plan whose cpp snippets use std::min, SRV_DBG, LLAMA_LOG, or any printf-style macro; plan claims snippet "compiles" or "implementable" without naming field types at assignment site

Action:

- Do look up field types in actual header. Do check std::min return type matches LHS field type without implicit narrowing. Do check SRV_DBG/LLAMA_LOG format specifier against argument type (int32_t wants %d, uint32_t wants %u, size_t wants %zu). Do flag non-blocker when snippet compiles with warning or format wrong. Don't accept "compiles" as proof of snippet correctness without type check.


## Improvement: PASS with residual evidence limits

Condition:

- Implementation re-review has focused substitute evidence for design requirement but still lacks model-backed, public HTTP, or live Prometheus evidence requested for later QA closure

Action:

- Do decide implementation gate from approved code contract and available substitute evidence. Do carry missing runtime evidence as explicit QA risk or next-owner item when not required to prove code correctness. Don't keep REWORK verdict solely because QA still needs fixture-backed confirmation.


## Improvement: Public exporter shape in observability reviews

Condition:

- Reviewing implementation evidence claiming metrics complete through direct stats, JSON get_stats() rows, or focused controller tests; approved design requires public Prometheus or operator-visible metrics

Action:

- Do trace each claimed metric dimension through public exporter and focused exporter tests. Do flag blocker when controller records required bounded labels but public Prometheus row drops or renames them. Don't accept direct stats as proof of public observability unless approved evidence plan classifies that value as internal-only.


## Improvement: Closure sweep keeps durable docs aligned

Condition:

- Manager closed stage with documented reclassifications, BLOCKED items, or follow-up tasks; task is to apply closure to durable design and implementation docs (entry doc, document index) rather than rewrite test report

Action:

- Do update entry-doc top-level Status line, current-gate paragraph, and stage-gate section to describe closed-with-limitations state. Do link executed test report, fixes handoff, and developer review from entry doc. Do list follow-up tasks as setup/evidence requirements rather than accepted skips. Do update index rows to reflect executed test report and closure decision. Don't modify test report body, evidence sections, or test plan to record specific outcome. Don't add closure section to one-time manager gate handoff doc. When Manager explicitly authorizes closure, do change top-level Verdict line in final test report from FAIL to PASS. Don't drift into rewriting evidence narratives or removing prior failure-section headings that are accurate historical records.


## Improvement: Closure sweep preserves historical failure headings

Condition:

- Closure sweep updates stage implementation log containing prior bug-fix loop or failed-attempt section headings dated earlier than closure date

Action:

- Do keep prior failure headings as-is when body still accurately documents earlier state. Do update only most recent bug-fix loop heading that closure actually closes. Do add new dated closure section after loop that met contracts. Don't rewrite or remove historical failure headings. Don't rephrase prior closure-attempt headings to claim success when user rejected them.


## Improvement: Triage per-area breakdown label vs unique count

Condition:

- Reviewing pre-merge or triage report listing per-prior-stage-area breakdown with counts and label like "by INTEGRATE count" or "by decision"; task brief asks whether per-area counts sum to unique INTEGRATE or unique decision count

Action:

- Do verify whether breakdown is per-commit count with overlap (single commit can touch multiple areas) vs unique-decision count. Do accept underlying data as correct when design rule is "touched by at least one commit" and per-area list internally consistent. Do record mislabel as non-blocking observation with suggested label rename. Do verify unique INTEGRATE count separately in INTEGRATE breakdown list, not by summing per-area counts. Don't reject report on label alone when underlying count correct and design's aggregation rule satisfied.


## Improvement: Verify test-report counts before applying closure text

Condition:

- Applying closure sweep to durable design or implementation docs based on test report; or reviewing Manager closure decision that reclassifies FAIL or BLOCKED rows before bug-fix loop complete

Action:

- Do check test report's final PASS, FAIL, BLOCKED, SKIP counts and test plan's closure contracts before applying closure-claim text. Do refuse to apply closure-claim text when any row FAIL or plan forbids reclassifying missing evidence as accepted. Do keep test report discoverable, link from entry doc and index, record real final counts. Don't apply closure-claim text just because test report exists. Don't rely on reclassification converting FAIL into BLOCKED-with-evidence to make closure contract disappear.


## Improvement: Reopened gate substitute-evidence audit

Condition:

- Reviewing a reopened stage gate where prior closure accepted wall-clock BLOCKED live rows, and later evidence or local fixtures may provide a smaller-model substitute

Action:

- Do read the latest QA report, Developer review, reopened test-plan part, tracker row, implementation entry, and local fixture inventory before accepting the old closure. Do distinguish transport/driver proof on a smaller local model from model-profile proof that still needs the original or MTP-capable fixture. Do require Manager docs to mark the prior closure as superseded/reopened until QA and Developer confirm expected-hit classification. Don't let "large model timed out" remain a blocker when a smaller fixture can prove the same cache behavior contract.


## Improvement: Cross-cutting stage planning notes

Condition:

- Extending multi-stage architecture or delivery plan by adding new stage addressing cross-cutting concern (upstream merge integration, stress validation, security review) rather than new feature; implementation-notes section does not yet mention how new stage relates to prior stages

Action:

- Do add short note in implementation-notes section naming cross-cutting concern, pointing to new stage number, explaining why it can revisit or invalidate prior stages. Don't invent new entry-doc files for cross-cutting stages when they fit naturally in same planning part file. Do verify file stays under 300-line split rule after addition.


## Improvement: Plan drops test named in approved design Testability section

Condition:

- Reviewing implementation plan whose approved design's Testability section enumerates test cases T-...-N..M, and plan's regression-test step lists a subset of those names without recording deferral rationale

Action:

- Do diff the plan's regression-test list against the design's Testability section test names. Do flag any design-named test missing from the plan's regression set as NON-BLOCKING finding with required action: add the test or record explicit deferral. Do not assume plan author deliberately dropped a single test; on a multi-test design list one omission is a common miss. Don't block PASS when the missing test covers a code path also covered by another test in the set; block only when the missing test is the sole proof of a new code path.

## Improvement: Plan-level risk additions match design risk table style

Condition:

- Reviewing implementation plan whose evidence-or-risks section adds risks beyond design's risk table; design uses single-column "Mitigation" or "Mitigation before approval" format rather than separate "Mitigation" and "Residual risk" columns

Action:

- Do verify each new plan-level risk carries concrete trigger, impact, and mitigation. Do accept single-column style as residual-outcome-embedded when matches design's table. Do flag missing trigger, impact, or mitigation on new risk as blocking plan gap. Do record style observation as non-blocking note. Don't require plan to split column when design does not. Don't invent residual-risk language design never used.


## Improvement: Closure doc sweep part-file split and CRLF normalization

Condition:

- Closure doc sweep adds substantial closure section, follow-up plan, tooling limitation addendum, and evidence-pointer list to stage entry doc and test-plan part file without those sections previously

Action:

- Do write full closure record in new part file from start; put short pointer in entry doc. Do write test-plan tooling limitation addendum in new part file; put short pointer in parent test-plan part. Do trim closure-status or lift-attempt narrative in merge log to short pointer referencing entry-doc closure part. Do convert every modified or new file to LF-only UTF-8 (no BOM). Don't author closure section inline in entry doc. Don't leave CRLF line endings on Windows-created markdown files. Don't rely on PowerShell `[regex]::Matches($string, '`n')` for line-ending counts; that token in single quotes is literal backtick-n and returns zero matches.


## Improvement: Pre-commit git diff --check --cached on every doc sweep

Condition:

- Doc sweep scope includes committing untracked durable docs authored by other agents on Windows; worktree author is same Windows host

Action:

- Do run `git diff --check --cached` on staged set before commit, not just on worktree diff. Do convert any staged file with CRLF to LF-only. Do re-run `git diff --check --cached` after conversion. Don't trust untracked file authored by another agent on Windows is LF-only or whitespace-clean. Don't add trailing space in markdown blockquote separator like `> `; use `>` alone with no trailing space.


## Improvement: Document-index row column-count check

Condition:

- Replacing row in `document-index.md` (or any markdown table) and user-supplied row text does not match table's column count, or prior row text already had column-count mismatch

Action:

- Do count columns in new row text against table header (split on unescaped `|` with surrounding whitespace stripped) before applying. If new row has fewer columns than header, do add missing column with one-line description rather than leaving row short. Do record column-count fix in post-task improvement rather than as blocking finding. Don't reject user-supplied text on column count alone. Don't add filler text to description column to reach header count. Don't add padding rows to balance tables when only one row is short; instead, do fix the row's column count directly.


## Improvement: Speculative decode-batch sizing needs call-site flow trace

Condition:

- Reviewing speculative decode-batch sizing rule claiming specific per-call token bound for draft context; design rationale cites formula like `1 + n_max` or `n_parallel * (1 + n_max)` as per-call bound

Action:

- Do trace actual call site flow: target decode in chunked loop, then speculative process, then draft decode. Do verify draft per-call `batch.n_tokens` same as chunked-loop chunk size, not separate formula. Do record non-blocking finding when design's stated per-call bound holds only for `n_parallel = 1`. Do verify cap-bump formula includes `min(n_batch, ...)` clamp that target `server_n_outputs_max` applies. Don't accept "symmetric formula" wording without checking clamp present.


## Improvement: Latest follow-up state before stage baseline PASS

Condition:

- Reviewing new stage design that names prior stage as CLOSED, while prior implementation tree has later follow-up parts, partial reports, or Manager closure records after cited closure commit

Action:

- Do read latest follow-up parts and test reports, then decide whether they are terminal, open, or unrelated before passing prerequisite. Do flag stale baseline as blocking when new stage covers behavior changed or still pending in follow-up. Don't rely on original closure commit alone when newer durable records exist.


## Improvement: Per-context cap vs per-sequence cap ambiguity in chunked-decode

Condition:

- Reviewing design or architecture part specifying chunked-decode bound as `min(n_batch, cparams.n_outputs_max / n_parallel)` or "equivalent per-sequence cap," and actual chunked loop chunks whole batch (not per-sequence)

Action:

- Do verify whether cap is per-context or per-sequence. Do check correct per-chunk bound is `min(n_batch, cparams.n_outputs_max)` (per-context). Do record non-blocking finding when design "per-sequence cap" wording could be misread as different chunking rule. Don't accept per-sequence wording as equivalent to per-context bound without checking loop actual behavior.


## Improvement: Closure sweep instruction references missing index row

Condition:

- Manager or user closure sweep task instructs updating specific row in `document-index.md` for phase entry doc, but row does not exist in implementation or design table

Action:

- Do verify row exists with targeted search before applying append. If row missing, do not silently invent new row from template; do not silently skip index update. Do appends on entry docs that exist, update rows that exist, and flag missing row in handoff so Manager or follow-up agent can author index row separately. Do verify pattern in nearby rows (column count, cell content scope, description style) so follow-up author has concrete template. Don't claim all instructed edits complete when one of cells missing its row.


## Improvement: Stage contract growth pushes part file over 300-line cap

Condition:

- Authoring later operational stage design that mirrors earlier stage part-file structure and adds new contract rows to constraints and traceability tables

Action:

- Do plan split up front. Do keep merge log, constraints, observability, testability, risks in main part file. Do move exclusions, traceability, handoff to overflow part file; link overflow from main part and entry-doc contents list. Do verify with line count after writing; split immediately when count exceeds 300. Don't try to trim constraint or traceability table to fit; new contracts mandatory and cap hard rule.


## Improvement: Cycle-scoped test reports under hidden test_reports dir and 300-line split rule

Condition:

- Reviewing cycle-scoped artifact (pre-merge report, merge log, test report) under hidden test_reports dir that exceeds 300-line cap

Action:

- Do record file size as non-blocking observation with two options: (a) document exception in implementation entry doc "Contents" section for cycle-scoped reports, citing earlier-stage precedent, or (b) split report into main file plus part file. Do recommend option (a) for cycle-scoped reports anchored to specific cycle date; recommend option (b) only when Manager prefers strict adherence. Don't flag as blocking finding; index rule's split mandate applies primarily to durable design docs, and pre-merge report is one-shot artifact. Do verify line count with raw LF byte count, not just `Measure-Object -Line`, and convert new file to LF-only UTF-8 (no BOM) before running `git diff --check`. Don't accept cycle report as "too long to review" or "split later"; surface rule and two-option recommendation in review's Required corrections or Handoff section.


## Improvement: Architecture deliverable bullet vs design named-callout

Condition:

- Reviewing operational stage design where architecture lists specific deliverable or test-coverage bullet by name and design implements bullet only by reference to procedure document rather than naming bullet in design section

Action:

- Do verify each architecture bullet named in corresponding design section, not only referenced. Do record as non-blocking observation with concrete section reference when design's procedural consistency holds but design does not call architecture bullet by name. Do recommend explicit naming for traceability. Don't flag as blocking when underlying procedure correct and design's reference resolves to named bullet's section. Do verify architecture bullet satisfied before recording PASS.


## Improvement: General-rule "apply consistently" beyond listed line numbers

Condition:

- Manager decision revises procedure or guide to add path alternative to documented primary path, and task lists explicit line-level changes plus general rule to "apply consistently" or "wherever the guide says..."

Action:

- Do scan each modified file with `Select-String` for same construct after applying listed line changes. Do apply same alternative-wording rule to remaining sites explicit list didn't name. Do confirm with final pass that construct appears only in forms that name both primary and alternative. Do update `document-index.md` only if part file's name, role, or split changes.


## Improvement: Post-review Manager decision revision

Condition:

- Manager revises recorded design decision (D1, D2, etc.) after design review doc for stage already closed and recorded original decision as accepted

Action:

- Do update design review doc finding rows and checklist items that reference revised decision with revision date, new decision wording summary, and pointer to where new text lives. Do mark row as ACCEPT (post-revision) rather than re-running design review. Do apply same wording change to every other part file and entry doc that quotes old decision. Don't fold revision into follow-up Manager gate or implementation plan step. Don't re-open design review gate. Don't leave design review reading as if original decision still in force.


## Improvement: Plan-review bare upstream ref vs explicit remote-tracking ref

Condition:

- Reviewing implementation plan whose Manager decision selects direct remote-tracking ref (e.g., `origin/upstream_master`) over local tracking branch, and plan uses bare ref name in conceptual or procedure-rule sections while explicit remote-tracking ref name used at all decision points and verification commands

Action:

- Do flag bare ref name in conceptual references and procedure rules as non-blocking observation. Bare form is conceptual reference, not stale "local tracking branch" instruction, but in explicit-ref context could be misread. Do record as N-class finding with concrete line numbers and suggested wording. Don't flag as blocking when all decision points and verification commands use explicit ref name consistently. Do verify by scanning each modified file for both bare and explicit form.


## Improvement: Plan-review resolved-decision in open-decision range

Condition:

- Reviewing implementation plan whose Step activity names range of Manager decisions to surface, and one of decisions in range already RESOLVED in same plan's Manager decisions log

Action:

- Do flag inclusion of resolved decision in still-open range as non-blocking observation. Plan material correct on resolution status; wording only issue. Do record line number, resolved decision, and suggested wording. Don't flag as blocking when plan's Manager decisions log already records correct RESOLVED status. Don't require plan to remove resolved decision from activity list entirely; activity can still name decision for traceability as long as wording marks it resolved.


## Improvement: PowerShell regex and $matches pipeline gotchas

Condition:

- Extracting structured data from log files via PowerShell `-match` operator across multiple lines in one pipeline

Action:

- Don't reuse $matches from one `-match` call in the next; PowerShell resets $matches between `-match` calls in the same pipeline. Do capture each match into a local variable before the next `-match`. Don't grep for substring that matches multiple patterns; do use leading-whitespace anchor or exact-match filter. Don't trust `Group-Object | ForEach-Object { $_.Group[0] }` for "first" when file is sorted; the first element is first occurrence in file order, not the minimum. Do use `Measure-Object -Minimum` on the value field for actual minimum.


## Improvement: Recurring part-file link across entry-doc sections

Condition:

- Adding new Contents-section link for part file in test-plan or design entry doc, and same part number or link text also appears in another section of same doc

Action:

- Do run grep_search for part line before editing and treat multi-match as expected. Do include neighboring ## section header in oldString to scope match when inserting into Contents section. Do not replace part line in both sections at once; non-Contents section is stage-anchored pointer and should keep own list. Do verify new link appears in Contents section and other section's line unchanged.


## Improvement: Plan-supplied relative paths vs source-file location

Condition:

- Executing user-supplied plan that authors or extends document at known repo path and plan text contains explicit relative Markdown links or filesystem paths to other files

Action:

- Do verify each relative path resolves from source file's actual location before committing. Do correct path during edit when wrong, record correction in post-task return summary, and don't reject plan outright. Do verify with `Test-Path` from source file's parent directory.


## Improvement: Pre-existing UTF-8 characterization before "preserve" claim

Condition:

- Task or plan says "existing file may have UTF-8 characters; preserve them" or similar, and constraint names specific character (e.g., em dash) without enumerating what is actually present

Action:

- Do scan source file's raw bytes for named UTF-8 pattern plus adjacent patterns (em dash, en dash, BOM, emoji) before editing, and report actual character set in return summary. Do count with `[System.IO.File]::ReadAllBytes` and byte triplet loop, or use regex against decoded string with explicit char codes. Do apply new section as plain ASCII regardless of which UTF-8 form present in existing file.


## Improvement: Bind-facts numbered list spanning prose headers trips MD029

Condition:

- Authoring bind-facts section with sequential numbered list 1..N where prose headers like "Code facts, file:" interleave between groups of items; markdownlint sees each prose header as list terminator and reports MD029 (ordered-list prefix expected 1/2/3, not 7/8/9)

Action:

- Do convert bind-facts to bullet list (- ) when items are independent reference rows; bullets are unaffected by MD029. Do keep global numeric ids like "F1" or "Bind-N" inline at the start of each bullet if a stable identifier is needed for cross-reference. Don't use a single bloated numbered list with prose interrupts that visually read separate. Do run markdownlint after the conversion to confirm no MD029 remains.

## Improvement: Brief R-item wording imprecision vs actual code behavior in bug-fix review

Condition:

- Reviewing bug-fix against brief with specific R-items, and R-item uses slightly imprecise wording that conflates related but distinct cases (e.g., brief says "fallback path taken when no boundary ends at target" but code only takes fallback when NO boundaries at all, not when boundaries exist but none end at target)

Action:

- Do verify each R-item claim against actual code in touched file, not just brief's interpretation. Do distinguish overall claim from specific code behavior claim. Do read touched function's if/else branches to confirm which case triggers which behavior. Do record wording imprecision as INFO, not BLOCKING, when overall claim holds but specific code behavior narrower than brief describes. Don't reject fix on wording imprecision alone. Don't accept R-item as PASS without checking actual code path.


## Improvement: Post-closure follow-up design review scope and dual-doc traceability

Condition:
- Reviewing a post-closure follow-up design correction (not full stage re-review) where correction introduces both a new design part (stage-scoped) and a new architecture-level invariant (cross-stage); task brief says review correction only

Action:
- Do write review verdict in new part file under the new stage's design directory (e.g., the current stage design directory), not in the closed stage's part file. Do follow the documented placement rule. Do explicitly state scope rule in review file (correction only, not full closed-stage re-review). Do list reviewed files in a scope table.
- Do include a separate Traceability section mapping each design claim to BOTH the stage design part AND the new architecture part line refs. Do not merge stage and architecture traceability into one cell.
- Do verify checksum function equivalence by reading both implementations when design says "same function" and code uses two byte-for-byte identical functions in different files (e.g., cache_metadata_checksum vs cache_token_span_checksum). Do record as non-blocking observation when equivalence holds but design wording imprecise.
- Do include Manager-decision-impact section when correction affects a prior Manager closure decision (e.g., reclassification of rows). Do recommend but do not make the decision. Do not fold the decision into the review verdict.
- Do not touch closed-stage design, implementation, test plan, or test report files. Do not run builds, tests, coverage, or k6. Do not load other agents' skills or memory. Do not re-open closed stage's design gate.
- Don't accept PASS without verifying the architecture-level invariant is correctly scoped to cross-stage applicability (architecture part's Cross-stage applicability section enumerates affected scopes) and the stage-level design correction is correctly scoped to one function or one file.
- Don't leave manager gate decision column at pending after PASS without recording the next owner in the Handoff section.


## Improvement: Variable scope in restructuring diffs

Condition:

- Reviewing a code diff that restructures control flow (e.g., replacing a `bool flag` pattern with a `pointer-or-null` pattern) and the diff removes the original flag declaration but keeps an assignment to the removed variable

Action:

- Do grep the diff for every variable name in the new code. Do verify each assignment and read has a matching declaration in scope (local, member, or parameter). Do flag the missed variable deletion as BLOCKING compile error. Do not trust the Developer's "Status: applied" claim without checking the code. Do check the touched function's full scope including any helper lambda or nested block. Don't accept "looks fine" without grep verification of every variable name.


## Improvement: Brief file-size claim verification

Condition:

- Reviewing a doc change where the brief claims a file is "at 300 lines (cap)" or any specific line count, and the brief uses the count to claim cap compliance

Action:

- Do verify the actual line count with `(Get-Content path).Count` before recording the cap check. Do flag the discrepancy as non-blocking finding when the file exceeds the cap. Do not trust the brief's count. Do record the actual count in the checklist evidence column. Don't accept "at the cap" as PASS without verification.


## Improvement: Code review for restructuring-diffs must check all surviving variable references

Condition:

- Reviewing a code change that replaces a `bool flag` pattern with a `pointer-or-null` pattern in a function, and the diff has both removed lines (declaration, early assignment, post-loop fallback) and added lines (new pointer variable, if-else branches)

Action:

- Do scan the diff for the original variable name after the `-` removal lines. Do check the `+` added lines for any assignment to the removed variable name. Do flag the surviving assignment as BLOCKING compile error. Do not assume the Developer cleaned up all references. Do verify by reading the actual file, not just the diff hunks. Don't accept the diff hunks alone; the actual file state may have survived lines the diff doesn't show cleanly.


## Improvement: Bug-fix review scope must verify test report root cause against code

Condition:

- Reviewing a bug-fix where the test report (FAIL) includes a root cause analysis that claims a specific code path or loop behavior as the reason for the failure

Action:

- Do verify the test report's root cause claim against the actual code in the touched file (read the function, trace the branches). Do record wording imprecision as non-blocking finding when the test report's overall claim holds but the specific code-behavior claim is slightly off. Do not let test report root cause analysis block the review if the bug-fix code itself is correct. Do not try to debug the original test failure during the bug-fix review; focus on whether the new fix is correct. Don't accept test report root cause as gospel; don't reject fix on test report wording alone.


## Improvement: Bug-fix review with environmental verification blocker

Condition:

- Reviewing a bug-fix where verification is blocked by a system-level crash or environmental issue that reproduces on baselines with no fix-related flags, and the fix is a pure reordering or relocation with byte-identical moved logic

Action:

- Do distinguish between fix-introduced blockers and environmental blockers. Do verify the blocker reproduces on baselines (no cache flags, default settings) before classifying as environmental. Do check fit_params projection, memory accounting, or other environmental indicators for system state change. Do approve the fix based on code review alone when the moved logic is byte-identical and the fix is dependency-safe (uses only pre-set fields). Do surface the environmental blocker as a separate Manager decision rather than blocking the bug-fix review. Do not require re-execution of the repro in the same system state. Do verify the fix is positioned to produce the expected clean behavior on the next clean-state execution (e.g., bounded error message text, expected exit code). Don't conflate environmental blockers with fix correctness. Don't block sign-off on a correct fix when the blocker is reproducible on baselines with no fix-related flags.


## Improvement: Brief R-item claim about matching loop first-match behavior

Condition:

- Bug-fix review brief says a new boundary will be picked first by a matching loop, but the loop iterates by token_end and picks the first boundary with the matching token_end regardless of whether it's the new boundary or a pre-existing per-message boundary

Action:

- Do trace the actual matching loop iteration order. Do record the brief's wording as non-blocking finding when the overall fix works (the new boundary is added to the list and is reachable) but the specific first-match claim is slightly off. Do verify the fix works end-to-end by checking the strict validator's re-iteration of boundaries after the matching loop sets descriptor fields. Don't reject fix on first-match wording imprecision alone when end-to-end behavior correct.


## Improvement: Standalone model-log analysis as durable architecture evidence

Condition:

- Advising or authoring a separate model-log analysis report for cache behavior after a stage has created implementation parts and test reports

Action:

- Do place durable Markdown analysis in the active stage implementation tree as the next numbered part when it drives architecture, Manager decisions, or cache behavior questions; keep raw logs under `._analysis` or `._test_output` and reference them. Do update `document-index.md` for the new durable part, and update the stage tracker only if the report changes gate state, classification, or handoff. Don't put new durable model-log conclusions only in raw log folders or transient test artifacts.


## Improvement: Architecture part filenames from entry docs

Condition:

- When a task asks for specific architecture part numbers and the architecture entry document lists full part filenames

Action:

- Do read the entry document links and use those exact filenames for part reads. Don't guess shortened part filenames from part numbers or section titles.


## Improvement: Implementation-review deferral honoring

Condition:

- Reviewing an implementation whose implementation evidence (e.g., a referenced implementation part) explicitly lists deferred or partial items, and the plan accepts those deferrals as the stage contract for the implementation-review gate

Action:

- Do verify each deferred item is recorded in the implementation evidence and that the design baseline does not require it for this gate. Do record checklist verdict as DEFERRED-ACCEPTABLE when deferral is contract-accepted, not BLOCKING. Do note the manager decision or design exclusion that authorizes the deferral. Don't re-surface implementor-recorded deferrals as new blocking findings when the contract already accepts them. Don't fold deferral evaluation into the main PASS/FAIL verdict; carry it as a separate per-row verdict and a short overall note.


## Improvement: MD040 and MD024 in multi-item design docs

Condition:

- Authoring stage design that contains multiple items (e.g., two distinct fix items) where each item has its own "Context" or "Behavior change analysis" subsection, and design includes code snippets

Action:

- Do add language tag to every fenced code block (for example cpp for C++ snippets, powershell for PowerShell, text for plain). Do disambiguate repeated subsection titles across items with item-specific qualifiers (for example Item 1: Context vs Item 2: Coverage build context; Item 1: Behavior change analysis vs Item 2: Coverage-build behavior change analysis). Do run markdown linter after writing to catch MD040/MD024 before finalizing. Don't use bare fences; linter reports MD040. Don't reuse exact H3 heading text across items; linter reports MD024.


## Improvement: Pre-fix line citations in post-fix handoff text

Condition:

- Reviewing bug-fix report where Handoff or Rationale section cites specific line numbers for the return-false pattern or other code shape that existed in pre-fix file; post-fix source has those exact lines pointing to different code after the fix's move

Action:

- Do flag pre-fix line citations in fix report handoff as non-blocking observation (NB-class) when fix itself is correct. Do suggest replacing pre-fix line numbers with post-fix line numbers (e.g., the new return-false lines in the moved block). Do not block gate on stale pre-fix citations when source diff is correct. Don't silently rewrite fix report during review.


## Improvement: Unescaped pipes in markdown review table cells

Condition:

- Authoring review report with markdown table cells that quote PowerShell pipeline commands (e.g., `git show HEAD:path | Select-String -Pattern 'X'`), brace-expansion paths (e.g., `path/{A|B|C}-*.md`), or any text containing `|` characters inside a 4-column table row

Action:

- Do escape every `|` inside table cell content as `\|` before committing. Do scan all table cells for unescaped pipes after writing. Do run the linter (or `markdownlint` equivalent) on the file before declaring done. Do not rely on backtick code-fence protection alone; some linters still treat `|` inside backticks as a column separator. Don't ship a review report with MD056 (table-column-count) or MD060 (table-column-style) errors.


## Improvement: Path-prefix consistency between evidence text and on-disk artifacts

Condition:

- Reviewing implementation evidence that references artifact paths in manifest table or prose; plan file uses one convention (e.g., ._test_output/) but evidence file uses different convention (e.g., _test_output/)

Action:

- Do cross-check evidence file's path references against actual on-disk listing using Get-ChildItem -Recurse -Force. Do record the discrepancy as non-blocking finding since artifacts exist at correct path. Do note which convention the plan file uses and recommend normalizing evidence file to match. Don't flag as BLOCKING when artifacts are findable via the plan-correct path; this is documentation hygiene, not implementation defect.


## Improvement: Infrastructure pass is not workload coverage

Condition:

- Authoring a follow-up stage design after a prior report passed fixture, launch, script, or infrastructure readiness but explicitly deferred full workload coverage

Action:

- Do separate the prior infrastructure PASS from the new workload PASS criteria. Do define the exact workload classes, fixture limits, time caps, metrics, evidence files, and PASS/FAIL/BLOCKED outcomes needed before the follow-up can close. Don't let a prior launch or smoke report stand in for mixed workload evidence.


## Improvement: Multi-item stage design with per-item Manager decision gating

Condition:

- Authoring stage design with multiple items where one or more items require a binding Manager decision (e.g., fixture acquisition path, integration branch choice, deferred-item disposition) and other items do not depend on that decision

Action:

- Do list in the entry-doc handoff section which items may proceed in parallel with the Manager decision and which items MUST wait for the decision record. Do not block all items on a single decision when only one item depends on it. Do not let items proceed when the decision is binding for them. Do record the dependency direction explicitly per item. Do put the binding items in a separate gate-status row that names the Manager decision ID. Do keep the design authored-state wording for non-binding items so implementation planning can open for them independently. Don't invent a fallback path in the design when the user prompt explicitly forbids it; surface the gap as a Manager decision and stop.


## Improvement: Prototype edit checklist drift in plan reviews

Condition:

- Reviewing an implementation plan that patches a prototype script, and the plan states a design-required runtime value in ordered execution steps but omits that value from the prototype edit checklist

Action:

- Do compare current prototype constants against both the approved design and the plan's ordered execution steps. Do flag checklist omissions as non-blocking when the execution step already carries the binding value and implementation can apply it during the planned patch. Do make it blocking only when the omission leaves no enforceable step or evidence point for the required value.


## Improvement: Runner verdict must enforce design PASS criteria

Condition:

- Reviewing a runner script or harness that produces PASS, FAIL, BLOCKED, or PASS-candidate verdicts for a staged workload gate

Action:

- Do trace every approved design PASS/BLOCKED criterion into executable verdict predicates, not only into summary fields. Do require presence/minimum counts for every design-required workload class before PASS/PASS-candidate, then require the class-specific evidence for those rows. Do flag a blocking finding when the runner records required evidence counts or statuses but can still return PASS without proving them, or when it validates only rows that happen to exist while missing required classes can pass. Don't accept dry-run flag checks as proof that live verdict logic enforces bounded miss, redaction, metric, artifact, or workload-class requirements.


## Improvement: Parallel decision IDs across design and tracker

Condition:

- Reviewing a stage design authored before Manager records their binding decision; design uses a design-side decision ID like R-NN-DESIGN-MGR-01 and tracker records the Manager-side decision ID like DNN-EXEC-01; both refer to same fixture acquisition path or substitute choice

Action:

- Do record both IDs as non-blocking observation in the design review findings table. Do require implementation plan to reference both IDs in a single decision table row so future audits reconcile them. Don't reject design on parallel IDs when design correctly defers to Manager and Manager already recorded a parallel decision; the reconciliation is implementation-plan-time work.


## Improvement: State-machine validation-order contradictions

Condition:
- When reviewing a design for a state-machine refactor where one requirement says to preserve current validation order and another requires special handling for a state already rejected by that order

Action:
- Do compare the proposed order against current code line-by-line and flag the contradiction as blocking unless the design states the exact reordered branch or diagnostic outcome. Do require a focused unit assertion for the special state.


## Improvement: Race-fix plans need deterministic duplicate/stale assertions

Condition:
- When reviewing an implementation plan for an async race, stale callback, duplicate callback, or idempotent completion fix

Action:
- Do require focused deterministic unit assertions for the stale/duplicate state transitions and counter stability. Don't accept heavy rerun evidence or timing-dependent async behavior as the only proof path.


## Improvement: Placeholder tests are not acceptance evidence

Condition:
- When reviewing implementation evidence that maps a required test ID to a registered test function

Action:
- Do inspect the test body, not only its name and registration. If the function only prints, `assert(true)`, or otherwise cannot fail when the required behavior regresses, do not count it as meaningful coverage. Do accept separately registered underlying tests only when the implementation log states that mapping truthfully.


## Improvement: User hints are hypotheses, not requirements

Condition:
- When a bug-fix review mentions a user-provided thinking hint such as async timing, race behavior, or suspected root cause

Action:
- Do decide independently from code, evidence, and approved docs whether that hint is required for the fix. Don't treat the hint as a new design requirement unless Manager or the accepted design records it.


## Improvement: Fallback predicates must match accepted scope

Condition:
- When reviewing a bug fix that claims fallback is limited to restore-visible or resident state, but code gates fallback through a broader descriptor-exists predicate

Action:
- Do compare the exact predicate used for candidate visibility with the accepted fix wording and focused regression setup. Don't accept a descriptor-only predicate when the gate requires resident bytes or hot-record visibility; require code narrowing or a documented Manager-approved behavior expansion.


## Improvement: Fragility review blocker threshold

Condition:
- When Manager requires a fragility or design review after a multi-iteration
  bug-fix cascade before QA rerun authorization

Action:
- Do separate current-fix correctness from broader design fragility. Block QA
  only when the active fix violates approved architecture, leaves durable
  behavior undocumented, lacks a focused regression for the newly accepted
  contract, or needs a Manager-approved contract change. Record simpler
  ownership or retry-contract cleanup as advisory when the active contract is
  implemented, documented in persistent stage docs, and still gated by the
  heavy rerun.


## Improvement: Raw payload retention success paths

Condition:
- When reviewing a memory-pressure fix that drops, trims, or gates raw payload
  data only on a failure, skip, or rejection path

Action:
- Do inspect the corresponding success/admission path for retained raw vectors
  or copied payload lists. Do require a regression that proves the success path
  is bounded, not only that the skip path drops data.


## Improvement: Entry docs near line cap

Condition:
- When updating an entry/navigation document that is already close to the
  300-line cap

Action:
- Do run a line count after adding links or gate wording, then trim duplicate
  status text into the existing top-level status/gate line before finishing.
  Don't leave a parent entry over cap because the new detailed part is under
  cap.


## Improvement: Multi-leg row runner port contract

Condition:
- When reviewing a runner-contract fix where one logical row starts more than
  one server leg or uses `Port + N` internally

Action:
- Do verify the wrapper port allocation, batching rule, dry-run side log, and
  next-row interaction. Require a code fix when approved execution can batch
  the row with a colliding neighbor; otherwise record an explicit handoff
  constraint such as focused row only or `BatchSize 1`.


## Improvement: Mixed-workload runner evidence with collapsed public profiles

Condition:
- When reviewing a mixed-workload runner fix where the fixture's public prompt
  evidence collapses every request into one product profile or one lookup
  outcome

Action:
- Do distinguish fixture/product profile classification from harness prompt
  classes. Accept the runner contract only when a machine-readable artifact
  records per-class plan and counts, request status, metrics deltas, redacted
  evidence counts, checksum or lookup-path spread, and a non-PENDING summary.
  Record the collapsed public profile as a QA evidence limitation, not a
  blocker, unless the approved row requires product-visible profile diversity.


## Improvement: Durable report names and whitelist

Condition:
- When reviewing a plan or design that introduces a custom durable report name
  under `._design_docs/.test_reports/`

Action:
- Do check the active `.test_reports/.gitignore` whitelist and the test output
  folder convention before approving report placement. Require either a
  whitelisted report name or an explicit docs-only whitelist/convention update.
  When a plan correction intentionally supersedes an older design artifact
  name, record that supersession in the review or parent implementation doc so
  Manager can open implementation without relying on an ignored path. When
  implementation evidence claims a durable report or final report leak scan,
  verify the exact file exists on disk under the whitelisted path and is visible
  to `git status -- <path>`. Don't accept "durable" report paths that git will
  ignore or evidence checks for report files that are absent.


## Improvement: Smoke failures during implementation re-review

Condition:
- When implementation re-review evidence includes smoke-run FAIL or BLOCKED
  outcomes while the review subject is the runner contract rather than final
  test execution

Action:
- Do separate runner correctness from product or test-result behavior. Pass the
  implementation gate when the runner preserves `PASS`, `FAIL`, and `BLOCKED`
  states, computes the required evidence from artifacts, and keeps durable docs
  accurate. Record smoke failures as INFO or follow-up test-result risks unless
  the failure proves a runner-contract defect.


## Improvement: Closure sweep applies verbatim Manager decisions

Condition:

- Manager records explicit closure decisions and asks Architect to apply those decisions to durable design or implementation docs

Action:

- Do quote Manager decisions verbatim in the closure record and align per-row final classifications with them. Do update entry-doc current-gate and handoff wording to closed or terminal state. Do not rewrite final test reports, fixes files, developer review files, or test-plan evidence unless the Manager explicitly asks for those edits. Do convert new closure docs to LF-only UTF-8 before `git diff --check`.

## Improvement: Future-migration contract documented in main body

Condition:

- Reviewing multi-part design whose main body documents a future-migration contract (abort path with shadow fields, future API surface, planned refactor) that the current stage explicitly does not implement

Action:

- Do flag the unused future contract as non-blocking observation. Do recommend moving to OQ list, follow-up part file, or removing from main body. Do not block review when design correctly disclaims current non-implementation; reader may still misread contract as current behavior.


## Improvement: Architecture rework with constraint to not split into new parts

Condition:

- Task asks to rework an existing multi-part architecture doc to reflect a new stage target state; constraint forbids adding new part files or new sections to keep part count stable

Action:

- Do rework wording inside existing sections to reference the new stage's tx_* methods, mutex, and invariants. Do preserve stage traceability per existing part. Do update tables (requirements, traceability, integration boundaries) inline. Do not add new section headings or new part files; rely on existing structure to carry new content. Do consolidate new content into existing paragraphs or table rows. Do cite the new stage by name and reference its design doc instead of duplicating content. Don't split content into new files even when the part exceeds 300 lines, if the over-300 condition is pre-existing and the user has not authorized a split. Don't add cross-cutting sections even if the rework would naturally fit them; rework existing sections instead.


## Improvement: Verify which files actually changed before claiming preserved

Condition:

- Doc rework task that says "preserve parts X and Y" but the LF-normalize step touches every file in the directory

Action:

- Do run `git --no-pager diff -w --numstat -- <paths>` after edits to confirm content-only changes per file. Whitespace-ignored numstat isolates real content deltas; files with only CRLF to LF conversion show empty numstat. Do list explicit "Files preserved as-is" in the return message with the whitespace-ignored numstat as evidence. Don't claim a file is preserved just because no edit tool was called on it; the byte-level normalization pass may have rewritten it.


## Improvement: Plan-vs-design wording tension on folded-vs-retained helpers

Condition:

- Reviewing implementation plan where the design document says an existing helper is "folded into tx_X as inline worker call; no separate completion handler" but the plan text says the same helper "remains as a private helper used by the inline implementation" (or similar)

Action:

- Do cross-read design Part 3 (or equivalent migration table) row for each helper the plan claims to retain. Do flag plan/design wording tension as non-blocking observation, not blocking finding. Do recommend the implementation author pick one wording (either fully inlined or retained as private seam) and align the other doc to match before coding starts. Do not block plan review when the underlying operation result is identical and the wording difference is about source-organization preference. Do record the observation in the review's Required corrections or Non-blocking section so Developer can resolve during implementation.


## Improvement: Verify tx_* canonical entry points via caller search, not declaration

Condition:

- Reviewing implementation that introduces transactional API methods (tx_save, tx_restore, tx_apply_restore, tx_load) where design Part 3 mapping table names slot lifecycle methods (save_slot, try_restore_from_cache, load_slot) as routing THROUGH those tx_* methods

Action:

- Do grep production caller files (server-context.cpp, server-cache-hybrid.cpp) for actual `slot_lifecycle_method->tx_*` invocations before signing off on routing. Do confirm production call sites bind to tx_* methods; do not accept stub-returning-false tx_* methods as evidence of routing because lock acquisition in caller still preserves atomicity but breaks the canonical entry-point contract. Do distinguish alias tx_* methods (tx_evict_entry -> evict_entry_by_id, tx_update -> update) that DO acquire lock via aliased callee from stubs that bypass real work. Do flag as BLOCKING when tx_save/tx_load returns false unconditionally or tx_restore/tx_apply_restore has zero callers in production code path. Don't rely on existence of lock_guard at top of slot lifecycle as proof of routing; lock acquisition can live in either the slot lifecycle or the tx_* method, but only one path should be the canonical entry per design.


## Improvement: Stub vs implemented tx_* distinction

Condition:

- Reviewing implementation where design requires new tx_* methods that all should be canonical entry points but implementation leaves some as stubs returning false or empty

Action:

- Do read each tx_* method body and classify as: full implementation, alias to other tx_* or impl method that acquires lock, or stub (returns false / GGML_UNUSED params). Do list stubs separately from full implementations in review findings. Do call out stubs as BLOCKING when binding requirement says production slot lifecycle routes through them. Do not classify stubs as "API surface for future use" without explicit user/Manager approval recorded in design Part 6. Don't accept stub existence with `// real body in server-context.cpp` comment as compliant with routing requirement.


## Improvement: Closure sweep record-vs-test-report coupling

Condition:

- Closure sweep task records verbatim Manager decisions, per-row final classification, and code-change summary in entry-doc and new part file; risk that recorded classification differs from test-report final counts

Action:

- Do read the durable test report for the stage closure row (PASS/FAIL/BLOCKED/SKIP counts) before writing the closure record. Do verify each cited row classification matches the test report's per-row verdict field. Do record classification as BLOCKED-evidence-gap or BLOCKED-structural-not-infra with explicit Manager decision ID when Manager decisions reclassify rows; do not paraphrase Manager reclassification wording. Do include all 5 Manager decisions verbatim in the closure record when Manager passes a multi-decision closure. Do not edit the test report body, fixes files, or developer review files during closure sweep; those are durable evidence that must remain stable for downstream agents. Do verify gate-status wording across entry doc, current-gate section, gate-status table, handoff section, and tracker row stays in lockstep after closure. Don't claim closure complete when test report row count contradicts recorded final counts.


## Improvement: Doc sweep stale-phrase grep with legitimate-use exceptions

Condition:

- Closure sweep task lists specific stale phrases to remove (e.g., "current gate: test execution", "ready for QA", "open"); grep finds matches that are legitimate technical uses (file names like "open transactions" in technical sense, "open items" in triage sense)

Action:

- Do distinguish legitimate technical matches from stale-status matches before claiming grep clean. Do report grep result as "clean" only when all matches are legitimate (file names, technical vocabulary, historical quoted findings). Do not blanket-replace "open" without context check; file names and technical vocabulary are real. Do verify closure-purpose phrases (status: closed, D-CLOSURE-NN-NN, current gate: terminal) are present in all touched entry docs and handoff sections. Do list each touched file with closure phrases added in the return message so user can verify the swap.


## Improvement: Programming symbols with trailing asterisk in markdown prose

Condition:

- Authoring durable markdown design / review docs on Windows that reference programming symbols whose names contain a trailing or internal asterisk (e.g., `tx_*`, `n_*`, `foo_*`, `obj*`); the markdown linter flags MD037 (Spaces inside emphasis markers) when the symbol appears in prose with surrounding spaces or punctuation

Action:

- Do wrap the symbol in backticks every time it appears in prose or table cells (`` `tx_*` ``). Do not rely on the symbol appearing inside an existing code-fence to escape the linter; linters still parse emphasis markers outside code-fences. Do run a final grep before declaring done for any of: `* `, ` *`, `_*`, or any text-fragment-with-asterisk pattern and confirm each match is inside backticks or a code-fence. Do verify own deliverables byte-level after authoring on Windows (CR=0, no BOM, no unicode, no trailing whitespace). Don't ship design docs with MD037 errors when the fix is backtick-wrapping.


## Improvement: Rename impact radius includes durable docs and reports

Condition:

- Reviewing a hard rename of public metric names, artifact fields, script flags, or test labels

Action:

- Do grep source, scripts, durable design docs, test plans, and active reports for the old name. Update current operational docs and entry docs to the new name. Leave old names only when they are historical evidence, and label that status so readers do not treat old names as current contract.


## Improvement: Tight-scope rework respects file boundary even for non-blocking items

Condition:
- Task brief says tight scope (e.g., 'fix the counts only') AND lists non-blocking items that target OTHER files, while hard constraint says 'DO NOT modify other files beyond what these fixes require'

Action:
- Do limit edits strictly to the file(s) named by the BLOCKING fix descriptions. Do report non-blocking address ratio as X/N honestly with one-line deferral reason. Do run grep_search verifications for non-blocking items and include findings in the response as INFO without committing them to docs. Don't expand scope to non-blocking items even when addressing them is cheap and within reach. Don't silently skip the non-blocking items; surface them in the response so the next owner can decide.


## Improvement: Re-review count fixes require file-line match verification

Condition:

- Re-reviewing design after rework that claimed to fix a BLOCKING count mismatch (e.g. a document count claim did not match source)

Action:

- Do extract the claimed count text from design doc and the cited line numbers. Do read the actual fixture file at each cited line with Select-String -Pattern <regex> to confirm every cited line matches. Do pipe the same pattern through Measure-Object to confirm count == cited count. Do record the verified count, line list, and pattern used. Don't accept the design's self-claim alone; rework-session descriptions can lie about line numbers as easily as they did about counts. Do report VERIFIED only when both count and per-line content match exactly. Do record this as a separate finding from any other verification done.


## Improvement: Verify prior commit candidate fix before authoring new fix

Condition:

- User task names a bug as "still reproducing" and asks for a new design stage, but HEAD commit already contains a candidate fix in source comments

Action:

- Do run `git log --oneline -20` and `git show <commit>` on the most recent commit to find any candidate fix. Do read the relevant function in the current source and check whether the fix is in place. Do not assume "still reproducing" means "no fix attempted"; it may mean "fix attempted but unverified". Do design the new stage as verification-first (rebuild + rerun) before adding new code. Do cite the prior commit's candidate fix and source comment in the design's root-cause analysis. Do not propose a different fix without first explaining why the existing candidate is insufficient. Don't waste design effort re-deriving a fix that's already on disk.


## Improvement: Byte-scan normalize script in tmp/ for multi-file LF-only authoring

Condition:

- Authoring entry doc + N part files for a new stage design on Windows; create_file inserts CRLF on every file; MD047 linter surfaces trailing-newline defect after every create_file

Action:

- Do write a small PowerShell normalize script to `tmp/<stage>-normalize.ps1` that reads each new file's bytes, drops 0x0D, collapses any trailing LF run to a single LF, writes back, then verifies CR=0, last=10, no BOM, no trailing whitespace per line. Do run the script via `& tmp/<script>.ps1` after every create_file batch. Do run `git add` + `git diff --check --cached` and report exit 0. Do report each file's CR/LF/last/bom/lines/trailing_ws counts. Don't trust MD047 linter warnings alone; do verify last byte is LF in the byte scan. Don't inline large PowerShell into a terminal call when it tokenizes `$_` badly; do save to tmp and run via `-File`.


## Improvement: test-data reuse in focused regression tests

Condition:

- Authoring a focused regression test in tests/test-cache-controller.cpp that needs to drive N saves with large synthetic payloads

Action:

- Do pre-allocate N payload buffers before the save loop and reuse them across iterations; do measure the destination-side allocation (the bug pattern) without re-allocating the source buffers. Do snapshot baseline counts before the loop and assert post-conditions after the loop. Do use the public debug helper for the production path so the test exercises the same code path as the live server. Do add minimal debug helpers (3-5 one-liners) for tests that need internal map access. Do not reload or duplicate large buffers in the test loop; the test should measure destination behavior, not source memory churn.


## Improvement: Closure-cited root cause must be verified against source before inheritance

Condition:

- Authoring new stage design or design correction that inherits a root cause analysis from a prior stage closure part-file (e.g., prior closure root cause), and the prior closure cites specific line numbers, abort mechanisms, or NDEBUG/CONFIG_NDEBUG behavior

Action:

- Do read the cited source file directly with read_file and verify the cited line numbers and mechanism. Do grep_search for NDEBUG, __fastfail, abort(), __try, __except and similar symbols at the cited location. Do re-state the root cause in the new design with corrected wording when the prior closure is imprecise; do not silently inherit incorrect technical claims. Do record the correction as an explicit note (e.g., "Prior closure wording: ... Actual code: ...") so future stages can trace the correction. Don't trust prior closure as gospel; don't reject the prior closure's fix scope when the wording is imprecise but the fix is correct.


## Improvement: Drift direction must be computed before listing candidate fixes

Condition:

- Authoring or reviewing a fix design for a metric vs filesystem (or vs physical resource) drift where the drift direction is empirical but the design's candidate root causes are listed without checking whether each candidate would produce the observed direction

Action:

- Do compute the drift direction (resource_bytes / metric_bytes ratio) and per-resource uniformity (file size, record count) before listing candidates. Do verify each candidate would produce the observed direction. Do flag the candidate that produces the opposite direction as not-the-cause. Do require a diagnosis step in the design when no candidate matches the observed direction; do not pick the most-likely candidate and proceed without confirmation. Do record the empirical observation and the per-candidate direction analysis in the design part file so reviewers can audit the candidate set.


## Improvement: 300-line cap pre-allocation for multi-part designs with binding scope

Condition:

- Authoring stage design with binding scope (technical debt inventory, bug fix catalog, or multi-iteration plan) where a single part file risks exceeding 300 lines

Action:

- Do pre-allocate 300-line cap budget per part file before writing; do split into separate part files (one per concern) rather than combining fix-design + verification + risks in one file. Do keep entry doc under 100 lines when possible (link table only). Do verify with line count after writing each part file; do split immediately if count exceeds 250. Do use `## heading` level for per-item subsections and `### subheading` for per-fix details so the lint MD024 (no-duplicate-heading) does not flag cross-item subsections with the same name. Don't try to fit everything in one part file when the scope naturally partitions.


## Improvement: Async worker dead-code investigation must trace callers in both production and test paths

Condition:

- Investigating async worker code as technical debt after a prior stage design declared it retired but the methods, the worker thread, and the no-op stub still exist in the source tree

Action:

- Do grep_search for every method name (class, start/stop, enqueue_*, process_*, drain_*, handle_*_completion, worker_thread_func, debug_*_for_tests) across tools/server/, tests/, and any documented test helpers. Do classify each match as prod, test-only, or dead before deciding fix approach. Do specifically check whether the worker thread is actually started in the production constructor (not just declared) and whether no-op stubs are wired into production wait loops that burn wall-clock time. Do surface broken production paths (hang or descriptor leak) as new HIGH bugs even when the original task scoped the investigation as MEDIUM. Do promote the deletion to MEDIUM iteration 2 with explicit conditional (compile-clean Phase B first) rather than leaving it deferred to a future stage when the user asks the investigation in-scope. Do not trust comment text claiming the worker is "retained for source compat" without verifying the callers actually exist and the path is non-broken.


## Improvement: Plan-review deliverable filename table must match actual part-file naming

Condition:
- Reviewing implementation plan whose deliverable table in an open-questions part or similar summary section lists part-file paths that do not match the actual filenames in the same plan directory

Action:
- Do grep the plan directory for actual part file names (part files) before reviewing. Do flag any deliverable table row referencing a stale filename (e.g., one part filename when actual files use split part names). Do record as non-blocking observation since the entry doc links the correct filenames and the stale references are cosmetic; the developer doesn't follow these as implementation instructions. Do verify entry doc link table matches actual filenames since entry doc is the navigation surface.


## Improvement: Plan-review wording-vs-actual-code mismatch in cpp fix snippets

Condition:
- Reviewing implementation plan that describes a cpp line substitution using a pattern (e.g., if (self->promote_payload(...)) with if-wrapper) that doesn't match the actual code at the cited line (the line has no if, or has a different wrapper, or has been moved)

Action:
- Do grep the actual line number in the cited file to confirm the substitution pattern matches. Do record as non-blocking observation when the substitution intent is clear (replacing the method name) but the textual pattern is inaccurate; the developer applies the substitution regardless of pattern wording. Do not block sign-off on minor textual mismatch when the design and plan both name the correct method/line and the intent is unambiguous.


## Improvement: Plan-review [[deprecated]] marker location must match symbol's class

Condition:
- Reviewing implementation plan that marks symbols with [[deprecated]] but lists the wrong header file (e.g., a member of hybrid_cache_controller in server-cache-io-worker.h, or vice versa)

Action:
- Do grep the actual symbol's class declaration across all .h files in the same directory. Do flag as non-blocking observation when the marker location is wrong but the intent is clear. Do recommend the developer grep for the symbol first and apply the marker to the actual declaration header. Do not block sign-off when the marker is on the right symbol regardless of which header the plan names, as long as the developer can locate the right declaration.


## Improvement: Multi-candidate fix designs vs implementer-chosen alternative

Condition:
- Reviewing implementation report that cites a design part file as the basis for its fix but the design lists three named candidates (A/B/C) and the implementation takes none of them; the fix report cites the design as if it documented the chosen alternative.

Action:
- Do grep the design file for the cited "Option" or "Fix N" reference before accepting the citation. Do flag as BLOCKING design-scope drift when the approved design does not document the implementer's chosen strategy. Do require either a design correction (new part file or amendment to existing part) recording the chosen strategy before re-review, OR a revert to one of the approved candidates. Do not accept "achieves same outcome" as a substitute for design approval; design gate exists to constrain strategy choice, not just outcome. Do recommend the Manager decide between design amendment (preferred if the alternative is genuinely better) and revert (preferred if the approved candidates are still viable and the alternative defers critical root-cause fixes).


## Improvement: Counter pattern parity between get_stats() and Prometheus /metrics

Condition:
- Reviewing implementation that adds a new counter exposed via get_stats() JSON, when the user's checklist explicitly references `/metrics` (the public Prometheus endpoint) and a similar existing counter (e.g., cache_cold_cleanup_total) is exposed in BOTH endpoints.

Action:
- Do grep server-context.cpp for write_cache_metric calls to verify whether the new counter is exposed in the public Prometheus exporter. Do flag as BLOCKING when the user explicitly cited /metrics in their checklist and the existing pattern exposes similar counters in both endpoints. Do distinguish design-internal-only counters (acceptable in get_stats() alone) from observability-required counters (must be in /metrics). Do record the server-context.cpp line range where the new write_cache_metric line should be added. Do not accept "exposed in get_stats()" as proof of /metrics exposure when both endpoints have separate write_cache_metric wiring.


## Improvement: git diff --check on CRLF cpp files reports CR as trailing whitespace

Condition:
- Running git diff --check on cpp files in this repo where the file is CRLF throughout (CR count matches line count, design convention says "CRLF for cpp"); diff shows "trailing whitespace" on every newly added line but byte-level scan shows zero trailing space characters.

Action:
- Do run a byte-level scan (ReadAllBytes + 0x0D/0x20 membership) on the touched cpp file before declaring a hygiene defect. Do report the CR count vs line count to distinguish real CRLF convention from accidental trailing CR. Do flag as INFO, not BLOCKING, when byte scan shows CR matches line count and zero trailing spaces (genuine CRLF hygiene noise). Do flag as BLOCKING when byte scan shows non-zero trailing-space count or CR count > line count + 1 (genuine defect). Don't trust git diff --check exit code alone on a CRLF file; the exit code is 1 for any CR at end of line, which is the project's convention.


## Improvement: LLM-side prompt cache vs application-side response cache are different measurement domains

Condition:

- Reviewing a "can tool X measure or compare Y" question where X targets LLM-provider-side prompt-cache effectiveness (KV-cache reuse on chat-completions API, reading `cached_tokens` / `cache_read_input_tokens` / `x-cache` header) and Y targets application-level response caching (e.g., llama-server `--cache-mode legacy` vs `--cache-mode hybrid` with `llamacpp_cache_*` counters on `/metrics`)

Action:

- Do distinguish the two domains up front in the verdict. Do state which metrics surface each tool reads. Do not accept "reuse X to compare Y" without naming why the chat-completions response contains (or does not contain) the application cache counters. Do flag as Blocking when X discards live-state tool results in favour of a constant placeholder but Y needs real metric deltas. Do propose Options A (new driver, same shape), B (extend extractor with new rules), C (re-use pattern only) rather than picking one without user input. Do record explicit scope disclaimer in the existing tool's docs once the comparison decision is made.


## Improvement: Hybrid-mode A/B test layers and real-agentic workload capture

Condition:

- Designing or reviewing a comparison test between llama-server cache modes (e.g., `--cache-mode legacy` vs `--cache-mode hybrid`) intended to drive improvement/fix decisions on the hybrid mode, where the test must use real agentic sessions and measure both wall-clock and KV-cache reuse

Action:

- Do structure the report in three layers in order: correctness (cold-store validity, fallback rate, output equivalence) before per-request comparison (cache_n_ratio, ttft, wall_clock) before aggregated (mean hit rate, total reuse, VRAM peak). Don't bury correctness behind performance numbers. Do treat `cache_n_tokens` and `cache_n_ratio` (cache_n / prompt_n) as the headline per-request KV-reuse indicator and pair them with cumulative `/metrics` counter deltas for the population view. Do require workload capture at the LLM call site (logging proxy, OpenAI client wrapper) because existing chat_log.jsonl and bench-cache-correctness.js do not capture real completion requests. Do accept synthetic-but-representative workloads only when real-agent capture is impractical, and label them as such. Do frame the decision-support output as specific questions (does hybrid reuse more KV than legacy, when hybrid hits is it faster, is cold-miss overhead acceptable, is eviction policy hurting reuse, does correctness hold) rather than a single pass/fail. Do require identical warm-up, identical --ctx-size, --cache-ram, --parallel, and only --cache-mode and --cache-cold-path as variables between the two instances. Do surface ground-truth cross-checks (`du -sb` on cold dir, output equivalence check) alongside the `/metrics` counters to catch metric-vs-reality drift.


## Improvement: Sequential not parallel for server A/B comparison tests

Condition:

- Designing or reviewing a comparison test that boots two llama-server (or similar model server) instances to compare behaviour across configurations (cache mode, prompt-cache on/off, model variants, parallelism settings)

Action:

- Do require sequential execution of the two runs, not parallel. Do not run both instances concurrently even when they fit in VRAM. Do not assume resource contention is negligible because the two instances "should not interact". Do list the specific contention surfaces the sequential choice avoids (VRAM for two model weights plus two KV caches, CPU scheduler interleaving, RAM pressure, cold-store disk I/O interleaving, /metrics scrape window overlap, GPU thermal throttling from concurrent load). Do require a configurable cooldown between the two runs that covers VRAM release, file handle release, cold-store unmount, plus a host-state check (e.g., nvidia-smi VRAM back to baseline). Do use the same port for both runs since they are not concurrent. Do use the same captured workload JSONL for both runs so the prompt sequence, prompt timings, and prompt contents are byte-identical. Do record the full workload under a single JSONL path so the second run cannot accidentally replay a different file. Do not propose parallel execution even when the workload is short or when the test is intended to run on a multi-GPU host.


## Improvement: Multi-file durable-design authoring needs content-fix normalization, not just byte-fix normalization

Condition:

- Authoring a stage entry doc plus 11+ part files for a new stage design in one Architect session on Windows; create_file inserts CRLF; linter reports a mix of byte-level defects (MD047 trailing newline) and content-level defects (MD040 fenced-code-language, MD032 blanks-around-lists, MD004 ul-style plus vs dash, MD037 no-space-in-emphasis)

Action:

- Do write a single normalization script that combines byte-level (strip CR, ensure trailing LF, no BOM) with content-level (add `text` to bare ``` fences, replace leading `+ ` with `- `, replace `* N.NN` multiplication patterns with `x N.NN`, insert blank lines before list items that follow non-list non-blank content) fixes, run it across every authored file, and re-run the linter. Don't rely on per-file manual fixes when 10+ files share the same lint patterns. Don't fix bytes alone and let MD040/MD032/MD004/MD037 ship; don't fix content alone and let CRLF/trailing-newline/BOM slip through. Do verify each file with both a byte check (LF count, CR count, BOM check, trailing-LF check) and a pipe-count check before declaring done. Don't accept MD037 escape as a stopgap; rewrite `* 1.10` to `x 1.10` in the source so the multiplication sign is unambiguous.


## Improvement: Cache-mode A/B comparison requires current metric naming contract

Condition:

- Authoring or reviewing a legacy-vs-hybrid cache-mode comparison where proposal text or prior docs use older metric names

Action:

- Do reconcile every metric name against the current public `/metrics` contract before writing the design. Do replace stale underscore-form or no-prefix names with current names, and add a driver-side check that fails if the old form reappears. Do not silently inherit mixed metric naming from proposals or historical reports.


## Improvement: Stage tracker row column-count check before commit

Condition:

- Updating or replacing a stage row in `cache-handling-stage-tracker.md` or any markdown table whose header has fixed column count; task asks to change cell content (e.g., status, design doc link) in an existing row

Action:

- Do count pipes in the row being replaced and the header before applying the change. Do preserve the exact pipe count. Do not split a long cell with `|` characters that could be misread as column separators. Do not introduce `<br>` or other pseudo-newlines inside a cell. Do count pipes with a small PowerShell script (`($line.ToCharArray() | Where-Object { $_ -eq '|' }).Count`) before commit; running the script takes 2 seconds and prevents column drift that downstream readers will not notice. Do not rely on visual inspection of long cells in markdown tables.


## Improvement: Verify Stage M lib API before accepting design's reuse claim

Condition:

- Reviewing a stage design that reuses a Stage M (M < N) library or script and documents a driver invocation with specific parameter names or output shapes; design claims "no new script is needed" or "lib unchanged"

Action:

- Do read the actual lib's public function signature including [Parameter(Mandatory=...)] and [ValidateSet(...)] blocks. Do read the output schema from the lib's write function. Do check whether the lib requires a live server endpoint at the time of invocation. Do compare the documented driver invocation against the lib's actual mandatory and optional parameters; do not accept invocation parameters that the lib does not define. Do check the reuse table for "No modification" claims and trace each parameter listed back to the actual lib signature. Do flag as BLOCKING when driver invocation contradicts the lib's API, when the invocation order contradicts the lib's server dependency, or when the documented output schema contradicts the lib's actual output schema. Do record API mismatch, server-dependency mismatch, and output-schema mismatch as separate BLOCKING findings so the rework list can fix each independently. Do not accept "Stage M lib calibrated" wording without reading the actual function.


## Improvement: Stale line-number cites in closed-binary references

Condition:

- Reviewing design that cites specific line numbers in source files for prior-stage fixes that are preserved by the closed binary; the cited file may have grown or shifted after the cited fix landed

Action:

- Do treat the line number as historical reference only; do not block sign-off when the function or fix is preserved by the closed binary. Do flag as INFO when the cited line number does not match the current file line count, so future readers are not misled. Do not require the design to update the line number because the design does not modify that code.


## Improvement: Verdict-first review reports and table lint

Condition:

- Authoring a review report where task instructions require a `VERDICT: PASS` or `VERDICT: REWORK` line before the heading, and markdown lint also reports table or heading warnings

Action:

- Do keep the verdict line first when the task contract requires it; treat MD041 as an expected linter exception for that file. Do still fix real table defects such as MD056 or MD060 by counting pipes in every table row against the header, escaping literal `|` characters, or moving long cell details into follow-up paragraphs. Do not move the verdict under a heading just to satisfy MD041.


## Improvement: Parser fix must close every evidence channel

Condition:

- Reviewing a fix loop where Developer reclassifies a live product failure as a driver, extractor, or parser bug, but the failed report also cites independent evidence channels such as metric deltas, server logs, counters, or filesystem state

Action:

- Do trace each cited evidence channel back to its producer before approving the reclassification. Do require the fix report to explain why each binding channel was false or to provide new focused evidence that closes it. Don't let a request-row parser fix close metric-delta or server-log failures unless those channels share the same bug or have fresh proof.


## Improvement: create_file with dot-prefixed Windows paths lands in wrong directory

Condition:

- Using create_file with an absolute path under a dot-prefixed directory on Windows (e.g., d:\source\llama.cpp-jet\._design_docs\...)

Action:

- Do verify the resulting file path with Test-Path after creation. Do not assume the dot-prefix is preserved. Do move or rewrite the file to the correct path if it landed elsewhere (typical wrong-path is _design_docs\... without leading dot). Do delete the wrong-path file before continuing with format checks. Do record the correct path before running byte-level CR/LF/BOM checks. Do not rely on the tool success message alone. Do not read content from the wrong path and assume it is the intended file.


## Improvement: create_file on Windows inserts CRLF and non-ASCII chars

Condition:

- Authoring durable review report (or any markdown file) via `create_file` on Windows host; user hard constraint requires "ASCII only, LF line endings, no BOM, no trailing whitespace"; author writes content with em dash (U+2014), multiplication sign (U+00D7), or other non-ASCII characters naturally in text

Action:

- Do read raw bytes after `create_file` to confirm CR=0 and non-ASCII=0. Do strip CR bytes via `[System.IO.File]::ReadAllBytes` + `Where-Object { $_ -ne 0x0D }` + `WriteAllBytes`. Do scan for any byte > 0x7F and identify whether the sequence is UTF-8 multi-byte (e.g., 0xE2 0x80 0x94 = em dash, 0xC3 0x97 = multiplication sign). Do replace em dash with `--`, multiplication with `x`, right-arrow with `->`, and other punctuation with ASCII equivalents before byte-level check. Do verify last byte is 0x0A after the CR strip. Don't trust `create_file` to honor the "ASCII only" constraint even when the author thinks they wrote ASCII. Don't use `ReadAllText` then `WriteAllText` for the CR strip; the round-trip preserves CR. Do use `WriteAllBytes` from the byte array.


## Improvement: PowerShell disjoint line-range reads

Condition:
- Reading several non-contiguous line ranges from one file in PowerShell

Action:
- Do use separate `foreach($n in A..B)` loops or an array of explicit range objects. Don't assign `$ranges=@(A..B,C..D)` and then iterate as if each item were a range; PowerShell flattens or casts it poorly and can fail before any useful output.


## Improvement: Whole-file ASCII scan after touching dirty index docs

Condition:

- Editing an already-dirty markdown index or tracker file under a user constraint that touched markdown must be ASCII-only

Action:

- Do scan the whole touched file for non-ASCII after edits, not only the new hunk. Do convert pre-existing non-ASCII punctuation in that touched file to ASCII equivalents before final verification. Don't claim ASCII compliance from the authored section alone.


## Improvement: Focused evidence vs missing live rerun in implementation review

Condition:

- Reviewing implementation where the approved plan allows focused deterministic tests, but a prior live workload rerun has not been repeated after the fix

Action:

- Do decide pass or rework from the approved evidence contract and code-level coverage. Do record the missing live rerun as an advisory or Manager/QA gate decision when focused tests prove the root behavior and no design requirement mandates the live rerun. Don't hide the gap inside a PASS verdict, and don't block solely because a full rerun would be stronger evidence.


## Improvement: Near-cap design docs need line-count-aware linking

Condition:

- Authoring or updating a single-file stage design or review doc under the 300-line document-index cap, especially when adding review links/status to a parent doc already near the cap

Action:

- Do check `(Get-Content path).Count` before and after the first patch and before final hygiene checks. If the parent is close to 300 lines, add the review link/status by replacing or extending an existing status line instead of creating a new section. If the file is over 300 lines by only a small amount, condense duplicated checklist or handoff text instead of splitting. Do not proceed to final verification until the entry doc is 300 lines or fewer.


## Improvement: Prose-only evidence extraction blocks QA handoff

Condition:

- Reviewing an implementation or test-execution plan where the approved design requires QA to extract metrics, classify results, or prove hygiene from run artifacts

Action:

- Do require executable extraction commands or a named evidence-only extractor with fixed output paths and accepted regex/schema rules. Don't accept prose bullets such as "grep for labels" or "report p50/p99" when QA would have to choose patterns, files, thresholds, or destination paths. Do flag as BLOCKING when stale-binary proof names a timestamp rule but omits the source-file baseline to compare against.


## Improvement: Verify Developer line citations against actual file before quoting

Condition:

- Reviewing a Developer report that cites specific line numbers in production code as bind facts (e.g., "the slow read is at lines 4892-4910 of server-cache-hybrid.cpp")

Action:

- Do run Select-String or Get-Content with line offsets to confirm the cited lines contain the claimed code. Do not propagate the Developer's line numbers verbatim if they are off; cite the actual lines and note the discrepancy in a non-blocking observation. Do treat line-number drift as a useful signal: if a line-number is off by tens of lines, the Developer's analysis may be pointing at the wrong code path. Don't accept any cited line number without byte-level verification, even when the broader claim is correct.

## Improvement: Hyphenated globs can miss root peer files

Condition:

- Reviewing stage-specific file-glob filters for upstream merge triage or commit-set selection

Action:

- Do verify wildcard patterns against the actual repo file list before approving them. Check whether patterns like `src/llama-*.cpp` intentionally exclude root peers such as `src/llama.cpp`; flag a blocker when the excluded peer can carry the same runtime contract and Developer would have to invent an extra filter during triage. On re-review, confirm the correction covers every relevant filter row, not only one occurrence, and cite the actual file-list check before passing.

## Improvement: Verify invariant claims beyond the cited line

Condition:

- Reviewing a design or fix report that names an invariant tied to a code site (e.g., "idempotent save returns true at L4825") where the invariant claim depends on a wider code path than the single cited line

Action:

- Do trace the claim through every branch that satisfies the predicate's premise (e.g., predicate residency hot vs cold, with-entry vs no-entry). Do read helper bodies called from the cited branch (`materialize_entry_payload`, `admit_entry_with_payload`, `refresh_existing_entry`) to confirm the asserted effect (e.g., `use_count++` via `mark_used`) occurs on every reachable branch, not only the cited one. Do widen the invariant wording as a NON-BLOCKING finding if the live code is stronger than the invariant asserts. Don't accept an invariant audit that verified only one branch.

## Improvement: Test-only forced reads in production-path reviews

Condition:

- Reviewing a controller-only test that must prove a production slow-read or commit window but uses a test-only forced payload/read hook because no live model context exists

Action:

- Do verify the test still enters the real production transaction method, reaches the hook between the same lock/unlock boundaries as the live slow read, and resumes into the real commit or dedupe branch. Do record the forced bytes as a non-blocking test-fixture limitation when they are fully guarded by `LLAMA_SERVER_CACHE_TESTS`. Don't reject the test solely because the byte source is synthetic if the concurrency window and branch ownership are production code.

## Improvement: Manager-approved merge rework routing parts need complete per-track gates

Condition:

- Authoring upstream-merge rework routing parts after Manager groups REWORK-REQUIRED pre-merge rows by track

Action:

- Do copy every SHA, subject, decision, and affected surface from the accepted pre-merge analysis into the relevant track part. Do give each part the same gate-critical sections: affected contract owners, risk, required analysis before merge, allowed integration conditions, regression evidence, durable prior-stage or architecture doc updates if behavior changes, and blocked handoff. Do update the parent stage design status and handoff so merge execution remains blocked until all rework parts pass review and Manager gate.

## Improvement: Provisional upstream refs need Manager confirmation in merge-cycle designs

Condition:

- Authoring an upstream merge-cycle design from Manager intake that names an initial upstream reference candidate but says final reference policy is not closed

Action:

- Do keep the candidate ref provisional in the design, require Manager design-gate confirmation before Developer opens the commit range, and require fresh staleness checks both before pre-merge analysis and at regression time. Don't write the candidate as final policy just because the ref exists locally.

## Improvement: Review-time upstream staleness must be rechecked

Condition:

- Reviewing a merge-cycle pre-merge analysis that includes an upstream staleness verdict, commit range, and filtered triage table

Action:

- Do rerun a non-mutating upstream tip check such as `git ls-remote` during the review, without fetching, and compare it to the reported source ref before accepting the range. Do block the gate when the actual upstream tip moved after the Developer report, even if the report's local counts and table math are internally consistent.
