# Stage 23 S07 runner-contract fix review

Verdict: PASS
Date: 2026-06-22
Owner: Architect
Review target: [stage23-remaining-s07-20260622-01-fixes.md](stage23-remaining-s07-20260622-01-fixes.md)

## Scope

Reviewed the S07 runner-contract fix only. I did not run the S07 live row.
QA owns the focused S07 rerun after Manager accepts this review.

Reviewed files:

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-01.md`
- `._design_docs/.test_reports/stage23-remaining-s07-20260622-01-fixes.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`

## Findings

No blocking findings.

The root cause is correctly classified as a runner-contract gap. S07's child
script set local `--cache-ram 8`, then the wrapper appended `--cache-ram 512`
through `Stage17ServerArgsBase64`. The server used the later value, so the
row ran with a 512 MiB hot budget and did not exercise protected-root pressure.
This matches the QA report evidence: protected-root decisions, protected-root
demotions, payload evictions, and payload demotions were all 0.

The fix scope is narrow. `Get-Stage20Flags` now suppresses wrapper
`--cache-ram` for S07 as well as S06. The wrapper passes `-HotBudgetMiB 8` to
S07, and the S07 row script still owns the local `--cache-ram "$HotBudgetMiB"`
flag. No product code, public CLI flag, public metric, test code, or fixture
change is present in the reviewed diff.

S06 behavior is preserved. S06 still suppresses wrapper `--cache-ram 512`,
still receives `-HotBudgetMiB 16`, and still records the pressure-workload
side-log line for the Qwen3-0.6B pressure fixture. The S06 pressure model path
and pressure behavior were not changed by this fix.

Non-pressure rows still receive the wrapper hot budget. S04 dry-run evidence
shows `--cache-ram 512` in the Stage 17 flag string.

S07 still receives required Stage 23 flags: `--cache-mode hybrid`,
`--cache-cold-max-mib 512`, `--n-gpu-layers all`, `--fit off`,
`--cache-cold-path`, `--cache-prompt-evidence redacted`,
`--cache-prompt-evidence-dir`, model path, and row output root.

Side-log evidence is sufficient for QA to accept the dry-run gate and then run
the focused live row. Dry-run records the full wrapper flag string and an S07
hot-budget line:

```text
DryRun S07 hot_budget effective_cache_ram_mib=8 source=S07-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false
```

The live path writes the same S07 hot-budget line before row completion. QA
should still verify the live `evidence-summary.md` and server startup log in
the fresh rerun, because this review did not run the live row.

## Evidence checked

Parser checks passed:

```text
PARSER_OK ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1
PARSER_OK ._design_docs/cache-handling-test-scripts/stress/stress_s12_s07_protected_root_pressure.ps1
PARSER_OK ._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1
```

Scoped whitespace check passed:

```text
git diff --check -- ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1 ._design_docs/cache-handling-phase23-implementation.md ._design_docs/document-index.md ._design_docs/cache-handling-stage-tracker.md
```

Wrapper dry-runs passed without launching a server:

```text
S07: DryRun OK; side log has no wrapper --cache-ram 512 and has effective_cache_ram_mib=8
S06: DryRun OK; side log has no wrapper --cache-ram 512 and has effective_cache_ram_mib=16
S04: DryRun OK; side log has wrapper --cache-ram 512
```

Line and byte checks:

```text
cache-handling-phase23-implementation.md: 295 lines, LF, ASCII, no BOM
document-index.md: 137 lines, LF, ASCII, no BOM
cache-handling-stage-tracker.md: 65 lines, LF, ASCII, no BOM
S07 fixes report: 157 lines, LF, ASCII, no BOM
S07 QA report: 129 lines, LF, ASCII, no BOM
```

Git diff scope checked. Task-local changed files are the wrapper and Stage 23
docs. Existing dirty self-improvement memory files for Developer and QA are
outside this review.

## Handoff

Architect review passes.

Next owner: Manager. Manager may authorize QA to run focused S07 only with
fresh output and cold roots. QA should confirm the live side log contains
`effective_cache_ram_mib=8`, `evidence-summary.md` has only the effective
S07 `--cache-ram 8`, server startup reports an 8 MiB hot limit, and protected
root pressure appears before classifying S07 PASS.

S08 and L01..L03 remain stopped.
