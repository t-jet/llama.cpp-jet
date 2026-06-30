# MANAGER INPUTS - NOT AN APPROVED DESIGN

## Stage 33 intake brief: Full legacy-vs-hybrid A/B comparison

This is a Manager intake brief and execution handoff. It opens a new stage for
the broader comparison run requested after Stage 32 closed.

## User directive

> "Create a new stage to run A/B comparison as was ran on Stage 29 to compare hybrid cache behavior with legacy one."

Date: 2026-06-30

## Stage goal

Run the legacy-vs-hybrid A/B comparison on the current tree and produce a fresh
comparison report. The run reuses the Stage 29 comparison design and driver
shape, with the Stage 32 fixes and evidence extraction rules applied.

The stage answers whether the current hybrid cache behavior, after Stage 31 and
Stage 32 fixes, still preserves correctness while improving hot-RAM use and
showing live cache reuse compared with legacy mode.

## Progress reconstruction

Stage 32 is closed PASS. Its focused fix loop closed the two concrete failures
from the previous full run:

- `/v1/chat/completions` cached-token extraction now reads
  `usage.prompt_tokens_details.cached_tokens` before falling back to
  `timings.cache_n`.
- Aggregate public cache metrics now use bounded `scope="all"` labels instead
  of `namespace="all"`.

Stage 32 closure records the longer comparison as optional follow-up if broader
warm-cycle or performance evidence is wanted. This user directive requests that
follow-up, so Stage 33 opens at the execution gate.

## Source documents

Approved comparison baseline:

- Design: `._design_docs/cache-handling-phase29-design.md`
- Implementation and driver history:
  `._design_docs/cache-handling-phase29-implementation.md`
- Test-plan baseline:
  `._design_docs/cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md`
- Driver:
  `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

Current fixed baseline:

- Stage 31 closure:
  `._design_docs/cache-handling-phase31-implementation/part-06-manager-closure-20260629.md`
- Stage 32 design:
  `._design_docs/cache-handling-phase32-design.md`
- Stage 32 corrected implementation plan:
  `._design_docs/cache-handling-phase32-implementation.md`
- Stage 32 plan corrections:
  `._design_docs/cache-handling-phase32-implementation/part-02-plan-corrections-20260630.md`
- Stage 32 implementation-plan re-review PASS:
  `._design_docs/cache-handling-phase32-implementation/part-03-implementation-plan-re-review-20260630.md`
- Stage 32 focused retest PASS:
  `._design_docs/.test_reports/test-report-20260630-02-stage32-focused-retest.md`
- Stage 32 Developer review PASS:
  `._design_docs/.test_reports/test-report-20260630-02-stage32-focused-retest-developer-review.md`
- Stage 32 Manager closure PASS:
  `._design_docs/cache-handling-phase32-implementation/part-06-manager-closure-20260630.md`

## Gate plan

1. Stage intake: PASS by this document.
2. Design: SKIP. Reuse approved Stage 29 comparison design plus approved
   Stage 32 live-comparison design deltas.
3. Implementation planning: SKIP. Reuse Stage 32 corrected implementation plan
   and re-review PASS.
4. Implementation: SKIP. Product code and driver fixes already closed in Stage
   32. No new edit is approved before execution evidence fails.
5. Test planning: SKIP. Reuse Stage 32 test plan and review PASS, with Stage
   33 paths below.
6. Test execution: OPEN. QA owns the fresh full comparison run.
7. Test-results review: Developer reviews the Stage 33 report.
8. Bug-fix loop: only if the Stage 33 report finds a product or driver defect.
9. Closure: Manager after Developer review.

## Current gate

Test execution.

Current owner: QA.

No open blocker is known at intake.

## Execution parameters

Use the Stage 32 corrected run shape, which is the current approved form of the
Stage 29 A/B comparison:

- Route: `/v1/chat/completions`
- Modes: legacy, then hybrid
- Servers: sequential only
- Model:
  `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Binary:
  `D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe`
- Context size: 4096
- Parallel: 2
- Seed: 42
- Request count: 200
- Cycles: 3 warm cycles after the cold-start cycle
- Output-equivalence prompts: 5
- Hot budget: 512 MiB
- Cold budget: 2048 MiB
- Base port: 8900 unless occupied and Manager approves a replacement
- Wall-clock budget: reserve 150 minutes; allow 180 minutes if the run still
  makes progress and artifacts are being written

## Stage 33 paths

Durable report:

```text
D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-03-stage33-01.md
```

Run root:

```text
D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01
```

Hybrid cold path:

```text
D:\tmp\cache-cold-stage33-20260630-01
```

