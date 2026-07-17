# Part 195: Manager D39-QA-12 rerun gate

Date: 2026-07-17
Verdict: PASS
Decision: D39-QA-12

Architect Part 194 accepts the D39-QA-11 descriptor/residency delta driver fix.
TP-39-03 now expects the exact metric deltas for the same-owner exact-cold and
checkpoint-evicted transition, while TP-39-02 and TP-39-04 remain unchanged.

D39-QA-12 authorizes `test-report-20260717-12.md`: fresh clean Release
seam-ON build of the full D39-QA target set, PowerShell 7 and Windows
PowerShell 5 parser and pure tests, then one bounded canonical TP-39-03 node.
Require full `Assert-Tp3903` PASS.

Only after that PASS, run the four coverage blocks under Parts 149 and 155.
Stop on the first verdict-fixing failure. No product, fixture, workload, seam,
budget, threshold, stage-plan, commit, push, PR, or reviewer-response change is
authorized. Developer review follows the QA report.
