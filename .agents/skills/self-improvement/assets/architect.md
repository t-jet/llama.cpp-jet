# Architect improvement memory

## Improvement: Coverage denominator rate vs XML root rate

Condition:
- T114 verdict where QA report cites Cobertura XML root `line-rate` as combined rate for filtered denominator

Action:
- Verify cited rate is from script's filtered-denominator output (`coverage-report.md` combined result row), not XML root; XML root covers all tracked files, almost always lower than filtered-denominator rate. Estimate true rate from per-file table before deciding on bug-fix loop. Don't open bug-fix loop based solely on rate from wrong denominator.

## Improvement: Test-plan review evidence-source consistency

Condition:
- Reviewing test plan referencing both public HTTP observability and internal controller stats or focused C++ tests, and some scenario rows reference metrics not exposed in public Prometheus endpoint

Action:
- Check each metric reference against design observability section and implementation review to confirm Prometheus metric vs internal controller stat. Flag any row referencing internal stat as requiring stats-capable harness or focused C++ test in evidence requirements. Don't assume all metric names in scenario rows are publicly observable.

## Improvement: Memory load before acknowledgement

Condition:
- Task instructions require reading self-improvement memory before any other task action, including tasks starting with AGENTS.md content, repo instructions, long delegated-agent brief, or multiple required skills

Action:
- Make first assistant action and first tool call single-purpose memory read of self-improvement skill and Architect memory before any acknowledgement, commentary update, skill-use announcement, plan, analysis, other skill reads, or non-memory tool use. If skill-use announcement required, send only after memory read completes. Don't use `multi_tool_use.parallel` or batched shell calls to include architect, humanizer, repo docs, status checks, or other task reads in that first call. Don't send user-facing update first. Don't let AGENTS.md, environment context, long user brief, efficiency concerns, required skill list, or efficiency urge tempt batching memory reads with task reads.

## Improvement: Gate wording with open findings

Condition:
- Architecture, design, implementation-plan, implementation evidence, or re-review deliverable changes gate state or closes earlier finding; or current entry docs carry stale limitation, owner, or handoff wording

Action:
- Check live entry docs, active fix reports, correction-evidence status lines, `document-index.md` summaries, top-level Status lines, current-status sections, handoff text, and linked gate-status part files before and after patching. Distinguish historical quoted findings from current contradictions. Keep durable gate-status locations in same state: reviewable, rework-required, manager-gate-ready, planning-open, approval-pending, approved, ready-for-QA, bug-fix-review-pass, implementation-re-review-pass, or blocked. Don't leave stale limitation, review-pending, awaiting-review, re-review-ready, handoff-closed, ready-for-review, ready-for-implementation, ready-for-re-review, or not-started wording after gate has advanced or while open finding remains.

## Improvement: Misconfigured-probe diagnosis vs product bug

Condition:
- Writing architectural fix instructions for BLOCKED fixture-dependent row (e.g., public /metrics row showed zero) where fixture is capable but probe was misconfigured

Action:
- Trace probe start command against design-required flags (cache-mode, spec-type, cache-ram, etc.) and server stdout/stderr to confirm misconfiguration vs product bug. Specify corrected start command with exact flag names from parser source (e.g., common_speculative_type_to_str values). Include focused-substitute evidence path with specific test function names and assertion points covering public-row check via get_stats() or focused exporter tests, so Developer can fix probe or fall back to substitute evidence. Don't leave row in generic BLOCKED state without corrected start command or substitute evidence citation.

## Improvement: Changed paths for untracked review docs

Condition:
- Adding or updating review part files in doc tree that is untracked or only partly tracked by git

Action:
- Track paths edited during task. Patch new review files, entry docs, and index rows as separate steps when tree is dirty or untracked. Verify contents directly. Separate task-local edits from pre-existing dirty paths. Report task-local path list. Don't rely on `git diff` or `git status` alone to prove what changed. Before declaring referenced doc "not edited" or "not touched", run `git status -- <path>` and read current contents to confirm pre-existing uncommitted changes; report as pre-existing rather than own work.

