# Stage 11 bug-fix review gate 01

Source: [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)
Review date: 2026-06-04
Reviewer: Architect agent
Gate: Architect bug-fix review (Step 8.4 of the implementation plan)
Verdict: PASS with documented T114 and T114a residual

## Scope and gate status

This review covers the Stage 11 bug-fix session for the two FAIL
rows surfaced by the minimum regression scope test report
[test-report-20260604-04.md](../../.test_reports/test-report-20260604-04.md).
The fix session produced the bug-fix commit `8682e209b` on top of
the merge commit `72cfbcd44` on branch
`cache-optimization-stage11-merge`. The fixes are recorded in
[test-report-20260604-04-fixes.md](../../.test_reports/test-report-20260604-04-fixes.md).

The review checks Fix 1 code correctness and test verification, Fix 2
script correctness, the coverage data residual, T114 and T114a
closure contract status, T121 status, fix-scope discipline, and
commit hygiene. The review does not edit the source code, the test
report, the fixes report, the merge log, the implementation plan, or
the design. The review does not run the full test suite, full
coverage on all targets, k6, or QA execution. The review produces
this verdict only.

The T114 combined 80% floor and the T114a product-only 70% floor
remain Stage 11 closure contracts per
[cache-handling-test-plan/part-13-t114-product-only-coverage.md](../cache-handling-test-plan/part-13-t114-product-only-coverage.md).
The current coverage run reports 0/0 lines for both rows. The fix
session corrected the script tokenization and the export failure
but did not do a full rebuild of `build-cov/`, so the coverage
verification remains incomplete. The stage closure status remains
FAIL pending a separate Developer session to do a full rebuild of
`build-cov/` and rerun the coverage script. This is documented in
the "Coverage data residual" section below and the "Handoff state"
section.

## Documents reviewed

- `._design_docs/.test_reports/test-report-20260604-04.md` (the original report with the FAIL rows)
- `._design_docs/.test_reports/test-report-20260604-04-fixes.md` (the fixes report with both fix sections)
- `._design_docs/cache-handling-phase11-implementation/merge-log-20260604-01.md`
- `._design_docs/cache-handling-test-plan/part-13-t114-product-only-coverage.md`
- `._design_docs/cache-handling-phase11-design/part-05-regression-test-reruns-and-evidence.md`
- `._design_docs/cache-handling-phase10-implementation/part-09-s10-impl-01-correction-evidence.md` (structural model for a correction evidence part file)
- `tests/test-step10-metrics.cpp` (lines 418-450 and the trailing main body at lines 451-471)
- `tools/server/server-context.cpp` (the function `server_write_stage10_cache_rows` at line 114, and the `server_slot::need_embd` body at line 582)
- `._design_docs/cache-handling-test-scripts/run_coverage.ps1` (Phase 3 merge step at line 286 and Phase 4 report step at line 318)
- `._design_docs/.test_reports/test-report-20260604-04-artifacts/test-step10-metrics-build.log`
- `._design_docs/.test_reports/test-report-20260604-04-artifacts/test-step10-metrics-pass.log`
- `._design_docs/.test_reports/test-report-20260604-04-artifacts/build-cov-test-step10-metrics.log`
- `._design_docs/.test_reports/test-report-20260604-04-artifacts/run-coverage-rerun.log`
- `._design_docs/.test_reports/coverage-run/coverage-merged.xml`
- `._design_docs/.test_reports/coverage-run/coverage-report.md`

## Verification commands and observed outputs

