# Part 12: dry-run hang fix 2026-06-24

Status: ready for Architect bug-fix review
Date: 2026-06-24
Owner: Developer
Scope: Stage 24 runner-contract fix after `test-report-20260624-01.md`.

## Trigger

The fresh CUDA execution attempt for `stage24-chat-s02-s03-20260624-01` was
blocked before live execution. Clean CUDA configure and `llama-server` build
passed, and `build-cov/CMakeCache.txt` contained `GGML_CUDA:BOOL=ON`, but the
required Stage 24 dry-run hung before `dry-run-plan.json` was available. The
S02-only diagnostic dry-run hung the same way. No `llama-server` live leg
started.

## Root cause

The hang was in the runner dry-run serializer on Windows PowerShell 5. Debug
trace stopped inside `Write-JsonFile` while `ConvertTo-Json -Depth 12` was
serializing the dry-run plan:

```text
Write-JsonFile -Path $dryRunPlanPath -Value $plan
[System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth $Depth), $Utf8NoBom)
```

PowerShell 7 did not reproduce the stall, which is why direct `pwsh -File`
diagnostics completed. The closure runner must work with the Windows
PowerShell command path used by QA, so the serializer cannot depend on PS7-only
behavior.

The investigation also found a second runner-contract gap. Child process
invocation can pass `-RowsToRun S02-chat,S03-chat` as one scalar argument.
Before this fix, that shape was treated as an unsupported row instead of the
two intended rows.

## Changes made

Changed file:

```text
._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1
```

Runner changes:

- Added `ConvertTo-JsonSafeValue`, a bounded plain-object conversion used by
  `Write-JsonFile` before `ConvertTo-Json`. This prevents Windows PowerShell
  from walking problematic wrapper objects while preserving the existing JSON
  shape.
- Added `Normalize-RowsToRun` so comma-delimited row strings and normal
  string-array row input both become explicit row IDs before planning.
- Changed `-DryRun` output to create `RunRoot`, write `dry-run-plan.json`, and
  print one short status line instead of dumping the whole plan JSON to stdout.
  The machine-checkable contract remains the plan file.

No product code, public API, public metrics, fixtures, Stage 23 artifacts, or
live comparison behavior changed.

## Verification evidence

Parser/static check:

```text
[System.Management.Automation.Language.Parser]::ParseFile(...)
Result: parser=PASS
```

S02-only dry-run:

```text
RunId: stage24-fixverify-s02
Command: runner -RowsToRun S02-chat -DryRun
Result: exit 0, elapsed_ms=259, dry-run-plan.json present
```

Full S02/S03 dry-run:

```text
RunId: stage24-fixverify-full
Command: runner -RowsToRun S02-chat,S03-chat -DryRun
Result: exit 0, elapsed_ms=345, dry-run-plan.json present
```

Windows PowerShell child-process dry-run:

```text
RunId: stage24-fixverify-file
Command: powershell -NoProfile -ExecutionPolicy Bypass -File runner -RowsToRun S02-chat,S03-chat -DryRun
Result: exit 0, dry-run-plan.json present, stderr length 0
```

Route and CUDA flag assertions across S02-only, full direct, and child-process
plans:

```text
Rows: 1 / 2 / 2
Variants: 2 / 4 / 4
CUDA build proof: PASS / PASS / PASS
bad_route: 0
bad_gpu_flags: 0
```

Static route check:

```text
route_v1_count: 1
legacy_route_assignment: False
dryrun_branch: True
dryrun_before_live: True
```

CUDA configure proof:

```text
build-cov/CMakeCache.txt: GGML_CUDA:BOOL=ON
```

Live-process check after dry-runs:

```text
llama-server-processes=0
```

## Residual risk

This fix only proves the preflight dry-run contract. It did not run live S02 or
S03 legs, did not start `llama-server`, and did not validate runtime CUDA/NVIDIA
startup proof. The next QA execution still must preserve the existing S02
request-error policy and S03 hybrid near-prefix unsafe-restore policy from
Parts 10 and 11.

## Handoff

Verdict: ready for Architect bug-fix review.

After review acceptance, Manager can send QA back to the fresh CUDA execution
gate. QA should use a new run root and report suffix; `test-report-20260624-01`
remains a blocked setup record.
