VERDICT: PASS

# Part 148: Architect TP-39-03 terminal negative matrix re-review

Date: 2026-07-17
Scope: F146-01 correction in Part 147

## Review basis

Reviewed Parts 146 and 147, the active fix report, and the pure terminal proof
assertion and negative matrix in `stage39-two-layer-pressure.ps1`. Parser
validation and preflight-free PowerShell 7 and Windows PowerShell 5 self-tests
passed. No model, build, coverage, product, fixture, seam, or test-plan command
ran.

## Finding disposition

| Finding | Result | Evidence |
| --- | --- | --- |
| F146-01 | CLOSED | Each missing terminal assertion group has an isolated rejecting mutation. Shared fixture edits restore their original value in `finally`; each real secret is tested in a separate nonempty log. |
| F142-02 | CLOSED | Parts 145 and 148 together prove raw-byte retrieval, consumption, full positive terminal assertions, artifact redaction, and negative-group parity. |

## Negative matrix

- Status and process identity mutations reject in the terminal shape check.
- Final-generation regression rejects in the monotonic generation check.
- Prepared-record payload drift rejects against the ordered binding.
- Entry and branch mutations reject independently.
- Cold and staging inventory mutations reject independently.
- Topology delta and checkpoint-link mutations reject independently.
- Snapshot token, proof token, and terminal HMAC each reject when placed in a
  nonempty log.

The terminal fixture passes before the negative loop. Each stateful case changes
one field and restores it in `finally`, so later cases cannot inherit corrupted
state. The three log cases do not mutate the fixture. Existing retrieval,
raw-byte, decision, transaction, diagnostic, descriptor, forbidden-observation,
and forbidden-effect negatives still pass. Script changes are confined to the
pure self-test matrix; runtime behavior is unchanged.

## Verification

| Check | Result |
| --- | --- |
| PowerShell parser API | PASS, 0 errors |
| PowerShell 7 preflight-free pure self-test | PASS, exit 0 |
| Windows PowerShell 5 preflight-free pure self-test | PASS, exit 0 |

## Gate

F146-01 and F142-02 are closed. QA may run the already approved bounded
canonical TP-39-03 and coverage scope. This review does not claim those runtime
rows passed.
