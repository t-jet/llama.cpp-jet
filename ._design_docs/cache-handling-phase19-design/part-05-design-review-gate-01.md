# Part 5: Stage 19 design review (Architect, fresh session)

Status: PASS
Date: 2026-06-18
Stage: 19 (System-Level Model Warmup Crash Investigation)
Reviewer: Architect (design review, fresh session)
Scope: Stage 19 design review only. Not re-review of Stage 17 or Stage 18,
not implementation, not test plan, not Stage 20.

## Inputs reviewed

| File | LF lines | Notes |
| --- | --- | --- |
| _design_docs/cache-handling-phase19-design.md | 62 | Entry doc (62 LF / 48 content lines, under 300) |
| _design_docs/cache-handling-phase19-design/part-01-question-disposition-and-reproduction.md | 88 | Question, three-branch disposition, reproduction plan |
| _design_docs/cache-handling-phase19-design/part-02-root-cause-analysis-and-fix-proposal.md | 114 | Root cause analysis (Step 1-3), Branch A/B/C fix proposals |
| _design_docs/cache-handling-phase19-design/part-03-test-plan-closure-traceability.md | 48 | 4 test plan rows, closure criteria, traceability |
| _design_docs/cache-handling-phase19-design/part-04-risks-open-questions-handoff.md | 50 | R-19-DESIGN-01..04, OQ-19-DESIGN-01..02, handoff |

Reference (read for context):

- _design_docs/cache-handling-phase18-implementation.md (D18-CLOSURE-01 substantive finding, 2026-06-18)
- _design_docs/.test_reports/test-report-20260618-01-rerun.md (Stage 18 test rerun, 14 PASS / 0 FAIL)
- _design_docs/cache-handling-phase17-implementation.md (D17-EXEC-02 baseline crash, 2026-06-17)
- _design_docs/.test_reports/test-report-20260617-01-fixes.md (fit_params 9933 MiB vs 1466 MiB baseline)
- _design_docs/.test_reports/test-report-20260617-01-developer-review.md (I17-BUGFIX-01 environmental classification)
- _design_docs/cache-handling-stage-tracker.md (Stage 18 row closed, Stage 19 row added)
- include/llama.h (line 555 `llama_get_memory`, line 774 `llama_memory_can_shift`)

Verification commands executed (read-only):

