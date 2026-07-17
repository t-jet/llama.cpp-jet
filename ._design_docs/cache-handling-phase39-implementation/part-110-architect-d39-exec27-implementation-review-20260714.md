# Part 110: Architect D39-EXEC-27 implementation review

Date: 2026-07-14
Verdict: REWORK; FRESH SEAM BUILD EVIDENCE REQUIRED
Scope: D39-EXEC-27 observed forbidden-effect correction

## Review result

The seven corrected forbidden-effect fields are observational. Checkpoint
classification, publish, committed completion, cold-file creation, descriptor
mutation, link mutation, and explicit guarded generation advances each use a
monotonic counter sampled before apply and after the common epilogue. Cold-file,
descriptor, and link results also compare full baseline and terminal state and
take the nonzero event or state delta. A changed-then-restored effect therefore
cannot disappear.

Descriptor comparison covers payload and owner identity, kind, residency,
store reference, target and draft sizes and checksums, resident bytes, and pair
state. Link comparison covers the owner entry's checkpoint link. Cold-file
comparison covers the expected checkpoint object identity, existence, and
bytes. Counter increments sit at the existing classification, publish,
commit, descriptor-write, and link-write boundaries.

Normal `STAGE39_CACHE_MUTATED()` calls use
`advance_cache_generation_locked(false)`. Guarded setup and explicit calls use
the default `true` argument. The terminal delta therefore distinguishes an
unwanted explicit advance from normal production-owned generation changes.
The negative probe advances once after baseline and updates the expected
generation, so it tests the delta without breaking the generation chain.

All observation state and probes remain under
`LLAMA_STAGE39_LIVE_TEST_SEAM`. No product route, public metric, selector,
fixture, budget, or default-build behavior changed.

## Consumer and authentication review

The controller forced-nonzero probe covers all seven fields and proves the
shared terminal predicate rejects each value. Midpoint and step-2 controller
tests use that same predicate and require equal before/after state plus zero
event counts for the restorable effects.

The route helper requires the same before/after and event relations, all seven
zero deltas, the complete terminal matrix, and byte-equivalent authenticated
retrieval. Pure tests remove every observation field, remove every descriptor
subfield, and change every required zero. The terminal HMAC covers the complete
terminal body before `terminal_hmac` is added. Retrieval binds process,
session, run, supplied HMAC, current final generation, and constant-time HMAC
recalculation. Controller tests also prove tamper rejection.

The focused results themselves pass: one incremental seam build linked
controller and server targets, 104 pure negatives passed, and the complete
controller suite passed with the seven forced probes and both faults. The three
C4477 warnings are pre-existing and outside this correction.

## Blocking finding F39-OBS-01

The recorded build is not fresh against the current source metadata.
`server-cache-hybrid.cpp` was written at 02:50:34, after
`server-cache-hybrid.obj` at 02:48:19 and `llama-server.exe` at 02:48:28.
Developer reports a guarded commit-counter move followed by an exact reverse
patch, and current placement is correct immediately after successful
`mark_committed()`. There is no durable pre-edit source hash or compiler-input
hash that proves byte identity with the built source. The timestamp therefore
cannot be waived at this gate.

## Handoff

No design correction is needed. Manager may authorize one incremental rebuild
of `test-cache-controller` and `llama-server` in `build-stage39-seam-on`, then
one complete controller-suite run. Record source, object, and binary hashes or
freshness evidence with the command results. The 104 pure negatives need no
rerun unless Python changes. Stop on failure and request fresh Architect
re-review after PASS.

Both route nodes remain blocked. After F39-OBS-01 closes, the route contract in
Part 107 remains unchanged: midpoint then step 2 in isolated fresh processes,
accepted D39-EXEC-25 fixture, hashes, budgets, caps, and artifacts, with exact
acceptance `2 PASS / 0 FAIL / 0 BLOCKED`. Canonical TP-39-03, default build,
coverage, full QA, commit, push, PR, and reviewer responses remain blocked.
Next owner is Manager.
