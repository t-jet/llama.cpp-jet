# Stage 9 design: testability, traceability, exclusions, and risks -- Part 5

Source: [../cache-handling-phase9-design.md](../cache-handling-phase9-design.md)

## Testability

Stage 9 implementation planning must include focused tests that do not require
full model-backed inference for every branch.

Required focused coverage:

- workload profile detection for plain transformer, checkpoint-dependent, and
  target plus draft modes
- checkpoint descriptor admission and rejection
- exact-blob preference for `plain_transformer`
- checkpoint-first ranking for `checkpoint_dependent`
- exact blob as accelerator or root for checkpoint-dependent paths
- boundary-attached checkpoint placement
- fallback when prepared-prompt metadata is missing
- token, checksum, and boundary validation mismatch
- metadata-only checkpoint re-materialization
- cold promotion and demotion of checkpoint descriptors
- target/draft pair mismatch rejection for checkpoint payloads
- metric shape and reason labels without prompt or path leakage

Required integration coverage:

- public HTTP or equivalent task flow showing boundary metadata reaches the
  cache controller
- model-backed checkpoint-first restore for at least one checkpoint-dependent
  fixture when available
- target plus draft checkpoint save and restore when local fixtures support it
- safe fallback for unsupported multimodal or draft combinations

Deterministic seams remain required for clocks, usage updates, graph lookup,
store backends, and I/O worker outcomes.

## Requirement traceability

| Requirement | Stage 9 disposition |
| --- | --- |
| R5 | Covered. Exact blobs remain supported and are preferred for plain transformers. |
| R6 | Covered. Checkpoints are canonical branch structure for checkpoint-dependent profiles. |
| R7 | Covered through checkpoint participation in hot and cold residency. |
| R8, R8a, R8b | Constrained. Stage 9 uses Stage 8 metadata residency and budget rules. |
| R9, R10 | Covered. Checkpoint payloads preserve target/draft coupling. |
| R11 | Covered. Plain-transformer strategy preserves exact-blob efficiency. |
| R12 | Covered. Checkpoint-dependent strategy prefers checkpoint nodes. |
| R13 | Covered through target plus draft overlay and MTP namespace isolation. |
| R14 | Covered. Unsafe or unavailable checkpoint restores fall back safely. |
| R27-R33 | Covered. Boundary-aware checkpoint placement uses prepared metadata and degrades with diagnostics. |
| R37-R39c | Covered or constrained by earlier stages. Stage 9 applies descriptor separation and re-materialization to checkpoint payloads. |
| R40-R48 | Covered by branch-node and descriptor interface requirements. |
| R49-R56 | Constrained. Stage 9 uses Stage 6 cold-store behavior for checkpoint payloads and preserves async I/O. |
| R57-R60 | Constrained. Stage 9 extends residency ranking to checkpoints without adding a new policy. |
| R61-R68 | Covered for Stage 9 events through checkpoint metrics, restore failure counters, and fallback diagnostics. |
| R69-R73 | Covered. Checkpoints become first-class branch-node payloads and traversal does not require hot bytes. |
| R74-R83 | Constrained. Stage 9 preserves Stage 7 and Stage 8 branch graph sharing rules. |
| R83a | Constrained. Equivalent branch deduplication remains Stage 8 behavior and applies to checkpoint paths. |
| R84-R86 | Covered. Checkpoint-dependent profiles use checkpoint nodes as canonical continuity points. |
| R87-R89 | Constrained. Multimodal reuse requires namespace and media-span validation; unsupported cases fail explicitly. |
| R96 | Covered. Checkpoint-based branch hit rate is measurable through Stage 9 metrics. |
| R101 | Covered. Boundary propagation is required integration evidence for checkpoint placement. |
| R103 | Covered. Checkpoint cold offload and restore must be tested. |
| R106 | Covered. Checkpoint-dependent behavior must be tested. |
| R117 | Covered. The design preserves slot state, checkpoint, prompt-cache, and target/draft terminology. |
| R128 | Covered. Deterministic tests are required for checkpoint-first restore behavior. |

Requirements outside this table remain governed by earlier accepted stage
designs or by Stage 10 hardening and operator-readiness work.

## Exclusions and deferrals

Stage 9 explicitly defers:

- Stage 10 security review completion and operator documentation
- benchmark suite expansion beyond the metrics needed to measure checkpoint
  branch hit rate
- public cache inspection or control endpoints
- new request payload fields for cache markers
- cross-restart restore guarantees
- new CLI budget flags unless Manager opens a separate CLI surface decision
- a public workload-profile selector

These are not implementation gaps for Stage 9 unless a later review finds that
one of them is required to make checkpoint restore safe.

## Risks

| Risk | Impact | Required mitigation before implementation approval |
| --- | --- | --- |
| Runtime capability detection is incomplete. | Unsafe reuse across model families or context modes. | Define exact detection sources and negative tests for unknown modes. |
| Boundary metadata is unavailable for important routes. | Lower hit rate or misplaced checkpoints. | Emit degraded diagnostics and fall back to token or position rules. |
| Checkpoint weighting starves exact blobs. | Plain-transformer workloads regress. | Keep exact-blob preference for `plain_transformer` and test ranking. |
| MTP and separate-draft modes share pair state but differ in compatibility. | Cross-mode restore corruption. | Keep speculative-mode identity in the namespace and reject mismatches. |
| Cold promotion failure happens after partial live mutation. | Slot can enter an invalid target/draft state. | Require promotion and validation before restore application. |
| Metrics expose prompt or path material. | Observability leaks sensitive data. | Restrict labels to profile, residency, pair state, result, and reason enums. |

## Review readiness

The Stage 9 design is reviewable when:

- the entry document and all part files stay under 300 lines
- `document-index.md` links the Stage 9 design
- the gate status does not approve implementation planning
- open risks are visible to the next reviewer and Manager

Current state: ready for independent Architect design review.