- `git log --oneline -3 -- tools/server/server-context.cpp` returned HEAD `cb93f3dbd` matching design prerequisite.
- `git status --short` showed 1 modified file (cache-handling-stage-tracker.md +1 line Stage 19 row) and 5 untracked files (the 5 stage 19 design files). No other working-tree changes.
- `git diff HEAD --stat` returned 1 file, 1 insertion (tracker only).
- `git diff HEAD -- ._design_docs/document-index.md` returned 0 (no doc-index update for stage 19 yet).
- `Get-Item build-cov/bin/Release/llama-server.exe` returned Length=13312, LastWriteTime=2026-06-18 02:17:04 (matches design prerequisite).
- `Test-Path ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf` returned True (fixture available for baseline reproduction).
- Read-file byte-level inspection of all 5 design files: CR count 0, LF count matches, BOM=False, non-ASCII count 0 in each file.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'cache_ram_mib'` returned 6 matches at lines 1249 (gate), 1528/1529/1532/1542 (cache controller creation block at line 1528+), 1664 (cache disable check).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'common_init_from_params'` returned 1 match at line 1292 (matches design claim).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'cache-cold-path requires --cache-mode hybrid'` returned 1 match at line 1283 (inside validation block; post-slot-init duplicate at 1554-1557 confirmed deleted by Stage 18 Item 1).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'cache-cold-max-mib requires --cache-mode hybrid'` returned 1 match at line 1277 (inside validation block).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'slots.emplace_back'` returned 1 match at line 1455 (design claims line 1442; off by 13).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'slot.reset\('` returned 1 match at line 1500 (design claims line 1497; off by 3).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'mctx = mtmd_init_from_file'` returned 1 match at line 1389 (design range 1372-1400 contains it; off).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'model_dft.reset\(llama_model_load_from_file'` returned 1 match at line 1331 (design range 1308-1370 contains it; off).
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'fit_params'` returned 9 matches; `SRV_INF` lines at 1135 and 1235 log fit_params projection values to server.err.log (matches design Step 3 evidence capture).
- `Get-Content include/llama.h | Select-String -Pattern 'LLAMA_API.*llama_get_memory'` returned 1 match at line 555 (confirms Branch A fix API).
- `Get-Content include/llama.h | Select-String -Pattern 'LLAMA_API bool llama_memory_can_shift'` returned 1 match at line 774 (confirms Branch A fix API).
- `git -C d:/source/llama.cpp-jet diff HEAD -- ._design_docs/cache-handling-stage-tracker.md` confirmed 1-line insertion for Stage 19 row matching design prerequisites.

## Verification checklist

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Three-branch disposition (A/B/C) clearly mapped | PASS | part-01 lines 11-32: Branch A (code-related fix), Branch B (environmental follow-up), Branch C (no reproduction close) each with closure path and criteria. |
| 2 | Baseline reproduction command correct (no cache flags, default values) | PASS | part-01 lines 44-50: command is `build-cov\bin\Release\llama-server.exe --port 18220 --model ._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf` with explicit "No `--cache-mode`, no `--cache-ram-mib`, no `--cache-cold-path`, no `--cache-cold-max-mib`, no `--cache-prompt-evidence`, no `--cache-prompt-evidence-dir`, no `--log-prompts-dir`" prohibition. Qwen3-0.6B fixture verified present. |
| 3 | Reproduction run matrix adequate | PASS | part-01 lines 60-67: RT1.1 single launch, RT1.2 5x repeat for memory accumulation, RT1.3 port-shift (18221) for port-conflict isolation, RT1.4 process watcher for crash-site timing. 5x repeat count justified by Stage 17 D17-EXEC-02 evidence (3/3 deterministic). |
| 4 | Step 1 (validation gate verification) methodology | PASS | part-02 lines 13-26: Select-String on `if \(params_base.cache_ram_mib != 0\)` is correct gate string. Expected 1 match verified (line 1249 gate, no duplicate after Stage 18 Item 1 deletion). |
| 5 | Step 2 (crash site localization) candidate line ranges cover load_model | PASS (with F-19-DR-01) | part-02 lines 28-55: function structure from 1108 to 1500+; candidates at `common_init_from_params` (1292), `model_dft` init (1331), `ctx_dft` MTP init (1374), `mctx` init (1389), `slots.emplace_back()` (1455), `slot.reset()` (1500). All sites covered; line numbers have minor drift from design claims. |
| 6 | Step 3 (environmental vs code-related) methodology sound | PASS | part-02 lines 57-67: `Get-Process` baseline working set, total system available memory via `Get-CimInstance Win32_OperatingSystem`, `fit_params` projection from `server.err.log`. Decision rule (projection > 5000 MiB AND system mem below projection -> Branch B) is reasonable threshold. `fit_params` projection verified to log via `SRV_INF` at server-context.cpp:1135 and :1235. |
| 7 | Branch A fix proposal (similar to Stage 18 fix) technically feasible | PASS (with F-19-DR-04) | part-02 lines 71-77: 3-step fix mirrors Stage 18 style. API `llama_memory_can_shift(llama_get_memory(ctx_tgt))` verified at include/llama.h:774 (returns bool) and :555 (returns llama_memory_t). Both APIs exist; guard expression is valid C++. |
| 8 | Branch B no-fix proposal (environmental follow-up) appropriately scoped | PASS | part-02 lines 79-82: explicit "No code fix" + "Surface as new separate stage (Stage 19 follow-up or Stage 21)". Closure criteria in part-01 lines 22-24 requires system-state evidence (memory snapshot, fit_params log) and Manager closure follow-up decision. |
| 9 | Branch C close-no-fix proposal (no reproduction) defensible | PASS | part-01 lines 26-32: closure criteria is 5 successive baseline launches all reach /health 200 with stable memory snapshot. Defensible because Stage 18 fix moved validation block before warmup at lines 1242-1291; remaining crash source must be independent of cache flags and would require separate investigation. |
| 10 | TP-19-RT1 (baseline 5x repeat) adequate for crash reproduction | PASS | part-03 line 13: integration reproduction row, baseline launch 5x, expect clean /health 200 each run. RT1.2 in part-01 line 63 confirms 5x count. |
| 11 | TP-19-RT2 (baseline + memory snapshot) adequate for environmental classification | PASS | part-03 line 14: integration reproduction row, baseline launch with system memory snapshot before/after, expect working set stable. Provides Branch B evidence per Step 3 methodology. |
| 12 | TP-19-RT3 (Stage 18 regression smoke) adequate for no-regression guarantee | PASS | part-03 line 15: integration regression row, Stage 18 IT1 + IT3 cache-flag-induced paths still PASS. Aligns with Stage 18 test plan part-28 smoke check coverage. |
| 13 | TP-19-FT1 (crash signature fixture, conditional on Branch A) adequate | PASS | part-03 line 16: focused signature row, conditional on Branch A selection, captures crash signature (size, address, stack frame count) for future regression. Conditional scope is appropriate. |
| 14 | Each item maps to source decision (D17-EXEC-02, D18-CLOSURE-01) | PASS | part-03 lines 30-38: traceability table maps design components to D17-EXEC-02 (Branch A/B/C question, reproduction plan, RCA Step 3), D18-CLOSURE-01 (validation block gate analysis, Branch C), F-17-EXEC-01 row 14 (RT1.1 baseline evidence source), part-06 architect bugfix review row 14 (RT1.2 repeat count), part-06 row 16 (RCA Step 2 crash site candidates), Stage 18 fix line range (RCA Step 1). Six source decisions traced. |
| 15 | Risks R-19-DESIGN-01..04 have owners and mitigations | PASS | part-04 lines 6-15: four risks with severity (medium/low), description, mitigation. R-19-DESIGN-01 (cache_ram_mib gate baseline gap) mitigated by RT1.1. R-19-DESIGN-02 (memory pressure drift since 2026-06-17) mitigated by RT2 snapshot. R-19-DESIGN-03 (Branch A fix scope depends on crash site) mitigated by conditional fix proposal framing. R-19-DESIGN-04 (Branch B follow-up not pre-defined) mitigated by Manager closure decision. |
| 16 | Open questions have explicit recording path | PASS | part-04 lines 18-24: OQ-19-DESIGN-01 (cache_ram_mib != 0 gate vs user-facing flag behavior, esp. when --cache-cold-path without --cache-ram-mib) recorded as out-of-scope for Stage 19, routed to Stage 20. OQ-19-DESIGN-02 (pre-define fix per Branch vs wait for evidence) resolved by Design pre-defines Branch A conditional fix; Branch B/C do not require fixes. |
| 17 | Entry doc under 300 lines | PASS | Entry doc 62 LF / 48 content lines (Get-Content Measure-Object Line count). |
| 18 | Each part file under 300 lines | PASS | part-01 88 LF, part-02 114 LF, part-03 48 LF, part-04 50 LF. All under 300-line cap. |
| 19 | LF line endings, no CRLF, no BOM | PASS | All 5 files byte-level inspected: CR count 0, LF count matches Get-Content count, BOM=False. |
| 20 | No unicode icons | PASS | All 5 files non-ASCII count 0. |

## Findings

| # | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-19-DR-01 | NON-BLOCKING | Line number drift in Step 2 candidate crash site table | part-02 lines 47-55 cites `slots.emplace_back()` at line 1442 (actual line 1455, off by 13), `slot.reset()` at line 1497 (actual line 1500, off by 3), `mctx` init at lines 1372-1400 (actual at 1389, within range but mid-range not endpoints), `model_dft` init at lines 1308-1370 (actual at 1331), `ctx_dft` MTP path at lines 1342-1366 (actual at 1374 for MTP, off by 8). | Developer session verifies exact line numbers from `git show HEAD:tools/server/server-context.cpp` before crash-site evidence capture; no design change required. |
| F-19-DR-02 | INFO | Step 1 verification text says "validation block at line 1242" but gate is at line 1249 | part-02 line 22 says "exactly 1 match (the validation block at line 1242...)" but `Select-String -Pattern 'if \(params_base.cache_ram_mib != 0\)'` returns the gate at line 1249, not 1242. The range "1242-1291" in entry doc prerequisites refers to the comment-to-end span (comment header at line 1242, gate at 1249, closing brace at 1290). | No action required; the design's "lines 1242-1291" range matches the actual block extent. The Step 1 verification text uses the range start (1242) as a landmark. |
| F-19-DR-03 | INFO | Document-index has no row for stage 19 yet | `git diff HEAD -- ._design_docs/document-index.md` returns 0 lines; the doc-index was last updated for stage 18 closure on 2026-06-18. The design doc and stage tracker row exist on disk but not yet indexed. | No action required at design review time. Doc-index row will be added after Manager design gate PASS, consistent with stage 17 and stage 18 doc-index update timing. |
| F-19-DR-04 | NON-BLOCKING | Branch A fix proposal uses valid APIs but exact crash site is undetermined | part-02 lines 71-77 Branch A fix references `llama_memory_can_shift(llama_get_memory(ctx_tgt))`. Both APIs verified at include/llama.h:555 and :774. However, Step 2 candidate sites span 1292-1500 (6 distinct candidates), so the Developer session must first localize the actual crash site before applying the conditional fix. The design's "Move the speculative decoding init and `slots.emplace_back()` loop into a guarded block" is a starting template, not a one-to-one patch. | Developer session localizes the crash site via Step 2 LAST log line comparison (part-02 line 32) before authoring the conditional fix in the implementation plan; no design change required. |

## Counts

- BLOCKING: 0
- Non-blocking: 2 (F-19-DR-01, F-19-DR-04)
- INFO: 2 (F-19-DR-02, F-19-DR-03)

## Verdict

**PASS.** The Stage 19 design correctly scopes the system-level model
warmup crash investigation to a three-branch disposition (A/B/C) that
explicitly addresses the gap left by Stage 18: the validation block
move at lines 1242-1291 resolves cache-flag-induced crashes but does
not exercise the baseline path (no cache flags), which is the path
Stage 19 must investigate. The baseline reproduction command uses no
cache flags and runs against the Qwen3-0.6B fixture, with a 5x repeat
matrix for memory-accumulation pattern detection. The Step 1-3 root
cause analysis methodology is sound: Step 1 verifies the validation
gate is correctly positioned before the model warmup step (confirmed
via Select-String at line 1249, range 1242-1291); Step 2 localizes
crash sites to six candidate ranges within `load_model` (1108-1500+)
with `common_init_from_params` at 1292 as the most probable site; Step
3 distinguishes environmental vs code-related via fit_params projection
(SRV_INF logs at 1135 and 1235) plus `Get-CimInstance Win32_OperatingSystem`
memory snapshot. The Branch A fix proposal is technically defensible
(both referenced APIs exist at include/llama.h:555 and :774) and
mirrors the Stage 18 style; Branch B and Branch C are appropriately
scoped with no-fix decisions and Manager closure follow-up paths.
The 4 test plan rows (3 integration + 1 focused, conditional) cover
reproduction, environmental classification, regression smoke, and
conditional crash signature fixture. The traceability table maps six
source decisions (D17-EXEC-02, D18-CLOSURE-01, F-17-EXEC-01 row 14,
part-06 row 14, part-06 row 16, Stage 18 fix line range). The four
risks (R-19-DESIGN-01..04) have severity and mitigation; the two open
questions (OQ-19-DESIGN-01..02) have explicit dispositions. All five
files are LF-only UTF-8 without BOM, under the 300-line cap, and free
of unicode icons. The two non-blocking findings (F-19-DR-01 line drift
in Step 2 candidates, F-19-DR-04 Branch A fix crash-site localization)
are Developer verification items for the implementation session, not
design defects.

## Handoff

Next owner: **Manager** for the design gate in a fresh session.

If Manager design gate PASS, the design advances to Developer for
reproduction execution (RT1.1-RT1.4, RT2, RT3) in a fresh session, then
to QA for test plan row execution per the Branch A/B/C outcome. The
stage 17 implementation log, stage 18 implementation log, tracker,
document-index, and any other durable doc are NOT modified by this
review. The four findings (2 non-blocking, 2 INFO) are tracked above
as Developer verification items; they do not block Manager gate review
or reproduction authorization.
