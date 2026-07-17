# Part 90: Manager trace preflight rerun gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-21

Design Part 47 and Architect Part 89 prove that D39-EXEC-20 selected the MTP
runtime but bound two trace-only records at default verbosity. D39-EXEC-21
authorizes the narrow test-helper correction and exact two-node rerun.

Developer may add exactly one adjacent pair after the speculative selector:

```text
--spec-type draft-mtp --log-verbosity 4
```

The dedicated helper must reject duplicate logging options, environment log
overrides, verbose or debug aliases, or any level other than 4. Add the 64 MiB
server-log cap and retain every capability, pair, purity, fault, resource, and
artifact assertion in design Part 47.

Run only the midpoint and step-2 route nodes, sequentially from fresh isolated
processes and roots. Acceptance is `2 passed`, `0 failed`, `0 skipped`. Existing
20-minute, 16 GiB RSS, and 4 GiB cold-root caps remain binding per node. Any
failed preflight or cap stops before apply.

No product code, default logging, other startup option, fallback, build,
canonical TP-39-03, coverage, full route suite, full QA, commit, push, PR, or
reviewer response is authorized. Fresh Architect implementation review is next
after the rerun.
