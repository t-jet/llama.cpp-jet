# Part 145: TP-39-03 terminal proof rework

Date: 2026-07-17
Status: ARCHITECT RE-REVIEW REWORK
Scope: Part 144 finding F142-02 only

## Correction

The PowerShell driver now preserves the apply response bytes, extracts the
embedded `prepared_proof` object without parsing or serializing it, and compares
those bytes with the successful authenticated retrieval body. It exposes
retrieval consumption through a required retry of the original apply request;
the retry must fail with `consumed`.

The terminal assertion now checks the complete successful TP-39-03 row:

- one `retained_cold/cold_room` decision, one `evicted/both_filled` decision,
  and one `commit/none` transaction;
- no terminal diagnostic rows;
- exact descriptor, cold file, and byte map equality;
- checkpoint hot-to-evicted descriptor and link observations;
- the full observed-effect map, including zero checkpoint cold publication,
  commit, file, admission, diagnostics, and later-work effects;
- retained entry and branch identity with the expected zero resident state,
  one sync, unchanged topology, no staging files, and no later victim.

Pure negatives cover raw-byte drift, missing consumption, accepted retry,
decision, transaction, diagnostics, descriptor accounting, observed cold-file
effects, and forbidden-effect deltas. Token and terminal HMAC artifacts remain
redacted. F142-01, F142-03, and Part 141 scope are unchanged.

## Evidence

| Check | Result |
| --- | --- |
| PowerShell parser API | PASS, 0 errors |
| PowerShell 7 preflight-free self-test | PASS, exit 0 |
| Windows PowerShell 5 preflight-free self-test | PASS, exit 0 |

No model, build, coverage, product, fixture, seam, test-plan, or threshold
command ran.

## Gate

Part 146 confirms the raw-byte, consumption, successful terminal assertion,
and redaction paths, but returns F142-02 because pure terminal negatives do not
cover every assertion group. Canonical TP-39-03 and coverage remain blocked.
