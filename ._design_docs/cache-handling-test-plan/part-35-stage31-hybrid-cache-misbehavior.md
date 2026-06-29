# Test plan part 35: Stage 31 hybrid cache misbehavior

Status: authored; pending Manager test-plan gate
Date: 2026-06-29
Stage: 31 (Hybrid cache misbehavior after Stage 30)
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: generic Stage 31 validation plan. Do not treat this as execution
evidence.

## References

Design:

- [Stage 31 design](../cache-handling-phase31-design.md)
- [Design review PASS](../cache-handling-phase31-design/part-01-design-review-20260629.md)

Implementation:

- [Stage 31 implementation](../cache-handling-phase31-implementation.md)
- [Part 01: implementation plan](../cache-handling-phase31-implementation/part-01-implementation-plan.md)
- [Part 03: probe evidence](../cache-handling-phase31-implementation/part-03-probe-evidence-20260629.md)
- [Part 04: implementation evidence](../cache-handling-phase31-implementation/part-04-implementation-evidence-20260629.md)
- [Part 05: implementation review PASS](../cache-handling-phase31-implementation/part-05-implementation-review-20260629.md)
- [Stage 30 report with wording correction](../.test_reports/test-report-20260629-12-stage30-01.md)

Code surfaces:

- `tests/test-cache-controller.cpp`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-context.cpp`
- `tools/server/server-context.h`

Prior plan parts:

- [Part 7: test report quality and templates](./part-07-test-report-quality-and-templates.md)
- [Part 24: test output folder convention](./part-24-test-output-folder-convention.md)
- [Part 33: Stage 29 cache modes comparison](./part-33-stage29-cache-modes-comparison.md)

## Scope and decision

Stage 31 validates the focused fix for the Stage 30 hybrid cache symptoms:
zero hits in an exact-repeat-capable workload, high namespace cardinality, raw
namespace labels in public metrics, and duplicate Prometheus HELP/TYPE blocks.

In scope:

- Clean Release build of `test-cache-controller`.
- Direct `test-cache-controller` execution.
- `ctest -R cache` execution.
- Namespace behavior: exact repeat, near-prefix, bounded namespace count, and
  isolation for stable runtime compatibility changes.
- Metric shape: one HELP and one TYPE line per metric name, with bounded public
  labels and no raw namespace ids.
- Checkpoint-dependent safety carried by existing controller tests in the same
  binary, plus explicit Stage 31 evidence that those tests still run after the
  namespace broadening.
- Stage 30 wording correction verification.

Out of scope:

- Full Stage 30 comparison rerun as a Stage 31 closure requirement.
- New model-backed workload automation.
- Graph topology redesign, response cache behavior, or public request schema
  changes.

Decision on full live Stage 30 rerun:

- Not required for Stage 31 closure if the clean Release controller build,
  direct run, `ctest -R cache`, metric-shape checks, namespace rows, checkpoint
  regression evidence, and Stage 30 wording verification all pass.
- Recommended as follow-up or advisory evidence for Stage 30/31 comparison
  confidence because focused tests do not replay all 200 Stage 30 live requests
  through the model-backed chat route.
- Required only if Manager changes the closure gate to demand live workload
  confirmation.

## Clean build gate

Stale builds are invalid evidence. Start the execution session with a clean
Release build and record the binary mtime, size, and command output in the
fresh report.

```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target test-cache-controller -j 4

