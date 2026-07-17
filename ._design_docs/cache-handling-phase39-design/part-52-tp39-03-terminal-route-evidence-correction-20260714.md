# Part 52: TP-39-03 terminal route evidence correction

Date: 2026-07-14
Status: ARCHITECT CORRECTION; MANAGER GATE NEXT
Scope: D39-EXEC-18 midpoint and step-2 route assertions only

## Finding

D39-EXEC-25 proves that the corrected public workload reaches the natural
same-owner exact/checkpoint pair. It does not close the route assertion contract
in Part 43.

`_assert_coherent_terminal_fault()` currently checks the failed response,
fault name, preparation flags, generation order, one cold commit, and a
nonempty forest. The terminal proof does not expose the terminal entry,
branch, descriptor, cold-file, byte-map, decision, or later-work state. A route
PASS could therefore miss a checkpoint unlink, stale branch projection, extra
decision, later victim, duplicate sync, or retained checkpoint staging file.

The midpoint path also checks `checkpoint_attempted == false` without checking
`checkpoint_prepared == false`. The step-2 path checks preparation but does not
check staging cleanup or absence of classification, admission, publish, and
commit effects.

## Required terminal proof

Keep the D39-EXEC-17 control flow unchanged. Extend the guarded terminal proof
with one authenticated, redacted state block captured after the common
epilogue and after `tx_update()` returns. It must contain:

- entry ID, exact and checkpoint links, resident bytes, and target/draft flags;
- branch ID, both links, resident bytes, target/draft flags, and sync count;
- exact descriptor residency, immutable cold-file bytes, descriptor bytes, and
  byte-map bytes;
- checkpoint descriptor residency and resident component bytes;
- cold directory inventory, staging inventory, entry count, node count, LRU
  membership, branch-prune count, and later-victim count;
- decision and transaction tuple deltas from the pre-apply snapshot; and
- diagnostic and generation-advance deltas owned by checkpoint or later work.

The HMAC must bind this block with the existing records and generation fields.
Retrieval must return it byte-equivalent and keep the current generation check.
Do not add a new route, repair, sync, generation advance, or production metric.

## Exact fault assertions

Both controller and route nodes must compare pre-apply evidence with the
terminal block.

Midpoint must prove exact cold and committed once, checkpoint hot and neither
attempted nor prepared, one common sync, coherent entry and branch links and
bytes, one failed apply, one consumed retry, and no checkpoint or later-work
delta.

Step 2 must prove exact cold and committed once, checkpoint hot and prepared
once, checkpoint staging removed, no checkpoint classification, admission,
publish, commit, cold file, descriptor/link mutation, decision, diagnostic, or
later-work delta, plus the same common-sync and failed-request checks.

For both faults, require exactly one `commit/none` transaction delta for exact,
the exact retained-cold decision delta required by production, zero other
decision or transaction deltas, unchanged entry/node/LRU topology, no branch
prune, no success snapshot, strict
`common_sync_generation > exact_return_generation`, and no explicit or
duplicate guarded generation advance.

Add pure response-shape tests that fail when each required terminal field or
zero delta is removed or changed. Run controller tests before any model node.

## Gate

Manager may authorize this guarded evidence and assertion correction, one
seam-enabled controller/server build, and pure and controller tests. Fresh
Architect implementation review must pass before the two route faults run.
D39-EXEC-25 artifacts remain accepted and need no rerun. Default product build,
fixture changes, canonical TP-39-03, coverage, full QA, commit, and push remain
blocked.
