# Part 21: Architect implementation re-review

Date: 2026-07-12
Verdict: PASS

## Scope

Reviewed Part 19 findings against Part 20, approved design Parts 1-3, production
hybrid-cache pressure code, focused controller tests, and the Stage 39 live
driver. `tools/server/grafana/dashboard.json` was excluded.

## Findings

No blocking findings remain.

| Finding | Result | Evidence |
| --- | --- | --- |
| F39-IR-01 | CLOSED | `tx_demote_payload()` preserves the capacity subtype. The production caller emits `evicted/oversized_both` only when the exact cold object exceeds the cold budget and the resident pair exceeds the positive hot budget. Failed room-making otherwise emits `evicted/both_filled`. `test_stage39_production_capacity_reason_selection()` drives and distinguishes both paths. |
| F39-IR-02 | CLOSED | `mark_payload_kind_evicted()` emits `bypassed/cold_disabled` before the existing hot-only eviction when cold is unavailable. `test_stage39_production_cold_disabled_bypass()` verifies the tuple, eviction count, and released hot bytes. The `--cache-ram 0` server path still constructs no cache controller. |
| F39-IR-03 | CLOSED | The focused tests use normal admission pressure rather than metric injection. `stage39-two-layer-pressure.ps1` exposes executable `oversized-both`, `cold-disabled`, and `hot-zero` scenarios and asserts their public metric contracts. Model-backed runs and the complete evidence matrix remain QA-owned. |

## Verification

- Release `test-cache-controller` target build: PASS.
- Release `test-cache-controller.exe`: PASS, including all Stage 39 focused
  production-path and transaction tests.
- Stage 39 PowerShell live-driver parser check: PASS.
- Production review confirms capacity failure is the only path that proceeds
  from failed demotion to payload eviction. Non-capacity failure retains hot
  bytes and returns without entry removal.

The live driver starts a fresh server for each scenario, so its observed public
series are scenario-local. QA must still preserve before/after metrics, matching
logs, byte/accounting data, and lookup/branch counts required by design Part 3.

## Handoff

PASS. Stage 39 implementation matches the approved two-layer retention contract
for the reviewed scope. Manager may run the implementation gate. QA execution
remains closed until that Manager gate passes.
