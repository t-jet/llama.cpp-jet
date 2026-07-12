# Stage 38 QA test plan handoff

Source: [../cache-handling-phase38-implementation.md](../cache-handling-phase38-implementation.md)
Plan part: [../cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md](../cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md)

Date: 2026-07-11
Stage: 38
Owner: QA

## Scope

This part records the Stage 38 test-plan and automation additions. It does not
edit production code, tests, or the shared implementation log. No commits,
pushes, staging, or reverts were performed.

## Inputs read

- `cache-handling-phase38-design/part-03-observability-and-tests.md` (TP-38
  rows and metrics contract).
- `cache-handling-phase38-implementation.md` (implementation steps and the
  test/regression plan section).
- `cache-handling-phase38-implementation/part-03-implementation-evidence-20260711.md`
  (focused commands already run).
- `cache-handling-phase38-implementation/part-05-implementation-rework-evidence-20260711.md`
  (rework focused tests added).
- `cache-handling-test-plan.md` (shared plan entry).
- `tests/test-cache-controller.cpp` (12 Stage 38 focused test functions).

## Deliverables

### Test-plan additions

- `cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md`
  (new). Generic Stage 38 section: scope, clean-build rule, evidence tiers,
  model-backed evidence requirements, all TP-38 rows with positive/negative
  cases and observability checks, focused-controller row mapping,
  classification, and handoff.
- `cache-handling-test-plan.md` (updated). Added Part 42 to the contents list,
  added a Stage 38 line to the coverage summary and current-testable scope, and
  advanced `Last updated` to 2026-07-11 with scope extended through Stage 38.

### Automation additions

- `cache-handling-test-scripts/stage38-prefix-restore-and-cold-budget.ps1`
  (new). Standalone hybrid-server script. Sends one chat turn, then a
  duplicate-prefix-plus-suffix turn, and asserts Stage 38-specific public
  contract: run-local stable ChatML template, actual assistant replay from turn
  1, strict rendered-token prefix proof before cache assertions, nonzero
  `usage.prompt_tokens_details.cached_tokens`, full
  `usage.prompt_tokens` equal to the rendered full request token count,
  `timings.cache_n` equal to
  `usage.prompt_tokens_details.cached_tokens`, positive
  `llamacpp:cache_hits_total{mode="hybrid"}` delta, at least one accepted
  prefix row in `/metrics`, and the public
  `llamacpp:cache_cold_budget_bytes{mode="hybrid"} 2147483648` gauge line.
  Refuses stale binaries older than 10 minutes. Writes per-row outcomes and raw
  metrics/request/response files to the non-durable run root.
- `cache-handling-test-scripts/README.md` (updated). Documented the new Stage 38
  script, what it adds over `compare-legacy-vs-hybrid.ps1 -BurstDuplicateMode`,
  and its parameters.

## TP-38 to evidence mapping

| Row | Evidence unit | Script / test name |
| --- | --- | --- |
| TP-38-PR-01 | Focused controller | `test_stage38_exact_repeat_wins_over_prefix` |
| TP-38-PR-02 (unit) | Focused controller | `test_stage38_chat_strict_prefix_restore_plan` |
| TP-38-PR-02 (live) | Model-backed script | `stage38-prefix-restore-and-cold-budget.ps1` suffix turn |
| TP-38-PR-02 (hit delta) | Model-backed script | `stage38-prefix-restore-and-cold-budget.ps1` hybrid hit delta |
| TP-38-PR-02 (prefix metric) | Model-backed script | `stage38-prefix-restore-and-cold-budget.ps1` accepted prefix row |
| TP-38-PR-02 (exact prompt total) | Model-backed script | `/apply-template` plus `/tokenize` rendered request length |
| TP-38-PR-02 (prefix proof) | Model-backed script | Turn 1 request and assistant replay token arrays are strict prefixes of turn 2 rendered tokens |
| TP-38-PR-03 | Focused controller | `test_stage38_prefix_boundary_checksum_rejects` |
| TP-38-PR-04 | Focused controller | `test_stage38_namespace_template_tool_drift_rejects` |
| TP-38-PR-05 | Focused controller | `test_stage38_pair_state_mismatch_rejects_prefix` |
| TP-38-PR-06 | Focused controller | `test_stage38_target_draft_prefix_requires_checkpoint_safe` |
| TP-38-PR-07 | Focused controller | `test_stage38_cold_prefix_payload_promotes_or_falls_back` |
| TP-38-PR-08 | Focused controller | `test_stage38_protected_prefix_metadata_survives_pressure` |
| TP-38-PR-09 | Focused controller | `test_stage38_generated_output_never_replayed` |
| TP-38-PR-10 | Focused controller | `test_stage38_completion_strict_prefix_recomputes` |
| TP-38-MET-01 (unit) | Focused controller | `test_stage38_cold_budget_prometheus_gauge_output` |
| TP-38-MET-01 (live) | Model-backed script | `stage38-prefix-restore-and-cold-budget.ps1` Prometheus gauge row |
| TP-38-MET-02 | Focused controller | `test_stage38_cold_budget_metric_boundary_math` |

Every TP-38 row has at least one executable evidence path.

## Test-plan review corrections

Architect test-plan review part 09 returned REWORK. Corrections applied in this
session:

- F38-TP-01: the standalone script now extracts `timings.cache_n`, asserts it
  equals `usage.prompt_tokens_details.cached_tokens`, and includes both values
  in the report evidence.
- F38-TP-02: part 42, README, and this handoff now state the script proves
  `usage.prompt_tokens` equals the rendered full request token count from
  `/apply-template` plus `/tokenize`, so the public total is not merely the
  restored prefix length.
- F38-TP-03: script README `Last updated` is 2026-07-11.

## Checks performed

### Generic vs run-specific

The new part file and the updated entry sections contain no references to a
specific prior run, date-stamped artifact directory, or PID. Commands are
documented with generic `YYYYMMDD-NN` placeholders matching the repo convention.

Verified by reading the part file after edit: no run IDs, no `_test_output`
artifact dirs with stamps, no specific report filenames.

### ASCII and unicode

All three new documents use plain ASCII status labels (`PASS`, `FAIL`, `SKIP`,
`BLOCKED`). No unicode status icons. The PowerShell script prints plain ASCII
labels only.

### Clean-build rule

Documented in the part file under a dedicated `Clean-build rule` heading: clean
Release build required before every Stage 38 session, target list
(`llama-server`, `test-cache-controller`), and stale-binary prohibition.

### Byte hygiene

The two new files were created with CRLF endings by the file tool and normalized
to LF. Re-checked: CR=0 for both. No BOM. No bytes above 127. The README is a
pre-existing tracked file and was not created in this session.

### Line counts

- `cache-handling-test-plan.md`: 299 lines (under the 300 cap).
- `part-42-stage38-prefix-restore-cold-budget.md`: 149 lines.
- `part-08-qa-test-plan-20260711.md`: this file (under 300).

## Out of scope

- No production code or test edits.
- No `document-index.md` update (Manager or Architect at the appropriate gate).
- No Manager gate authorizing QA execution (Manager writes that).
- No live execution in this planning session.

## Handoff

Next gate: test-plan review (Architect). After review PASS and Manager
test-plan gate PASS, QA execution can run the focused controller tests and the
standalone Stage 38 script against a clean Release build.
