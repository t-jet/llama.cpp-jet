# Stage 14 design: merge log, constraints, observability, testability, and risks -- Part 6

Source: [../cache-handling-phase14-design.md](../cache-handling-phase14-design.md)

## Goal

This part records the merge log format, the constraints Stage 14
keeps inherited from prior stages, the observability and
testability rules the merge must not break, the risks, the
exclusions, the requirement traceability, and the handoff state.
It is the durable record the Stage 14 implementation log links to.

## Merge log format

The merge log is a durable artifact. The Developer owns the merge
log and the Architect reviews it. The merge log is a separate
report, not a part file of this design. The design prescribes the
required sections and the minimum content per section.

### Required sections

1. Cover and metadata
   - Stage number, design baseline link, date opened, date closed
   - Owner (Developer), reviewer (Architect), approver (Manager)
   - Upstream remote name (`origin`), upstream ref
     (`origin/upstream_master`), fork point SHA, integration branch
     name, integration branch tip SHA on close
2. Upstream reference verification
   - The `origin/upstream_master` ref tip SHA on the date the
     merge opened, with the actual upstream `master` tip SHA
     obtained from `git ls-remote
     https://github.com/ggml-org/llama.cpp.git master` (or the
     GitHub REST API endpoint)
   - The gap (ahead, behind, or diverged) and the Manager
     decision to fast-forward or merge with the gap, per D1
3. Decisions
   - The list of in-scope upstream commits and the final triage
     decision for each, with a one-line reason that names a
     prior-stage contract from Part 1
   - The list of any NO-OP, INTEGRATE, or DEFER decision that the
     Architect or Manager changed during the merge, with the
     date and reason for the change
4. Deferred upstream commits
   - Upstream SHA, commit subject, the contract the commit would
     have affected, the reason for the deferral, and the
     follow-up owner
   - The expected cycle or condition that would lift the
     deferral
5. Known gaps
   - The list of contract gaps the merge exposed but did not
     close through a rework
   - Each known gap has a follow-up owner, a target cycle, and a
     link to the affected prior-stage contract
   - A known gap that the Manager escalates to a rework is moved
     out of this section and into the reworks list
   - Stale `origin/upstream_master` ref is recorded here when D1
     fast-forward vs merge-with-gap is exercised
6. Conflicts encountered
   - Each conflict the merge tool surfaced, with the upstream
     SHA, the local path, the local resolution, and the
     prior-stage contract the resolution preserves
   - The merge tool choice and the conflict resolution policy
     the Developer followed
7. Reworks opened
   - For each rework, the affected stage, the upstream change
     that triggered it, the rework part file link, and the rework
     status on the date the merge log was last updated
   - A rework that is still open at the date of the merge log
     update is recorded with its current status, not with a
     closure date
8. Regression evidence
   - Link to the Stage 14 test report and to the ctest,
     coverage, MTP probe, endpoint probe, stress harness
     preflight, and benchmark harness preflight artifacts the
     Developer produced
   - The T114 combined-rate verdict, the T114a product-only
     verdict, the T115 per-file aggregation verdict, the T121
     public checkpoint admission verdict, and the E13-01..E13-16
     endpoint parity verdicts, with the cited artifact section
     for each
9. Closure status
   - The set of architecture exit criteria from Part 1 that the
     integration branch has met on the date the merge log was
     last updated
   - The set of exit criteria that are still open and the
     follow-up action the Manager assigned

A merge log that is missing any of the sections above fails the
Architect review and is sent back to the Developer for a
rewrite.

## Constraints carried forward

The merge and any rework must keep the constraints from the prior
stages in force. The constraints are not relaxed for the merge.

