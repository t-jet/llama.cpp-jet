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
- Check live entry docs, active fix reports, correction-evidence status lines, correction part handoff sections, downstream design handoff sections, `document-index.md` summaries, top-level Status lines, current-status sections, handoff text, and linked gate-status part files before and after patching. Distinguish historical quoted findings from current contradictions. Keep durable gate-status locations in same state: reviewable, rework-required, manager-gate-ready, planning-open, approval-pending, approved, ready-for-QA, bug-fix-review-pass, implementation-re-review-pass, or blocked. Don't leave stale limitation, review-pending, awaiting-review, re-review-ready, handoff-closed, ready-for-review, ready-for-implementation, ready-for-re-review, or not-started wording after gate has advanced or while open finding remains.

## Improvement: Misconfigured-probe diagnosis vs product bug

Condition:
- Writing architectural fix instructions for BLOCKED fixture-dependent row (e.g., public /metrics row showed zero) where fixture is capable but probe was misconfigured

Action:
- Trace probe start command against design-required flags (cache-mode, spec-type, cache-ram, etc.) and server stdout/stderr to confirm misconfiguration vs product bug. Specify corrected start command with exact flag names from parser source (e.g., common_speculative_type_to_str values). Include focused-substitute evidence path with specific test function names and assertion points covering public-row check via get_stats() or focused exporter tests, so Developer can fix probe or fall back to substitute evidence. Don't leave row in generic BLOCKED state without corrected start command or substitute evidence citation.

## Improvement: Changed paths for untracked review docs

Condition:
- Adding or updating review part files in doc tree that is untracked or only partly tracked by git

Action:
- Track paths edited during task. Patch new review files, entry docs, and index rows as separate steps when tree is dirty or untracked. Verify contents directly with targeted reads, `rg`, line counts, and raw byte checks when `git diff` cannot show untracked file content. Separate task-local edits from pre-existing dirty paths. Report task-local path list. Don't rely on `git diff` or `git status` alone to prove what changed. Before declaring referenced doc "not edited" or "not touched", run `git status -- <path>` and read current contents to confirm pre-existing uncommitted changes; report as pre-existing rather than own work.

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

## Improvement: Latest follow-up state before stage baseline PASS

Condition:
- Reviewing a new stage design that names a prior stage as CLOSED, while the prior implementation tree has later follow-up parts, partial reports, or Manager closure records after the cited closure commit

Action:
- Read latest follow-up parts and test reports, then decide whether they are terminal, open, or unrelated before passing the prerequisite. Flag stale baseline as blocking when the new stage covers behavior changed or still pending in the follow-up. Don't rely on the original closure commit alone when newer durable records exist.

## Improvement: Per-context cap vs per-sequence cap ambiguity in chunked-decode rules

Condition:
- Reviewing design or architecture part specifying chunked-decode bound as `min(n_batch, cparams.n_outputs_max / n_parallel)` or "equivalent per-sequence cap," and actual chunked loop chunks whole batch (not per-sequence)

Action:
- Verify whether cap is per-context (`n_outputs_max <= cparams.n_outputs_max` assertion at `src/llama-context.cpp:2152` checks per-context total) or per-sequence. Correct per-chunk bound is `min(n_batch, cparams.n_outputs_max)` (per-context cap). Per-sequence share `cparams.n_outputs_max / n_parallel` is implicit in per-context bound. Record non-blocking finding when design "per-sequence cap" wording could be misread as different chunking rule. Don't accept per-sequence wording as equivalent to per-context bound without checking loop actual behavior.

## Improvement: B01 exact-blob threshold vs non-destructive hybrid cache

Condition:
- Reviewing B01 (S12-B01) exact-blob hit-rate bench FAIL where QA says k6 threshold `rate>=0.60` is unattainable for a probe shorter than the warmed slot, hybrid cache reports LCP f_keep < 0.5, timings.cache_n stays 0, and the k6 metric is wired to timings.cache_n > 0 boolean

