# Test report 20260607-04 fixes

Source report: test-report-20260607-04.md
Source developer review: test-report-20260607-04-developer-review.md
Date: 2026-06-07
Owner: Developer

## Scope

Apply Bug A (S01 serverFlags missing --model) and Bug B (S05 serverFlags missing --model in at least one profile sub-run) from the Developer test-results review. Two stress scripts patched in place. No product code change, no fixture change, no build change, no doc change beyond this fix report and the implementation log update.

Scripts touched:

- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s01_budget_exhaustion.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s05_mixed_workload_profiles.ps1`

Reference (working pattern, not modified): `._design_docs/cache-handling-test-scripts/stress/stress_s12_s02_concurrent_multi_slot.ps1`.

## Root cause

Both scripts built the server-flag array as a literal that did not include `--model`. llama-server then entered router mode ("starting router server, no model will be loaded in this process"), and `/metrics` returned `400 model name missing`. Root cause is harness-only; the same llama-server binary served S02 successfully in the same session with the right flags.

S01 had one shared `$serverFlags` literal that fed both the dry-run echo (line 50) and the live `Start-Process -ArgumentList` (line 89), so a single literal patch fixes both paths.

S05 has a `$profiles` array of three hashtables. Each hashtable carries its own `args` array. The three sub-runs (plain-transformer, target-plus-draft, checkpoint-dependent) all lacked `--model` in their per-profile `args`. The live-run path later appended `@('--model', $p.model)` to `startArgs` per profile, so the live run technically already had a model; the fix keeps that and additionally exposes `--model` in the per-profile `args` for evidence consistency and dry-run/harness parity with S01.

## Fix plan

1. S01: append `'--model', $ModelPath` to the `$serverFlags` literal at lines 44 to 47 in the S02 append-form (separate array elements, not interpolation). Single literal covers both the dry-run echo and the live `Start-Process` call.
2. S05: append `'--model', $ModelPath` to the per-profile `args` array of all three profile hashtables in the `$profiles` definition at lines 45 to 48. Append-form, not interpolation.
3. Verify both scripts parse cleanly with `[System.Management.Automation.PSParser]::Tokenize` and run a `-DryRun` round on S01 to confirm the command-line echo now contains `--model`.
4. Write this fix report and run `git diff --check` on the touched files. Do not commit. Do not push. Hand off to QA for fresh live execution.

## Evidence

### S01 diff

File: `stress_s12_s01_budget_exhaustion.ps1`
Line range: 44 to 47 (serverFlags literal).

Before:

```powershell
$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--ctx-size','512',
                 '--temp','0','--seed',"$Seed")
```

After:

```powershell
$serverFlags = @('--cache-mode','hybrid','--cache-ram',"$HotBudgetMiB",
                 '--parallel',"$ParallelSlots",'--metrics','--ctx-size','512',
                 '--temp','0','--seed',"$Seed",'--model',$ModelPath)
