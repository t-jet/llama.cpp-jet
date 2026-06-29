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

## Improvement: Coverage denominator vs XML root rate

Condition:

- T114 verdict cites Cobertura XML root `line-rate` as combined rate for filtered denominator

Action:

- Do verify cited rate from script's filtered-denominator output (combined result row in coverage report), not XML root. Don't open bug-fix loop based on rate from wrong denominator. XML root covers all tracked files, almost always lower than filtered-denominator rate. Do estimate true rate from per-file table before deciding.

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

- Do check live entry docs, active fix reports, correction-evidence status lines, correction part handoff sections, downstream design handoff, index summaries, top-level Status lines, current-status sections, handoff text, and linked gate-status part files before and after patching. Do distinguish historical quoted findings from current contradictions. Do keep durable gate-status locations in same state: reviewable, rework-required, manager-gate-ready, planning-open, approval-pending, approved, ready-for-QA, bug-fix-review-pass, implementation-re-review-pass, or blocked. Don't leave stale limitation, review-pending, awaiting-review, re-review-ready, handoff-closed, ready-for-review, ready-for-implementation, ready-for-re-review, or not-started wording after gate advances or while finding remains. Do grep `git diff` output and the patched file content for stale-status phrases inside IF/ELSE contingency branches that the patch did not touch; an unchanged contingency branch can still hide a stale phrase. Do prefix retained contingency branches with an explicit `Historical outcome (<date>): ...` label that names the actual path taken when only one branch applied. Don't rely on a single status-line edit to clear all stale wording in a part file.

## Improvement: Contingency-branch stale wording hides after status-line fix

Condition:

- Closure sweep updates top-level Status line, handoff text, and gate sections but leaves IF/ELSE contingency-branch text in the same part file with stale wording (e.g., `D-EXEC-24-03 status: OPEN` inside an `if V4 shows the crash still reproduces` branch even after V4 actually PASSED)

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

- Do track paths edited during task. Do verify contents directly with targeted reads, ripgrep, line counts, raw byte checks when `git diff` cannot show untracked content. For new untracked durable docs, run a separate whitespace check such as `git diff --check --no-index` against an empty temp file and interpret no output as clean even though no-index exits 1 for content differences. Do separate task-local edits from pre-existing dirty paths and from older diffs inside the same index or tracker file before reporting. Do report task-local path list. Don't rely on `git diff` or `git status` alone to prove what changed. Before declaring referenced doc "not edited", do run `git status -- <path>` and read current contents; report as pre-existing rather than own work.

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

- Do verify each format claim with byte-level check (`[System.IO.File]::ReadAllBytes` + `0x0D` membership, BOM check, unicode scan) regardless of what the subject's own text says. Don't trust the subject's self-description; on Windows, `create_file` and `Set-Content` insert CRLF even when the author writes `\n` mentally and the file text claims "LF line endings". Do compare against a sibling durable doc in the same directory as a sanity reference (e.g., parent test report should be LF-only; if fixes file has CR=True and parent has CR=False, the deviation is real). Do flag as BLOCKING when a user-listed checklist item like "LF-only" is violated, even if the underlying code change is correct; documentation hygiene is a gate per Stage 15+ governance. Do record format-property violations as separate findings from code-correctness findings so re-review can fix just the doc.

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

- Do verify production save, restore, eviction, metrics, or lifecycle path actually invokes behavior. Don't accept debug-only coverage as proof. Do flag blocker when tests only exercise debug hooks or standalone APIs for contract approved design assigns to production flow.

## Improvement: Skill path fallback

Condition:

- Required repo skill listed in session but first documented skill path cannot be read

Action:

- Do check repo-local `.agents/skills/<skill>/SKILL.md` path before falling back to ad hoc behavior. Do record path issue only briefly.

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

## Improvement: Plan-review metric count drift vs design table

Condition:

- Reviewing implementation plan whose evidence section or metric-list summary states a count (e.g., "12 per-leg Prometheus counter deltas (4 general + 8 hybrid-only)") that differs from the design's table (e.g., 13 deltas: 3 general + 10 hybrid-only)

Action:

- Do row-count the design's metric table to confirm the actual count. Do record off-by-one as non-blocking INFO observation with concrete line refs in both plan and design. Do not block sign-off because the implementation session will scrape whatever counter set the metrics endpoint actually emits; the count discrepancy is documentation quality, not implementation blocker. Do note when the same off-by-one wording repeats across multiple plan files (entry doc, part-01b, part-03) so the implementation session can correct all instances. Do not require the plan to pre-resolve the count; the implementation session observes the live counter set.

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

## Improvement: Cross-cutting stage planning notes

Condition:

- Extending multi-stage architecture or delivery plan by adding new stage addressing cross-cutting concern (upstream merge integration, stress validation, security review) rather than new feature; implementation-notes section does not yet mention how new stage relates to prior stages

Action:

- Do add short note in implementation-notes section naming cross-cutting concern, pointing to new stage number, explaining why it can revisit or invalidate prior stages. Don't invent new entry-doc files for cross-cutting stages when they fit naturally in same planning part file. Do verify file stays under 300-line split rule after addition.

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

## Improvement: Authoring review-file tables with long cells

Condition:

- Authoring implementation review or design review file with markdown tables; one cell has a long string (multi-clause sentence with backticks and code references) and other rows are short

Action:

- Do count pipes in every row before writing the file, not just header. Do treat long cell content as reason to move that content out of the table and into a follow-up paragraph or sub-section, keeping the table cell short (one line, one finding). Don't let one row's cell-content length cause you to forget the closing pipe. Don't add padding rows to balance column count; do fix the row itself. Do verify with a pipe count test (e.g., `$line.ToCharArray() | Where-Object { $_ -eq '|' } | Measure-Object -Count`) on each row before declaring the file done. Do expect MD056 linter warning as a real defect, not a false positive, and fix the cell or move the long content. Do distinguish MD041 (verdict-line first, expected per task contract) from MD056 (real column-count defect that must be fixed).

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

## Improvement: Verdict line at top overrides MD041 linter warning

Condition:

- Task instruction explicitly requires "VERDICT: PASS" or "VERDICT: REWORK" line at top of review file (plain ASCII, no emoji), and Markdown linter reports MD041/first-line-heading because verdict line is not heading

Action:

- Do place verdict line at very top of file as first line, before title heading and all sections; task instruction takes precedence over linter warning. Do expect linter warning as expected behavior, not defect. Don't restructure file to put heading first just to satisfy linter; that buries verdict and violates task contract.

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

- Do record file size as non-blocking N-class observation with two options: (a) document exception in implementation entry doc "Contents" section for cycle-scoped reports, citing earlier-stage precedent, or (b) split report into main file plus part file. Do recommend option (a) for cycle-scoped reports anchored to specific cycle date; recommend option (b) only when Manager prefers strict adherence. Don't flag as blocking finding; index rule's split mandate applies primarily to durable design docs, and pre-merge report is one-shot artifact. Do verify line count with raw LF byte count, not just `Measure-Object -Line`, and convert new file to LF-only UTF-8 (no BOM) before running `git diff --check`. Don't accept cycle report as "too long to review" or "split later"; surface rule and two-option recommendation in review's Required corrections or Handoff section.

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

## Improvement: Brief R-item wording imprecision vs actual code behavior in bug-fix review

Condition:

- Reviewing bug-fix against brief with specific R-items, and R-item uses slightly imprecise wording that conflates related but distinct cases (e.g., brief says "fallback path taken when no boundary ends at target" but code only takes fallback when NO boundaries at all, not when boundaries exist but none end at target)

Action:

- Do verify each R-item claim against actual code in touched file, not just brief's interpretation. Do distinguish overall claim from specific code behavior claim. Do read touched function's if/else branches to confirm which case triggers which behavior. Do record wording imprecision as INFO, not BLOCKING, when overall claim holds but specific code behavior narrower than brief describes. Don't reject fix on wording imprecision alone. Don't accept R-item as PASS without checking actual code path.

## Improvement: Post-closure follow-up design review scope and dual-doc traceability

Condition:
- Reviewing a post-closure follow-up design correction (not full stage re-review) where correction introduces both a new design part (stage-scoped) and a new architecture-level invariant (cross-stage); task brief says review correction only

Action:
- Do write review verdict in new part file under the new stage's design directory (e.g., cache-handling-phaseN-design/part-01-design-review-gate-01.md), not in the closed stage's part file. Do follow upstream-merge-guide part-04 section 5 step 2 placement. Do explicitly state scope rule in review file (correction only, not full closed-stage re-review). Do list the 10+ files reviewed in a scope table.
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

- Reviewing an implementation whose implementation evidence (e.g., part-04) explicitly lists deferred or partial items, and the plan accepts those deferrals as the stage contract for the implementation-review gate

Action:

- Do verify each deferred item is recorded in the implementation evidence and that the design baseline does not require it for this gate. Do record checklist verdict as DEFERRED-ACCEPTABLE when deferral is contract-accepted, not BLOCKING. Do note the manager decision or design exclusion that authorizes the deferral. Don't re-surface implementor-recorded deferrals as new blocking findings when the contract already accepts them. Don't fold deferral evaluation into the main PASS/FAIL verdict; carry it as a separate per-row verdict and a short overall note.

## Improvement: MD040 and MD024 in multi-item design docs

Condition:

- Authoring stage design that contains multiple items (e.g., two distinct fix items) where each item has its own "Context" or "Behavior change analysis" subsection, and design includes code snippets

Action:

- Do add language tag to every fenced code block (for example cpp for C++ snippets, powershell for PowerShell, text for plain). Do disambiguate repeated subsection titles across items with item-specific qualifiers (for example Item 1: Context vs Item 2: Coverage build context; Item 1: Behavior change analysis vs Item 2: Coverage-build behavior change analysis). Do run markdown linter after writing to catch MD040/MD024 before finalizing. Don't use bare fences; linter reports MD040. Don't reuse exact H3 heading text across items; linter reports MD024.

## Improvement: Stage-17 follow-up line numbers drift from earlier review

Condition:

- Authoring follow-up design for a closed stage where an earlier-stage review (e.g., bug-fix review part) cited specific line numbers for a code artifact, and the artifact has been edited or shifted since the review

Action:

- Do verify the actual current line numbers with Select-String or read_file before specifying the deletion or modification scope in the new design. Do cite both the older review's quoted line range (as historical reference) and the verified current line range. Don't copy line numbers from earlier-stage reviews without re-verifying; line numbers drift when neighboring code is added or moved.


## Improvement: create_file on Windows produces CRLF

Condition:

- Using create_file tool to author a new markdown durable doc on Windows host; verifying line endings with raw byte inspection after creation

Action:

- Do NOT assume create_file produces LF-only line endings on Windows; the file may be CRLF from the moment of creation (system default). Do run raw byte inspection (CR/LF count) on the file right after create_file, not only after edits. Do convert to LF-only with [System.IO.File]::WriteAllBytes after byte-level CR strip when CR > 0. Do re-verify with raw byte count after conversion. Do not trust LF-only authoring assumption for new files on Windows. Don't waste turns reading the file content expecting LF when bytes are CRLF; check bytes first.

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

## Post-task: 2026-06-18 Stage 19 implementation-plan review

Task completed:

- Yes

Effectiveness assessment:

- Authored Stage 19 implementation-plan review report (part-01-architect-implementation-plan-review-gate-01.md) with 0 BLOCKING, 2 non-blocking, 1 INFO findings. Verdict PASS. Plan file is 298 LF, CR=0, BOM=False, non-ASCII=0, under 300-line cap. Linter initially flagged MD056/MD060 on table cells with unescaped PowerShell pipes; fixed by escaping to `\|`. After fix, ran `git diff --check` and got clean result. The pipe-escape pattern was a new improvement not yet in the memory.

Improvement outcome candidate:

- Condition:
  - When authoring review report with markdown table cells that quote PowerShell pipeline commands or brace-expansion paths containing `|` characters
- Action:
  - Do escape every `|` inside table cell content as `\|` before committing; do run linter on file before declaring done

Similar memory check:

