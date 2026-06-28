# Stage 29 implementation fix pointer: S29-IMPL-FIX-04

Status: fix complete (Developer fix session, 2026-06-29)
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (fix session in response to Manager authorization S29-IMPL-FIX-04)
Triggering finding: F-29-EXEC-08 (NEW BLOCKING) from QA report -03
Triggering handoff: QA execution handoff [part-13](./part-13-qa-execution-handoff-20260629.md)
Prior fix pointer: [./part-12-impl-fix-driver-cold-mode-flag-coupling-20260628.md](./part-12-impl-fix-driver-cold-mode-flag-coupling-20260628.md) (S29-IMPL-FIX-03)
Branch: work-branch

## Summary

S29-IMPL-FIX-04: one-line driver fix at L40-44 (insert `. (Join-Path $libDir 'agentic-prompt-generator.ps1')` before the wrapper dot-source at L44) so the Stage 20 lib that defines `New-AgenticChatPrompt` is in scope when the driver calls `New-ComparisonWorkload`. Status DONE.

## Root cause

The wrapper `lib/compare-legacy-vs-hybrid-workload.ps1` (design-correct, 200 lines, unchanged) calls `New-AgenticChatPrompt` at L106 and L142. `New-AgenticChatPrompt` is defined only in the Stage 20 lib `lib/agentic-prompt-generator.ps1` at L82. The wrapper's own header at L18-19 documents the expected dot-source order (`agentic-prompt-generator.ps1` first, then the wrapper), but the driver did not honour it.

When the driver reached Phase 0.5 workload build at L146, `New-ComparisonWorkload` (defined in the wrapper) tried to call `New-AgenticChatPrompt`, PowerShell could not resolve the function name, the inner try-block failed, the server was correctly stopped in the finally block (port 8900 free after the run), and the exception propagated with `The term 'New-AgenticChatPrompt' is not recognized as a name of a cmdlet, function, script file, or executable program`. Full exception trace at [main.err.log](../../_test_output/stage29-cache-modes-20260629-01/main.err.log). Driver exit code: 1.

This defect was latent since the wrapper was authored (per the wrapper header at L18-19) but hidden behind the prior F-29-EXEC-04 BLOCKING failure from QA report -02. The cold-mode flag coupling bug short-circuited the run at server boot before Phase 0.5 ever started, so the missing Stage 20 lib dot-source was never exercised. Once F-29-EXEC-04 was fixed by S29-IMPL-FIX-03, Phase 0.5 started running and immediately hit F-29-EXEC-08.

## Diff

File: `_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

BEFORE (L40-43, 4 lines):

```text
$scriptDir = $PSScriptRoot
$repoRoot  = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$libDir    = Join-Path $scriptDir 'lib'
. (Join-Path $libDir 'compare-legacy-vs-hybrid-workload.ps1')
```

AFTER (L40-44, 5 lines):

```text
$scriptDir = $PSScriptRoot
$repoRoot  = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$libDir    = Join-Path $scriptDir 'lib'
. (Join-Path $libDir 'agentic-prompt-generator.ps1')
. (Join-Path $libDir 'compare-legacy-vs-hybrid-workload.ps1')
```

The Stage 20 lib is dot-sourced FIRST (per wrapper header documented order at L18-19), then the wrapper, then the four helper libs (Read-Stage29MetricSnapshot, Write-Stage29EvidenceRow, Test-Stage29OutputEquivalence, Wait-Stage29VramBaseline). Net change: 1 added line, 0 lines removed.

## Self-test

`compare-legacy-vs-hybrid.ps1 -DryRun` returns exit 0 with preflight reporting `status: PASS`. Captured at session end (2026-06-29):

```text
DryRun preflight: {"ps_version_ok":true,"binary_exists":true,"fixture_exists":true,"port_free":true,"cuda_proof":"PASS","git_head":"97e9c77c9004c4a4fa8d9ef4bc27c5372b6af395","git_dirty":24,"status":"PASS"}
EXIT: 0
```

All five gating sub-checks pass: `ps_version_ok`, `binary_exists`, `fixture_exists`, `port_free`, `cuda_proof`. The preflight does not boot a server, so the new dot-source is not exercised by `-DryRun`. Live execution is NOT performed in this fix session per the Manager brief.

## Verification evidence

- AST parse: `[System.Management.Automation.Language.Parser]::ParseFile` on
  `compare-legacy-vs-hybrid.ps1` returned 0 errors.
- Grep for `New-AgenticChatPrompt` across
  `._design_docs/cache-handling-test-scripts/**/*.ps1` returns 9 matches
  total:
  - 6 matches in `lib/agentic-prompt-generator.ps1` (L4 header, L19 usage
    example, L82 function definition, L100 throw, L103 throw, L141 throw).
  - 3 matches in `lib/compare-legacy-vs-hybrid-workload.ps1` (L46 header
    reference, L106 call site, L142 call site).
  - 0 matches in the driver `compare-legacy-vs-hybrid.ps1` (the driver does
    not use the function directly; it loads the lib via dot-source, and
    the wrapper uses it).
- Byte-level audit of `compare-legacy-vs-hybrid.ps1` after fix:
  - Length: 14392 bytes
  - LF count: 247 (matches `Get-Content .Count`, +1 from pre-fix 246)
  - CR count: 0
  - BOM: none
  - Last byte: 0x0A
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- `git diff --check` on driver: exit 0, no whitespace warnings.
- Driver line count: 247 (under the 300-line cap, +1 from pre-fix 246).
- Driver is untracked (`??` prefix) per status quo; production tree
  (`tools/server/`, `tests/`, `common/`, `ggml/`, `gguf-py/`) unchanged.
- Pointer part file (this file): 112 LF (under 300-line cap).

## Constraint compliance

- Production code, test code, runner, design, implementation (other than
  the appended log section and this pointer part), and test plan:
  NOT modified.
- Stage 25-28 invariants preserved (driver still reads from
  post-Stage-28 closed binary; no source under `tools/server/`,
  `tests/`, `common/`, `ggml/`, or `gguf-py/` is modified).
- ASCII only, LF line endings, no BOM, no trailing whitespace, no
  non-ASCII characters in all files authored or modified.
- Driver stays at 247 lines (cap 300, +1 from pre-fix 246).
- This pointer part stays at 112 lines (cap 300).
- `git diff --check` clean on the driver (scoped diff).
- Pointer part byte-level verified (LF-only, no BOM, no trailing
  whitespace, no non-ASCII).

## Handoff

Next owner: Manager (implementation-fix gate review, iteration 3).
Next gate: Manager implementation-fix gate #3 review, then QA
re-execution of the Stage 29 driver per the existing QA test plan
part-33 (the 11 BLOCKED-driver-dot-source rows in QA report -03
should re-run and produce real per-leg evidence). After QA re-run
PASS: Developer test-results review. After Developer review PASS:
Manager closure per D-CLOSURE-29-NN.
