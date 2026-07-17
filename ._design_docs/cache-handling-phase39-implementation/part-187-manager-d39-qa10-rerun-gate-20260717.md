# Part 187: Manager D39-QA-10 rerun gate

Date: 2026-07-17
Verdict: PASS
Decision: D39-QA-10

Architect Part 186 accepts the D39-QA-09 empty cold-inventory driver fix. The
PowerShell driver now normalizes header-only CSV imports and typed null
placeholders, counts real `.cold` rows for TP-39-03 cold-empty setup, and keeps
final cold-state checks strict.

D39-QA-10 authorizes `test-report-20260717-10.md`: fresh clean Release
seam-ON build of the full D39-QA target set, PowerShell 7 and Windows
PowerShell 5 parser and pure tests, then one bounded canonical TP-39-03 node.
Require full `Assert-Tp3903` PASS.

Only after that PASS, run the four coverage blocks under Parts 149 and 155.
Stop on the first verdict-fixing failure. No product, fixture, workload, seam,
budget, threshold, stage-plan, commit, push, PR, or reviewer-response change is
authorized. Developer review follows the QA report.
