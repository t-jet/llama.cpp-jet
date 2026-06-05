# Stage 11 design: merge log, constraints, observability, testability, risks, exclusions, traceability, and handoff -- Part 6

Source: [../cache-handling-phase11-design.md](../cache-handling-phase11-design.md)

## Goal

This part records the merge log format, the constraints Stage 11 keeps
inherited from prior stages, the observability and testability rules
the merge must not break, the risks, the exclusions, the requirement
traceability, and the handoff state. It is the durable record the
Stage 11 implementation log links to.

## Merge log format

The merge log is a durable artifact. The Developer owns the merge log
and the Architect reviews it. The merge log is a separate report, not a
part file of this design. The design prescribes the required sections
and the minimum content per section.

### Required sections

1. Cover and metadata
   - Stage number, design baseline link, date opened, date closed
   - Owner (Developer), reviewer (Architect), approver (Manager)
   - Upstream remote name, upstream ref, fork point SHA, integration
     branch name, integration branch tip SHA on close
2. Decisions
   - The list of in-scope upstream commits and the final triage
     decision for each, with a one-line reason that names a prior-stage
     contract from Part 1
   - The list of any NO-OP, INTEGRATE, or DEFER decision that the
     Architect or Manager changed during the merge, with the date and
     reason for the change
3. Deferred upstream commits
   - Upstream SHA, commit subject, the contract the commit would have
     affected, the reason for the deferral, and the follow-up owner
   - The expected cycle or condition that would lift the deferral
4. Known gaps
   - The list of contract gaps the merge exposed but did not close
     through a rework
   - Each known gap has a follow-up owner, a target cycle, and a link
     to the affected prior-stage contract
   - A known gap that the Manager escalates to a rework is moved out
     of this section and into the reworks list
5. Conflicts encountered
   - Each conflict the merge tool surfaced, with the upstream SHA, the
     local path, the local resolution, and the prior-stage contract the
     resolution preserves
   - The merge tool choice and the conflict resolution policy the
     Developer followed
6. Reworks opened
   - For each rework, the affected stage, the upstream change that
     triggered it, the rework part file link, and the rework status on
     the date the merge log was last updated
   - A rework that is still open at the date of the merge log update
     is recorded with its current status, not with a closure date
7. Regression evidence
   - Link to the Stage 11 test report and to the ctest, coverage, and
     MTP probe artifacts the Developer produced
   - The T114 combined-rate verdict, the T114a product-only verdict,
     the T115 per-file aggregation verdict, and the T121 public
     checkpoint admission verdict, with the cited artifact section
     for each
8. Closure status
   - The set of architecture exit criteria from Part 1 that the
     integration branch has met on the date the merge log was last
     updated
   - The set of exit criteria that are still open and the follow-up
     action the Manager assigned

A merge log that is missing any of the sections above fails the
Architect review and is sent back to the Developer for a rewrite.

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
| Bounded diagnostic fields are stable | Stage 10 | Bounded enums keep the log volume bounded. |
| T114 combined 80% floor is a closure contract | Stage 10, test plan Part 12 | The coverage floor is not a guideline. |
| T114a product-only 70% floor is a closure contract | Test plan Part 13, Stage 11 onward | Test files must not mask product gaps. |
| T115 per-file aggregation rule is stable | Test plan Part 12, Part 13 | The per-file table is the source of truth for the coverage verdict. |
| T121 public checkpoint admission row is exposed | Stage 10 implementation Part 9 | Operators read the row to confirm the checkpoint path is exercised. |
| Stage 5 speculative-mode namespace isolation is stable | Architecture Part 6 | Target-only, separate draft, MTP-on-target, and MTP-on-separate-draft descriptors must not reuse each other's entries. |
| Stage 7 multi-namespace shared budgets are stable | Architecture Part 2 | Per-namespace quota is a future extension, not a current contract. |
| Branch metadata budget is configurable and enforced | Architecture, R8b, R21a | Branch metadata exhaustion must not silently bypass the budget. |

A constraint that an upstream change would weaken is a rework
candidate, not a silent integration.

## Observability rules

The merge must keep the observability shapes from Stage 10 intact. The
Developer does not rename a public metric, drop a bounded label, or
add a new public metric during the merge. The following rules apply:

1. The four `cache_checkpoint_*` rows from Stage 10 implementation
   Part 9 remain exposed through the public /metrics endpoint when a
   hybrid-mode server with MTP or checkpoint-capable draft is
   exercised.
