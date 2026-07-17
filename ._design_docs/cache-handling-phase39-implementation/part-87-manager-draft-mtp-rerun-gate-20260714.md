# Part 87: Manager draft-MTP rerun gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-20

Design Part 46 and Architect Part 86 prove that D39-EXEC-19 omitted one
required runtime selector. D39-EXEC-20 authorizes the narrow helper correction
and exact two-node rerun.

Developer may add exactly one adjacent argument pair to the dedicated
`Stage39MTPServer` command:

```text
--spec-type draft-mtp
```

Developer must also add the Part 46 fail-closed checks: exactly one selector
pair before admission, positive draft bytes in the source save, and positive
target and draft components in both proof rows. All Part 45 fixture identity,
literal request, budgets, isolation, pair, purity, fault, artifact, and cap
requirements remain binding.

Run only these nodes, sequentially with fresh processes and roots:

- `test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal`
- `test_live_pressure_prepared_proof_step2_fault_coherent_terminal`

Acceptance is `2 passed`, `0 failed`, `0 skipped` within 20 minutes, 16 GiB
RSS, and 4 GiB cold-root size per node. Preserve both new artifact roots. Any
failed preflight or cap stops before apply.

No product code, other startup option, fallback, build, canonical TP-39-03,
coverage, full route suite, full QA, commit, push, PR, or reviewer response is
authorized. Fresh Architect implementation review is next after the rerun.
