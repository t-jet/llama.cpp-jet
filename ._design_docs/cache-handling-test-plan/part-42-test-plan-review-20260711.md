# Stage 38 test-plan review (independent, part 42)

Source: [../cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md](part-42-stage38-prefix-restore-cold-budget.md)
Date: 2026-07-12
Reviewer: QA (fresh independent review)
Branch: `work-branch`
Scope: review only. No edits to plan, code, tests, README, or part-08.

## Authority sources cross-checked

- `cache-handling-phase38-design/part-03-observability-and-tests.md` (TP-38 rows, metrics table, reporting contract).
- `cache-handling-phase38-implementation.md` (test/regression plan section).
- `cache-handling-phase38-implementation/part-05-implementation-rework-evidence-20260711.md` (focused tests already implemented).
- `tests/test-cache-controller.cpp` (focused test names verified present).

## Verdict: PASS

All 12 TP-38 rows mapped to executable evidence, every named test exists in
`tests/test-cache-controller.cpp`, generic wording holds, ASCII is clean,
clean-build rule is documented, no BLOCKING findings.

## Checklist results

| # | Item | Result | Evidence |
| --- | --- | --- | --- |
| 1 | Scope matches design part 3 + impl log | PASS | Part 42 `Scope` lists both fixes (chat strict-prefix restore, D36-FU-01 cold-budget gauge); out-of-scope covers `/completion` recompute and full prompt-totals. Aligns with design part 3 regression table and impl log test/regression plan. |
| 2 | All 12 TP-38 rows mapped to executable evidence | PASS | `TP-38 to evidence mapping` table in part 42 + verified every named test exists in `tests/test-cache-controller.cpp` via grep. See mapping section below. |
| 3 | Positive and negative coverage per row | PASS | Part 42 `TP-38 rows` table has `Positive case` and `Negative case` columns for every row. PR-02 negative is the `/completion` recompute case. |
| 4 | Observability explicit | PASS | Every row has an `Observability check` column naming counters, metrics, and public fields (`cached_tokens`, `timings.cache_n`, `prompt_tokens`, `cache_prefix_candidates_total`, `cache_restore_misses_total`, `cache_cold_budget_bytes`). Matches design part 3 metrics table. |
| 5 | Clean-build rule documented | PASS | Part 42 has a dedicated `Clean-build rule` heading: clean Release build required, targets `llama-server` + `test-cache-controller`, stale-binary prohibition. Entry plan restates the rule. |
| 6 | Generic wording, no run-specific leakage | PASS | No PID, no dated artifact dir, no stage38-cache-* live dir in plan or script. The only date is the document authoring date `2026-07-11`, consistent with every sibling part file. Script generates runtime timestamps; no hardcoded ones. |
| 7 | ASCII plain labels only, no unicode icons | PASS | Byte scan: part 42 has 0 non-ASCII bytes, script has 0 non-ASCII bytes. Plain labels `PASS`, `FAIL`, `SKIP`, `BLOCKED`. No BOM, CR=0 on both files. |
| 8 | Evidence format clear (PASS/FAIL/SKIP/BLOCKED, reproducible) | PASS | Part 42 `Classification` table defines each outcome with conditions. Script writes per-row `Outcome` column and reproducible raw files. |
| 9 | Script standalone (not coupled to prior run) | PASS | Script header and README both state standalone. Run-local template, timestamped `RunRoot`, no prior-run reads. Script + README both state "does not depend on a prior run output". |
| 10 | Reusable automation registered in README | PASS | `cache-handling-test-scripts/README.md` has a dedicated `stage38-prefix-restore-and-cold-budget.ps1` section: what it adds over `compare-legacy-vs-hybrid.ps1 -BurstDuplicateMode`, parameters, usage example, stale-binary rule. |

## Mapping completeness: 12/12 TP-38 rows covered

Every named test was verified present in `tests/test-cache-controller.cpp`.

| Row | Focused controller test (verified present) | Live script |
| --- | --- | --- |
| TP-38-PR-01 | `test_stage38_exact_repeat_wins_over_prefix` | - |
| TP-38-PR-02 (unit) | `test_stage38_chat_strict_prefix_restore_plan` | - |
| TP-38-PR-02 (live) | - | suffix turn + prefix proof rows |
| TP-38-PR-03 | `test_stage38_prefix_boundary_checksum_rejects` | - |
| TP-38-PR-04 | `test_stage38_namespace_template_tool_drift_rejects` | - |
| TP-38-PR-05 | `test_stage38_pair_state_mismatch_rejects_prefix` | - |
| TP-38-PR-06 | `test_stage38_target_draft_prefix_requires_checkpoint_safe` | - |
| TP-38-PR-07 | `test_stage38_cold_prefix_payload_promotes_or_falls_back` | - |
| TP-38-PR-08 | `test_stage38_protected_prefix_metadata_survives_pressure` | - |
| TP-38-PR-09 | `test_stage38_generated_output_never_replayed` | - |
| TP-38-PR-10 | `test_stage38_completion_strict_prefix_recomputes` | - |
| TP-38-MET-01 (unit) | `test_stage38_cold_budget_prometheus_gauge_output` | - |
| TP-38-MET-01 (live) | - | Prometheus gauge row |
| TP-38-MET-02 | `test_stage38_cold_budget_metric_boundary_math` | - |

All 12: yes.

## Generic-vs-run-specific audit: PASS

Plan body and script contain no run IDs, no PID references, no dated
`_test_output` artifact dirs, no specific report filenames. Generic
`YYYYMMDD-NN` placeholders match repo convention. The document authoring date
is standard for the documentation set.

## ASCII audit: PASS

Part 42 non-ASCII bytes: 0 (CR=0, no BOM).
Script non-ASCII bytes: 0 (CR=0, no BOM).
Both use plain ASCII status labels only.

## Findings

NON-BLOCKING (1):

- Part-08 self-attestation records part 42 at 149 lines; observed actual line
  count is 155; the source brief cited 145. None exceed the 300 cap. Cosmetic
  count drift inside the producer's own handoff note only. No correction
  required for plan approval; the producer may update the self-count if desired.

No BLOCKING findings.

## Next owner

Manager (gate decision).