Action:
- Confirm the test framework false-positive by reading k6-results.json (cache_hit_rate value lines), server.err.log (look for "try_restore - no exact match found" + "prefix X of Y" + graph_reused monotonic counter), and bench-cache-correctness.js (threshold definition is hard-coded `rate>=0.60` against `body.timings.cache_n`). Don't open a product bug-fix loop. Recommend re-classify to BLOCKED-test-framework-threshold-incompatible and ask Dev to lower threshold or add prefix_match_rate metric. Cite graph_reused counter as the meaningful hybrid-cache correctness signal when timings.cache_n stays 0. Don't accept "k6 threshold 0.60" as a product gate when non-destructive hybrid restore is the primary path.

## Improvement: B02 driver MtpVariant not honored

Condition:
- Reviewing B02 (S12-B02) checkpoint hit-rate bench FAIL where driver declares `[int] $MtpVariant = 0` but only consumes it via `Resolve-MtpJinjaPath`, never switches fixtures, never adds `--spec-type draft-mtp`, and server log shows "common_speculative_init: no implementations specified for speculative decoding"

Action:
- Confirm the driver bug with targeted grep over the bench ps1 for `MtpVariant` (should return 2 hits: param decl + Resolve-MtpJinjaPath only, no fixture branch). Recommend re-classify to BLOCKED-driver-bug and ask Dev to add `if ($MtpVariant -eq 1) { $LargerModel = ...Qwen3.5-4B-MTP...; $flags += @('--spec-type','draft-mtp') }` plus remove `--model-draft` for V1 path. Don't classify as product bug; cache works (14-token restore + hits) but on V2 fixtures. Cite part-21a sec 4 "per-driver variant logic is not permitted" and part-19 sec 7.1 inventory gap.

## Improvement: Verdict line at top overrides MD041 linter warning

Condition:
- Task instruction explicitly requires "VERDICT: PASS" or "VERDICT: REWORK" line at top of review file (plain ASCII, no emoji), and Markdown linter reports MD041/first-line-heading because verdict line is not heading

Action:
- Place verdict line at very top of file as first line, before title heading and all sections; task instruction takes precedence over linter warning. Expect linter warning as expected behavior, not defect. Don't restructure file to put heading first just to satisfy linter; that buries verdict and violates task contract.

## Improvement: Closure sweep instruction references missing index row

Condition:
- Manager or user closure sweep task instructs updating a specific row in `document-index.md` for a phase entry doc (implementation or design), but the row does not exist in the implementation or design table

Action:
- Verify the row exists with a targeted search (`Select-String` or `Get-Content` line scan) before applying the append. If the row is missing, do not silently invent a new row from template; do not silently skip the index update. Do the appends on the entry docs that do exist, update the rows that do exist, and flag the missing row in the handoff so Manager or follow-up agent can author the index row separately. Verify the pattern in nearby rows (column count, cell content scope, description style) so the follow-up author has concrete template. Don't claim all instructed edits are complete when one of the cells is missing its row.


## Improvement: Stage-12/13 contract growth pushes part-06 over 300 lines

Condition:
- Authoring Stage 14 design (or any later operational stage) that mirrors the Stage 11 part-06 structure (merge log + constraints + observability + testability + risks + exclusions + traceability + handoff) and adds Stage 12/13 contract rows to the constraints and traceability tables

Action:
- Plan part-06 split up front: keep merge log + constraints + observability + testability + risks in part-06, move exclusions + traceability + handoff to a part-06a overflow file, and link part-06a from part-06 and the entry-doc contents list. The Stage 11 part-06 was 207 lines; adding Stage 12 (stress S01..S08, L01..L03, B01..B08, config matrix, public metric shape) and Stage 13 (E13-01..E13-16, MTMD placeholder, diagnostic-source namespace isolation, bounded cache metadata: format, transcript route coverage, embedding cache exclusion) contract rows pushes part-06 to ~325 lines, over the 300-line cap. Verify with Get-Content | Measure-Object -Line after writing and split immediately when the count exceeds 300. Don't try to trim the constraint or traceability table to fit; the new contracts are mandatory and the cap is a hard rule.

## Improvement: Cycle-scoped test reports under .test_reports/ and the 300-line split rule

Condition:
- Reviewing a cycle-scoped artifact (pre-merge report, merge log, test report) under `._design_docs/.test_reports/` that exceeds the 300-line cap

