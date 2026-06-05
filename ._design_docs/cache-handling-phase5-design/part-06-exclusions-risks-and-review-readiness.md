# Phase 5 design: payload-metadata separation and target/draft pairing - Part 6: Exclusions, risks, and review readiness

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Exclusions and deferred work

Stage 5 does not include:

- cold payload files or a cold-store directory
- asynchronous I/O workers
- payload promotion or demotion
- checkpoint payload admission
- branch graph nodes or namespace traversal
- metadata-only nodes
- branch pruning
- re-materialization from retained ancestors
- new CLI flags or operator budget controls beyond the Stage 4 `--cache-ram` behavior
- implementation steps, task breakdowns, or code changes

These exclusions keep Stage 5 focused on descriptor correctness and pairing enforcement. Later stages can build on the descriptor contract without reopening the target/draft invariants.

## Risks

| Risk | Mitigation |
| --- | --- |
| Descriptor separation accidentally changes legacy behavior | Keep all descriptor work behind hybrid mode. Add regression tests for legacy mode. |
| Descriptor ownership becomes ambiguous when equivalent entries refresh | Require one owner per descriptor and admit replacements only after validation succeeds. |
| Pairing errors leave a half-restored slot | Require pre-apply validation plus scratch staging or pre-restore snapshot rollback before fallback. |
| Metrics count invalid candidates as cache hits | Refresh usage and hit counters only after full restore succeeds. |
| Future cold-store fields invite premature disk behavior | Reserve `store_ref` and `residency_state`, but reject `cold` in Stage 5. |
| Checksum work adds overhead on hot restores | Keep checksum helper focused and benchmark later implementation evidence. Correctness comes first. |
| Draft-model coverage remains thin | Make target-plus-draft descriptor and restore tests required before implementation sign-off. |

## Design decisions

- Use `PayloadDescriptor` as the first-class metadata record for exact-blob payloads in Stage 5.
- Keep checkpoint descriptors schema-compatible but inactive until a later stage admits checkpoint payloads.
- Keep descriptor ownership singular.
- Treat `target_and_draft` as an atomic pair across every cache operation.
- Require transactional restore semantics: failed target, draft, or commit application leaves the live slot in its pre-restore state and falls back without hit accounting.
- Reject runtime pair mismatches instead of attempting a downgrade.
- Keep cold-layer states reserved but unimplemented.
- Keep existing Stage 4 LRU and protected-root behavior unchanged.

## Review readiness

This document is ready for independent design review if the reviewer confirms:

- Stage 4 closure is accepted as the prerequisite.
- Stage 5 scope is limited to descriptor separation and pairing enforcement.
- No implementation plan or code change is embedded in the design.
- Descriptor validation covers version, size, checksum, residency, store reference, and ownership.
- Pairing rules cover target-only and target-plus-draft runtimes.
- Failure behavior is explicit and safe, including draft-apply failure after target-apply success.
- Metrics and diagnostics are sufficient for review and later QA planning.
- Requirement traceability includes the manager-requested requirements.

## Gate status

Status: independent design re-review passed.

Open findings: none. The Part 7 independent review finding has been corrected in Parts 3, 4, and 5, recorded in Part 8, and closed by the independent re-review in Part 9.

Implementation planning handoff: open by the manager gate in [Part 10](part-10-manager-design-gate.md).

Code work remains closed until the implementation plan passes independent review and manager approval.
