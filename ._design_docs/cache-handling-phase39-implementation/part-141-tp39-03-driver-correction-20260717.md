# Part 141: TP-39-03 driver correction

Date: 2026-07-17
Status: READY FOR ARCHITECT REVIEW
Scope: Part 140's bounded canonical PowerShell correction

## Result

The canonical `both-filled` path now matches the accepted natural same-owner
route contract. It admits source then incoming once, leaves the incoming slot
reference intact, validates one eligible source exact row with empty cold,
proves the owner's ordered hot exact/checkpoint pair, and sends prepared
bindings with `tp39_03_setup:"same_owner_kind_sequence"`.

Historical cold-owner setup, owner moves, and cold-rank setup are absent from
the request. Checked byte formulas set positive hot and cold budgets while
proving both Part 43 inequalities. Existing caps, authentication, redaction,
terminal, accounting, metric, log, and artifact checks remain in place.

## Evidence

The full correction record is
[`test-report-20260717-01-fixes.md`](../.test_reports/test-report-20260717-01-fixes.md).
Parser validation and preflight-free self-tests pass under PowerShell 7 and
Windows PowerShell 5. Pure negatives cover every Part 140 case. No model,
build, or coverage command ran.

## Handoff

Next gate is a fresh Architect review. If it passes, Manager may authorize one
fresh bounded canonical TP-39-03 run. The four coverage blocks remain deferred
until TP-39-03 passes.
