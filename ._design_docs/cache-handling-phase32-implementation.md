# Stage 32 implementation: live comparison planning

Status: closed; Manager closure PASS 2026-06-30
Date: 2026-06-30
Stage: 32 (post-Stage-31 live comparison rerun)
Owner: Developer
Current gate: closed
Branch: work-branch

## Baseline

Approved design:

- [Stage 32 design](./cache-handling-phase32-design.md)
- [Design review 2026-06-30](./cache-handling-phase32-design/part-01-design-review-20260630.md): PASS
- [Manager intake](./.manager-inputs/manager-input-20260629-stage32-fix-stage31-and-rerun-comparison.md)

Stage 31 is closed PASS. Its focused evidence covers the namespace
compatibility fix, bounded Prometheus labels, one HELP/TYPE block per tested
cache metric, clean Release `test-cache-controller`, direct controller run, and
`ctest -R cache`. Stage 32 does not reopen Stage 31. It runs fresh model-backed
comparison traffic to prove the Stage 31 fixes work under live cache reuse.

No product-code edit is approved before failed live evidence. The existing
Stage 29/30 comparison driver is the execution path unless QA finds a missing
evidence-only extraction hook during preflight.

## Planning status

- Initial implementation-plan review:
  [implementation-plan review 2026-06-30](./cache-handling-phase32-implementation/part-01-implementation-plan-review-20260630.md).
  It found F32-PLAN-01 and F32-PLAN-02.
- Correction part:
  [plan corrections 2026-06-30](./cache-handling-phase32-implementation/part-02-plan-corrections-20260630.md).
  It addresses F32-PLAN-01 with explicit Stage 31 source timestamp comparison
  and F32-PLAN-02 with fixed proof paths, accepted regex/schema rules, and an
  evidence-only PowerShell extractor under the run root.
- Re-review:
  [implementation-plan re-review 2026-06-30](./cache-handling-phase32-implementation/part-03-implementation-plan-re-review-20260630.md):
  PASS. QA can execute Stage 32 without inventing stale-binary or
  post-processing decisions.
- Product code: unchanged by this planning entry.
- Test scripts: unchanged by this planning entry.
- Workload size: `SizeClass=2k` is set inside the existing driver calls to
  `New-ComparisonWorkload`; it is not a public driver parameter.
- Durable report target:
  `D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-01-stage32-01.md`
- Non-durable run root:
  `D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01`
- Hybrid cold path:
  `D:\tmp\cache-cold-stage32-20260630-01`

## Fix loop status

QA report
[`test-report-20260630-01-stage32-01.md`](./.test_reports/test-report-20260630-01-stage32-01.md)
failed completed live traffic on two findings: recorded zero exact-repeat reuse
and aggregate public cache rows using `namespace="all"`.

Developer ownership for the correction loop is tracked in
[`test-report-20260630-01-stage32-01-fixes.md`](./.test_reports/test-report-20260630-01-stage32-01-fixes.md).

F32-FIX-01 was corrected in the driver, not product restore code. Focused probe
evidence showed `/v1/chat/completions` reports restored prompt tokens at
`usage.prompt_tokens_details.cached_tokens`; the old driver only read
`timings.cache_n`. The driver now derives request-row token stats from chat
`usage` fields when present and falls back to `timings` fields otherwise.

F32-FIX-02 was corrected in product metric emission and test coverage. Remaining
aggregate Stage 8/10 cache rows now use `scope="all"` instead of
`namespace="all"`, and `test-cache-controller` covers those row families through
the Stage 31 bounded-label helper.

Focused Developer verification passed:

- PowerShell parse of the comparison driver.
- AST-extracted `Get-Stage29ResponseStats` probe for chat `usage` cached-token
  extraction.
- Scoped grep proving no touched code/test/script still contains
  `namespace="all"`.
- Scoped `git diff --check`.
- Release `test-cache-controller` build.
- Direct `test-cache-controller.exe` run: 142/142.
- `ctest --test-dir build-cuda -C Release -R cache -V`: 1/1.
- Release `llama-server` build.

Architect fix review:
[part 04 2026-06-30](./cache-handling-phase32-implementation/part-04-architect-fix-review-20260630.md):
REWORK. F32-FIX-01 closes request-row parsing only; it does not close the
independent `llamacpp:cache_hits_total` hit-delta evidence from the failed
Stage 32 report.

Developer rework evidence:

- Live duplicate chat probe:
  `_test_output/stage32-fix-live-duplicate-chat-20260630-01/probe-summary.json`.