$Binary = Get-Item build\bin\Release\test-cache-controller.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "test-cache-controller.exe is stale. Run the clean build again."
}
```

If the local generator writes the binary to a different Release path, record the
actual path and keep the same freshness rule.

## Test rows

| ID | Area | Command or check | Expected outcome | Evidence | Verdict rule |
| --- | --- | --- | --- | --- | --- |
| TP-31-BLD-01 | Clean build | Clean Release build of `test-cache-controller` | build exits 0; binary fresh within 10 minutes | build log, binary path, mtime, size | PASS = clean fresh build; BLOCKED-stale-build = stale or reused binary; FAIL = compile/link failure |
| TP-31-DIR-01 | Direct controller run | `.\build\bin\Release\test-cache-controller.exe` | process exits 0; Stage 31 rows run; no abort output | stdout/stderr transcript | PASS = exit 0 and Stage 31 row names present; FAIL = non-zero exit or missing Stage 31 rows |
| TP-31-CTEST-01 | CTest cache run | `ctest --test-dir build -C Release -R cache -V` | `test-cache-controller` selected and PASS | ctest transcript | PASS = selected cache test PASS; FAIL = selected test FAIL; BLOCKED = no cache test selected |
| TP-31-NS-01 | Exact repeat | Direct run covers `test_stage31_namespace_uses_runtime_compatibility_only` exact A/A case | exact repeat namespace parity and lookup match | direct run transcript plus source line citation | PASS = A/A namespace same and match tokens > 0; FAIL = exact repeat misses |
| TP-31-NS-02 | Near-prefix | Same Stage 31 namespace test, B over A case | near-prefix shares namespace and finds safe prefix candidate | direct run transcript plus source line citation | PASS = prefix lookup returns expected shared token count; FAIL = prompt-local metadata splits namespace |
| TP-31-NS-03 | Bounded namespace count | `test_stage31_namespace_cardinality_bounded_for_prompt_variants` | 20 prompt variants under one runtime produce one namespace | direct run transcript plus stats assertion source | PASS = namespace set and branch forest count are 1; FAIL = count grows with prompt variants |
| TP-31-NS-04 | Isolation | Existing namespace isolation tests in same binary | model path, draft model, draft context mode, template, LoRA, control vectors, multimodal identity, KV-unified state, and compatibility key still isolate | direct run transcript and source citations | PASS = existing isolation tests pass in same run; FAIL = any isolation regression |
| TP-31-MET-01 | HELP/TYPE shape | `test_stage31_metric_shape_bounded_labels` or parsed `/metrics` from equivalent focused run | each tested metric has one HELP and one TYPE block | direct run transcript; optional metrics sample | PASS = one HELP/TYPE per metric name; FAIL = duplicates |
| TP-31-MET-02 | Bounded labels | Same metric test or `/metrics` parse | branch lookup labels use bounded `method`; namespace gauges use `scope="all"`; no raw namespace id label | direct run transcript; optional metrics sample | PASS = labels bounded and raw namespace absent; FAIL = raw namespace label leaks |
| TP-31-CHK-01 | Checkpoint safety | Existing checkpoint tests in same controller binary after Stage 31 fix | checkpoint descriptor, boundary, pair-state, and dependent-profile validation still pass | direct run transcript plus list of checkpoint test names or source citations | PASS = checkpoint tests pass in same run; FAIL = any checkpoint validation regression; INFO = no new Stage 31-specific corrupt-checkpoint test |
| TP-31-DOC-01 | Stage 30 wording | Inspect Stage 30 report | report says exact-repeat rows can produce in-cycle hits and Stage 31 investigated 0-hit behavior | cited report line | PASS = correction present; FAIL = stale "cold start, no hits yet" remains unqualified |

## Evidence and report rules

Create a fresh report in `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
before execution. Store build logs, command transcripts, and optional metric
samples under `._test_output/<run-id>/`.

The report must include:

- git commit and dirty working-tree status;
- exact build commands and binary metadata;
- direct controller command and exit code;
- ctest command, selected tests, and exit code;
- Stage 31 row mapping to test names or source citations;
- checkpoint-dependent safety source list;
- Stage 30 wording correction citation;
- final PASS, FAIL, SKIP, and BLOCKED counts.

## Classification

Stage 31 QA PASS requires TP-31-BLD-01, TP-31-DIR-01, TP-31-CTEST-01,
TP-31-NS-01..04, TP-31-MET-01..02, TP-31-CHK-01, and TP-31-DOC-01 to pass or
carry only the allowed INFO note on missing Stage 31-specific corrupt-checkpoint
coverage.

FAIL if a valid clean build produces a product or test regression in namespace,
metric shape, checkpoint safety, or Stage 30 correction evidence.

BLOCKED if the clean Release build cannot be produced, no cache test is
selected by ctest, or required evidence cannot be captured.

SKIP is allowed only for optional live Stage 30 rerun evidence when Manager did
not make it a closure gate.

## Handoff

Next owner: Manager test-plan gate. After gate PASS, QA execution can run the
clean Release focused validation. Full live Stage 30 rerun remains advisory
unless Manager upgrades it to a required closure gate.
