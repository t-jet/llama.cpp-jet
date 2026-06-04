# Stage 10 implementation review gate

Source: [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)
Review date: 2026-06-02
Reviewer: Architect agent
Gate: Implementation review
Verdict: REWORK

## Scope and gate status

This review covers the current uncommitted Stage 10 code, tests, and durable
docs against the accepted Stage 10 design and implementation plan.

Reviewed sources:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase10-design.md`
- `._design_docs/cache-handling-phase10-design/part-01-scope-surfaces-and-prerequisites.md`
- `._design_docs/cache-handling-phase10-design/part-02-observability-security-and-hardening.md`
- `._design_docs/cache-handling-phase10-design/part-03-validation-traceability-and-readiness.md`
- `._design_docs/cache-handling-phase10-implementation.md`
- `._design_docs/cache-handling-phase10-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase10-implementation/part-02-evidence-plan-and-risks.md`
- `._design_docs/cache-handling-phase10-implementation/part-06-implementation-evidence-20260602.md`
- `._design_docs/cache-handling-phase10-implementation/part-07-implementation-evidence-20260602-final.md`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-store-cold.h`
- `tools/server/server-cache-store-cold.cpp`
- `tools/server/server-context.cpp`
- `tests/test-stage10-cold-store-hardening.cpp`
- `tests/test-step10-metrics.cpp`
- `tools/server/hybrid-cache.md`
- `tools/server/README.md`
- `tools/server/README-dev.md`
- `tools/server/bench/README.md`
- `tools/server/tests/README.md`

Gate state after this review:

| Gate | Status |
| --- | --- |
| Stage 10 design | PASS |
| Stage 10 implementation plan | PASS |
| Stage 10 implementation review | REWORK |
| Stage 10 QA planning and execution | CLOSED |

## Findings

### S10-IMPL-01 [BLOCKING] Public Prometheus rows drop required observability dimensions

The accepted design requires complete hybrid metrics through the existing
metrics endpoint. It also requires R62 exact-blob observations with result,
profile, pair state, and residency where useful, and R64/R65 promotion and
demotion observations by payload kind, pair state, result, and reason. The
accepted evidence plan classifies cold transition demotions and promotions as
public Prometheus evidence.

The controller records the missing dimensions in direct stats:

- `stage10_payload_shape_key()` records `operation`, `payload_kind`,
  `pair_state`, `residency`, `profile`, `result`, and `reason` in
  `tools/server/server-cache-hybrid.cpp:152`.
- `record_payload_transition()` uses that shape for promotion and demotion rows
  in `tools/server/server-cache-hybrid.cpp:1201`.
- `record_exact_restore()` uses the same shape without `operation` in
  `tools/server/server-cache-hybrid.cpp:1197`.

The public exporter then collapses those rows. `write_stage10_rows()` in
`tools/server/server-context.cpp:4604` exports only `payload_kind`, `pair_state`,
`result`, and `reason`. The public `cache_payload_transitions_total` row at
`tools/server/server-context.cpp:4627` drops `operation`, so an operator cannot
separate R64 promotions from R65 demotions through the new bounded row. The
public `cache_exact_blob_restores_total` row at
`tools/server/server-context.cpp:4622` drops `profile` and `residency`, even
though Part 7 claims those dimensions as part of the filled R62 evidence.

Existing raw counters such as `llamacpp_cache_payload_demotions_total` and
`llamacpp_cache_payload_promotions_total` distinguish operation at aggregate
level, but they do not carry the bounded Stage 10 dimensions required by the
design. Direct stats prove the controller can compute the shape; they do not
close the operator-facing Prometheus contract.

Required correction: export the Stage 10 rows with the required dimensions, or
split them into public metrics that preserve the same information without
unbounded labels. Add focused coverage that checks the exported label names and
values, not only `get_stats()` rows.

## Decisions

- REWORK: Stage 10 implementation review cannot pass until S10-IMPL-01 is
  corrected and re-reviewed.
- PASS: The R107 legacy-path justification is acceptable. The touched
  legacy-adjacent paths are limited to the shared `/metrics` exporter and test
  target registration. No legacy cache policy change was found.
- PASS: Prometheus label escaping is directionally correct for the touched
  exporter path. Backslash, quote, newline, and carriage return are escaped
  before label values are written.
- PASS: Cold-store root hardening is scoped and matches the Stage 10 design.
  It keeps a canonical absolute root, rejects unsafe roots, checks derived paths
  against the root, allows literal `..` characters in a safe root name, and
  removes raw paths from diagnostics.
- PASS: Startup validation and pressure or abuse tests cover useful Stage 10
  cases, including impossible budgets, protected-root pressure, branch metadata
  pressure, queue pressure, shutdown with pending work, and repeated integrity
  failures.
- PASS with QA carry-forward: Part 7's coverage and benchmark blockers are
  acceptable as implementation-review evidence limits. They do not prove R107
  coverage or benchmark acceptance yet, so QA planning must carry them as
  required environment setup and evidence collection work after this rework is
  closed.
- PASS: No request-marker validation code is required in this repo state
  because no hybrid cache request-marker surface is enabled.
- PASS with S10-IMPL-01 caveat: `tools/server/hybrid-cache.md` and related
  READMEs are durable operator docs and match the intended flags, cold-store
  limits, benchmark evidence classes, and security exclusions. The metric list
  must stay aligned with the corrected public metric shape.

## Required corrections

| ID | Severity | Owner | Correction |
| --- | --- | --- | --- |
| S10-IMPL-01 | BLOCKING | Developer | Preserve required Stage 10 observability dimensions in public Prometheus rows and add focused exporter coverage for the corrected labels. |

## Handoff

Handoff state: rework required.

Next owner: Developer. After the public metric shape is corrected and tests are
updated, return to Architect for implementation re-review. QA planning and QA
execution remain closed.
