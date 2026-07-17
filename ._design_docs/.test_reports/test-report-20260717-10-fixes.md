# D39-QA-10 fixes

Date: 2026-07-17
Status: FIX REVIEW PASS
Input report: `test-report-20260717-10.md`
Developer review: `test-report-20260717-10-developer-review.md`
Implementation part: `../cache-handling-phase39-implementation/part-189-d39-qa10-paired-decision-driver-fix-20260717.md`

## Scope

This fix addresses F39-QA10-01 only.

Changed:

- `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`

Not changed:

- product cache code;
- model fixture or live workload;
- budgets, thresholds, route behavior, seam behavior, or coverage policy;
- TP-39-02 and TP-39-04 one-decision assertions.

## Root cause

`Assert-Tp3903` used `Assert-ExactOutcomeS39`, which requires the whole
`llamacpp:cache_two_layer_decisions_total` family delta to be exactly one row.
That helper is correct for TP-39-02 and TP-39-04, but not for TP-39-03.

Canonical TP-39-03 validly records two decision rows in one guarded apply:

- `retained_cold/cold_room=1` for the exact payload;
- `evicted/both_filled=1` for the checkpoint payload.

The same operation also records exactly one cold transaction:

- `commit/none=1`.

## Fix

Added TP-39-03-specific validators:

- `Assert-Tp3903OutcomeS39` requires the paired decision set above, rejects any
  missing, wrong, duplicate, or extra decision tuple, and keeps transaction
  validation exact at one `commit/none`.
- `Assert-Tp3903ApplyLogS39` requires the matching paired apply-window decision
  logs and the single `commit/none` transaction log.

`Assert-Tp3903` now uses those TP-39-03 validators. `Assert-ExactOutcomeS39`
remains unchanged and is still used by TP-39-02 and TP-39-04, preserving their
exact one-decision expectations.

## Regression coverage

The PowerShell pure self-test now includes:

- a passing TP-39-03 paired metric delta:
  `retained_cold/cold_room=1`, `evicted/both_filled=1`, and `commit/none=1`;
- missing retained-cold tuple rejection;
- missing evicted tuple rejection;
- duplicate evicted tuple rejection;
- extra unrelated decision tuple rejection;
- wrong retained-cold reason rejection;
- missing `commit/none` transaction rejection;
- paired apply-window log validation.

## Evidence

Commands run from repo root:

```text
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile(''._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1'', [ref]$tokens, [ref]$errors) > $null; if ($errors.Count) { $errors | Format-List *; exit 1 }'
powershell -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile(''._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1'', [ref]$tokens, [ref]$errors) > $null; if ($errors.Count) { $errors | Format-List *; exit 1 }'
pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest
powershell -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest
```

Results:

| Check | Result |
| --- | --- |
| PowerShell 7 parser | PASS |
| Windows PowerShell 5 parser | PASS |
| PowerShell 7 `-MetricValidationSelfTest` | PASS |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS |

The self-test output reports `Outcome : PASS`, TP-39-03 roles `source` and
`incoming`, and TP-39-03 literal lengths `721` and `723` in both shells.

## Not run

Per the correction request, this session did not run:

- TP-39-03 model execution;
- coverage blocks.

## Handoff

Part 190 records Architect PASS for the driver-only assertion change and pure
regression matrix. Manager rerun gate is next. QA still owns the
Manager-authorized D39-QA-10 order after that gate: clean seam-ON Release full
target build, PowerShell 7/5 parser and pure checks, one canonical TP-39-03
node, and coverage only after full `Assert-Tp3903` PASS.
