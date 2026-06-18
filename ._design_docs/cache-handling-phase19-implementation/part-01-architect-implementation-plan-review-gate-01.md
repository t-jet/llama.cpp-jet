# Part 1: Stage 19 implementation-plan review (Architect, fresh session)

Status: PASS
Date: 2026-06-18
Reviewer: Architect (implementation-plan review, fresh session)
Scope: Stage 19 implementation-plan review only. Not design re-review, not implementation execution, not test plan authoring, not Stage 20.

## Inputs reviewed

| File | LF lines | Notes |
| --- | --- | --- |
| _design_docs/cache-handling-phase19-implementation.md | 298 | Plan under review; 298 LF, CR=0, BOM=False, NonAscii=0, under 300-line cap |
| _design_docs/cache-handling-phase19-design.md | 63 | Design entry doc (PASS at Manager design gate) |
| _design_docs/cache-handling-phase19-design/part-01-question-disposition-and-reproduction.md | 88 | Three-branch disposition; reproduction plan; run matrix |
| _design_docs/cache-handling-phase19-design/part-02-root-cause-analysis-and-fix-proposal.md | 114 | Root cause analysis Step 1-3; Branch A conditional fix |
| _design_docs/cache-handling-phase19-design/part-03-test-plan-closure-traceability.md | 48 | 4 test plan rows; 5 closure criteria; traceability table |
| _design_docs/cache-handling-phase19-design/part-04-risks-open-questions-handoff.md | 50 | R-19-DESIGN-01..04; OQ-19-DESIGN-01..02; handoff |
| _design_docs/cache-handling-phase19-design/part-05-design-review-gate-01.md | 200+ | Architect design review PASS (0 BLOCKING, 2 non-blocking, 2 INFO) |
| _design_docs/cache-handling-phase19-design/part-06-manager-design-gate.md | 50 | Manager design gate PASS, 2026-06-18 |

Reference (read for context):

- _design_docs/cache-handling-phase18-implementation.md (D18-CLOSURE-01 substantive finding, 2026-06-18)
- _design_docs/cache-handling-phase17-implementation.md (D17-EXEC-02 baseline crash, 2026-06-17)
- include/llama.h lines 555, 774 (Branch A fix API references)

Verification commands executed (read-only):

- `git log --oneline -3 -- tools/server/server-context.cpp` returned HEAD `cb93f3dbd` on work-branch (matches design prerequisite).
- `git status --short` showed 2 modified files (cache-handling-stage-tracker.md, developer improvement memory), 8 untracked files (5 stage 19 design files plus 1 implementation plan and the directory). No uncommitted code change to `tools/server/server-context.cpp`.
- Byte-level inspection of plan file: CR=0, LF=298, BOM=False, non-ASCII=0.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'if \(params_base.cache_ram_mib != 0\)'` returned 2 matches at lines 1249 (validation block) and 1528 (cache controller creation block). Matches plan Step 2.1 claim.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'slots.emplace_back'` returned 1 match at line 1455. Matches plan Step 2.2 table.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'slot.reset\('` returned 1 match at line 1500. Matches plan Step 2.2 table.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'common_init_from_params'` returned 1 match at line 1292. Matches plan Step 2.2 table.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'mctx = mtmd_init_from_file'` returned 1 match at line 1389. Matches plan Step 2.2 table.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'model_dft.reset\(llama_model_load_from_file'` returned 1 match at line 1331. Matches plan Step 2.2 table.
- `Get-Content tools/server/server-context.cpp | Select-String -Pattern 'fit_params'` returned 9 matches; the two `SRV_INF` log lines for `fit_params` projection are at 1135 (mtmd) and 1232-1234 (spec), not 1235 as plan Step 2.3 states. Off by 1-3 lines.

## Verification checklist

### Reproduction plan

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Step 1.1 single baseline launch: command correct (no cache flags, default values) | PASS | Plan lines 47-66: command uses `--port 18220 --model ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf` only; no `--cache-mode`, no `--cache-ram-mib`, no `--cache-cold-*`, no `--cache-prompt-evidence*`, no `--log-prompts-dir`. Prohibits all cache flags. Health-probe loop 30 iterations at 2-second intervals. |
| 2 | Step 1.2 5x repeat for memory accumulation: methodology sound | PASS | Plan lines 68-72: 5 sequential launches with 5-second gap; captures per-launch lifetime, exit code, peak working set, last log line; rule-based detection (>10% peak working set growth = Branch B; 5x clean = Branch C). Detection rules explicit. |
| 3 | Step 1.3 port-shift: rules out port conflict; correct | PASS | Plan lines 74-76: ports 18220/18221/18222 sequentially; same metrics captured; Stage 17 D17-EXEC-02 evidence (3/3 deterministic) supports port-conflict exclusion. |
| 4 | Step 1.4 process watcher: StartTime/ExitTime/HasExited/ExitCode correct; last log line capture adequate | PASS | Plan lines 78-93: explicit capture of `Process.StartTime`, `Process.ExitTime`, `HasExited`, `ExitCode`; last log line via `server.err.log` read after exit; JSON record format with `lastLogLine` and `lastLogLineOffset` fields. Resolves F-19-DR-01 (line drift) by capturing actual lines from process output. |

