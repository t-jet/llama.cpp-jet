# Part 2: transaction and failure design

## Transaction flow

All steps run under the existing cache-state transaction.

1. Calculate hot pressure from current resident bytes and requested pair size.
2. Select victim using current global LRU and protected-root ordering.
3. `cold_store.prepare(payload_pair)` serializes target and optional draft bytes,
   header, lengths, checksums, alignment, and all other format overhead into one
   immutable file in the cold root's staging directory. It returns an owning
   `prepared_cold_object` with staging path, payload ID, pair state, checksum,
   and exact `uint64_t serialized_bytes` from the closed file length. The file
   is not restore-visible and has no descriptor reference.
4. Validate the staged object, then compute the cold-admission plan with checked
   `uint64_t` addition. The plan uses `serialized_bytes`, deterministic victims,
   ownership checks, and post-commit totals. Overflow returns `size_overflow`,
   retains hot bytes, and deletes the staged object.
5. For a fitting plan, rename each victim file to a unique transaction quarantine
   name in the same cold directory. Record original/quarantine names and exact
   bytes in a transaction manifest. A rename failure reverses earlier renames.
6. Rename the prepared object to its final name, validate it there, apply incoming
   and victim descriptor states plus accounting from the precomputed plan, then
   release hot bytes. Descriptor records for victims become evicted tombstones.
   This descriptor/accounting apply is non-fallible after full validation; an
   invariant failure before apply triggers rollback.
7. Mark the manifest committed with atomic replace. Only then unlink quarantined
   victims and the manifest. Cleanup failure leaves quarantine bytes accounted
   against the cold budget until recovery removes them.
8. If planning returns `capacity_exhausted`, mark payload evicted only after
   rechecking hot pressure and cold capacity inside the same transaction.

Cold room-making must not evict the payload being demoted, its paired data, or a
payload with a live branch reference that forbids deletion. If no eligible cold
victim can free enough bytes, cold is filled for this admission.

## Layer cases

| Case | Required result |
| --- | --- |
| Both positive and enabled | Two-layer retention contract applies. |
| Cold disabled or unconfigured | Keep current hot-only semantics; record bypass. |
| Hot budget unlimited | No hot-capacity eviction or demotion is required. |
| Hot budget zero | `--cache-ram 0` disables prompt cache storage. No controller, cold admission, payload eviction, or Stage 39 guarantee applies, even with a cold path. |
| Cold budget zero | Treat cold as disabled, not filled; record bypass. |
| Payload exceeds both budgets | Capacity eviction allowed with `oversized_both`. |
| Cold I/O or integrity error | Preserve hot payload; do not classify as both-filled. |
| Victim quarantine error | Roll back; preserve hot payload and prior cold owners. |
| Post-commit quarantine unlink error | Keep committed state; count quarantine bytes; recovery retries cleanup. |
| Missing/corrupt existing cold victim | Quarantine or existing integrity handling; do not use uncertain reclaimed bytes in admission math. |

## Rollback and crash recovery

Before commit-marker durability, recovery restores every quarantined victim to
its original name, removes an incoming final file not referenced by committed
descriptor state, removes staging data, and restores the manifest's pre-state
accounting. Runtime rollback follows reverse mutation order: descriptor/accounting
snapshot (if not yet applied), incoming final-to-staging rename, victim quarantine
renames in reverse order, then staged-object deletion. Hot bytes remain resident.

After commit-marker durability, recovery completes the commit: incoming final
file and descriptor state are authoritative; quarantined victims are unlinked;
their bytes remain charged until unlink succeeds. Recovery is idempotent. It
runs before cold files become restore-visible. Unknown or corrupt manifests
disable cold mutation and preserve all files for integrity handling.

Failure injection is required after staging, each victim rename, incoming rename,
final validation, descriptor/accounting apply, commit-marker replace, and each
victim unlink. Multi-victim tests use equal-rank victims and payload ID as the
stable tie-breaker, then fail every victim position.

## Compatibility and rollback

No new public CLI or endpoint field is required. Existing hot and cold budgets
remain authoritative. Implementation must remove the current shortcut that skips
demotion solely because hot bytes already exceed the hot budget.

`prepared_cold_object` owns cleanup until commit-marker durability. Every return,
exception, capacity result, validation error, and overflow destroys or transfers
that ownership. Staging and quarantine names are never restore-visible.

Rollback is code-local: reverting Stage 39 restores prior hot-pressure behavior
without descriptor migration or on-disk format changes.
