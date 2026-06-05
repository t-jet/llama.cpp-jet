# Part 09: Independent Design Re-Review - Stage 7

**Reviewer**: Architect agent  
**Date**: 2026-05-31  
**Verdict**: REWORK

## Scope reviewed

Reviewed the current Stage 7 entry document and Parts 01-08 after the correction pass. Started from `._design_docs/document-index.md` and checked the design against:

- `cache-handling-architecture/part-01-method.md`
- `cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `cache-handling-architecture/part-04-adr-009-distinguish-payload-eviction-from-branch.md`
- `cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
- `cache-handling-requirements/part-01-status.md`
- `cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- `cache-handling-phase4-design/part-03-protected-root-budget-behavior.md`
- `cache-handling-phase4-design/part-06-review-gate-and-handoff.md`

This re-review focused on the prior Part 08 findings R1, R2, and N1, then checked for new architectural blockers introduced or left open by the correction.

## Prior Part 08 finding status

| Finding | Status | Re-review note |
| --- | --- | --- |
| R1: Token-span lookup is not implementable from the documented data model | RESOLVED | Part 02 now stores `token_span` and `prefix_checksums` on `branch_node`, defines length-qualified checksum lookup, and includes both vectors in `metadata_ram_bytes()`. Parts 03, 04, and 06 now test and account for that data. |
| R2: Metadata-budget eviction prunes graph nodes without the required pruning contract | RESOLVED | Parts 01, 02, 03, 04, and 06 now state that Stage 7 records metadata over-budget diagnostics only. Production metadata pressure must not prune, orphan, reparent, delete, or convert graph nodes. Branch pruning and metadata enforcement remain Stage 8 behavior. |
| N1: Public metadata-budget flag needs an architecture decision | RESOLVED | The public `--cache-branch-metadata-mib` flag was removed. Stage 7 uses an internal/test-only `branch_metadata_ram_soft_max` setting and keeps the public metadata-budget CLI deferred. |

## New blocking finding

### R3: Protected roots are treated as payload pins, contradicting the approved budget policy

**Location**: `part-02-component-design.md` Sections 2.7 and 2.8; `part-03-implementation-steps.md` Step 7.7; `part-04-test-specifications.md` Test 7.4.8; `part-05-metrics-and-observability.md` Eviction metrics

The corrected Stage 7 design says `payload_eviction_candidates()` excludes nodes with `protected_root == true`, that protected roots are never selected for payload eviction, and that payload eviction attempts can be blocked by protected root status.

That conflicts with the accepted Stage 4 and architecture contract:

- Stage 4 closed with protected roots as higher-priority retention entries, not pinned memory.
- `cache-handling-phase4-design/part-03-protected-root-budget-behavior.md` allows protected-root eviction when protected bytes exceed the budget and records that case explicitly.
- `cache-handling-phase4-design/part-06-review-gate-and-handoff.md` says protected roots survive ordinary pressure but do not bypass the budget.
- `cache-handling-architecture/part-02-restore-and-residency-flow.md` says protected roots raise eviction priority but do not bypass accounting.

Stage 7 may preserve protected root graph nodes. It may not make protected root payload bytes permanently ineligible for hot-payload eviction or demotion. Doing so can break the shared hot-payload budget whenever protected roots alone exceed `--cache-ram`.

**Required correction**:

- Keep protected root metadata and topology protected from graph removal in Stage 7.
- Change hot-payload eviction policy so protected roots have higher retention priority, but remain eligible when budget pressure cannot be satisfied by unprotected payloads.
- Replace "blocked by protected root status" metrics/tests with protected-root decision evidence that covers skip, demote/evict under over-budget pressure, and admission or diagnostic behavior.
- Update Tests 7.4.8 and 7.4.13 to verify graph-node preservation separately from payload residency.

## New non-blocking findings

None.

## Gate decision

Stage 7 remains in design rework. The correction closed Part 08 R1, R2, and N1, but the current protected-root payload residency wording contradicts the approved Stage 4 budget policy and the architecture's protected-root contract.

Do not open implementation planning until R3 is corrected and re-reviewed.

## Manager handoff

Handoff state: REWORK REQUIRED.

Correction owner should update Parts 02, 03, 04, 05, and 06 so protected roots are graph-protected and higher-priority for payload retention, but not payload pins. After that, request a focused Architect re-review for R3 and a quick regression check of the already closed Part 08 findings.
