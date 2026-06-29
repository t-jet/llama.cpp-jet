# Stage 31 design review 2026-06-29

VERDICT: PASS

## Scope

Review subject:

- `._design_docs/cache-handling-phase31-design.md`

Inputs checked:

- `._design_docs/document-index.md`
- `._design_docs/.manager-inputs/manager-input-20260629-stage31-hybrid-cache-misbehavior.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `._design_docs/cache-handling-architecture/part-08-stage-13-endpoint-compatibility-corrections.md`
- `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-graph.h`

This is an independent design review. No production code was approved or
changed in this session.

## Gate status

PASS. The design is ready for Developer implementation planning.

No blocking or non-blocking findings remain open.

## Traceability review

The design traces the Stage 31 intake symptoms to the right system boundary:
HTTP prompt preparation, `prepared_prompt_metadata`, namespace computation,
branch forest lookup, save admission, and Prometheus emission.

Architecture alignment:

- Architecture part 2 defines namespace as runtime compatibility. The design
  adopts that rule by separating allowed compatibility inputs from prompt-local
  validation inputs.
- Architecture part 2 requires candidates to validate before restore. The
  design keeps token, checksum, descriptor metadata, pair-state, payload-kind,
  and checkpoint-boundary validation mandatory after namespace broadening.
- Architecture part 8 requires endpoint parity without cache-specific request
  fields. The design keeps the investigation inside internal metadata and
  server-side probes.
- Architecture part 9 requires chat prompt-span boundaries. The design treats
  those boundaries as validation inputs, not namespace inputs.

Requirement alignment:

- R80-R83a: Stage 31 directly protects shared branch reuse by checking whether
  compatible traffic is split into prompt-local namespaces.
- R90-R92: The design prioritizes safe fallback and validation over hit rate.
- R94-R98: The probes measure exact hits, prefix candidates, checkpoint hits,
  cold payload behavior, and prompt processing reuse.
- R99-R106: The regression plan covers exact repeat, near-prefix, namespace
  isolation, checkpoint-dependent behavior, and bounded metric evidence.

## Namespace decision

The namespace decision is safe and complete for implementation planning.

Current code confirms the design risk. `compute_namespace_id(metadata)` appends
`metadata.compatibility_key`, `metadata.preparation_id`, degraded reason, and
every boundary type, span, checksum, and metadata string before hashing
(`server-cache-hybrid.cpp:4243`). Restore and save both use that derived
namespace (`server-cache-hybrid.cpp:4790`, `server-cache-hybrid.cpp:5198`).
The branch forest then filters lookup candidates by exact namespace
(`server-cache-graph.cpp:200`, `server-cache-graph.cpp:221`).

The design's correction rule is the right one: namespace must describe stable
runtime compatibility, while prompt spans, checksums, role labels, protected
flags, and diagnostic text remain validation-only data. That keeps cross-prompt
reuse possible without removing the restore safety checks.

`preparation_id` is left to Developer planning only under a narrow rule: it may
stay in namespace if it names a stable preparation ABI, and must move to
validation or diagnostics if it is request-local. That is acceptable because the
design gives the decision criterion and requires probe evidence before the
production fix.

## Probe sufficiency

The probe set is sufficient and correctly ordered before any production fix:

- P31-01 proves exact-repeat reuse and separates zero-hit behavior from a cold
  server explanation.
- P31-02 proves namespace cardinality under one model/config fixture.
- P31-03 checks whether Stage 29/30 workload labels survive chat templating at
  token level.
- P31-04 compares save and lookup namespace snapshots around `tx_save()` and
  `tx_restore()`.
- P31-05 checks Prometheus shape and cardinality.

Developer implementation planning must run or implement these probes first. If
a probe contradicts the expected root cause, the plan should record that result
before changing production behavior.

## Metrics review

The design covers both metric cardinality and HELP/TYPE defects.

Current code emits one HELP and TYPE block for each labeled cache sample through
the local metric writer lambdas (`server-context.cpp:4346`). Branch lookup and
namespace metrics also expose raw namespace ids as public labels
(`server-context.cpp:4412`, `server-context.cpp:4448`). The design requires one
HELP and one TYPE line per metric name, bounded public labels, and retention of
raw namespace ids only in stats JSON or opt-in diagnostics. That is the right
public observability contract.

## Stage 30 wording correction

The design covers the wording correction. It identifies the Stage 30 "cold
start, no hits yet" explanation as incomplete, then adds TP31-06 requiring a
durable correction that says exact-repeat rows can produce in-cycle hits.

Developer planning should name the exact durable target for that correction:
either the Stage 30 report follow-up note or the Stage 31 implementation
documentation, with the Stage 30 report linked if it is amended.

## Handoff

Next owner: Developer.

Next gate: implementation planning.

Required Developer planning content:

- Run or add probes P31-01 through P31-05 before any production fix.
- Document the observed root cause and the smallest production fix.
- Decide `preparation_id` using the design's stable-ABI versus request-local
  rule.
- Keep prompt-local metadata out of public Prometheus labels.
- Add regression coverage for TP31-01 through TP31-06.
- Record the Stage 30 wording correction in durable docs.

Implementation planning may proceed without another Architect design review
unless the probe results invalidate the namespace decision or require a broader
behavior change than the current design permits.
