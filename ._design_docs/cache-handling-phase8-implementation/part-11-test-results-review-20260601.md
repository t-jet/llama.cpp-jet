# Stage 8 test-results review - 2026-06-01

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)

Reviewed report: [../.test_reports/test-report-20260601-04.md](../.test_reports/test-report-20260601-04.md)

## Scope

This review covers the QA report generated on 2026-06-01 at 11:24:07 for the
Stage 8 test-results gate. I checked the report against:

- [Stage 8 implementation log](../cache-handling-phase8-implementation.md)
- [Part 10: Architect implementation re-review](part-10-architect-implementation-re-review-20260601.md)
- [Stage 8 test plan](../cache-handling-test-plan/part-10-stage8-metadata-only-rematerialization.md)
- [Stage 8 manager test-plan gate](../cache-handling-test-plan/stage-8-manager-test-plan-gate-20260601.md)
- Changed runner behavior in `execute_tests.ps1` and `run_cache_integration.ps1`

## Verdict

PASS for the Stage 8 test-results gate.

The report records 56 total rows: 55 PASS, 0 FAIL, 1 SKIP, and 0 BLOCKED.
No product bug is indicated by this QA run. The one skip is a known helper
coverage gap outside the Stage 8 acceptance scope.

## Failure, skip, and blocker classification

| Item | Classification | Owner | Closure scope |
| --- | --- | --- | --- |
| FAIL count: 0 | No product failures reported. | None | No bug-fix retest required. |
| BLOCKED count: 0 | No execution blocker remains in this report. | None | No blocker-clearance rerun required. |
| N04 missing model path startup failure: SKIP | Test automation limitation. The reusable helper always supplies a model path, so it cannot create the missing-model precondition. This is not a product bug and is unrelated to Stage 8 metadata-only behavior. | QA/tooling | Close by adding a helper mode that can intentionally omit `--model`, or keep as an accepted non-Stage-8 skip. |
| Python `test_cache_modes.py`: 1 xfailed | Expected test-suite marker, not a Stage 8 failure. The report states the metric-shape checks passed with 3 passed and 1 xfailed. | None | No Stage 8 retest required. Track only if the xfail reason changes. |

## Evidence assessment

The report meets the Stage 8 gate rules for the rows it claims:

- Clean-build evidence is listed before the run, including `llama-server`,
  `test-cache-controller`, `test-step12-branch-graph`, and
  `test-step13-stage8`.
- Public integration rows cover startup modes, public HTTP behavior,
  concurrency smoke, metrics-facing behavior, and model-backed draft probes.
- Focused `ctest` evidence covers `test-step13-stage8` and
  `test-cache-controller`.
- Python public metric-shape evidence uses
  `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1`, which is allowed only for startup,
  public surface, and Prometheus metric-label checks.
- D03 and D05 are not treated as public HTTP proof. They are closed by focused
  binary evidence, which matches the Stage 8 test-plan source rules.

The D-series behavior in the runner changed from placeholder skips to real
fixture-aware probes:

- D01 now uses the local target/draft fixture pair and requires a hybrid cache
  hit delta.
- D02 verifies startup failure with a missing draft model and uses an extended
  wait path for late draft-load failures.
- D03 runs `test-step13-stage8.exe` for atomic target/draft materialization
  coverage.
- D04 exercises the `--spec-draft-model` alias with the same draft runtime.
- D05 runs `test-cache-controller.exe` for draft namespace isolation coverage.

That split is acceptable. Public HTTP cannot force partial target/draft save
failure or switch draft identity inside one server, so focused evidence is the
right source for D03 and D05.

## Product bug assessment

No product bug is open from this report.

The prior implementation-review blockers remain closed by the current evidence:

- S8-IMPL-01: production metadata-only restore planning has focused Stage 8
  coverage and no QA regression.
- S8-IMPL-02: Stage 8 Prometheus metric names and labels have public
  metric-shape coverage.
- S8-IMPL-03: branch-metadata admission rejection has focused Stage 8 coverage.

## Test automation and execution notes

The remaining issue is N04. It is a harness limitation because the shared helper
always injects a model path. It does not block Stage 8 closure.

The report also keeps the right boundary for focused evidence. Stage 8 internals
such as metadata-only topology, re-materialization validation, mismatch-parent
selection, equivalent deduplication, cold cleanup ownership, and metadata
admission rejection are not claimed from metric presence alone.

## Retest and closure scope

No full Stage 8 rerun is required for this gate.

Retest only if one of these changes lands before closure:

- Stage 8 production restore, branch graph, admission, cleanup, or metrics code
  changes.
- The D-series draft fixture paths or speculative decoding startup flags change.
- The PowerShell runner changes how D03 or D05 invoke focused binaries.
- The Python metric-shape test changes the Stage 8 Prometheus assertions.

Optional future closure for N04 is a narrow harness rerun that starts
`llama-server` without any model argument and expects startup failure. That is
not required for Stage 8 acceptance.

## Handoff

Gate state: PASS. Manager can proceed to Stage 8 closure review with no open
product bug, no execution blocker, and one accepted non-Stage-8 automation skip.
