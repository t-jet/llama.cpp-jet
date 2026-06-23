# Stage 23 S07 runner-contract fix

Status: ready for Architect review
Date: 2026-06-22
Owner: Developer
Trigger: [stage23-remaining-s07-20260622-01.md](stage23-remaining-s07-20260622-01.md)
Scope: S07 runner/script contract only. No product code, public flags, public
metrics, tests, fixtures, commits, or pushes changed.

## Root cause

S07 is the protected-root pressure row. Its child script starts llama-server
with a small hot cache budget:

```text
--cache-ram 8
```

The Stage 23 wrapper encoded common Stage 17 flags in
`Stage17ServerArgsBase64` and appended them after the child script's local
flags. For S07 that appended:

```text
--cache-ram 512
```

The server uses the later duplicate flag value. The live row therefore used a
512 MiB hot cache budget. The row completed requests, but it never put pressure
on protected roots: protected-root decisions, protected-root demotions, payload
evictions, and demotions all stayed 0. QA correctly marked the row
`BLOCKED-runner-contract`.

## Changed files

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-01-fixes.md`

## Behavior after fix

For S07 only, the wrapper no longer includes `--cache-ram <CacheRamMib>` in the
encoded Stage 17 flag list. The wrapper now passes the child script:

```text
-HotBudgetMiB 8
```

The child script still owns the S07 local protected-root pressure flag:

```text
--cache-ram 8
```

The required Stage 23 flags still pass through S07:

```text
--cache-mode hybrid
--cache-cold-max-mib 512
--n-gpu-layers all
--fit off
--cache-cold-path <row cold root>
--cache-prompt-evidence redacted
--cache-prompt-evidence-dir <row evidence root>
```

The S07 dry-run and live side log now record:

```text
S07 hot_budget effective_cache_ram_mib=8 source=S07-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false
```

S06 behavior is preserved: S06 still omits wrapper `--cache-ram 512`, still
receives `-HotBudgetMiB 16`, and still prints `effective_cache_ram_mib=16`.
Rows that rely on wrapper `-CacheRamMib 512` still receive `--cache-ram 512`.

## Evidence commands and results

Parser checks:

```text
[System.Management.Automation.Language.Parser]::ParseFile(...kickoff-stage20-stress-longrun.ps1...)
result: parser ok: kickoff-stage20-stress-longrun.ps1

[System.Management.Automation.Language.Parser]::ParseFile(...stress_s12_s07_protected_root_pressure.ps1...)
result: parser ok: stress_s12_s07_protected_root_pressure.ps1
```

S07 wrapper dry-run:

```text
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S07 -RunRoot ._test_output\stage23-s07-contract-fix-dryrun -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -CacheColdPath D:\tmp\cache-cold-stage23-s07-contract-fix-dryrun -CachePromptEvidenceDir ._test_output\stage23-s07-contract-fix-dryrun\prompt-evidence -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8992 -BatchSize 1 -DryRun
exit: 0
```

Side-log evidence:

```text
DryRun OK S07 ... flags='--cache-mode hybrid --cache-cold-max-mib 512 --n-gpu-layers all --fit off --cache-cold-path D:\tmp\cache-cold-stage23-s07-contract-fix-dryrun --cache-prompt-evidence redacted --cache-prompt-evidence-dir ._test_output\stage23-s07-contract-fix-dryrun\prompt-evidence'
DryRun S07 hot_budget effective_cache_ram_mib=8 source=S07-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false
```

Focused side-log assertion:

```text
S07HasCacheRam512 : False
S07HasEffective8  : True
S07HasColdMax512  : True
S07HasCudaAll     : True
S07HasFitOff      : True
S07HasRedacted    : True
S04HasCacheRam512 : True
S06HasCacheRam512 : False
S06HasEffective16 : True
```

Non-S07 guard:

```text
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S04 ... -CacheRamMib 512 -DryRun
exit: 0

DryRun OK S04 ... flags='--cache-mode hybrid --cache-cold-max-mib 512 --cache-ram 512 --n-gpu-layers all --fit off --cache-cold-path D:\tmp\cache-cold-stage23-s07-contract-fix-dryrun-s04 --cache-prompt-evidence redacted --cache-prompt-evidence-dir ._test_output\stage23-s07-contract-fix-dryrun-s04\prompt-evidence'
```

S06 regression guard:

```text
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S06 ... -CacheRamMib 512 -DryRun
exit: 0

DryRun OK S06 ... flags='--cache-mode hybrid --cache-cold-max-mib 512 --n-gpu-layers all --fit off --cache-cold-path D:\tmp\cache-cold-stage23-s07-contract-fix-dryrun-s06 --cache-prompt-evidence redacted --cache-prompt-evidence-dir ._test_output\stage23-s07-contract-fix-dryrun-s06\prompt-evidence'
DryRun S06 hot_budget effective_cache_ram_mib=16 source=S06-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false
```

## Retest scope

Do not rerun full S/L matrix for this fix review. Suggested QA retest after
Architect review:

- S07 wrapper dry-run with the Stage 23 command shape.
- Focused live S07 row only, with a fresh output root and cold root.
- Confirm live side log contains the S07 hot budget line.
- Confirm `S07-Jnew/evidence-summary.md` contains only one effective
  `--cache-ram`, value 8.
- Confirm server startup log reports the hot cache limit as 8 MiB.
- Confirm protected-root pressure appears as protected-root decisions,
  protected-root demotions, payload evictions, or demotions before classifying
  the row.

## Handoff

Next owner: Architect.

Review the runner contract change before QA reruns S07. S08 and L01..L03 stay
stopped until Manager accepts the review and authorizes the next focused run.
