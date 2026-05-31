# Part 08: Independent Design Re-Review - Stage 7

**Reviewer**: Architect agent  
**Date**: 2026-05-31  
**Verdict**: REWORK

## Scope reviewed

Reviewed the current Stage 7 entry document and Parts 01-07 after the earlier independent review. Checked the design against:

- `cache-handling-architecture/part-01-method.md`
- `cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `cache-handling-architecture/part-04-adr-009-distinguish-payload-eviction-from-branch.md`
- `cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
- `cache-handling-requirements/part-01-status.md`
- `cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`

The prior blocking findings B1-B3 have been addressed in the edited Stage 7 parts. The current design still cannot pass because it introduced two new blocking issues in the corrected model.

## Prior finding status

| Finding | Status | Re-review note |
| --- | --- | --- |
| B1: BranchNode mismatch with architecture | RESOLVED | Part 02 now defines a shared `branch_node` with node ID, namespace, parent, token/checksum span fields, position range, usage, residency, protection, metadata-only flag, and payload references. |
| B2: Budget model contradicts shared global budget | RESOLVED WITH FOLLOW-UP | The old per-namespace slot budget is gone. The design now uses a shared three-part budget and global eviction. New finding R2 covers unsafe metadata-node eviction under that model. |
| B3: NamespaceKey lacks compatibility semantics | RESOLVED | Part 02 now includes model identity, draft mode/model identity, tokenizer/template identity, runtime modifiers, multimodal settings, context/KV settings, and workload profile with strict equality validation. |
| N1: BranchForestIndex key scope ambiguity | RESOLVED | The index is keyed by `node_id`; namespace scoping is explicit in node metadata and lookup APIs. |
| N2: `fork_offset` vs span model | RESOLVED | `fork_offset` has been removed from the proposed node. The design uses `n_tokens`, `pos_min`, and `pos_max`. |
| N3: R83a traceability incorrect | RESOLVED | Part 01 marks Stage 7 as primitive-only coverage and defers full equivalent-branch deduplication to Stage 8. |
| N4: R93 budget model mismatch | RESOLVED WITH FOLLOW-UP | The design now describes hot payload RAM, branch-metadata RAM, and cold storage budgets. New finding N1 asks for the public CLI surface to be reconciled with the architecture. |
| N5: Budget integration file list incomplete | RESOLVED | Step 7.4 now places budget enforcement in controller/hybrid files and removes `cache_slot.cpp` as the budget owner. |
| N6: Concurrency test underspecified | RESOLVED | Test 7.4.7 now names thread count, operation mix, duration, consistency checks, and TSAN evidence. |
| N7: Lock contention metric underspecified | RESOLVED | Part 05 replaces the ratio gauge with acquire and retry counters and gives a derived formula. |

## New blocking findings

### R1: Token-span lookup is not implementable from the documented data model

**Location**: `part-02-component-design.md` Sections 2.1 and 2.2; `part-04-test-specifications.md` Tests 7.4.1 and 7.4.4

`branch_forest_index::find_nodes_by_token_span()` accepts a token prefix and Test 7.4.4 expects prefix lookup to distinguish `[1,2,3]` from `[1,2,3,4,5]`. The documented `branch_node` does not store node tokens, a token span descriptor, a token-range index, or any secondary index that can answer that query. It stores only `n_tokens`, `pos_min`, `pos_max`, and one `token_checksum`.

The inconsistency shows up in the tests too: Test 7.4.1 says `metadata_ram_bytes()` must include `10 * sizeof(llama_token)`, but the node struct has no token vector or token-span storage to account for.

This blocks the design because Stage 7 explicitly promises branch lookup by token/checksum spans. An implementation following the current design would either be unable to implement token-prefix lookup or would add undocumented storage and accounting behavior during coding.

**Required correction**:

- Define the exact token-span lookup data: either store validated node token spans, store a compact token/checksum span index, or narrow the Stage 7 API to checksum-only lookup.
- Update `metadata_ram_bytes()` and budget accounting to include that data.
- Update Tests 7.4.1, 7.4.4, and 7.4.5 so they match the chosen representation.

### R2: Metadata-budget eviction prunes graph nodes without the required pruning contract

**Location**: `part-02-component-design.md` Sections 2.5 and 2.7; `part-03-implementation-steps.md` Step 7.4; `part-06-acceptance-criteria.md` Known Limitations

The design enforces `branch_metadata_ram_max` by evicting branch nodes from the forest. Section 2.7 says children of an evicted node become orphaned roots if they have slot references, otherwise they are also evicted.

That conflicts with the architecture's pruning rules:

- R38c requires retaining an internal branch node as metadata-only if removing it would break discovery, lookup, or traversal for retained descendants.
- R76a requires valid parent-child topology for retained descendants when an intermediate ancestor is metadata-only.
- ADR-009 rejects treating payload eviction and branch pruning as the same lifecycle event.
- Stage 8 owns metadata-only node retention, re-materialization, cold cleanup safety, equivalent-branch deduplication, and branch-metadata budget enforcement.

The current Stage 7 design says metadata-only nodes and branch pruning are deferred, but it also defines metadata-budget node eviction that can reparent live children and delete subtrees. That is branch pruning without the safety rules.

**Required correction**:

- Either defer branch-metadata node eviction/enforcement to Stage 8 and keep Stage 7 global eviction limited to payload residency, or
- Add a safe Stage 7 pruning contract that preserves descendant topology, handles cold descriptor cleanup, defines which nodes may be pruned, and tests retained-descendant cases.

The second option would expand Stage 7 into Stage 8 behavior. The cleaner fix is to keep Stage 7 focused on the branch graph and shared namespace budget model, while making metadata budget accounting observable but non-pruning until Stage 8.

## New non-blocking finding

### N1: Public metadata-budget flag needs an architecture decision

**Location**: `part-02-component-design.md` Section 2.5; `part-03-implementation-steps.md` Step 7.4; `part-06-acceptance-criteria.md` R93 row

The design adds `--cache-branch-metadata-mib`. The architecture's CLI table keeps public metadata budget flags deferred and names the future option `--cache-budget-metadata-ram`. Requirements R8b and R93 require configurable metadata budgets, so configuration itself is valid, but the public operator-facing flag conflicts with the architecture's upstream-facing CLI guidance.

**Required correction**:

- Decide whether Stage 7 is allowed to expose a private-fork flag now, or keep the setting internal/test-only until the architecture opens the public CLI surface.
- If a public flag remains, align the name and status with the architecture or record an explicit architecture exception.

## Gate decision

Stage 7 remains in design rework. The corrected documents closed the previous B1-B3 blockers and all prior non-blocking findings, but R1 and R2 are current blockers. The entry document must not be treated as approved until a follow-up design revision resolves both.

## Manager handoff

Handoff state: REWORK REQUIRED.

Recommended correction loop:

1. Developer or design owner updates Parts 02, 03, 04, and 06 for token-span lookup storage/accounting.
2. Design owner resolves the Stage 7 metadata-budget pruning scope: defer pruning to Stage 8, or document a complete safe pruning contract.
3. Architect performs another re-review focused on R1, R2, and the CLI decision in N1.
