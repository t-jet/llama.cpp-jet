# Part 47: QA plan guarded discovery correction

Date: 2026-07-13
Status: READY FOR FRESH INDEPENDENT ARCHITECT RE-REVIEW
Scope: documentation only; no code, scripts, tests, commits, or pushes

## Finding closed

F39-GDR-RR-01 is corrected in test-plan Part 43. The plan now uses the guarded
`discover` to snapshot-token to `apply` flow from design Part 15 and
implementation Parts 45-46. It removes the superseded apply-only body, global
`cold_victims` array, and cross-array owner uniqueness rule.

Discovery returns complete hot candidates and one complete `cold_sets` member
for every incoming owner. Cold selection uses only cold residency and incoming
owner exclusion. Descriptor integrity remains a separate retryable check. One
entry may own one exact blob and one checkpoint, while payload IDs remain unique
inside each exact set.

## Evidence correction

Part 43 names controller and Python route tests for:

- pure hot enumeration with no production metric delta;
- stable non-consuming discovery and retryable integrity failure;
- stale generation, wrong HMAC, changed-then-restored state, slot-reference
  drift, budget drift, and process-token binding;
- exact mixed-kind sets, omitted or extra checkpoints, and atomic apply
  revalidation;
- complete mutation-family generation ownership and explicit before/after
  generation;
- compile/runtime guards, loopback and admin security, strict schema, idle race,
  token redaction, terminal failure, and successful normal `tx_update()`;
- TP-39-02/03/04 metric, fixed-log, topology, file, and byte-accounting proof.

Repeated successful discovery and every retryable failure must leave metrics,
decision counters, LRU and ranks, descriptors, budgets, files, topology,
generation, and one-shot state unchanged. Apply success and terminal failure
must return separate before and after generation fields and safe recomputed
snapshots without echoing the request token.

## Preserved gates

The correction keeps TP-39-01 through TP-39-15, live model-backed tiers,
PowerShell 5 and 7 success and forced-failure coverage probes, the canonical
server probe and denominator, and the 80 percent changed-line requirement.
Production policy, public API, metrics, thresholds, reason taxonomy, and normal
transaction outcomes remain unchanged.

## Handoff

Part 43 and this correction record are ready for fresh independent Architect
re-review against design Parts 15 and 17 and implementation Parts 45-46. Manager
gate, code or script changes, QA execution, and Stage 39 closure remain blocked.