If QA starts on a later date or suffix, use the next chronological suffix and
keep the report, run root, cold path, and `RunId` aligned. Do not reuse any
path that already contains setup or traffic artifacts.

## Required setup evidence

QA must capture the same setup evidence required by Stage 32:

- clean Release CUDA configure;
- Release build of `llama-server` and `test-cache-controller`;
- direct `test-cache-controller.exe` run;
- `ctest --test-dir build-cuda -C Release -R cache -V`;
- git HEAD and dirty status;
- `GGML_CUDA:BOOL=ON` proof from `CMakeCache.txt`;
- binary path, size, and UTC timestamp;
- stale-binary proof using the Stage 32 corrected rules.

Any failed build, missing CUDA proof, stale binary, missing fixture, occupied
port that cannot be reassigned, or unsafe cleanup state is `BLOCKED`, not
`PARTIAL`.

## Dry-run command

Run from `D:\source\llama.cpp-jet` after setup evidence passes:

```powershell
pwsh -NoProfile -File D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -DryRun `
    -RunId stage33-cache-modes-20260630-01 `
    -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01 `
    -ReportPath D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-03-stage33-01.md `
    -CacheColdPath D:\tmp\cache-cold-stage33-20260630-01 `
    -LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe `
    -BasePort 8900 -ColdBudgetMiB 2048 -HotBudgetMiB 512 `
    -ContextSize 4096 -Parallel 2 -Seed 42 -RequestCount 200 `
    -Cycles 3 -OutputEquivalencePrompts 5
```

Dry-run must prove the model exists, the fresh binary is selected, the output
paths match this stage, the cold path is unique, and no server starts during
preflight.

## Full comparison command

After dry-run PASS:

```powershell
Remove-Item -LiteralPath D:\tmp\cache-cold-stage33-20260630-01 -Recurse -Force -ErrorAction SilentlyContinue
pwsh -NoProfile -File D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -RunId stage33-cache-modes-20260630-01 `
    -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01 `
    -ReportPath D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-03-stage33-01.md `
    -CacheColdPath D:\tmp\cache-cold-stage33-20260630-01 `
    -LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe `
    -BasePort 8900 -ColdBudgetMiB 2048 -HotBudgetMiB 512 `
    -ContextSize 4096 -Parallel 2 -Seed 42 -RequestCount 200 `
    -Cycles 3 -OutputEquivalencePrompts 5
```

Preserve partial artifacts if the 180 minute limit is reached.

## Evidence rows

The report must classify these rows:

| Row | PASS signal |
| --- | --- |
| Setup | clean Release CUDA build, focused controller run, `ctest -R cache`, CUDA proof, fresh binary proof |
| Correctness | output-equivalence `diff.txt` is empty |
| Hybrid reuse | exact-repeat hybrid rows show `cache_hit=true` or `cache_n > 0`, and `llamacpp:cache_hits_total{mode="hybrid"}` increases |
| Namespace bounds | namespace count is <= 4 unless every split has a documented compatibility cause |
| Public metric labels | no raw namespace ids, prompt hashes, request ids, paths, payload ids, or free-form metadata appear as labels |
| HELP/TYPE shape | each cache metric has at most one HELP line and at most one TYPE line |
| Hot RAM | hybrid hot cache bytes are at least 40 percent below legacy on comparable completed legs |
| Cold store | hybrid cold bytes and payload count are recorded, and cold-store failure counters stay zero |
| Performance | hybrid prompt and generation throughput are no more than 10 percent below legacy on comparable completed legs |
| Errors | no crash, SEH dump, fatal request error, `token_count_mismatch`, or `checksum_mismatch` |
| Cleanup | no `llama-server` process remains, port is free, and final cold-path size/count are recorded |
| Hygiene | durable report and public artifacts do not expose prompt text, raw namespace ids, payload bytes, or local secret material |

## Verdict rules

PASS requires all evidence rows to pass.

PARTIAL applies only when correctness and bounded-memory evidence pass but the
full warm-cycle set does not finish inside 150 to 180 minutes. The report must
list completed legs, open rows, and preserved artifacts.

FAIL applies when correctness fails, hybrid reuse remains zero on completed
exact-repeat traffic, namespace count is high without explanation, public
labels are unbounded, HELP/TYPE blocks duplicate, cold-store failures increase,
server logs show product errors, or throughput regresses by more than 10
percent without an accepted host cause.

BLOCKED applies to invalid setup or missing required artifacts before usable
comparison evidence exists.

## Handoff

Next owner: QA.

Next gate: Stage 33 test execution.

After QA writes the Stage 33 report, hand off to Developer for test-results
review. Product-code edits remain out of scope unless the Stage 33 report
fails and Manager opens a correction loop.
