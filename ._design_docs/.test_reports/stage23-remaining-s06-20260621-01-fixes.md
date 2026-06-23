# Stage 23 S06 runner-contract fix

Status: ready for Architect review
Date: 2026-06-21
Owner: Developer
Trigger: [stage23-remaining-s06-20260621-01.md](stage23-remaining-s06-20260621-01.md)
Scope: runner/script contract only. No product code, public flags, public
metrics, tests, fixtures, commits, or pushes changed.

## Root cause

S06 is the cold queue pressure row. Its child script starts llama-server with a
small hot cache budget:

```text
--cache-ram 16
```

The Stage 23 wrapper encoded common Stage 17 flags in
`Stage17ServerArgsBase64` and appended them after the child script's local
flags. For S06 that appended:

```text
--cache-ram 512
```

The server uses the later duplicate flag value. The live row therefore used a
512 MiB hot cache budget. A single 50.595 MiB hot entry did not create cold
pressure, so there were 0 demotions, 0 skipped demotions, 0 cold evictions, and
0 cold files. QA correctly marked the row `BLOCKED-runner-contract`.

## Changed files

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/.test_reports/stage23-remaining-s06-20260621-01-fixes.md`

## Behavior after fix

For S06 only, the wrapper no longer includes `--cache-ram <CacheRamMib>` in the
encoded Stage 17 flag list. The wrapper now passes the child script:

```text
-HotBudgetMiB 16
```

The child script still owns the S06 local pressure flag:

```text
--cache-ram 16
```

The required Stage 23 flags still pass through S06:

```text
--cache-mode hybrid
--cache-cold-max-mib 512
--n-gpu-layers all
--fit off
--cache-cold-path <row cold root>
--cache-prompt-evidence redacted
--cache-prompt-evidence-dir <row evidence root>
```

The S06 dry-run and live side log now record:

```text
S06 hot_budget effective_cache_ram_mib=16 source=S06-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false
```

Other rows still receive wrapper `--cache-ram 512` when the wrapper is invoked
with `-CacheRamMib 512`.

## Evidence commands and results

Parser checks:

```text
[System.Management.Automation.Language.Parser]::ParseFile(...kickoff-stage20-stress-longrun.ps1...)
result: parser ok: kickoff-stage20-stress-longrun.ps1

[System.Management.Automation.Language.Parser]::ParseFile(...stress_s12_s06_cold_queue_pressure.ps1...)
result: parser ok: stress_s12_s06_cold_queue_pressure.ps1
```

S06 wrapper dry-run:

```text
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S06 -RunRoot ._test_output\stage23-s06-contract-fix-dryrun -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -CacheColdPath D:\tmp\cache-cold-stage23-s06-contract-fix-dryrun -CachePromptEvidenceDir ._test_output\stage23-s06-contract-fix-dryrun\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8990 -BatchSize 1 -DryRun
exit: 0
```

Side-log evidence:

```text
DryRun OK S06 ... flags='--cache-mode hybrid --cache-cold-max-mib 512 --n-gpu-layers all --fit off --cache-cold-path D:\tmp\cache-cold-stage23-s06-contract-fix-dryrun --cache-prompt-evidence redacted --cache-prompt-evidence-dir ._test_output\stage23-s06-contract-fix-dryrun\prompt-evidence'
DryRun S06 hot_budget effective_cache_ram_mib=16 source=S06-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false
```

The S06 flags line contains no wrapper `--cache-ram 512`. The side log states
that the final intended hot cache budget is 16 MiB before any live rerun.

Focused side-log assertion:

```text
S06HasCacheRam512 : False
S06HasEffective16 : True
S06HasColdMax512  : True
S06HasCudaAll     : True
S06HasFitOff      : True
S06HasRedacted    : True
```

Non-S06 guard:

```text
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S04 ... -CacheRamMib 512 -DryRun
exit: 0
```

Side-log evidence:

```text
DryRun OK S04 ... flags='--cache-mode hybrid --cache-cold-max-mib 512 --cache-ram 512 --n-gpu-layers all --fit off --cache-cold-path D:\tmp\cache-cold-stage23-s06-contract-fix-dryrun-s04 --cache-prompt-evidence redacted --cache-prompt-evidence-dir ._test_output\stage23-s06-contract-fix-dryrun-s04\prompt-evidence'
```

This confirms rows that rely on wrapper `-CacheRamMib 512` still receive it.

## Retest scope

Do not rerun full S/L matrix for this fix review. Suggested QA retest after
Architect review:

- S06 wrapper dry-run with the Stage 23 command shape.
- Focused live S06 row only, with a fresh output root and cold root.
- Confirm live side log contains the S06 hot budget line.
- Confirm `S06-Jnew/evidence-summary.md` contains only one effective
  `--cache-ram`, value 16.
- Confirm server startup log reports the hot cache limit as 16 MiB.
- Confirm cold pressure appears as demotion, skip, or eviction evidence before
  classifying the row.

## Handoff

Next owner: Architect.

Review the runner contract change before QA reruns S06. S07 must stay closed
until Manager accepts the S06 disposition or authorizes the focused rerun.