## Improvement: CRLF trailing whitespace on Windows tool-inserted content

Condition:
- Using file-editing or create_file tool on Windows that inserts content with CRLF line endings while surrounding file is LF-only, and `git diff --check` reports `trailing whitespace` on every inserted line

Action:
- Convert inserted content to LF-only with `[System.IO.File]::WriteAllText` UTF8-no-BOM write. Verify with raw byte inspection that line endings are LF (no `0x0D` anywhere). Re-run `git diff --check` on touched path. Report EXITCODE separately for new untracked files (no-op, exit 0), own entry-doc edits, and pre-existing trailing whitespace user's edits did not introduce (verify with `git show HEAD:<path>`). Don't treat EXITCODE alone as proof of cleanliness.

## Improvement: Design correction vs new stage for post-closure follow-ups

Condition:
- Closed stage surfaces new design gap through investigation report; task is to author correction, not rework or new stage

Action:
- Add new part to closed stage's design directory (next available number) as primary deliverable. Add separate architecture-level part if invariant applies beyond closed stage. Record new part as post-closure follow-up in entry doc without re-opening closed stage's design gate. Cite new test plan rows as proposals (test plan is separate durable doc) and let test plan follow-up pick them up. Don't fold correction into closed stage's existing parts, don't reopen closed stage's gate, and don't touch implementation log or test plan as part of correction.

## Improvement: Code-review findings tied to approved docs

Condition:
- Performing implementation review against approved staged design or implementation plan

Action:
- Tie each blocking finding to both exact code location and specific approved design or plan requirement it violates. Don't block sign-off on style or pre-existing behavior unless it affects current stage gate.

## Improvement: Line-ending diff noise on Windows script edits

Condition:
- Reviewing script, config, or text change applied on Windows where developer used edit tool that rewrites line endings, and full `git diff` shows hundreds of insertions/deletions while real content change is small

Action:
- Run `git diff -w --numstat` and `git diff -w` first to confirm whitespace-ignoring content change. Run `git diff --check` on touched path to confirm no whitespace errors. Count raw CR/LF/size and read first three bytes to confirm LF-only and no UTF-8 BOM. Only read full `git diff` for line context around hunks. Don't assess content from full `git diff` alone when stat shows large symmetric insert+delete numbers; line-ending rewrite can hide or duplicate actual hunks.

## Improvement: Debug-hook evidence is not production integration

Condition:
- Implementation evidence claims runtime contract is covered by tests or diagnostics, but code under review exposes behavior through debug hooks, standalone helpers, or unit-only APIs

Action:
- Verify production save, restore, eviction, metrics, or lifecycle path actually invokes behavior. Flag blocker when tests only exercise debug hooks or standalone APIs for contract approved design assigns to production flow.

## Improvement: Skill path fallback

Condition:
- Required repo skill listed in session but first documented skill path cannot be read

Action:
- Check repo-local `.agents/skills/<skill>/SKILL.md` path before falling back to ad hoc behavior. Record path issue only briefly.

## Improvement: Scoped traceability for deferred requirements

Condition:
- Authoring stage design for subset of architecture requirements; intake lists broad requirement ranges with later-stage subrequirements

Action:
- Expand each named contiguous requirement range into explicit checklist before finishing. Trace every relevant requirement or subrange as covered, constrained, or explicitly deferred in persistent design. Don't skip standalone requirements inside range or leave deferred subrequirements implied only by scope section.

## Improvement: Atomic-operation design reviews

Condition:
- Reviewing or correcting design or implementation claiming operation is atomic but described steps mutate live state in sequence; or implementation evidence documents limitation against approved atomicity contract

Action:
- Require explicit pre-apply validation, scratch-apply or exact rollback contract, fallback live-state outcome, diagnostics or metrics, and failure-injection tests before marking design or implementation ready. Don't accept goal-level wording like "leave state valid" or documented production limitation unless durable design has approved exception.