- Similar improvement found: No
- Existing improvements cover line endings (CRLF), diff readability, format-property self-claims, but none specifically address pipe escape in markdown table cells.
- Decision: Add new improvement because the unescaped-pipe pattern caused real linter errors that required a fix pass, and a future review report will hit the same trap.

Memory update:

- Final improvement outcome stored: see "Improvement: Unescaped pipes in markdown review table cells" above.

## Improvement: Path-prefix consistency between evidence text and on-disk artifacts

Condition:

- Reviewing implementation evidence that references artifact paths in manifest table or prose; plan file uses one convention (e.g., ._test_output/) but evidence file uses different convention (e.g., _test_output/)

Action:

- Do cross-check evidence file's path references against actual on-disk listing using Get-ChildItem -Recurse -Force. Do record the discrepancy as non-blocking finding (F-19-IR-01-style) since artifacts exist at correct path. Do note which convention the plan file uses and recommend normalizing evidence file to match. Don't flag as BLOCKING when artifacts are findable via the plan-correct path; this is documentation hygiene, not implementation defect.

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

## Post-task review 2026-06-18 (Stage 21 implementation re-review)

Task completed:
- Yes

Effectiveness assessment:
- Re-reviewed F-21-IR-01 after commit 65d678d71, produced part-06 with REWORK verdict, and updated only the Stage 21 implementation entry gate status. The review caught that corrected live logic blocks missing evidence for existing near/new rows but can still pass when those required classes are absent.

Improvement outcome candidate:
- Condition:
  - When reviewing a staged workload runner verdict gate after a correction claims required evidence is enforced
- Action:
  - Do test missing-class paths as well as missing-evidence paths; PASS must require required class presence and class-specific evidence.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Runner verdict must enforce design PASS criteria
- Decision: Strengthen existing improvement.

Memory update:
- Final improvement outcome stored:
  - Condition:
    - When reviewing a runner script or harness that produces PASS, FAIL, BLOCKED, or PASS-candidate verdicts for a staged workload gate
  - Action:
    - Do require presence/minimum counts for design-required workload classes before PASS/PASS-candidate, then require the class-specific evidence for those rows.

### Post-Task Review - 2026-06-18 (Stage 20 design authoring)

Task: Author Stage 20 design (Stage 17 Test Infrastructure Additions) covering three deferred items from Stage 17 closure: agentic prompt generator (TP-17-SY1..SY5), Qwen3.6-27B-MTP fixture (TP-17-HV1/HV2), and S/L framework re-invocation (TP-17-ST1..ST3). Manager decision R-20-DESIGN-MGR-01 required for Item 2.

Task completed: Yes.

Effectiveness assessment: Authored five LF-only UTF-8 no-BOM files: entry doc (93 lines), part 1 Item 1 generator design (192 lines), part 2 Item 2 fixture + R-20-DESIGN-MGR-01 (177 lines), part 3 Item 3 S/L framework (194 lines), part 4 traceability/risks/handoff (114 lines). All under 300-line cap. CR=0, BOM=False, non-ASCII=0 across all five. Trailing newline OK on all five. Verified via byte-level ReadAllBytes per the existing improvement `Verify review file output line endings before declaring document quality PASS`. Manager decision R-20-DESIGN-MGR-01 listed with four options (A: HuggingFace, B: local copy, C: Qwen3.5-4B-MTP substitute, D: defer) and Architect did NOT pick a fallback. Item 1 and Item 3 may proceed in parallel with the Manager decision; Item 2 must wait.

Improvement outcome candidate: Multi-item stage design with per-item Manager decision gating - the existing improvements cover plan-review handoff prerequisites and one-gate stage design authoring, but do not specifically address the case where a multi-item stage design has one item gated on a Manager decision while the other items can proceed in parallel. The new improvement above captures this pattern.

Similar memory check: Similar improvement found: partial. `Handoff prerequisites in plan reviews` covers "wait for manager handoff" but applies to plan reviews, not design authoring. `One-gate stage design authoring` covers leaving unstarted gates as unstarted but does not address per-item gating within a single design. The new improvement is specific to design authoring for multi-item stages with binding Manager decisions.

Decision: Add new improvement because the pattern surfaced explicitly in this task (user prompt: "Architect must NOT pick a fallback... must surface this as a Manager decision") and the entry-doc handoff had to clearly partition Item 1+3 (parallel) from Item 2 (gated). Future multi-item stage designs will hit the same trap.

Memory update: New improvement `Multi-item stage design with per-item Manager decision gating` stored above; this post-task review appended below.


## Improvement: Parallel decision IDs across design and tracker

Condition:

- Reviewing a stage design authored before Manager records their binding decision; design uses a design-side decision ID like R-NN-DESIGN-MGR-01 and tracker records the Manager-side decision ID like DNN-EXEC-01; both refer to same fixture acquisition path or substitute choice

Action:

- Do record both IDs as non-blocking observation in the design review findings table. Do require implementation plan to reference both IDs in a single decision table row so future audits reconcile them. Don't reject design on parallel IDs when design correctly defers to Manager and Manager already recorded a parallel decision; the reconciliation is implementation-plan-time work.
## Post-task review 2026-06-18 (Stage 20 design review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed Stage 20 design in a fresh Architect session; produced part-05-design-review-gate-01.md with verdict PASS, 0 BLOCKING, 3 non-blocking, 0 INFO.
- Successfully verified all 23 checklist items using byte-level format checks (LF/BOM/unicode/line-count) and shell verification commands (Get-ChildItem, Test-Path, git status, git diff --check).
- Used Manager decision D20-EXEC-01 from tracker alongside design-side R-20-DESIGN-MGR-01; documented parallel IDs as non-blocking observation.
- Encountered read_file tool failure on dot-prefixed paths (._design_docs/...) on Windows; recovered by routing through cmd /c type and PowerShell Get-Content with explicit path. Worktree-readable alternative works.

Improvement outcome candidate:
- Condition: Reviewing design authored before Manager decision; design uses R-NN-DESIGN-MGR-01, tracker uses DNN-EXEC-01.
- Action: Record both IDs as non-blocking observation; require implementation plan to reconcile.

Similar memory check:
- Existing: Handoff prerequisites in plan reviews, One-gate stage design authoring, Closure doc sweep part-file split and CRLF normalization.
- Decision: Add new improvement (already appended above as "Parallel decision IDs across design and tracker").

Memory update:
- Added improvement: Parallel decision IDs across design and tracker.

Note on read_file tool:
- read_file tool reports "Unable to resolve nonexistent file" on Windows paths under dot-prefixed directories like ._design_docs/. cmd /c type works. Future architect tasks should expect to route reads through cmd /c type and stage outputs in chat session resources for further inspection.

## Post-task review 2026-06-18 (Stage 20 implementation-plan review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed Stage 20 implementation plan in a fresh Architect session; produced part-01-architect-implementation-plan-review-gate-01.md in newly-created `_design_docs/cache-handling-phase20-implementation/` subdirectory. Verdict PASS, 0 BLOCKING, 2 non-blocking, 4 INFO.
- The 30-item user-supplied checklist mapped cleanly to substantive plan evidence; no rework loops. Found one user-brief line-count mismatch (143 vs actual 201), two user-brief param-count mismatches (5+3 vs design 5+2; 6 vs plan 7) - all recorded as INFO, not blockers, because plan matches approved design exactly.
- Plan under review was LF-only and clean (CR=0, BOM=False, no unicode, no trailing whitespace). My own review deliverable was NOT clean on first write: create_file on Windows inserted CRLF (CR=139) and I introduced one em-dash (U+2014) in my own prose. Caught both via byte-level check on own output and fixed by replacing em-dash with ASCII hyphen, then rewriting via WriteAllText after stripping CR.

Improvement outcome candidate:
- Condition: Authoring any review deliverable (architect review report, design review, implementation review, code review) on Windows.
- Action: Do run byte-level format verification on own output before declaring done (CR=0, BOM=False, nonAscii=0, no trailing whitespace). Do replace em-dash with comma or " - " before write; create_file on Windows preserves both CRLF and any U+2014 character in the input string. The same CRLF rule already covers the technical fix; the new wrinkle is that the Architect itself authored the violations.

Similar memory check:
- Existing "CRLF and trailing whitespace on Windows tool-inserted content" already says "Do convert to LF-only by reading raw bytes, filtering out 0x0D, and writing with [System.IO.File]::WriteAllBytes". Existing "Self-claim format verification in review subjects" already says verify format claims on review subjects. The gap: neither rule explicitly says "do this on your OWN review deliverable too, not only on subjects you review."
- Decision: Strengthen the existing CRLF rule with an explicit self-application clause rather than add a duplicate improvement.

Memory update:
- Existing CRLF rule strengthened below with self-application clause.

## Improvement: CRLF/em-dash verification applies to own deliverables too

Condition:

- Architect author just authored a review report, design review, implementation review, or other durable doc on Windows; create_file and Set-Content on Windows insert CRLF even when the author wrote prose intending LF; author may also have inserted em-dash (U+2014) in their own prose

Action:

- Do apply the CRLF rule (strip 0x0D, write via WriteAllBytes/WriteAllText with UTF8-no-BOM after byte strip) to OWN durable deliverables before declaring done, not only to subjects under review. Do replace any U+2014 in own prose with comma or " - " before write. Do verify own output byte-level: CR=0, BOM=False, nonAscii=0, no trailing whitespace, line count under cap. Do expect linter MD041 warning on verdict-first-line format; task instruction takes precedence. Don't trust create_file to produce LF; the same Windows default applies to my own writes.

## Post-task review 2026-06-18 (Stage 20 implementation review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed Stage 20 implementation evidence in a fresh Architect session; produced part-04-architect-implementation-review-gate-01.md. Verdict PASS, 0 BLOCKING, 1 non-blocking, 0 INFO.
- 35-item user-supplied checklist mapped cleanly to substantive evidence; no rework loops. Verified all three items (agentic-prompt-generator.ps1, 27B fixture, S/L wrapper) against byte-level format, parameter contract, and per-item smoke evidence.
- Caught one non-blocking self-claim discrepancy in the subject: implementation evidence file claims `agentic-prompt-generator.ps1` has 274 lines but actual file has 308 lines. Script itself is LF-only, no BOM, no unicode, no trailing whitespace, fully functional. Other format properties (CR=0, BOM=False, no non-ASCII) are correctly stated.
- My own review deliverable was NOT clean on first write: create_file on Windows inserted CRLF (CR=141). Caught via the existing byte-level check and fixed via WriteAllBytes after stripping 0x0D. MD041 warning was expected per task contract (verdict line at top).
- All evidence artifacts spot-checked (smoke JSONs, side logs, extracted chat template). Implementation matches approved design and plan; verdict PASS.

Improvement outcome candidate:
- Condition: Reviewing implementation evidence file that records a line-count claim for a code artifact (script, helper) the review must also byte-check.
- Action: Do not trust the subject's line-count claim; do verify by LF byte count (or Get-Content count) on the actual file. Do flag as non-blocking when subject's other format claims hold but the LF count number is wrong. Do not flag as blocking unless the script content is wrong.

Similar memory check:
- Existing "Self-claim format verification in review subjects" already says "Do verify each format claim with byte-level check regardless of what the subject's own text says." This case reinforces the existing rule - the implementation evidence's claim "LF=274" was incorrect but the underlying file was correct, and the existing rule's separation of format violations from code correctness held up. No update needed.

Memory update:
- No new improvement; existing "Self-claim format verification in review subjects" was reinforced and correctly applied.

## Post-task review 2026-06-18 (Stage 21 design review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed Stage 21 design in a fresh Architect session and produced `part-01-design-review-gate-01.md` with verdict PASS, 0 BLOCKING, 3 non-blocking, 1 INFO. Updated the Stage 21 entry doc with Contents and Gate status. Verified modified deliverables with LF byte count, CR=0, BOM=False, non-ASCII=0, no trailing whitespace, under 300 lines, and clean `git diff --check`. Local markdownlint was unavailable without package install.