| Constraint | Source | Why the merge must keep it |
| --- | --- | --- |
| Hybrid mode is opt-in only | Architecture, R1, R4 | Removing the opt-in would change the default cache path. |
| Legacy default path is unchanged | Architecture, R2, R107 | Legacy behavior is the user-visible default and is the Stage 1-3 contract. |
| Hybrid mode gate is isolated from the legacy path | Stage 1 | Mode dispatch in `server_context` keeps the controllers separated. |
| Target and draft pairing is atomic | Stage 5, ADR-002 | A partial paired restore is a blocking defect. |
| Cold store root is normalized and contained | Stage 6, Stage 10 | Path traversal, world-writable root, and missing containment are OWASP A01 and A05 mitigations. |
| Descriptor validation is mandatory before restore | Stage 5, Stage 10 | Skip-on-restore is a blocking defect. |
| Public Prometheus metric set and label shape are stable | Stage 10, S10-IMPL-01 | Operators read the metric set without parsing changes. |
| Bounded diagnostic fields are stable | Stage 10, Stage 13 | Bounded enums keep the log volume bounded. The bounded `cache metadata:` format at task launch carries `{source, method, degraded, tokens, boundaries}` and is emitted only as a diagnostic. |
| Diagnostic-source namespace isolation is stable | Stage 13, bug-fix review 2026-06-10 | The endpoint source label used in bounded diagnostic emission must not enter the namespace-affecting `preparation_id` or any other namespace key component. |
| MTMD placeholder path is stable | Stage 13 implementation, implementation log part 8 | Multimodal placeholder path preserved across the merge. |
| T114 combined 80% floor is a closure contract | Stage 10, test plan Part 12 | The coverage floor is not a guideline. |
| T114a product-only 70% floor is a closure contract | Test plan Part 13, Stage 11 onward | Test files must not mask product gaps. |
| T115 per-file aggregation rule is stable | Test plan Part 12, Part 13 | The per-file table is the source of truth for the coverage verdict. |
| T121 public checkpoint admission row is exposed | Stage 10 implementation Part 9 | Operators read the row to confirm the checkpoint path is exercised. |
| Stage 5 speculative-mode namespace isolation is stable | Architecture Part 6 | Target-only, separate draft, MTP-on-target, and MTP-on-separate-draft descriptors must not reuse each other's entries. |
| Stage 7 multi-namespace shared budgets are stable | Architecture Part 2 | Per-namespace quota is a future extension, not a current contract. |
| Branch metadata budget is configurable and enforced | Architecture, R8b, R21a | Branch metadata exhaustion must not silently bypass the budget. |
| Stage 12 stress harness outputs S01..S08 and L01..L03 are stable | Stage 12 design Part 2, Part 3 | Production-scale stress evidence; the merge does not weaken or delete any of them. |
| Stage 12 benchmark outputs B01..B08 are stable | Stage 12 design Part 3 | Production-scale performance evidence; the merge does not weaken or delete any of them. |
| Stage 12 configuration matrix is stable | Stage 12 design Part 2 | The matrix dimensions remain in scope for the cycle's stress and benchmark evidence. |
| Stage 13 endpoint parity rows E13-01..E13-16 are stable | Stage 13 design Part 3, implementation log | Public endpoint parity evidence; the cycle's regression rerun includes these rows. |
| Stage 13 transcript route coverage is stable | Stage 13 implementation plan rework 2026-06-09 | Transcription routes remain in the Stage 13 route inventory. |
| Stage 13 embedding cache exclusion is stable | Stage 13 implementation Part 2, Part 3 | Embedding routes remain excluded from hybrid cache prompt state by design. |
| Synthetic Stage 12 V2/V3/non-MTP expansion remains paused | 2026-06-09 close-at-current-progress | The 2026-06-09 Manager decision keeps the synthetic expansion paused; lifting the pause requires a separate Manager decision. |
| `test-stage10-policy-lru` pre-existing semantic bug is out of Stage 14 scope | Tracked separately | Not a Stage 14 contract; not a Stage 14 rework trigger. |

A constraint that an upstream change would weaken is a rework
candidate, not a silent integration.

## Observability rules

The merge must keep the observability shapes from Stage 10 and
the Stage 13 endpoint parity contract intact. The Developer does
not rename a public metric, drop a bounded label, or add a new
public metric during the merge. The following rules apply:

1. The four `cache_checkpoint_*` rows from Stage 10
   implementation Part 9 remain exposed through the public
   /metrics endpoint when a hybrid-mode server with MTP or
   checkpoint-capable draft is exercised.
2. The R61-R68 metric set, the bounded labels, and the absence
   of sensitive material in labels remain in force. The
   Developer does not add a label whose value could carry
   request material, prompt text, or model paths.
3. Bounded diagnostic events for failure, fallback, unsupported
   configuration, marker validation, cold-store failure,
   namespace rejection, pair-state rejection, and restore
   failure remain in force. The Developer does not rename a
   diagnostic event.
4. The bounded `cache metadata:` line at task launch carries
   `{source, method, degraded, tokens, boundaries}` and is
   emitted on the native `/completion` and OpenAI-compatible
   `/v1/chat/completions` degraded paths. The format and
   emission sites are stable across the merge.
5. The diagnostic endpoint source label is emitted only as a
   diagnostic field; it does not enter the namespace-affecting
   `preparation_id` or any other namespace key component.
6. The hot, cold, and branch-metadata byte gauges and the
   cold-operation latency buckets remain in force. The
   Developer does not remove a gauge or bucket the upstream
   changes do not justify.
7. The public /metrics endpoint does not gain a cache
   inspection endpoint, a per-branch metrics endpoint, or a
   per-slot metrics endpoint. Operators read the public
   Prometheus set as is.

The Architect reviews the observability impact of every
INTEGRATE, REWORK-REQUIRED, DEFER, and REVERT decision in the
pre-merge report.

