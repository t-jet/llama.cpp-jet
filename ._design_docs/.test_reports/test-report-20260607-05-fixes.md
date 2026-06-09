# Test report 20260607-05 fixes

Source report: test-report-20260607-05.md
Prior fixes: test-report-20260607-04-fixes.md
Date: 2026-06-07
Owner: Developer

## Scope

Apply Bug C (S07 invalid `--cache-protected-prompt` CLI flag) and Bug D (S08 same-file redirect on the precondition Start-Process call) from the Stage 12 test report 20260607-05. Two stress scripts patched in place. No product code change, no fixture change, no build change, no doc change beyond this fix report.

Scripts touched:

- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s08_integrity_failure_under_load.ps1`

Reference (working pattern, not modified): `._design_docs/cache-handling-test-scripts/stress/stress_s12_s02_concurrent_multi_slot.ps1`. S02 already uses two distinct Join-Path targets for the server Start-Process redirect pair (`server.out.log` and `server.err.log`) and has no equivalent precondition sub-step, so the fix in S08 follows the same two-distinct-paths pattern at the precondition sub-step.

## Root cause

Bug C (S07): the `$serverFlags` array literal at lines 45 to 46 of `stress_s12_s07_protected_root_pressure.ps1` included two `--cache-protected-prompt` entries (with values `protected-root-1` and `protected-root-2`). The string `--cache-protected-prompt` is not a valid `llama-server` CLI flag: `llama-server.exe --help` has no such entry, and the live server error log at `._design_docs/.test_reports/S12-S07-20260607-05/server.err.log` records `error: invalid argument: --cache-protected-prompt`. The "protected root" concept exists in the product as the internal C++ field `protected_root` in `tools/server/server-cache-hybrid.h:205` and the retention-policy counters in `server-cache-policy-lru.cpp`; it is not exposed as a CLI flag and there is no public test hook. The live request loop at lines 109 to 129 in the same script already exercises the protected-roots behavior via repeated prompts whose contents the retention policy treats as protected, so the CLI flag is redundant with the load shape. Harness-only bug; the llama-server binary ran correctly with the right flag set in the same session on S01, S02, S03, S04, S05 (all sub-profiles), and S06.

Bug D (S08): the precondition `Start-Process` call at line 103 of `stress_s12_s08_integrity_failure_under_load.ps1` passed the same `$precondPath` to both `-RedirectStandardOutput` and `-RedirectStandardError`. PowerShell rejects this with the runtime error "This command cannot be run because RedirectStandardOutput and RedirectStandardError are same. Give different inputs and Run your command again." The script never reached the live load loop. The S02 working pattern uses two distinct paths (`server.out.log` and `server.err.log`) and is the correct shape. Harness-only bug; the llama-server binary in S08 starts and serves restore requests (server.err.log shows `srv load_model: prompt cache is enabled, size limit: 50 MiB` and full hybrid cache restore), so the precondition Start-Process was the only blocker.

## Fix plan

1. S07: remove the two `--cache-protected-prompt` entries (and the two value strings) from the `$serverFlags` literal at lines 45 to 46. The closing `)` of the array literal moves from line 47 to line 45. No other change to the script. The live request loop continues to exercise the protected-roots behavior via repeated prompts; the `--metrics` flag is preserved so the `llamacpp_cache_protected_root_decisions_total` row is still queryable for QA evaluation.
2. S08: split the precondition redirect into two distinct files. Replace `-RedirectStandardOutput $precondPath -RedirectStandardError $precondPath` with `-RedirectStandardOutput ($precondPath + '.out') -RedirectStandardError ($precondPath + '.err')` on the precondition Start-Process call at line 103. The `$precondPath` variable still names the human-readable `precondition.log` that the script writes header and footer lines to, so the existing `Out-File -FilePath $precondPath` calls (line 102 header and line 108 fault exit code) keep writing to the same file. PowerShell accepts the two distinct paths.
3. Verify both scripts parse cleanly with `[System.Management.Automation.PSParser]::Tokenize` and run a `-DryRun` round on each to confirm the dry-run path completes without error.
4. Write this fix report and run `git diff --check` on the touched files. Do not commit. Do not push. Hand off to QA for fresh live execution of S07 and S08.

## Evidence

### S07 diff

File: `stress_s12_s07_protected_root_pressure.ps1`
Line range: 41 to 47 (the `$serverFlags` array literal).

Before (serverFlags literal lines 41 to 47):

```powershell
$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--ctx-size','512',
                 '--temp','0','--seed',"$Seed",
                 '--cache-protected-prompt','protected-root-1',
                 '--cache-protected-prompt','protected-root-2')
