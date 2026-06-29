# Stage 31 implementation plan review 2026-06-29

VERDICT: PASS

## Scope

Review subject:

- `._design_docs/cache-handling-phase31-implementation/part-01-implementation-plan.md`

Inputs checked:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase31-design.md`
- `._design_docs/cache-handling-phase31-design/part-01-design-review-20260629.md`
- `._design_docs/cache-handling-phase31-implementation.md`
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`
- `._design_docs/cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-cache-graph.cpp`

This is an implementation-plan review only. No production code was approved
beyond the plan gate, and no implementation work was done.

## Gate status

PASS. Developer may begin Stage 31 probes P31-01 through P31-05.

No blocking or non-blocking findings remain open.

## Review decisions

### Probe ordering

PASS. The plan starts with P31-01 through P31-05 before root-cause write-up,
before namespace changes, and before metric writer changes. It also says
production code changes are not authorized until those probes record evidence.
That matches the approved design handoff.

Acceptance condition for Developer: record probe evidence in the implementation
log before editing production behavior. If probes disprove the namespace
hypothesis, stop and request design update.

### Design scope

PASS. Planned production scope matches the approved design:

- namespace computation in `hybrid_cache_controller::compute_namespace_id`
- test-only save/lookup parity diagnostics when needed
- bounded public metrics and one HELP/TYPE block per metric name
- Stage 30 wording correction
- focused tests for exact repeat, near-prefix, isolation, checkpoint-dependent
  restore safety, metric shape, and wording evidence

The plan excludes graph topology redesign, prompt similarity cache, response
cache, public request schema changes, full Stage 30 rerun before root cause, and
commit or push. No hidden behavior changes are implied.

### `preparation_id` decision

PASS. The plan gives a safe decision process. It requires tracing all current
assignments, classifying each value as stable ABI or request-local, and keeping
`preparation_id` in the namespace only if every production value is stable ABI.

Current code supports the planning assumption. `server-context.cpp` assigns
`rendered-text-boundary-inference` and `token-position-fallback` as preparation
ids, along with degraded reasons such as rendered-text inference and minimal
token-span metadata. Those values look diagnostic or request-mapping related,
not runtime compatibility keys. The plan requires trace evidence before the
production change, so the decision is executable without guessing.

### Namespace safety

PASS. The plan keeps validation separate from namespace broadening. Current code
hashes `metadata.compatibility_key`, `metadata.preparation_id`,
`degraded_reason`, and every boundary span, checksum, and metadata string into
the namespace. It then filters branch candidates by exact namespace. The plan
limits namespace input to stable compatibility data while preserving token,
checksum, descriptor, pair-state, payload-kind, and checkpoint validation before
slot mutation.

That matches the architecture rule that namespace prevents unsafe cross-restore
between materially different runtimes, while restore still validates the chosen
candidate.

### Tests and evidence

PASS. Evidence requirements cover the review checklist:

| Required evidence | Plan coverage |
| --- | --- |
| exact repeat | P31-01, exact-repeat unit test |
| near-prefix | P31-01/P31-02, near-prefix unit test |
| namespace isolation | namespace ABI/config/profile tests |
| checkpoint-dependent profile | checkpoint validation after namespace broadening |
| metric shape | P31-05 and metric HELP/TYPE test |
| Stage 30 wording correction | ordered step 9 and durable wording target |

The plan also includes workload token-hash evidence for Stage 29/30 labels,
which is needed because chat templating can change the real token stream.

### Metric contract

PASS. Current `/metrics` writers emit HELP and TYPE from each sample-writing
lambda and expose raw namespace ids on branch lookup and namespace stats labels.
The plan requires one HELP and one TYPE line per metric name and bounded public
labels, while keeping raw namespace ids in stats JSON or opt-in debug output.
That preserves public metric stability without discarding diagnostic detail.

### Executability

PASS. Affected files are named, step order is clear, rollback is bounded to
namespace and metric writer changes, and build/test commands are listed with a
rule to record the actual local build path if `build` is absent.

## Required corrections

None.

## Handoff

Next owner: Developer.

Next gate: implementation execution. Developer may start P31-01 through P31-05
and must keep the Stage 31 implementation log current after each completed
probe or production fix.
