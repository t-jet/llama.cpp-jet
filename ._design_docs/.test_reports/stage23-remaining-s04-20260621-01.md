# Stage 23 remaining S04 20260621-01

Status: PASS
Date: 2026-06-21
Owner: QA
Scope: S04 only after Manager decision D23-RESUME-01. S05..S08 and
L01..L03 were not run in this sub-session.

## Gate

Run id: `stage23-remaining-s04-20260621-01`

Suffix `01` was selected because durable report, output root, and cold root
were unused.

Run root: `._test_output/stage23-remaining-s04-20260621-01`

Cold root:
`D:\tmp\cache-cold-stage23-stage23-remaining-s04-20260621-01`

Model:
`D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`

## Preflight

Evidence root: `._test_output/stage23-remaining-s04-20260621-01/preflight`

Checks:

- Branch: `01-branch.txt`; branch was `work-branch`.
- Dirty state: `02-git-status.txt`; pre-existing Stage 21/22/23 changes were
  present and were not reverted.
- CUDA build flag: `03-cmake-cuda.txt`; `GGML_CUDA:BOOL=ON`.
- CUDA device state: `04-nvidia-smi-before.txt`; two RTX 5060 Ti devices.
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
kickoff-stage20-stress-longrun.ps1 -RowsToRun S04 -RunRoot ._test_output\stage23-remaining-s04-20260621-01 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s04-20260621-01 -CachePromptEvidenceDir ._test_output\stage23-remaining-s04-20260621-01\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

Evidence:

- `preflight/14-wrapper-dry-run-command.txt`
- `preflight/14-wrapper-dry-run.log`
- `preflight/14-wrapper-dry-run-exit.txt`
- `preflight/15-dry-run-side-log-checks.txt`
- `batch-summary.log.side`

Result: PASS. Dry-run exit was 0. Side log and check file show S04 only, run
root under `._test_output`, model path, `--cache-mode hybrid`,
`--cache-cold-max-mib 512`, `--cache-ram 512`, `--n-gpu-layers all`,
`--fit off`, redacted prompt evidence directory, and cold/evidence dirs.

## Live S04

Command summary:

```text
kickoff-stage20-stress-longrun.ps1 -RowsToRun S04 -RunRoot ._test_output\stage23-remaining-s04-20260621-01 -ModelPath <Qwen3.5 MTP gguf> -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s04-20260621-01 -CachePromptEvidenceDir ._test_output\stage23-remaining-s04-20260621-01\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1
```

Evidence:

- Wrapper: `preflight/17-wrapper-live-command.txt`,
  `preflight/17-wrapper-live.log`, `preflight/17-wrapper-live.err`,
  `preflight/17-wrapper-live-exit.txt`
- GPU sampling: `preflight/18-nvidia-smi-during-live.txt`
- Row output: `S04-Jnew/`
- Row files: `launch.log`, `launch.err`, `server.out.log`, `server.err.log`,
  `metrics-before.txt`, `metrics-after.txt`, `resource-samples.csv`,
  `evidence-summary.md`
- Prompt evidence: `prompt-evidence/cache-prompt-evidence.jsonl`
- Side log: `batch-summary.log.side`

CUDA evidence: PASS. Live `nvidia-smi` shows `llama-server.exe` PID 20160 on
both RTX 5060 Ti devices during S04.

## Row verdict

| Row | Verdict | Evidence | Notes |
| --- | --- | --- | --- |
| S04 | PASS | `S04-Jnew/evidence-summary.md`, `metrics-after.txt`, `server.err.log`, `batch-summary.log.side`, prompt JSONL | 30 minute run completed, wrapper exit 0, row gate OK, 6272 requests, after metrics present, no crash, no restore failure, no corrupt or unsafe restore. |

## Metrics and checks

- Wrapper: PASS. `17-wrapper-live-exit.txt` records `exit=0`; side log records
  `row_gate S04 exitCode=0 ok=True`.
- Workload: PASS. Evidence summary records 6272 requests and 1800 seconds.
  The stress threshold is met.
- Cache outcomes: PASS. `llamacpp_cache_hits_total{mode="hybrid"} 0` and
  `llamacpp_cache_misses_total{mode="hybrid"} 6272`.
- Restore safety: PASS. `llamacpp_cache_restore_failures_total 0`,
  `cache_restore_misses_total{reason="exact_entry_absent"...} 6272`,
  1441 `try_restore - found match` log lines, 6256 `no exact match` lines,
  and no crash/corrupt/unsafe restore marker.
- S04 prompt-storm behavior: PASS. Misses stayed bounded as
  `exact_entry_absent`, redacted evidence was written for every request, and
  no raw prompt text leaked.
- Redacted evidence: PASS. JSONL has 6272 records. Head/tail records contain
  redacted fields such as `namespace_hash`, token counts, checksum,
  `lookup_outcome`, and `prefix_candidate`. Raw-key regex scan count was 0 for
  prompt/message/content/role/user/assistant/system keys.
- Cold budget: PASS. Metrics show `cache_cold_bytes 0` and
  `cache_cold_budget_bytes 536870912`. Cold directory held 53,280,768 bytes,
  under the 512 MiB budget.
- Bounded pressure diagnostics: PASS. Metrics record 1302 cold evictions for
  `cold_budget_pressure`; logs record bounded demotion pressure and eviction
  diagnostics. No filesystem write failure or host allocation failure was seen.
- Checkpoint admissions: PASS for S04 scope. Metrics show 6121 checkpoint
  admission failures by descriptor shape; these were bounded misses and did
  not produce restore failures or crashes.
- `cap-exit.json`: not produced by the S04 script. This is a harness evidence
  quirk, not a row failure here, because the script completed normally, wrote
  after metrics, and the wrapper row gate passed.

## Handoff

S04 PASS. S05..S08 and L01..L03 remain not run in this sub-session.

Next owner: Manager may open a fresh S05 sub-session under D23-RESUME-01.
