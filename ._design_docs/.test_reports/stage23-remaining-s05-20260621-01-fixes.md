# Stage 23 remaining S05 20260621-01 fixes

Status: ready for Architect review
Date: 2026-06-21
Owner: Developer
Trigger report: [stage23-remaining-s05-20260621-01.md](stage23-remaining-s05-20260621-01.md)
Scope: runner/script contract fix only. No product code, public server metrics,
public CLI flags, tests, fixtures, or model assets changed.

## Root cause

Stage 23 defines S05 as one stress row with a 30 minute row cap. The wrapper
passes `-DurationMin 30` to the S05 script as the row cap.

`stress_s12_s05_mixed_workload_profiles.ps1` treated `DurationMin` as a
per-profile duration. It ran:

- `plain-transformer` for 30 minutes
- `target-plus-draft` for 30 minutes
- `checkpoint-dependent` for 30 minutes

That made one S05 row last about 90 minutes. The parent wrapper timed out and
did not write `row_gate` or `batch_end`, so QA correctly classified the run as
`BLOCKED-runner-contract`.

## Changed files

- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s05_mixed_workload_profiles.ps1`
- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/.test_reports/stage23-remaining-s05-20260621-01-fixes.md`

Pre-existing dirty changes in the wrapper and S05 script were preserved. This
fix only adds the S05 row-cap allocation behavior and dry-run/live allocation
logging.

## Behavior after fix

`DurationMin` is now the whole S05 row cap. The S05 script splits that cap
across the three mixed workload profiles:

- 30 minute row cap = 1800 seconds total
- `plain-transformer` = 600 seconds
- `target-plus-draft` = 600 seconds
- `checkpoint-dependent` = 600 seconds

For row caps that do not divide evenly, the last profile receives the remainder.
Each profile evidence summary records its allocated profile duration.

S05 script dry-run now prints the row cap and per-profile allocation before any
server launch.

Wrapper dry-run and live side log now write:

```text
DryRun S05 profile_allocation rowCapSeconds=1800 allocations=plain-transformer=600,target-plus-draft=600,checkpoint-dependent=600
```

Live wrapper launch writes the same `S05 profile_allocation` line before it
waits for the child row. QA can verify the allocation from wrapper dry-run
before rerunning live S05.

## Evidence

Command:

```powershell
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\stress\stress_s12_s05_mixed_workload_profiles.ps1 -DurationMin 30 -OutDir ._test_output\stage23-s05-contract-fix-dryrun\S05-Jnew -DryRun
```

Result: exit 0. Output:

```text
DRY-RUN: S12-S05 row cap 30 min (1800 sec); profiles=3
DRY-RUN: would run profile plain-transformer for 600 sec
DRY-RUN: would run profile target-plus-draft for 600 sec
DRY-RUN: would run profile checkpoint-dependent for 600 sec
```

Command:

```powershell
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 -RowsToRun S05 -RunRoot ._test_output\stage23-s05-contract-fix-wrapper-dryrun-2 -CacheColdPath D:\tmp\cache-cold-stage23-s05-contract-fix-2 -CachePromptEvidenceDir ._test_output\stage23-s05-contract-fix-wrapper-dryrun-2\prompt-evidence -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

Result: exit 0. Console output:

```text
DryRun OK; 1 rows; per-row flags present
```

Side log:

```text
DryRun S05 profile_allocation rowCapSeconds=1800 allocations=plain-transformer=600,target-plus-draft=600,checkpoint-dependent=600
kickoff-stage20-stress-longrun DryRun end; ok=True
```

Command:

```powershell
$files=@('._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1','._design_docs/cache-handling-test-scripts/stress/stress_s12_s05_mixed_workload_profiles.ps1'); foreach($f in $files){ $tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$tokens, [ref]$errors) > $null; if($errors.Count){ "PARSE FAIL $f"; exit 1 } else { "PARSE OK $f" } }
```

Result: exit 0.

```text
PARSE OK ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1
PARSE OK ._design_docs/cache-handling-test-scripts/stress/stress_s12_s05_mixed_workload_profiles.ps1
```

No full S05 live row was run in this fix loop.

## Retest scope

Architect should review the runner/script contract fix before QA reruns S05.

After Architect PASS, QA should rerun S05 only with the same Stage 23 CUDA
preflight rules, `-RowsToRun S05`, `-BatchSize 1`, and a fresh run root. QA
should verify:

- wrapper dry-run contains the S05 `profile_allocation` line
- live wrapper side log contains the same allocation line
- `row_gate` and `batch_end` are written
- S05 completes inside the Stage 23 30 minute row cap plus normal startup and
  cleanup overhead
- per-profile evidence exists for all three mixed workload profiles

S06..S08 and L01..L03 remain blocked until S05 disposition is accepted.

## Handoff

Next owner: Architect.

Architect review should decide whether this minimal runner/script contract fix
is acceptable for focused S05 rerun. Manager/QA should not open S06 before S05
disposition is recorded.
