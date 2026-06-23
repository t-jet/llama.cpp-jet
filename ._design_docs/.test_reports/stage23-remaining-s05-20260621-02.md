# Stage 23 remaining S05 20260621-02

Status: PASS
Date: 2026-06-21
Owner: QA
Scope: S05 only after Architect runner-contract review PASS. S06..S08 and
L01..L03 were not run in this sub-session.

## Gate

Run id: `stage23-remaining-s05-20260621-02`

Suffix `02` was selected because suffix `01` already existed across same-day
S05 report/output/cold artifacts. This keeps the latest rerun lexically latest.

Run root: `._test_output/stage23-remaining-s05-20260621-02`

Cold root:
`D:\tmp\cache-cold-stage23-stage23-remaining-s05-20260621-02`

Model:
`D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`

## Preflight

Evidence root: `._test_output/stage23-remaining-s05-20260621-02/preflight`

Checks:

- Branch: `01-branch.txt`; branch was `work-branch`.
- Dirty state: `02-git-status.txt`; pre-existing changes were not reverted.
- CUDA build flag: `03-cmake-cuda.txt`; `GGML_CUDA:BOOL=ON`.
- CUDA device state: `04-nvidia-smi-before.txt`; NVIDIA devices visible.
- Fixture: `05-fixture.txt`; model size 2,834,975,040 bytes.
- Ports: `06-port-selection.json`; 8900..8921 was free, so BasePort 8900 was
  used.
- Cold path: `07-cold-path-before.txt`; empty.
- Disk: `08-disk.txt`; D: free space exceeded 30 GiB output and 10 GiB cold
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
kickoff-stage20-stress-longrun.ps1 -RowsToRun S05 -RunRoot ._test_output\stage23-remaining-s05-20260621-02 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s05-20260621-02 -CachePromptEvidenceDir ._test_output\stage23-remaining-s05-20260621-02\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

Evidence:

- `preflight/14-wrapper-dry-run-command.txt`
- `preflight/14-wrapper-dry-run.log`
- `preflight/14-wrapper-dry-run-exit.txt`
- `preflight/15-dry-run-side-log-checks.txt`
- `preflight/16-batch-summary-after-dry-run.log.side`
- `batch-summary.log.side`

Result: PASS. Dry-run exit was 0. Side log shows S05 only, the requested model,
run root under `._test_output`, Stage 17 flags, redacted prompt evidence, and:

```text
DryRun S05 profile_allocation rowCapSeconds=1800 allocations=plain-transformer=600,target-plus-draft=600,checkpoint-dependent=600
```

## Live S05

Command summary:

```text
kickoff-stage20-stress-longrun.ps1 -RowsToRun S05 -RunRoot ._test_output\stage23-remaining-s05-20260621-02 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s05-20260621-02 -CachePromptEvidenceDir ._test_output\stage23-remaining-s05-20260621-02\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1
```

Evidence:

- Wrapper: `preflight/17-wrapper-live-command.txt`,
  `preflight/17-wrapper-live.log`, `preflight/17-wrapper-live.err`,
  `preflight/17-wrapper-live-exit.txt`
- GPU sampling: `preflight/18-nvidia-smi-during-live.txt`
- Cleanup check: `preflight/20-processes-after-live.txt`
- Row output: `S05-Jnew/plain-transformer/`,
  `S05-Jnew/target-plus-draft/`,
  `S05-Jnew/checkpoint-dependent/`
- QA metrics rollup: `S05-Jnew/qa-metrics-summary.txt`
- Prompt evidence: `prompt-evidence/cache-prompt-evidence.jsonl`
- Side log: `batch-summary.log.side`

Live wrapper exit was 0. CUDA evidence is PASS: `nvidia-smi` captured
`llama-server.exe` on both RTX 5060 Ti GPUs during the row.

Required side-log gates are present:

```text
S05 profile_allocation rowCapSeconds=1800 allocations=plain-transformer=600,target-plus-draft=600,checkpoint-dependent=600
row_gate S05 exitCode=0 ok=True evidenceFiles=20 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt missing=
batch_end #1 idx=0-0
```

## Row verdict

| Row | Verdict | Evidence | Notes |
| --- | --- | --- | --- |
| S05 | PASS | `batch-summary.log.side`, `S05-Jnew/*/evidence-summary.md`, `S05-Jnew/qa-metrics-summary.txt`, prompt JSONL | Three profiles ran 600 seconds each under the 1800 second row cap. Wrapper wrote `row_gate` and `batch_end`. |

## Metrics and checks

| Profile | Requests | Duration | Hits | Misses | Restore failures | Cold bytes | Cold budget | Prompt records |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| plain-transformer | 510 | 600s | 0 | 510 | 0 | 0 | 536870912 | 510 |
| target-plus-draft | 547 | 600s | 546 | 1 | 0 | 0 | 536870912 | 547 |
| checkpoint-dependent | 542 | 600s | 541 | 1 | 0 | 0 | 536870912 | 542 |

Checks:

- Total requests: 1599.
- Redacted prompt evidence: 1599 JSONL records.
- Raw prompt-key scan: 0 matches for prompt/message/content/role/user/assistant/system keys.
- Cold budget: `cache_cold_bytes` stayed 0, below the 512 MiB budget.
- Metrics after files: present for all three profiles.
- Error scan: 0 HTTP 500 lines and 0 `ERROR|fatal|STATUS_STACK|exception|corrupt` lines in profile server stderr files.
- Cleanup: no S05 `llama-server.exe` process remained after live wrapper exit.

## Handoff

S05 PASS. This clears the S05 runner-contract rerun gate for the current Stage
23 sequence.

Next owner: Manager. Manager may open the S06 sub-session. S06..S08 and
L01..L03 remain not run by this report.
