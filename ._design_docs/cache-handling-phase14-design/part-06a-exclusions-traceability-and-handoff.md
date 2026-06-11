# Stage 14 design: exclusions, requirement traceability, and handoff -- Part 6a

Source: [../cache-handling-phase14-design.md](../cache-handling-phase14-design.md)
Split from: [part-06-merge-log-constraints-and-traceability.md](part-06-merge-log-constraints-and-traceability.md)

## Goal

This part closes the Stage 14 design with the exclusions, the
requirement traceability table, and the handoff state. It is
split from Part 6 to keep each part file under the 300-line cap.

## Exclusions

Stage 14 does not include:

- A change to the architecture, the requirements, or any prior
  stage design as part of the merge. A change to a prior-stage
  design is the affected stage's rework, not a Stage 14 design
  change.
- A change to the default cache path or to the public CLI
  surface.
- A new public cache inspection endpoint, a new cache metric,
  or a new diagnostic field.
- A change to the public Prometheus metric set or the bounded
  diagnostic field set.
- A change to the MTMD placeholder path.
- A change to the diagnostic-source namespace isolation rule.
- A change to the bounded `cache metadata:` format at task
  launch.
- An upstream CI matrix adoption. The Stage 14 closure
  contract is the prior-stage contracts, not the upstream
  project's CI matrix.
- A replacement of local fork tests with upstream tests. The
  Developer does not delete a closed-stage focused test binary
  during the merge.
- A history rewrite of the integration branch. A failed merge
  is closed with a reverse merge, an explicit `git reset` to
  the fork point, or a new merge attempt from the fork point.
- A pre-merge change to the fork point. A change to the fork
  point is recorded in the merge log and reopens the pre-merge
  analysis.
- A fix to the `test-stage10-policy-lru` pre-existing semantic
  bug. The bug is out of Stage 14 scope and is tracked
  separately.
- A resumption of the synthetic Stage 12 V2/V3/non-MTP matrix
  expansion. The 2026-06-09 close-at-current-progress decision
  keeps the expansion paused; lifting the pause requires a
  separate Manager decision.

If execution uncovers a design gap that requires behavior
change, the Architect opens a correction or a new stage. The
test report alone does not change durable behavior.

## Requirement traceability

The Stage 14 design does not introduce new requirements. It
records how the merge and rework preserve the requirements that
the prior stages already accepted. The table below names the
requirement ranges the merge must keep in force and the part of
this design that keeps them in force.

| Requirement range | Stage 14 disposition |
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
| Code quality and best practices (R130, R131) | Constrained by the no-history-rewrite exclusion in this part and the no-broad-redesign rule in Part 4. |
| Multimodal safety (R87-R89) | Covered by the namespace and pairing contract rows in Part 1 and the MTMD placeholder path constraint in Part 6. |
| Testability and verification (R99-R106, R125-R129) | Covered by the testability rules in Part 6. |
| Security review and abuse handling (R121-R123, R132-R133) | Covered by the cold store integrity contract row in Part 1, the OWASP mitigations row in Part 1, and the cold store root containment constraint in Part 6. |
| T114 combined 80% floor and T114a product-only 70% floor | Covered by the coverage contract rows in Part 1 and the coverage constraint in Part 6. The T114a row is a closure contract from Stage 11 onward. |
| T115 per-file aggregation rule | Covered by the per-file aggregation contract row in Part 1 and the coverage report citation rules in Part 5. |
| T121 public checkpoint admission row | Covered by the checkpoint admission public /metrics row contract row in Part 1 and the MTP probe evidence rules in Part 5. |
| Stage 12 stress harness outputs S01..S08 and L01..L03 | Covered by the stress harness contract row in Part 1 and the stress harness preflight evidence rule in Part 5. |
| Stage 12 benchmark outputs B01..B08 | Covered by the benchmark harness contract row in Part 1 and the benchmark harness preflight evidence rule in Part 5. |
| Stage 12 configuration matrix | Covered by the configuration matrix contract row in Part 1 and the preflight shape check in Part 5. |
| Stage 12 public Prometheus metric shape | Covered by the public Prometheus metric shape contract row in Part 1 and the observability rules in Part 6. |
| Stage 13 endpoint parity rows E13-01..E13-16 | Covered by the endpoint parity contract row in Part 1 and the Stage 13 endpoint probe evidence rule in Part 5. |
| Stage 13 MTMD placeholder path | Covered by the MTMD placeholder path contract row in Part 1 and the constraint in Part 6. |
| Stage 13 diagnostic-source namespace isolation | Covered by the diagnostic-source namespace isolation contract row in Part 1 and the constraint in Part 6. |
| Stage 13 bounded `cache metadata:` format at task launch | Covered by the bounded `cache metadata:` format contract row in Part 1 and the constraint in Part 6. |
| Stage 13 transcript route coverage | Covered by the transcript route coverage contract row in Part 1 and the Stage 13 endpoint probe evidence rule in Part 5. |
| Stage 13 embedding cache exclusion | Covered by the embedding cache exclusion rationale contract row in Part 1 and the constraint in Part 6. |

Requirements not listed here remain governed by the prior stage
designs. The Stage 14 merge does not re-derive the prior stages'
requirement coverage. A requirement that the prior stages did
not trace is not a Stage 14 closure contract.

## Handoff

This design opens the implementation-planning gate for Stage 14.
The next gate is implementation planning. The next owner is the
Developer.

The Developer is responsible for:

- Opening the pre-merge report described in Part 2
- Running the merge execution plan described in Part 3
- Running the regression test reruns described in Part 5
- Writing the merge log described in Part 6
- Recording the Stage 14 implementation plan in the Stage 14
  implementation log entry doc

The Architect is responsible for reviewing the pre-merge report,
the merge log, and the Stage 14 implementation plan. The Manager
is responsible for approving the rework-trigger decision, the
known-gap acceptance decision, and the Stage 14 closure decision.

The Stage 14 design is approved when the Architect records the
design review verdict and the Manager records the design-gate
decision. The implementation-planning gate opens only after the
design-gate decision is PASS.