- Fixture and workload: current `build-cuda\bin\Release\llama-server.exe`,
  Stage 32 Qwen3.5 MTP fixture, and exact duplicate request group
  `r-0051,r-0059,r-0080,r-0109,r-0162,r-0187` from
  `_test_output/stage32-cache-modes-20260630-01/workload.jsonl`.
- Request rows: `cache_n` values `0,1911,1911,1911,1911,1911`,
  `prompt_n=1915` on all six rows, and 5/6 `cache_hit=true`.
- Metrics: `llamacpp:cache_hits_total{mode="hybrid"}` went from `0` to `5`,
  so `hit_delta=5`.
- Product save/restore path was not changed for the rework because duplicate
  chat restore and the hybrid hit counter both passed in the live probe.

Architect fix re-review:
[part 05 2026-06-30](./cache-handling-phase32-implementation/part-05-architect-fix-re-review-20260630.md):
PASS. The live duplicate chat probe closes part 04 F32-ARCH-FIX-01 and opens
QA focused retest. Full comparison rerun remains a Manager decision after
focused PASS.

QA focused retest:
[`test-report-20260630-02-stage32-focused-retest.md`](./.test_reports/test-report-20260630-02-stage32-focused-retest.md):
PASS. Clean Release CUDA configure/build passed, direct
`test-cache-controller` passed, `ctest -R cache` passed, and the live duplicate
chat probe showed request-row `cache_n` values `0,1911,1911,1911,1911,1911`
with `llamacpp:cache_hits_total{mode="hybrid"}` delta `5`. Namespace count was
`1`, no public cache metric used a `namespace` label, HELP/TYPE blocks were
unique, and server logs had no crash, exception, request error,
`token_count_mismatch`, or `checksum_mismatch`.

Developer focused-retest review:
[`test-report-20260630-02-stage32-focused-retest-developer-review.md`](./.test_reports/test-report-20260630-02-stage32-focused-retest-developer-review.md):
PASS. No Stage 32 product bug remains from the focused evidence. Manager may
close the focused fix loop. A full 150 to 180 minute comparison rerun is
optional and advisory under the shorter-run guidance unless Manager wants
broader performance and warm-cycle evidence.

## Required commands

Run from `D:\source\llama.cpp-jet` in a Developer PowerShell with the Visual
Studio build environment loaded.

Clean Release configure:

```powershell
$repo = 'D:\source\llama.cpp-jet'
$build = Join-Path $repo 'build-cuda'
if (Test-Path $build) {
    $resolved = (Resolve-Path $build).Path
    if ($resolved -ne $build) { throw "Unexpected build path: $resolved" }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
cmake -B $build -S $repo -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON
```

Build server and focused controller target:

```powershell
cmake --build D:\source\llama.cpp-jet\build-cuda --config Release --target llama-server test-cache-controller -j 4
```

Run focused cache controller evidence:

```powershell
& D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
ctest --test-dir D:\source\llama.cpp-jet\build-cuda -C Release -R cache -V
```

Stale-binary and CUDA proof:

```powershell
$server = Get-Item D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe
$test = Get-Item D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
git rev-parse HEAD
git status --short
$server | Select-Object FullName,Length,LastWriteTimeUtc
$test | Select-Object FullName,Length,LastWriteTimeUtc
Select-String -Path D:\source\llama.cpp-jet\build-cuda\CMakeCache.txt -Pattern '^GGML_CUDA:BOOL=ON$'
```

The run is BLOCKED-stale-binary if `llama-server.exe` is older than the Stage
31 source changes being validated, or if `GGML_CUDA:BOOL=ON` is absent.
Use the executable source-file timestamp comparison in the correction part for
the binding stale-binary decision.

Driver dry-run/preflight:

```powershell
pwsh -NoProfile -File D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -DryRun `
    -RunId stage32-cache-modes-20260630-01 `
    -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01 `
    -ReportPath D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-01-stage32-01.md `
    -CacheColdPath D:\tmp\cache-cold-stage32-20260630-01 `
    -LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe `
    -BasePort 8900 -ColdBudgetMiB 2048 -HotBudgetMiB 512 `
    -ContextSize 4096 -Parallel 2 -Seed 42 -RequestCount 200 `
    -Cycles 3 -OutputEquivalencePrompts 5
```

Full Stage 32 comparison command, 150 to 180 minute budget:

