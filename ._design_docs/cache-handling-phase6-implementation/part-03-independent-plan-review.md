# Phase 6 implementation plan - Part 3: Independent plan review

Source: [../cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)

## Verdict: REWORK

Date: May 30, 2026
Reviewer: Architect (independent)
Scope: Implementation plan Parts 1 and 2 (Steps 1-12, NB resolutions, store_ref decision)

One blocking finding. The dependency graph for Steps 6 and 7 is incorrect.
Four non-blocking observations.

---

## Blocking findings

### BF-1: Steps 6 and 7 are missing a dependency on Step 8

Steps 6 and 7 each add methods to `hybrid_cache_controller` that reference two member variables
that do not yet exist at the point those steps would be implemented:

- Step 6 calls `cold_store.is_configured()` and `worker.enqueue_demotion()`.
- Step 7 calls `worker.enqueue_promotion()`.

Both `cold_store` (`server_cache_store_cold`) and `io_worker` (`server_cache_io_worker`) are
declared as private members of `hybrid_cache_controller` in Step 8, not before. Step 6 lists
dependencies 1, 2, 3, 5. Step 7 lists dependencies 1, 4, 5, 6. Neither lists Step 8.

A developer following the dependency graph may implement Step 6 immediately after Step 5. The
code would reference undeclared members and fail to compile. Step 7 inherits the same gap via
Step 6.

Required correction: add Step 8 to the dependency list of Step 6. Step 7's dependency on Step 6
transitively covers Step 8 once Step 6 is corrected, but the developer plan should make this
explicit. Alternatively, renumber Step 8 to precede Step 6 in the ordered step list and adjust
all dependency references accordingly.

The fix does not require any code or design changes. Only the dependency lines in Part 1 and
Part 2 need updating.

---

## Verified items

Each checkpoint from the review scope is listed below.

**1. Design baseline traceability**
Part 1 explicitly references the independent design review in Part 8 (verdict: PASS) and the
manager design gate in Part 9 (verdict: PASS, date May 30, 2026). Traceability is correct.

**2. Completeness**
All six Stage 6 exit criteria from the architecture document and all deliverables in the Stage 6
section of `cache-handling-architecture/part-05` are covered by at least one step:
`server_cache_store_cold` (Steps 2-4), atomic write/rename (Step 3), `server_cache_io_worker`
(Step 5), demotion/promotion protocols (Steps 6-7), startup configuration and validation (Steps
8-9), metrics (Step 10), test hooks (Step 11), documentation (Step 12).

**3. Step quality**
All twelve steps carry a goal, affected files, a change description, an acceptance test, and a
dependency list. No step is missing a required field.

**4. NB-1 through NB-5 resolutions**
Each observation from the design review is resolved with a concrete action:

- NB-1 (transient states): Step 1 adds `demoting` and `promoting` enum values and transition
  table.
- NB-2 (queue-full revert): Steps 6 and 7 pin the immediate revert before returning.
- NB-3 (cold_ref_for removal): Step 2 omits the operation and documents the removal.
- NB-4 (completion model): result-queue model selected in NB-4 resolution; documented in Step 5.
- NB-5 (hot-byte release timing): pinned to Step 6 completion callback success result.

**5. store_ref schema decision**
Stage 5 code confirms `payload_store_ref` is `struct { uint64_t id = 0; }` - an opaque uint64
handle. No concrete pointer type is used. The decision not to increment `format_version` is
technically sound. The `id` field can carry a cold-ref registry key under `residency_state ==
cold` without any layout change.

**6. Step ordering (excluding BF-1)**
With the correction in BF-1 applied, all other dependency chains are consistent. Steps 1-5 form
a clean forward chain. Steps 9, 10, 11 correctly depend on the steps that produce their required
artifacts. Step 12 depends on all prior steps.

**7. Cold file format coverage**
Step 2 declares `cold_store_header` with all ten required fields: `magic`, `format_version`,
`checksum_algorithm`, `payload_id`, `pair_state`, `target_size_bytes`, `draft_size_bytes`,
`target_checksum`, `draft_checksum`, `header_checksum`. Matches design Part 2 table exactly.