## Improvement: Handoff prerequisites in plan reviews

Condition:
- Reviewing implementation plan whose approved design or prior gate says planning or code work must wait for manager handoff, gate approval, or other prerequisite decision

Action:
- Verify prerequisite decision is recorded or linked in durable docs before returning PASS. Don't treat technically sound plan as approved when document set still says handoff is closed.

## Improvement: Cross-part protocol consistency in multi-part design reviews

Condition:
- Multi-part design specifies step-by-step protocol in one part and failure-mode handling for same steps in separate part, and two parts can produce conflicting state outcomes (e.g., transient state set before enqueue attempt but failure table implies prior state must be preserved on queue-full)

Action:
- Read both protocol steps and failure-handling table together. Identify cases where protocol mutates state before fallible step and failure table implies that mutation must be reverted. Record as non-blocking observation with concrete implementation contract requirement. Don't flag as blocking finding if correct outcome is unambiguous across both parts.

## Improvement: Dependency graph completeness in implementation plan reviews

Condition:
- Reviewing implementation plan where later steps add member variables to class and earlier-numbered steps add methods using those same variables, but dependency list on method-adding steps does not reference member-adding step

Action:
- Trace each step's code changes to check that every member variable, function, or type referenced in step's changes exists at point step's dependencies are satisfied. Flag any referenced symbol introduced only in later step as blocking missing-dependency finding. Don't assume numerical step order implies correct dependency graph.

## Improvement: Coverage-method decisions in plan reviews

Condition:
- Reviewing implementation plan whose approved design requires coverage tool, metric type, command family, denominator, or exclusions to be defined before code work starts

Action:
- Verify plan names coverage tool and whether it provides branch or line coverage on intended platform, not only denominator or later "select before implementation" placeholder. Flag missing coverage-method selection as blocking plan gap when design made it pre-code decision.

## Improvement: Verify current state before applying review fixes

Condition:
- Fixing findings from design review where review report describes older version of design

Action:
- Read current file state first. Compare against review report's description of problem. Apply fixes only for issues still existing in current files. Don't blindly apply all review recommendations without verifying current state.

## Improvement: Re-review corrected designs for new scope drift

Condition:
- Re-reviewing design edited to close earlier architecture blockers

Action:
- Verify each correction is implementable from documented data model and does not pull deferred-stage behavior into current stage without required safety contract. Don't limit re-review to confirming old finding text disappeared.

## Improvement: Narrow re-reviews still update navigation state

Condition:
- Task asks for focused re-review of one prior finding and also says to update `document-index.md` only if materially needed

Action:
- Keep review finding scope narrow, but still update entry-doc contents, current gate text, stage-gate text, and any index row that would otherwise describe old review state. Don't leave stale REWORK, awaiting-review, or correction-drafted wording in durable navigation docs after PASS re-review.

## Improvement: One-gate stage design authoring

Condition:
- Task asks to advance exactly one architecture gate by creating new stage design deliverable

Action:
- Mark authored design as ready for independent review while leaving design review, manager gate, implementation planning, implementation, and QA gates unstarted. Don't use new design document to approve later gates or imply implementation authorization.

## Improvement: Operational stage design keeps architecture scope verbatim

Condition:
- Authoring stage design for stage whose architecture scope, deliverables, and exit criteria are fixed and stage is operational (upstream merge, stress validation, security review, benchmarking) rather than feature

Action:
- Keep architecture scope, deliverables, and exit criteria as design baseline. Write design around operational contract (preconditions, command family, evidence shape, rework workflow, log format) instead of redefining what stage produces. Don't invent new deliverables, new exit criteria, or new scope items. Don't split single architecture scope block into narrower design scope items. Don't relax architecture exit criterion even if test plan or evidence scope cannot meet it at first attempt.

## Improvement: Multi-payload implementation reviews

Condition:
- Reviewing implementation adding second payload kind, descriptor reference, or residency path to existing cache entry or branch node

