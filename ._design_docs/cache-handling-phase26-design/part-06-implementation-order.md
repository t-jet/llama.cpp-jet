# Part 6: Implementation order

Status: design draft
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope: ordered steps so each step has a runnable state.

## Order rationale

Each step ends with a buildable binary or a runnable test so partial
progress is recoverable. The SEH handler is sequenced first because
parts 05 and the D-EXEC-24-03-b closure depend on the dump file
being captured. The metrics renames are sequenced before the
fixture script updates so the binary emits new names first, then
the regex updates match.

## Steps

### Step 1: SEH handler + minidump + exit-code capture (part-03)

- New files: `tools/server/server-crash-handler.h`,
  `tools/server/server-crash-handler.cpp`.
- Modified file: `tools/server/CMakeLists.txt` (add the new source
  under `if(WIN32)`).
- Modified file: `tools/server/llama-server.cpp` (install filter at
  top of `main()`).
- Build: `cmake --build build-cuda --config Release -j --target
  llama-server` exits 0.
- Smoke test: launch server with `--crash-dump-dir C:\tmp\dumps`,
  force a crash via Process Explorer (Terminate Process with access
  violation), confirm `.dmp` file written.
- After this step: SEH handler is active and dumps will be captured
  in subsequent steps.

### Step 2: Cold-store metric accounting fix (part-04)

- Modified file: `tools/server/server-cache-hybrid.h` (add
  `cold_payload_bytes_by_id_` field, `cold_payload_files_count_`
  field).
- Modified file: `tools/server/server-cache-hybrid.cpp`
  (`handle_demotion_completion`, `cold_budget_make_room`,
  `mark_payload_kind_evicted`, `mark_payload_evicted`, cold cleanup
  in `update()`).
- New unit tests in `tests/test-cache-controller.cpp`:
  `TP-26-COLD-01..05` covering per-id accounting, eviction
  decrement, cleanup decrement.
- Build: `cmake --build build-cuda --config Release -j --target
  test-cache-controller` exits 0.
- Test: `test-cache-controller.exe` runs 137 / 137 PASS (132 prior
  plus 5 new).
- After this step: metric tracks cold payload bytes correctly per
  per-id map; file count matches.

### Step 3: Metrics renames (part-02)

- Modified file: `tools/server/server-context.cpp` (67 metric-name
  string changes per the rename map).
- Modified file: `tools/server/server-cache-hybrid.h` (no source
  change; only references to renamed metrics in comments).
- Modified file: `tools/server/server-cache-hybrid.cpp` (rename
  `llamacpp_cache_X` references in `LLAMA_SERVER_CACHE_TESTS` block
  if present).
- Modified file: `tests/test-cache-controller.cpp` (update any
  metric-name references in unit-test fixtures).
- Modified file: `tools/server/server-context.cpp` line 4537
  (`cache_prompt_evidence_records_total` rename `"mode"` argument
  to `"scope"`).
- Build: same as Step 1.
- After this step: `/metrics` emits `llamacpp:cache_X` not
  `llamacpp_cache_X`; `cache_prompt_evidence_records_total` no
  longer has duplicate `mode` label.

### Step 4: Fixture script updates (part-02)

- Modified file: `._design_docs/cache-handling-test-scripts/execute_tests.ps1`
  (11 regex updates: `llamacpp_cache_.*` to `llamacpp:cache_.*`).
- Modified file:
  `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
  (6 metric-name references in `metric_deltas` table; add
  `metrics_format_pass` and `label_uniqueness_pass` to leg summary;
  add `cold_store_drift_ratio` to leg summary).
- No build required (PowerShell).
- Smoke test: dry-run the runner; verify the new fields are emitted
  in `dry-run-plan.json` and `summary.json`.

### Step 5: Stage 24 rerun (part-05)

- Run the command in part-05 with `RunId = stage26-rerun-20260626-NN`.
- Capture `metrics-before.txt` and `metrics-after.txt` for each leg.
- Verify the checklist in part-05 passes per leg.
- Author `test-report-20260626-NN.md` with per-row verdict and
  comparison vs Stage 24 -06.

## State after each step

| Step | Buildable | Testable | Notes |
| --- | --- | --- | --- |
| 1 | yes | yes (smoke) | SEH active; existing metrics and behavior unchanged |
| 2 | yes | yes (137 tests) | Cold-store metric accurate; existing behavior unchanged |
| 3 | yes | yes (132 tests; metric tests may need fixture update) | Metrics renamed; label conflict gone |
| 4 | n/a (PS1) | yes (dry-run) | Fixture scripts match new metric names |
| 5 | yes | yes (full Stage 24 evidence) | Carry-over + metrics alignment + rerun complete |

## Handoff

Part-06 is reviewable. Implementation plan (D26-IMPL-PLAN-01) will
re-state these steps in the standard plan format and reference
parts 01 through 07.
