# part-16: QA re-execution handoff 2026-06-29 (QA -05)

Session: 5th QA re-execution of Stage 29, after S29-IMPL-FIX-05.

Driver:
- L44 dots agentic-prompt-generator.ps1 (S29-IMPL-FIX-04 verified)
- L86-93 branches cold-path flags on `$Mode -eq 'hybrid'` (S29-IMPL-FIX-03 verified)
- L147 passes `-MaxIterations 200` for main workload (S29-IMPL-FIX-05 verified for main path)
- L149 passes `-MaxIterations 50` for equivalence workload (F-29-EXEC-12 NEW BLOCKING)

Wrapper:
- L66 declares `[int] $MaxIterations = 200` (S29-IMPL-FIX-05 verified)
- L115 + L152 both call `New-AgenticChatPrompt -MaxIterations $MaxIterations` (S29-IMPL-FIX-05 verified)
- L60-63 default SizeClass='12k' sets TargetTokens=12000

F-29-EXEC-12 (NEW BLOCKING, equivalence workload): driver L149 passes -MaxIterations 50 which is insufficient for the wrapper default SizeClass=12k (12000 target). Stage 20 lib agentic-prompt-generator.ps1:128-141 inner loop converges at 50 iterations to lastTokens=10631 (delta=178 short). Same defect class as F-29-EXEC-09 (prior session -02) but on the equivalence call site rather than the main call site. S29-IMPL-FIX-05 resolved F-29-EXEC-09 for the main path; the equivalence path was not addressed.

Suggested one-line fix (Developer):

Driver L149: change `-MaxIterations 50` to `-MaxIterations 200`. Or add a `-EquivalenceMaxIterations` parameter defaulting to 200 and pass it at L149. Either approach lets the wrapper converge at SizeClass=12k.

Verified control case (this session):

`pwsh -NoProfile -Command ". 'wrapper'; . 'lib'; New-ComparisonWorkload -RequestCount 5 -ServerUrl http://127.0.0.1:8902 -OutPath eq-smoke.jsonl -Seed 42 -MaxTokens 8 -MaxIterations 200"` exits 0 with 5 prompts at 12k each (302552 bytes). Same wrapper invocation with -MaxIterations 50 fails with the same exception trace as the driver.

## Phase 0.5 main workload build status

PASS: workload.jsonl emits 200 lines, 12 MB, cache_class distribution 78/65/57 (close to 80/60/60 design target within +/- 5 tolerance per re-review C-01). Confirms the S29-IMPL-FIX-05 main-path plumbing works end-to-end.

## TP-29-RG-01 + TP-29-RG-02 status

- TP-29-RG-01 focused test-cache-controller: 142/142 PASS (19392 bytes log). Same as Stage 28 closure contract.
- TP-29-RG-01 pytest: 0 items collected, exit 5, BLOCKED-env carry-forward (huggingface-hub==1.16.1 vs transformers >=0.34.0,<1.0). Not blocking regression contract.
- TP-29-RG-02: git status tools/server/ empty, git status tests/ empty, git diff stat hybrid.cpp empty. PASS for both sub-checks.

## TP-29-CV-01 status

BLOCKED-Release-without-/Zi (carry-forward F-29-EXEC-04/07/11/13). `build-cuda/CMakeCache.txt:80` carries `/O2 /Ob2 /DNDEBUG` (no `/Zi`). OpenCppCoverage at `D:\app\OpenCppCoverage\OpenCppCoverage.exe` exists but cannot produce meaningful coverage without debug symbols. Non-blocking per Stage 10 closure contract.

## Test report

Durable: `._design_docs/.test_reports/test-report-20260629-03-stage29-05.md` (205 LF, 19609 bytes, no BOM, no CR, git diff --check clean).

Per-row counts: PASS=1 (RG-02), FAIL=0, PARTIAL=1 (RG-01), BLOCKED=12 (11 equivalence-workload-build, 1 Release-without-/Zi).

## Handoff

Next owner: Developer. One-line fix at driver L149. After Developer fix and review, next QA re-execution per test plan part-33. After QA PASS, Developer test-results review. After Developer review PASS, Manager closure per D-CLOSURE-29-NN.

Manager directive 2026-06-29: "Don't close the stage until all things are resolved." Stage remains at bug handoff.
