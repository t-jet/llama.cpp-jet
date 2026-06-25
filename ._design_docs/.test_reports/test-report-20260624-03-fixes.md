# Stage 24 report 03 runner-contract fix

Status: ready for Architect review
Date: 2026-06-24
Owner: Developer
Scope: runner-only fix for `test-report-20260624-03.md`.

## Trigger

QA report `test-report-20260624-03.md` blocked during live S02 native startup.
The server startup log already contained CUDA/NVIDIA proof, but the runner
crashed before requests, metrics, summaries, or comparison artifacts were
written.

Failure:

```text
Cannot find an overload for "Add" and the argument count: "1".
stage24-chat-s02-s03-comparison.ps1:214
```

## Root cause

`Get-CudaRuntimeProof` used `$matches` as a local `List[object]`. PowerShell
variable names are case-insensitive, so `$matches` conflicts with the automatic
`$Matches` variable populated by `-match`. After a CUDA proof line matched, the
automatic variable replaced the list with a hashtable. The next call tried to
invoke hashtable `Add(key, value)` with one ordered-dictionary argument, causing
the overload error.

## Fix scope

Changed file:

```text
._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1
```

The fix renames the CUDA proof collection from `$matches` to `$proofMatches`
inside `Get-CudaRuntimeProof`. No product code, public API, metrics, fixtures,
request generation, row classification, or Stage 23 artifact changed.

## Evidence

Parser/static checks:

```text
[System.Management.Automation.Language.Parser]::ParseFile(...)
Result: parser=PASS

Route scan:
routeAssignments=1
legacyCompletionLiterals=0

Helper scan:
no remaining `$matches` reference in Get-CudaRuntimeProof
```

Direct CUDA proof check against QA captured startup log:

```text
Input:
._test_output/stage24-chat-s02-s03-20260624-03/S02-chat/native-legacy/server.err.log

Result:
captured_log=PASS matches=3 first_line=3
```

Isolated no-server Add regression check:

```text
Input log:
._test_output/stage24-fixverify-03-cuda-proof.log

Result:
isolated_add=PASS matches=2
```

CUDA build-path proof:

```text
build-cuda/CMakeCache.txt: GGML_CUDA:BOOL=ON
Result: cuda_cache=PASS
```

Dry-run with active `build-cuda` path:

```text
RunId: stage24-fixverify-03
RunRoot: ._test_output/stage24-fixverify-03
ReportPath: ._design_docs/.test_reports/test-report-20260624-99.md
Command: stage24 runner with -RowsToRun S02-chat,S03-chat -LlamaServerPath build-cuda/bin/Release/llama-server.exe -DryRun

Result:
dryrun=PASS rows=2 variants=4 cuda=PASS badRoute=0 badFlags=0 llamaServerProcesses=0
scratch_report_created=NO
```

Document hygiene:

```text
test-report-20260624-03-fixes.md: lines=84, ASCII=True, trailing=0
cache-handling-phase24-implementation.md: lines=251, ASCII=True, trailing=0
git diff --check scoped to tracked touched paths: PASS
```

## Residual risk

This fix only addresses CUDA runtime proof collection. QA still must rerun the
Stage 24 CUDA execution from a fresh suffix to classify S02/S03 behavior.

## Handoff

Verdict: ready for Architect review.

QA should rerun Stage 24 from a fresh suffix after review acceptance. The
blocked `test-report-20260624-03.md` remains setup evidence only and is not
S02/S03 closure evidence.