Action:
- Record file size as non-blocking N-class observation with two options: (a) document an exception in the implementation entry doc "Contents" section for cycle-scoped reports under `.test_reports/`, citing Stage 11 precedent (upstream-merge-guide Part 1 procedure-at-a-glance and Stage 11 plan), or (b) split the report into a main file (cover, verification, decision records, handoff) plus a part file (commit range, top-N subjects, range composition, triage table, open questions). Recommend option (a) for cycle-scoped reports anchored to a specific cycle date (`pre-merge-report-YYYYMMDD-NN.md`, `test-report-YYYYMMDD-NN.md`); recommend option (b) only when the Manager prefers strict adherence. Don't flag as blocking finding; the index rule's split mandate applies primarily to durable design docs, and the pre-merge report is a one-shot artifact that will not be referenced after the cycle closes. Verify line count with `(Get-Content).Count` or raw LF byte count, not just `Measure-Object -Line`, and convert new file to LF-only UTF-8 (no BOM) before running `git diff --check`. Don't accept the cycle report as "too long to review" or "split later"; surface the rule and the two-option recommendation in the review's Required corrections or Handoff section.

## Improvement: Architecture deliverable bullet vs design named-callout

Condition:
- Reviewing operational stage design (upstream merge, stress validation, etc.) where architecture lists a specific deliverable or test-coverage bullet by name (e.g., "semantic-duplicate and divergent-fix-path handling", "CUDA fallback behavior under stress") and the design implements the bullet only by reference to a procedure document (e.g., upstream-merge-guide Part 2) rather than naming the bullet in the design section

Action:
- Verify each architecture bullet is named in the corresponding design section, not only referenced. Record as non-blocking observation with concrete section reference when the design's procedural consistency holds (it points to the right guide section) but the design does not call the architecture bullet by name. Recommend explicit naming for traceability. Don't flag as blocking when the underlying procedure is correct and the design's reference resolves to the named bullet's section in the referenced document. Verify architecture bullet is satisfied before recording PASS.

## Improvement: General-rule "apply consistently" beyond listed line numbers

Condition:
- Manager decision revises a procedure or guide to add a path alternative to the documented primary path (e.g., add a direct remote-tracking ref alternative to a local tracking branch), and the task lists explicit line-level changes plus a general rule to "apply consistently" or "wherever the guide says..."

Action:
- After applying the listed line changes, scan each modified file with `Select-String` for the same construct (variable name, paragraph phrase, or table column) and apply the same alternative-wording rule to the remaining sites the explicit list did not name. The general rule's "consistently" wording covers more sites than the explicit change list. Don't stop at the listed lines and leave inconsistent references in the same file. Confirm with a final pass that the construct appears only in forms that name both the primary and the alternative, or only in a sub-section dedicated to the primary path with a parallel sub-section for the alternative. Update `document-index.md` only if a part file's name, role, or split changes.

## Improvement: Post-review Manager decision revision

Condition:
- Manager revises a recorded design decision (D1, D2, etc.) after the design review doc for the stage has already closed and recorded the original decision as accepted

Action:
- Update the design review doc finding rows and checklist items that reference the revised decision with the revision date, the new decision wording summary, and a pointer to where the new text lives (entry doc Manager decisions section, part-XX Upstream reference strategy section, or equivalent). Mark the row as ACCEPT (post-revision) rather than re-running the design review. Apply the same wording change to every other part file and entry doc that quotes the old decision so a single search for the old phrasing returns no remaining hits. Don't fold the revision into a follow-up Manager gate or implementation plan step. Don't re-open the design review gate. Don't leave the design review reading as if the original decision is still in force.



## Improvement: Plan-review bare upstream ref vs explicit remote-tracking ref

Condition:
- Reviewing implementation plan whose Manager decision selects a direct remote-tracking ref (e.g., `origin/upstream_master`) over a local tracking branch (e.g., `upstream_master`), and the plan uses the bare ref name in conceptual or procedure-rule sections while the explicit remote-tracking ref name is used at all decision points and verification commands