Improvement outcome candidate:
- Condition:
  - When authoring an independent design review part and the entry doc has no Contents or stale pending-review gate state
- Action:
  - Do update entry-doc Contents and Gate status in the same task while keeping Manager gate pending

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - One-gate stage design authoring and Narrow re-reviews still update navigation state already require recording independent design review PASS in the review report and entry doc while leaving Manager gate pending.
- Decision: No update

Memory update:
- No new improvement; existing navigation-state rules were reinforced and applied.

## Post-task review 2026-06-18 (Stage 21 implementation review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed Stage 21 runner patch and dry-run evidence without running full heavy execution. Produced `part-04-architect-implementation-review-gate-01.md` with verdict REWORK, 1 BLOCKING, 2 non-blocking, 2 INFO. Updated Stage 21 implementation entry status and gate row. Verified own review output and entry edit as LF-only, no BOM, ASCII, no trailing whitespace, under 300 lines, and `git diff --check` clean.

Improvement outcome candidate:
- Condition:
  - When reviewing a runner script or harness that produces PASS, FAIL, BLOCKED, or PASS-candidate verdicts for a staged workload gate
- Action:
  - Do trace every approved design PASS/BLOCKED criterion into executable verdict predicates, not only summary fields

Similar memory check:
- Similar improvement found: partial
- Existing improvement:
  - Infrastructure pass is not workload coverage
- Decision: Add new improvement because this review found a script-specific live verdict gap, not just a workload-scope mismatch.

Memory update:
- Added `Runner verdict must enforce design PASS criteria`.

## Post-task review 2026-06-18 (Stage 22 design authoring)

Task completed:
- Yes

Effectiveness assessment:
- Authored Stage 22 design and reconciled index/tracker without production edits. Verified new doc line count, LF/no-BOM/no-trailing-whitespace, and tracked-doc `git diff --check`. Normal `git diff --check` skipped the untracked new design doc, so a no-index check against an empty temp file was needed.

Improvement outcome candidate:
- Condition:
  - When authoring a new durable doc that is still untracked
- Action:
  - Do run a separate whitespace check for the new file because normal `git diff --check` skips untracked paths.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement: Untracked or partly-tracked review doc paths
- Decision: Strengthen existing improvement.

Memory update:
- Final improvement outcome stored:
  - Condition:
    - When adding or updating review/design docs that are untracked or partly tracked by git
  - Action:
    - Do verify untracked content directly and run `git diff --check --no-index` against an empty temp file for new durable docs when normal diff cannot include them.

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

## Post-task review 2026-06-18 (Stage 22 design review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed Stage 22 design against architecture, requirements, Stage 21 evidence, and current demotion code. Produced an in-place review section under the 300-line cap with REWORK verdict, 2 blocking findings, and 1 non-blocking stale-history note. Verified the updated untracked design doc with byte-level LF/ASCII checks, normal `git diff --check`, and no-index whitespace check.

Improvement outcome candidate:
- Condition:
  - When reviewing a design for a state-machine refactor where preserved validation order conflicts with required special handling for a state already rejected by that order
- Action:
  - Do compare proposed order against current code and block until the design names the exact reordered branch or diagnostic outcome, with a unit assertion.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Cross-part protocol consistency in multi-part design
- Decision: Add new improvement because this task found a single-function validation-order contradiction, not a cross-part protocol conflict.

Memory update:
- Final improvement outcome stored:
  - Condition:
    - When reviewing a design for a state-machine refactor where one requirement says to preserve current validation order and another requires special handling for a state already rejected by that order
  - Action:
    - Do compare the proposed order against current code line-by-line and flag the contradiction as blocking unless the design states the exact reordered branch or diagnostic outcome. Do require a focused unit assertion for the special state.

## Post-task review 2026-06-18 (Stage 22 design correction)

Task completed:
- Yes

Effectiveness assessment:
- Corrected the Stage 22 design in place after review gate 01 without code/test edits. Closed F-22-DR-01 by making the already-demoting validation branch precede generic non-hot rejection, and closed F-22-DR-02 by adding explicit target/draft demotion completion coverage. Kept the design under 300 lines and verified LF/no-BOM/ASCII/trailing whitespace plus `git diff --check`.

Improvement outcome candidate:
- Condition:
  - When correcting a design review finding in an untracked stage doc that already has an in-place review section
- Action:
  - Do keep the review finding historical, add a separate correction record after it, and update current status/handoff lines to corrected pending re-review.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement: Gate wording with open findings
- Decision: No update; existing rule already covers stale handoff/status cleanup after gate state changes.

Memory update:
- No new improvement; existing gate wording rule was applied.

## Post-task review 2026-06-18 (Stage 22 design re-review)

Task completed:
- Yes

Effectiveness assessment:
- Re-reviewed correction record 01, checked current demotion code and existing test hooks narrowly, and recorded PASS in the Stage 22 design without production/test edits. Kept the untracked design doc under the 300-line cap and updated current status/handoff plus index state.

Improvement outcome candidate:
- Condition:
  - When appending a re-review section to a design doc close to the 300-line cap
- Action:
  - Do count lines before patching, keep the section compact, and update stale current status/handoff lines in place rather than adding extra prose.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement: Gate wording with open findings
- Decision: No update; existing gate wording and line-cap rules already cover this pattern.

Memory update:
- No new improvement; existing rules were applied.

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

## Post-task review 2026-06-19 (Stage 22 D22-EXEC-01 bug-fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed bug-fix report, Stage 22 docs, QA/developer reports, and code/test diffs without editing production code or tests. Appended PASS review under the report line cap and verified untracked doc hygiene with byte-level checks plus no-index whitespace check.

Improvement outcome candidate:
- Condition:
  - When a bug-fix review includes a user-provided async or timing hint
- Action:
  - Do decide independently whether the hint is required, based on code, evidence, and accepted docs.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement: Race-fix plans need deterministic duplicate/stale assertions
- Decision: Add new improvement because this review covered user-hint classification, not test evidence sufficiency.

Memory update:
- Final improvement outcome stored:
  - Condition:
    - When a bug-fix review mentions a user-provided thinking hint such as async timing, race behavior, or suspected root cause
  - Action:
    - Do decide independently from code, evidence, and approved docs whether that hint is required for the fix. Don't treat the hint as a new design requirement unless Manager or the accepted design records it.

## Post-task review 2026-06-19 (Stage 22 implementation review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed Stage 22 code, tests, accepted design, implementation plan, Stage 21 context, build output, test output, and diff checks. Recorded a REWORK verdict in a split implementation review part because the entry doc was already 288 lines. Found one blocking test/evidence issue: TP-22-UT6 wrapper is a placeholder even though TP-21 invariant tests are real and separately registered. Verified own docs as LF-only, no BOM, ASCII, no trailing whitespace, and under 300 lines.

Improvement outcome candidate:
- Condition:
  - When reviewing implementation evidence that maps a required test ID to a registered test function
- Action:
  - Do inspect the test body and reject placeholder functions as meaningful coverage; require truthful evidence mapping if underlying tests satisfy the row separately.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Race-fix plans need deterministic duplicate/stale assertions
- Decision: Add new improvement because this task exposed a test-body/evidence-mapping gap, not only a deterministic assertion gap.

Memory update:
- Final improvement outcome stored:
  - Condition:
    - When reviewing implementation evidence that maps a required test ID to a registered test function
  - Action:
    - Do inspect the test body, not only its name and registration. If the function only prints, `assert(true)`, or otherwise cannot fail when the required behavior regresses, do not count it as meaningful coverage. Do accept separately registered underlying tests only when the implementation log states that mapping truthfully.

## Post-task review 2026-06-19 (Stage 22 implementation re-review)

Task completed:
- Yes

Effectiveness assessment:
- Re-reviewed the narrow F-22-IR-01 correction without editing production code or tests. Verified the placeholder wrapper was removed from source, active evidence now records 104 total tests with 7 focused Stage 22 tests plus direct TP-21 invariant PASS lines, and stale gate wording was updated in the implementation entry, split re-review part, document index, and tracker. Ran focused binary output check plus tracked and no-index whitespace checks for touched docs.

Improvement outcome candidate:
- Condition:
  - When a re-review correction changes both gate result and evidence counts in an untracked stage implementation doc
- Action:
  - Do update the split review part, entry status/Contents, document index, and tracker row together; verify untracked docs with no-index whitespace checks and tracked docs with normal `git diff --check`.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Gate wording with open findings; Untracked or partly-tracked review doc paths
- Decision: No update; existing rules already cover gate-state sweep and no-index checks for untracked durable docs.

Memory update:
- No new improvement; existing gate wording and untracked-doc verification rules were applied.

## Post-task review 2026-06-19 (Stage 22 D22-RERUN-01 bug-fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the D22-RERUN-01 fix report, QA rerun 02, Developer review, Stage 22 docs, and current code/test diffs without editing production code or tests. Appended a PASS review under the report line cap. Verified the ignored fixes report directly because normal `git diff` could not see it; byte checks and no-index whitespace check were clean.

Improvement outcome candidate:
- Condition:
  - When appending review text to an ignored `.test_reports` file
- Action:
  - Do verify path status, byte hygiene, and no-index whitespace checks instead of relying on normal `git diff`.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Untracked or partly-tracked review doc paths
- Decision: No update; existing rule already requires direct verification and no-index whitespace checks for untracked or partly tracked durable docs.

Memory update:
- No new improvement; existing untracked-doc verification rule was reinforced.

## Improvement: Fallback predicates must match accepted scope

Condition:
- When reviewing a bug fix that claims fallback is limited to restore-visible or resident state, but code gates fallback through a broader descriptor-exists predicate

Action:
- Do compare the exact predicate used for candidate visibility with the accepted fix wording and focused regression setup. Don't accept a descriptor-only predicate when the gate requires resident bytes or hot-record visibility; require code narrowing or a documented Manager-approved behavior expansion.

## Post-task review 2026-06-19 (Stage 22 D22-RERUN-03-F1 correction re-review)

Task completed:
- Yes

Effectiveness assessment:
- Re-reviewed the narrow D22-RERUN-03-F1 correction, verified the fallback
  predicate now uses restore-visible resident exact state, verified the
  metadata-only source checkpoint precheck is guarded by selected payload kind,
  and confirmed 109/109 focused test evidence locally. Appended the PASS review
  to the ignored fixes report and updated stale gate wording in the Stage 22
  implementation entry, tracker, and index. Verified ignored and untracked docs
  with byte checks and no-index whitespace checks.

Improvement outcome candidate:
- Condition:
  - When re-reviewing a correction to a fallback predicate after a prior
    Architect blocker
- Action:
  - Do compare the fixed predicate against the exact accepted scope and require
    the regression to assert both the allowed and rejected boundary.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Fallback predicates must match accepted scope.
- Decision: No update; the existing improvement already covered this behavior.

Memory update:
- No new improvement; existing fallback-predicate and ignored-doc verification
  rules were applied.

## Post-task review 2026-06-19 (Stage 22 D22-RERUN-04-F1 bug-fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the D22-RERUN-04-F1 fix without editing production code or tests.
  Appended a PASS review to the ignored fixes report, checked prefix/LRU/delete
  invariants, verified the focused A/B/C regression is registered, and used
  byte-level plus no-index whitespace checks because normal git diff does not
  show ignored `.test_reports` files.

Improvement outcome candidate:
- Condition:
  - When reviewing a fix that keeps an entry in a discovery index after
    eviction or demotion
- Action:
  - Do distinguish discovery visibility from restore visibility by tracing the
    later descriptor, owner, residency, and hot-record predicates before
    deciding whether the index retention is safe.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Fallback predicates must match accepted scope; Untracked or partly-tracked
    review doc paths.
- Decision: No update. Existing predicate-scope and ignored-doc verification
  rules covered the task; the discovery-index distinction was applied but does
  not need a separate memory entry.

Memory update:
- No new improvement; existing predicate and ignored-doc rules were reinforced.