Action:
- Trace admission, restore selection, pre-restore residency filtering, byte accounting, eviction, demotion, promotion, cleanup, metrics, and tests for each payload kind separately and together. Verify cold or transient descriptors can still reach intended promotion, fallback, or rejection path instead of being filtered out as absent. Don't accept aggregate entry-level accounting or debug-only coverage as proof all payload kinds participate in production lifecycle.

## Improvement: Plan-review code-snippet type and format check

Condition:
- Reviewing implementation plan whose cpp snippets use std::min, SRV_DBG, LLAMA_LOG, or any printf-style macro; plan claims snippet "compiles" or is "implementable" without naming field types at assignment site

Action:
- Look up field types in actual header (common/common.h for common_params, include/llama.h for llama_context_params, common/speculative.h for common_speculative_n_max return type). Check whether std::min return type matches LHS field type without implicit narrowing. Check SRV_DBG/LLAMA_LOG format specifier against argument type (int32_t wants %d, uint32_t wants %u, size_t wants %zu). Flag non-blocker when snippet compiles with warning or format is wrong. Don't accept "compiles" as proof of snippet correctness without type check.

## Improvement: PASS with residual evidence limits

Condition:
- Implementation re-review has focused substitute evidence for design requirement but still lacks model-backed, public HTTP, or live Prometheus evidence requested for later QA closure

Action:
- Decide implementation gate from approved code contract and available substitute evidence. Carry missing runtime evidence as explicit QA risk or next-owner item when not required to prove code correctness. Don't keep REWORK verdict solely because QA still needs fixture-backed confirmation.

## Improvement: Public exporter shape in observability reviews

Condition:
- Reviewing implementation evidence claiming metrics are complete through direct stats, JSON `get_stats()` rows, or focused controller tests; approved design requires public Prometheus or operator-visible metrics

Action:
- Trace each claimed metric dimension through public exporter and focused exporter tests. Flag blocker when controller records required bounded labels but public Prometheus row drops or renames them. Don't accept direct stats as proof of public observability unless approved evidence plan classifies that value as internal-only.

## Improvement: New review files on Windows have CRLF trailing whitespace

Condition:
- Creating new review part file (or any markdown under `._design_docs/`) on Windows using `create_file` or similar tool not normalizing line endings; file to be checked by `git diff --check` before commit

Action:
- Convert file to LF-only line endings immediately after creation. Count raw CR/LF/size and read first three bytes to confirm LF-only and no UTF-8 BOM. Run `git diff --check` on new file path. Don't trust tool's default line endings; `create_file` on Windows frequently writes CRLF. Don't fix with `Set-Content` and `-NoNewline`; that collapses file to single line. Use `[System.IO.File]::ReadAllText` followed by `-replace "\r\n", "\n"` and `WriteAllText` with `UTF8Encoding($false)`. Don't claim `git diff --check` is clean without re-running on converted file.

## Improvement: Closure sweep keeps durable docs aligned without re-running the report

Condition:
- Manager has closed stage with documented reclassifications, BLOCKED items, or follow-up tasks; task is to apply closure to durable design and implementation docs (entry doc, document index) rather than rewrite test report

Action:
- Update entry-doc top-level Status line, current-gate paragraph, and stage-gate section to describe closed-with-limitations state. Link executed test report, fixes handoff, and developer review from entry doc. List follow-up tasks as setup/evidence requirements rather than accepted skips. Update document-index.md rows to reflect executed test report and closure decision. Don't modify test report body, evidence sections, or test plan to record specific outcome. Don't add closure section to one-time manager gate handoff doc. When Manager explicitly authorizes closure, change top-level Verdict line in final test report from FAIL to PASS. Don't drift into rewriting evidence narratives or removing prior failure-section headings that are accurate historical records.

## Improvement: Closure sweep preserves historical failure headings

Condition:
- Closure sweep updates stage implementation log containing prior bug-fix loop or failed-attempt section headings dated earlier than closure date

