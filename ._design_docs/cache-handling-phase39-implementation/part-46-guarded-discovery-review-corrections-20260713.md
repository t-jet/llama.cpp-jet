# Part 46: guarded discovery review corrections

Date: 2026-07-13
Status: READY FOR FRESH INDEPENDENT ARCHITECT RE-REVIEW
Scope: documentation correction only; no code or test execution

## Inputs

- Design Part 15 guarded discovery correction
- Design Part 16 independent review
- Implementation Parts 43-45
- Current hot selection and cold room-making code

## F39-GDR-01: corrected

Design Part 15 and implementation Part 45 now require a pure hot enumeration
core. It returns production candidates and a blocked-reference count without
changing state. Production `build_policy_candidates()` is the only wrapper that
adds that count to `n_eviction_payload_blocked_refs`. Discovery, apply
validation, and before/after snapshot building call only the pure core.

Required tests compare metrics, decision counters, LRU/ranks, generation,
descriptors, budgets, files, topology, and one-shot state across repeated
successful discovery and retryable discovery failures.

## F39-GDR-02: corrected

The cold candidate predicate now matches current production exactly:

```text
residency == cold && owner_entry_id != incoming_owner_entry_id
```

The inventory includes every selected descriptor. It does not add payload-kind,
live-owner, kind-specific owner-link, byte-map, or store-reference eligibility.
The guarded seam validates those integrity facts after enumeration. Integrity
failure is retryable and non-consuming and cannot alter production selection.

Healthy-state coverage requires complete mixed exact-blob and checkpoint sets
for each incoming owner, with omitted and extra row rejection. Corruption cases
cover dangling owners, wrong kind-specific links, identity mismatch, and cold
byte-accounting mismatch without policy mutation.

## F39-GDR-03: corrected

One process-local monotonic generation owner now covers every inventory or
eligibility mutation under `cache_state_mutex_`:

- entry creation, removal, replacement, ownership, protection, sizes, and
  LRU/prefix order;
- descriptor and payload-record creation, replacement, removal, identity,
  owner, kind, pair state, sizes, metadata, and cold-byte accounting;
- residency transitions and cold-rank updates;
- forest node/link/protection/order changes and every slot-reference acquire or
  release;
- demotion/promotion dispatch and completion application;
- save, restore, admission, validation-rank, eviction, and cleanup mutations;
- startup recovery, committed-victim application, rollback restoration, and
  accounting repair;
- runtime/test budget changes, guarded consumption, setup writes, and setup
  rollback.

Changed-then-restored state advances again. Generation never rewinds. Discovery
returns `snapshot_generation` and a keyed token over the process nonce,
generation, canonical inventories, and budgets. Apply requires an exact current
generation and constant-time token match before consumption. Its response uses
`before_generation` and recomputed `after_generation`; it has no singular
generation field.

Tests cover stable repeated discovery, changed-then-restored staleness, slot-ref
drift, budget drift, consumed/setup increments, recovery and rollback
increments, token process binding and redaction, and after-state generation.

## Evidence plan retained

The correction does not reduce Part 45 evidence. Developer still owes guarded
controller tests, named Python route tests, TP-39-02/03/04 driver flow,
model-backed smoke, OFF/ON builds, PowerShell 5/7 parser and coverage probes,
forced merge failure, preserved artifacts, and the 80 percent coverage verdict
after Manager authorization.

## Handoff

F39-GDR-01 through F39-GDR-03 are corrected in the durable design and
implementation plan. Fresh independent Architect re-review is next. Manager
correction gate, code changes, tests, QA execution, and closure remain blocked.
