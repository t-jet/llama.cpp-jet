# Stage 23 execution plan REWORK corrections

Status: corrected; ready for QA execution-plan re-review
Date: 2026-06-20
Stage: 23 (Full S/L Matrix Execution)
Owner: Developer
Scope: harness and execution-plan correction only. No production C++ code, full
matrix execution, or server live run.

## Source finding

QA review gate 01 returned REWORK with four blocking findings:

- F-23-PLAN-01: live wrapper launches did not pass Stage 17 hook flags.
- F-23-PLAN-02: the required Qwen3.5-4B-MTP fixture was verified but not used.
- F-23-PLAN-03: wrapper row output rooted under `._design_docs/.test_reports`.
- F-23-PLAN-04: per-batch and per-row gates were left to operator memory.

## Corrections

### F-23-PLAN-01

Changed files:

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/lib/Get-Stage17ServerArgs.ps1`
- all 8 stress row scripts
- all 3 longrun row scripts

The wrapper now encodes its reviewed Stage 17 server args and passes them to
each child row via `-Stage17ServerArgsBase64`. Each row decodes that value and
appends the args to the actual `llama-server` argument list. The row dry-run
path prints the same appended args.

The live arg set includes:

- `--cache-mode hybrid`
- `--cache-cold-max-mib 512`
- `--cache-ram 512`
- `--cache-cold-path <path>`
- `--cache-prompt-evidence redacted`
- `--cache-prompt-evidence-dir <path>`

`--cache-ram` is used because that is the supported llama-server flag.

### F-23-PLAN-02

The wrapper now has `-ModelPath`. Stage 23 commands pass:

`D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`

The wrapper passes that path to every child row. If `-ModelPath` is omitted, the
wrapper defaults to the same Qwen3.5 MTP fixture unless
`LLAMA_CACHE_TEST_MODEL` is set.

### F-23-PLAN-03

The wrapper now has `-RunRoot`. Stage 23 commands pass:

`D:\source\llama.cpp-jet\._test_output\stage23-sl-matrix-YYYYMMDD-NN`

The side log and row directories are created below that root. Durable Markdown
reports remain under `._design_docs/.test_reports/`.

### F-23-PLAN-04

The wrapper now waits for child rows and writes these side-log gates:

- `batch_gate`: ports, listeners, free bytes, cold-path item count, run-root
  writable probe.
- `launched`: PID, port, script, cap, model path through wrapper state, and
  Stage 17 flag string.
- `row_gate`: child exit code, recursive evidence file count, required evidence
  file names found under the row output directory, and the output path.

The execution plan now requires `-BatchSize 1` for Stage 23. That is still
within the design rule of at most two concurrent rows and avoids row cleanup
cross-talk from the existing S/L scripts.

## Extra harness fix

`stress_s12_s05_mixed_workload_profiles.ps1` did not accept `-Port`, although
the wrapper passed `-Port` for every row. It now accepts `-Port`, and its three
profile ports derive from that base port. This keeps Stage 23 port-gate
evidence accurate for S05.

## Evidence

Syntax parse:

```powershell
$paths = @(
  '._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1',
  '._design_docs/cache-handling-test-scripts/lib/Get-Stage17ServerArgs.ps1'
) + (Get-ChildItem ._design_docs\cache-handling-test-scripts\stress,
                 ._design_docs\cache-handling-test-scripts\longrun -Filter *.ps1 |
     Select-Object -ExpandProperty FullName)
foreach ($path in $paths) {
  [scriptblock]::Create((Get-Content -Raw -LiteralPath $path)) | Out-Null
}
```

Result: PASS for wrapper, helper, 8 stress scripts, and 3 longrun scripts.

Wrapper dry-run:

```powershell
powershell -NoProfile -Command "& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('S01','S02','S03','S04','S05','S06','S07','S08','L01','L02','L03') `
  -RunRoot 'D:\source\llama.cpp-jet\._test_output\stage23-sl-matrix-dryrun-all' `
  -ModelPath 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
  -CacheColdPath 'D:\tmp\cache-cold-stage23' `
  -CachePromptEvidenceDir 'D:\source\llama.cpp-jet\._test_output\stage23-sl-matrix-dryrun-all\prompt-evidence' `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8800 -BatchSize 1 -DryRun"
```

Result: `DryRun OK; 11 rows; per-row flags present`.

Representative child dry-run:

```powershell
powershell -NoProfile -File ._design_docs\cache-handling-test-scripts\stress\stress_s12_s01_budget_exhaustion.ps1 `
  -BuildDir D:\source\llama.cpp-jet\build-cov `
  -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -OutDir D:\source\llama.cpp-jet\._test_output\stage23-child-dryrun\S01-Jnew `
  -Port 8800 -MtpVariant 1 -JinjaVariant marked `
  -Stage17ServerArgsBase64 <encoded reviewed args> -DurationMin 1 -DryRun
```

Result: PASS. Output included Qwen3.5 model path, `chat_template_new.jinja`,
`--cache-mode hybrid`, `--cache-cold-max-mib 512`, `--cache-ram 512`,
`--cache-cold-path`, `--cache-prompt-evidence redacted`, and
`--cache-prompt-evidence-dir`.

All child row dry-runs:

```powershell
# Same encoded reviewed args, model path, and build path as above.
# Rows: S01 S02 S03 S04 S05 S06 S07 S08 L01 L02 L03.
```

Result: all 11 exited 0.

## Handoff

QA execution remains blocked until QA re-reviews the corrected plan and Manager
accepts the execution plan. After acceptance, run the matrix with the corrected
commands in the Stage 23 implementation entry.

This file uses plain ASCII text and stays under the 300-line durable-doc cap.