Action:
- Keep prior failure headings as-is when body still accurately documents earlier state. Update only most recent bug-fix loop heading that closure actually closes. Add new dated closure section after loop that met contracts. Don't rewrite or remove historical failure headings to make document look like stage closed cleanly first time. Don't rephrase prior closure-attempt headings to claim success when user rejected them.

## Improvement: Triage per-area breakdown label vs unique INTEGRATE count

Condition:
- Reviewing pre-merge or triage report listing per-prior-stage-area breakdown with counts and label like "by INTEGRATE count" or "by decision"; task brief asks whether per-area counts sum to unique INTEGRATE or unique decision count

Action:
- Verify whether breakdown is per-commit count with overlap (single commit can touch multiple areas; NO-OP commits can appear alongside INTEGRATE commits in same area) vs unique-decision count. Accept underlying data as correct when design rule is "touched by at least one commit" and per-area list is internally consistent. Record mislabel as non-blocking observation with suggested label rename, not blocking finding. Verify unique INTEGRATE count separately in INTEGRATE breakdown list, not by summing per-area counts. Don't reject report on label alone when underlying count is correct and design's aggregation rule is satisfied.

## Improvement: Verify test-report counts before applying closure text

Condition:
- Applying closure sweep to durable design or implementation docs based on test report; or reviewing Manager closure decision that reclassifies FAIL or BLOCKED rows before bug-fix loop is complete

Action:
- Check test report's final PASS, FAIL, BLOCKED, and SKIP counts and test plan's closure contracts (e.g., 80% hybrid-path coverage rule, rules against recording missing coverage or benchmark evidence as accepted skips) before applying closure-claim text to durable docs. If any row is FAIL or plan forbids reclassifying missing evidence as accepted, refuse to apply closure-claim text, flag closure as premature, and link test report evidence without claiming stage is closed. Keep test report discoverable, link from entry doc and document index, record real final counts. Don't apply closure-claim text just because test report exists. Don't rely on reclassification converting FAIL into BLOCKED-with-evidence to make closure contract disappear.

## Improvement: Cross-cutting stage planning notes

Condition:
- Extending multi-stage architecture or delivery plan by adding new stage addressing cross-cutting concern (upstream merge integration, stress/benchmark validation, security review, etc.) rather than new feature; implementation-notes section does not yet mention how new stage relates to prior stages

Action:
- Add short note in implementation-notes section naming cross-cutting concern, pointing to new stage number, explaining why it can revisit or invalidate prior stages. Don't invent new entry-doc files for cross-cutting stages when they fit naturally in same planning part file. Verify file stays under 300-line split rule after addition.

## Improvement: Plan-level risk additions match design risk table style

Condition:
- Reviewing implementation plan whose evidence-or-risks section adds risks beyond design's risk table; design uses single-column "Mitigation" or "Mitigation before approval" format rather than separate "Mitigation" and "Residual risk" columns

Action:
- Verify each new plan-level risk carries concrete trigger, impact, and mitigation. Accept single-column style as residual-outcome-embedded when it matches design's table. Flag missing trigger, impact, or mitigation on new risk as blocking plan gap. Record style observation as non-blocking note. Don't require plan to split column when design does not. Don't invent residual-risk language design never used.

## Improvement: Closure doc sweep part-file split and CRLF normalization

Condition:
- Closure doc sweep adds substantial closure section, follow-up plan, tooling limitation addendum, and evidence-pointer list to stage entry doc and test-plan part file without those sections previously

Action:
- Write full closure record in new `part-XX-stageN-closure.md` from start; put short pointer in entry doc. Write test-plan tooling limitation addendum in new `part-XX-tNNN-tooling-limitation.md`; put short pointer in parent test-plan part. Trim closure-status or T114a-lift-attempt narrative in merge log to short pointer referencing entry-doc closure part.
- Convert every modified or new file to LF-only UTF-8 (no BOM) with `UTF8Encoding($false)`. Verify with `[regex]::Matches($string, [char]13).Count -eq 0` and `[System.BitConverter]::ToString($bytes[0..2])` for BOM check before running `git diff --check`. Don't author closure section inline in entry doc. Don't leave CRLF line endings on Windows-created markdown files. Don't rely on `[regex]::Matches($string, '`n')` for line-ending counts; that token in PowerShell single quotes is literal backtick-n and returns zero matches.

