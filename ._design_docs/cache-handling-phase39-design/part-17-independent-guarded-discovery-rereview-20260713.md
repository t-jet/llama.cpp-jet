VERDICT: REWORK

# Part 17: independent guarded discovery re-review

Date: 2026-07-13
Scope: corrected design Part 15, implementation Parts 45-46, test-plan Part 43,
design Part 16 findings, and current production code

## Gate result

F39-GDR-01 through F39-GDR-03 are closed. The corrected design now separates
pure hot enumeration from the production metric wrapper, preserves the exact
Stage 39 transactional cold predicate before a separate integrity check, and
defines complete locked generation and token ownership.

The correction set is not ready for Manager gate. Test-plan Part 43 still
specifies the superseded apply-only request and old test map. Developer and QA
would receive two incompatible seam contracts.

## Re-review of Part 16 findings

| Finding | Result | Evidence |
| --- | --- | --- |
| F39-GDR-01 | CLOSED | Part 15 defines pure `enumerate_hot_policy_candidates_core()` and keeps the blocked-reference metric increment only in production `build_policy_candidates()`. Current code confirms why the split is required: `build_policy_candidates()` increments `n_eviction_payload_blocked_refs` while enumerating referenced entries at `server-cache-hybrid.cpp:4451-4469`. Discovery, validation, and snapshots are required to call only the pure core. |
| F39-GDR-02 | CLOSED | Part 15 uses cold residency plus incoming-owner exclusion, exactly matching Stage 39 transactional room-making at `server-cache-hybrid.cpp:4974-4988`. Kind, live owner, owner link, byte map, and store reference are separate seam integrity checks. Integrity failure is retryable and non-consuming, so it does not narrow production selection. |
| F39-GDR-03 | CLOSED | Part 15 supplies one process-local checked generation owner and a mutation matrix covering entries, descriptors, residency, forest slot references, completion, save/restore, recovery, rollback, budgets, and control state. It defines a 256-bit process nonce, HMAC-SHA-256 token, constant-time comparison, changed-then-restored invalidation, and separate before/after generations on terminal success or failure. Part 45 requires direct forest reference calls to move behind locked controller methods; current direct calls such as `server-context.cpp:5955-5958` confirm that implementation work is necessary. |

## Blocking finding

### F39-GDR-RR-01: Part 43 retains the superseded seam contract

Part 43 still requires one request with `hot_candidates` and `cold_victims`,
unique owner IDs across both arrays, and one global cold exact set. Corrected
Part 15 requires `discover`, snapshot generation and token binding, `apply`, and
a complete cold set for each incoming owner. It also permits one owner to hold
an exact blob and a checkpoint. The Part 43 rule would reject that valid state.

Part 43 also maps only the prior apply, security, terminal, and normal-pressure
tests. It does not bind the new discovery, stable repeat, counter purity,
integrity failure, changed-then-restored staleness, slot-reference drift, budget
drift, omitted/extra checkpoint, process-token binding, or before/after
generation cases to exact controller and route test names.

Correct Part 43 before Manager gate:

1. Replace the old apply-only schema and global cold-victim text with the
   Part 15 discover/apply, snapshot, and per-incoming cold-set contract.
2. Permit kind-distinct descriptors owned by one entry while keeping payload
   identities unique within each exact set.
3. Add exact controller and Python test names for every new Part 15 case.
4. Retain the prior compile-OFF, runtime-OFF, startup guard, token/schema,
   validation retry, idle race, redaction, terminal failure, successful normal
   `tx_update()`, TP-39-02/03/04, and production metric/log/accounting tests.
5. Require stable discovery on success and retryable failure to leave metrics,
   decision counters, LRU/ranks, descriptors, budgets, files, topology,
   generation, and one-shot state unchanged.

## Code and scope checks

- Current hot builder has the metric side effect Part 15 isolates.
- Current Stage 39 transaction selector has the cold predicate Part 15 copies.
- Current seam remains apply-only and uses narrowed exact-blob/live-owner
  validation at `server-cache-hybrid.cpp:5229-5426`; code is correctly blocked.
- Existing route and controller coverage is incomplete, as Parts 43-45 state.
  Planned evidence is not treated as executed evidence.
- Production policy, public API, thresholds, metrics, and normal outcomes remain
  unchanged by this documentation correction.

## Handoff

REWORK. Developer documentation owner must correct test-plan Part 43 and record
the change in the implementation tree. Fresh independent Architect re-review
follows. Manager correction gate, code changes, QA, and Stage 39 closure remain
blocked.
