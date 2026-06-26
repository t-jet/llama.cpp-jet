# Part 3: Evidence plan

Status: planning
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Developer
Scope source: [cache-handling-phase26-design/part-05-stage24-rerun-plan.md](../cache-handling-phase26-design/part-05-stage24-rerun-plan.md) + [part-07-test-plan.md](../cache-handling-phase26-design/part-07-test-plan.md)

## Build evidence (Step 9)

| Check | Command | Expected |
| --- | --- | --- |
| Clean build | `cmake --build build-cuda --config Release -j --target llama-server test-cache-controller` | exit 0; no warnings on touched files |
| Binary mtime > source mtime | `Get-Item build-cuda\bin\Release\llama-server.exe \| Select-Object LastWriteTime` | newer than source .cpp files |
| Test binary built | `Get-Item build-cuda\bin\Release\test-cache-controller.exe` | exists |
| CUDA build proof | `Select-String -Path build-cuda\CMakeCache.txt -Pattern '^GGML_CUDA:BOOL=ON'` | match |

## Unit test evidence (Step 8 / 9)

| Check | Command | Expected |
| --- | --- | --- |
| Run test binary | `tests\test-cache-controller.exe` | exit 0 |
| Total count printed | grep `Total: 137 tests` | match |
| Stage 26 tests present | grep `test_stage26_cold_metric` | 5 matches |
| All 5 new tests PASS | observe stdout | each prints `PASSED` |

## Metrics format evidence (Step 11)

| Check | Source | Expected |
| --- | --- | --- |
| Old format absent | `grep -cE '^llamacpp_cache_' metrics-after.txt` | 0 |
| New format present | `grep -cE '^llamacpp:cache_' metrics-after.txt` | >= 1 |
| All 67 metrics present | count distinct metric names in `metrics-after.txt` matching `^llamacpp:` | 67 distinct names (some have multiple label sets; count families not samples) |

## Label uniqueness evidence (Step 11)

| Check | Source | Expected |
| --- | --- | --- |
| Duplicate `mode` label | `grep -cE ',mode="[^"]*",mode="' metrics-after.txt` | 0 |
| `scope` label on prompt_evidence | `grep -E '^llamacpp:cache_prompt_evidence_records_total.*scope="' metrics-after.txt` | matches with `scope` and `result` labels only |

## Cold-store drift evidence (Step 11)

| Check | Source | Expected |
| --- | --- | --- |
| Metric bytes after | `summary.json -> cold_budget.metric_bytes_after` | bounded < 512 MiB |
| Filesystem bytes after | `summary.json -> cold_budget.filesystem_bytes_after` | documented |
| Drift ratio | `summary.json -> cold_budget.drift_ratio` | target <= 1.10 (vs Stage 24 -06 baseline of 16.4x) |
| File count metric | `metrics-after.txt -> llamacpp:cache_cold_payload_count` | matches readdir count |

## Stage 24 rerun evidence (Step 11)

Report path: `._design_docs/.test_reports/test-report-20260626-01.md`

| Row | Verdict target | Failure classifier |
| --- | --- | --- |
| S02-chat native-legacy | PASS | none |
| S02-chat hybrid-stage24 | PASS or crash-with-dump | D-EXEC-24-03 carry-over |
| S03-chat native-legacy | PASS | none |
| S03-chat hybrid-stage24 | PASS or crash-with-dump | D-EXEC-24-03 |

Per-leg summary must include:

- `metrics_format_pass` (bool, true)
- `label_uniqueness_pass` (bool, true)
- `cold_store_drift_ratio` (numeric, <= 1.10 target)
- `metric_bytes_after`, `filesystem_bytes_after`, `budget_mib`
- `cuda_runtime_proof.state` (PASS)
- `cleanup.state` (PASS)
- `verdict`, `failure_classification`

## PF-03 cross-stage latency comparison (Step 11)

Per design part-05, the rerun emits per-leg latency percentiles. PF-03
closure requires:

| Row | Stage 24 -06 p50 (ms) | rerun p50 (ms) | delta | Verdict |
| --- | ---: | ---: | ---: | --- |
| S02-chat native-legacy | (from -06 report) | (from rerun) | < 25% | PASS or BLOCKED-pf-03 |
| S02-chat hybrid-stage24 | (from -06 report) | (from rerun) | < 25% | PASS or BLOCKED-pf-03 |
| S03-chat native-legacy | (from -06 report) | (from rerun) | < 25% | PASS or BLOCKED-pf-03 |
| S03-chat hybrid-stage24 | (from -06 report) | (from rerun) | < 25% | PASS or BLOCKED-pf-03 |

If any row regresses > 25%, PF-03 stays open and the test report
escalates the delta to Manager.

## Crash-dump evidence (Step 11, conditional)

If a hybrid leg crashes during the rerun:

- `.dmp` file exists under the `--crash-dump-dir` path.
- `summary.json` includes `crash_dump_path` and `crash_dump_size`.
- Crash attribution: `WinDbg !analyze -v` on the .dmp; the test
  report records the call stack top frame and the exception code.

## Carry-over closure evidence

| Carry-over | Closure path |
| --- | --- |
| D-EXEC-24-03-a (SEH) | Step 1 install + Step 11 rerun captures .dmp if any crash |
| D-EXEC-24-03-b (silent crash) | Step 11 rerun either passes (no crash) or captures .dmp (attributable) |
| D-EXEC-24-03-c (cold-store drift) | Step 2 accounting fix + Step 11 rerun shows drift_ratio <= 1.10 |
| PF-03 (cross-stage perf) | Step 11 rerun per-leg latency comparison table |
| Stage 25 S02 hybrid confirmation | Step 11 S02 hybrid verdict (PASS closes follow-up (e); FAIL-with-dump at req 48 again escalates `tx_*` routing implication) |

## Test report structure

`test-report-20260626-01.md` follows the established Stage 24 / 25
report format:

| Section | Content |
| --- | --- |
| Header | RunId, RunRoot, Route, ModelPath hash, CUDA build proof |
| Per-row table | Row \| Verdict \| Failure \| CUDA native \| CUDA hybrid \| Leak scan \| Near-prefix requests \| Near-prefix nonzero cache_n \| Hybrid cold state \| Evidence |
| Metrics format check | New section; 0 matches for `^llamacpp_cache_`, >= 1 match for `^llamacpp:cache_` |
| Label uniqueness check | New section; 0 matches for duplicate `mode` label |
| Cold-store drift | New section; metric vs filesystem per leg |
| PF-03 latency comparison | New section; per-leg p50 / p95 deltas vs Stage 24 -06 |
| Carry-over closure | New section; D-EXEC-24-03 a/b/c, PF-03, Stage 25 S02 follow-up (e) per-row status |

## Handoff

Part-03 is reviewable. Next: part-04 risks and open questions.
