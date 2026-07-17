VERDICT: PASS

# Part 162: Architect D39-QA-04 fix review

Date: 2026-07-17
Scope: Part 160, Part 161, D39-QA-04 fixes, guarded seam, driver, and focused regressions

## Review result

No blocking finding. Correction stays inside guarded evidence and driver code.
Production eviction, retention, budgets, fixture, workload, caps, plan, and
coverage threshold are unchanged.

## Contract checks

| Check | Result |
| --- | --- |
| Signed topology deltas | PASS. Entry, node, LRU membership, and branch-prune deltas use one `int64_t` subtraction helper. Nlohmann JSON therefore emits signed integer values; `1 -> 0` is `-1`, not `UINT64_MAX`. |
| Hot LRU semantics | PASS. `evict_entry_by_id()` removes a successfully demoted source from `lru_index` while preserving lookup visibility. Terminal source membership `0` and delta `-1` match that policy. |
| Retained source state | PASS. Driver still requires source entry and branch identity, exact owner link, zero source resident bytes, exact descriptor cold residency, one matching cold file, descriptor bytes, serialized bytes, and byte-map bytes. Checkpoint remains an evicted tombstone; entry, node, and prune deltas remain zero. |
| Over-budget accounting | PASS. Proof enumerates resident entries with live branch references. Driver requires exactly one different-owner row, positive references, and row bytes equal to total remaining resident bytes above the applied budget. Source resident state is independently required to be zero, so stale source bytes cannot hide in this explanation. |
| Negative tests | PASS. Pure tests reject membership `1`, delta `0`, unsigned wrap, source-owner substitution, and an unexplained resident-byte mismatch. Each mutation must throw or the self-test fails. |
| Scope | PASS. Changes affect `LLAMA_STAGE39_LIVE_TEST_SEAM`, controller regression evidence, and the Stage 39 driver only. No product behavior path changed for this correction. |

## Focused verification

- Existing seam-ON `test-cache-controller.exe`: PASS, including the signed LRU regression.
- PowerShell 7 parser and `-MetricValidationSelfTest`: PASS.
- Windows PowerShell 5 parser and `-MetricValidationSelfTest`: PASS.
- No model, coverage, fixture, or plan command ran.

## Handoff

Architect fix review passes. Manager may authorize one canonical TP-39-03
rerun under the existing fail-fast contract. Coverage remains closed until the
full terminal assertion passes.
