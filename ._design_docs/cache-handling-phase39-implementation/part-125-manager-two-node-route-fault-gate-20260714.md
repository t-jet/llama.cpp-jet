# Part 125: Manager two-node route fault gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-32

Architect Part 124 closes F39-TEST-02 and passes route readiness. D39-EXEC-32
authorizes exactly the two route nodes named there, sequentially with
`--maxfail=1`: midpoint first, then step 2.

Each node must use a fresh process, port, token, session, cold/artifact root,
IDs, generation, and proof. Use the existing seam-ON Release server, unchanged
helper, `--spec-type draft-mtp --log-verbosity 4`, context 8192, and 2048 MiB
hot/cold startup budgets. Bind the accepted source and incoming request bytes
and SHA-256 values from Part 124.

Preserve the low-budget inequalities, trace preflight, full terminal matrix,
seven observed forbidden-effect checks, HMAC retrieval/tamper rejection,
consumed retry, and exact decision/transaction deltas. Per-node caps are 20
minutes, 16 GiB RSS, 4 GiB cold root, and 64 MiB server log. Preserve every
artifact listed by Part 124.

Acceptance is exactly `2 PASS / 0 FAIL / 0 BLOCKED`, with no skip or fallback.
Stop on the first failure, blocker, cap breach, drift, or missing artifact.

Build, source/helper/fixture changes, default or canonical TP-39-03, coverage,
full QA, commit, push, PR, and reviewer responses remain blocked. Fresh
Architect implementation/evidence review follows PASS.
