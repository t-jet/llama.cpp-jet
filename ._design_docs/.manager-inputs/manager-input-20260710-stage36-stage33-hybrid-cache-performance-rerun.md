# MANAGER INPUTS - NOT AN APPROVED DESIGN

## Stage 36 intake brief: Hybrid hit and performance validation

This Manager intake brief opens a new stage for the user request on 2026-07-10:

> "open and manage a new stage to run hybrid cache test from the Stage 33
> design and ensure that hybrid cache hits is on expected level and no bugs.
> Measure hybrid cache performance as it was designed for Stage 33."

## Stage goal

Run fresh current-tree evidence for hybrid cache hits and performance using the
Stage 33 comparison lineage, but do not repeat the Stage 33 workload unchanged.
Stage 33 already proved that the original long-spaced duplicate workload
produces expected zero hits at 512 MiB. Stage 36 keeps the Stage 33 performance
and observability rows while changing the traffic shape enough to make positive
hybrid hits an expected result.

The stage answers:

1. Does the current tree preserve correctness under the Stage 33 comparison
   lineage?
2. Does a tight duplicate workload produce the expected positive hybrid hits?
3. Are there any crashes, product checksum/token errors, unbounded labels, or
   cleanup bugs?
4. Does hybrid cache performance remain within the Stage 33 threshold while
   keeping hot RAM below legacy?

## Progress reconstruction

Stage 33 is closed PARTIAL with PASS-WITH-ACCEPTANCE. Its Developer review and
Manager closure reclassified zero hybrid hits as EXPECTED BEHAVIOR for the
original 512 MiB hot-cache, long-spaced duplicate workload. The documented
reason is that the hot cache holds about six entries of roughly 85 MiB each,
while exact duplicates return after at least 107 seconds and usually much later.
The original entry is evicted before the duplicate arrives.

Stage 35 is closed PASS. Current HEAD is merge commit
`89d13d2e3047c9976d37f22dfe3e8375862c0e87` with parents
`ecd9e0fd97366b9901eebc36f1920375256541df` and
`47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.

This stage does not authorize commits, pushes, PRs, merge aborts, or reviewer
responses.

## Source documents

Approved comparison baseline:

- `._design_docs/cache-handling-phase29-design.md`
- `._design_docs/cache-handling-phase29-implementation.md`
- `._design_docs/cache-handling-test-plan/part-36-stage32-live-comparison-rerun.md`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

Current expectation baseline:

- `._design_docs/.test_reports/test-report-20260630-03-stage33-01.md`
- `._design_docs/.test_reports/test-report-20260630-03-stage33-01-developer-review.md`
- `._design_docs/.test_reports/test-report-20260630-03-stage33-01-manager-closure.md`
- `._design_docs/cache-handling-phase35-implementation/part-34-manager-closure-20260709.md`

## Gate plan

1. Stage intake: PASS by this document.
2. Design: OPEN. Architect owns a design that keeps Stage 33 comparison rows
   but adds a tight duplicate workload so positive hits are expected.
3. Implementation planning: pending design approval.
4. Implementation: pending implementation-plan approval. Product code is out of
   scope unless test evidence later proves a product bug.
5. Test planning: pending implementation approval.
6. Test execution: pending test-plan approval.
7. Test-results review: Developer reviews the Stage 36 report if execution
   finds any FAIL or unexpected hit/performance result.
8. Bug-fix loop: only if the Stage 36 report identifies a product or driver
   defect.
9. Closure: Manager after QA evidence and Developer review if needed.

## Current gate

Design.

Current owner: Architect.

Known setup issue at intake: `build-cuda/bin/Release/test-cache-controller.exe`
is missing and must be rebuilt before any QA setup can pass.

## Target execution shape

Keep the Stage 33 comparison controls unless design or implementation planning
records a measured reason to change them:

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
- Hot budget: 512 MiB
- Cold budget: 2048 MiB
- Base port: 8900 unless occupied and Manager records a replacement

The workload must be tight duplicate bursts, not the unchanged Stage 33 random
long-spaced workload.

## Initial Stage 36 paths

Durable report:

```text
D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260710-01-stage36-stage33-rerun.md
```

Run root:

```text
D:\source\llama.cpp-jet\_test_output\stage36-stage33-rerun-20260710-01
```

Hybrid cold path:

```text
D:\tmp\cache-cold-stage36-stage33-rerun-20260710-01
```

Final commands are owned by the design, implementation plan, and test plan.

## Evidence rows

The report must classify the Stage 33 rows plus explicit positive-hit evidence:

| Row | PASS signal |
| --- | --- |
| Setup | Clean Release CUDA build, focused controller run, `ctest -R cache`, CUDA proof, fresh binary proof |
| Correctness | Output-equivalence `diff.txt` is empty |
| Hybrid hit expectation | Tight duplicate traffic produces positive hybrid hit delta and nonzero per-request cached tokens on repeat rows |
| Namespace bounds | Public metric labels remain bounded; no raw namespace id label appears |
| Public metric labels | No raw namespace ids, prompt hashes, request ids, paths, payload ids, or free-form metadata appear as labels |
| HELP/TYPE shape | Each cache metric has at most one HELP line and at most one TYPE line |
| Hot RAM | Hybrid hot cache bytes are at least 40 percent below legacy, or a documented tight-burst exception shows no product bug |
| Cold store | Hybrid cold bytes and payload count are recorded, and cold-store failure counters stay zero |
| Performance | Hybrid prompt and generation throughput are no more than 10 percent below legacy on comparable completed legs |
| Errors | No crash, SEH dump, fatal request error, product-level `token_count_mismatch`, or product-level `checksum_mismatch` |
| Cleanup | No `llama-server` process remains, port is free, and final cold-path size/count are recorded |
| Hygiene | Durable report and public artifacts do not expose prompt text, raw namespace ids, payload bytes, or local secret material |

## Verdict rules

PASS requires setup, correctness, positive expected-hit classification, hot-RAM,
performance, metric shape, error, cleanup, and hygiene rows to pass.

PARTIAL applies only when required rows pass but an optional warm-cycle set does
not finish inside the approved wall-clock budget.

FAIL applies when output equivalence fails, the tight duplicate workload still
shows zero hybrid hits, namespace or public labels become unbounded, HELP/TYPE
blocks duplicate, cold-store failures increase, server logs show product
errors, or throughput regresses by more than 10 percent without an accepted host
cause.

BLOCKED applies to invalid setup or missing required artifacts before usable
comparison evidence exists.

## Handoff

Next owner: Architect.

Next gate: Stage 36 design.
