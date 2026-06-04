# Cache handling test plan - Part 13: T114 split: combined rate and product-only rate

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

- Date: 2026-06-04
- Owner: Architect
- Source of action: [test-report-20260603-architect-review.md](../../.test_reports/test-report-20260603-architect-review.md) Finding B / Action B

## Why T114 needs a second row

Stage 10 closed on a T114 combined rate of 85.21% (5231/6139, 19-file
hybrid-mode denominator). The same run reported a product-only rate of
70.4% (2097/2978) for the 11 product files. The gap exists because the
hybrid-mode denominator includes 8 focused test files that run to near
completion and inflate the combined rate.

A future stage that lets product code drop to 70% while test files keep
the combined rate at 80% would clear the T114 closure contract with a
genuine production code gap still open. Finding B of the Architect
review records the closure contract as insufficient and asks for a
product-only row alongside the combined row.

This part file adds a T114a row for the product-only rate and sets a
floor that prevents test files from masking product gaps. The T114 row
stays as the combined-rate contract. The split is additive, not a
replacement.

## T114 (unchanged)

| ID | Scenario | Expected result |
| --- | --- | --- |
| T114 | Hybrid path coverage | A coverage run proves at least 80% coverage for the reviewed hybrid-mode denominator, including observability emission, cold-store hardening, descriptor validation, hot/cold transitions, branch and Stage 8 paths, checkpoint paths, and target/draft pairing. |

The T114 verdict continues to cite the `## Combined result` block at the
bottom of `coverage-report.md` per the Action A QA process guidance in
[part-13-qa-process-guidance.md](../../cache-handling-phase10-implementation/part-13-qa-process-guidance.md).

## T114a (new)

| ID | Scenario | Expected result |
| --- | --- | --- |
| T114a | Product-only hybrid path coverage | A coverage run proves at least 70% coverage for the 11 product files in the hybrid-mode denominator. Test files in the denominator are excluded from the T114a verdict. |

### Product-only denominator

The 11 product files named in the Architect review Finding B:

| File | Stage 10 rate | Notes |
| --- | --- | --- |
| server-cache-hybrid.cpp | 63.16% | largest uncovered surface; C2 follow-up targets the 80% per-file target |
| server-cache-hybrid.h | 59.29% | mostly inline helpers; covered when the .cpp test coverage improves |
| server-cache-store-cold.cpp | 86.88% | passes the 70% floor |
| server-cache-store-cold.h | 74.07% | passes the 70% floor |
| server-cache-controller.cpp | 83.33% | passes the 70% floor |
| server-cache-controller.h | 0% | not exercised by the current focused tests; needs follow-up |
| server-cache-graph.cpp | 87.19% | passes the 70% floor |
| server-cache-graph.h | 95.00% | passes the 70% floor |
| server-cache-io-worker.cpp | 84.42% | passes the 70% floor |
| server-cache-policy-lru.cpp | 70.37% | C1 follow-up targets the 80% per-file target |
| server-cache-legacy.h | 0% | not exercised by the current focused tests; needs follow-up |
| **Combined (11 files)** | **70.4% (2097/2978)** | borderline; C1 and C2 must lift the combined rate |

The list is copied verbatim from the Architect review and is not
redefined here.

### Floor threshold

The floor is 70%. The 70.4% Stage 10 closure rate was already at the
edge of acceptable for production code coverage. A 65% floor would have
passed the Stage 10 closure and would not catch the kind of gap
Finding B is about. A 75% ceiling is reserved because the post-C1 and
post-C2 product-only rate is not measured yet.

The 70% floor is a thin safety margin above the Stage 10 closure rate.
The C1 and C2 follow-ups are expected to lift the product-only rate
above 70% on the next coverage run. If they do not, the next stage
fails the T114a contract even if T114 still passes on the combined
rate.

### Expected post-C1 and post-C2 product-only rate

The C1 follow-up
[part-11-stage10-policy-lru-coverage-followup.md](../../cache-handling-phase10-implementation/part-11-stage10-policy-lru-coverage-followup.md)
adds `test-stage10-policy-lru` to the `$focusedTests` array in
`run_coverage.ps1`. The Architect review estimated the impact as
`server-cache-policy-lru.cpp` reaching 80%+ once included.

The C2 follow-up
[part-12-stage10-hybrid-controller-coverage-followup.md](../../cache-handling-phase10-implementation/part-12-stage10-hybrid-controller-coverage-followup.md)
adds six hybrid-controller test functions to
`tests/test-cache-controller.cpp` for the uncovered blocks in
`server-cache-hybrid.cpp` and `server-cache-hybrid.h`. The Architect
review recorded 680 uncovered lines in `server-cache-hybrid.cpp` and
57 uncovered lines in `server-cache-hybrid.h` as the pre-C2 surface.

