# Stage 23 longrun before-metrics correction

Status: corrected; ready for QA re-review
Date: 2026-06-20
Stage: 23 (Full S/L Matrix Execution)
Owner: Developer
Scope: F-23-REREVIEW-01 harness correction only. No production C++ edits, full
matrix execution, or live server run.

## Source finding

QA re-review gate 01 returned REWORK for F-23-REREVIEW-01: L01..L03 did not
create `metrics-before.txt`, while the Stage 23 evidence contract and wrapper
`row_gate` require it for every row.

## Correction

Changed files:

- `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l01_6h_hybrid_stability.ps1`
- `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l02_30m_legacy_comparison.ps1`
- `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l03_2h_mixed_workload.ps1`

Each longrun script now captures:

`http://127.0.0.1:<port>/metrics -> metrics-before.txt`

The capture runs after the server health probe succeeds and before
`resource-samples.csv` is initialized or any workload request is sent. The
existing `metrics-after.txt` capture remains at row shutdown.

This matches the Stage 23 per-row evidence contract and the wrapper
`row_gate` required file list:

- `server.out.log`
- `server.err.log`
- `metrics-before.txt`
- `metrics-after.txt`

## Evidence

Syntax parse:

```powershell
$paths = @(
  '._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1'
) + (Get-ChildItem ._design_docs\cache-handling-test-scripts\longrun -Filter *.ps1 |
     Select-Object -ExpandProperty FullName)
foreach ($path in $paths) {
  [scriptblock]::Create((Get-Content -Raw -LiteralPath $path)) | Out-Null
}
```

Result: PASS for wrapper and L01..L03.

Focused static check:

```powershell
Select-String ._design_docs\cache-handling-test-scripts\longrun\*.ps1 `
  -Pattern 'metrics-before.txt','metrics-after.txt'
```

Result: L01, L02, and L03 each contain both required metric file names.

Dry-run checks:

```powershell
powershell -NoProfile -Command "& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('L01','L02','L03') `
  -RunRoot 'D:\source\llama.cpp-jet\._test_output\stage23-longrun-metrics-dryrun' `
  -ModelPath 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
  -CacheColdPath 'D:\tmp\cache-cold-stage23' `
  -CachePromptEvidenceDir 'D:\source\llama.cpp-jet\._test_output\stage23-longrun-metrics-dryrun\prompt-evidence' `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8808 -BatchSize 1 -DryRun"
```

Result: PASS, `DryRun OK; 3 rows; per-row flags present`.

Child dry-runs:

```powershell
# L01, L02, and L03 called directly with Stage17ServerArgsBase64,
# Qwen3.5 model path, output roots under ._test_output, and -DryRun.
```

Result: PASS, all three exited 0.

## Handoff

F-23-REREVIEW-01 is corrected in harness scope. QA should re-review this
correction and Manager must accept the Stage 23 execution plan before any
multi-hour matrix execution starts.

This file uses plain ASCII text and stays under the 300-line durable-doc cap.
