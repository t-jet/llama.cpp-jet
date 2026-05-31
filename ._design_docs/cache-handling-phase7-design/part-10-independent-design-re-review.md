# Part 10: Independent Design Re-Review - Stage 7

**Reviewer**: Architect agent  
**Date**: 2026-05-31  
**Verdict**: PASS

## Scope reviewed

Reviewed the current Stage 7 entry document and Parts 01-09 after the latest correction pass. This review focused on Part 09 R3 and did a regression check that Part 08 R1, R2, and N1 remain closed.

References checked:

- `._design_docs/document-index.md`
- `cache-handling-architecture/part-01-method.md`
- `cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `cache-handling-architecture/part-04-adr-009-distinguish-payload-eviction-from-branch.md`
- `cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
- `cache-handling-requirements/part-01-status.md`
- `cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- `cache-handling-phase4-design/part-03-protected-root-budget-behavior.md`
- `cache-handling-phase4-design/part-06-review-gate-and-handoff.md`

## Prior finding status

| Finding | Status | Re-review note |
| --- | --- | --- |
| Part 09 R3: Protected roots are treated as payload pins | RESOLVED | Parts 02, 03, 04, 05, and 06 now say protected roots protect graph metadata and topology, not hot payload bytes. Protected-root payloads count against `hot_payload_ram_max`, are skipped while unprotected candidates can satisfy pressure, and can be demoted or evicted with diagnostics when protected bytes alone keep the cache over budget. This matches Stage 4 protected-root budget behavior. |
| Part 08 R1: Token-span lookup is not implementable from the documented data model | STILL RESOLVED | Part 02 stores `token_span` and `prefix_checksums`, uses them for token and checksum lookup, and includes both vectors in `metadata_ram_bytes()`. Parts 03, 04, and 06 still test and account for that data. |
| Part 08 R2: Metadata-budget eviction prunes graph nodes without the required pruning contract | STILL RESOLVED | Parts 01, 02, 03, 04, and 06 still keep Stage 7 metadata pressure diagnostic-only. Production metadata pressure must not prune, orphan, reparent, delete, or convert graph nodes. Branch pruning and metadata-only lifecycle work remain deferred to Stage 8+. |
| Part 08 N1: Public metadata-budget flag needs an architecture decision | STILL RESOLVED | The Stage 7 design still uses an internal/test-only `branch_metadata_ram_soft_max` and keeps the public `--cache-budget-metadata-ram` surface deferred. No public `--cache-branch-metadata-mib` flag remains in the current design parts. |

## R3 assessment

The current design now matches the accepted protected-root policy:

- Part 02 says `protected_root` protects root graph metadata and parent-child topology from graph removal, and explicitly says it is not a hot-payload pin.
- Part 02 shared-budget and global-eviction rules include protected-root payload bytes in hot payload RAM accounting.
- Part 02 orders hot payload eviction as unprotected candidates first, then protected-root payloads oldest first if the budget is still exceeded.
- Part 03 Step 7.7 requires protected root graph preservation while keeping protected-root payloads as lower-priority eviction or demotion candidates.
- Part 04 Tests 7.4.8 and 7.4.13 cover graph preservation separately from protected-root payload demotion or eviction under over-budget pressure.
- Part 05 replaces the earlier blocked-by-protection evidence with protected-root payload decision metrics.
- Part 06 marks pinned protected-root payload bytes outside accounting as a fail condition.

This closes Part 09 R3 without adding Stage 8 branch pruning behavior.

## New findings

No new blocking or non-blocking findings.

## Gate decision

Stage 7 design review passes. The design is ready for manager gate consideration and implementation planning after manager approval.

Recommended entry-document state:

- Design: PASS
- Design Review: PASS
- Implementation: PENDING
- Implementation Review: PENDING
- QA: PENDING
- Closure: PENDING

## Manager handoff

Handoff state: READY FOR MANAGER GATE.

The current Stage 7 design closes the prior review blockers and matches the architecture for branch graph foundation, compatibility namespaces, shared budgets, metadata accounting, global hot-payload LRU across namespaces, and protected-root retention priority. Implementation planning can open after the manager records the gate decision.