The actual post-C1 and post-C2 product-only rate will be measured by
QA in the next coverage run. The expected direction is up, but the
exact delta depends on the OpenCppCoverage denominator and the other
tests in the run. The Developer does not measure coverage in the C1
or C2 gates; the measurement is a QA-owned task.

### Closure contract for the combined T114 and the new T114a

Both rows are closure contracts for any stage that has both rows in
its test plan. A stage fails to close if either row reports FAIL. The
combined rate and the product-only rate are tracked separately. A
stage cannot meet the T114 closure contract on the combined rate while
leaving T114a below 70%.

The Stage 10 closure record at
[test-report-20260603-05.md](../../.test_reports/test-report-20260603-05.md)
cites the T114 row only. The T114a row is forward-looking and applies
to Stage 11 onward.

### Evidence source for T114a

The T114a verdict cites the `## Product-only result` block at the
bottom of `coverage-report.md`, not the Cobertura XML root attributes
and not the T114 `## Combined result` block. The citation format is
the same shape as the T114 citation per the Action A QA process
guidance, with the section header changed to `## Product-only
result` and the verdict text changed to the 70% threshold check.

Citation format for the T114a row in a Stage N test report:

- Artifact: `._design_docs/.test_reports/test-report-YYYYMMDD-NN-artifacts/coverage/coverage-report.md`
- Script: `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
- Verdict cites the `## Product-only result` block (product-only line
  rate, product-only covered X / Y, 70% threshold PASS/FAIL).
- Do not cite `coverage-merged.xml` root attributes in the verdict
  section.
- Do not cite the T114 `## Combined result` block as the T114a
  verdict number. The two rows have separate blocks in the report.

## Required change to `run_coverage.ps1`

The script change is required for the T114a row to be evidence-citeable.
The script itself is not edited in this gate; the Developer applies the
change in a separate gate per the scope rules.

The required change adds a new section to `coverage-report.md` after the
existing `## Combined result` block. The new section reports the
product-only covered and valid line totals across the 11 product files
named in the Architect review, the product-only line rate, and a
verdict against the 70% floor.

### Required script behavior

1. Keep the existing 19-file per-file table.
2. Keep the existing `## Combined result` block.
3. After the `## Combined result` block, add a new
   `## Product-only result` block that:
   - Filters the per-file table rows to the 11 product files named
     in the `Product-only denominator` section of this part file.
   - Sums the per-file `Covered` and `Valid` line counts across the
     11 product files.
   - Computes the product-only line rate as `Covered / Valid`, rounded
     to four decimal places, matching the combined rate format.
   - Reports a verdict of `PASS` when the product-only rate is at or
     above 0.70, `FAIL` otherwise.
4. The product-only section is written with the same marker style as
   the combined section: a heading, three bulleted lines (line rate,
   covered X / Y, threshold verdict).

### Required output sample

```text
## Product-only result

- Product-only line rate: 0.704
- Product-only covered: 2097 / 2978
- 70% threshold: PASS
```

The sample numbers are the Stage 10 closure values. Real values will
change with each coverage run.

### No other script logic changes

The `$srcPatterns` and `$denomBasenames` arrays keep all 19 entries.
The per-test loop keeps the 9 focused tests. The HTTP probe keeps the
existing model-backed configuration. The HTML export and Cobertura XML
export keep the existing outputs. No new entry is added to
`$focusedTests` in this gate. The C1 and C2 follow-up changes are
already in place.

## Cross-references

- Architect review:
  [test-report-20260603-architect-review.md](../../.test_reports/test-report-20260603-architect-review.md)
  Finding B, Action B
- C1 coverage script follow-up:
  [part-11-stage10-policy-lru-coverage-followup.md](../../cache-handling-phase10-implementation/part-11-stage10-policy-lru-coverage-followup.md)
- C2 hybrid controller test functions follow-up:
  [part-12-stage10-hybrid-controller-coverage-followup.md](../../cache-handling-phase10-implementation/part-12-stage10-hybrid-controller-coverage-followup.md)
- Action A QA process guidance (T114 citation rule):
  [part-13-qa-process-guidance.md](../../cache-handling-phase10-implementation/part-13-qa-process-guidance.md)
- Stage 10 closure rationale:
  [test-report-20260603-05.md](../../.test_reports/test-report-20260603-05.md)
- Stage 10 implementation log entry doc:
  [cache-handling-phase10-implementation.md](../../cache-handling-phase10-implementation.md)

## Scope

This part file is a test-plan enhancement. No code, test, or script
change is in scope. The Developer applies the required
`run_coverage.ps1` change in a separate gate. QA runs the next
coverage and verifies the T114a verdict rule.