Action:
- Flag the bare ref name in conceptual references and procedure rules (e.g., commit range rule, decision D7 reasoning) as a non-blocking observation, not a blocking finding. The bare form is a conceptual reference, not a stale "local tracking branch" instruction, but in the explicit-ref context it could be misread as the old local branch. Record as N-class finding with concrete line numbers and suggested wording. Don't flag as blocking when all decision points and verification commands use the explicit ref name consistently. Verify by scanning each modified file with `Select-String` for both the bare and the explicit form, and confirm the explicit form appears at every decision and verification site.

## Improvement: Plan-review resolved-decision in open-decision range

Condition:
- Reviewing implementation plan whose Step activity names a range of Manager decisions to surface (e.g., "D4-D11"), and one of the decisions in the range is already RESOLVED in the same plan's Manager decisions log

Action:
- Flag the inclusion of a resolved decision in a still-open range as a non-blocking observation (N-class), not a blocking finding. The plan material is correct on the resolution status; the wording is the only issue. Record the line number, the resolved decision, and suggested wording (e.g., "D5-D11" instead of "D4-D11" when D4 is RESOLVED). Don't flag as blocking when the plan's Manager decisions log already records the correct RESOLVED status for that decision. Don't require the plan to remove the resolved decision from the activity list entirely; the activity can still name the decision for traceability as long as the wording marks it resolved.

## Improvement: PowerShell line count undercount on multi-line markdown

Condition:
- Verifying file line counts for the 300-line split rule on Windows using `Get-Content | Measure-Object -Line`, and the reported count is lower than the actual line count (e.g., reports 230 for a 286-line file)

Action:
- Use `(Get-Content $file).Count` or `(Get-Content -Raw $file).Split([char]10).Count` to get the authoritative line count. Confirm with raw byte LF count via `[System.IO.File]::ReadAllBytes` and `foreach` over bytes checking for `0x0A`. `Measure-Object -Line` can undercount on multi-line markdown with trailing newlines, embedded blank lines, or specific encoding handling. Don't trust the `Measure-Object` count alone when the file is near the 300-line cap. Re-run line count verification after any conversion or normalization step.


## Improvement: Recurring part-file link across entry-doc sections

Condition:
- Adding a new Contents-section link for a part file in a test-plan or design entry doc, and the same part number or link text also appears in another section of the same doc (e.g., a Finding current implementation status block that lists the same part files)

Action:
- Run grep_search for the part line before editing and treat multi-match as expected. When inserting a new link into the Contents section, include a neighboring ## section header in the oldString to scope the match. Do not replace a part line in both sections at once; the non-Contents section is a stage-anchored pointer and should keep its own list. Verify the new link appears in the Contents section and that the other section's line is unchanged.

## Improvement: Plan-supplied relative paths vs source-file location

Condition:
- Executing a user-supplied plan that authors or extends a document at a known repo path (e.g., root `README.md`, a part file under `._design_docs/`) and the plan text contains explicit relative Markdown links or filesystem paths to other files

Action:
- Before committing, verify each relative path resolves from the source file's actual location. For a root-level README, sibling paths use `./<dir>/<file>` (with the leading dot for `._design_docs/`, `._test_output/`, `.agents/`). For a file inside `._design_docs/cache-handling-architecture/`, sibling paths use `../<sibling-dir>/<file>`. A `../` in a root-level file points outside the repo. When a path in the plan is wrong, correct it during the edit, record the correction in the post-task return summary, and don't reject the plan outright. Verify with `Test-Path` from the source file's parent directory.

## Improvement: Pre-existing UTF-8 characterization before "preserve" claim

Condition:
- Task or plan says "the existing file may have UTF-8 characters; preserve them" or similar, and the constraint names a specific character (e.g., em dash) without enumerating what is actually present

Action:
- Scan the source file's raw bytes for the named UTF-8 pattern plus adjacent patterns (em dash `E2 80 94`, en dash `E2 80 93`, BOM `EF BB BF`, emoji) before editing, and report the actual character set in the return summary. Plan text often names em dash as a guess when the file actually has en dashes or emoji. Count with `[System.IO.File]::ReadAllBytes` and a `for` loop over byte triplets, or use a regex against the decoded string with `[char]0x2013`, `[char]0x2014`, `[char]0xFE0F`. Apply the new section as plain ASCII regardless of which UTF-8 form is present in the existing file.
