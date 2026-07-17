# Part 151: TP-39-03 draft-MTP driver fix

Date: 2026-07-17
Status: READY FOR ARCHITECT REVIEW
Source: Part 150 and `../.test_reports/test-report-20260717-02-fixes.md`

## Correction

The canonical PowerShell driver now inserts one adjacent
`--spec-type draft-mtp` pair after the TP-39-03 chat-template argument. A final
argv check requires that exact pair for `both-filled`, rejects duplicate
selectors and speculative aliases, and rejects the selector in every other
scenario. It also rejects `LLAMA_ARG_SPEC_TYPE` for the canonical node so an
environment override cannot change the selected runtime.

The driver now saves these files before proof component validation:

- `control-linked-proof-request.json`
- `control-linked-proof-response.json`
- `control-explicit-proof-request.json`
- `control-explicit-proof-response.json`

The writer redacts `snapshot_token`, `proof_token`, and `terminal_hmac` at any
object depth and checks that known secret values do not remain in serialized
output. Explicit proof ID construction checks the ordered pair identity without
requiring valid component sizes. This lets the driver preserve both exchanges
before the positive draft-component check fails.

## Pure regression evidence

The embedded self-test covers selector presence in `both-filled`, absence in
the six other scenarios, duplicate and alias rejection, wrong placement, and
cross-scenario leakage. Its proof-artifact case writes all four files with a
zero draft component, confirms the expected preflight failure, then checks file
survival and redaction of snapshot token, proof token, and terminal HMAC.

| Check | Result |
| --- | --- |
| PowerShell 7 parser | PASS, 0 errors |
| Windows PowerShell 5 parser | PASS, 0 errors |
| PowerShell 7 pure self-test | PASS, exit 0 |
| Windows PowerShell 5 pure self-test | PASS, exit 0 |

No model, build, coverage, product, fixture, seam, test-plan, or threshold work
ran or changed.

## Handoff

Fresh Architect review is next. A Manager gate remains required before one new
canonical TP-39-03 run. Coverage remains blocked until that node passes.