## Post-task review 2026-06-19 (Stage 22 D22-RERUN-05-F1 bug-fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the narrow D22-RERUN-05-F1 fix without editing product code or
  tests. Appended a PASS review to the ignored fixes report, verified the
  branch-forest eviction candidate filter against LRU membership, checked the
  strengthened A/B/C regression body, and confirmed scoped diff hygiene plus
  ignored-report byte/no-index checks.

Improvement outcome candidate:
- Condition:
  - When reviewing a fix that intentionally keeps entries visible for lookup
    while removing them from eviction planning
- Action:
  - Do trace both indexes independently: the lookup index must still find the
    entry, while the policy candidate builder must reject entries absent from
    the LRU or ownership index.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Fallback predicates must match accepted scope; D22-RERUN-04 post-task note
    on distinguishing discovery visibility from restore visibility; Untracked
    or partly-tracked review doc paths.
- Decision: No update. Existing predicate-scope and ignored-doc rules covered
  the task, and the prior discovery-visibility note already captured the
  needed review pattern.

Memory update:
- No new improvement; existing predicate/index-scope and ignored-doc rules were
  reinforced.

## Post-task review 2026-06-20 (Stage 22 D22-RERUN-06-F1/F2/F3 bug-fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the narrow D22-RERUN-06 promotion lifetime fix without editing
  product code or tests. Appended a PASS review to the ignored fixes report,
  verified `remove_payload` preserves promoting descriptors, checked bounded
  promotion completion handling, ran focused test binary evidence locally, and
  confirmed ignored-report byte hygiene plus no-index whitespace check.

Improvement outcome candidate:
- Condition:
  - When reviewing a fix for queued async completion lifetime
- Action:
  - Do trace the owner descriptor from enqueue through cleanup/removal and
    completion, then require a regression that forces cleanup while completion
    is still queued.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Debug-hook evidence is not production integration; Race-fix plans need
    deterministic duplicate/stale assertions; Untracked or partly-tracked
    review doc paths.
- Decision: No update. Existing async evidence and ignored-doc verification
  rules covered the task.

Memory update:
- No new improvement; existing async-completion and ignored-doc rules were
  reinforced.

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

## Post-task review 2026-06-20 (Stage 22 D22-RERUN-07-F1/F2/F3/F4 bug-fix and fragility review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the D22-RERUN-07 cold checkpoint promotion fix and the full Stage 22
  fix cascade without editing product code or tests. Appended a PASS Architect
  review to the ignored fixes report, ran both focused builds, ran
  `test-cache-controller.exe` locally with 112/112 PASS, verified scoped diff
  hygiene, and recorded that the Stage 22 fragility review does not block QA.

Improvement outcome candidate:
- Condition:
  - When Manager requires a fragility or design review after a multi-iteration
    bug-fix cascade before QA rerun authorization
- Action:
  - Do separate current-fix correctness from broader design fragility; block QA
    only for active contract, documentation, regression, or architecture
    violations, and record post-QA simplification as advisory when the heavy
    rerun remains the process-level proof.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Debug-hook evidence is not production integration; Gate wording with open
    findings; Atomic-operation design reviews.
- Decision: Add new improvement because this task required a distinct
  blocker-threshold decision for a required fragility review, not only evidence
  sufficiency or stale gate wording.

Memory update:
- Added `Fragility review blocker threshold`.

## Post-task review 2026-06-20 (Stage 23 design authoring)

Task completed:
- Yes

Effectiveness assessment:
- Authored a new Stage 23 design for the deferred full S/L matrix, updated the
  index and tracker, avoided product/test/runner edits, and verified line caps,
  LF-only bytes, ASCII, trailing whitespace, normal diff check, and no-index
  whitespace check for the untracked design file.

Improvement outcome candidate:
- Condition:
  - When authoring a new stage design that depends on prior deferred execution
    scope and closed follow-up stages
- Action:
  - Do keep the new design scoped to the deferred activity, cite the closed
    stages as prerequisites, and avoid reopening their gates unless a current
    blocker exists.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Gate wording with open findings; Scoped traceability for deferred
    requirements; Untracked or partly-tracked review doc paths.
- Decision: No update. Existing rules already covered scoped deferred design,
  stale gate wording, and untracked-doc verification.

Memory update:
- No new improvement; existing scoped-traceability and gate-wording rules were
  reinforced.

## Post-task review 2026-06-20 (Stage 23 design review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the Stage 23 full S/L matrix execution design against Stage 20
  deferred scope, Stage 17 TP-17-ST1..ST3, Stage 21/22 closure context,
  requirements, architecture, index, tracker, and wrapper shape. Recorded a
  PASS review in a new Stage 23 design part without editing the design,
  tracker, index, scripts, or product code. Verified line caps and doc hygiene
  for the new untracked report.

Improvement outcome candidate:
- Condition:
  - When reviewing a design where the user forbids editing the reviewed design
    but still asks to create a separate review-history part
- Action:
  - Do keep the verdict and handoff in the review part only, and record any
    post-gate tracker or index state change as Manager-owned unless the user
    explicitly authorizes durable status edits.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Gate wording with open findings; Untracked or partly-tracked review doc
    paths.
- Decision: No update. Existing gate-wording and untracked-doc verification
  rules already covered the behavior.

Memory update:
- No new improvement; existing gate-wording and untracked-doc rules were
  reinforced.

## Improvement: Raw payload retention success paths

Condition:
- When reviewing a memory-pressure fix that drops, trims, or gates raw payload
  data only on a failure, skip, or rejection path

Action:
- Do inspect the corresponding success/admission path for retained raw vectors
  or copied payload lists. Do require a regression that proves the success path
  is bounded, not only that the skip path drops data.

## Post-task review 2026-06-21 (Stage 23 S03 product fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the S03 product fix without editing product code. Returned REWORK
  because checkpoint-list copying was fixed only for skipped checkpoint
  admission, while successful admission still retained full raw checkpoint
  vectors outside resident-payload eviction pressure. Verified the new review
  part and updated docs for line cap, LF-only bytes, ASCII, no BOM, no trailing
  whitespace, and scoped diff checks.

Improvement outcome candidate:
- Condition:
  - When reviewing a memory-pressure fix that drops raw payload data on only
    one branch
- Action:
  - Do inspect both skip/failure and success/admission paths, and require
    success-path boundedness evidence.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Fallback predicates must match accepted scope; Debug-hook evidence is not
    production integration.
- Decision: Add new improvement because this task exposed raw payload retention
  on a success path, not only predicate scope or test hook sufficiency.

Memory update:
- Added `Raw payload retention success paths`.

## Post-task review 2026-06-21 (Stage 23 S03 correction re-review)

Task completed:
- Yes

Effectiveness assessment:
- Re-reviewed the narrow F-23-S03-AR-01/F-23-S03-AR-02 corrections, verified
  success-path checkpoint metadata storage and target+draft demotion pressure,
  recorded PASS in a new Stage 23 implementation part, and swept current gate
  wording across the parent, index, correction part, and ignored fix report.

Improvement outcome candidate:
- Condition:
  - When re-reviewing a correction for a prior raw-payload retention finding
- Action:
  - Do verify the previously failing success path, confirm the new regression
    would fail under the old behavior, and update all current handoff locations
    from re-review-ready to the new gate state.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Raw payload retention success paths; Gate wording with open findings;
    Untracked or partly-tracked review doc paths.
- Decision: No update. Existing rules already covered success-path review,
  stale handoff cleanup, and direct verification for untracked/ignored docs.

Memory update:
- No new improvement; existing raw-payload and gate-wording rules were
  reinforced.

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

## Post-task review 2026-06-21 (Stage 23 S03 startup-crash fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the focused startup-crash fix without editing product code or tests,
  verified missing-cold-path and existing-cold-path evidence on disk, corrected
  stale durable test-count text, wrote a PASS review artifact, and updated the
  parent/index gate. The parent entry initially crossed the 300-line cap after
  link and gate wording were added; a follow-up trim brought it back to exactly
  300 lines.

Improvement outcome candidate:
- Condition:
  - When updating an entry/navigation document that is already close to the
    300-line cap
- Action:
  - Do run a line count after adding links or gate wording, then trim duplicate
    status text into the existing top-level status/gate line before finishing.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - CRLF and trailing whitespace on Windows tool-inserted content; Gate wording
    with open findings.
- Decision: Add new improvement because existing rules cover hygiene and gate
  consistency, but not the pattern where parent link updates push an entry over
  the split-rule cap.

Memory update:
- Added `Entry docs near line cap`.

## Post-task review 2026-06-21 (Stage 23 S03 rerun09 bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the narrow F-23-S03-RERUN09-01 metadata lifetime fix, verified the
  symbolized attach-checkpoint boundary read, confirmed the new stale-completion
  regression, ran focused build/test/diff hygiene, wrote a PASS report in the
  ignored `.test_reports` tree, and updated the Stage 23 implementation/index
  gate without touching product or test code.

Improvement outcome candidate:
- Condition:
  - When reviewing a narrow crash fix in an ignored report directory with a
    near-cap implementation entry
- Action:
  - Do combine direct ignored-file byte checks, scoped diff hygiene, and entry
    line-count checks before returning the handoff.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Untracked or partly-tracked review doc paths; Self-claim format
    verification in review subjects; Entry docs near line cap; Gate wording
    with open findings.
- Decision: No update. Existing rules already covered ignored report
  verification, byte hygiene, line cap checks, and gate wording.

Memory update:
- No new improvement; existing ignored-doc, byte-hygiene, line-cap, and
  gate-wording rules were reinforced.

## Post-task review 2026-06-22 (Stage 23 S07 pressure-workload bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the S07 pressure-workload fixture substitution without running the
  full live row or editing product code. Confirmed the Qwen3.5 payload was
  rejected before hot admission under the 8 MiB hot budget, verified S07 uses
  the Qwen3-0.6B pressure fixture while keeping Stage 23 flags and primary
  model notes, checked S06/S04 dry-run guards, accepted the `.test_reports`
  stage23 Markdown whitelist, wrote a PASS review artifact, and updated the
  Stage 23 gate docs. Direct byte checks, no-index whitespace checks, parser
  checks, dry-runs, and line counts covered the new report and near-cap
  implementation entry.

Improvement outcome candidate:
- Condition:
  - When reviewing a pressure row whose public workload cannot emit trusted
    protected-root metadata but existing guidance names a focused controller
    evidence substitute
- Action:
  - Do separate live payload-pressure acceptance from trusted protected-root
    evidence. Accept the workload fix when pressure is proved and require the
    focused protected-root evidence in the QA rerun instead of blocking on
    degraded public counters.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Evidence-source consistency in test plan; Misconfigured-probe diagnosis vs
    product bug; Untracked or partly-tracked review doc paths; Entry docs near
    line cap.
- Decision: No update. Existing evidence-source and ignored-doc rules covered
  the decision once the Stage 4 script guidance was checked.

Memory update:
- No new improvement; existing evidence-source, ignored-doc, and line-cap rules
  were reinforced.

## Post-task review 2026-06-22 (Stage 23 S07 runner-contract bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the narrow S07 runner-contract fix without running the live row or
  editing product code. Confirmed the duplicate `--cache-ram` root cause,
  verified S07 omits wrapper cache RAM while receiving `-HotBudgetMiB 8`,
  checked S06 still receives `-HotBudgetMiB 16`, verified S04 still receives
  wrapper `--cache-ram 512`, wrote a PASS report in the ignored
  `.test_reports` tree, and updated Stage 23 implementation/index/tracker gate
  state. Parser checks, scoped dry-runs, byte checks, no-index whitespace
  checks, and line counts covered the new report and near-cap implementation
  entry.

Improvement outcome candidate:
- Condition:
  - When reviewing a runner-contract fix that changes per-row wrapper flag
    suppression
- Action:
  - Do verify the fixed row, the adjacent suppressed row, and one default row
    with wrapper dry-runs before passing the contract.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Untracked or partly-tracked review doc paths; Entry docs near line cap;
    Gate wording with open findings; prior S06/S05 runner-contract post-task
    notes.
- Decision: No update. Existing ignored-report, dry-run, line-cap, and gate
  wording rules already covered the task.

