# Part 149: Manager TP-39-03 and coverage rerun gate

Date: 2026-07-17
Verdict: PASS
Decision: D39-QA-02

Architect Part 148 passes the corrected TP-39-03 driver and pure negative
matrix. D39-QA-02 authorizes one fresh focused QA session recorded in
`._design_docs/.test_reports/test-report-20260717-02.md`.

QA must start with a fresh clean Release seam-ON build and record the same
environment, fixture, toolchain, timestamp, dirty-state, and cleanup evidence
required by test-plan Part 43. Run cheap parser and PowerShell 7/5 self-tests
before expensive work.

Then run exactly:

1. one bounded canonical TP-39-03 node with the approved Qwen3.5-4B MTP
   fixture and require `Assert-Tp3903` PASS under the Part 43 caps;
2. the PowerShell 7 coverage success block in a fresh root;
3. the PowerShell 7 forced merge-failure block in a fresh root;
4. the Windows PowerShell 5 coverage success block in a fresh root;
5. the Windows PowerShell 5 forced merge-failure block in a fresh root.

Successful coverage must exit 0, preserve real merged XML and Markdown, and
meet at least 80 percent. Each forced block must exit 1, preserve capture files
and the delegated exit-23 message, and write neither merged XML nor report.
Stop after the first result that fixes the stage verdict. Preserve exact
commands, outputs, artifacts, hashes, caps, and cleanup.

No product, driver, fixture, seam, test-plan, threshold, contract, commit, push,
PR, or reviewer-response change is authorized. Developer test-results review
follows the rerun report.
