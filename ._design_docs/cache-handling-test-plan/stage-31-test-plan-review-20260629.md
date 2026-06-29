# Stage 31 test-plan review 2026-06-29

VERDICT: PASS

## Scope

Review subject:

- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-test-plan/part-35-stage31-hybrid-cache-misbehavior.md`

Inputs checked:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase31-design.md`
- `._design_docs/cache-handling-phase31-design/part-01-design-review-20260629.md`
- `._design_docs/cache-handling-phase31-implementation.md`
- `._design_docs/cache-handling-phase31-implementation/part-03-probe-evidence-20260629.md`
- `._design_docs/cache-handling-phase31-implementation/part-04-implementation-evidence-20260629.md`
- `._design_docs/cache-handling-phase31-implementation/part-05-implementation-review-20260629.md`
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`
- `tests/test-cache-controller.cpp`
- `tools/server/server-context.cpp`

No tests were executed. This is a plan review only.

## Findings

No blocking or non-blocking findings.

## Checklist

Scope is current and generic. Part 35 is explicitly a validation plan, not
execution evidence, and it scopes Stage 31 to the implemented namespace,
metrics, checkpoint-safety, and Stage 30 wording fixes. It avoids adding new
model-backed automation or graph redesign to the closure gate.

Clean build and evidence rules are clear. TP-31-BLD-01 requires a clean Release
`test-cache-controller` build, binary freshness within 10 minutes, build log,
mtime, size, and path. The report rules require a fresh per-session report and
separate non-durable output root.

Row coverage is sufficient:

- exact repeat: TP-31-NS-01 maps to
  `test_stage31_namespace_uses_runtime_compatibility_only`;
- near-prefix: TP-31-NS-02 maps to the same test and requires safe prefix
  candidate evidence;
- bounded namespace count: TP-31-NS-03 maps to
  `test_stage31_namespace_cardinality_bounded_for_prompt_variants`;
- isolation: TP-31-NS-04 keeps the existing namespace isolation tests in the
  same binary as required evidence;
- metric shape: TP-31-MET-01 and TP-31-MET-02 cover HELP/TYPE uniqueness,
  bounded `method`, bounded `scope="all"`, and absence of raw namespace labels;
- checkpoint safety: TP-31-CHK-01 requires the existing checkpoint regression
  tests to pass in the same controller run and allows only an INFO note for no
  new Stage 31-specific corrupt-checkpoint case;
- Stage 30 wording: TP-31-DOC-01 requires citation of the corrected Stage 30
  report text.

The full live Stage 30 rerun decision is explicit and acceptable. The plan says
the rerun is not required for Stage 31 closure if the focused clean-build,
direct-run, ctest, namespace, metrics, checkpoint, and wording rows pass. It
also preserves the rerun as advisory comparison confidence, or required only if
Manager changes the closure gate. That matches the implementation review's
remaining-risk note.

Report and evidence format is clear. Part 35 names the fresh durable report
path, non-durable artifact root, mandatory command transcripts, row-to-source
mapping, checkpoint safety source list, Stage 30 citation, and final status
counts. It does not rely on stale Stage 30 execution as Stage 31 pass evidence.

## Gate

Stage 31 test plan is ready for Manager test-plan gate. QA execution should not
start until Manager accepts the plan and confirms whether the live Stage 30
rerun remains advisory or becomes required closure evidence.