Memory update:
- No new improvement; existing runner-contract review, ignored-doc, line-cap,
  and gate-wording rules were reinforced.

## Post-task review 2026-06-22 (Stage 23 S06 pressure-workload bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the S06 pressure-workload fixture substitution without running the
  full live row or editing product code. Confirmed the Qwen3.5 payload was
  rejected before hot admission under the 16 MiB hot budget, verified the S06
  pressure fixture path and Stage 23 flags, checked smoke evidence for real
  demotion and cold eviction pressure, wrote a PASS report in the ignored
  `.test_reports` tree, and updated Stage 23 gate docs. Direct byte checks,
  no-index whitespace checks, parser checks, and line counts covered the new
  ignored report and near-cap implementation entry.

Improvement outcome candidate:
- Condition:
  - When reviewing a runner workload fixture substitution for a pressure row
- Action:
  - Do verify both the old fixture rejection boundary and the substitute
    fixture admission/pressure evidence before accepting the substitution.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Untracked or partly-tracked review doc paths; Entry docs near line cap;
    Gate wording with open findings; Raw payload retention success paths.
- Decision: No update. Existing rules already covered direct ignored-report
  verification, line-cap hygiene, gate updates, and success-path pressure
  evidence checks.

Memory update:
- No new improvement; existing ignored-doc, line-cap, gate-wording, and
  success-path verification rules were reinforced.

## Post-task review 2026-06-21 (Stage 23 S06 runner-contract bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the narrow S06 runner-contract fix without running the live row or
  editing product code. Confirmed the duplicate `--cache-ram` root cause,
  verified S06 omits wrapper cache RAM while preserving required Stage 23 flags,
  verified S04 still receives wrapper `--cache-ram 512`, wrote a PASS review in
  the ignored `.test_reports` tree, and updated the Stage 23 implementation and
  index gate. Direct byte checks and no-index whitespace checks covered the new
  ignored report, and line counts kept the near-cap implementation entry under
  300 lines.

Improvement outcome candidate:
- Condition:
  - When reviewing a runner-contract fix whose fix report changed-files list
    omits an actual changed runner script
- Action:
  - Do inspect git status and diffs directly, include the omitted file in the
    review artifact, and treat the omission as a risk note rather than a blocker
    when the verified contract and durable gate docs are correct.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Untracked or partly-tracked review doc paths; Entry docs near line cap;
    Gate wording with open findings.
- Decision: No update. Existing rules already required direct status/diff
  verification, ignored-report checks, and gate-doc consistency. The omission
  was handled in the review artifact without needing a new memory entry.

Memory update:
- No new improvement; existing direct-verification, ignored-doc, line-cap, and
  gate-wording rules were reinforced.

## Post-task review 2026-06-21 (Stage 23 S05 runner-contract bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the narrow S05 runner-contract fix without editing product code or
  tests. Confirmed the per-profile duration root cause, verified 600/600/600
  allocation in direct and wrapper dry-runs, wrote a PASS report in the ignored
  `.test_reports` tree, updated the Stage 23 implementation/index gate, and
  trimmed the near-cap implementation entry back under 300 lines.

Improvement outcome candidate:
- Condition:
  - When reviewing a runner-contract fix in an ignored report directory with a
    near-cap implementation entry
- Action:
  - Do combine direct ignored-file byte checks, scoped parser/dry-run evidence,
    and entry line-count checks before returning the handoff.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Untracked or partly-tracked review doc paths; CRLF and trailing whitespace
    on Windows tool-inserted content; Entry docs near line cap; Gate wording
    with open findings.
- Decision: No update. Existing rules already covered ignored report
  verification, byte hygiene, parser/dry-run evidence, line-cap trimming, and
  gate wording.

Memory update:
- No new improvement; existing ignored-doc, byte-hygiene, line-cap, and
  gate-wording rules were reinforced.

## Post-task review 2026-06-22 (Stage 23 L02 runner-contract bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the L02 paired legacy-control/hybrid runner fix, wrote a PASS
  durable report, updated current Stage 23 gate docs, verified parser and
  wrapper dry-runs, checked the child smoke artifacts, and kept the near-cap
  implementation entry at 300 lines.

Improvement outcome candidate:
- Condition:
  - When reviewing a runner-contract fix where one logical row starts more than
    one server leg or uses `Port + N` internally
- Action:
  - Do verify wrapper port allocation, batching, dry-run side logs, and
    next-row interaction; require a code fix for approved colliding batches or
    record a focused-row/`BatchSize 1` handoff constraint.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Runner-contract dry-run review notes existed for per-row flag suppression,
    but not for multi-leg port use.
- Decision: Add new improvement because this task exposed a separate wrapper
  batching and port-allocation review point.

Memory update:
- Added `Multi-leg row runner port contract`.

## Post-task review 2026-06-22 (Stage 23 L03 runner-contract bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the L03 mixed-workload runner fix before QA rerun, wrote a PASS
  durable report, updated current Stage 23 gate docs, verified parser and
  wrapper/child dry-runs, inspected the child smoke artifacts, and kept the
  near-cap implementation entry at 299 lines. The main judgment point was
  accepting harness prompt-class diversity even though the Qwen3.5 MTP public
  prompt evidence still reports one product profile.

Improvement outcome candidate:
- Condition:
  - When reviewing a mixed-workload runner fix where public prompt evidence
    collapses all requests into one profile or outcome
- Action:
  - Do separate product profile classification from harness prompt-class
    coverage, and require machine-readable plan/count/metric/checksum evidence
    before accepting the rerun gate.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Evidence-source consistency in test plan; Workload follow-up design after
    infrastructure PASS; Untracked or partly-tracked review doc paths.
- Decision: Add new improvement because this task needed a specific review
  threshold for runner-class evidence when public product profile labels are
  fixture-collapsed.

Memory update:
- Added `Mixed-workload runner evidence with collapsed public profiles`.

## Post-task review 2026-06-23 (Stage 23 L02 comparison explanation)

Task completed:
- Yes

Effectiveness assessment:
- Explained a read-only L02 comparison report by reading the index, Stage 23
  design and implementation entries, the focused report, and local comparison
  metrics. Kept the answer scoped to interpretation and did not edit repo
  design, test report, product, or runner files.

Improvement outcome candidate:
- Condition:
  - When a read-only explanation asks about one Stage 23 focused report
- Action:
  - Do read the durable report plus the relevant stage entry and any local
    machine-readable artifact before answering; don't infer row meaning from
    metric names alone.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Evidence-source consistency in test plan; Multi-leg row runner port
    contract; Mixed-workload runner evidence with collapsed public profiles.
- Decision: No update. Existing evidence-source and runner-artifact rules
  already cover this behavior.

Memory update:
- No new improvement; existing evidence-source and runner-artifact rules were
  reinforced.

## Post-task review 2026-06-23 (Stage 24 design authoring)

Task completed:
- Yes

Effectiveness assessment:
- Authored the Stage 24 design from the intake stub, kept the work scoped to
  durable design and index docs, made the S02/S03 runner and evidence decisions
  explicit, and corrected the design entry from 331 to 270 lines after the
  split-rule check caught the cap breach.

Improvement outcome candidate:
- Condition:
  - When authoring a dense stage design entry that approaches or exceeds the
    300-line cap
- Action:
  - Do run the line-count check before finalizing and either trim duplicate
    wording or split immediately; don't rely on visual length.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Entry docs near line cap; Scoped traceability for deferred requirements.
- Decision: No update. Existing line-cap and scoped-traceability rules already
  cover this behavior.

Memory update:
- No new improvement; existing line-cap and scoped-traceability rules were
  reinforced.

## Post-task review 2026-06-23 (Stage 24 design review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the Stage 24 design in a fresh architect session, kept the work to
  durable review/index updates, wrote a PASS part-file report instead of
  bloating the near-cap entry, and verified line caps, byte hygiene, and the
  pre-existing dirty index state before handoff.

Improvement outcome candidate:
- Condition:
  - When reviewing a near-cap stage design that already has untracked or
    partly tracked entry docs
- Action:
  - Do add the review as a part file, update only the parent link and index
    gate text, and verify new untracked docs directly with line, byte, and
    whitespace checks.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Entry docs near line cap; Untracked or partly-tracked review doc paths;
    Gate wording with open findings.
- Decision: No update. Existing rules already cover part-file review records,
  direct verification of untracked docs, and gate wording checks.

Memory update:
- No new improvement; existing line-cap, untracked-doc, and gate-wording rules
  were reinforced.

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

## Post-task review 2026-06-23 (Stage 24 implementation-plan review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the Stage 24 implementation plan against the approved design,
  Manager D24-DESIGN-01..03, and evidence/report conventions. Caught a
  report-placement blocker: the custom Stage 24 report name matched the design
  but was not whitelisted by `.test_reports/.gitignore`, so it would not be
  durable unless the plan changes the name or updates the whitelist/convention.

Improvement outcome candidate:
- Condition:
  - When reviewing a plan or design that introduces a custom durable report name
    under `._design_docs/.test_reports/`
- Action:
  - Do check the active `.test_reports/.gitignore` whitelist and test output
    convention before approving report placement.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Untracked or partly-tracked review doc paths; Hidden test_reports directory
    and path resolution.
- Decision: Add new improvement because existing rules cover ignored-file
  verification after creation, not pre-implementation report naming that would
  make future durable evidence ignored.

Memory update:
- Added `Durable report names and whitelist`.

## Post-task review 2026-06-23 (Stage 24 implementation-plan re-review)

Task completed:
- Yes

Effectiveness assessment:
- Re-reviewed the corrected Stage 24 implementation plan, confirmed the
  whitelisted `test-report-YYYYMMDD-NN.md` durable report pattern, kept the
  stage-specific identity in `RunId` and `._test_output/`, wrote a PASS
  re-review record, and updated the implementation entry and index without
  touching code or runner files.

Improvement outcome candidate:
- Condition:
  - When a plan correction supersedes an older design artifact name to satisfy
    `.test_reports` whitelist rules
- Action:
  - Do record the supersession in the review or parent implementation doc so
    Manager can open implementation against the corrected durable path.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Durable report names and whitelist.
- Decision: Strengthen existing improvement.

Memory update:
- Strengthened `Durable report names and whitelist` with explicit supersession
  handling for corrected report names.

## Post-task review 2026-06-23 (Stage 24 implementation review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the Stage 24 runner implementation against the approved design and
  implementation plan, wrote a REWORK review artifact, and updated the
  implementation entry, index, and tracker without touching product code. The
  review found that part 04 claimed a final durable report check for a
  `test-report-20260623*.md` file that was not present under the repo or
  `.test_reports/`.

Improvement outcome candidate:
- Condition:
  - When implementation evidence claims a durable report or final report leak
    scan under `._design_docs/.test_reports/`
- Action:
  - Do verify the exact report file exists on disk under the whitelisted path
    and is visible to `git status -- <path>` before accepting the evidence.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Durable report names and whitelist.
- Decision: Strengthen existing improvement because it already covered report
  naming and whitelist checks, but not the case where the claimed report file is
  absent.

Memory update:
- Strengthened `Durable report names and whitelist` with exact file-existence
  and `git status -- <path>` verification for claimed durable report evidence.

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

## Post-task review 2026-06-23 (Stage 24 implementation re-review)

Task completed:
- Yes

Effectiveness assessment:
- Re-reviewed the Stage 24 correction, verified the four prior blockers
  against script behavior and preserved artifacts, wrote a PASS Part 7
  re-review record, updated the implementation entry, index, and tracker, and
  kept product code untouched. The main judgment point was classifying the S02
  and S03 smoke failures as preserved test-result/product-behavior risks rather
  than runner implementation blockers.

Improvement outcome candidate:
- Condition:
  - When implementation re-review evidence includes smoke-run FAIL or BLOCKED
    outcomes while the review subject is the runner contract rather than final
    test execution
- Action:
  - Do separate runner correctness from product or test-result behavior and
    record smoke failures as INFO or follow-up risks when the runner preserves
    them correctly.

