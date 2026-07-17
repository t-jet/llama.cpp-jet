# Part 173: Manager D39-QA-07 rerun gate

Date: 2026-07-17
Verdict: PASS
Decision: D39-QA-07

Architect Part 172 passes the D39-QA-06 driver contract correction. The
canonical TP-39-03 driver now accepts and verifies the three reviewed
zero-valued component fields, while the exact property-set guard still rejects
missing, nonzero, stale 15-field, and extra-field shapes in PowerShell 7 and
Windows PowerShell 5 pure checks.

D39-QA-07 authorizes `test-report-20260717-07.md`: fresh clean Release
seam-ON build, PowerShell 7 and Windows PowerShell 5 parser and pure tests,
then one bounded canonical TP-39-03 node. Require full `Assert-Tp3903` PASS.

Only after that PASS, run the four coverage blocks under Parts 149 and 155.
Stop on the first verdict-fixing failure. No product, fixture, workload, seam,
budget, threshold, stage-plan, commit, push, PR, or reviewer-response change is
authorized. Developer review follows the QA report.
