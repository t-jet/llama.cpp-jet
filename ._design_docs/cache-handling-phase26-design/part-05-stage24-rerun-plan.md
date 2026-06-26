# Part 5: Stage 24 rerun plan

Status: design draft
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope: re-run Stage 24 S02/S03 cases against the post-metrics binary
so prior Stage 24 evidence stays comparable and the carry-over status
is verifiable.

## Goal

Re-execute the Stage 24 chat-completion S02/S03 comparison using the
existing `stage24-chat-s02-s03-comparison.ps1` runner, with the
following deltas to the runner:

- `--crash-dump-dir` is set on the server (when SEH handler is
  installed).
- Runner summary records the new metrics-format check result and
  the new label-uniqueness check result.
- Comparison JSON records the new fields
  `metrics_format_pass` (bool) and `label_uniqueness_pass` (bool).
- Runner records `cold_store_drift_ratio` =
  `filesystem_bytes_after / max(metric_bytes_after, 1)` so the
  cold-store drift from part-04 is tracked.

All other runner parameters (model path, port, leg duration,
cold-budget MiB, dry-run gate, leak scan, unsafe-prefix check)
stay unchanged. The runner script is modified in this stage to
emit the new fields; the existing fields stay byte-compatible.

## Command family

```powershell
& ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
    -RunId stage26-rerun-20260626-NN `
    -RowsToRun S02-chat,S03-chat `
    -ModelPath '._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
    -RunRoot '._test_output\stage26-rerun-20260626-NN' `
    -ReportPath '._design_docs\.test_reports\test-report-20260626-NN.md' `
    -CacheColdPath 'D:\tmp\cache-cold-stage26' `
    -BasePort 8900 `
    -LegDurationMin 10 `
    -ColdBudgetMiB 512 `
    -LlamaServerPath 'build-cuda\bin\Release\llama-server.exe'
```

## Verification checklist (per leg)

| Check | Source | Expected |
| --- | --- | --- |
| CUDA build proof | `build-cuda/CMakeCache.txt` `GGML_CUDA:BOOL=ON` | PASS |
| Binary mtime > source mtime | `cmake --build` exits 0 | PASS |
| Fixture present | `._test_models/.../Qwen3.5-4B-Q4_K_M.gguf` | PASS |
| Dry-run gate | `dry-run-plan.json` `cuda_build_proof.state = PASS` | PASS |
| `/metrics` reachable | runner health check | PASS |
| `metrics-before.txt` non-empty | runner artifact | PASS |
| `metrics-after.txt` non-empty | runner artifact | PASS |
| Metrics format = `llamacpp:` | grep `^llamacpp_` (underscore) | 0 matches |
| Metrics format = `llamacpp:` | grep `^llamacpp:` (colon) | >= 1 match |
| Label uniqueness | grep `,mode=.*,mode=` | 0 matches |
| Leak scan | `final-leak-scan.json` | PASS |
| Cold budget | metric or filesystem within 512 MiB | PASS |
| Cold-store drift ratio | filesystem / metric | documented, target <= 1.10 |
| Unsafe-prefix cache_n | hybrid near-prefix | 0 |
| CUDA runtime proof | leg summary | PASS |
| Cleanup | leg summary | PASS |
| Crash dump captured (if crash) | `--crash-dump-dir` artifacts | optional, depends on crash |

## Per-row verdicts (target)

| Row | Target verdict | Failure classifier |
| --- | --- | --- |
| S02-chat native-legacy | PASS | none |
| S02-chat hybrid-stage24 | PASS or crash-with-dump | depends on carry-over fix outcomes |
| S03-chat native-legacy | PASS | none |
| S03-chat hybrid-stage24 | PASS or crash-with-dump | depends on D-EXEC-24-03 |

If S02 hybrid rerun PASSES (was FAIL in Stage 25-01 at req 48),
the Stage 25 follow-up (e) on `tx_*` routing acceleration is closed
as not implicated. If S02 hybrid rerun FAILS again, the Stage 25
follow-up (e) is escalated: the `tx_*` routing is implicated and
escalation follows in the test report.

If S03 hybrid rerun captures a crash dump, the dump is loaded in
WinDbg and the call stack / faulting instruction is recorded in the
test report's handoff section. The crash is attributed to either
the hybrid cache path or a layer below (Windows process termination)
per the dump contents.

## Comparison vs Stage 24 -06 baseline

PF-03 closure requires a side-by-side latency comparison. The
runner emits `comparison.json` per row with the same fields as
Stage 24 -06 (planned / observed / status_counts / cache_n_nonzero_rate
/ prompt_evidence / metric_deltas / cold_budget). The new fields
above are appended. The test report includes a per-leg latency
comparison table:

| Row | -06 p50 (ms) | rerun p50 (ms) | -06 p99 (ms) | rerun p99 (ms) | delta |
| --- | ---: | ---: | ---: | ---: | ---: |

If the rerun latency is within 25% of the Stage 24 -06 baseline,
PF-03 is closed as "no regression". If the rerun latency regresses
>25%, PF-03 stays open and the test report escalates the delta.

## Handoff

Part-05 is reviewable. Implementation order in part-06 runs the
carry-over fixes (parts 03, 04) and the metrics alignment (part 02)
before the rerun, so the rerun produces post-fix evidence.
