# Stage 10 QA handoff - 20260603-03

## 1. Context

Main report: [test-report-20260603-03.md](test-report-20260603-03.md).

This is a handoff file, not a bug-fix log. It records the open decisions and known script-quality issues for Manager triage. No product code is changed in this handoff.

## 2. No product bugs found in this execution

The two FAIL rows (T114, T115) and the one BLOCKED row (T121) are automation, evidence-blocker, and fixture-availability issues, not product defects. They are not regressions in the cache code under test.

- T114 (coverage threshold): the merged Cobertura XML is a real union merge, the denominator is correct, and the measurement is reproducible. The threshold (80%) is not met by the current focused test set.
- T115 (aggregation): the per-file table in `coverage/coverage-report.md` lists each file 8 times because the renderer concatenates per-test rows. The merged XML is correct.
- T121 (checkpoint fixture): the only available local fixture for a public probe (Qwen3-0.6B) is a plain-transformer model. The four `cache_checkpoint_*` metric rows are present and correctly shaped; they are at zero because no checkpoint-capable model is in the local fixture catalog.

## 3. T114 coverage threshold (73.15% < 80%)

### Measurement

- `coverage/coverage-merged.xml` root attributes: `line-rate="0.73145526093192603"`, `lines-covered="19889"`, `lines-valid="27191"`.
- Threshold: 80% (`line-rate >= 0.80`).
- 73.15% < 80% -> FAIL.

### Largest uncovered files

- `server-cache-hybrid.cpp` 1166/1846 (63.16%) - main hybrid file, largest uncovered surface.
- `server-cache-hybrid.h` 78/140 (55.71%) - header.
- `server-cache-store-cold.cpp` 174/218 (79.82%) - close to threshold.
- `server-cache-store-cold.h` 20/27 (74.07%) - header.
- `server-cache-policy-lru.cpp` 19/27 (70.37%).

The two `0%` files (`server-cache-controller.h`, `server-cache-legacy.h`) are 1-5 line headers with no executable lines; they do not move the needle.

### T114 recommendations (handed to Manager)

1. Add focused tests for the uncovered hybrid paths in `server-cache-hybrid.cpp`/`.h` and `server-cache-store-cold.cpp`/`.h` to lift the union rate above 80%. This is the preferred option.
2. Raise the threshold to match the actual measured coverage (for example, 73% or 75%) with an explicit Manager decision recorded against the cache-handling test plan.
3. Reclassify T114 as BLOCKED-with-coverage-evidence until a checkpoint-capable public fixture is added, since the public probe paths are limited to plain-transformer behaviour in the current fixture catalog.

The decision belongs to Manager. QA will not adjust the threshold unilaterally.

## 4. T115 coverage denominator aggregation bug in `run_coverage.ps1`

### T115 observation

- `coverage/coverage-report.md` per-file table lists each file 8 times (once per focused test). This is a renderer bug.
- The merged `coverage/coverage-merged.xml` is a true union merge produced with OpenCppCoverage `--input_coverage`, not a sum. The XML is the authoritative source.

### Recommendation (handed to Developer)

- Fix the report-generation logic in `run_coverage.ps1` (or its associated renderer) to aggregate per-file line rates from the merged XML, not from the per-test Cobertura exports.
- The merged XML should be the single source of truth for both line rate and per-file breakdown in the rendered markdown.

The merged XML is not changed by this fix; only the per-file table in `coverage-report.md` becomes correct.

## 5. T121 checkpoint-capable fixture

### Fixture observation

- Qwen3-0.6B (used as the public probe fixture) is plain-transformer.
- The four `cache_checkpoint_*` rows in `metrics-checkpoint-excerpt.txt` are correctly shaped but remain at zero.
- Focused substitute evidence in `test-cache-controller` covers checkpoint descriptor validation, pair validation, and metric label shape for the public row.

### T121 recommendations (handed to Manager)

1. Add a checkpoint-capable model to the local fixture catalog. The `Qwen3.5-4B-MTP-GGUF` directory in `D:\source\llama.cpp-jet\._test_models\` may be a candidate; it requires the MTP/draft path to be exercised by the public probe and validated against the public `cache_checkpoint_*` rows.
2. Re-scope T121 to use focused-substitute evidence for the public row, with an explicit Manager decision recorded against the cache-handling test plan.

The fixture-catalog and scope decisions belong to Manager.

## 6. Coverage report and metrics parser hygiene

Two script-quality items are open after this run:

- `coverage/coverage-report.md` per-file aggregation bug (T115) - lists each file 8 times.
- `bench/evidence-summary.md` parsing bug - the original showed public Prometheus hits/misses deltas of 0/0/0 because the metrics-extract step read the file before all k6 traffic had incremented the counters. The corrected `bench/evidence-summary.md` is in the same artifacts directory and is what the main report references.

Both items are recorded for the next Developer pass on `run_coverage.ps1` and `run_benchmark_k6.ps1`. The corrected `bench/evidence-summary.md` is part of this artifacts bundle.

## 7. Handoff

- Manager to route the open decisions (T114 threshold, T115 script fix, T121 fixture scope) per the project workflow.
- Developer, in a fresh session, to fix the `run_coverage.ps1` per-file aggregation bug and the `run_benchmark_k6.ps1` metrics-extract ordering bug.
- QA to re-run the affected rows once the above changes ship, and to update this handoff file with the new outcomes.
