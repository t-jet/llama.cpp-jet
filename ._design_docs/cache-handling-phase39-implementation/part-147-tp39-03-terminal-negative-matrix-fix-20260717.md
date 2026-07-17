# Part 147: TP-39-03 terminal negative matrix fix

Date: 2026-07-17
Status: REVIEWED; ARCHITECT PASS IN PART 148
Scope: F146-01 pure PowerShell negatives only

## Correction

The pure terminal matrix now mutates each group named by F146-01 and requires
`Assert-Tp3903TerminalProofS39` to reject it. Cases cover terminal status and
process identity, generation order, prepared records, entry and branch state,
cold and staging inventories, topology, and the checkpoint link observation.

Three nonempty-log cases inject the snapshot token, proof token, and terminal
HMAC separately. Each must reach the existing credential-leak rejection. Every
shared fixture mutation restores its original value in `finally`.

Runtime code, route schema, fixture, seam, and test plan are unchanged.

## Evidence

| Check | Result |
| --- | --- |
| PowerShell parser API | PASS, 0 errors |
| PowerShell 7 preflight-free pure self-test | PASS, exit 0 |
| Windows PowerShell 5 preflight-free pure self-test | PASS, exit 0 |

No model, build, coverage, product, fixture, seam, test-plan, or threshold
command ran.

## Gate

Part 148 closes F146-01 and F142-02. QA owns the already approved bounded
canonical TP-39-03 and coverage rerun.
