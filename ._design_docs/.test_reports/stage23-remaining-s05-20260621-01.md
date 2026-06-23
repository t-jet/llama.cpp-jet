# Stage 23 remaining S05 20260621-01

Status: BLOCKED-runner-contract
Date: 2026-06-21
Owner: QA
Scope: S05 only after Manager decision D23-RESUME-01. S06..S08 and
L01..L03 were not run in this sub-session.

## Gate

Run id: `stage23-remaining-s05-20260621-01`

Suffix `01` was selected because durable report, output root, and cold root
were unused.

Run root: `._test_output/stage23-remaining-s05-20260621-01`

Cold root:
`D:\tmp\cache-cold-stage23-stage23-remaining-s05-20260621-01`

Model:
`D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`

## Status check

S05 was not still legitimately running under the Stage 23 row cap.

The Stage 23 design says stress rows use a 30 minute per-row cap. The S05 row
script runs three profiles for `DurationMin` each:

- `plain-transformer`: 1800 seconds, summary at 18:19:28
- `target-plus-draft`: 1800 seconds, summary at 18:50:02
- `checkpoint-dependent`: 1800 seconds, summary at 19:20:08

Wrapper live launch was 17:49:23. The QA tool call timed out after 45 minutes,
then a follow-up wait showed the S05 child still alive through 19:19:54. At
19:20:49 the row had no wrapper `row_gate` or `batch_end`. Evidence was
captured and S05 processes were cleaned up. This is a runner-contract block,
not product evidence for PASS.

## Preflight

Evidence root: `._test_output/stage23-remaining-s05-20260621-01/preflight`

Checks:

- Branch: `01-branch.txt`; branch was `work-branch`.
- Dirty state: `02-git-status.txt`; pre-existing changes were not reverted.
- CUDA build flag: `03-cmake-cuda.txt`; `GGML_CUDA:BOOL=ON`.
- CUDA device state: `04-nvidia-smi-before.txt`; NVIDIA devices visible.
- Fixture: `05-fixture.txt`; model size 2,834,975,040 bytes.
- Ports: `06-port-listeners-8900-8921.txt`; empty, so BasePort 8900 was used.
- Cold path: `07-cold-path-before.txt`; empty.
- Disk: `08-disk.txt`; D: free space above 30 GiB output and 10 GiB cold
  thresholds.

## Clean build

Commands:

```text
cmake --build build-cov --config Release --target clean
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target llama-server -j 4
.\build-cov\bin\Release\test-cache-controller.exe
```

Evidence:

- `preflight/09-clean.log`, `09-clean-exit.txt`
- `preflight/10-build-test-cache-controller.log`,
  `10-build-test-cache-controller-exit.txt`
- `preflight/11-build-llama-server.log`, `11-build-llama-server-exit.txt`
- `preflight/12-test-cache-controller.log`,
  `12-test-cache-controller-exit.txt`
- `preflight/13-binary-freshness.txt`

Result: PASS. All exit files record `exit=0`. Binary freshness records
`llama-server.exe`, `llama-server-impl.dll`, and
`test-cache-controller.exe` after the clean build.

## Dry run

Command summary:

```text
kickoff-stage20-stress-longrun.ps1 -RowsToRun S05 -RunRoot ._test_output\stage23-remaining-s05-20260621-01 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s05-20260621-01 -CachePromptEvidenceDir ._test_output\stage23-remaining-s05-20260621-01\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

Evidence:

- `preflight/14-wrapper-dry-run-command.txt`
- `preflight/14-wrapper-dry-run.log`
- `preflight/14-wrapper-dry-run-exit.txt`
- `preflight/15-dry-run-side-log-checks.txt`
- `preflight/16-batch-summary-after-dry-run.log.side`

Result: PASS. Dry-run exit was 0. Side log and check file show S05 only, run
root under `._test_output`, model path, `--cache-mode hybrid`,
`--cache-cold-max-mib 512`, `--cache-ram 512`, `--n-gpu-layers all`,
`--fit off`, redacted prompt evidence directory, and cold/evidence dirs.

## Live S05

Command summary:

```text
kickoff-stage20-stress-longrun.ps1 -RowsToRun S05 -RunRoot ._test_output\stage23-remaining-s05-20260621-01 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s05-20260621-01 -CachePromptEvidenceDir ._test_output\stage23-remaining-s05-20260621-01\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1
```

Evidence:

- Wrapper: `preflight/17-wrapper-live-command.txt`,
  `preflight/17-wrapper-live.log`, `preflight/17-wrapper-live.err`
- GPU sampling: `preflight/18-nvidia-smi-during-live.txt`
- Timeout/process capture: `preflight/20-wait-after-tool-timeout.txt`,
  `21-processes-after-wait.txt`, `22-*`, `23-processes-after-cleanup.txt`
- Row output: `S05-Jnew/plain-transformer/`,
  `S05-Jnew/target-plus-draft/`,
  `S05-Jnew/checkpoint-dependent/`
- Prompt evidence: `prompt-evidence/cache-prompt-evidence.jsonl`
- Side log: `batch-summary.log.side`

CUDA evidence: PASS. Live `nvidia-smi` sampling shows `llama-server.exe`
during S05.

## Row verdict

| Row | Verdict | Evidence | Notes |
| --- | --- | --- | --- |
| S05 | BLOCKED-runner-contract | `batch-summary.log.side`, `S05-Jnew/*/evidence-summary.md`, `preflight/20-wait-after-tool-timeout.txt`, `preflight/22-*` | Stage 23 caps stress rows at 30 minutes, but the S05 script ran three 30 minute profiles. Wrapper parent timed out and never wrote `row_gate` or `batch_end`. |

## Metrics and checks

- Wrapper: BLOCKED. Side log records launch but no `row_gate` or `batch_end`.
- Runtime: BLOCKED. Live command started 17:49:23. Profile summaries were
  written at 18:19:28, 18:50:02, and 19:20:08. Total S05 runtime exceeded the
  Stage 23 30 minute row cap.
- Workload evidence preserved: 4787 requests across three profiles. Profile
  summaries remain `PENDING`; QA does not upgrade them to PASS because the row
  violated the Stage 23 cap and wrapper gate.
- Cache outcomes observed but not accepted as S05 PASS: plain transformer
  0 hits / 1526 misses; target-plus-draft 1637 hits / 1 miss;
  checkpoint-dependent 1622 hits / 1 miss.
- Restore safety observed: all three `metrics-after.txt` files record
  `llamacpp_cache_restore_failures_total{mode="hybrid"} 0`.
- Redacted evidence observed: JSONL has 4787 records. Raw-key regex scan count
  was 0 for prompt/message/content/role/user/assistant/system keys.
- Cold budget observed: metrics show `cache_cold_bytes 0` and
  `cache_cold_budget_bytes 536870912` for all three profiles.
- Process cleanup: PASS after QA cleanup. `23-processes-after-cleanup.txt`
  records no S05 `llama-server.exe`.

## Classification

This is a setup/runner block. No product bug is opened from this session.

Root cause: `stress_s12_s05_mixed_workload_profiles.ps1` treats
`DurationMin=30` as per-profile duration while Stage 23 treats S05 as one
30 minute row. The wrapper dry-run cannot reveal this because it validates
flags and row selection, not internal profile duration.

## Handoff

S05 BLOCKED-runner-contract. S06..S08 and L01..L03 remain not run.

Next owner: Manager. Manager should assign a runner/automation fix or approve a
specific S05 cap interpretation before any S05 rerun. Do not open S06 until
S05 disposition is accepted.
