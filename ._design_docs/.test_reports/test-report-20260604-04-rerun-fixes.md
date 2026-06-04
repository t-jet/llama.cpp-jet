# Stage 11 test report 20260604-04 rerun fixes handoff

Source report: [test-report-20260604-04-rerun.md](test-report-20260604-04-rerun.md)
Date: 2026-06-04
Owner: Stage 11 Developer (rerun session, handoff)
Next owner: Stage 11 Developer (fixes session, separate from this session)
Verifier: Stage 11 Architect (fixes review)
Approver: Stage 11 Manager (closure decision)

## Row that needs fixes

One row failed in the rerun coverage verification. T114 PASSES
on the combined rate; T114a FAILS on the product-only rate.

### Row 1: T114a product-only hybrid path coverage

Test name: T114a per [cache-handling-test-plan/part-13-t114-product-only-coverage.md](../cache-handling-test-plan/part-13-t114-product-only-coverage.md).

Failure surface: `coverage-report.md` `## Product-only
result` block reports
`Product-only line rate: 0.6974`,
`Product-only covered: 2077 / 2978`,
`70% threshold: FAIL`. The product-only rate is 0.0026 below
the 70% floor.

Reproduction: the coverage run completed successfully:

```powershell
$env:LLAMA_CACHE_TEST_MODEL = 'D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\run_coverage.ps1 -BuildDir build-cov -OutDir ._design_docs\.test_reports\coverage-run
```

Phase 1 (9 focused tests), Phase 2 (server HTTP probe),
Phase 3 (merge), Phase 4 (report) all complete. The Cobertura
XML is 1.05 MB with 11 product files and 8 test files in
the per-file table. The combined rate is 0.8508 (PASS); the
product-only rate is 0.6974 (FAIL).

Root cause: the product-only denominator is 11 hybrid cache
implementation files. Two product files are well below the
70% floor:

- `server-cache-legacy.h` at 0/1 (0% covered, 1 valid line).
  The only non-test file with zero coverage. Not exercised
  by any focused test.
- `server-cache-controller.h` at 0.4 (2/5 lines covered).
  Not exercised by the current focused tests.

Two product files are between 50% and 70%:

- `server-cache-hybrid.h` at 0.5929 (83/140 lines).
  57 uncovered lines per the Architect review Finding B C2
  follow-up.
- `server-cache-hybrid.cpp` at 0.6197 (1144/1846 lines).
  680 uncovered lines per the Architect review Finding B C2
  follow-up.

`server-cache-policy-lru.cpp` at 0.7037 is above the 70%
floor but below the 80% C1 follow-up target. The remaining
5 product files are all above 74% and pass the 70% floor.

Contract impact: the T114a product-only 70% floor is a
Stage 11 closure contract per test plan Part 13. The combined
T114 row is met (0.8508 >= 0.80). The stage cannot close
with T114a in FAIL. The closure status remains FAIL pending
the T114a product-only coverage gap.

Fix scope: the fixes session should add or extend focused
tests to cover the product-only gaps. The largest
uncovered surfaces are:

1. `server-cache-legacy.h` (0/1). The single uncovered line
   needs a focused test that exercises the legacy controller
   interface in `server-cache-legacy.h`. The test plan does
   not currently cover this file.
2. `server-cache-controller.h` (0.4). 3 uncovered lines out
   of 5. The test plan does not currently cover the header
   declarations.
3. `server-cache-hybrid.h` (0.5929). 57 uncovered lines.
   The C2 follow-up in
   [cache-handling-phase10-implementation/part-12-stage10-hybrid-controller-coverage-followup.md](../cache-handling-phase10-implementation/part-12-stage10-hybrid-controller-coverage-followup.md)
   targets this surface.
4. `server-cache-hybrid.cpp` (0.6197). 680 uncovered lines.
   Same C2 follow-up target.

The minimum fix to clear the 70% T114a floor is to add
focused tests for `server-cache-legacy.h` and
`server-cache-controller.h` to cover the 4 uncovered lines
across both files. The product-only rate would rise to
(2077 + 4) / 2978 = 0.7001, just above the floor.

The recommended fix is the full C2 follow-up scope: add six
hybrid-controller test functions to
`tests/test-cache-controller.cpp` for the uncovered blocks
in `server-cache-hybrid.cpp` and `server-cache-hybrid.h`,
plus a new focused test for `server-cache-legacy.h` and
`server-cache-controller.h`. The C2 follow-up is expected
to lift the product-only rate above 0.74.

Fix owner: Stage 11 Developer (fixes session, separate
from the rerun session).

Re-test scope: rebuild `test-cache-controller` (and any new
focused tests), rerun the coverage script, and verify the
`## Product-only result` block shows
`Product-only line rate >= 0.70` and `70% threshold: PASS`.

## Non-failures worth noting

- T114 PASSES on the combined rate. The combined line rate is
  0.8508 (5359 / 6299 lines), within 0.0013 of the Stage 10
  closure rate of 0.8521.
- The 0/0 residual from the bug-fix review gate 01 is
  cleared. The Cobertura XML is 1.05 MB with 19 files in
  the per-file table. The HTML export is produced.
- The `build-cov/` full rebuild completed in 125 seconds
  with 0 errors and 2 warnings. All 14 DLLs and 79 PDBs are
  timestamped to this rebuild.

## Handoff

The rerun report is at
[test-report-20260604-04-rerun.md](test-report-20260604-04-rerun.md).
The Stage 11 closure status is FAIL pending the T114a
product-only coverage gap. The next gate is the Stage 11
Manager closure decision after the fixes session closes the
T114a row.
