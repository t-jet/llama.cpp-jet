# Part 6: independent Architect implementation-plan re-review

Date: 2026-07-12
Verdict: REWORK REQUIRED

## Scope

Reviewed Parts 1, 4, and 5 against the approved Stage 39 design and current
cold-store and hybrid-controller construction paths.

## Finding closure

### F39-IPR-02: closed

Part 1 now defines final, staging, quarantine, logical, and physical bytes for
each transaction state. The equations consistently count incoming bytes once.
Exact-fit, one-byte-over, partial-victim, cleanup, restart, and overflow cases
derive from the table with checked arithmetic.

### F39-IPR-03: open

The recovery API now separates store inspection from controller apply, but its
record is insufficient for the promised startup apply. A fresh controller has
empty `per_id_map`, entry links, and hot records. `cold_descriptor_snapshot`
contains payload shape and checksums, not owning entry ID or payload kind. The
victim record contains only payload ID, size, and quarantine path. Therefore
`apply_recovered_commit()` cannot validate or reconstruct incoming ownership,
entry-to-payload links, victim descriptor tombstones, or their accounting after
a process restart. Calling it before reconciliation does not supply that state.

Correction: define the durable ownership and descriptor fields needed to apply
a committed manifest to a fresh controller, or explicitly define startup as
filesystem cleanup only and reconcile that policy with the approved recovery
contract. Give `apply_recovered_commit()` exact behavior for missing owners and
prove committed recovery with a destroy-and-reconstruct controller test, not a
same-controller retry.

Acceptance: every field consumed by startup apply has a durable source; a test
destroys the committing controller, constructs a new one, and proves exact
incoming ownership, victim tombstones, logical bytes, cleanup, and idempotence.

## Verdict and handoff

REWORK REQUIRED. F39-IPR-02 is closed; F39-IPR-03 remains open. Code and Manager
implementation-plan gate remain blocked. Developer must correct Part 1 and add
a correction record before another fresh Architect re-review.
