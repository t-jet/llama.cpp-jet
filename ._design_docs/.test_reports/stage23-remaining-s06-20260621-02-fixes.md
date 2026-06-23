# Stage 23 S06 pressure-workload fix

Status: ready for Architect review
Date: 2026-06-22
Owner: Developer
Trigger: [stage23-remaining-s06-20260621-02.md](stage23-remaining-s06-20260621-02.md)
Scope: runner workload only. No product code, public server flags, public
metrics, tests, fixtures, commits, or pushes changed.

## Root cause

The S06 rerun 02 fixed the previous flag precedence bug: the live server used
the intended 16 MiB hot payload budget.

The row still did not create cold pressure because its Qwen3.5 MTP payload was
larger than the hot budget. Server logs from rerun 02 show each short request
tried to save an about 50.595 MiB payload:

```text
save rejected because payload bytes exceed hot budget
payload bytes: 53052428
budget bytes: 16777216
```

That rejection happens before the cache admits a hot payload. With no admitted
payloads, the row cannot demote, evict cold files, or skip demotions.

## Changed files

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/.test_reports/stage23-remaining-s06-20260621-02-fixes.md`

## Workload behavior after fix

S06 still runs with a 16 MiB hot payload budget and keeps the required Stage 23
server flags:

```text
--cache-mode hybrid
--cache-cold-max-mib 512
--n-gpu-layers all
--fit off
--cache-cold-path <row cold root>
--cache-prompt-evidence redacted
--cache-prompt-evidence-dir <row evidence root>
```

For S06 only, the wrapper now exposes a pressure fixture:

```text
._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf
```

The S06 script uses that fixture when it exists. The Stage 23 primary model
path remains recorded in the evidence summary, but the pressure workload uses
the smaller fixture because it admits about 3.4 to 3.8 MiB payloads under the
16 MiB hot budget. The wrapper side log records:

```text
DryRun S06 pressure_workload pressure_model=<0.6B fixture> pressure_model_state=available mtp_variant=2 unique_prompt_per_request=true expected_payload_fit=below_16MiB
```

The request loop now sends a deterministic unique prompt per request. The
script also samples the effective Stage 23 cold path from decoded Stage 17
flags, so `resource-samples.csv` reports real cold files instead of the local
fallback temp path.

## Evidence commands and results

Parser checks:

```text
[System.Management.Automation.Language.Parser]::ParseFile(...kickoff-stage20-stress-longrun.ps1...)
result: parser ok

[System.Management.Automation.Language.Parser]::ParseFile(...stress_s12_s06_cold_queue_pressure.ps1...)
result: parser ok
```

Wrapper dry-run:

```text
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S06 -RunRoot ._test_output\stage23-s06-pressure-fix-dryrun -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -CacheColdPath D:\tmp\cache-cold-stage23-s06-pressure-fix-dryrun -CachePromptEvidenceDir ._test_output\stage23-s06-pressure-fix-dryrun\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8990 -BatchSize 1 -DryRun
exit: 0
```

Dry-run side log confirmed S06 kept CUDA all, fit off, cold max 512, redacted
prompt evidence, cold path, evidence dir, and effective hot budget 16. It also
confirmed pressure model available and unique prompts enabled.

Direct child dry-run confirmed the S06 script decodes the Stage 17 cold path:

```text
cold-path=D:\tmp\cache-cold-stage23-s06-pressure-fix-child-dryrun2
pressure-model=True
unique-prompts=true
```

Four-minute direct child smoke:

```text
Out:  ._test_output/stage23-s06-pressure-fix-smoke4m
Cold: D:\tmp\cache-cold-stage23-s06-pressure-fix-smoke4m
Duration: 240 seconds
Request count: 215
```

Smoke metrics:

```text
llamacpp_cache_payload_demotions_total{mode="hybrid"} 214
llamacpp_cache_payload_cold_evictions_total{mode="hybrid"} 72
cache_cold_evictions_total{mode="hybrid",reason="cold_budget_pressure",payload_kind="exact_blob"} 72
cache_cold_bytes{mode="hybrid"} 534372000
cache_cold_budget_bytes{mode="hybrid"} 536870912
llamacpp_cache_demotion_failure_write_error_total{mode="hybrid"} 0
```

Cold-path evidence:

```text
resource-samples.csv tail cold_files: 142
cold files on disk: 142
cold bytes on disk: 534381088
```

Error scan:

```text
HTTP 500=0
ERROR=0
fatal=0
STATUS_STACK=0
exception=0
corrupt=0
write failure=0
write_error=0
save rejected because payload bytes exceed hot budget=0
```

No full 30 minute S06 live row was run.

## Retest scope

After Architect review, QA should run focused S06 only with a fresh durable
report suffix, fresh output root, and fresh cold root. S07 must stay closed
until Manager accepts the S06 disposition or authorizes the focused rerun.

QA checks for the focused S06 rerun:

- wrapper side log contains `S06 pressure_workload`
- live evidence summary uses `Qwen3-0.6B-Q8_0.gguf` as pressure model and
  records the Qwen3.5 primary model in notes
- server startup uses hot limit 16 MiB and cold budget 512 MiB
- after metrics show non-zero demotions
- after metrics show cold eviction or cold demotion skip before any write
  failure
- redacted prompt evidence is present and raw prompt scan is clean
- cold bytes stay at or below the 512 MiB budget

## Handoff

Next owner: Architect.

Review the S06 workload change before Manager authorizes QA to rerun focused
S06. This fix keeps product code and public surfaces untouched.