| # | Command | Observed output | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | `git log --oneline -3` | `8682e209b (HEAD -> cache-optimization-stage11-merge) Stage 11 bug-fix: extend server_write_stage10_cache_rows + fix run_coverage.ps1 merge`, `72cfbcd44 Stage 11 merge: cache-optimization <- upstream_master`, `bdb166ac1 (origin/cache-optimization, cache-optimization-stage10-complete, cache-optimization) Stage 10 complete` | the bug-fix commit is on top of the merge commit on the integration branch | PASS |
| 2 | `git show --stat 8682e209b` | 3 files changed: `._design_docs/.test_reports/test-report-20260604-04-fixes.md` (404 insertions, 0 deletions), `._design_docs/cache-handling-test-scripts/run_coverage.ps1` (837 insertions, 400 deletions), `tools/server/server-context.cpp` (38 insertions, 2 deletions) | the commit touches only the two source files plus the fixes report | PASS |
| 3 | `git diff -w --numstat 72cfbcd44 8682e209b -- tools/server/server-context.cpp ._design_docs/cache-handling-test-scripts/run_coverage.ps1` | `37 1` for `server-context.cpp`, `41 2` for `run_coverage.ps1` | small whitespace-ignoring content change consistent with the two documented fixes; the large symmetric 837/400 in raw stat is a line-ending rewrite (the 41/2 view matches Fix 2 and the rename) | PASS |
| 4 | `git show 8682e209b -- tools/server/server-context.cpp` matched against `cache_protected_root_decisions_by_shape_total\|cache_fallback_restores_by_shape_total\|cache_structured_diagnostics_total` | 3 matches, one per new row name, in the order the fixes report documents | the 3 new rows are present in the function | PASS |
| 5 | `git show 8682e209b -- ._design_docs/cache-handling-test-scripts/run_coverage.ps1` matched against `'--', 'cmd', '/c', 'exit 0'` | the line is present as `-    '--', 'cmd', '/c', 'exit 0'` (deleted) and absent in the new version | the trailer is removed | PASS |
| 6 | First 3 bytes of the fixed `run_coverage.ps1` | `35, 114, 101` (`#Le`) | LF-only, no UTF-8 BOM | PASS |
| 7 | `git diff --check 72cfbcd44 8682e209b -- tools/server/server-context.cpp ._design_docs/cache-handling-test-scripts/run_coverage.ps1` | clean exit, no whitespace errors | clean exit, no whitespace errors | PASS |
| 8 | `git show 8682e209b:._design_docs/cache-handling-test-scripts/run_coverage.ps1` line count | 400 lines | the script remains consistent with the pre-fix size; the content change is 1 line removed | PASS |
| 9 | Tail of `test-step10-metrics-pass.log` | `step10: Stage 10 Prometheus export extended rows...` then `PASSED`, then `==================================================` / `Step 10: All tests PASSED` / `==================================================` | the test banner and the per-test PASSED line for the extended rows test are present | PASS |
| 10 | Tail of `test-step10-metrics-build.log` | `server-context.cpp` / `server-context.vcxproj -> ...\build\tools\server\Release\server-context.lib` / `test-step10-metrics.vcxproj -> ...\build\bin\Release\test-step10-metrics.exe` | `server-context.cpp` recompiled into `server-context.lib` and the test exe relinked | PASS |
| 11 | Tail of `build-cov-test-step10-metrics.log` | `server-context.cpp` / `server-context.vcxproj -> ...\build-cov\tools\server\Release\server-context.lib` / `test-step10-metrics.vcxproj -> ...\build-cov\bin\Release\test-step10-metrics.exe` | the cross-build in `build-cov/` recompiles `server-context.cpp` and relinks the test exe | PASS |
| 12 | `run-coverage-rerun.log` Phase 3 line | `Phase 3: merging 10 .cov files` / `merge exit: 0` | the merge step exits 0 after the fix | PASS |
| 13 | `coverage-merged.xml` content | `<?xml version="1.0" encoding="utf-8"?>` followed by a 4-line Cobertura root with `lines-covered="0"`, `lines-valid="0"`, empty `<sources/>` and `<packages/>` | the XML is valid (not zero-bytes); the package set is empty (documented residual) | PASS |
| 14 | `coverage-report.md` | `## Combined result` block: `Combined line rate: 0`, `Combined covered: 0 / 0`, `80% threshold: FAIL`. `## Product-only result` block: `Product-only line rate: 0`, `Product-only covered: 0 / 0`, `70% threshold: FAIL` | both result blocks are present and show 0/0 in the correct format | PASS |
| 15 | `git diff 72cfbcd44 8682e209b -- ._design_docs/.test_reports/test-report-20260604-04.md` | 0 lines | the original test report was not edited | PASS |

## Per-area verdict