## Testability rules

The merge must keep the testability contracts from the prior
stages. The following rules apply:

1. The deterministic seams from Stage 10 remain in force. The
   Developer does not remove a deterministic clock, a fake
   store backend, a deterministic graph lookup, or a
   deterministic worker completion order.
2. The focused C++ test binaries that the closed stages used
   remain in the build. The Developer does not delete a focused
   test binary during the merge, even when the upstream change
   makes the test surface smaller.
3. The focused exporter coverage command family and the
   citation rules from the test plan Part 13 remain in force.
   The Developer does not change the citation rules during the
   merge.
4. The ctest command family used by the closed stages remains
   the primary regression command family. The Developer does
   not replace ctest with another test runner during the
   merge.
5. The Stage 12 stress harness and the Stage 12 benchmark
   harness remain in the build. The Developer does not delete
   or replace either harness during the merge.
6. The Stage 13 endpoint probe and its E13-01..E13-16 parity
   rows remain in scope. The Developer does not drop an E13
   row from the regression rerun when the merge touched the
   corresponding endpoint adapter.
7. The Architect's per-file coverage target from the Stage 10
   review remains an internal target. The Developer does not
   lower the per-file target during the merge.

## Risks

| Risk | Impact | Required mitigation before merge approval |
| --- | --- | --- |
| Upstream cache, checkpoint, or endpoint changes invalidate a prior-stage contract that the closed stages did not record. | The merge integrates a contract-breaking change without a rework. | The Architect's pre-merge review must surface every contract gap the triage table lists. The Manager decides rework vs known gap. The Stage 12 and Stage 13 post-closure contracts are part of the lens. |
| An upstream change touches a hybrid-mode source file the closed stages did not test. | The regression rerun passes locally but the production path breaks. | The focused exporter coverage and the ctest rerun must include the affected file. The T114 and T114a floors remain closure contracts. |
| An upstream change touches a Stage 13 endpoint adapter and breaks an E13-01..E13-16 parity row. | Public endpoint parity evidence fails. | The Stage 13 endpoint probe rerun must include the affected row. The Developer records the failing row, the request payload, and the contract the row covers. |
| An upstream change renames a public metric, a bounded diagnostic field, the MTMD placeholder path, or the bounded `cache metadata:` format. | Operator dashboards, log queries, and route adapters break. | The Architect must record the upstream rename in the pre-merge report with the proposed mapping. The Manager decides whether the rename is a rework, a known gap, or a silent integration with a documented mapping. |
| The merge tool produces a fast-forward even though INTEGRATE decisions require a merge commit. | The local adjustments are silently skipped. | The Developer must not allow a fast-forward when the pre-merge analysis lists at least one INTEGRATE or REWORK-REQUIRED decision. The merge log records the merge strategy actually used. |
| A reworked stage closes after the Stage 14 regression rerun. | The Stage 14 regression rerun is stale. | The Stage 14 regression rerun is rerun after every rework closes. The merge log records the date and the rerun count. |
| The pre-merge analysis is reopened after the merge has already started. | The merge log and the triage table are out of date. | The Developer stops the merge, reopens the pre-merge analysis, and the Architect re-reviews the report. The merge restarts only after the re-review verdict. |
| The T114 combined or T114a product-only coverage floor drops below the threshold after the merge. | The Stage 14 closure contract is unmet. | The Developer reopens the coverage evidence and records the drop in the merge log. The Manager decides whether the drop is a rework, a known gap, or a silent integration with a follow-up plan. |
| The `origin/upstream_master` ref is stale. | The cycle merges from a stale fork point. | Per D1, the Developer verifies `origin/upstream_master` ref currency against the actual upstream `master` via `git ls-remote https://github.com/ggml-org/llama.cpp.git master` (or the GitHub REST API endpoint) before the merge opens. A stale ref is a known gap recorded in the merge log; the Manager decides whether to fast-forward or merge with the gap. |
| An upstream change exposes a path the pre-existing `test-stage10-policy-lru` semantic bug covers. | The cycle may treat the test bug as a closure blocker. | The triage records the upstream commit as a DEFER or INTEGRATE with a one-line reason that references the tracked-separately record. The test bug is not a Stage 14 rework trigger. |
| An upstream change resumes the synthetic Stage 12 V2/V3/non-MTP matrix expansion. | The 2026-06-09 close-at-current-progress decision is silently reversed. | The triage records the upstream commit as a rework candidate for Stage 12. The cycle does not lift the pause; lifting requires a separate Manager decision. |

The exclusions, requirement traceability, and handoff sections
for this part are in
[part-06a-exclusions-traceability-and-handoff.md](part-06a-exclusions-traceability-and-handoff.md).
