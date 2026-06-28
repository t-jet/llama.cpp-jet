# Stage 29 implementation fix pointer: S29-IMPL-FIX-03

Status: fix complete (Developer fix session, 2026-06-29)
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (fix session in response to Manager authorization S29-IMPL-FIX-03)
Triggering finding: F-29-EXEC-04 (BLOCKING) from QA report -02
Triggering review: Developer test-results review [test-report-20260628-02-stage29-02-developer-review.md](../.test_reports/test-report-20260628-02-stage29-02-developer-review.md)
Prior review: [./part-08-impl-fix-review-20260628.md](./part-08-impl-fix-review-20260628.md) (Architect PASS on S29-IMPL-FIX-01..02)
Branch: work-branch

## Summary

S29-IMPL-FIX-03: ~3-line edit at `compare-legacy-vs-hybrid.ps1` L88
inside `Start-Stage29Server` so the cold-path flags
(`--cache-cold-max-mib`, `--cache-cold-path`) are appended only when
`$Mode -eq 'hybrid'`. Hybrid arms keep both flags. Status DONE.

## Root cause

`Start-Stage29Server` constructed the `llama-server.exe` ArgumentList
with `--cache-cold-max-mib $ColdBudgetMiB` and
`--cache-cold-path $CacheColdPath` unconditionally, regardless of
`$Mode`. The server-side validation in
[../../../tools/server/server-context.cpp:611-625](../../../tools/server/server-context.cpp#L611)
rejects both flags when `--cache-mode legacy` because
`cache_mode_val != CACHE_MODE_HYBRID`:

```text
L611-615: if (cache_cold_max_mib != -1 && cache_mode_val != CACHE_MODE_HYBRID)
              SRV_ERR("...requires --cache-mode hybrid\n"); return false;
L616-621: if (cache_cold_max_mib != 0 && !cache_cold_path.empty()
              && cache_mode_val != CACHE_MODE_HYBRID)
              SRV_ERR("...requires --cache-mode hybrid\n"); return false;
```

The QA report -02 captured the rejection in `server.err.log`:

```text
0.00.264.562 I srv load_model: loading model '...Qwen3.5-4B-Q4_K_M.gguf'
0.00.264.596 E srv load_model:  - cache: --cache-cold-max-mib requires --cache-mode hybrid
0.00.264.599 I srv operator (): operator (): cleaning up before exit...
0.00.265.589 E srv llama_server: exiting due to model loading error
```

The driver error path then surfaced as `BLOCKED-workload-build:
tokenize helper failed /health` at driver L140 (Phase 0.5), which
misclassified all 11 driver-driven rows (CC-01..04, PR-01..03,
AG-01..04) as BLOCKED-driver-cold-mode instead of producing real
per-leg evidence.

The prior S29-IMPL-FIX-02 (see [./part-11-impl-fix-driver-cache-cold-flag-pointer-20260628.md](./part-11-impl-fix-driver-cache-cold-flag-pointer-20260628.md))
fixed the `--cache-cold-dir` to `--cache-cold-path` typo. That fix
made the flag name correct but did not gate the flags on cache mode;
both legs continued to receive cold-path flags regardless of
`--cache-mode`. S29-IMPL-FIX-03 adds the missing mode guard.

## Diff

File: `_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

BEFORE (L86-90, 5 lines):

```text
function Start-Stage29Server {
    param([string]$Mode, [int]$Port)
    $args = @('-m', (Resolve-Stage29Path $ModelPath), '--cache-mode', $Mode, '--port', $Port, '-c', $ContextSize, '--parallel', $Parallel, '--cache-ram', $HotBudgetMiB, '--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-path', $CacheColdPath, '--metrics', '--seed', $Seed)
    return Start-Process -FilePath $LlamaServerPath -ArgumentList $args -PassThru -RedirectStandardOutput "$RunRoot\server.out.log" -RedirectStandardError "$RunRoot\server.err.log"
}
```

AFTER (L86-93, 8 lines):

```text
function Start-Stage29Server {
    param([string]$Mode, [int]$Port)
    $args = @('-m', (Resolve-Stage29Path $ModelPath), '--cache-mode', $Mode, '--port', $Port, '-c', $ContextSize, '--parallel', $Parallel, '--cache-ram', $HotBudgetMiB, '--metrics', '--seed', $Seed)
    if ($Mode -eq 'hybrid') {
        $args += @('--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-path', $CacheColdPath)
    }
    return Start-Process -FilePath $LlamaServerPath -ArgumentList $args -PassThru -RedirectStandardOutput "$RunRoot\server.out.log" -RedirectStandardError "$RunRoot\server.err.log"
}
```

The base `$args` array no longer carries cold-path flags. The
`if ($Mode -eq 'hybrid')` block appends them only for hybrid boots.
Hybrid arms keep both flags (`--cache-cold-max-mib $ColdBudgetMiB`
and `--cache-cold-path $CacheColdPath`) so they still satisfy the
server's third check at server-context.cpp:622-625 (cold writes
enabled in hybrid mode require both flags together).

Net change: 3 added lines (the if-block), 0 removed lines from the
base array beyond moving the cold-path flags into the conditional.

## Self-test

Expected outcome: re-run
`compare-legacy-vs-hybrid.ps1 -DryRun` produces exit 0 with
`Invoke-Preflight` reporting `status: PASS` (assuming CUDA build
root still has `CMakeCache.txt` with `GGML_CUDA:BOOL=ON`, model
fixture is present, and BasePort is free). The preflight does not
boot a server, so the new `if ($Mode -eq 'hybrid')` block is not
exercised by `-DryRun`. Live execution is NOT performed in this fix
session per the Manager brief ("Do NOT execute a full live run").

The PowerShell AST parse of the patched file reports 0 errors,
confirming syntactic correctness. Grep across the driver confirms
that `--cache-cold-max-mib` and `--cache-cold-path` appear ONLY at
L90 (the conditional branch); L23 still carries the
`$CacheColdPath` parameter default (`'D:\tmp\cache-cold-stage29'`),
which is a directory path value and not a CLI flag.

## Verification evidence

- AST parse: `[System.Management.Automation.Language.Parser]::ParseFile`
  on `compare-legacy-vs-hybrid.ps1` returned 0 errors.
- `Select-String` for `cache-cold` (SimpleMatch) in driver:
  - L23: `[string]   $CacheColdPath          = 'D:\tmp\cache-cold-stage29',`
  - L90: `$args += @('--cache-cold-max-mib', $ColdBudgetMiB, '--cache-cold-path', $CacheColdPath)`
  L23 is the param default (a directory path string); L90 is the only
  CLI flag literal pair.
- `Select-String` for `cache-cold` (SimpleMatch) across
  `._design_docs/cache-handling-test-scripts/lib/*.ps1`: 0 matches.
  No lib helper references the cold-path flags.
- Byte-level audit of `compare-legacy-vs-hybrid.ps1`:
  - Length: 14339 bytes
  - LF count: 246 (matches `Get-Content .Count` line count)
  - CR count: 0
  - BOM: none
  - Last byte: 0x0A
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- `git diff --check` on driver: exit 0, no whitespace warnings.
- Driver line count: 246 (under the 300-line cap).
- `git status` on driver: untracked (`??` prefix); production tree
  (`tools/server/`, `tests/`, `common/`, `ggml/`, `gguf-py/`)
  unchanged.

## Constraint compliance

- Production code, test code, runner, design, implementation log
  (entry doc append), and test plan: NOT modified (entry doc gets
  only a brief append per Stage 29 fix-log convention; part-12 is
  the new durable pointer file).
- Stage 25-28 invariants preserved (driver still reads from
  post-Stage-28 closed binary; no source under `tools/server/`,
  `tests/`, `common/`, `ggml/`, or `gguf-py/` is modified).
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Driver stays at 246 lines (cap 300).
- `git diff --check` clean on every file authored or modified.

## Handoff

Next owner: Manager (implementation-fix gate review, iteration 2).
Next gate: implementation-fix gate review, then QA re-execution
of the Stage 29 driver per the existing QA test plan part-33 (the
11 BLOCKED-driver-cold-mode rows in QA report -02 should re-run
and produce real per-leg evidence). After QA re-run PASS: Developer
test-results review. After Developer review PASS: Manager closure
per D-CLOSURE-29-NN.

The two non-blocking environment findings F-29-EXEC-06 (pytest
huggingface-hub version gap) and F-29-EXEC-07 (Release build
without `/Zi` and OpenCppCoverage not installed) are independent
of Stage 29 and remain in their separate Developer handoffs.