Similar memory check:
- Similar improvement found: Partial
- Existing improvement:
  - Durable report names and whitelist; Gate wording with open findings.
- Decision: Add new improvement because existing rules cover evidence
  durability and gate wording, but not smoke-result classification during a
  runner implementation review.

Memory update:
- Added `Smoke failures during implementation re-review`.

## Post-task review 2026-06-24 (Stage 24 correction re-review gate)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the CUDA correction plus S02/S03 pre-rerun fixes without running the
  full comparison or editing product code. Verified CUDA build/runtime gates,
  request-loop abort semantics, S03 hybrid-only unsafe-prefix policy, invalid
  CPU report alignment, line caps, byte hygiene, and gate wording. Wrote a PASS
  Part 11 review and updated the Stage 24 implementation, test plan, and index
  status.

Improvement outcome candidate:
- Condition:
  - When a fresh implementation re-review spans a runner fix, invalid prior
    report, and status-bearing docs
- Action:
  - Do verify script behavior, persistent docs, prior report evidence, and gate
    wording together before passing; update only the gate/status docs needed to
    remove stale pending-review text.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Gate wording with open findings; Smoke failures during implementation
    re-review; Durable report names and whitelist; Untracked or partly-tracked
    review doc paths.
- Decision: No update. Existing gate-wording, smoke-classification, durable
  report, and untracked-doc rules already covered the review.

Memory update:
- No new improvement; existing gate-wording, runner-evidence, and untracked-doc
  rules were reinforced.

## Post-task review 2026-06-24 (Stage 24 dry-run hang bug-fix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the Windows PowerShell dry-run serializer fix without running the
  live comparison or touching product code. Verified the root-cause evidence,
  safe JSON conversion shape, comma-delimited and array row handling, invalid
  row rejection, route and CUDA flag plan proof, preserved S02/S03 policies,
  and no server/HTTP activity during dry-run. Wrote a PASS Part 13 review and
  updated the Stage 24 implementation entry and index. Line, byte, parser,
  scoped dry-run, process, and whitespace checks passed, with no-index checks
  used for untracked files.

Improvement outcome candidate:
- Condition:
  - When reviewing a dry-run hang fix for an untracked runner script
- Action:
  - Do combine source-order proof that `-DryRun` exits before live execution
    with scoped dry-run validation, invalid-input rejection, process checks,
    and no-index whitespace checks for untracked artifacts.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Untracked or partly-tracked review doc paths; Line-ending diff noise on
    Windows; Gate wording with open findings; Smoke failures during
    implementation re-review.
- Decision: No update. Existing rules already require direct verification of
  untracked files, dry-run/source evidence, gate wording checks, and separate
  handling of runner-contract evidence.

Memory update:
- No new improvement; existing untracked-doc, dry-run/source-evidence,
  line-ending, and gate-wording rules were reinforced.

## Post-task review 2026-06-24 (Stage 24 report 03 runner-contract bugfix review)

Task completed:
- Yes

Effectiveness assessment:
- Reviewed the `$Matches` collision fix without rerunning live QA or touching
  product code. Verified the PowerShell root cause, invoked the fixed CUDA proof
  helper against the captured QA startup log, checked dry-run route/CUDA flags,
  confirmed scratch durable report absence, wrote a PASS Part 15 review, and
  aligned implementation/test-plan/index gate wording. A stale line-count claim
  in the fixes report was caught but was non-blocking because the verified file
  remained under 300 lines with clean byte hygiene.

Improvement outcome candidate:
- Condition:
  - When a runner-contract fix report includes self-claimed format or evidence
    counts
- Action:
  - Do verify current counts and byte hygiene directly, and treat stale numeric
    claims as non-blocking only when the verified gate condition still passes.

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Self-claim format verification in review subjects; Untracked or
    partly-tracked review doc paths; Gate wording with open findings.
- Decision: No update. Existing rules already require direct verification of
  self-claims, ignored/untracked artifacts, and gate wording.

Memory update:
- No new improvement; existing self-claim, untracked-doc, and gate-wording
  rules were reinforced.

## Improvement: Closure doc sweep applies verbatim Manager decisions and bypasses test-plan rework

Condition:

- Manager records closure decisions D-EXEC-24-01, D-EXEC-24-02, D-EXEC-24-03, D-CLOSURE-24-01 verbatim in closure instructions and the Architect task is to apply those decisions to durable design and implementation docs, not to rewrite test plans or test reports

Action:

- Do quote each Manager decision verbatim in the closure part file and in any per-row classification. Do not paraphrase decision text. Do record per-row final classification aligned with Manager decisions, including reclassifications. Do create closure record in new part file rather than inline in entry doc. Do replace entry-doc Current gate and Handoff wording with closure-appropriate phrasing ("terminal", "closed per D-CLOSURE-24-01") rather than "ready for QA", "current gate: test execution", "open", "blocked". Do update test plan part file Status line and Handoff section so it points to the closure part file rather than "may reopen QA execution". Do NOT modify the final test reports, fixes files, or developer review files. Do NOT modify test plan to record coverage gaps or benchmark-scope gaps as accepted skips. Do NOT commit code changes; per AGENTS.md AI agents wait for user commit approval and Manager closure preserves the uncommitted state. Do convert new closure part file to LF-only UTF-8 no BOM before running git diff --check. Do scan modified entry docs for stale phase-mismatch wording and replace with closure-appropriate phrasing.

## Post-task review 2026-06-25 (Stage 24 closure doc sweep)

Task completed:

- Yes

Effectiveness assessment:

- Applied D-CLOSURE-24-01 across six durable docs without rewriting test reports, fixes files, or developer review files. Authored new closure part file (part-16-manager-closure-20260625.md, 152 LF lines, LF-only no BOM no trailing whitespace no non-ASCII), updated implementation entry doc Status/Current gate/Handoff, updated design entry doc Status, updated tracker Stage 24 row (replaced implementation re-review PASS with closed under D-CLOSURE-24-01 with full decision summary in Notes), updated test plan part-29 Status and Handoff section, and added five new test-report rows + updated two existing index entries in document-index.md. All six touched files under 300 lines (implementation 297, design 275, tracker 66, test plan 296, index 153, part-16 152). git diff --check exit 0 on tracked files; no-index exit 1 for new file because content exists vs empty (not a whitespace failure).

Improvement outcome candidate:

- Condition:
  - When Manager closure task quotes decisions verbatim and instructs closure doc sweep across implementation log, tracker, design, test plan, and document index without modifying test reports or fixes files
- Action:
  - Do quote decisions verbatim in closure part file; do update entry-doc Status and Current gate with closure-appropriate wording ("closed per D-NN", "terminal"); do replace stale phase-mismatch wording ("ready for QA", "current gate: test execution", "may reopen QA execution"); do not modify test reports, fixes files, or developer review files; do not commit code changes per AGENTS.md.

Similar memory check:

- Similar improvement found: Yes
- Existing improvement:
  - Closure sweep keeps durable docs aligned; Closure sweep preserves historical failure headings; Closure doc sweep part-file split and CRLF normalization.
- Decision: Strengthen existing improvement by adding the verbatim-decision requirement and the bypass of test-plan/test-report editing. Existing rules cover file-split and CRLF hygiene; new wording covers the Manager-decision verbatim, entry-doc gate wording replacement, and the explicit bypass list.

Memory update:

- Final improvement outcome stored: see "Improvement: Closure doc sweep applies verbatim Manager decisions and bypasses test-plan rework" above.

## Improvement: Future-migration contract documented in main body

Condition:

- Reviewing multi-part design whose main body documents a future-migration contract (abort path with shadow fields, future API surface, planned refactor) that the current stage explicitly does not implement

Action:

- Do flag the unused future contract as non-blocking observation. Do recommend moving to OQ list, follow-up part file, or removing from main body. Do not block review when design correctly disclaims current non-implementation; reader may still misread contract as current behavior.

## Post-task review 2026-06-25: Stage 25 atomic-transaction design review

Task completed:

- Yes

Effectiveness assessment:

- Reviewed Stage 25 atomic-transaction design across entry doc + 7 part files plus baseline architecture entry, part-2 restore flow, stage 17, stage 22, stage 24 part-16 closure. 0 BLOCKING, 3 non-blocking observations (vestigial inner-call `tx_restore -> tx_update`, unused shadow fields in failure-mode contract, plan/apply split wording clarity), 6 OQs for Manager gate.
- Format claims (LF-only, no BOM, no trailing whitespace, under 300 lines) verified byte-level per existing memory rule. All 8 files clean. `git diff --check` exit 0 across entry doc + 7 part files.
- Verdict PASS. Atomic-transaction protocol sound; user requirement coverage complete; preserved invariants all listed; performance impact acceptable; migration path viable.
- Hard constraint "DO NOT modify design files" honored; gate wording not updated in entry doc per memory rule "Design-review PASS with Manager gate pending". PASS verdict recorded in review response only.

Improvement outcome candidate:

- Condition:
  - When reviewing multi-part design whose main body documents a future-migration contract (abort path, shadow fields, future API surface, planned refactor) that the current stage explicitly disclaims
- Action:
  - Do flag the unused future contract as non-blocking observation; do recommend moving to OQ list, follow-up part file, or removing from main body; do not block review when design correctly disclaims current non-implementation

Similar memory check:

- Similar improvement found: No exact match
- Existing improvement:
  - "Cross-part protocol consistency in multi-part design" (covers state-mutation consistency between protocol steps and failure-mode handling, different scope)
  - "Re-review corrected designs for new scope drift" (specific to re-reviews)
- Decision:
  - Add new, narrow improvement specific to future-contract documentation

Memory update:

- Final improvement outcome stored:
  - Condition:
    - When reviewing multi-part design whose main body documents a future-migration contract (abort path, shadow fields, future API surface, planned refactor) that the current stage explicitly disclaims as not implemented
  - Action:
    - Do flag the unused future contract as non-blocking observation; do recommend moving to OQ list, follow-up part file, or removing from main body; do not block review when design correctly disclaims current non-implementation; do record wording-clarity observation when reader may misread contract as current behavior

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

## Post-task review 2026-06-25: Stage 25 architecture baseline rework

Task completed:

- Yes

Effectiveness assessment:

- Reworked architecture entry doc + parts 1-3, 5-7 to reflect Stage 25 atomic transactional method. Parts 4, 8, 9 preserved as-is per user instruction. Part count stayed at 9; no new part files or sections added.
- Format claims verified byte-level on all 10 architecture files (LF-only, no BOM, no trailing whitespace, trailing LF). Entry doc stayed lean at 23 lines. Part 5 stayed at 337 lines (over 300 cap), pre-existing condition from when stages 4-14 were progressively added; the user prohibited splitting into new part files so the over-300 state was preserved as-is and noted in the return.
- git diff --check exit 0 across all 10 files after final hygiene pass. Whitespace-ignored numstat confirmed parts 4, 8, 9 had zero content changes; parts 1-3, 5-7 had expected transactional-method references.
- ADR-007 (asynchronous cold store) was the largest single rework: replaced decision text, alternatives, and consequences to reflect synchronous transactional model with worker repurposed as inline-under-lock helper. ADR status changed from Proposed to Active (rewritten Stage 25). Stage traceability preserved on every other ADR.

Improvement outcome candidates:

- Architecture rework with constraint to not split into new parts: see new improvement above. Added.
- Verify which files actually changed before claiming preserved: see new improvement above. Added.

Similar memory check:

- Similar improvements found: none covering the rework-without-split constraint; existing "Closure doc sweep part-file split" covers the opposite case (closure adds part file).
- Existing improvement "Self-claim format verification in review subjects" partially covers preservation verification but is specific to review subjects self-claiming format properties.

Decision:

- Add new improvement for rework-without-split constraint.
- Add new improvement for content-only diff verification after LF normalize pass.

Memory update:

- Final improvement outcomes stored: see "Improvement: Architecture rework with constraint to not split into new parts" and "Improvement: Verify which files actually changed before claiming preserved" above.

## Improvement: Plan-vs-design wording tension on folded-vs-retained helpers