2. The R61-R68 metric set, the bounded labels, and the absence of
   sensitive material in labels remain in force. The Developer does
   not add a label whose value could carry request material, prompt
   text, or model paths.
3. Bounded diagnostic events for failure, fallback, unsupported
   configuration, marker validation, cold-store failure, namespace
   rejection, pair-state rejection, and restore failure remain in
   force. The Developer does not rename a diagnostic event.
4. The hot, cold, and branch-metadata byte gauges and the
   cold-operation latency buckets remain in force. The Developer does
   not remove a gauge or bucket the upstream changes do not justify.
5. The public /metrics endpoint does not gain a cache inspection
   endpoint, a per-branch metrics endpoint, or a per-slot metrics
   endpoint. Operators read the public Prometheus set as is.

The Architect reviews the observability impact of every INTEGRATE,
REWORK-REQUIRED, DEFER, and REVERT decision in the pre-merge report.

## Testability rules

The merge must keep the testability contracts from the prior stages.
The following rules apply:

1. The deterministic seams from Stage 10 remain in force. The
   Developer does not remove a deterministic clock, a fake store
   backend, a deterministic graph lookup, or a deterministic worker
   completion order.
2. The focused C++ test binaries that the closed stages used remain
   in the build. The Developer does not delete a focused test binary
   during the merge, even when the upstream change makes the test
   surface smaller.
3. The focused exporter coverage command family and the citation
   rules from the test plan Part 13 remain in force. The Developer
   does not change the citation rules during the merge.
4. The ctest command family used by the closed stages remains the
   primary regression command family. The Developer does not replace
   ctest with another test runner during the merge.
5. The Architect's per-file coverage target from the Stage 10 review
   remains an internal target. The Developer does not lower the
   per-file target during the merge.

## Risks

| Risk | Impact | Required mitigation before merge approval |
| --- | --- | --- |
| Upstream cache or checkpoint changes invalidate a prior-stage contract that the closed stages did not record. | The merge integrates a contract-breaking change without a rework. | The Architect's pre-merge review must surface every contract gap the triage table lists. The Manager decides rework vs known gap. |
| An upstream change touches a hybrid-mode source file the closed stages did not test. | The regression rerun passes locally but the production path breaks. | The focused exporter coverage and the ctest rerun must include the affected file. The T114 and T114a floors remain closure contracts. |
| An upstream change renames a public metric or a bounded diagnostic field. | Operator dashboards and log queries break. | The Architect must record the upstream metric or field change in the pre-merge report with the proposed mapping. The Manager decides whether the rename is a rework, a known gap, or a silent integration with a documented mapping. |
| The merge tool produces a fast-forward even though INTEGRATE decisions require a merge commit. | The local adjustments are silently skipped. | The Developer must not allow a fast-forward when the pre-merge analysis lists at least one INTEGRATE or REWORK-REQUIRED decision. The merge log records the merge strategy actually used. |
| A reworked stage closes after the Stage 11 regression rerun. | The Stage 11 regression rerun is stale. | The Stage 11 regression rerun is rerun after every rework closes. The merge log records the date and the rerun count. |
| The pre-merge analysis is reopened after the merge has already started. | The merge log and the triage table are out of date. | The Developer stops the merge, reopens the pre-merge analysis, and the Architect re-reviews the report. The merge restarts only after the re-review verdict. |
| The T114 combined or T114a product-only coverage floor drops below the threshold after the merge. | The Stage 11 closure contract is unmet. | The Developer reopens the coverage evidence and records the drop in the merge log. The Manager decides whether the drop is a rework, a known gap, or a silent integration with a follow-up plan. |

## Exclusions

Stage 11 does not include:

- A change to the architecture, the requirements, or the prior-stage
  designs as part of the merge. A change to a prior-stage design is
  the affected stage's rework, not a Stage 11 design change.
- A change to the default cache path or to the public CLI surface.
- A new public cache inspection endpoint, a new cache metric, or a
  new diagnostic field.
- An upstream CI matrix adoption. The Stage 11 closure contract is
  the prior-stage contracts, not the upstream project's CI matrix.
- A replacement of local fork tests with upstream tests. The
  Developer does not delete a closed-stage focused test binary during
  the merge.
- A history rewrite of the integration branch. A failed merge is
  closed with a reverse merge, an explicit `git reset` to the fork
  point, or a new merge attempt from the fork point.
- A pre-merge change to the fork point. A change to the fork point
  is recorded in the merge log and reopens the pre-merge analysis.

