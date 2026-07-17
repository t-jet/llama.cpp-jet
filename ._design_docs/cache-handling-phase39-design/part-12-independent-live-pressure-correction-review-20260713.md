# Part 12: independent live pressure correction review

Date: 2026-07-13
Verdict: REWORK
Scope: design Part 11, implementation Part 39, and test-plan Part 43 only

## Review basis

Reviewed against approved design Parts 1-3, D39-EXEC-01, Developer Part 38,
current `tx_update()` and cold-victim ordering, the server route surface, and
the Phase 3 coverage merge command.

The correction keeps the seam test-only, default-OFF, runtime-gated, loopback
only, hybrid only, tokened, one-shot, and unable to call outcome helpers. Its
budget-lowering approach resolves the original TP-39-04 startup reachability
problem. Calling `tx_update()` reaches the normal production pressure,
demotion, transaction, decision, accounting, log, and exporter path.

## Blocking findings

| ID | Finding | Required correction |
| --- | --- | --- |
| F39-LPCR-01 | Part 11 checks that slots are idle before entering the controller transaction, but it does not prevent a normal completion from becoming active between that check and budget/rank mutation. Part 39 names an idle-state wrapper without a serialization rule. The one-shot state is also consumed only after the final snapshot, so an exception after pressure starts can leave a mutated process eligible for a second control request. | Define one server-side critical section or admission latch that blocks new completion dispatch, verifies all slots idle, and remains held until control finishes. Mark the request consumed before the first mutation. Validation failures may remain retryable; any failure after mutation starts must leave the one-shot terminal. Add deterministic race and post-mutation-failure tests. |
| F39-LPCR-02 | `hot_order` ranks owner entries, but the schema rejects duplicate payload IDs only. Two selected payloads may name one owner and request conflicting owner ranks. The contract also does not reject an unlisted eligible hot candidate, so normal LRU planning can choose a payload outside the declared order and invalidate TP-39-02 through TP-39-04 tuple counts. | Require unique owner entry IDs for selected exact-blob payloads. Validate that the request names the complete eligible hot candidate set for the pressure operation, or define and test an equivalent exclusion rule. State how owner LRU index updates remain consistent. Keep equal `cold_rank` ordering as `(last_validated_sequence, payload_id)`. |
| F39-LPCR-03 | Part 43 still says TP-39-04 must "Admit pair larger than both positive budgets", then later says admission occurs under high budgets before both budgets are lowered. Part 11 does not explicitly supersede the earlier Part 3 procedure wording. One QA plan therefore contains both the unreachable procedure and its correction. | Make the corrected order authoritative in Part 11 and Part 43: admit while both positive startup budgets exceed the pair, measure it, then lower both budgets below it. State that this replaces only the old TP-39-04 setup wording and does not change its result or acceptance contract. |
| F39-LPCR-04 | Part 39 leaves the route-test file or target undecided, does not map named assertions separately to TP-39-02, TP-39-03, and TP-39-04, and asks for a forced nonzero coverage probe without an executable command or fixture. QA would still choose how to prove the gate. | Name every affected source, script, and test file or target. Map each TP row to named tests and assertions. Specify executable OFF/ON, route-misuse, idle-race, one-shot, PowerShell 5/7, Phase 3 positive, and forced-nonzero merge probes with fixed expected exits and artifacts. |

## Checks that pass

- Compile guard and runtime opt-in are separate; default and installed builds
  expose no route or controller seam symbol.
- Loopback, single-model, hybrid, metrics, positive budgets, token length,
  constant-time comparison, strict schema, redaction, and route-absence rules
  preserve public production semantics.
- The seam changes fixture setup only. It does not call demotion, eviction,
  transaction, metric, log, accounting, ownership, or topology helpers.
- Positive lower budgets preserve the Stage 39 zero/unlimited semantics.
- Current cold victim ordering is deterministic by
  `(last_validated_sequence, payload_id)` once the complete candidate set is
  controlled.
- Replacing the Phase 3 `cmd /c exit 0` tail with absolute, no-argument
  `whoami.exe` avoids `Start-Process` argument reconstruction. Checking its
  existence and testing merge exit before XML parsing are correct boundaries.
- No threshold, denominator, phase order, server probe, or live-tier rule is
  relaxed.

## Handoff

Next owner: Developer. Correct Parts 11, 39, and 43 only. Do not implement the
seam or coverage change until a fresh independent Architect re-review passes.