**8. Target/draft pairing**
Step 6 validates that both sides of a `target_and_draft` descriptor are present before enqueueing
demotion. Step 7 acceptance test confirms that draft-side promotion failure leaves the descriptor
in `evicted` state, not partially hot. Pair demotion and promotion as a unit is explicitly covered.

**9. Startup validation**
Step 9 covers four of the five checks in design Part 5 startup validation table: root path
non-empty, exists as directory, is writable, and worker thread creation. See NB-3 below for the
fifth check.

**10. Async worker shutdown**
Step 5 requires the worker to complete in-progress tasks before joining on `stop()`. Step 8
destructor calls `io_worker.stop()` before releasing the cold store. Shutdown race mitigation is
addressed.

**11. Completion callback locking model**
NB-4 resolution selects the result-queue model. Step 5 documents it in a comment block.
Descriptor state mutations remain on the `server_context` thread. Consistent with design Part 4.

**12. Hot-byte release timing**
Pinned in NB-5 resolution and Step 6: hot bytes are held until the demotion completion callback
carries a success result. Consistent with design Part 7 risk entry for hot byte release ordering.

**13. Test hooks**
Step 11 defines all five test hooks matching design Part 6 exactly (injectable backend, delay,
queue capacity override, promotion failure injection, direct residency query). The acceptance test
requires all ten fault injection cases from design Part 6 to have corresponding test cases.

**14. No hidden decisions**
The `store_ref` schema decision resolves an open item from design Part 8 and is technically
grounded in the Stage 5 code. The NB-3 removal of `cold_ref_for` is a permitted implementation-
time resolution, not a new hidden decision. No other new architectural decisions appear in the plan.

**15. No scope creep**
No branch graph, namespace traversal, Stage 7 or later work appears in any step. The cold budget
deferral from design Part 7 is respected. Operator documentation and security review remain
deferred per the design.

---

## Non-blocking observations

**NB-A: NB-3 resolution supersedes design Part 2 without a correction record**
Design Part 2 lists `cold_ref_for(payload_id)` as a required operation. The plan removes it via
NB-3 resolution. Step 2 documents the removal, but no design correction to Part 2 is created or
referenced. Before Step 2 is implemented, the Developer should either create a design correction
part or add a supersession note to the Part 2 interface table so the design and implementation
remain consistent.

**NB-B: Fifth startup check not acknowledged in Step 9**
Design Part 5 startup validation table includes a fifth check: `--cache-ram` is set to a positive
value when hybrid mode is enabled, with note "(inherited from Stage 4, revalidated here)". Step 9
does not mention this check. The validation presumably still runs from Stage 4 code and is not
broken by Step 9's changes, but the plan should state explicitly whether it relies on the existing
Stage 4 check or adds a re-check in the Stage 6 startup path.

**NB-C: Evidence plan part number conflicts with this review**
The evidence plan in Part 2 designates `part-03-implementation-evidence.md` as the location for
implementation evidence. This review is written as `part-03-independent-plan-review.md`. The
Developer should update the evidence plan to redirect implementation evidence to `part-04`.

**NB-D: Part 3 prose order inconsistency**
Design Part 3, promotion protocol step 6 prose lists validation items as "header checksum, magic,
format version, checksum algorithm" - a different order from the explicit numbered check list that
follows in the same section (magic -> format_version -> header_checksum -> checksum_algorithm).
The implementation plan correctly defers to "the order specified in design Part 3" and lists the
numbered check order. Implementers should be directed to the numbered check list, not the prose
in step 6. This is a defect in design Part 3 prose only.

---

## Required correction before re-review

The Developer must update the dependency list in Part 1 (Step 6) and Part 2 (Step 7) to add
Step 8 as a dependency. No other blocking change is required. The corrected plan should be
resubmitted for Architect sign-off before code work begins.

## Handoff state

REWORK. Blocked on BF-1. Plan is otherwise complete and technically sound. No new design review
is required. After BF-1 is corrected and the non-blocking observations are addressed or
acknowledged, the plan is ready for manager approval.
