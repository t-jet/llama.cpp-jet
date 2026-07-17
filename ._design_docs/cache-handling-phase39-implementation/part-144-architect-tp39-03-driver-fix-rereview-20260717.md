VERDICT: REWORK

# Part 144: Architect TP-39-03 driver fix re-review

Date: 2026-07-17
Scope: Part 142 findings F142-01 through F142-03 after Part 143

## Review basis

Reviewed Parts 141-143, the active fix report, test-plan Part 43, the guarded
proof and retrieval product paths, the canonical PowerShell driver, and its
pure self-tests. Parser validation and preflight-free PowerShell 7 and Windows
PowerShell 5 self-tests passed. No model, build, coverage, product, fixture,
seam, or test-plan command ran.

## Finding disposition

| Finding | Result | Evidence |
| --- | --- | --- |
| F142-01 | CLOSED | `stage39_build_runtime_proof_locked()` expands a requested payload through its owner's exact and checkpoint links, sorts by kind, and returns both guarded rows. The driver validates that bootstrap result, extracts both nonzero IDs, and sends `payload_ids` in exact/checkpoint order for the binding proof. Product apply rebuilds the same proof and checks both ordered bindings and the proof HMAC. |
| F142-02 | OPEN | Retrieval is authenticated and HTTP-successful, apply consumption and terminal exact-cold/checkpoint-evicted topology are checked, and saved apply/retrieval artifacts redact the terminal HMAC. The remaining proof is incomplete: the driver compares parsed objects reserialized by PowerShell, not the response bytes; it cannot assert the retrieval result's `consumed` flag because the route returns only `terminal_body`; and it ignores terminal `decision_deltas`, `transaction_deltas`, `diagnostic_deltas`, `forbidden_observations`, `forbidden_effects`, and exact descriptor/file/byte-map accounting. The pure terminal fixture omits those fields, so both shells pass without exercising them. |
| F142-03 | CLOSED | The negative adds payload 201 owned by entry 21, keeps payload 101 owned by entry 11, adds the matching empty cold set, and reaches the exact source-count rejection in both shells. |

## Rework required

Expose and assert authenticated retrieval consumption. Compare the successful
retrieval response bytes against one explicitly defined canonical byte form of
the apply terminal proof. Assert every terminal accounting and forbidden-effect
field required by Part 43, including exact decision/transaction cardinality,
zero forbidden checkpoint effects, and descriptor/file/byte-map equality.
Extend the pure fixture with those fields and add one rejecting mutation for
each assertion group.

Part 141's workload scope, strict request schema, checked formulas, positive
budgets, six-chat cap, 20-minute cap, 16-GiB RSS cap, and 4-GiB cold-root cap
remain correct.

## Gate

Canonical TP-39-03 and coverage remain blocked. Developer owns F142-02 rework;
fresh Architect re-review follows.