Condition:

- Reviewing implementation plan where the design document says an existing helper is "folded into tx_X as inline worker call; no separate completion handler" but the plan text says the same helper "remains as a private helper used by the inline implementation" (or similar)

Action:

- Do cross-read design Part 3 (or equivalent migration table) row for each helper the plan claims to retain. Do flag plan/design wording tension as non-blocking observation, not blocking finding. Do recommend the implementation author pick one wording (either fully inlined or retained as private seam) and align the other doc to match before coding starts. Do not block plan review when the underlying operation result is identical and the wording difference is about source-organization preference. Do record the observation in the review's Required corrections or Non-blocking section so Developer can resolve during implementation.

## Post-task review 2026-06-25: Stage 25 implementation plan review

Task completed:

- Yes

Effectiveness assessment:

- Reviewed 7 plan files (entry + 6 parts) against 7 design files (entry + 6 parts) + 9 architecture parts + current code (server-cache-hybrid.cpp/h, server-context.cpp, test-cache-controller.cpp). All 8 tx_* methods covered, 6 OQs resolved with rationale, 10 new tests scoped (TP-25-UT1..UT10), 8 risks identified with mitigation, 12-step order sound, lock semantics sound, worker retirement Option B applied, OQ-25-01 SPLIT correctly explained, slot lifecycle call sites at lines 6362/6516/6859 verified against code, and unchanged call sites at lines 1087/1858/1881/1886/4080/4201 verified.
- Hygiene verified byte-level on all 7 plan files: LF-only, no BOM, no trailing whitespace. git diff --check --no-index per file returned empty (clean).
- 3 of 8 open impl questions need architect confirmation (OQ-25-IMP-02 io_worker.execute_inline signature, OQ-25-IMP-03 tx_apply_restore argument shape, OQ-25-IMP-06 runner git SHA). The other 5 have sound proposed resolutions.
- 1 design-vs-plan wording tension observed (handle_demotion_completion retention wording differs between design Part 3 row 3 and plan Part 1 Step 3).
- 1 build-directory naming inconsistency observed in plan Part 3 (build-cov for Release tests vs build-coverage for Debug coverage).

Improvement outcome candidate:

- Plan-vs-design wording tension on folded-vs-retained helpers: see new improvement above. Added.

Similar memory check:

- Similar improvement found: none covering plan-review wording cross-check.
- Existing improvement "Verify test-report counts before applying closure text" covers a different verification (counts, not wording).
- Existing improvement "Self-claim format verification in review subjects" covers format claims, not implementation-vs-design wording.

Decision:

- Add new improvement for plan-vs-design wording cross-check on helpers that are partially folded.

Memory update:

- Final improvement outcome stored: see "Improvement: Plan-vs-design wording tension on folded-vs-retained helpers" above.

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

- Closure sweep task lists specific stale phrases to remove (e.g., "current gate: test execution", "ready for QA", "open"); grep finds matches that are legitimate technical uses (file names like part-06-open-questions.md, "open transactions" in technical sense, "open items" in triage sense)

Action:

- Do distinguish legitimate technical matches from stale-status matches before claiming grep clean. Do report grep result as "clean" only when all matches are legitimate (file names, technical vocabulary, historical quoted findings). Do not blanket-replace "open" without context check; file names and technical vocabulary are real. Do verify closure-purpose phrases (status: closed, D-CLOSURE-NN-NN, current gate: terminal) are present in all touched entry docs and handoff sections. Do list each touched file with closure phrases added in the return message so user can verify the swap.

## Improvement: Programming symbols with trailing asterisk in markdown prose

Condition:

- Authoring durable markdown design / review docs on Windows that reference programming symbols whose names contain a trailing or internal asterisk (e.g., `tx_*`, `n_*`, `foo_*`, `obj*`); the markdown linter flags MD037 (Spaces inside emphasis markers) when the symbol appears in prose with surrounding spaces or punctuation

Action:

- Do wrap the symbol in backticks every time it appears in prose or table cells (`` `tx_*` ``). Do not rely on the symbol appearing inside an existing code-fence to escape the linter; linters still parse emphasis markers outside code-fences. Do run a final grep before declaring done for any of: `* `, ` *`, `_*`, or any text-fragment-with-asterisk pattern and confirm each match is inside backticks or a code-fence. Do verify own deliverables byte-level after authoring on Windows (CR=0, no BOM, no unicode, no trailing whitespace). Don't ship design docs with MD037 errors when the fix is backtick-wrapping.

## Post-task review 2026-06-25 (Stage 26 design authoring)

Task completed:

- Yes

Effectiveness assessment:

- Authored Phase 26 design (entry doc + 7 part files in `._design_docs/cache-handling-phase26-design/`) covering 3 goals: Stage 24 + 25 carry-over resolution, Prometheus metrics alignment to upstream `llamacpp:` convention, and Stage 24 S02/S03 rerun. Entry doc 100 LF, part-01 45, part-02 136, part-03 129, part-04 113, part-05 111, part-06 109, part-07 88. All under 300-line cap. CR=0, no BOM, no unicode, trailing LF on every file. `git diff --check` clean on every file. No linter errors after the trailing-newline + backtick fix pass.
- Initial create_file pass on Windows inserted CRLF (CR=99..136) and linter flagged MD047 (no trailing newline) on every file plus MD037 on `tx_*` references in entry doc, part-01, part-05. Fixed via the existing CRLF rule: WriteAllBytes after stripping 0x0D and appending trailing LF. Replaced bare `tx_*` with backticked `` `tx_*` `` via multi_replace_string_in_file. Then re-verified CR=0 LF=line count last=0x0A first3=ASCII on all 8 files in one normalization pass.
- Survey of metric inventory: 37 `llamacpp_X` metrics to rename to `llamacpp:X`, 30 `cache_X` metrics to prefix with `llamacpp:`, 1 duplicate `mode` label on `cache_prompt_evidence_records_total` line 4537 (helper at line 4359-4368 already adds `mode` but caller at 4537 passes `"mode"` as label_a_name, producing `{mode=...,mode=...}`). Total 67 metrics renamed; `mode` duplicate resolved by renaming caller-side `"mode"` to `"scope"`.
- Carry-over inventory (part-01) lists 5 issues: D-EXEC-24-03-a SEH handler, D-EXEC-24-03-b widen silent-crash to S02 hybrid earlier-crash, D-EXEC-24-03-c cold-store metric drift (5.78 GiB on disk vs 352 MiB metric), PF-03 cross-stage latency evidence gap, Stage 25 S02 hybrid confirmation. Implementation order (part-06) sequences SEH handler before cold-store accounting before metrics rename before fixture update before Stage 24 rerun so each step has a buildable binary and produces incremental evidence.

Improvement outcome candidate:

- Condition: When authoring durable markdown design docs that reference programming symbols whose names contain trailing or internal asterisk characters (e.g., `tx_*`)
- Action: Do wrap the symbol in backticks every time it appears in prose or table cells; do not rely on surrounding code-fences; do run byte-level format verification on Windows after authoring.

Similar memory check:

- Similar improvement found: No
- Existing CRLF rule covers the byte-level fix; existing pipe-escape rule covers table-cell special chars; neither addresses MD037 from asterisks in programming symbols. The CRLF rule and the asterisk rule both surface on Windows-authored markdown; combining them in one byte-level pass per file is the cleanest enforcement pattern.
- Decision: Add new improvement.

Memory update:

- New improvement `Programming symbols with trailing asterisk in markdown prose` stored above; post-task review appended.


## Improvement: Stage design part-02 metric count claims vs source ground truth

Condition:
- Reviewing stage design whose part-02 (rename map) cites a specific count of metric renames (37 + 30 = 67) and runner/fixture-script reference count (e.g., 6 metric-name references in stage24-chat-s02-s03-comparison.ps1 lines 30..36) that the author did not verify against source

Action:
- Do run grep_search for each named metric prefix in the actual source file (e.g., 	ools/server/server-context.cpp for the llamacpp_X callsites) and in each named script before accepting the count. Do count unique callsites and unique script occurrences with raw matching, not summary line ranges. Do record count mismatches as non-blocking finding with corrected count, not as blocking gate failure, when underlying rename contract holds. Do verify runner MetricNames = @(...) array length when part-02 names runner line range.

## Improvement: Hard rename impact radius includes durable design + test reports, not just fixture scripts

Condition:
- Stage design proposing HARD RENAME of public Prometheus metric names (public API breaking change) and explicitly enumerating fixture script updates but omitting the fact that prior-stage test reports and prior-stage design part files already quote the OLD metric names by example (llamacpp_cache_X)

