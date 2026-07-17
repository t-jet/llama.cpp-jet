# Part 140: Developer D39-QA-01 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Scope: QA report 20260717-01, TP-39-03, and deferred coverage

## Verdict

Full review:
`../.test_reports/test-report-20260717-01-developer-review.md`

QA passed 14 TP rows. TP-39-03 did not reach apply because the canonical
PowerShell path still uses the superseded owner-reassignment workload and
schema. Product logs prove both exact and checkpoint bytes were admitted. The
discovery result is correct for its entry-level policy inventory and empty cold
store. No product defect is established.

Coverage was intentionally not started after the closure-blocking TP-39-03
preflight result. This is a valid Part 139 fail-fast stop and leaves coverage
unmeasured, not failed.

## Correction plan

Developer owns one bounded automation correction:

1. Make TP-39-03 use the accepted source-then-incoming lifecycle once. Keep the
   incoming slot referenced so discovery exposes exactly one eligible source
   exact row and one empty cold set.
2. Call guarded `proof` with that exact payload ID. Require ordered exact and
   checkpoint rows, one owner, hot residency, compatible pair state, positive
   component sizes, and stable process/generation bindings.
3. Build `prepared_bindings` from proof rows. Send
   `tp39_03_setup:"same_owner_kind_sequence"`; remove
   `tp39_03_cold_owner_setup`, owner moves, and cold-rank setup.
4. Derive positive hot and cold budgets from Part 43's exact checked formulas.
   Preserve all current caps, HMAC, redaction, generation, terminal, accounting,
   metric, log, and artifact assertions.
5. Add pure driver tests for the accepted request shape and negatives for a
   second eligible owner, nonempty cold, missing/reordered kinds, owner drift,
   zero component, stale generation/process binding, and forbidden historical
   fields.

No product, guarded seam, fixture, test-plan, coverage contract, or threshold
change belongs in this correction.

## Exact retest

After fresh Architect review and Manager authorization:

- run script parser/self-tests under PowerShell 7 and Windows PowerShell 5;
- run one fresh bounded canonical TP-39-03 node and require `Assert-Tp3903`
  PASS with `evicted/both_filled`, exact retained cold, checkpoint evicted,
  zero pruning, retained topology, and reconciled bytes/files;
- run all four Part 43 coverage blocks in distinct fresh roots and require the
  success artifacts, forced-failure behavior, and at least 80 percent coverage.

No build, test, model, or coverage execution occurred in this review.
