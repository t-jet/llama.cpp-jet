# Part 1: Ordered implementation steps

Status: planning
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Developer
Scope source: [cache-handling-phase26-design/part-06](../cache-handling-phase26-design/part-06-implementation-order.md)

## Step 1: SEH handler + minidump + exit-code capture

Design: [part-03-seh-handler-crash-dump.md](../cache-handling-phase26-design/part-03-seh-handler-crash-dump.md)

- New files:
  - `tools/server/server-crash-handler.h`
  - `tools/server/server-crash-handler.cpp`
- Modified files:
  - `tools/server/CMakeLists.txt` (add new source under `if(WIN32)`)
  - `tools/server/llama-server.cpp` (install filter at top of `main()`)
- Implementation content (server-crash-handler.h):
  - Declare `install_crash_dump_handler(const std::string & dump_dir)`;
    `#ifdef _WIN32` guard, no-op signature on non-Windows.
  - `g_crash_dump_dir` static std::string for use by the filter.
- Implementation content (server-crash-handler.cpp):
  - `#ifdef _WIN32` block: `SetUnhandledExceptionFilter` -> writes
    `<dump_dir>/llama-server-<pid>-<timestamp>.dmp` via
    `MiniDumpWriteDump`.
  - Dump type: `MiniDumpWithIndirectlyReferencedMemory |
    MiniDumpWithThreadInfo` for bounded size.
  - `__try / __except(EXCEPTION_EXECUTE_HANDLER)` wrap around
    `MiniDumpWriteDump` to avoid recursive crash on dump write fail.
  - On any failure, log to stderr so the failure surfaces in
    `server.err.log` even when minidump itself fails.
- CLI surface: `--crash-dump-dir <path>` registered in main.cpp
  argument parser. Empty default = disabled.
- Smoke: launch server with `--crash-dump-dir C:\tmp\dumps`; force a
  crash via Process Explorer Terminate-Process-with-access-violation;
  confirm `.dmp` file exists and is loadable in WinDbg.
- Build: `cmake --build build-cuda --config Release -j --target
  llama-server` exits 0. After this step: SEH active; existing metrics
  and behavior unchanged.

## Step 2: Cold-store metric accounting fix

Design: [part-04-cold-store-metric-drift-fix.md](../cache-handling-phase26-design/part-04-cold-store-metric-drift-fix.md)

- Modified files:
  - `tools/server/server-cache-hybrid.h`: add fields
    - `std::unordered_map<uint64_t, size_t> cold_payload_bytes_by_id_;`
    - `size_t cold_payload_files_count_ = 0;` (file count, separate
      from descriptor count)
  - `tools/server/server-cache-hybrid.cpp`:
    - `handle_demotion_completion` (line 677): on demote success,
      set `cold_payload_bytes_by_id_[pid] = descriptor.target_size_bytes +
      descriptor.draft_size_bytes;` keep current
      `n_cold_payload_bytes +=` increment (single source of truth).
    - `cold_budget_make_room` (line 603): on each candidate eviction
      decrement step, look up
      `cold_payload_bytes_by_id_[candidate_id]` and subtract that
      exact value; erase the map entry; fall back to `target+draft`
      only when the map entry is absent (legacy descriptor from
      pre-step-2 state).
    - `mark_payload_kind_evicted` and `mark_payload_evicted`
      (line 3329 + 3378): same decrement + erase pattern in the
      cold eviction path.
    - `update()` cold cleanup loop (line 939..990): on successful
      cold_store.delete_ids, decrement `n_cold_payload_bytes` and
      `cold_payload_files_count_` for each deleted id using
      `cold_payload_bytes_by_id_`; erase map entries.
    - On deserialization / restore, populate the map from the cold
      store directory walk at controller init (one-time O(N) scan)
      so restored descriptors have correct accounting.
- New unit tests in `tests/test-cache-controller.cpp`:
  - `test_stage26_cold_metric_tracks_per_id_bytes` (TP-26-UT1)
  - `test_stage26_cold_metric_decrements_on_evict` (TP-26-UT2)
  - `test_stage26_cold_metric_decrements_on_cleanup` (TP-26-UT3)
  - `test_stage26_cold_metric_no_double_count_on_redemote` (TP-26-UT4)
  - `test_stage26_cold_payload_files_count_matches_disk` (TP-26-UT5)
- Build: `cmake --build build-cuda --config Release -j --target
  test-cache-controller` exits 0. After this step: cold-store metric
  accurate per per-id map; existing behavior unchanged.

## Step 3: Metrics rename (37 + 30 = 67 metrics)

Design: [part-02-metrics-alignment-plan.md](../cache-handling-phase26-design/part-02-metrics-alignment-plan.md)

- Modified file: `tools/server/server-context.cpp` (line range
  4344..4687).
