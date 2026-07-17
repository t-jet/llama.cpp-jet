# Part 1: contract and invariants

## Terms

- Hot filled: hot budgeting is enabled and admitting or retaining the selected
  payload pair would leave hot resident bytes above the configured hot budget
  after eligible lower-ranked hot payloads have been considered.
- Cold filled: cold storage is configured, its budget is enabled, and an exact
  room-making calculation cannot admit the selected serialized payload pair
  without exceeding the cold budget after eligible cold victims are removed.
- Disabled layer: no usable capacity. It is unavailable, not filled. Cold may
  be disabled while hot remains active. `--cache-ram 0` disables prompt cache
  storage as a whole, so no hybrid controller or cold-only mode exists.
- Payload eviction: descriptor becomes non-restorable and bytes are absent from
  hot and cold storage. Branch metadata may remain.
- Entry removal: deletion of lookup entry or branch node. This stage does not
  authorize it under payload pressure.
- Branch pruning: metadata-budget operation subject to ADR-009 ownership and
  descendant-reachability rules.

"Filled" is a capacity result, not a transient I/O error, corruption result,
missing directory, permission failure, or serialization failure.

## Admission and demotion

1. Admit a new payload hot when it fits.
2. On hot pressure, rank hot victims with existing LRU/protection policy.
3. For each selected hot victim, attempt atomic demotion before payload eviction.
4. Cold room-making may evict cold payload bytes only under cold pressure. It
   uses existing reuse ranking and leaves each descriptor record as an evicted
   tombstone; lookup entries and branch owners remain.
5. After successful cold admission, release hot bytes and keep descriptor and
   lookup visibility.
6. Evict selected payload only when hot remains filled and cold admission returns
   `capacity_exhausted` after room-making.
7. A payload larger than either positive layer budget is a capacity-exhausted
   case for that layer. If it fits neither, eviction is allowed with an explicit
   `oversized_both` reason.

Protected roots influence victim order but do not bypass either byte budget.
Exact-blob and checkpoint descriptors are independently ranked, while each
descriptor's target/draft pair moves or evicts atomically.

## Invariants

- I-39-01: no capacity-driven payload eviction while either enabled layer can
  retain the complete payload pair.
- I-39-02: hot pressure never deletes branch metadata.
- I-39-03: cold room-making deletes only exclusive payload bytes and descriptors;
  retained descendants and branch owners remain valid.
- I-39-04: demotion commits descriptor state, cold bytes, and hot-byte release as
  one transaction; failure leaves the pre-transaction hot payload restorable.
- I-39-05: capacity accounting uses actual hot resident bytes and actual cold
  bytes written or stored, with overflow-safe arithmetic.
- I-39-06: legacy mode and restore correctness remain unchanged.
- I-39-07: cold capacity decisions use the exact byte length of an immutable,
  validated staged object, including pair data and all format overhead.
- I-39-08: a cold victim is never irreversibly removed before incoming-object,
  descriptor, accounting, and victim-state changes have a recoverable commit.

## Traceability

| Contract | Requirements |
| --- | --- |
| Byte-based layer pressure | R21, R57a, R57c |
| Demotion before eviction | R38, R38a, R57b |
| Safe cold cleanup | R38b, R38c, R55a |
| Pair atomicity and transactions | R37, Stage 25 I-25-01 to I-25-03 |
| Event visibility | R61, R65, R66, R66a, R67 |

R57d and R57e remain outside Stage 39: this stage does not add a combined budget
or change startup validation policy.
