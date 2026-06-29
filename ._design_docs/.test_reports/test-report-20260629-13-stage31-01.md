# Stage 31 QA execution report 2026-06-29 13

Status: PASS
Stage: 31 hybrid cache misbehavior focused validation
Owner: QA
Date: 2026-06-29

## Scope

Executed focused clean Release validation from Part 35 only.

Full live Stage 30 rerun remains advisory and is not required for Stage 31
closure. This run did not execute model-backed Stage 30 comparison traffic.

## Environment

- Branch: `work-branch`
- Commit: `2e1d19b84d9ceb9343935c968c5804b003809ef5`
- Durable report: `._design_docs/.test_reports/test-report-20260629-13-stage31-01.md`
- Non-durable evidence root: `_test_output/stage31-20260629-01/`
- Build delete preflight: resolved `D:\source\llama.cpp-jet\build` and verified it was under `D:\source\llama.cpp-jet\build` before `Remove-Item`.

Dirty status at session start:

```text
 M ._design_docs/.test_reports/test-report-20260629-12-stage30-01.md
 M ._design_docs/cache-handling-test-plan.md
 M ._design_docs/document-index.md
 M .agents/skills/self-improvement/assets/architect.md
 M .agents/skills/self-improvement/assets/developer.md
 M .agents/skills/self-improvement/assets/manager.md
 M .agents/skills/self-improvement/assets/qa.md
 M tests/test-cache-controller.cpp
 M tools/server/server-cache-hybrid.cpp
 M tools/server/server-cache-hybrid.h
 M tools/server/server-context.cpp
 M tools/server/server-context.h
?? ._design_docs/.manager-inputs/manager-input-20260629-stage31-hybrid-cache-misbehavior.md
?? ._design_docs/cache-handling-phase31-design.md
?? ._design_docs/cache-handling-phase31-design/
?? ._design_docs/cache-handling-phase31-implementation.md
?? ._design_docs/cache-handling-phase31-implementation/
?? ._design_docs/cache-handling-test-plan/part-35-stage31-hybrid-cache-misbehavior.md
?? ._design_docs/cache-handling-test-plan/stage-31-test-plan-review-20260629.md
```

## Commands

| Step | Command | Exit | Evidence |
| --- | --- | ---: | --- |
| Configure | `cmake -B build -S . -DCMAKE_BUILD_TYPE=Release` | 0 | `cmake-configure.stdout.log`, `cmake-configure.stderr.log`, `cmake-configure.exit.txt` |
| Build | `cmake --build build --config Release --target test-cache-controller -j 4` | 0 | `cmake-build-test-cache-controller.stdout.log`, `cmake-build-test-cache-controller.stderr.log`, `cmake-build-test-cache-controller.exit.txt` |
| Direct | `.\build\bin\Release\test-cache-controller.exe` | 0 | `direct-test-cache-controller.stdout.log`, `direct-test-cache-controller.stderr.log`, `direct-test-cache-controller.exit.txt` |
| CTest | `ctest --test-dir build -C Release -R cache -V` | 0 | `ctest-cache.stdout.log`, `ctest-cache.stderr.log`, `ctest-cache.exit.txt` |

Binary metadata:

```text
Path: D:\source\llama.cpp-jet\build\bin\Release\test-cache-controller.exe
Size: 1060864 bytes
LastWriteTime: 2026-06-29T22:35:51.911766+03:00
Freshness: PASS, built in this clean session before direct and ctest runs
```

## Evidence summary

Direct controller run:

- Exit code 0.
- `direct-test-cache-controller.stdout.log` ends with `All tests passed successfully!`
- Total: 142 tests.
- Stage 31 rows present in direct transcript:
  - line 87: `Stage 31 namespace uses runtime compatibility only`
  - line 89: `Stage 31 namespace cardinality bounded for prompt variants`
  - line 91: `Stage 31 workload token fixture`
  - line 93: `Stage 31 metric shape bounded labels`

CTest run:

- Exit code 0.
- Selected `test-cache-controller`.
- `1/1 Test #28: test-cache-controller ............   Passed`
- `100% tests passed, 0 tests failed out of 1`

Stage 30 wording spot check:

- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md:67`
  says exact-repeat rows can produce in-cycle hits and that zero hybrid hits
  required Stage 31 investigation.

Bounded metrics spot check:

- `tests/test-cache-controller.cpp:1616` defines
  `test_stage31_metric_shape_bounded_labels`.
- `tests/test-cache-controller.cpp:1647` through `1652` assert one HELP and
  one TYPE block for tested cache metrics.
- `tests/test-cache-controller.cpp:1655` through `1659` assert bounded
  `method` labels and `scope="all"` namespace gauge output.

Checkpoint safety spot check:

- Direct transcript includes Stage 9 checkpoint tests at lines 127, 129, 133,
  135, and 137.
- Direct transcript includes Stage 17 checkpoint tests at lines 181 and 183.
- Direct transcript includes Stage 23 checkpoint tests at lines 219, 221, and
  223.
- Direct transcript includes Stage 22 checkpoint-dependent tests at lines 249,
  251, and 253.
- Direct transcript includes Stage 26 and Stage 28 checkpoint regression tests
  at lines 289, 293, and 295.

## Row results

| ID | Verdict | Evidence |
| --- | --- | --- |
| TP-31-BLD-01 | PASS | Clean build from deleted `build`; configure/build exit 0; fresh binary metadata captured. |
| TP-31-DIR-01 | PASS | Direct run exit 0; Stage 31 row names present; 142 tests passed. |
| TP-31-CTEST-01 | PASS | `ctest -R cache -V` selected `test-cache-controller`; 1/1 passed. |
| TP-31-NS-01 | PASS | `test_stage31_namespace_uses_runtime_compatibility_only` ran and passed; exact repeat path covered. |
| TP-31-NS-02 | PASS | Same Stage 31 namespace test ran and passed; near-prefix shared namespace path covered. |
| TP-31-NS-03 | PASS | `test_stage31_namespace_cardinality_bounded_for_prompt_variants` ran and passed. |
| TP-31-NS-04 | PASS | Existing namespace isolation tests ran and passed in same binary: comprehensive key, draft model, draft context, metadata key, template, model path, LoRA, control vectors, multimodal, KV-unified. |
| TP-31-MET-01 | PASS | `test_stage31_metric_shape_bounded_labels` ran and passed; source asserts one HELP and one TYPE per tested metric. |
| TP-31-MET-02 | PASS | Same metric test ran and passed; source asserts bounded `method` and `scope="all"` labels. |
| TP-31-CHK-01 | PASS | Existing checkpoint safety tests ran and passed in same direct and ctest runs. No new Stage 31-specific corrupt-checkpoint test was required by Part 35. |
| TP-31-DOC-01 | PASS | Stage 30 report line 67 contains the corrected exact-repeat/in-cycle-hit wording. |

## Counts

| Status | Count |
| --- | ---: |
| PASS | 11 |
| FAIL | 0 |
| BLOCKED | 0 |
| SKIP | 0 |

## Hygiene

- Report line count: 152.
- ASCII check: PASS.
- LF/no CR check: PASS.
- BOM check: PASS.
- Trailing whitespace check: PASS.
- `git diff --check` on report plus Stage 31/Stage 30 touched docs: PASS.

## Handoff

Verdict: PASS.

Next gate: Manager Stage 31 closure decision.

No failures or blockers found in focused clean Release validation. Full live
Stage 30 rerun remains advisory evidence only for Stage 31 closure under the
accepted Part 35 gate.
