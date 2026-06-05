# Phase 4 Design: LRU Eviction Policy with Protected Roots - Part 2: Policy and interfaces

Source: [../cache-handling-phase4-design.md](../cache-handling-phase4-design.md)

## Component boundary

Phase 4 introduces an internal policy component named `server_cache_policy_lru`. The implementation can place it in dedicated server cache policy files, but the design contract matters more than the final filenames:

- the hybrid cache controller owns entries, payload bytes, indexes, and restore logic
- the policy owns eviction ordering and budget decisions
- the metrics/export layer reads policy outcomes through cache stats, not by inspecting policy internals

The policy must not serialize state, restore state, parse HTTP metadata, or decide namespace compatibility.

## Policy inputs

The controller passes policy candidates with these fields:

| Field | Purpose |
| --- | --- |
| entry id or stable iterator handle | lets the controller remove the selected entry |
| namespace id | used only for diagnostics and future fairness work |
| resident payload bytes | byte pressure input for `--cache-ram` |
| token count | diagnostic context |
| last use sequence | primary LRU ordering key |
| protected-root state | retention weighting input |
| target-present and draft-present flags | diagnostic and invariant checks |

The policy may also receive aggregate state:

- configured hot payload byte budget
- current resident hot payload bytes
- incoming entry resident bytes when evaluating admission
- current protected and unprotected byte totals

## Policy outputs

The policy returns an eviction plan. A plan contains:

- zero or more entries to evict
- the reason for each eviction: `over_budget`, `admission_retry`, or `protected_budget_pressure`
- whether protected entries were considered
- whether the budget remained unsatisfied after all legal evictions

The controller executes the plan. Removal from storage, prefix indexes, LRU indexes, and stats remains a controller responsibility.

## Recency model

LRU ordering must use a deterministic recency key. A monotonic `uint64_t use_sequence` is preferred over wall-clock time because tests can assert exact ordering without sleeping.

The controller increments the sequence when:

- a new entry is admitted
- an existing equivalent entry is refreshed during save
- an entry is successfully restored

Failed restore attempts must not refresh recency. A candidate that cannot be restored should not become harder to evict.

## Byte accounting

The hot payload budget is measured in resident serialized payload bytes:

```text
resident_payload_bytes = target_state_bytes + draft_state_bytes
```

Entry metadata, token vectors, indexes, and prepared-prompt metadata are not part of the Phase 4 hot payload budget. They remain visible through stats where useful, but Stage 8 is the first stage that defines branch-metadata budget enforcement.

For compatibility with existing stats, the implementation may keep a broader `size_bytes` field. If it does, Phase 4 must also expose or internally track `resident_payload_bytes` so eviction decisions are not tied to incidental metadata overhead.

## Admission and eviction flow

On save:

1. Build the cache entry and compute its resident payload bytes.
2. Reject admission with a warning if the entry has no target payload or violates target/draft pairing invariants.
3. If the entry alone exceeds `--cache-ram`, reject the save unless the configured budget is unlimited.
4. Add or refresh the entry.
5. Ask the policy for an eviction plan until resident bytes are within budget or no legal plan remains.

On restore:

1. Restore target and draft state as one logical payload.
2. Refresh usage only after successful restore.
3. Leave the entry resident and eligible for later eviction.

## Pluggability

The policy interface must avoid LRU-specific names in the controller boundary. The first implementation can instantiate only LRU, but the controller should depend on a small policy contract that can later support SLRU or 2Q.

Phase 4 intentionally does not add `--cache-eviction-policy`. The Stage 4 architecture says to keep policy selection internal while LRU is the only implemented policy. This is a temporary exception to long-term requirement R20a and is recorded in the review gate.

