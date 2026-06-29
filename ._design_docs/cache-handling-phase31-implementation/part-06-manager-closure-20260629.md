# Stage 31 Manager closure 2026-06-29

Verdict: PASS

## Scope

Stage 31 investigated the Stage 30 hybrid cache symptoms: zero cache hits,
about 170 namespaces, raw namespace labels in Prometheus output, and duplicate
HELP/TYPE emission risk.

## Gate evidence

- Manager intake: `._design_docs/.manager-inputs/manager-input-20260629-stage31-hybrid-cache-misbehavior.md`
- Design review: `cache-handling-phase31-design/part-01-design-review-20260629.md`, PASS.
- Implementation-plan review: `cache-handling-phase31-implementation/part-02-implementation-plan-review-20260629.md`, PASS.
- Probe evidence: `cache-handling-phase31-implementation/part-03-probe-evidence-20260629.md`.
- Implementation evidence: `cache-handling-phase31-implementation/part-04-implementation-evidence-20260629.md`.
- Implementation review: `cache-handling-phase31-implementation/part-05-implementation-review-20260629.md`, PASS.
- QA execution: `.test_reports/test-report-20260629-13-stage31-01.md`, PASS=11, FAIL=0, BLOCKED=0, SKIP=0.
- Developer test-results review: `.test_reports/test-report-20260629-13-stage31-01-developer-review.md`, PASS.

## Manager decisions

D31-CLOSURE-01: The focused Stage 31 QA evidence is sufficient for closure.
The full live Stage 30 comparison rerun stays advisory, not required.

D31-CLOSURE-02: Stage 30 report wording is corrected. A cold server process can
still produce in-cycle hits when exact-repeat prompts appear after their first
occurrence.

D31-CLOSURE-03: Stage 31 closes with no product bug left open. A future
model-backed comparison can be opened as a separate stage if needed.

## Product result

Root cause: `compute_namespace_id(metadata)` mixed stable runtime compatibility
with prompt-local validation data. That split compatible prompts into many
namespaces before validation and reuse could happen.

Fix result:

- Metadata namespace hashing now uses stable runtime compatibility plus
  `metadata.compatibility_key`.
- Prompt-local spans, checksums, labels, degraded reasons, and preparation IDs
  remain validation and diagnostics data.
- Prometheus cache metrics now aggregate bounded labels and emit one HELP/TYPE
  block per metric name.
- Raw namespace IDs remain available through JSON/debug stats, not as public
  high-cardinality metric labels.

## Test result

Binding Stage 31 validation passed:

- Clean Release configure: PASS.
- Clean Release `test-cache-controller` build: PASS.
- Direct `test-cache-controller.exe` run: PASS, 142 tests.
- `ctest --test-dir build -C Release -R cache -V`: PASS, 1/1.
- `git diff --check`: PASS in Developer evidence.

The debug build path without `--config Release` still has the known debug-only
const-mutex compile issue at `server-cache-hybrid.cpp:4601`; it is outside the
approved Stage 31 Release evidence path.

## Closure checklist

- Design, implementation, test plan, QA report, Developer review, and index
  agree on Stage 31 closed PASS state.
- No unresolved review findings remain.
- No Stage 31 FAIL or BLOCKED test rows remain.
- Follow-up live Stage 30 rerun is advisory only.

## Handoff

Stage 31 is closed. No next owner is required.
