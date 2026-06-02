# Stage 9 test-results review - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
QA report: [../.test_reports/test-report-20260601-05.md](../.test_reports/test-report-20260601-05.md)
Gate: Stage 9 test-results review
Owner: Developer
Status: BUG-FIX REQUIRED

## Scope

This review classifies every non-pass row from QA report 20260601-05. It does
not change product code.

Rows reviewed:

- Q100 BLOCKED
- Q102 BLOCKED
- Q103 FAIL
- Q109 SKIP
- Q112 FAIL

## Classification summary

| Row | QA status | Classification | Review decision |
| --- | --- | --- | --- |
| Q100 | BLOCKED | Execution blocker | Blocked by Q112 because `test-step13-stage8` aborted before later cleanup ownership tests. |
| Q102 | BLOCKED | Test limitation | Public metrics were scraped, but the public probe never admitted or restored a checkpoint. Focused metric-shape evidence passed. |
| Q103 | FAIL | Test limitation | The local MTP fixture loaded and produced draft tokens, but the probe did not create a checkpoint precondition. It is not valid product-failure evidence for checkpoint-first restore. |
| Q109 | SKIP | Expected skip | The fixture-unavailable fallback row does not apply because a local MTP fixture was found. |
| Q112 | FAIL | Product bug | Stage 9 code regressed Stage 8 target/draft re-materialization descriptor accounting. |

## Q103 and Q102 review

Q103 should not stay classified as a product failure from this report. The public
MTP probe proved server startup and MTP draft activity, but it did not prove a
checkpoint restore attempt.

Evidence from the report artifacts:

- The command used the local Qwen3.5 MTP fixture and `--spec-type draft-mtp`.
- Responses reported draft activity (`draft_n` and `draft_n_accepted` were
  non-zero).
- The first probe evaluated 13 prompt tokens. The repeat-pattern probe evaluated
  24 prompt tokens.
- Public metrics showed:
  - `cache_checkpoint_admissions_total{mode="hybrid"} 0`
  - `cache_checkpoint_restores_total{mode="hybrid",profile="none",payload_residency="none",pair_state="none",result="none"} 0`
  - `cache_checkpoint_hits_total{mode="hybrid",profile="none",payload_residency="none",pair_state="none"} 0`
  - `llamacpp_cache_hits_total{mode="hybrid"} 0`
  - `llamacpp_cache_misses_total{mode="hybrid"} 2`

The server only creates normal context checkpoints for sufficiently large prompt
state. The current production path also guards checkpoint creation behind the
completion task flow, checkpoint enablement, and a minimum prompt size. The QA
probe did not reach that setup: no checkpoint admission occurred, so no
checkpoint restore or checkpoint hit could occur.

Classification:

- Q103: test limitation.
- Q102: test limitation for public checkpoint-active metrics. The row remains
  blocked for live checkpoint rows, but the focused `test-cache-controller` and
  metrics tests still cover the metric shape.

Required QA rerun scope:

- Use a checkpoint-dependent fixture with a prompt and task shape that creates
  at least one checkpoint before the repeated restore request.
- Capture logs or metrics proving checkpoint admission before claiming
  checkpoint restore evidence.
- Re-scrape public `/metrics` after a checkpoint admission and after a restore
  attempt.

## Q112 product bug

Classification: product bug.

Observed failure:

- `test-step13-stage8.exe` fails in
  `test_hybrid_rematerialization_commits_target_draft_together`.
- The assertion at `tests/test-step13-stage8.cpp:553` expects
  `n_target_and_draft_payload_descriptors == 1`.
- The failure log also reports descriptor validation failure:
  `missing target payload`.

Root-cause hypothesis:

Stage 9 made eviction and descriptor handling payload-kind aware for exact and
checkpoint descriptors. The Stage 8 re-materialization path still depends on
the exact-payload descriptor being rebuilt atomically for target/draft entries
after metadata-only eviction. The current behavior leaves descriptor accounting
or validation inconsistent after `debug_evict_first_payload_for_tests()` and
`debug_rematerialize_first_entry_for_tests(256, 96)`, so the re-materialized
target/draft payload is not counted as one valid target-and-draft descriptor.

Owner:

- Developer.

Required fix scope:

- Fix exact-payload re-materialization after metadata-only eviction for
  target/draft entries.
- Keep descriptor ownership, hot payload record creation, pair-state validation,
  branch node payload IDs, and resident byte accounting in sync.
- Confirm the Stage 9 payload-kind changes did not leave stale evicted
  descriptors or clear the wrong entry/branch payload ID during re-materialize.

Retest scope:

- `build\bin\Release\test-step13-stage8.exe`
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step10-metrics|test-step12-branch-graph|test-step13-stage8" --output-on-failure`
- `build\bin\Release\test-cache-controller.exe`
- A Stage 9 public MTP/checkpoint probe rerun after Q103 is corrected at the
  QA harness level.

## Q100 blocker

Classification: execution blocker.

Q100 did not run to completion because `test-step13-stage8` aborted at Q112
before later cleanup ownership tests. Treat Q100 as blocked by the Q112 product
bug, not as an independent product finding.

Retest scope:

- Rerun `test-step13-stage8.exe` after the Q112 fix.
- Confirm the cleanup ownership rows that were skipped by the abort execute and
  pass.

## Q109 skip

Classification: expected skip.

Q109 covers the "model-backed fixture unavailable" path. QA found a local MTP
fixture and used it, so the fixture-unavailable row is not applicable. No
developer action is required for Q109.

## Gate decision

Stage 9 cannot close from QA report 20260601-05.

Next action:

- Developer fixes Q112.
- QA reruns the focused Stage 8/Stage 9 regression set.
- QA reruns Q103 and Q102 with a public probe that first proves checkpoint
  admission. If no suitable fixture or prompt shape can create a checkpoint,
  Q103 should be reclassified as blocked by fixture/probe limits and cite the
  focused substitute evidence already accepted in implementation review.
