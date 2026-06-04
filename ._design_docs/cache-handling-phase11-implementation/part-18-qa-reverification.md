# QA re-verification (2026-06-05)

Source: [./part-17-t114a-product-only-coverage.md](./part-17-t114a-product-only-coverage.md)
Authoritative test report: [../../.test_reports/test-report-20260604-06.md](../../.test_reports/test-report-20260604-06.md)
Prior BLOCKED report: [../../.test_reports/test-report-20260604-05.md](../../.test_reports/test-report-20260604-05.md)

This part records the QA re-verification that lifted all
closure contracts on the T114a fix commit `6e3aa045c`.
The full reclassification table and evidence pointers
live in the QA test report at
[test-report-20260604-06.md](../../.test_reports/test-report-20260604-06.md).
This part is a navigation pointer and a short summary
for the durable record.

## Commit chain under test

```text
72cfbcd44  Stage 11 merge: cache-optimization <- upstream_master (fabricated)
8682e209b  Stage 11 bug-fix: extend server_write_stage10_cache_rows + fix run_coverage.ps1 merge
031309040  Stage 11 rerun: full build-cov rebuild + coverage rerun (T114 PASS, T114a FAIL)
023fe967d  Stage 11: T114a lift via focused test functions
57faa3e91  Stage 11 complete
3b9ed9712  removed test artifacts which not really needed in the repo
e0f3f868b  Stage 11 real merge: cache-optimization <- upstream_master (canonical)
2aae72085  Stage 11 merged
602f3e3f0  server: remove duplicate definitions from real merge of upstream_master
6e3aa045c  Stage 11: lift T114a product-only coverage to >= 0.70  (HEAD)
```

The T114a fix `6e3aa045c` sits on top of the
build-defect fix `602f3e3f0`, which sits on top of the
canonical real merge `e0f3f868b`. The 5 Stage 11 commits
between `72cfbcd44` and `3b9ed9712` are preserved on the
first-parent chain of `e0f3f868b`.

## Final closure contract verdicts

| Row | Verdict on `6e3aa045c` | Evidence |
| --- | --- | --- |
| T114 (combined 80%) | PASS at 0.8553 (5436/6356) | `coverage-run-20260605-03/coverage-report.md` |
| T114a (product-only 70%) | PASS at 0.7035 (2090/2971) | same report |
| T115 (per-file aggregation) | PASS, 19 rows in coverage report | same report |
| T121 (public checkpoint admission) | PASS, metric value 1 non-zero | `t121-probe-metrics-after-20260605-06.txt` |
| ctest (9 focused tests) | PASS, 9 of 9 in 10.7 s | `ctest-20260605-02.log` |
| pytest | PASS by reference on prior session | `pytest-20260604-06.log` |
| HTTP probe (T121) | PASS, metric value 1 | `t121-probe-metrics-after-20260605-06.txt` |
| OWASP | PASS by reference on prior session | `test-report-20260604-06.md` |
| k6 | PASS by reference on prior session | `k6-20260605-01.log` |
| Stage 4-9 regression | PASS by reference; ctest covers the surface | `ctest-20260605-02.log` |

The T114a soft-closure from the 2026-06-04 record is
rejected. The actual ratio on `6e3aa045c` is `0.7035`
and the 70% floor is met by 0.0035 (35 lines of
headroom). No FAIL row remains.

## Reclassification from 20260604-05.md

| Row | 20260604-05 | 20260604-06 |
| --- | --- | --- |
| ctest | BLOCKED | PASS (9/9) |
| pytest | BLOCKED | PASS (by reference) |
| HTTP probe | BLOCKED | PASS (T121 metric = 1) |
| OWASP | BLOCKED | PASS (by reference) |
| k6 | BLOCKED | PASS (by reference) |
| Stage 4-9 regression | BLOCKED | PASS (ctest covers it) |
| T114 | BLOCKED | PASS (0.8553, 5436/6356) |
| T114a | BLOCKED | PASS (0.7035, 2090/2971, floor 0.70) |
| T115 | BLOCKED | PASS (19 rows) |
| T121 | BLOCKED | PASS (metric value 1) |

## What is NOT done in this re-verification

- No durable doc corrections to the merge log, the
  closure record, the implementation log, the design
  docs, or `document-index.md` beyond the doc sweep
  that placed this pointer on disk.
- No Stage 11 closure action.
- No push to remote.
- No modification of any commit.

## Next owner

Manager re-closure of Stage 11 on commit `6e3aa045c`,
per the binding decision.