## Requirement traceability

The Stage 11 design does not introduce new requirements. It records
how the merge and rework preserve the requirements that the prior
stages already accepted. The table below names the requirement
ranges the merge must keep in force and the part of this design that
keeps them in force.

| Requirement range | Stage 11 disposition |
| --- | --- |
| Activation and compatibility (R1-R4) | Covered by the legacy default and hybrid opt-in constraints in Part 6 and the prior-stage contracts in Part 1. |
| Hybrid model and model-family awareness (R5-R14) | Covered by the namespace and pairing constraints in Part 6 and the Stage 5 and Stage 9 contract rows in Part 1. |
| Non-destructive hits, reuse-aware eviction, protected roots (R15-R26) | Covered by the LRU and protected-root contract row in Part 1 and the byte-accounted LRU constraint in Part 6. |
| Prepared-prompt boundaries (R27-R33) | Covered by the prepared-prompt boundary contract row in Part 1 and the boundary placement constraint in Part 6. |
| Correctness and fallback (R34-R36, R36a-R36d, R90-R92, R120-R124) | Covered by the atomic target and draft restore contract row in Part 1, the descriptor validation contract row in Part 1, and the bounded diagnostic constraint in Part 6. |
| Payload separation, cold layer, hot/cold residency (R37-R60, R93-R98) | Covered by the hot and cold residency contract row, the cold store integrity contract row, and the descriptor validation contract row in Part 1. |
| Observability (R61-R68) | Covered by the public Prometheus metric set and label shape constraint in Part 6. |
| Shared branch graph and slot-independent reuse (R69-R83, R83a) | Covered by the branch forest, namespace validation, slot references, and equivalent-branch deduplication contract rows in Part 1. |
| Metadata-only branch nodes and payload/pruning lifecycle (R38a-R38c, R71a-R71e, R76a, R79a-R79b, R55a) | Covered by the metadata-only nodes and re-materialization contract row and the cold cleanup ownership contract row in Part 1. |
| Validation mismatch and mismatch-parent selection (R36a-R36d, R39a-R39c, R71e, R123a) | Covered by the metadata-only nodes and re-materialization contract row in Part 1. |
| Budget accounting and pruning preference (R8a, R8b, R21a, R57a-R57e) | Covered by the branch metadata budget constraint in Part 6. |
| Eviction policy evolution (R20a, R20b) | Covered by the byte-accounted LRU contract row in Part 1. |
| Code quality and best practices (R130, R131) | Constrained by the no-history-rewrite exclusion in Part 6 and the no-broad-redesign rule in Part 4. |
| Multimodal safety (R87-R89) | Covered by the namespace and pairing contract rows in Part 1. |
| Testability and verification (R99-R106, R125-R129) | Covered by the testability rules in Part 6. |
| Security review and abuse handling (R121-R123, R132-R133) | Covered by the cold store integrity contract row in Part 1, the OWASP mitigations row in Part 1, and the cold store root containment constraint in Part 6. |
| T114 combined 80% floor and T114a product-only 70% floor | Covered by the coverage contract rows in Part 1 and the coverage constraint in Part 6. The T114a row is a new closure contract for Stage 11 onward. |
| T115 per-file aggregation rule | Covered by the per-file aggregation contract row in Part 1 and the coverage report citation rules in Part 5. |
| T121 public checkpoint admission row | Covered by the checkpoint admission public /metrics row contract row in Part 1 and the MTP probe evidence rules in Part 5. |

Requirements not listed here remain governed by the prior stage
designs. The Stage 11 merge does not re-derive the prior stages'
requirement coverage. A requirement that the prior stages did not
trace is not a Stage 11 closure contract.

## Handoff

This design opens the implementation-planning gate for Stage 11. The
next gate is implementation planning. The next owner is the Developer.

The Developer is responsible for:

- Opening the pre-merge report described in Part 2
- Running the merge execution plan described in Part 3
- Running the regression test reruns described in Part 5
- Writing the merge log described in Part 6
- Recording the Stage 11 implementation plan in the Stage 11
  implementation log entry doc

The Architect is responsible for reviewing the pre-merge report, the
merge log, and the Stage 11 implementation plan. The Manager is
responsible for approving the rework-trigger decision, the known-gap
acceptance decision, and the Stage 11 closure decision.

The Stage 11 design is approved when the Architect records the design
review verdict and the Manager records the design-gate decision. The
implementation-planning gate opens only after the design-gate
decision is PASS.
