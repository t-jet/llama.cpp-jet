# Part 107: Architect D39-EXEC-26 implementation review

Date: 2026-07-14
Verdict: REWORK; DESIGN PART 53 REQUIRED
Scope: D39-EXEC-26 only

## Conforming work

Terminal capture runs after `tx_update()` and the common branch-sync epilogue.
It records real entry and branch links, resident flags and bytes, descriptor
residency and sizes, cold and staging inventories, topology, metric tuples,
diagnostics, generations, and sync count. The HMAC covers the terminal block
with the prepared records and ordered generations. Retrieval checks process,
session, run, supplied HMAC, current final generation, and a constant-time HMAC
recalculation before returning the stored body byte-equivalent.

Controller and route assertions distinguish midpoint from step 2. Midpoint
requires neither checkpoint attempt nor preparation. Step 2 requires both and
requires empty staging. Both require exact cold, checkpoint hot, one
`retained_cold/cold_room` decision, one `commit/none` transaction, one common
sync, strict sync generation order, stable entry/node/LRU topology, no branch
prune or later victim, failed apply, no success token, consumed retry,
authenticated retrieval, and tamper rejection.

Recorded evidence stays inside the Manager gate: 70 pure negative cases pass,
the seam controller and server targets build, and both controller faults pass.
No model, default build, canonical run, coverage, commit, or push is recorded.
The implementation part is LF-only, ASCII, and below 300 lines.

## Blocking finding F39-TERM-01

`stage39_finalize_prepared_locked()` writes literal zero for checkpoint
classification, publish, commit, cold-file, descriptor-mutation,
link-mutation, and explicit-generation-advance deltas. Neither the baseline nor
terminal capture observes these events. Tests assert the generated constants,
so they cannot detect the forbidden production effects named by Design Part
52 and Manager Part 105.

Some adjacent evidence is real: checkpoint admission uses a counter,
transaction and decision tuples are baseline deltas, diagnostics are map
deltas, inventory is read from disk, topology is compared, and later work uses
generation and eviction deltas. Those do not make the seven literal fields
observational.

Pure tests remove every terminal-state field and mutate the existing zero
fields, but this only validates response assertion shape. It does not close
F39-TERM-01. The controller assertions also consume the same literal fields.

Design Part 53 requires guarded event observations and complete pre/terminal
checkpoint descriptor and link comparison. It preserves product behavior and
the accepted fixture.

## Verdict and handoff

D39-EXEC-26 is REWORK. The two route faults are not authorized. Next owner is
Manager for one bounded Part 53 correction gate. After the guarded observation
fix, reuse the seam build and run pure negatives plus both controller faults,
then request fresh Architect review.

If that review passes, the exact next execution gate is two isolated model
nodes in sequence: midpoint first, step 2 second, each in a fresh process using
the accepted D39-EXEC-25 MTP fixture, request hashes, budgets, trace selector,
and existing route-helper caps. Each node must preserve its full artifact
bundle, pass with no skip, and satisfy acceptance `2 PASS / 0 FAIL / 0 BLOCKED`.
No new build is needed after a passing review unless guarded C++ changes after
the reviewed build. Canonical TP-39-03, coverage, full QA, commit, and push stay
blocked until Manager opens their later gates.
