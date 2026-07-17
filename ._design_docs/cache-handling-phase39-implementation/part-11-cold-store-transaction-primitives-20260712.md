# Part 11: cold-store transaction primitives

Date: 2026-07-12
Status: PARTIAL

## Scope

This tranche implements the disk-side Stage 39 transaction primitives. It does
not integrate cold admission planning, controller state reconstruction,
decision metrics, or the full failure-boundary matrix. Stage 39 remains open.

## Implementation

`server-cache-store-cold.h` now defines the approved prepared-object,
transaction manifest, recovery, victim, owner, descriptor, and cleanup records.
The store exposes `prepare`, `validate_prepared`, `quarantine`, `publish`,
`write_manifest`, `mark_committed`, `cleanup`, and `recover_transactions`.

`server-cache-store-cold.cpp` writes one closed, exact-size staging object and
validates its header, declared lengths, exact file length, and payload
checksums before publish. Victims move to same-root quarantine paths. Manifest
replacement flushes file data before rename. POSIX builds fsync the cold root
after namespace changes. Windows flushes file handles; Windows has no direct
directory-fsync equivalent.

Manifest recovery checks enum bounds, record counts, checked victim sums, and
the exact logical-byte equation. Pre-commit replay removes incoming work and
restores quarantined victims. Committed records are returned unchanged for the
controller-owned reconstruction pass. Cleanup and replay are idempotent.

The implementation uses a versioned binary manifest instead of a text format.
The approved plan fixed record content and behavior, not an on-disk encoding.
All approved recovery fields are stored.

## Tests and evidence

`test_stage39_cold_store_transaction_primitives` covers exact prepared size,
staging invisibility, validation, publish, repeated quarantine, manifest commit,
committed recovery contents, cleanup, and replay after cleanup.

- Release `test-cache-controller` build: PASS.
- Full `build/bin/Release/test-cache-controller.exe`: PASS.
- `git diff --check`: PASS.

## Remaining work

- Wire prepare, plan, and commit through the hybrid controller.
- Apply fresh-controller committed reconstruction and claimed-path handling.
- Add pre-commit and post-commit restart cases for every persisted boundary.
- Add failure injection, cleanup-debt blocking, metrics, logs, live tests, and
  focused coverage evidence.
