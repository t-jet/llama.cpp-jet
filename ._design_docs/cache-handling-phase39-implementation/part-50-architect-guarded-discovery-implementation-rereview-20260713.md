VERDICT: REWORK

# Part 50: Architect guarded discovery implementation re-review

Date: 2026-07-13
Scope: D39-EXEC-03 implementation in Part 49 against design Part 15,
implementation Parts 39 and 45-48, test-plan Part 43, and Part 44 findings

## Verified implementation

- The obsolete apply-only route is gone. Strict tagged `discover` and `apply`
  parsing is compiled only with `LLAMA_STAGE39_LIVE_TEST_SEAM`.
- Hot enumeration is split into a pure core and the production-only blocked-ref
  metric wrapper at `server-cache-hybrid.cpp:4547-4597`.
- Production cold room-making and guarded snapshots use the same pure selector.
  Its predicate at `server-cache-hybrid.cpp:4600-4616` is exactly cold residency
  plus incoming-owner exclusion and includes checkpoint descriptors.
- Integrity validation is separate from selection. Discovery builds separate
  hot and per-incoming cold sets and does not call `tx_update()`.
- Apply revalidates generation, HMAC, exact arrays, incoming identity, and lower
  positive budgets while holding the cache lock. Admission serialization in
  `server-context.cpp:4458-4470` prevents completion dispatch during control.
- Responses use recomputed before/after inventories and explicit
  `before_generation` and `after_generation` fields.
- The ON Release controller executable passed during this review, including the
  eight currently registered guarded cases.

These points close Part 44 findings F39-LPIR-01 through F39-LPIR-03 only for the
implemented selector, discovery, and response subset.

## Blocking findings

### F39-GDIR-01: generation ownership is not implemented

Design Part 15 and Parts 45-46 require every inventory or eligibility mutation
to advance one monotonic owner in the same locked critical section. Current
production save, restore, completion, recovery, cleanup, descriptor, entry,
residency, rank, and topology writes do not call
`advance_cache_generation_locked()`. The direct calls are limited to guarded
apply and a few debug budget or slot-reference helpers.

`stage39_sync_generation_to_state_locked()` at
`server-cache-hybrid.cpp:5456-5482` is a control-time digest fallback. It omits
required state families and cannot detect a mutation followed by restoration to
the same digest. This does not meet the changed-then-restored or complete
mutation-owner contract.

Required correction: route every Part 15 mutation family through the locked
generation owner. Remove the digest fallback as freshness authority. Add the
named mutation-matrix test with changed-then-restored, recovery, rollback,
completion, entry, descriptor, rank, forest, slot-reference, and budget rows.

### F39-GDIR-02: apply does not perform required rank and order setup

Part 39 requires reindexing hot owners and setting controlled rank fields.
Design Part 15 requires apply to perform setup rank, order, and budget mutations.
The request type has no desired order or rank fields distinct from the snapshot,
and `stage39_live_pressure_control()` at
`server-cache-hybrid.cpp:5542-5553` changes only consumed state and two budgets
before `tx_update()`.

The driver copies discovered arrays unchanged. It cannot create TP-39-02 equal
cold ranks or its payload-ID tie-break setup. Required correction: add strict
desired setup fields, validate them before consumption, apply them through the
generation owner, and restore them on pre-transaction failure.

### F39-GDIR-03: required controller and route contracts are absent

Test-plan Part 43 names 15 guarded controller cases. Seven names are absent,
including integrity retry, full mutation matrix, idle-dispatch race, terminal
failure, and normal `tx_update()` success. The three TP-39-02/03/04 controller
tests from Part 39 are also absent. Several existing cases cover only one field
or one counter rather than the required state snapshot.

`tools/server/tests/unit/test_stage39_live_pressure.py` does not exist. Compile
OFF, runtime OFF, startup guards, loopback/token rejection, strict schema,
process binding, redaction, retry, idle race, terminal response, and HTTP success
therefore lack their approved executable route evidence.

Required correction: implement and run every exact controller and Python route
case named by Part 43. Test bodies must assert the listed contract, not only
register the expected name.

### F39-GDIR-04: driver assertions do not prove TP-39-02 through TP-39-04

`Assert-Tp3902`, `Assert-Tp3903`, and `Assert-Tp3904` at
`stage39-two-layer-pressure.ps1:112-114` only delegate to common response-shape
checks. They do not assert ordered victims, mixed-kind completeness, exact
decision and transaction deltas, fixed logs, measured size predicates,
tombstones, byte/file accounting, retained topology, zero pruning, or atomic
pair outcome required by Parts 39 and 43.

Required correction: implement the row-specific assertions and preserve the
named artifacts. Run one model-backed smoke through normal admission, discovery,
apply, and production `tx_update()` before returning for review.

### F39-GDIR-05: nonce source does not meet the cryptographic contract

Design Part 15 requires a platform cryptographic random source for the 256-bit
process nonce. Construction at `server-cache-hybrid.cpp:424-428` fills it from
`std::random_device`, whose cryptographic strength is not guaranteed by C++.

Required correction: use an explicit supported OS cryptographic RNG and fail
closed if nonce generation fails. Keep nonce serialization and logging banned.

## Evidence ownership

- Python route suite and complete controller mutation matrix are blocking
  implementation-review evidence because they verify the guarded interface and
  its security and atomicity contracts.
- Model-backed TP-39-02/03/04 final row verdicts remain QA-owned. The approved
  implementation gate still requires one model-backed guarded smoke and working
  row-specific driver assertions; those are blocking here.
- The four canonical PowerShell 5/7 coverage success and forced-failure probes,
  real artifacts, and 80 percent result are required by Parts 39 and 45 before
  QA handoff. Their absence is blocking implementation review. QA must rerun
  coverage for final Stage 39 closure.

## Handoff

REWORK. Next owner: Developer for F39-GDIR-01 through F39-GDIR-05 and the exact
evidence commands. Then return to a fresh Architect implementation re-review.
Manager gate and QA remain blocked.
