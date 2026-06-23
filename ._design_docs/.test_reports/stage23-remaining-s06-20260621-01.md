# Stage 23 remaining S06 20260621-01

Status: BLOCKED-runner-contract
Date: 2026-06-21
Owner: QA
Scope: S06 only under D23-RESUME-01. S07..S08 and L01..L03 were not run.

## Gate

Run id: `stage23-remaining-s06-20260621-01`

Suffix `01` was unused across durable report, `._test_output`, and cold roots
before reservation. A local preflight helper syntax error happened after root
reservation and before build, dry-run, or live execution; the same root was
kept and the error note is preserved in `preflight/00-run-id-rationale.txt`.

Run root: `._test_output/stage23-remaining-s06-20260621-01`

Cold root:
`D:\tmp\cache-cold-stage23-stage23-remaining-s06-20260621-01`

Model:
`D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`

## Preflight

Evidence root: `._test_output/stage23-remaining-s06-20260621-01/preflight`

Checks:

- Branch: `01-branch.txt`; branch was `work-branch`.
- Dirty state: `02-git-status.txt`; pre-existing changes were not reverted.
- CUDA build flag: `03-cmake-cuda.txt`; `GGML_CUDA:BOOL=ON`.
- CUDA device state: `04-nvidia-smi-before.txt`; NVIDIA devices visible.
- Fixture: `05-fixture.txt`; Qwen3.5 MTP model found.
- Ports: `06-port-selection.json`; 8900..8921 was free, so BasePort 8900 was used.
- Cold path: `07-cold-path-before.txt` and `16-cold-path-before-live.txt`; empty.
- Disk: `08-disk.txt`; D: free space exceeded 30 GiB output and 10 GiB cold thresholds.

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
`llama-server.exe`, `llama-server-impl.dll`, and `test-cache-controller.exe`
after the clean build.

## Dry run

Command summary:

```text
kickoff-stage20-stress-longrun.ps1 -RowsToRun S06 -RunRoot ._test_output\stage23-remaining-s06-20260621-01 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s06-20260621-01 -CachePromptEvidenceDir ._test_output\stage23-remaining-s06-20260621-01\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

Evidence:

- `preflight/14-wrapper-dry-run-command.txt`
- `preflight/14-wrapper-dry-run.log`
- `preflight/14-wrapper-dry-run-exit.txt`
- `preflight/15-dry-run-side-log-checks.txt`
- `preflight/16-batch-summary-after-dry-run.log.side`
- `batch-summary.log.side`

Result: PASS. Dry-run exit was 0. Side-log checks confirm S06 only, requested
model, run root under `._test_output`, cold root, redacted prompt evidence,
`--n-gpu-layers all`, `--fit off`, `--cache-cold-max-mib 512`, and
`--cache-ram 512`.

## Live S06

Command summary:

```text
kickoff-stage20-stress-longrun.ps1 -RowsToRun S06 -RunRoot ._test_output\stage23-remaining-s06-20260621-01 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s06-20260621-01 -CachePromptEvidenceDir ._test_output\stage23-remaining-s06-20260621-01\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1
```

Evidence:

- Wrapper: `preflight/17-wrapper-live-command.txt`,
  `preflight/17-wrapper-live.log`, `preflight/17-wrapper-live.err`,
  `preflight/17-wrapper-live-exit.txt`
- GPU sampling: `preflight/18-nvidia-smi-during-live.txt`
- Cleanup check: `preflight/20-processes-after-live.txt`
- Cold after-live summary: `preflight/21-cold-path-after-live.txt`
- Row output: `S06-Jnew/`
- QA metrics rollup: `S06-Jnew/qa-metrics-summary.txt`
- Prompt evidence: `prompt-evidence/cache-prompt-evidence.jsonl`
- Side log: `batch-summary.log.side`

Live wrapper exit was 0. CUDA evidence is PASS: server startup logs list CUDA0
and CUDA1 as RTX 5060 Ti devices, and `nvidia-smi` captured
`llama-server.exe` on both GPUs during the row.

Required side-log gates are present:

```text
batch_gate #1 ports=8900 listeners= diskFreeBytes=1599891685376 coldItems=0 runRootWritable=true
row_gate S06 exitCode=0 ok=True evidenceFiles=8 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt missing=
batch_end #1 idx=0-0
```

## Row verdict

| Row | Verdict | Evidence | Notes |
| --- | --- | --- | --- |
| S06 | BLOCKED-runner-contract | `batch-summary.log.side`, `S06-Jnew/evidence-summary.md`, `S06-Jnew/qa-metrics-summary.txt`, prompt JSONL | Wrapper and server ran cleanly for 1800 seconds and 1596 requests, but the cold queue pressure behavior was not exercised. |

## Metrics and checks

| Check | Value |
| --- | --- |
| Requests | 1596 |
| Hits | 0 |
| Misses | 1596 |
| Restore miss reason | `exact_entry_absent`, 1596 |
| Prompt records | 1596 JSONL and 1596 metric records |
| Raw prompt-key scan | 0 matches for prompt/message/content/role/user/assistant/system keys |
| Cold bytes | 0 |
| Cold budget | 536870912 bytes |
| Cold files | 0 max in `resource-samples.csv`; cold root empty after live |
| Demotions/promotions/cold evictions/skips | 0 |
| Error scan | 0 HTTP 500, ERROR, fatal, STATUS_STACK, exception, corrupt, or write-failure lines |

The runner appends Stage 23 flags after the S06 script's local pressure flags.
`S06-Jnew/evidence-summary.md` shows both `--cache-ram 16` and later
`--cache-ram 512`; server logs show the effective limit as 512.000 MiB. With a
single 50.595 MiB hot entry, the row did not force demotion, queue pressure,
skip, or eviction. That blocks the S06 acceptance check
"cold demotions skip or evict before write failure" without showing a product
bug.

## Handoff

S06 is BLOCKED-runner-contract. Product behavior did not crash, leak raw prompt
evidence, corrupt restore, or write-fail. The row did not test the required
cold pressure path under the requested Stage 23 `-CacheRamMib 512` wrapper
shape.

Next owner: Manager. Manager should decide whether S06 needs a runner contract
fix or a scoped rerun with a cold-pressure hot budget before opening S07.