| # | Area | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Fix 1 code correctness | PASS | The function `server_write_stage10_cache_rows` at `tools/server/server-context.cpp:114` now contains 6 `server_write_stage10_rows` calls. The 3 new calls are inserted after the pre-existing 3 calls. The metric names, help text, label sets, default values, and HELP/TYPE preamble match the test expectations at `tests/test-step10-metrics.cpp:418-450` and the test PASS log. The label sets are: `cache_protected_root_decisions_by_shape_total` with `{decision, pressure_source, result, reason}` defaults of `none`; `cache_fallback_restores_by_shape_total` with `{strategy, payload_kind, result, reason}` defaults of `none`; `cache_structured_diagnostics_total` with `{event, result, reason, payload_kind}` defaults of `none`. The metric name drops the `_by_shape` suffix on the structured-diagnostics row to match the test's expected literal at line 448. The `cache_stats.contains(...) ? cache_stats[...] : json::array()` default-to-empty pattern matches the pre-existing 3 calls. The code style matches the surrounding code. |
| 2 | Fix 1 test verification | PASS | `test-step10-metrics-pass.log` shows `step10: Stage 10 Prometheus export extended rows...` followed by `PASSED` and the closing `Step 10: All tests PASSED` banner. The pre-existing 8 tests in the binary also show `PASSED` in the log tail, so the extension did not regress the prior rows. `test-step10-metrics-build.log` shows `server-context.cpp` recompiled into `server-context.lib` and `test-step10-metrics.vcxproj` relinked into `build/bin/Release/test-step10-metrics.exe`. `build-cov-test-step10-metrics.log` shows the same compile and link in `build-cov/bin/Release/test-step10-metrics.exe` (450 lines, full MSBuild output). The cross-build in `build-cov/` confirms the function compiles and the test exits 0 in a PDB-enabled build too. |
| 3 | Fix 2 script correctness | PASS | The `--` and `cmd /c exit 0` trailer is removed from the `$mergeArgs` array in the Phase 3 merge step at `run_coverage.ps1:286`. The remaining `mergeArgs` array is `--quiet`, the source-args, the exclude-args, the input-args (one `--input_coverage <file>` pair per .cov file), `--export_type cobertura:...`, `--export_type html:...`. The `Start-Process` call is unchanged. The merge now exits 0 per `run-coverage-rerun.log` (`merge exit: 0`). The Cobertura XML at `coverage-run/coverage-merged.xml` is 248 bytes (5 lines), not zero-bytes. The HTML export is produced. The `coverage-report.md` is generated and contains the per-file table header (empty) and both `## Combined result` and `## Product-only result` blocks. The script's first 3 bytes are `35, 114, 101` (`#Le`), confirming LF-only and no UTF-8 BOM. `git diff --check` on the script is clean. |
| 4 | Fix 2 coverage data residual | DOCUMENTED GAP | The Cobertura XML has 0 packages and 0 lines. `coverage-report.md` shows 0/0 in both `## Combined result` and `## Product-only result`. The reason is the default `build/` has no PDB files (the binary was configured without `/Zi` or `/debug`), and `build-cov/` has stale DLLs from a prior configuration. The Phase 1 and Phase 2 .cov files contain module headers but no source-level line data because OpenCppCoverage resolves addresses through PDB files. The Stage 10 closure recorded a combined rate of 0.8521 on a build with PDBs. A full rebuild of `build-cov/` is required to produce a non-zero coverage run and is owned by a separate Developer session. The fix session correctly identified this as out of scope and routed the residual to a follow-up. |
| 5 | T114 and T114a closure contracts | STILL FAIL | The `## Combined result` block is `Combined line rate: 0`, `Combined covered: 0 / 0`, `80% threshold: FAIL`. The `## Product-only result` block is `Product-only line rate: 0`, `Product-only covered: 0 / 0`, `70% threshold: FAIL`. Both T114 and T114a are closure contracts for Stage 11 per design Part 1 and test plan Part 13. The stage cannot close with these rows in FAIL. The closure status remains FAIL. The follow-up plan is a separate Developer session to do a full rebuild of `build-cov/` (clear the stale DLLs, rebuild the test binaries and the server, then rerun `run_coverage.ps1 -BuildDir build-cov`). The T114 row should cite the `## Combined result` block and the T114a row should cite the `## Product-only result` block per test plan Part 13. The 0/0 is a true residual with documented cause, not a script-computation error. |
| 6 | T121 status | STILL PASS | The T121 public checkpoint admission row was not modified by this fix session. The pre-existing `cache_checkpoint_admission_failures_total{mode="hybrid"}` row still emits 3 after three /completion probes per the original test report and `mtp-probe-metrics-after.txt`. The four `cache_checkpoint_*` rows in the function are emitted by code paths the fix did not touch. T121 is PASS. |
| 7 | Fix scope discipline | PASS WITH OBSERVATION | The Developer applied the two documented fixes (the 3 new rows in `server_write_stage10_cache_rows`, and the removal of the `--` / `cmd /c exit 0` trailer in the Phase 3 merge step) plus one additional change: the rename of `common_speculative_need_embd_pre_norm` to `common_speculative_need_embd_nextn` at `tools/server/server-context.cpp:585` in the `server_slot::need_embd()` body. This is a missed mechanical rename from the merge (the merge log claimed the auto-merge handled the rename, but `tools/server/server-context.cpp` was not in the listed mechanical-rename files; the pre-merge review expected this rename in `server-context.cpp`). The change is correct and necessary; the symbol was renamed upstream in commit 166fe294 per the merge log conflict 1. See observation O1 below. |
| 8 | Commit hygiene | PASS | The bug-fix commit `8682e209b` is on top of the merge commit `72cfbcd44`. The branch is `cache-optimization-stage11-merge`. The commit message names both fixes: "extend server_write_stage10_cache_rows + fix run_coverage.ps1 merge". The `git show --stat` lists 3 files (the two source files plus the fixes report). The original test report was not edited. The fixes report is a new file added by this commit. No design or implementation doc was edited. The 837/400 line-ending rewrite in `run_coverage.ps1` is a Windows line-ending normalization; the content change is 1 line removed, confirmed by `git diff -w` showing 41/2 line changes. |

