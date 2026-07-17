# Part 84: Manager TP-39-03 route fixture gate

Date: 2026-07-14
Verdict: PASS
Decision: D39-EXEC-19

Design Part 45 and implementation Part 83 close the Part 82 route-fixture
design blocker. D39-EXEC-19 authorizes only the helper change and two bounded
route nodes described there.

Developer may add a dedicated MTP helper for these exact tests:

- `test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal`
- `test_live_pressure_prepared_proof_step2_fault_coherent_terminal`

Each node must use its own seam-ON Release server, port, cold root, process
token, artifact directory, and one-shot session. The helper must use the exact
Part 45 model, template, startup flags, literal request bytes, 2048 MiB hot
budget, capability checks, natural same-owner pair checks, and fail-closed
rules. The 20-minute, 16 GiB RSS, and 4 GiB cold-root caps apply per node. The
nodes run sequentially and must finish `2 passed`, `0 failed`, `0 skipped`.

Any missing fixture, metadata mismatch, missing checkpoint, pair drift, cap
breach, or preflight mutation stops before apply and records the fixed blocked
reason. No fallback model, short prompt, synthetic checkpoint, owner
reassignment, or controller setup is authorized.

Developer may change only the dedicated route helper and related focused test
fixtures. Product code, guarded route schema, production policy, cold format,
metrics, and unguarded paths remain unchanged. Preserve node artifacts and add
durable implementation evidence. Fresh Architect implementation review is the
next gate after both nodes pass.

Canonical TP-39-03, coverage, full route execution, full QA, commit, push, PR,
and reviewer responses remain blocked.

## Historical outcome

Part 85 executed this authority and stopped both nodes before apply because the
approved command omitted `--spec-type draft-mtp`. Part 86 returns current
evidence as narrow REWORK and passes design Part 46's corrected startup and
preflight contract. A new Manager gate is required before another run.
