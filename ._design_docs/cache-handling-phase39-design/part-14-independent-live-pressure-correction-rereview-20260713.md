# Part 14: independent live pressure correction re-review

Date: 2026-07-13
Verdict: PASS
Scope: design Part 11, implementation Parts 39-41, and test-plan Part 43

## Review basis

Reviewed the documentation correction against design Parts 1-3, Parts 12-13,
D39-EXEC-01, the current hot-pressure and cold room-making production paths,
and the canonical coverage runner. This is a plan review. Commands and expected
results are specified but have not run in this review.

## Prior findings

F39-LPCR-RR-01 is closed. `hot_candidates` and `cold_victims` are disjoint,
complete sets. Validation recomputes each set under the cache-state lock and
checks residency, ownership, unique IDs, omissions, and extras independently.
Hot rows require exclusive hot residency. Cold rows require exclusive cold
residency. Equal cold ranks preserve the production
`(last_validated_sequence, payload_id)` order.

TP-39-02 now has a reachable production flow. Normal admissions and `tx_save()`
pressure first leave two eligible victims cold and the incoming candidate hot.
The control request changes setup state only, then calls normal `tx_update()`.
Production hot pressure selects the incoming owner, `tx_demote_payload()`
prepares its immutable object, and cold room-making selects the complete cold
set. QA must derive the lowered cold budget from measured object sizes so the
incoming object fits only after both victims are reclaimed. The numeric `1`
values in the schema example are illustrative, not TP-39-02 fixture values.

F39-LPCR-RR-02 is closed. Part 39 gives exact OFF and ON configure, build,
pytest, and controller commands. It names route cases, fixed exits, and artifact
rules. The literal batch fixture delegates capture calls and returns 23 only
for merge calls. PowerShell 7 and Windows PowerShell 5 use distinct fresh
success and failure trees. Success requires exit 0, `coverage-merged.xml`,
`coverage-report.md`, and the 80 percent gate. Forced merge failure requires
runner exit 1, retained `.cov` files, the exact exit-23 error, and neither final
artifact. This matches the runner's actual merged XML name.

## Retained boundaries

- Compile-OFF removes symbols and route. Runtime opt-in, loopback, single-model,
  hybrid mode, metrics, token, schema, redaction, and positive budgets remain
  mandatory.
- One admission latch serializes idle validation, mutation, production pressure,
  final snapshot, and cleanup against new completion dispatch.
- `ready` becomes irreversibly `consumed` before first mutation. Validation is
  retryable; later failure is terminal. Pre-pressure state restores locally;
  production transaction recovery owns every post-pressure outcome.
- Seam cannot change residency, ownership, IDs, files, sizes, counters, pair
  state, or topology, and cannot call outcome, demotion, eviction, metric, log,
  or accounting helpers directly.
- TP-39-04 still admits and measures under larger positive budgets before both
  budgets are lowered. Serialization uses the immutable prepared-file length.
- Coverage correction remains limited to absolute no-argument `whoami.exe` and
  immediate nonzero merge failure. Phase order, denominator, captures, server
  probe, report format, and threshold remain unchanged.

## Verdict and handoff

PASS. No blocking finding remains from Parts 12 or 13. This verdict approves
the correction plan, not implementation or QA evidence.

Next owner: Manager for the correction-plan gate and implementation handoff.
Code, script, test implementation, and QA execution remain blocked until that
gate authorizes the next step.
