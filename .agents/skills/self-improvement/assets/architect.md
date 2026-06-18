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

- Do check live entry docs, active fix reports, correction-evidence status lines, correction part handoff sections, downstream design handoff, index summaries, top-level Status lines, current-status sections, handoff text, and linked gate-status part files before and after patching. Do distinguish historical quoted findings from current contradictions. Do keep durable gate-status locations in same state: reviewable, rework-required, manager-gate-ready, planning-open, approval-pending, approved, ready-for-QA, bug-fix-review-pass, implementation-re-review-pass, or blocked. Don't leave stale limitation, review-pending, awaiting-review, re-review-ready, handoff-closed, ready-for-review, ready-for-implementation, ready-for-re-review, or not-started wording after gate advances or while finding remains.

## Improvement: Misconfigured-probe diagnosis vs product bug

Condition:

- Architectural fix instructions for BLOCKED fixture-dependent row (e.g., public metrics row zero) where fixture capable but probe misconfigured

Action:

- Do trace probe start command against design-required flags and server stdout/stderr to confirm misconfiguration vs product bug. Do specify corrected start command with exact flag names from parser source. Do include focused-substitute evidence path with specific test names and assertion points. Don't leave row in generic BLOCKED state without corrected start command or substitute evidence citation.

## Improvement: Untracked or partly-tracked review doc paths

Condition:

- Adding or updating review part files in doc tree untracked or partly tracked by git

Action:

- Do track paths edited during task. Do verify contents directly with targeted reads, ripgrep, line counts, raw byte checks when `git diff` cannot show untracked content. Do separate task-local edits from pre-existing dirty paths and from older diffs inside the same index or tracker file before reporting. Do report task-local path list. Don't rely on `git diff` or `git status` alone to prove what changed. Before declaring referenced doc "not edited", do run `git status -- <path>` and read current contents; report as pre-existing rather than own work.

## Improvement: CRLF and trailing whitespace on Windows tool-inserted content

Condition:

- File-editing or content-creation tool on Windows inserts CRLF line endings or trailing whitespace while surrounding file is LF-only; `git diff --check` reports errors

Action:

- Do convert to LF-only by reading raw bytes, filtering out `0x0D`, and writing with `[System.IO.File]::WriteAllBytes` (or `[System.IO.File]::WriteAllText` with explicit UTF8-no-BOM but only AFTER a byte-level CR strip). Do NOT trust `ReadAllText` + `WriteAllText` alone; on Windows the read preserves CR and the write preserves CR. Do verify with raw byte inspection: no `0x0D` anywhere, no UTF-8 BOM, no trailing whitespace on any line. Do run `git diff --check` after conversion. Don't trust tool's default line endings. Don't use `Set-Content -NoNewline`; collapses file to single line. Don't trust `Measure-Object -Line` for line count; it counts only non-empty lines and can return a number much smaller than actual line count (e.g. 60 for an 86-line file). Do use `(Get-Content path).Count` or LF byte count for true line count. Don't claim EXITCODE alone proves cleanliness; report separately for new untracked, own entry-doc edits, pre-existing trailing whitespace user's edits didn't introduce. Don't use padded table-column style on new files if linter flags MD060; compact single-space padding satisfies rule.

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

## Improvement: Dependency graph completeness in plan reviews

Condition:

- Reviewing implementation plan where later steps add member variables to class and earlier-numbered steps add methods using those same variables, but dependency list on method-adding steps does not reference member-adding step

Action:

- Do trace each step's code changes to check that every member, function, or type referenced exists at point step's dependencies satisfied. Do flag any symbol introduced only in later step as blocking missing-dependency. Don't assume numerical step order implies correct dependency graph.

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

- Do record independent design review as PASS in the review report, entry doc, index, and tracker; do keep Manager design gate explicitly pending and name Manager as next owner. Do not imply code work is authorized until Manager gate passes, even if tracker status moves to implementation-planning per task instruction.

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