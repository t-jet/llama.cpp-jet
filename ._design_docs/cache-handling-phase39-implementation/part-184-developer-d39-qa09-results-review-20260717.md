# Part 184: Developer D39-QA-09 results review

Date: 2026-07-17
Verdict: REWORK REQUIRED
Related report: `._design_docs/.test_reports/test-report-20260717-09.md`
Developer review: `._design_docs/.test_reports/test-report-20260717-09-developer-review.md`

## Decision

D39-QA-09 passes the clean seam-ON Release full target build and both
PowerShell parser/pure gates, then fails in canonical TP-39-03 at a driver
assertion. The failure is a driver assertion bug, not a Stage 39 product bug,
not an execution blocker, and not a design mismatch.

The product transition reached the expected tuple before the script threw:

- exact payload retained cold;
- checkpoint payload evicted because both layers were filled;
- one retained-cold decision, one evicted decision, and one commit;
- no entry count, node count, or branch prune delta.

The failing assertion is the cold-empty check in
`stage39-two-layer-pressure.ps1:1031`. The pre-apply cold inventory CSV is
header-only. PowerShell 7 imports that as `$null`, and then the `[object[]]`
parameter binding used by `Assert-Tp3903` causes `@($ColdBefore).Count` to be
`1`. That is a false cold-empty mismatch. A direct probe shows top-level
`@($null).Count` is `0`, while the same value bound to the typed assertion
shape counts as one null element in PowerShell 7.

The earlier `SKIP-preflight-fresh-root` row came from a pre-created run root
and is not product evidence.

## Owner and correction scope

Owner: Developer.

Correction scope:

- Fix `stage39-two-layer-pressure.ps1` cold inventory handling so empty
  inventories remain zero rows through both producer capture and typed
  assertion boundaries.
- Change TP-39-03 cold-empty validation to count actual cold inventory file
  rows, preferably `.cold` rows, instead of relying on `@($ColdBefore).Count`
  over a raw `[object[]]` parameter.
- Add PowerShell 7 and Windows PowerShell 5 pure coverage for the header-only
  CSV or null cold-inventory case through the typed TP-39-03 assertion path.
- Keep product code, workload, fixture, seam, budget, threshold, and coverage
  policy unchanged.

## Evidence required from the fix

Developer must provide:

- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- Focused proof that a header-only cold inventory imports and binds as zero
  rows through the TP-39-03 assertion boundary.
- Static review of the remaining TP-39 cold-empty checks so the same typed
  null-array mistake is not left in neighboring assertions.

QA retest after Developer and Architect review:

- Repeat Manager Part 183's D39-QA-09 order: fresh clean seam-ON Release full
  target build, PowerShell 7/5 parser and pure tests, one canonical TP-39-03
  node, then four coverage blocks only after full `Assert-Tp3903` PASS.
- Stop on the first verdict-fixing failure.

No code was changed for this review.
