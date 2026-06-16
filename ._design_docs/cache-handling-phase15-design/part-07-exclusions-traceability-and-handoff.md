# Stage 15 design: exclusions, traceability, and handoff -- Part 7

Source: [../cache-handling-phase15-design.md](../cache-handling-phase15-design.md)

## Exclusions

- New cache behavior, public endpoints, CLI flags, metrics, or
  bounded diagnostics.
- The synthetic Stage 12 V2/V3/non-MTP matrix expansion
  (2026-06-09 close-at-current-progress decision preserved).
- The pre-existing `test-stage10-policy-lru` semantic bug.
- Upstream merge work (closed at Stage 14).
- Production readiness for environments not in the local
  inventory. The benchmark report and the bug-fix loop operate
  on the local host; cross-host portability is out of scope.
- Performance optimization that would change cache behavior.
  The bug-fix loop fixes product bugs; it does not tune
  performance beyond what the closure contracts already require.

## Requirement traceability

The closure contracts Stage 15 re-verifies. Each contract names
the owner and the per-row contract.

| Contract | Owner | What Stage 15 re-verifies |
| --- | --- | --- |
| T114 combined hybrid-path coverage floor 0.80 | Stage 10, test plan Part 12 | Re-run coverage; record the combined rate in the QA report. |
| T114a product-only hybrid-path coverage floor 0.70 | Test plan Part 13, Stage 11 onward | Re-run coverage; record the product-only rate in the QA report. |
| T115 per-file aggregation rule | Test plan Part 12, Part 13 | Inspect the per-file table; record dedup by lowercased full path. |
| T121 public checkpoint admission row | Stage 10 implementation Part 9, test plan Part 12 | Public HTTP /metrics on the MTP-capable fixture records four `cache_checkpoint_*` rows with the bounded label set. |
| E13-01..E13-16 public endpoint parity | Stage 13 design Part 3, implementation | Public HTTP probe on a freshly started hybrid-mode server records PASS for each row in the Stage 13 route inventory. |
| Stage 12 stress rows S01..S08 | Stage 12 design Part 2 | Per-row evidence directory and verdict in the QA report. |
| Stage 12 long-run rows L01..L03 | Stage 12 design Part 2 | Per-row evidence directory and verdict (PASS-meets-intent or BLOCKED-time-budget) in the QA report. |
| Stage 12 benchmark rows B01..B08 | Stage 12 design Part 3 | Per-row evidence directory and verdict in the benchmark report. |
| Stage 13 MTMD placeholder path | Stage 13 implementation | The MTMD placeholder path is still the route-family value in the implementation; the QA cites the file or the route inventory entry. |
| Stage 13 diagnostic-source namespace isolation | Stage 13 design Part 2, bug-fix review | The endpoint source label is not in the `preparation_id` or any other namespace key component. |
| Stage 13 bounded `cache metadata:` format at task launch | Stage 13 bug-fix loop, test report 20260610-04 | The bounded diagnostic on the native `/completion` and OpenAI-compatible `/v1/chat/completions` degraded paths uses `{source, method, degraded, tokens, boundaries}`. |
| Stage 13 transcript route coverage | Stage 13 implementation plan rework 2026-06-09 | The transcription route is in the route inventory and is exercised in the public HTTP probe. |
| Stage 13 embedding cache exclusion rationale | Stage 13 implementation Parts 2 and 3 | The embedding routes are excluded from hybrid cache prompt state by design; the QA records the rationale. |
| Stage 4-9 regression | Test plan Parts 1-12 | The pytest runner and the Stage 4-9 rows PASS, FAIL, SKIP, or BLOCKED per their per-row contract. |

A row that fails its closure contract opens a bug-fix loop
iteration per part-4 of this design. A row that requires a
prior-stage design change opens a rework part file in the
affected stage's design tree, not in the Stage 15 design.

## Document updates Stage 15 will trigger

After the QA execution, the bug-fix loop, and the benchmark
report are filed, the following durable docs are updated:

- `._design_docs/cache-handling-stage-tracker.md`: the Stage 15
  row moves from `pending` to the next status. The Manager owns
  the row update.
- `._design_docs/document-index.md`: the implementation log, the
  test report, and the benchmark report gain rows in the
  "Cache implementation, verification, and tests" section.
- `._design_docs/cache-handling-phase15-implementation.md`: the
  implementation log entry doc is created when implementation
  planning opens. The entry doc follows the same template as
  the prior stage implementation logs.
- `._design_docs/cache-handling-phase15-design/part-08-design-review-gate-01.md`:
  the Architect independent design review, authored in a fresh
  Architect session after this design is otherwise complete.
- `._design_docs/cache-handling-phase15-design/part-09-manager-design-gate.md`:
  the Manager design gate decision, authored by the Manager
  after the independent review returns PASS or PASS-with-
  observations.

## Handoff

This design is the Stage 15 design deliverable. After Manager
approval, the next gate is implementation planning, owned by the
Developer. The Developer produces the implementation log entry
doc, the per-step plan, and the affected-file list. The QA owner
executes the test plan after implementation planning closes. The
Developer runs the bug-fix loop when the QA report surfaces a
product bug. The QA owner files the benchmark report after the
stress, long-run, and bench rows close or escalate. The Manager
records the closure decision in the implementation log.

Stage 15 is operational, not a feature. The design records the
operational contract that lets the QA, Developer, Architect, and
Manager work the test suite, the bug-fix loop, and the benchmark
report without redefining the architecture scope.
