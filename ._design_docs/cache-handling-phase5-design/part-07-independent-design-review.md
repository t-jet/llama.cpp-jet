# Phase 5 design: payload-metadata separation and target/draft pairing - Part 7: Independent design review

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Review scope

Review date: May 27, 2026

Reviewed documents:

- [Phase 5 design entry](../cache-handling-phase5-design.md)
- [Part 1: Scope, prerequisites, and assumptions](part-01-scope-prerequisites-and-assumptions.md)
- [Part 2: Interfaces, components, and data model](part-02-interfaces-components-and-data-model.md)
- [Part 3: Save, restore, eviction, and pairing behavior](part-03-save-restore-eviction-and-pairing-behavior.md)
- [Part 4: Validation, diagnostics, and observability](part-04-validation-diagnostics-and-observability.md)
- [Part 5: Testability and requirement traceability](part-05-testability-and-requirement-traceability.md)
- [Part 6: Exclusions, risks, and review readiness](part-06-exclusions-risks-and-review-readiness.md)
- [Architecture entry](../cache-handling-architecture.md) and Parts 1-5
- [Requirements entry](../cache-handling-requirements.md) and Parts 1-2
- [Stage 4 closure decision](../cache-handling-phase4-implementation/part-09-stage-closure-decision.md)
- [AGENTS.md](../../AGENTS.md)

This was a design review only. No code was reviewed or changed, and no implementation plan was created.

## Verdict

REWORK.

The design is mostly aligned with the Stage 5 architecture source. It separates descriptor metadata from exact-blob payload bytes, keeps the Stage 4 LRU and protected-root behavior unchanged, defines target-only and target-plus-draft pair states, rejects malformed descriptors, and keeps cold storage, branch graph nodes, checkpoint payload admission, and implementation planning out of scope.

One blocking design gap remains. The target-plus-draft restore path says the operation is atomic, but the design does not define the recovery contract when target application succeeds and draft application then fails. That gap affects pair-state correctness, fallback safety, and testability.

## Blocking finding

### Finding 1: partial restore recovery is not explicit enough

Part 3 restore behavior applies target bytes before draft bytes, then says any target or draft restore failure fails the whole restore and leaves the slot in a valid state. Part 5 requires tests for failed target restore and failed draft restore. The design does not say what the restore applier must do when target application succeeds and draft application fails.

This matters because R9, R10, R13, R34, R35, R90, R91, and R104 require target and draft state to be managed as one restore object. A sequential restore can leave the live slot with a restored target side and an unrestored draft side unless the design requires a specific rollback, pre-restore snapshot, scratch-apply path, or slot reset to a known fallback state. "Leave the slot in a valid state" is the right goal, but it is not enough for implementation planning or review.

Required correction:

- Define the transactional restore contract for `target_and_draft` descriptors.
- State what live slot state exists after target succeeds and draft fails.
- Require restore applier tests that prove failed draft application does not leave a reported hit, refreshed recency, or a half-restored target/draft pair.
- State whether target-only restore uses the same failure recovery path or a narrower one.

Acceptance check:

- A later implementation plan can point to one documented recovery behavior for every restore failure point before live state mutation, during target apply, and during draft apply.

## Review decisions

- Stage 4 closure is a valid prerequisite. The closure document records Stage 4 as closed with no blocking architecture, implementation, product bug, or QA blocker.
- Stage 5 scope is properly limited to descriptor separation and pairing enforcement for hot exact blobs. The design does not pull in cold files, asynchronous I/O, checkpoint payload admission, branch graph topology, metadata-only nodes, branch pruning, CLI changes, or implementation steps.
- Requirement traceability is mostly sound for the stage boundary. Deferred requirements for cold storage, checkpoint payloads, branch graph behavior, metadata-only nodes, mismatch-parent selection, and re-materialization are named as later-stage work.
- Data ownership is clear enough for Stage 5: one descriptor belongs to one interim exact-blob cache entry, and payload bytes remain owned by the hot payload store.
- Pair-state validation is conservative and safe. A runtime with a draft context accepts only `target_and_draft`, and a runtime without a draft context accepts only `target_only`.
- Eviction behavior preserves the Stage 4 byte budget and treats target and draft bytes as one eviction unit.
- Diagnostics and metrics cover descriptor validation failures, pairing violations, restore failures, fallback restores, and payload evictions without logging payload bytes.
- The optional retention of evicted descriptors is acceptable only as short-lived diagnostics for interim exact-blob entries. It must not become Stage 8 metadata-only branch behavior without a later design update.

## Requirement checks

R9-R10 and R13: REWORK. Pair-state rules and eviction atomicity are documented, but restore failure recovery is incomplete for target-plus-draft descriptors.

R34-R36 and R90-R92: REWORK for restore failure recovery. Descriptor validation fails closed and fallback behavior is otherwise explicit.

R37-R38 and R39-R48: Passed for Stage 5 scope. The descriptor schema separates metadata from payload bytes for hot exact blobs and reserves fields for later checkpoint and cold-layer stages.

R52 and R55: Passed for Stage 5 scope. Cold offload is deferred, but the pair-state and checksum model is compatible with a later cold layer.

R93-R98 and R104-R105: REWORK only for the missing partial-restore test contract. The remaining test seams and metrics are adequate for later QA planning.

R112, R117, R122, R127, and R133: Passed. Responsibilities, terminology, descriptor versioning, store substitutability, and security review points are documented.

AGENTS.md: Passed. The review stays concise, writes durable design-review documentation, does not implement code, and does not create a PR or reviewer response.

## Required corrections

Update the Phase 5 design before implementation planning:

- Add explicit transactional restore behavior for target-plus-draft descriptors.
- Add matching failure-injection test requirements for draft-apply failure after target-apply success.
- Keep the correction in the durable design parts, not only in a handoff note or later test report.

No code correction is requested by this review.

## Handoff

State: re-review required.

Next owner: architect or manager for design correction, followed by independent design re-review. Developer implementation planning should not start until this finding is closed or formally accepted in the design gate.
