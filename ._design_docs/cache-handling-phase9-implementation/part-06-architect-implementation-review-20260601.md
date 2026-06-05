# Stage 9 Architect implementation review - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Reviewer: Architect (independent)
Gate: Implementation review
Verdict: REWORK

## Scope and gate status

This review covers the first Stage 9 implementation pass only. It checks code,
tests, and implementation evidence against the approved Stage 9 design and the
approved implementation plan.

Gate status: REWORK. Stage 9 is not ready for QA or Manager closure.

## Source docs reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-phase9-design.md`
- `._design_docs/cache-handling-phase9-design/part-01-scope-and-workload-profiles.md`
- `._design_docs/cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md`
- `._design_docs/cache-handling-phase9-design/part-03-restore-strategy-and-prepared-prompt-boundaries.md`
- `._design_docs/cache-handling-phase9-design/part-04-pairing-cold-store-metrics-and-diagnostics.md`
- `._design_docs/cache-handling-phase9-design/part-05-testability-traceability-exclusions-and-risks.md`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase9-implementation/part-02-evidence-plan-and-risks.md`
- `._design_docs/cache-handling-phase9-implementation/part-03-architect-plan-review-gate.md`
- `._design_docs/cache-handling-phase9-implementation/part-04-manager-implementation-plan-gate.md`
- `._design_docs/cache-handling-phase9-implementation/part-05-implementation-evidence-20260601.md`

## Code files reviewed

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

## Blocking findings

### S9-IMPL-01: checkpoint descriptors do not carry or validate checkpoint placement metadata

Severity: BLOCKING

Approved design requirement:

- Part 2 requires checkpoint descriptors to record enough restore metadata to
  verify applicability, including token span, position range, context mode, and
  boundary ID when admitted from a prepared boundary.
- Part 3 requires boundary validation before restore: token span length,
  checksum or equivalent token-range validation, namespace/profile match,
  boundary kind, and media/projector compatibility.

Code evidence:

- `tools/server/server-cache-hybrid.cpp:2209` through `:2211` stores only the
  detected workload profile and a coarse `0..entry.n_tokens()-1` token span.
- `tools/server/server-cache-hybrid.cpp:2287` through `:2312` admits the latest
  checkpoint using only target/draft byte presence. It does not validate or
  store checkpoint position range, boundary ID, boundary checksum, boundary
  kind, or context-mode metadata.
- `tools/server/server-context.cpp:5555` through `:5588` wires production
  checkpoint admission from `slot.prompt.checkpoints.back()` but does not pass
  prepared-boundary metadata into checkpoint descriptor admission.
- `tools/server/server-context.cpp:5730` validates only the selected payload
  descriptor and hot record before restore. There is no checkpoint boundary or
  token-range validation step for checkpoint restores.

Impact:

The graph can accept and later restore a checkpoint as a first-class branch
payload without proving that the checkpoint belongs to the selected boundary or
runtime span. This violates the Stage 9 safety contract and makes boundary-aware
checkpoint reuse unsafe.

Required correction:

Add checkpoint restore metadata to the descriptor or an associated descriptor
record, pass prepared-boundary data through production admission, reject invalid
or degraded cases according to the design, and add focused tests for boundary
ID, span, checksum, and missing-boundary fallback.

### S9-IMPL-02: checkpoint-dependent restore can select an exact-only branch as the restore payload

Severity: BLOCKING

Approved design requirement:

- Part 1 states that checkpoint-dependent workloads use checkpoint nodes as the
  canonical branch structure.
- Part 3 says exact blobs may be accelerators or roots for the same branch path,
  but do not replace checkpoint branch continuity. Missing safe checkpoint paths
  must fall back to recompute.
- Part 1 and the implementation plan require missing checkpoint metadata for a
  checkpoint-dependent runtime to recompute instead of matching exact-only
  branches as canonical continuity.

Code evidence:

- `tools/server/server-cache-hybrid.cpp:1004` through `:1007` ranks an exact
  payload as a valid fallback candidate for `checkpoint_dependent` when no
  checkpoint exists.
- `tools/server/server-context.cpp:5673` through `:5703` accepts the selected
  candidate and selected payload kind without checking that a checkpoint path
  exists for checkpoint-dependent continuity.
- `tools/server/server-context.cpp:5730` through `:5869` then restores that
  payload as a normal hit.

Impact:

A constrained runtime can restore from an exact-only branch as if it were the
canonical checkpoint path. The implementation does not prove that the exact blob
is only an accelerator or root for a validated checkpoint branch.

Required correction:

For `checkpoint_dependent`, require a valid checkpoint-bearing path before
returning a cache hit. Exact blobs may speed replay only after the checkpoint
path is validated. If the path has no usable checkpoint metadata or checkpoint
payload, return a miss/fallback and emit the documented reason.

### S9-IMPL-03: checkpoint hot residency is not integrated with normal payload eviction

Severity: BLOCKING

Approved design requirement:

- Part 2 says evicting a checkpoint payload removes that descriptor and payload
  bytes without pruning the branch node.
- Part 4 requires exact blobs and checkpoint payloads to share the hot-payload
  budget, cold demotion, promotion, eviction, cleanup, and target/draft pair
  integrity rules.

Code evidence:

- `tools/server/server-cache-hybrid.cpp:1177` through `:1184` evicts an entry by
  saving `it->payload_id` and calling `mark_payload_evicted(*it)`.
- `tools/server/server-cache-hybrid.cpp:2019` through `:2064` only demotes or
  evicts `entry.payload_id`. It never demotes, evicts, or detaches
  `entry.checkpoint_payload_id`.
- `tools/server/server-cache-hybrid.cpp:2469` through `:2497` builds one policy
  candidate per entry from aggregate resident bytes, so the policy can choose an
  entry whose hot bytes include a checkpoint, but the eviction action clears
  only the exact payload accounting.

Impact:

Checkpoint payload bytes can remain hot after the budget path treats the entry
as demoted or evicted. That breaks byte accounting, eviction fairness, and the
shared residency contract for checkpoint payloads.

Required correction:

Make residency operations payload-kind aware. The budget path must be able to
demote or evict checkpoint descriptors, exact descriptors, or both according to
policy, while keeping branch metadata and descriptor ownership correct.

## Major findings

### S9-IMPL-04: required checkpoint Prometheus labels are exported as constant buckets

Severity: MAJOR

Approved design requirement:

- Part 4 requires `cache_checkpoint_restores_total` labels
  `profile`, `payload_residency`, `pair_state`, and `result`.
- Part 4 requires `cache_checkpoint_hits_total` labels `profile`,
  `payload_residency`, and `pair_state`.

Code evidence:

- `tools/server/server-context.cpp:4590` through `:4592` exports those metrics
  with constant label values: `profile="all"`, `payload_residency="hot"`, and
  `pair_state="all"`.
- `tools/server/server-cache-hybrid.cpp:653` through `:657` stores only coarse
  totals, so the exporter has no real per-profile, per-residency, or
  per-pair-state counts to report.

Impact:

The metric names exist, but operators cannot distinguish plain transformer vs
checkpoint-dependent restores, cold vs hot checkpoint paths, or target-only vs
target-and-draft behavior. This does not satisfy the Stage 9 observability
contract.

Required correction:

Record checkpoint hit and restore counters by the required enum dimensions and
export the real label values. Add metric-shape tests that prove no prompt text,
paths, marker labels, or serialized data are exported.

## Advisory findings

### S9-IMPL-05: tests are too narrow for the claimed implementation surface

Severity: ADVISORY

The focused tests in `tests/test-cache-controller.cpp` cover useful controller
helpers, but they do not yet cover production boundary admission, real
checkpoint restore application, target/draft checkpoint mismatch, checkpoint
replacement, checkpoint eviction through the normal budget path, or public
task-flow boundary propagation. Part 5 is honest that no model-backed
checkpoint-first row ran, but the next evidence pass should avoid calling the
Stage 9 behavior complete until those production paths are covered.

## Required corrections

- Fix S9-IMPL-01 through S9-IMPL-03 before re-review.
- Fix S9-IMPL-04 before QA handoff, or record Manager approval for a scoped
  observability exception. No such exception exists in the approved design.
- Add focused and production-path tests for the corrected behavior.
- Update Part 5 or add a new evidence part with the commands run, failures,
  skips, and model-backed or substitute evidence status.

## Next action

Next owner: Developer.

Handoff state: REWORK. Developer should correct the implementation and evidence,
then request Architect implementation re-review. QA should not start Stage 9
execution from this implementation snapshot.