### Analysis steps

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 5 | Step 2.1 validation gate verification: 2 matches expected (gate at 1249 + controller creation at 1528); not a duplicate | PASS | Plan lines 99-107: Select-String pattern matches the gate string; analysis correctly identifies line 1528 as the cache controller creation block (different from the validation block at 1249-1290). The 2-match observation is verified by the present review. Plan correctly notes the design text "1 match" is ambiguous and the actual count is 2 because the pattern also matches the post-slot-init controller creation. Not a defect. |
| 6 | Step 2.2 crash site localization: 6 candidate line ranges cover load_model | PASS | Plan lines 109-122: 6 candidate patterns (slots.emplace_back at 1455, slot.reset at 1500, mctx at 1389, model_dft at 1331, common_init_from_params at 1292, llama_init = common_init_from_params at 1292) cover the load_model function from line 1108 to 1500+. All 5 distinct sites covered; the last two patterns both resolve to line 1292 (redundant, see F-19-IPR-01). |
| 7 | Step 2.3 fit_params projection: SRV_INF 1135/1235 capture | PASS (with F-19-IPR-02) | Plan lines 124-128: Select-String for `fit_params`; cites SRV_INF at 1135 (mtmd) and 1235 (spec). Actual lines: 1135 matches; 1232-1234 is the spec SRV_INF span (off by 1-3 lines). Plan claims "9933 MiB vs 1466 MiB baseline" matches Stage 17 evidence in D17-EXEC-02. Branch B threshold of 5000 MiB matches design part 2. |
| 8 | Step 2.4 system memory snapshot: Get-CimInstance methodology | PASS | Plan lines 130-134: `Get-CimInstance Win32_OperatingSystem \| Select-Object TotalVisibleMemorySize, FreePhysicalMemory`; before/after delta is the working-set growth per launch. Methodology sound. |
| 9 | Step 2.5 branch determination: A/B/C verdict rule based on Step 2.1-2.4 evidence | PASS | Plan lines 136-144: 3-row verdict table maps Branch A (last log line + fit_params <= 5000 MiB + system memory ample), Branch B (fit_params > 5000 MiB AND system free memory low + system delta growing), Branch C (5x clean + working set stable). Rules are explicit and map back to design part 1. |

### Branch-specific action

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 10 | Branch A fix scope: minimal targeted, conditional on Step 2.2 crash site | PASS | Plan lines 148-156: 3-step conditional fix (move slot init into guarded block, replace throws with returns, add SRV_ERR log lines). Conditional on Step 2.2 localization. Fix template matches Stage 18 style (validation block move + throw to return). API references to `llama_get_memory` and `llama_memory_can_shift` verified at include/llama.h:555 and :774. Resolves F-19-DR-04 by deferring exact fix text to Step 2.2 evidence. |
| 11 | Branch B documentation: environmental classification, no code change | PASS | Plan lines 158-162: explicit "Do NOT modify code"; environmental classification (memory pressure, fit_params projection, system free memory); surface as new separate stage via `cache-handling-stage-tracker.md` Future stages row titled "System-level warmup environmental stability follow-up" (Manager closure follow-up). Maps to design part 1 Branch B closure path. |
| 12 | Branch C documentation: 5-successive-launch evidence, no code change | PASS | Plan lines 164-168: explicit "Do NOT modify code"; 5-successive-launch evidence (working set stable, all /health HTTP 200, no STATUS_STACK_BUFFER_OVERRUN); Stage 18 fix is sufficient as-is. Maps to design part 1 Branch C closure path. |
| 13 | All three branches map correctly to closure paths | PASS | Plan lines 170-172: Step 5 closure documentation cites the per-branch evidence file paths under `cache-handling-phase19-implementation/part-03-branch-{A\|B\|C}-*.md`. The 5-point closure criteria from design part 3 (lines 19-26) are reproduced at plan lines 174-181 and each branch step maps to one or more criteria. |