Action:
- Do run grep_search for the OLD prefix across all ._design_docs/** to enumerate durable-doc references. Do record count and locations as non-blocking observation: durable docs may be left as historical record of OLD names because they describe prior-stage evidence, but entry-doc Contents and any current operational doc should be updated to NEW names. Do not flag as blocking when durable docs are historical record and quote is in a one-time test report. Do recommend explicit entry in part-02 or architecture-invariant section listing which durable-doc categories are updated and which are left as historical.

## Improvement: Stage 26 part-04 cold-store accounting fix lists eviction sites incompletely

Condition:
- Stage design (part-04 cold-store drift fix) identifies a hypothesis (counter not decremented on disk-removal path) and lists 3-4 specific eviction sites in fix-step 4 to apply per-id byte map decrement; actual source has additional eviction/cleanup sites the design does not enumerate

Action:
- Do run grep_search for the relevant counter increment and decrement callsites in 	ools/server/server-cache-hybrid.cpp and verify each named site in design's fix-step list. Do record sites not in design list as non-blocking observation. Do verify the BYTE DECREMENT path (cold_store.delete_ids + descriptor erase) is explicitly listed. Do not flag as blocking when fix's intent (decrement on every disk-removal path) covers the additional sites implicitly via call-graph reachability, but do recommend adding explicit callout for any cleanup path that deletes files WITHOUT going through named eviction functions.

## Improvement: Tight-scope rework respects file boundary even for non-blocking items

Condition:
- Task brief says tight scope (e.g., 'fix the counts only') AND lists non-blocking items that target OTHER files, while hard constraint says 'DO NOT modify other files beyond what these fixes require'

Action:
- Do limit edits strictly to the file(s) named by the BLOCKING fix descriptions. Do report non-blocking address ratio as X/N honestly with one-line deferral reason. Do run grep_search verifications for non-blocking items and include findings in the response as INFO without committing them to docs. Don't expand scope to non-blocking items even when addressing them is cheap and within reach. Don't silently skip the non-blocking items; surface them in the response so the next owner can decide.

## Improvement: Re-review count fixes require file-line match verification

Condition:

- Re-reviewing design after rework that claimed to fix a BLOCKING count mismatch (e.g. part-02 said "6 references" when actual file had 10)

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

## Post-task review 2026-06-26 (Stage 28 design authoring)

Task completed:

- Yes

Effectiveness assessment:

- Authored Stage 28 design (Technical Debt Removal + Open Bug Fixes) per user direction 2026-06-26 "remove all technical debt and fix all known open bugs". Six LF-only UTF-8 no-BOM files: entry doc (131 lines), part-01 tech-debt inventory (198 lines, 21 items: 3 HIGH/7 MEDIUM/11 LOW), part-02 known-bug fix design (217 lines, 3 bugs with diagnosis), part-03 prioritized fix order (143 lines, 3 iterations), part-04 verification plan (130 lines, per-fix V-rows), part-05 risks (147 lines, per-fix + cross-cut + 5 OQ). All under 300-line cap. CR=0, BOM=False, non-ASCII=0, trailing LF on all six. Also updated `._design_docs/document-index.md` to add one Stage 28 row.
- Caught one substantive design ambiguity during authoring: the Stage 27 closure cited `tests/test-cache-controller.cpp:3645 assert` as NDEBUG-disabled, but the file actually undefines NDEBUG at line 22, so asserts are active in this TU. Real root cause is inconsistent abort pattern (`assert()` vs explicit `std::abort()` -> `__fastfail(FAST_FAIL_FATAL_APP_EXIT)` = 0xC0000409). Recorded the corrected root cause in part-02 R28-BUG-01 root cause confirmation section, with line references verified by read_file. The Stage 27 closure's wording was imprecise but the fix scope was correct.
- Diagnosed the cold-store drift direction empirically: filesystem 5.37 GiB (102 files of exactly 50.25 MiB each) vs metric 502 MiB (10 entries). Per-id map sum = filesystem bytes would require all 102 entries tracked; metric < disk means orphan files exist. Three candidate root causes (A: cold_budget_make_room early-continue, B: write-without-map path, C: cleanup-loop delete-without-map) listed with directional analysis: Candidate A would INCREASE metric, not decrease, so cannot be the orphan source; diagnosis step is mandatory before fix shape is final.
- All six files cleaned via the existing byte-level normalize workflow: read bytes, filter 0x0D, WriteAllBytes. Verified CR=0, last=0x0A (LF), first3='# S' (no BOM), line count via Get-Content. git diff --check clean on all 7 modified/added files.

Improvement outcome candidate:

- Condition:
  - Authoring multi-file durable design for stage with binding scope (technical debt inventory + bug fix catalog)
- Action:
  - Do verify each closure-cited root cause against actual source code in the same task; do not trust prior closure part-file wording when it cites line numbers or abort patterns that are slightly off
  - Do compute drift direction empirically before listing candidate fixes; do flag the candidate whose direction does not match observed evidence and require a diagnosis step
  - Do pre-allocate a single 300-line cap budget per part file and split into more parts rather than exceeding the cap with combined fix-design + verification + risks

Similar memory check:

- Similar improvements found: "Latest follow-up state before stage baseline PASS" (covers reading latest follow-up before referencing closure), "Closure sweep preserves historical failure headings" (covers not rewriting prior closure text), "Pre-fix line citations in post-fix handoff text" (covers stale line-number citations).
- Gap: prior improvements cover REVIEW of stale closure wording, but not AUTHORING of design that USES a closure-cited root cause as its baseline. The new improvement is about author responsibility to verify cited root cause against source, even when closure text appears authoritative.

Decision:

- Add new improvement because the pattern surfaced explicitly: the Stage 27 closure said "assert silently no-ops under NDEBUG" and cited line 3645, but the file has `#undef NDEBUG` at line 22 making the assertion active. An Architect authoring a follow-up design that inherits the closure wording without verifying would carry forward the imprecision into Stage 28.

Memory update:

- New improvement `Closure-cited root cause must be verified against source before inheritance` stored below.

## Improvement: Closure-cited root cause must be verified against source before inheritance

Condition:

- Authoring new stage design or design correction that inherits a root cause analysis from a prior stage closure part-file (e.g., D-EXEC-NN root cause), and the prior closure cites specific line numbers, abort mechanisms, or NDEBUG/CONFIG_NDEBUG behavior

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

- Investigating async worker code as technical debt after a prior stage design declared it retired (e.g., Stage 25 worker retirement Option B chose "replace with stateless helper") but the methods, the worker thread, and the no-op stub still exist in the source tree

Action:

- Do grep_search for every method name (class, start/stop, enqueue_*, process_*, drain_*, handle_*_completion, worker_thread_func, debug_*_for_tests) across tools/server/, tests/, and any documented test helpers. Do classify each match as prod, test-only, or dead before deciding fix approach. Do specifically check whether the worker thread is actually started in the production constructor (not just declared) and whether no-op stubs are wired into production wait loops that burn wall-clock time. Do surface broken production paths (hang or descriptor leak) as new HIGH bugs even when the original task scoped the investigation as MEDIUM. Do promote the deletion to MEDIUM iteration 2 with explicit conditional (compile-clean Phase B first) rather than leaving it deferred to a future stage when the user asks the investigation in-scope. Do not trust comment text claiming the worker is "retained for source compat" without verifying the callers actually exist and the path is non-broken.

## Improvement: Plan-review deliverable filename table must match actual part-file naming

Condition:
- Reviewing implementation plan whose deliverable table in part-05 (open questions) or similar summary section lists part-file paths that do not match the actual filenames in the same plan directory

Action:
- Do grep the plan directory for actual part file names (part-01*.md, part-02*.md, etc.) before reviewing. Do flag any deliverable table row referencing a stale filename (e.g., part-01-ordered-implementation-steps.md when actual files are part-01a-*.md + part-01b-*.md). Do record as non-blocking observation since the entry doc links the correct filenames and the stale references are cosmetic; the developer doesn't follow these as implementation instructions. Do verify entry doc link table matches actual filenames since entry doc is the navigation surface.

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

## Improvement: Cache-mode A/B comparison requires post-Stage-26 metric reconciliation

Condition:

- Authoring stage design for legacy-vs-hybrid cache-mode A/B comparison; original proposal or prior design references metrics in pre-Stage-26 underscore form (`llamacpp_cache_X`) or no-prefix form (`cache_X`); Stage 26 metrics alignment closed the underscore form

Action:

- Do explicitly call out the post-Stage-26 metric reconciliation in the design part file that lists the per-request metric inventory. Do replace every pre-Stage-26 metric reference with the post-Stage-26 `llamacpp:cache_X` colon-prefix form. Do add a driver-side grep assertion that fails any leg emitting underscore-form metrics as `FAIL-metric-format-regression`. Do not silently inherit the proposal's mixed pre/post-Stage-26 names; cite the Stage 26 design part-02 metric rename map as the binding contract.

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

## Improvement: VERDICT-line review report format compliance

Condition:

- Task instruction explicitly requires "VERDICT: PASS" or "VERDICT: REWORK" line at top of review file (plain ASCII, no emoji)

Action:

- Do put the VERDICT line as the first line of the file before any heading; do suppress Markdown linter MD041 (first-line-heading) on this row by user override. Do still ensure trailing newline (MD047), LF-only (no CR), no BOM, no trailing whitespace, and under 300 lines. Do run git diff --check on the review file. Do convert Windows tool-inserted CRLF to LF by stripping all 0x0D bytes and writing back via [System.IO.File]::WriteAllBytes. Do not pad a separate blank line after the VERDICT row if the user wants the verdict on the first line of the file.




## Improvement: create_file with dot-prefixed Windows paths lands in wrong directory

Condition:

- Using create_file with an absolute path under a dot-prefixed directory on Windows (e.g., d:\source\llama.cpp-jet\._design_docs\...)

Action:

- Do verify the resulting file path with Test-Path after creation. Do not assume the dot-prefix is preserved. Do move or rewrite the file to the correct path if it landed elsewhere (typical wrong-path is _design_docs\... without leading dot). Do delete the wrong-path file before continuing with format checks. Do record the correct path before running byte-level CR/LF/BOM checks. Do not rely on the tool success message alone. Do not read content from the wrong path and assume it is the intended file.
## Post-task review 2026-06-28 (Stage 29 implementation review)

Task completed:

- Yes

Effectiveness assessment:

- Authored Stage 29 implementation review part-06-impl-review-20260628.md in a NEW fresh Architect session (2026-06-28). Verdict PASS, 0 BLOCKING, 0 NON-BLOCKING, 5 INFO. Report is 207 LF, CR=0, BOM=False, non-ASCII=0, last byte 0x0A, trailing whitespace 0, under 300-line cap. git diff --check --no-index against empty temp file reports no whitespace warnings.
- Verified all 6 implementation deliverables byte-level: compare-legacy-vs-hybrid.ps1 (228 LF), compare-legacy-vs-hybrid.README.md (176 LF), 4 lib helpers (81/101/88/90 LF). Verified wrapper script unchanged (200 LF, 0 diff lines, mtime before Stage 20 lib).
- Verified all 6 helper call-sites in driver against actual lib helper signatures; no fabricated parameters (no recurrence of the prior review's B-01 defect).
- Live driver execution: -DryRun exit 0 prints BLOCKED-preflight JSON; -OutputEquivalenceOnly exit 4 prints BLOCKED-server-not-running.
- Live dot-source smoke test of all 4 lib helpers exposes 7 public functions.
- 5 INFO observations: impl entry doc at exactly 300 lines (boundary case, self-claims "under cap"); impl log says "17-param set" but driver has 18 params; impl log says "6 sub-checks" but Invoke-Preflight records 7 fields; impl log says "180s cap" but helper default is 120s and driver passes 120s; dry-run-stdout.txt git_dirty=16 vs dry-run.json git_dirty=17 (sequential captures).
- Three reusable patterns surfaced: (a) create_file with leading-underscore path on Windows silently writes to wrong path (created at d:\source\llama.cpp-jet\_design_docs\... instead of ._design_docs\...); (b) em-dash (U+2014) and check-mark (U+2713) characters survived in my own prose despite the prior CRLF/em-dash verification applies to own deliverables too improvement rule; (c) helper-default vs plan-claim parameter value drift surfaced as a documentation integrity issue.
- create_file failure root cause: tool likely normalizes leading dot in paths or treats .\_path as escape. Existing ead_file tool failure on dot-prefixed paths memory note covers reads but not writes.

Improvement outcome candidate:

- Condition:
  - Using create_file with an absolute path under a dot-prefixed directory on Windows (e.g., d:\source\llama.cpp-jet\._design_docs\...)
- Action:
  - Do verify the resulting file path with Test-Path after creation. Do not assume the dot-prefix is preserved. Do move or rewrite the file to the correct path if it landed elsewhere. Do delete the wrong-path file. Do record the correct path before continuing with format checks. Don't rely on the tool's response message alone.

Similar memory check:

- Similar improvement found: Partial
- Existing improvement:
  - read_file tool failure on dot-prefixed paths; CRLF/em-dash verification applies to own deliverables too; CRLF and trailing whitespace on Windows tool-inserted content
- Decision: Add new improvement because the dot-prefix path bug is specifically a write/create_file issue (not the existing read_file note), and the recovery pattern (verify path, copy with LF conversion, delete wrong-path) is concrete and reusable.

Memory update:

- Added Improvement: create_file with dot-prefixed Windows paths lands in wrong directory.

## Improvement: create_file on Windows inserts CRLF and non-ASCII chars

Condition:

- Authoring durable review report (or any markdown file) via `create_file` on Windows host; user hard constraint requires "ASCII only, LF line endings, no BOM, no trailing whitespace"; author writes content with em dash (U+2014), multiplication sign (U+00D7), or other non-ASCII characters naturally in text

Action:

- Do read raw bytes after `create_file` to confirm CR=0 and non-ASCII=0. Do strip CR bytes via `[System.IO.File]::ReadAllBytes` + `Where-Object { $_ -ne 0x0D }` + `WriteAllBytes`. Do scan for any byte > 0x7F and identify whether the sequence is UTF-8 multi-byte (e.g., 0xE2 0x80 0x94 = em dash, 0xC3 0x97 = multiplication sign). Do replace em dash with `--`, multiplication with `x`, right-arrow with `->`, and other punctuation with ASCII equivalents before byte-level check. Do verify last byte is 0x0A after the CR strip. Don't trust `create_file` to honor the "ASCII only" constraint even when the author thinks they wrote ASCII. Don't use `ReadAllText` then `WriteAllText` for the CR strip; the round-trip preserves CR. Do use `WriteAllBytes` from the byte array.

## Improvement: MD041 verdict-first vs MD056 column-count defect

Condition:

- Authoring review file with explicit `VERDICT: PASS|REWORK` line as first content line per task contract; linter (markdownlint) reports MD041 (first line should be heading) and MD056 (table column-count mismatch on later rows)

Action:

- Do fix MD041 by adding `# Title` as the first line and moving VERDICT below it as a section. Do fix MD056 by counting pipes in every row against the table header; if a row has fewer pipes than the header, do fix that row by splitting the long cell content (e.g., File+Line combined) into separate File and Line cells, or moving long content to a follow-up paragraph. Don't treat MD041 and MD056 as the same defect. Don't suppress MD041 to keep VERDICT as first line; user contract allowing VERDICT first is overridden by lint convention. Don't ignore MD056 as a false positive; it is a real column-count defect that downstream consumers parse.

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