## Improvement: Pre-commit `git diff --check --cached` on every doc sweep

Condition:
- Doc sweep scope includes committing untracked test report files or other durable docs authored by other agents on Windows, and worktree author is same Windows host

Action:
- Run `git diff --check --cached` on staged set before commit, not just on worktree diff. Convert any staged file with CRLF to LF-only via `[System.IO.File]::ReadAllText` then `-replace "\`r\`n", "\`n"` and `WriteAllText` with `UTF8Encoding($false)`. Re-run `git diff --check --cached` after conversion. Don't trust untracked file authored by another agent on Windows is LF-only or whitespace-clean. Don't add trailing space in markdown blockquote separator like `> ` - use `>` alone with no trailing space.

## Improvement: Document-index row column-count check

Condition:
- Replacing row in `document-index.md` (or any markdown table) and user-supplied row text does not match table's column count, or prior row text already had column-count mismatch

Action:
- Count columns in new row text against table header (split on unescaped `|` with surrounding whitespace stripped) before applying. If new row has fewer columns than header, add missing `Useful for` (or equivalent) column with one-line description rather than leaving row short. Record column-count fix in post-task improvement rather than as blocking finding. Don't reject user-supplied text on column count alone. Don't add filler text to description column to reach header count.

## Improvement: Speculative decode sizing rule needs call-site flow trace

Condition:
- Reviewing speculative decode-batch sizing rule (chunked-decode, cap-bump, or per-call bound) claiming specific per-call token bound for draft context (e.g., MTP draft, non-MTP draft); design rationale cites formula like `1 + n_max` or `n_parallel * (1 + n_max)` as per-call bound

Action:
- Trace actual call site flow: target `llama_decode` in chunked loop, then `common_speculative_process(spec, batch_view)`, then draft `llama_decode` in `common/speculative.cpp`. Verify draft per-call `batch.n_tokens` is same `batch_view` target just decoded (chunked-loop chunk size, not separate formula). Record non-blocking finding when design's stated per-call bound holds only for `n_parallel = 1` but not `n_parallel > 1`. Verify cap-bump formula includes `min(n_batch, ...)` clamp that target `server_n_outputs_max` applies at `tools/server/server-context.cpp:204`. Don't accept "symmetric formula" wording without checking clamp is present.

## Improvement: Per-context cap vs per-sequence cap ambiguity in chunked-decode rules

Condition:
- Reviewing design or architecture part specifying chunked-decode bound as `min(n_batch, cparams.n_outputs_max / n_parallel)` or "equivalent per-sequence cap," and actual chunked loop chunks whole batch (not per-sequence)

Action:
- Verify whether cap is per-context (`n_outputs_max <= cparams.n_outputs_max` assertion at `src/llama-context.cpp:2152` checks per-context total) or per-sequence. Correct per-chunk bound is `min(n_batch, cparams.n_outputs_max)` (per-context cap). Per-sequence share `cparams.n_outputs_max / n_parallel` is implicit in per-context bound. Record non-blocking finding when design "per-sequence cap" wording could be misread as different chunking rule. Don't accept per-sequence wording as equivalent to per-context bound without checking loop actual behavior.

## Improvement: Verdict line at top overrides MD041 linter warning

Condition:
- Task instruction explicitly requires "VERDICT: PASS" or "VERDICT: REWORK" line at top of review file (plain ASCII, no emoji), and Markdown linter reports MD041/first-line-heading because verdict line is not heading

Action:
- Place verdict line at very top of file as first line, before title heading and all sections; task instruction takes precedence over linter warning. Expect linter warning as expected behavior, not defect. Don't restructure file to put heading first just to satisfy linter; that buries verdict and violates task contract.