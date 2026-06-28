# Stage 29 implementation fix: Driver --cache-cold-path flag typo

Status: fix complete (Developer fix session, 2026-06-28)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (fix session in response to Manager BLOCKING flag-mismatch finding)
Source finding: Manager brief identified a one-character BLOCKING bug at `compare-legacy-vs-hybrid.ps1:88`
Branch: work-branch

## Background

`Start-Stage29Server` in `compare-legacy-vs-hybrid.ps1` constructed the
`llama-server.exe` ArgumentList with the flag `--cache-cold-dir` followed
by `$CacheColdPath`. The actual CLI option registered in
`common/arg.cpp:1366` is `--cache-cold-path`. The driver flag was a
transcription error against the design (which always named the flag
`--cache-cold-path`).

With the typo present, `llama-server.exe` rejects the unknown flag and
exits before the health endpoint binds. Both the legacy leg and the
hybrid leg would have failed Phase 0 / server startup; every QA test row
that depends on either leg was at risk of being misclassified as a
server-startup defect instead of a product defect.

## Scope of change

Single-character edit. One file touched, one line changed.

## Diff

File: `_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

Line 88 BEFORE:

```text
    $args = @('-m', (Resolve-Stage29Path $ModelPath), '--cache-mode', $Mode, '--port', $Port, '-c', $ContextSize, '--parallel', $Parallel, '--cache-ram', $HotBudgetMiB, '--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-dir', $CacheColdPath, '--metrics', '--seed', $Seed)
```

Line 88 AFTER:

```text
    $args = @('-m', (Resolve-Stage29Path $ModelPath), '--cache-mode', $Mode, '--port', $Port, '-c', $ContextSize, '--parallel', $Parallel, '--cache-ram', $HotBudgetMiB, '--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-path', $CacheColdPath, '--metrics', '--seed', $Seed)
```

The only change is `--cache-cold-dir` -> `--cache-cold-path`.

## Root cause

Transcription error. The Stage 29 design always specified
`--cache-cold-path` as the cache-cold directory flag (matching
`common/arg.cpp`). The driver copy-paste introduced `dir` instead of
`path`.

## Self-test

Expected outcome: re-run `compare-legacy-vs-hybrid.ps1 -DryRun`
produces exit 0 and `Invoke-Preflight` reports `status: PASS` (assuming
the CUDA build root still has `CMakeCache.txt` with `GGML_CUDA:BOOL=ON`,
the model fixture is present, and the BasePort is free).

This session does NOT execute the driver; the documented expectation
is sufficient per the Manager brief ("just document the expected
outcome").

## Verification evidence

- `grep_search` for `--cache-cold-dir` under
  `_design_docs/cache-handling-test-scripts/`: 0 matches after the fix
  (1 match before, the patched line itself).
- `grep_search` for `--cache-cold-path` under `common/arg.cpp:1366`:
  confirms the registered CLI flag name.
- `Get-Content` on driver line 88: shows `--cache-cold-path` in the
  ArgumentList.
- Byte-level audit of `compare-legacy-vs-hybrid.ps1`:
  - Length: 14284 bytes
  - LF count: 243 (matches `Get-Content .Count` line count)
  - CR count: 0
  - BOM: none (first 3 bytes 35,114,101 = `#re`)
  - Last 5 bytes: `0x4D 0x61 0x69 0x6E 0x0A` (`Main\n`)
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- `git diff --check -- _design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`:
  exit 0, no whitespace errors.
- Driver line count: 243 (under the 300-line cap).

## Constraint compliance

- Production code, test code, and test plans not modified.
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Driver stays at 243 lines (cap 300).

## Handoff

Next owner: Manager (implementation-fix gate review).
Next gate: implementation-fix gate review, then re-execution of the
Stage 29 driver per the existing QA test plan part-33.