- Rename map (binding per design part-02):
  - 37 `llamacpp_cache_X` -> `llamacpp:cache_X` (lines 4399..4576;
    covers entries/bytes/tokens/hits/misses/evictions/payload_*/failure_*/
    demotion_*/promotion_*/latency_bucket_*).
  - 30 `cache_X` -> `llamacpp:cache_X` (lines 4411..4687; covers
    branch_*/metadata_only_*/node_rematerializations/validation_*/
    mismatch_*/equivalent_branch_*/cold_cleanup/metadata_admission_*/
    cold_budget_bytes/checkpoint_*/prompt_evidence_*/prefix_candidates_*/
    restore_misses/etc.).
- Label conflict fix at line 4537:
  - Old: `write_cache_metric_with_two_labels("counter",
    "cache_prompt_evidence_records_total", "...", "mode", "off",
    "result", "none", 0)`
  - New: rename `"mode"` -> `"scope"`, keep `"result"`. Same change at
    line 4541 (the inner block that re-emits with the actual values).
- No comments reference metric names that need rephrasing beyond the
  rename map. The METRIC_GROUPS list (if present) is renamed in lockstep.
- Modified file: `tools/server/server-cache-hybrid.cpp` references to
  renamed metric names in any log strings (search for
  `llamacpp_cache_` outside metric-emission sites, none expected per
  grep).
- Modified file: `tests/test-cache-controller.cpp` references to
  metric-name strings (only in test fixtures; no production code paths).
- Build: same target as Step 1 exits 0. After this step: `/metrics`
  emits `llamacpp:cache_X`; `cache_prompt_evidence_records_total` no
  longer carries duplicate `mode` label.

## Step 4: Label uniqueness fix isolation

This step is covered by Step 3 line 4537. No separate code change;
verification is the metrics scrape test in Step 8.

## Step 5: Runner script MetricNames array update

Design: [part-02-metrics-alignment-plan.md](../cache-handling-phase26-design/part-02-metrics-alignment-plan.md) + [part-05-stage24-rerun-plan.md](../cache-handling-phase26-design/part-05-stage24-rerun-plan.md)

