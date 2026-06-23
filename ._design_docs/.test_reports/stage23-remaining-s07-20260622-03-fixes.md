# Stage 23 S07 pressure-workload fix

Status: ready for Architect review
Date: 2026-06-22
Owner: Developer
Trigger: [stage23-remaining-s07-20260622-03.md](stage23-remaining-s07-20260622-03.md)
Scope: S07 runner/workload/docs only. No product code, public flags, public
metrics, tests, fixtures, commits, or pushes changed.

## Root cause

The focused S07 rerun 03 fixed the prior duplicate flag bug. Dry-run and live
evidence used the intended 8 MiB hot cache budget, with no later wrapper
`--cache-ram 512` override.

The workload still could not create pressure because the primary Qwen3.5 MTP
fixture saves about 50 MiB per entry:

```text
payload bytes: 53150792
budget bytes: 8388608
```

Every save was rejected before any payload could be admitted. Protected-root
decisions, protected-root demotions, payload evictions, and payload demotions
therefore all stayed 0. This is a workload evidence gap, not a product failure.

## Changed files

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-03-fixes.md`

## Workload behavior after fix

S07 keeps the 8 MiB hot budget and required Stage 23 flags:

```text
--cache-mode hybrid
--cache-cold-max-mib 512
--n-gpu-layers all
--fit off
--cache-cold-path <row cold root>
--cache-prompt-evidence redacted
--cache-prompt-evidence-dir <row evidence root>
```

For S07 only, the wrapper now exposes the same small pressure fixture pattern
used by S06:

```text
._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf
```

The S07 child uses that fixture when available. The Stage 23 primary Qwen3.5
model remains in wrapper notes and the evidence summary. The S07 child now sends
a deterministic unique non-protected pressure prompt on each loop so the hot
payload budget is crossed after at least one entry has been admitted.

The wrapper side log records:

```text
DryRun S07 pressure_workload pressure_model=<0.6B fixture> pressure_model_state=available mtp_variant=2 unique_nonprotected_prompt_per_request=true expected_payload_fit=below_8MiB primary_model=<Qwen3.5 primary>
```

S06 behavior is unchanged: it keeps its 16 MiB hot budget, S06 pressure fixture,
and unique prompt workload. Non-pressure rows still receive wrapper
`--cache-ram 512`.

## Evidence commands and results

Parser checks:

```text
PARSER_OK ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1
PARSER_OK ._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1
PARSER_OK ._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1
```

S07 wrapper dry-run:

```text
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S07 -RunRoot ._test_output\stage23-s07-workload-fix-dryrun -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -CacheColdPath D:\tmp\cache-cold-stage23-s07-workload-fix-dryrun -CachePromptEvidenceDir ._test_output\stage23-s07-workload-fix-dryrun\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8992 -BatchSize 1 -DryRun
exit: 0
```

S07 dry-run side log:

```text
DryRun OK S07 ... flags='--cache-mode hybrid --cache-cold-max-mib 512 --n-gpu-layers all --fit off --cache-cold-path D:\tmp\cache-cold-stage23-s07-workload-fix-dryrun --cache-prompt-evidence redacted --cache-prompt-evidence-dir ._test_output\stage23-s07-workload-fix-dryrun\prompt-evidence'
DryRun S07 hot_budget effective_cache_ram_mib=8 source=S07-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false
DryRun S07 pressure_workload pressure_model=D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf pressure_model_state=available mtp_variant=2 unique_nonprotected_prompt_per_request=true expected_payload_fit=below_8MiB primary_model=D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf
```

Guard dry-runs:

```text
S06 dry-run exit 0; flags omit wrapper --cache-ram 512; effective_cache_ram_mib=16; S06 pressure_workload unchanged.
S04 dry-run exit 0; flags include wrapper --cache-ram 512.
```

One-minute direct S07 child smoke:

```text
Out: ._test_output/stage23-s07-workload-fix-smoke1m-final
Cold: D:/tmp/cache-cold-stage23-s07-workload-fix-smoke1m-final
Duration: 60 seconds
exit: 0
request count: 150
```

Smoke metrics:

```text
llamacpp_cache_entries{mode="hybrid"} 51
llamacpp_cache_bytes{mode="hybrid"} 3333443
llamacpp_cache_hits_total{mode="hybrid"} 38
llamacpp_cache_misses_total{mode="hybrid"} 112
llamacpp_cache_payload_evictions_total{mode="hybrid"} 1
llamacpp_cache_payload_demotions_total{mode="hybrid"} 129
llamacpp_cache_payload_cold_evictions_total{mode="hybrid"} 19
cache_payload_evictions_by_shape_total{mode="hybrid",payload_kind="exact_blob",pair_state="target_only",result="success",reason="hot_budget"} 1
```

Smoke log checks:

```text
startup/server state: limits: 8.000 MiB payload, 512 tokens
oversize rejects: 0
demotion completed lines: present
```

This proves the fixed workload admits payloads under the 8 MiB budget and
crosses the pressure boundary. The smoke is not a substitute for the full 30
minute QA row.

## Review note

The smoke still shows public protected-root decision counters at 0. That is not
new: public S07 requests use degraded metadata for protected-looking prompt
strings, while trusted protected-root counters require non-degraded protected
metadata. This fix closes the Qwen3.5 oversize workload gap and gives QA live
payload-pressure evidence. Architect should decide whether S07 acceptance also
requires a product or harness path for trusted protected-root metadata before
QA reruns the full focused row.

## Retest scope

After Architect review, QA should run focused S07 only with a fresh durable
report suffix, output root, and cold root. Do not run S08 or L01..L03.

QA checks:

- wrapper side log contains `S07 pressure_workload`
- live evidence summary records pressure model `Qwen3-0.6B-Q8_0.gguf` and the
  primary Qwen3.5 model in notes
- server startup reports 8 MiB hot limit and 512 MiB cold budget
- no wrapper `--cache-ram 512` override appears for S07
- after metrics show admitted entries plus non-zero payload demotions or payload
  evictions
- protected-root counters are reviewed against Architect's decision above
- redacted prompt evidence is present and raw prompt scan is clean
- cold bytes stay at or below the 512 MiB budget

## Handoff

Next owner: Architect.

Review the S07 workload change before Manager authorizes QA to rerun focused
S07. S08 and L01..L03 stay stopped.
