# Stage 39 QA4 driver fix

Date: 2026-07-13
Finding: F39-QA4-01
Status: READY FOR ARCHITECT REVIEW

## Scope

Fix the canonical Stage 39 driver's null-row crash for valid `hot-zero` and
`legacy` runs. Product code, the accepted test plan, and the QA report are
unchanged.

## Root cause

The driver passed `$decisions + $transactions` to row validation before it
checked the zero-row scenarios. When both collections were null, PowerShell
wrapped the result as one null loop item. The row parser then reported that
item as malformed.

## Correction

`Assert-Stage39MetricRowsS39` now owns both rules:

- `hot-zero` and `legacy` accept no Stage 39 rows and reject any emitted row;
- other scenarios validate every non-null row, reject malformed rows or
  labels, and reject duplicate label names.

The live path calls this helper before its scenario-specific tuple checks.
`-MetricValidationSelfTest` exercises empty `hot-zero` and `legacy` inputs,
valid nonempty decision and transaction rows, a malformed row, and a malformed
label. It returns before model or server preflight.

## Evidence

PowerShell AST parse:

```text
AST PASS
```

Focused self-test under PowerShell 7:

```powershell
pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 `
  -ModelPath unused -MetricValidationSelfTest
```

Result: exit 0; `PASS {hot-zero, legacy} True`.

Focused self-test under Windows PowerShell 5:

```powershell
powershell.exe -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 `
  -ModelPath unused -MetricValidationSelfTest
```

Result: exit 0; `PASS {hot-zero, legacy} True`.

## Handoff

F39-QA4-01 is ready for fresh Architect review. QA still owns live reruns of
`hot-zero` and `legacy`, canonical coverage, and TP-39-02 through TP-39-04.