- Modified file:
  `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
  (lines 29..39, the `$MetricNames` array).
- Replace each of the 10 entries with its new name:
  - `cache_restore_misses_total` -> `llamacpp:cache_restore_misses_total`
  - `cache_prefix_candidates_total` -> `llamacpp:cache_prefix_candidates_total`
  - `cache_prompt_evidence_records_total` ->
    `llamacpp:cache_prompt_evidence_records_total`
  - `cache_cold_bytes` -> `llamacpp:cache_cold_bytes`
  - `cache_cold_budget_bytes` -> `llamacpp:cache_cold_budget_bytes`
  - `cache_cold_demotions_skipped_total` ->
    `llamacpp:cache_cold_demotions_skipped_total`
  - `cache_cold_evictions_total` -> `llamacpp:cache_cold_evictions_total`
  - `cache_checkpoint_admissions_by_shape_total` ->
    `llamacpp:cache_checkpoint_admissions_by_shape_total`
  - `cache_checkpoint_admissions_total` ->
    `llamacpp:cache_checkpoint_admissions_total`
  - `cache_checkpoint_admission_failures_total` ->
    `llamacpp:cache_checkpoint_admission_failures_total`
- Modified same script, lines 1033..1035 (the `metric_delta_comparison`
  block): rename `cache_restore_misses_total` and
  `cache_prompt_evidence_records_total` and
  `cache_checkpoint_admissions_total` to the `llamacpp:` form.
- No build required (PowerShell).
- Smoke test: dry-run the runner; verify the renamed names appear in
  `dry-run-plan.json` and are looked up correctly.

## Step 6: execute_tests.ps1 metric-name regex updates

Design: [part-02-metrics-alignment-plan.md](../cache-handling-phase26-design/part-02-metrics-alignment-plan.md)

- Modified file:
  `._design_docs/cache-handling-test-scripts/execute_tests.ps1`.
- 10 regex updates (lines per grep_search):
  - line 188: `llamacpp_cache_.*\{.*mode="legacy"` -> `llamacpp:cache_.*\{.*mode="legacy"`
  - line 218: same rename for legacy match
  - line 248: same rename for hybrid match
  - line 1186: `llamacpp_cache_hits_total` ->
    `llamacpp:cache_hits_total`
  - line 1238: same rename
  - line 1293: `llamacpp_cache_misses_total` ->
    `llamacpp:cache_misses_total`
  - line 1357: same rename
  - line 1470: `llamacpp_cache_evictions_total` ->
    `llamacpp:cache_evictions_total`
  - line 1529: `llamacpp_cache_hits_total` ->
    `llamacpp:cache_hits_total`
  - line 1533: `llamacpp_cache_misses_total` ->
    `llamacpp:cache_misses_total`
- No build required (PowerShell). Smoke: dry-run the script with
  metrics text matching the new format.

## Step 7: server-context.cpp metric registration paths

- The actual write_cache_metric / write_cache_metric_with_two_labels
  helper names and signatures are unchanged. Only the string literal
  arguments (the metric NAMES) are updated. This step is folded into
  Step 3 (the same `replace_string_in_file` batch covers both the
  call-site renames and the registration strings, since the
  registration is the call).
- Verification: after Step 3 build, `grep -nE
  "llamacpp_cache_[a-z]" tools/server/server-context.cpp` returns 0
  matches.

## Step 8: 5 new unit tests (TP-26-UT1..UT5)

- Modified file: `tests/test-cache-controller.cpp`.
- New test functions:
  - `test_stage26_cold_metric_tracks_per_id_bytes`:
    synthetic demote of two payloads; assert
    `n_cold_payload_bytes == sum of per-id write sizes`.
  - `test_stage26_cold_metric_decrements_on_evict`:
    synthetic demote + evict each payload; assert
    `n_cold_payload_bytes == 0` at end.
  - `test_stage26_cold_metric_decrements_on_cleanup`:
    synthetic demote + cold cleanup; assert
    `n_cold_payload_bytes` matches on-disk directory walk.
  - `test_stage26_cold_metric_no_double_count_on_redemote`:
    demote + evict + demote same id; assert
    `n_cold_payload_bytes == latest write size`, not cumulative.
  - `test_stage26_cold_payload_files_count_matches_disk`:
    synthetic demote + cold cleanup; assert
    `n_cold_payload_count == readdir file count`.
- Add the 5 new function calls to `main()` after the Stage 25 block.
- All tests must use the `if (!cond) { fprintf(stderr, ...); std::abort(); }`
  pattern per developer memory (NDEBUG silently disables assert in
  Release build).

## Step 9: Build clean, run all 137 tests

- Build:
  - `cmake --build build-cuda --config Release -j --target
    llama-server test-cache-controller` exits 0.
- Test:
  - `tests/test-cache-controller.exe` exits 0 with the new total
    137 (132 prior + 5 new). All new tests PASS.
- Coverage target: 80%+ on cold-store accounting code paths affected
  by Step 2.

## Step 10: Update test summary count string

- Modified file: `tests/test-cache-controller.cpp` (the printf at
  end of `main()`).
- Old: `"Total: 132 tests (31 original + ... + 10 Stage 25 atomic transactional)\n"`
- New: append `+ 5 Stage 26 cold-store accounting`; change "132 tests"
  to "137 tests"; update subtotal for Stage 26.
- Format: keep one-line printf; ASCII; under 200 chars.

## Step 11: Stage 24 rerun

Design: [part-05-stage24-rerun-plan.md](../cache-handling-phase26-design/part-05-stage24-rerun-plan.md)

- Command:

  ```powershell
  & ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
      -RunId stage26-rerun-20260626-01 `
      -RowsToRun S02-chat,S03-chat `
      -ModelPath '._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
      -RunRoot '._test_output\stage26-rerun-20260626-01' `
      -ReportPath '._design_docs\.test_reports\test-report-20260626-01.md' `
      -CacheColdPath 'D:\tmp\cache-cold-stage26' `
      -BasePort 8900 `
      -LegDurationMin 10 `
      -ColdBudgetMiB 512 `
      -LlamaServerPath 'build-cuda\bin\Release\llama-server.exe'
  ```

- Use the post-Step-3 binary.
- Capture per-leg artifacts: `metrics-before.txt`, `metrics-after.txt`,
  `server.crash-dump.txt` (if a crash happens), `summary.json`,
  `comparison.json`.
- Verification checklist per part-05: PASS on CUDA build proof, dry-run,
  metrics format = `llamacpp:`, label uniqueness, leak scan, cold
  budget, cold-store drift ratio.

## Step 12: Documentation updates

- Update the Stage 26 design entry doc to mark design as IMPLEMENTED
  (only after Manager approval; this is a Manager-owned file).
- Append implementation summary to `cache-handling-phase26-implementation.md`
  (Developer-owned) with file-change list, evidence, and remaining
  risks.
- The implementation log captures each step's evidence. The actual
  test report goes to `._design_docs/.test_reports/test-report-20260626-01.md`
  per OQ-26-04.

## State after each step

| Step | Buildable | Testable | Notes |
| --- | --- | --- | --- |
| 1 | yes | yes (smoke) | SEH active; metrics and behavior unchanged |
| 2 | yes | yes (137 tests) | Cold-store metric accurate; behavior unchanged |
| 3 | yes | yes (132 + metric test still passes) | Metrics renamed; label conflict gone |
| 4 | n/a | yes | Folded into Step 3 |
| 5 | n/a (PS1) | yes (dry-run) | Runner MetricNames match new names |
| 6 | n/a (PS1) | yes (dry-run) | execute_tests.ps1 regex match new names |
| 7 | n/a | n/a | Folded into Step 3 |
| 8 | yes | yes (132 + 5 = 137) | 5 new cold-store accounting tests |
| 9 | yes | yes | Full clean build + 137 tests pass |
| 10 | yes | yes | Count summary text updated |
| 11 | yes | yes (full Stage 24 evidence) | Rerun produces test-report-20260626-01 |
| 12 | n/a | n/a | Documentation only |

## Handoff

Part-01 is reviewable. Next: part-02 affected files.