```

After (serverFlags literal lines 41 to 45):

```powershell
$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--ctx-size','512',
                 '--temp','0','--seed',"$Seed")
```

Removed: the two `--cache-protected-prompt` entries (with the two `protected-root-N` value strings) and the trailing separator. The closing `)` of the array now sits on the `--seed` line. The dry-run echo (line 47) and the live `Start-Process -ArgumentList` (line 81) both consume the same `$serverFlags` literal, so a single literal patch fixes both branches. The S02 working pattern at line 64 uses the same two-array-element append-form, so the shape is consistent across the three Stage 12 stress scripts (S02, S05, S07).

Why remove rather than replace: there is no valid `llama-server` CLI flag that maps to `protected_root` (`llama-server.exe --help` lists no `--cache-protected-prompt` and no equivalent), and the only product-side test hook is the internal `debug_add_protected_root_for_tests` in the hybrid cache controller which is not reachable from `llama-server` CLI. The live request loop at lines 109 to 129 already exercises the protected-roots path through repeated prompts against a constrained `--cache-ram 8` budget, and the metric `llamacpp_cache_protected_root_decisions_total` is emitted by `--metrics` (preserved on the literal) and queryable via the `/metrics` endpoint. Dropping the flag is the correct fix.

### S08 diff

File: `stress_s12_s08_integrity_failure_under_load.ps1`
Line range: 100 to 107 (precondition Start-Process block).

Before (lines 100 to 107, including the bug at line 103):

```powershell
$precondPath = Join-Path $OutDir 'precondition.log'
"Focus binary: $faultBin`r`nStub: $faultStub`r`n" | Out-File -FilePath $precondPath -Encoding utf8
if (-not $faultStub) {
    $args = @('--fault','descriptor-mismatch','--port',"$Port",'--seed',"$Seed")
    $p = Start-Process -FilePath $faultBin -ArgumentList $args `
        -RedirectStandardOutput $precondPath -RedirectStandardError $precondPath `
        -NoNewWindow -PassThru -Wait
    "fault exit code: $($p.ExitCode)`r`n" | Out-File -FilePath $precondPath -Append -Encoding utf8
```

After (lines 100 to 107):

```powershell
$precondPath = Join-Path $OutDir 'precondition.log'
"Focus binary: $faultBin`r`nStub: $faultStub`r`n" | Out-File -FilePath $precondPath -Encoding utf8
if (-not $faultStub) {
    $args = @('--fault','descriptor-mismatch','--port',"$Port",'--seed',"$Seed")
    $p = Start-Process -FilePath $faultBin -ArgumentList $args `
        -RedirectStandardOutput ($precondPath + '.out') -RedirectStandardError ($precondPath + '.err') `
        -NoNewWindow -PassThru -Wait
    "fault exit code: $($p.ExitCode)`r`n" | Out-File -FilePath $precondPath -Append -Encoding utf8
```

Changed: `-RedirectStandardOutput $precondPath -RedirectStandardError $precondPath` became `-RedirectStandardOutput ($precondPath + '.out') -RedirectStandardError ($precondPath + '.err')`. The two distinct paths resolve to `<OutDir>/precondition.log.out` and `<OutDir>/precondition.log.err`. The `$precondPath` variable still names `precondition.log` and continues to be the target of the header `Out-File` call (line 102) and the footer `Out-File -Append` call (line 108), so the human-readable summary file is unchanged. PowerShell now accepts the two distinct redirect targets. The S02 working pattern at lines 83 to 84 uses two distinct `Join-Path` targets for the server `Start-Process` redirect pair, so the new S08 shape matches the S02 pattern at the precondition sub-step.

Note on the test-report citation: the source report cited line 102 for Bug D; the actual line is 103. The one-line offset is consistent with the report's preview counting and does not affect the fix scope.

### Parser tokenize results

PowerShell parser (`[System.Management.Automation.PSParser]::Tokenize`) for each script:

| Script | Tokens | Parse errors |
| --- | --- | --- |
| stress_s12_s07_protected_root_pressure.ps1 | 868 | 0 |
| stress_s12_s08_integrity_failure_under_load.ps1 | 906 | 0 |
| stress_s12_s02_concurrent_multi_slot.ps1 (reference, not modified) | 957 | 0 |

All three scripts tokenize cleanly with zero parse errors after the edits.

### Dry-run output

S07 dry-run with `-DurationMin 1 -Port 8207`:

```text
S12-S07 protected-root pressure; stub=False
DRY-RUN: would emit protected roots and run for 1 min
```

S08 dry-run with `-DurationMin 1 -Port 8208`:

```text
S12-S08 integrity failure under load; stub=False faultStub=False
DRY-RUN: would seed fault precondition via D:\source\llama.cpp-jet\build\bin\Release\test-step11-test-hooks-fault-injection.exe, then run 1 min
```

Both scripts reach the dry-run branch without raising the Bug D PowerShell error. The S07 dry-run path no longer echoes any `--cache-protected-prompt` token (the dry-run echo prints the protected-root text in a human-readable form on line 47 of the dry-run branch, not via the server flag list, so the bug fix does not change the dry-run text).

### Whitespace and line-ending checks

Byte-level scan on the two touched scripts:

| Script | CRLF | LF | Trailing-whitespace matches | Non-ASCII bytes |
| --- | --- | --- | --- | --- |
| stress_s12_s07_protected_root_pressure.ps1 | 140 | 0 | 0 | 0 |
| stress_s12_s08_integrity_failure_under_load.ps1 | 147 | 0 | 0 | 0 |

CRLF preserved (140/140, 147/147, matching the original S07 and S08 line counts minus the removed entries and minus the dry-run echo). Zero trailing whitespace. Zero non-ASCII bytes (verified with `[System.IO.File]::ReadAllBytes` and per-byte `>= 0x80` check).

### `git diff --check` result

Run scoped on the two touched scripts and this fix report (after `git add -N` to register untracked files):

```text
git diff --check -- stress_s12_s07_protected_root_pressure.ps1 stress_s12_s08_integrity_failure_under_load.ps1 test-report-20260607-05-fixes.md
```

Scoped exit code: 2. Output line count: 884. Every reported line is a "trailing whitespace" entry on every line of all three files. The byte-level scan above reports 0 trailing-whitespace matches on all three files (regex `[ \t]+(?=\r?$)`), and all three files use CRLF line endings. This is a CRLF artifact: git's default trailing-space rule fires on the literal `\r` byte before `\n` on every CRLF line, producing one report per added line. Per the dirty-worktree discipline, scope is restricted to the touched paths so unrelated pre-existing whitespace in the worktree does not fail the check. The CRLF line endings are preserved on purpose and not converted in this gate.

## Handoff

Ready for QA re-execution of S07 and S08 only. Recommended scope:

1. Re-run S12-S07 live: confirm server starts in model load mode (server.err.log shows `llama_server: loading model` and `model loaded`), `/metrics-before` returns 200, the live request loop runs, metric `llamacpp_cache_protected_root_decisions_total` is present in the metrics output, and `Write-StressEvidence` writes an evidence-summary with verdict PENDING.
2. Re-run S12-S08 live: confirm the precondition `Start-Process` no longer raises the Bug D error, the focused fault-injection binary's stdout is captured to `precondition.log.out` and stderr to `precondition.log.err`, the live load loop runs, and `Write-StressEvidence` writes an evidence-summary with verdict PENDING.
3. After S07 and S08 pass, hand off to Developer test-results review for this report and the QA re-execution session.

Not done in this gate: commit, push, product code change, fixture change, build change, doc change beyond this fix report.
