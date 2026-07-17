# Part 45: guarded discovery correction plan

Date: 2026-07-13
Status: CORRECTED - READY FOR FRESH INDEPENDENT ARCHITECT RE-REVIEW
Authority: design Part 15 and implementation review Part 44

> discovery correction provisionally accepted for design review only; code changes blocked until Manager gate after independent PASS.

## Planned correction

1. Extend guarded request parsing with strict `discover` and `apply` tags. Keep
   the existing route, token comparison, startup guards, and redaction.
2. Split hot selection into pure
   `enumerate_hot_policy_candidates_core()` and production
   `build_policy_candidates()`. Pure core returns candidates plus blocked-ref
   count. Production wrapper alone increments
   `n_eviction_payload_blocked_refs`; discovery, validation, and snapshots call
   pure core and never mutate metrics.
3. Add one pure cold core used by production room-making and seam snapshots.
   Its complete predicate is exactly cold residency plus incoming-owner
   exclusion. Do not filter by kind, live owner, owner link, byte map, or store
   reference. Run guarded descriptor/owner integrity checks after enumeration;
   fail retryably without consuming or changing production policy.
4. Add process-local generation and opaque snapshot token support. Use one
   checked generation owner under `cache_state_mutex_` for entry/index,
   descriptor/record, residency/rank, forest slot-reference/topology, completion
   dispatch/apply, save/restore, recovery/cleanup, rollback, budget, and control
   setup mutations. Route direct forest slot-reference calls through locked
   controller methods.
5. Generate one 256-bit process nonce from a cryptographic source. Recompute a
   keyed SHA-256 token from nonce, generation, canonical inventories, and budgets
   under lock. Compare in constant time. Never serialize or log the nonce.
6. Add non-mutating, non-consuming discovery under admission then cache lock.
   Return hot inventory and per-incoming-owner cold sets. Stable discovery keeps
   generation/token stable; successful and failed discovery leave all counters,
   LRU state, descriptors, files, budgets, topology, generation, and one-shot
   state unchanged.
7. Rework apply to bind generation/token, incoming identity, expected current
   orders/ranks, and exact arrays. Validate all state before atomically consuming
   and starting setup mutation. Record `before_generation`; consumption and each
   setup mutation advance generation. Rollback restores through the same owner
   and advances again. Preserve Part 11 recovery ownership after `tx_update()`.
8. Rebuild separate before/after hot and cold snapshots. Recompute after-state
   eligibility from live production predicates and return
   `before_generation` plus `after_generation`, never one ambiguous generation.
9. Add named controller and Python route tests from design Part 15, including
   counter purity, malformed descriptor/owner failure, mixed-kind completeness,
   changed-then-restored staleness, slot-reference and budget drift, token
   redaction, and after-generation cases. Then finish Part 39 tests.
10. Update `stage39-two-layer-pressure.ps1`: discover after idle, persist
    `control-discover-request.json` and `control-discover-response.json`, build
    exact apply from that snapshot, persist `control-apply-request.json` and
    `control-apply-response.json`, and run TP-39-02/03/04 assertions.
11. Run OFF/ON builds, Release controller, route suite, model-backed smoke, both
    shell parser/self-tests, and Part 39 PowerShell 5/7 coverage success and
    forced-failure probes. Preserve exits, logs, trees, and 80 percent result.

## Acceptance

- Discovery changes no controller state and never consumes one-shot authority.
- Discovery uses no production metric-recording wrapper.
- Apply rejects stale generation/token, owner or residency drift, rank drift,
  missing/extra hot rows, and missing/extra exact or checkpoint cold rows before
  consumption.
- Cold inventory contains every descriptor selected by cold residency plus
  incoming-owner exclusion. Separate integrity failure does not narrow policy.
- Consumption and first setup mutation share one locked critical section.
- Every inventory or eligibility mutation family has one locked generation
  owner. Changed-then-restored state, slot-ref drift, budget drift, consumption,
  setup, recovery, and rollback all invalidate the old snapshot.
- Before and after contain separate current hot/cold sets; after eligibility is
  recomputed and both generation values are explicit.
- Route and controller cases use their exact names from Parts 15 and 39.
- Driver proves discover/apply flow for TP-39-02/03/04 without guessed IDs.
- Normal production path, guards, privacy, metrics, thresholds, and outcomes do
  not change.

## Gate

No code, test, or script change is authorized by this plan. Part 46 records the
F39-GDR-01 through F39-GDR-03 corrections. Fresh independent Architect re-review
is next. Manager must issue a new correction gate before Developer work. QA
remains blocked.
