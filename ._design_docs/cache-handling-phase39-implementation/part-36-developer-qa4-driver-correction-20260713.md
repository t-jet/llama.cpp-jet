# Part 36: Developer QA4 driver correction

Date: 2026-07-13
Status: READY FOR ARCHITECT REVIEW

## Scope

This correction closes Developer finding F39-QA4-01 only. It changes the
canonical Stage 39 live driver and adds focused parser evidence. Product code,
the accepted test plan, and QA report 20260712-04 are unchanged.

## Change

The driver used to validate a null combined collection before applying the
valid `hot-zero` and `legacy` zero-row rule. It now routes both rules through
`Assert-Stage39MetricRowsS39`:

- zero-row scenarios return only when both Stage 39 families are absent;
- emitted rows still fail those scenarios;
- nonempty rows still reject malformed rows, malformed labels, and duplicate
  label names.

`-MetricValidationSelfTest` covers both zero-row scenarios, valid nonempty
rows, and both malformed row and malformed label failures without starting a
server.

## Verification

- PowerShell AST parse: PASS.
- PowerShell 7 self-test: PASS, exit 0.
- Windows PowerShell 5 self-test: PASS, exit 0.
- LF-only and ASCII checks: PASS.
- Scoped `git diff --check`: PASS.

Full commands and output are in
`../.test_reports/test-report-20260712-04-fixes.md`.

## Handoff

Fresh Architect review is next. QA reruns live `hot-zero` and `legacy` only
after that review passes. Coverage and TP-39-02 through TP-39-04 remain open
under the existing QA/Manager ownership.