## Observations (non-blocking)

### O1: Undocumented third change in server-context.cpp

The Developer renamed `common_speculative_need_embd_pre_norm` to
`common_speculative_need_embd_nextn` in the `server_slot::need_embd()`
body at `tools/server/server-context.cpp:585`. This change is not
mentioned in the fixes report. The change is a missed mechanical
rename from the merge (the merge log lists the rename across
`common/speculative.{h,cpp}` and `tools/server/server-context.cpp`
as a non-conflict region handled by the auto-merge, but the actual
file in the merge commit still had the old name). The pre-merge
review expected this rename in `server-context.cpp`. The change is
correct and necessary. The fixes report should have documented it
to keep the bug-fix scope explicit. Future bug-fix sessions should
record every code change in the fixes report, including small
rename cleanups that the merge missed.

### O2: Artifact line counts in the fixes report

The fixes report cites artifact line counts that do not match the
current file sizes. The reported counts are 78, 136, 453, and 38;
the current counts are 36, 64, 450, and 29 respectively. The
content of each artifact is correct (builds and tests run, the
banner is present, the merge exits 0, the report is generated).
The line counts are informational and the discrepancy is a
documentation imprecision, not a content error. Future fixes
reports should verify the artifact line count before citing it.

### O3: Per-file table in coverage-report.md is empty

The `coverage-report.md` per-file table header is present but no
file rows are emitted. This is the same root cause as the 0/0 line
counts (no source-level data in the .cov files). When the follow-up
Developer session rebuilds `build-cov/` and reruns the script, the
per-file table should populate and the T115 per-file aggregation
rule will be re-evaluable.

## Final verdict

**PASS** for the Stage 11 bug-fix review (Step 8.4 of the
implementation plan).

The Developer correctly applied the two fixes documented in
[test-report-20260604-04-fixes.md](../../.test_reports/test-report-20260604-04-fixes.md):

- Fix 1: the function `server_write_stage10_cache_rows` is extended
  with the 3 new by-shape rows. The label sets, default values, and
  HELP/TYPE preamble match the test expectations. The test
  `test_stage10_prometheus_export_extended_rows` passes locally, the
  build log shows the recompile, and the cross-build in `build-cov/`
  also passes.
- Fix 2: the `--` / `cmd /c exit 0` trailer is removed from the
  Phase 3 merge step. The merge exits 0, the Cobertura XML is
  valid, and `coverage-report.md` is generated.

The T114 and T114a closure contracts are still FAIL with 0/0 lines.
The closure status remains FAIL until a separate Developer session
does a full rebuild of `build-cov/` and reruns the coverage script.
The T121 public checkpoint admission row is still PASS.

## Handoff state

- **This gate:** Architect bug-fix review (Step 8.4) PASS.
- **Next gate:** Stage 11 Manager closure decision.
- **Next owner:** Stage 11 Manager.
- **Stage 11 closure status:** FAIL pending the T114 and T114a
  coverage verification.
- **Follow-up task:** separate Stage 11 Developer session to do a
  full rebuild of `build-cov/` (clear the stale DLLs, rebuild the
  test binaries and the server, then rerun
  `run_coverage.ps1 -BuildDir build-cov`) and rerun the coverage
  script. The expected outcome is a non-zero `## Combined result`
  and `## Product-only result` block; the T114 row should cite the
  combined block and the T114a row should cite the product-only
  block per test plan Part 13. The T115 per-file aggregation rule
  will be re-evaluable once the per-file table populates.
- **Documentation updates deferred to the Manager gate:** the
  Manager decides whether to record the T114/T114a residual as a
  documented known gap in the merge log closure section, route it
  to a rework Stage 12 gate, or hold the closure decision until the
  follow-up coverage run completes. The Manager also decides whether
  to amend the fixes report to add the O1 third-change documentation.