```powershell
Remove-Item -LiteralPath D:\tmp\cache-cold-stage32-20260630-01 -Recurse -Force -ErrorAction SilentlyContinue
pwsh -NoProfile -File D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -RunId stage32-cache-modes-20260630-01 `
    -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01 `
    -ReportPath D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-01-stage32-01.md `
    -CacheColdPath D:\tmp\cache-cold-stage32-20260630-01 `
    -LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe `
    -BasePort 8900 -ColdBudgetMiB 2048 -HotBudgetMiB 512 `
    -ContextSize 4096 -Parallel 2 -Seed 42 -RequestCount 200 `
    -Cycles 3 -OutputEquivalencePrompts 5
```

Do not run legacy and hybrid servers concurrently. Preserve partial artifacts if
the 180 minute limit is reached.

## Artifacts to collect

- `workload.jsonl` and `equivalence-prompts.jsonl`.
- `phase-1-output-equivalence\legacy-decoded.txt`,
  `hybrid-decoded.txt`, and `diff.txt`.
- Per-leg `metrics-before.txt`, `metrics-after.txt`, and `requests.jsonl`.
- `summary.json`, `main.stdout.log`, `server.out.log`, and `server.err.log`.
- Cold-path listing, payload count, and byte-size proof after hybrid legs.
- Build logs, controller stdout/stderr, ctest stdout/stderr, binary metadata,
  git HEAD, dirty status, and `CMakeCache.txt` CUDA proof.

## Post-processing plan

Binding executable commands and output paths are in the correction part:
[plan corrections 2026-06-30](./cache-handling-phase32-implementation/part-02-plan-corrections-20260630.md).
The list below remains the evidence checklist.

Extract and report:

- Cache reuse: hybrid rows with `cache_hit=true`, rows with `cache_n > 0`,
  `cache_n` distribution by `cache_class`, and hit deltas from
  `llamacpp:cache_hits_total`.
- Workload class counts: `exact`, `near_prefix`, and `new_branch` from
  `workload.jsonl` and `summary.json`.
- Namespace count: `llamacpp:cache_namespace_count{mode="hybrid",scope="all"}`
  or the Stage 31 bounded equivalent. Count must be <= 4 unless the report
  explains a real compatibility split.
- Public metric labels: grep cache metric lines for raw namespace IDs, prompt
  hashes, request IDs, file paths, or free-form prompt metadata. Report
  `none found` or list each offending label.
- HELP/TYPE shape: count HELP and TYPE lines per cache metric name. Each metric
  name must have at most one HELP and at most one TYPE.
- Hot RAM: compare legacy and hybrid `cache_bytes` after completed legs.
- Cold store: cold bytes, payload count, demotion/promotion failure counters,
  filesystem byte proof, and cleanup state.
- Performance: prompt throughput and predicted-token throughput from completed
  comparable legs; p50/p99 request latency if extractable from `requests.jsonl`.
- Errors: server stderr crashes, SEH dumps, request errors, and driver errors.
- Cleanup: server process shutdown, port release, VRAM cooldown, and final
  cold-path size/count proof.

## Classification rules

PASS requires output equivalence PASS, non-zero live hybrid reuse, namespace
count <= 4 or justified, bounded public labels, one HELP/TYPE per metric name,
hybrid hot RAM at least 40 percent lower than legacy on comparable completed
legs, prompt and generation throughput no more than 10 percent below legacy,
zero cold-store failures, clean focused controller evidence, and cleanup proof.

PARTIAL applies when correctness and bounded-memory checks pass but the full
warm-cycle set does not finish inside 150 to 180 minutes. The report must list
completed legs and open rows.

FAIL applies when output equivalence fails, hybrid reuse remains zero on
completed exact-repeat traffic, namespace count is high without explanation,
public labels are unbounded, HELP/TYPE blocks duplicate, cold-store failures
increase, stderr shows crashes/request errors, or throughput regresses by more
than 10 percent without an accepted environmental cause.

BLOCKED applies to missing fixture, failed clean configure/build, missing CUDA
proof, stale binary, occupied port, server health failure before request
traffic, missing required artifacts, or unsafe cleanup state.

## Risks and non-goals

- Debug-only const-mutex build issue at `server-cache-hybrid.cpp:4601` is out
  of scope. Stage 32 uses Release evidence.
- Pre-existing Release `%zu` warnings in later `tests/test-cache-controller.cpp`
  code are advisory unless they become errors or touch Stage 32 evidence code.
- No product-code edit before failed live evidence or a Manager-approved
  correction loop.
- No full comparison was run during this planning gate.

## Handoff

Next owner: Manager.

Next gate: none. Full Stage 32 comparison rerun is optional and advisory after
focused PASS.