```

Append-form, matches S02 line ~95 working pattern. `--model $ModelPath` resolves to the same path the S02 live run used (`Qwen3-0.6B-Q8_0.gguf` default or `LLAMA_CACHE_TEST_MODEL` override).

Dry-run path (line 50) and live-start path (line 89) both consume the same `$serverFlags`, so the single literal patch fixes both branches. No separate dry-run-only edit was needed.

### S05 diff

File: `stress_s12_s05_mixed_workload_profiles.ps1`
Line range: 45 to 48 (`$profiles` array).

Before:

```powershell
$profiles = @(
    @{ name = 'plain-transformer'; model = $ModelPath;      draft = $null;     args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','50') }
    @{ name = 'target-plus-draft'; model = $largerModel;    draft = $DraftModelPath; args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','200','--model-draft',$DraftModelPath) }
    @{ name = 'checkpoint-dependent'; model = $largerModel; draft = $null;     args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','200') }
)
```

After:

```powershell
$profiles = @(
    @{ name = 'plain-transformer'; model = $ModelPath;      draft = $null;     args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','50','--model',$ModelPath) }
    @{ name = 'target-plus-draft'; model = $largerModel;    draft = $DraftModelPath; args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','200','--model-draft',$DraftModelPath,'--model',$ModelPath) }
    @{ name = 'checkpoint-dependent'; model = $largerModel; draft = $null;     args = @('--cache-mode','hybrid','--parallel','1','--metrics','--cache-ram','200','--model',$ModelPath) }
)
```

Append-form, not interpolation. Per-profile audit:

- plain-transformer (line 45): `--model $ModelPath` appended after `--cache-ram 50`.
- target-plus-draft (line 46): `--model $ModelPath` appended after `--model-draft $DraftModelPath`; the existing live-path append `@('--model',$p.model)` remains.
- checkpoint-dependent (line 47): `--model $ModelPath` appended after `--cache-ram 200`; the existing live-path append `@('--model',$p.model)` remains.

### Parser tokenize results

PowerShell parser (`[System.Management.Automation.PSParser]::Tokenize`) for each script:

| Script | Tokens | Parse errors |
| --- | --- | --- |
| stress_s12_s01_budget_exhaustion.ps1 | 882 | 0 |
| stress_s12_s05_mixed_workload_profiles.ps1 | 1104 | 0 |
| stress_s12_s02_concurrent_multi_slot.ps1 (reference) | 957 | 0 |

All three scripts tokenize cleanly with zero parse errors after the edits.

### Dry-run output verifying --model is now in command line

S01 dry-run with `LLAMA_CACHE_TEST_MODEL` set to a stub path (`D:\fake\Qwen3-0.6B-Q8_0.gguf`) and `-DurationMin 1 -Port 8201`:

```text
S12-S01 budget exhaustion; variant=cold-off; stub=True
DRY-RUN: would start server with: D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe --cache-mode hybrid --cache-ram 2 --parallel 2 --metrics --ctx-size 512 --temp 0 --seed 42 --model D:\fake\Qwen3-0.6B-Q8_0.gguf
DRY-RUN: would run for 1 min and write evidence to D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-s01-20260607-185743\cold-off
```

`--model D:\fake\Qwen3-0.6B-Q8_0.gguf` is now present at the tail of the command line. Confirms the dry-run echo path picked up the patched `$serverFlags` literal.

S05 dry-run with `-DurationMin 1`:

```text
DRY-RUN: would run profile plain-transformer for 1 min
DRY-RUN: would run profile target-plus-draft for 1 min
DRY-RUN: would run profile checkpoint-dependent for 1 min
```

S05 dry-run exits before any per-profile `args` is echoed, so the dry-run path does not print server flags. The fix is verifiable at parse time and via static read of the patched `$profiles` array (lines 45 to 47 above). Live-run path uses `$startArgs = $serverFlags + $modelArg + ...` where `$serverFlags = $p.args`; both branches contribute `--model` in append-form.

### Whitespace and line-ending checks

Per-file scan of byte content for the three stress scripts:

| Script | Lines | CRLF | LF | Trailing whitespace matches | Non-ASCII matches |
| --- | --- | --- | --- | --- | --- |
| stress_s12_s01_budget_exhaustion.ps1 | 150 | 149 | 149 | 0 | 0 |
| stress_s12_s05_mixed_workload_profiles.ps1 | 164 | 163 | 163 | 0 | 0 |
| stress_s12_s02_concurrent_multi_slot.ps1 | 158 | 157 | 157 | 0 | 0 |

CRLF preserved (149/149, 163/163, 157/157). Zero trailing whitespace. Zero non-ASCII characters.

### `git diff --check` result

Run scoped on the two touched scripts and this fix report (after `git add -N` to register untracked files):

```text
git diff --check -- stress_s12_s01_budget_exhaustion.ps1 stress_s12_s05_mixed_workload_profiles.ps1 test-report-20260607-04-fixes.md
```

Scoped exit code: 2. Output line count: 940, with every line of the three files reported as "trailing whitespace". The byte-level scan above reports 0 trailing-whitespace matches (`[ \t]+(?=\r?$)`) on all three files, and all three files use CRLF line endings. This is a CRLF artifact: git's default trailing-space rule fires on the literal `\r` before `\n` on every CRLF line, producing one report per added line. Scoped to the touched paths only, per dirty-worktree discipline. The CRLF line endings are preserved on purpose and not converted in this gate.

## Handoff

Ready for QA re-execution. Recommended scope:

1. Re-run S12-S01 live: confirm server enters model load mode, `/metrics-before` returns 200, prompt loop runs, metrics snapshots and `resource-samples.csv` written, evidence-summary verdict PASS.
2. Re-run S12-S05 live (or static audit plus a smoke run) and confirm all three profile sub-runs include `--model` in their per-profile `args` and in `startArgs`.
3. Re-run S12-S02 parallel8 alone with at least 90 s outer session timeout (per part-20 sec 9 known issue) to allow 60 s plus 60 s sub-runs.
4. Re-run the 17 BLOCKED live rows (S03..S08, B01..B08, L01..L03) one scenario at a time with adequate outer timeout.
5. B05-NL and B08-NL are subsumed under B05 and B08 per part-18a sec 13; re-run only if B05 and B08 finish without BLOCKED.

Not done in this gate: commit, push, product code change, fixture change, build change, doc change beyond this fix report and the implementation log update.