### Test plan execution

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 14 | TP-19-RT1 (5x repeat): adequate for crash reproduction | PASS | Plan lines 185-189: re-runs Step 1.2 5x repeat on post-Step-3 binary; per-launch JSON record with `startTime`, `exitTime`, `lifetimeSec`, `hasExited`, `exitCode`, `healthReached`, `peakWorkingSetMB`; writes to `._test_output/stage19-repro/RT1-results.json`. Branch-conditional expected outcomes explicit. |
| 15 | TP-19-RT2 (memory snapshot): adequate for Branch B | PASS | Plan lines 191-194: re-runs Step 2.3 and Step 2.4; output `._test_output/stage19-repro/RT2-memory-snapshot.json` with `totalMiB`, `freeMiB`, `fitParamsProjectionMiB`, and Branch B threshold check. Provides the evidence Branch B requires per design part 1 closure path. |
| 16 | TP-19-RT3 (Stage 18 regression): adequate for no-regression | PASS | Plan lines 196-198: runs Stage 18 IT1 + IT3 cache-flag-induced paths on post-Step-3 binary; expected PASS; uses Stage 18 test harness scripts unmodified. No-regression guarantee. |
| 17 | TP-19-FT1 (crash signature fixture): conditional on Branch A, no-op on B/C | PASS | Plan lines 200-205: focused signature fixture in `tests/test-cache-controller.cpp`; test function `test_stage19_baseline_crash_signature`; conditional on Branch A selection. Branch B and C are recorded as no-op with rationale. Maps to design part 3 row 4. |

### Closure documentation

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 18 | Per-branch evidence file paths under part-03-branch-{A\|B\|C}-*.md: correct | PASS | Plan lines 154, 161, 166, 187-205, 211-216: evidence file paths match the per-branch evidence plan (Branch A: branch-a-implementation-evidence.md, Branch B: branch-b-environmental-classification.md, Branch C: branch-c-no-reproduction.md). All paths under `._design_docs/cache-handling-phase19-implementation/`. |
| 19 | 5-point closure criteria from design part 3: complete | PASS | Plan lines 174-181: closure criteria 1-5 reproduced verbatim from design part 3 (lines 19-26). Each step (1-5) maps to one or more closure criteria. |

### Design-review findings addressed

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 20 | F-19-DR-01 (line drift): addressed in Step 2.2 | PASS | Plan lines 109-122: Step 2.2 uses `git show HEAD:tools/server/server-context.cpp \| Select-String -Pattern` to capture actual line numbers at HEAD before evidence capture. Resolves the line drift finding by making line capture a pre-evidence step. |
| 21 | F-19-DR-02 (gate line 1242 vs 1249): addressed in Step 2.1 | PASS | Plan lines 99-107: Step 2.1 explicitly uses the Select-String pattern that returns the gate at line 1249 and notes the "1242-1291" range is the comment-header-to-closing-brace span. Documents the design's "line 1242" wording as referring to the comment header landmark. |
| 22 | F-19-DR-03 (document-index): acknowledged (separate Manager activity) | PASS | Plan line "Design-review findings" table: F-19-DR-03 marked INFO; plan explicitly says "The document-index has no Stage 19 row yet. The doc-index update is a separate activity owned by the Manager closure cycle. No plan change here." Acknowledged without modification. |
| 23 | F-19-DR-04 (Branch A fix crash site): addressed in Step 2.2 + Step 3.1 | PASS | Plan lines 109-122 (Step 2.2 localizes crash site) and lines 148-156 (Step 3.1 applies conditional fix only AFTER localization): fix scope is explicitly bounded by Step 2.2 evidence. F-19-DR-04 finding text reproduced. |

### Document quality

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 24 | Under 300 lines (298 LF) | PASS | Byte-level LF count = 298, under 300-line cap. |
| 25 | LF line endings (no CRLF) | PASS | Byte-level CR count = 0. |
| 26 | No unicode icons | PASS | Byte-level non-ASCII count = 0. |
| 27 | Plain ASCII status labels | PASS | All `Status:` lines are ASCII; no em dashes or unicode; no decorative separators. |

## Findings

| # | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-19-IPR-01 | NON-BLOCKING | Redundant candidate row in Step 2.2 candidate table | Plan lines 116-118 lists `common_init_from_params` (line 1292) and `llama_init = common_init_from_params` (line 1292) as two separate candidates. Both resolve to the same line 1292. The second row adds no new information. | No plan change required; Developer session may collapse to single row or keep both as context-row markers. |
| F-19-IPR-02 | NON-BLOCKING | Step 2.3 fit_params SRV_INF line 1235 is off by 1-3 lines | Plan line 126 cites SRV_INF at "lines 1135 and 1235". Actual: line 1135 (mtmd) and 1232-1234 (spec, multi-line SRV_INF). The 1235 claim is close to the spec SRV_INF but the actual block spans 1232-1234. | No plan change required; Developer session should capture the actual line from `git show HEAD:tools/server/server-context.cpp \| Select-String -Pattern 'fit_params'` (which returns 9 matches) and identify the SRV_INF rows at planning time, not rely on the design's 1235 landmark. |
| F-19-IPR-03 | INFO | Plan file is 298 LF, not 206 as user listed in task description | Task description states "Under 300 lines (206 confirmed)" but byte-level LF count is 298. The plan grew between task authoring and review; still under 300-line cap. | No action required; just note that the file grew 92 lines from the initial estimate. |

## Counts

- BLOCKING: 0
- Non-blocking: 2 (F-19-IPR-01, F-19-IPR-02)
- INFO: 1 (F-19-IPR-03)

## Verdict

**PASS.** The Stage 19 implementation plan is approved. The plan is a faithful operationalization of the Stage 19 design: Step 1 (reproduction) runs the baseline launch matrix without any cache flags on the Qwen3-0.6B fixture; Step 2 (analysis) verifies the validation gate at line 1249 (correctly noting the 2-match observation is the gate plus the controller creation block, not a defect), localizes the crash site to six candidate ranges within load_model using `git show HEAD:tools/server/server-context.cpp` to capture actual line numbers (resolving F-19-DR-01), and applies the 3-branch verdict rule from design part 1. Step 3 maps Branch A to a minimal conditional fix using the existing `llama_get_memory` and `llama_memory_can_shift` APIs (both verified at include/llama.h:555 and :774), Branch B to environmental classification with no code change, and Branch C to a 5-successive-launch close. Step 4 covers the 4 test plan rows from design part 3 (TP-19-RT1, TP-19-RT2, TP-19-RT3, TP-19-FT1 conditional) with branch-conditional expected outcomes. Step 5 reproduces the 5-point closure criteria from design part 3 and maps each branch's evidence to a dedicated part-03 file path. The four design-review findings (F-19-DR-01..04) are addressed with explicit resolution paths: F-19-DR-01 by Step 2.2 actual-line capture, F-19-DR-02 by Step 2.1 explicit 2-match interpretation, F-19-DR-03 acknowledged as Manager closure activity, F-19-DR-04 by Step 2.2 + Step 3.1 conditional sequencing. The four design risks (R-19-DESIGN-01..04) are reproduced with plan-level mitigation paths. The out-of-scope list explicitly excludes: cmake changes, header changes, document-index, stage tracker (except the conditional Branch B follow-up row), Stage 18 implementation log, and design docs. The plan file is 298 LF, CR=0, BOM=False, non-ASCII=0, under the 300-line cap. The two non-blocking findings (F-19-IPR-01 redundant candidate row, F-19-IPR-02 SRV_INF line 1235 off by 1-3 lines) are cosmetic and do not affect plan correctness. The implementation plan is ready for execution in a fresh Developer session.

## Handoff

Next owner: **Manager** for the implementation-plan gate in a fresh session. The Manager reviews this Architect plan-review against:

1. The Stage 19 design (entry + parts 1-6) approved at Manager design gate.
2. The Stage 18 closure rationale (D18-CLOSURE-01) for context on baseline vs cache-flag paths.
3. The Stage 17 baseline crash evidence (D17-EXEC-02) for the original crash signature.
4. The four design-review findings and their resolution paths in the plan.
5. The four design risks and their plan-level mitigations.
6. The two non-blocking findings (F-19-IPR-01, F-19-IPR-02) and the one INFO finding (F-19-IPR-03).
7. The branch-specific action plans (Step 3.1-3.3) and their evidence paths under `cache-handling-phase19-implementation/part-03-branch-{A\|B\|C}-*.md`.
8. The test plan rows (Step 4.1-4.4) and their branch-conditioned outcomes.
9. The 5-point closure criteria reproduced from design part 3.

On Manager implementation-plan gate PASS, the Developer executes the plan in a fresh session: Step 1 reproduction, Step 2 analysis, Step 3 branch-specific action, Step 4 test plan execution, Step 5 closure documentation. The design, Stage 18 implementation log, stage tracker (except the conditional Branch B follow-up row), document-index, and any other durable doc are NOT modified by the plan or this review. The Branch B tracker follow-up row is a Step 3.2 conditional activity owned by the Developer, not a plan review concern.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable doc cap.
