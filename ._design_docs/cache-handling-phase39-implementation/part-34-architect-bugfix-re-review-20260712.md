# Stage 39 Architect bug-fix re-review 20260712

Date: 2026-07-12
Status: PASS
Gate: Architect bug-fix re-review of part-33
Reviewed artifact: part-33-developer-qa3-corrections-20260712.md
Paired evidence: ../.test_reports/test-report-20260712-03-fixes.md
Scope: code and focused tests only. Design, plan, implementation, test plan,
prior F39-FR-01..04 reviews, and any live execution remain out of scope.

## Verdict

PASS. Both targeted findings (F39-QA3-01, F39-QA3-02) are closed at the actual
source. No new product defect introduced. Remaining workload and coverage rows
are correctly left open for the next gate.

## Reviewed findings

| Finding | Description | Status | Evidence |
| --- | --- | --- | --- |
| F39-QA3-01 | Duplicate `mode` label in public Stage 39 Prometheus rows | closed | Exporter `server_write_stage39_cache_rows` at tools/server/server-context.cpp:3785-3805 emits only `result` and `reason` from each row tuple. The implicit single `mode="hybrid"` label is added once by `server_write_cache_metric_with_labels` (tools/server/server-context.cpp:79-96). Internal tuple still carries `mode` for diagnostics (tools/server/server-cache-hybrid.cpp:1277-1294). Focused regression `test_stage39_prometheus_export_has_unique_mode_label` (tests/test-step10-metrics.cpp:431-456) asserts both decision and transaction rows, rejects `mode="hybrid",mode=`, and counts exactly 2 `mode=` labels. |
| F39-QA3-02 | Stage 10 cold-bytes gauge assertion used hardcoded 125, skipped committed-file check | closed | tests/test-step10-metrics.cpp:176-180 now reads committed `tmp_dir / "1.cold"` size, asserts `committed_serialized_bytes == sizeof(cold_store_header) + 125`, then asserts the gauge equals the same computed bytes. Invariant matches cold-store format in tools/server/server-cache-store-cold.cpp:266-283 (`exact_bytes = sizeof(header) + target + draft`) and tools/server/server-cache-store-cold.h:111 (`sizeof(cold_store_header) == 64`). Test setup at tests/test-step10-metrics.cpp:158 writes 100 target + 25 draft = 125 payload bytes. Count, descriptor, and demotion assertions at lines 173 and 181-183 remain. |

## Review checklist results

1. F39-QA3-01 source verified. Single Stage 39 exporter at
   tools/server/server-context.cpp:3785. Two call sites
   (server_cache_stage39_prometheus_rows_for_tests at line 3812 for the focused
   test path, and the public metrics endpoint at line 4631) both route through
   it. No competing emission path references
   `cache_two_layer_decisions` or `cache_cold_transactions` (grep returned only
   the exporter and the hybrid stats builder). PASS.
2. F39-QA3-01 diagnostic-only `mode` retained. Internal tuple at
   tools/server/server-cache-hybrid.cpp:1277-1294 still emits `mode` per row for
   diagnostics and design-required observability. Exporter intentionally drops
   it from the public label set so the public sample has exactly one `mode`.
   PASS.
3. F39-QA3-02 gauge fix verified. tests/test-step10-metrics.cpp:174-180 reads
   `fs::file_size(cold_file)`, asserts the header+payload invariant, then
   compares the gauge against the same value. No regression to surrounding
   demotion/count/descriptor assertions at lines 173, 181-183. PASS.
4. Focused-test evidence real. `test_stage39_prometheus_export_has_unique_mode_label`
   exists (tests/test-step10-metrics.cpp:431), is registered in main() at
   tests/test-step10-metrics.cpp:472, and asserts what part-33 "Evidence"
   claims. Accessor declared in tools/server/server-context.h:18 and defined
   under LLAMA_SERVER_CACHE_TESTS at tools/server/server-context.cpp:3812.
5. No new product defect. Exporter change only affects new Stage 39 rows; the
   shared `server_write_cache_metric_with_labels` helper is unchanged, so other
   metric label sets (stage10 evictions, transitions, exact-blob restores,
   checkpoint admissions) are unaffected. Stage 10 test change strengthens, not
   weakens, the cold-bytes assertion. PASS.
6. Whitespace. `git diff --check -- tools/server/server-context.cpp
   tests/test-step10-metrics.cpp` exit 0, no findings. Diff is line-ending
   clean. PASS.

## Remaining open items (QA next gate)

These rows are workload or infrastructure scoped and must NOT be closed by any
code-review gate. They route to QA post-fix retest:

- TP-39-02 equal-rank live two-layer decision tuple. Requires a model-backed
  workload that drives a tie in victim ranking.
- TP-39-03 calibrated no-eligible-victim workload. Requires a workload that
  makes every cold resident ineligible, confirming the production precondition.
- TP-39-04 calibrated oversized-both-layers workload. Requires a pair-bound
  pressure against the exact production-pressure candidate.
- TP-39-15 live re-verification of F39-QA3-01. Needs a live hybrid run scraping
  `/metrics` to confirm exactly one `mode=` per Stage 39 row in production.
- Coverage smoke. OpenCppCoverage must emit a real readable `.cov` artifact, then
  the fail-closed coverage set must clear the 80% changed-line threshold.

## Next gate

QA post-fix retest. QA reruns TP-39-02, TP-39-03, TP-39-04, TP-39-15, the full
focused pack (including the new Stage 39 exporter regression), `ctest -R cache`,
and produces a real changed-line coverage smoke. Stage 39 remains open until QA
post-fix retest passes.
