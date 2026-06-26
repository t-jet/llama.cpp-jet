# Cache handling Phase 26 implementation plan

Status: bug-fix loop open; D-CLOSURE-26-01 reverted by user direction 2026-06-26 (D26-REOPEN-01); D-EXEC-24-03 still reproducing
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Owner: Manager (closure) and Architect (closure sweep)
Source design: [cache-handling-phase26-design.md](cache-handling-phase26-design.md) + parts 01..07
Scope: implementation log for Stage 26 cold-store accounting, metrics alignment, SEH handler, and Stage 24 rerun.
Current gate: bug-fix loop (D-EXEC-24-03 fix in progress)

## Scope

This plan executes Stage 26. It resolves every open follow-up from
Stage 24 and Stage 25 (D-EXEC-24-03 a/b/c, PF-03, Stage 25 S02 hybrid
manifestation), aligns cache Prometheus metrics with the upstream
llama.cpp convention (`llamacpp:` colon-prefix), fixes the duplicate
`mode` label scraper error, and reruns the Stage 24 S02/S03 comparison
cases against the post-fix binary.

Goals map to design parts:

| Goal | Source | Plan coverage |
| --- | --- | --- |
| 1. Carry-over fixes (SEH + cold-store drift) | part-01 + part-03 + part-04 | part-01 steps 1..2 |
| 2. Metrics alignment + label conflict fix | part-02 | part-01 steps 3..7, part-02 metric-rename map |
| 3. Stage 24 rerun | part-05 | part-01 step 11, part-04 evidence plan |

## OQ decisions (binding from design)

| OQ | Decision | Rationale |
| --- | --- | --- |
| OQ-26-01 (hard rename) | YES, hard rename with breaking-change note in impl log | scrapers must match upstream; aliases double surface without benefit |
| OQ-26-02 (--crash-dump-dir default) | EMPTY (disabled by default) | operator-facing diagnostic; explicit opt-in |
| OQ-26-03 (cold-store metric naming) | keep `llamacpp:cache_cold_payload_bytes` | already aligned after rename |
| OQ-26-04 (Stage 24 rerun report) | `._design_docs/.test_reports/test-report-20260626-01.md` | next available suffix 2026-06-26 |

## Architecture invariants preserved

- Cache stats field names (`n_hits`, `n_misses`, `n_cold_payload_bytes`)
  NOT renamed. Only Prometheus metric NAMES are renamed. JSON stats via
  `/stats` or `get_cache_stats()` stay stable.
- `mode` label on cache metrics is preserved (current behavior). The
  duplicate-label fix only renames the caller-side `"mode"` argument
  to `"scope"` on `cache_prompt_evidence_records_total`.
- Test fixture scripts that scrape metrics by name are updated in
  Stage 26. Scripts that read JSON get_cache_stats are NOT touched.
- Stage 24 rerun preserves all prior runner parameters and report
  fields. New fields (`metrics_format_pass`, `label_uniqueness_pass`,
  `cold_store_drift_ratio`) are appended to leg summary; existing
  fields stay unchanged.

## Contents

| Part | Title | Author | Status |
| --- | --- | --- | --- |
| [part-01](./cache-handling-phase26-implementation/part-01-implementation-plan.md) | Ordered implementation steps (12 steps) | Developer | this session |
| [part-02](./cache-handling-phase26-implementation/part-02-affected-files.md) | Affected code surfaces | Developer | this session |
| [part-03](./cache-handling-phase26-implementation/part-03-evidence-plan.md) | Evidence plan | Developer | this session |
| [part-04](./cache-handling-phase26-implementation/part-04-risks-and-open-questions.md) | Risks and open questions | Developer | this session |
| [part-05](./cache-handling-phase26-implementation/part-05-manager-review.md) | Manager design review | Manager | NOT authored by this session |
| [part-06](./cache-handling-phase26-implementation/part-06-implementation-evidence-20260625.md) | Implementation iter 1 evidence | Developer | this stage |
| [part-07](./cache-handling-phase26-implementation/part-07-architect-implementation-review-20260626.md) | Architect implementation review (PASS) | Architect | this stage |
| [part-08](./cache-handling-phase26-implementation/part-08-manager-closure-20260626.md) | Manager closure record D-CLOSURE-26-01 | Manager | this stage |

## Hard constraints (binding)

- DO NOT touch production code (plan only).
- DO NOT modify existing test plan or test reports.
- DO NOT modify tracker or document-index (Manager owns).
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part file under 300 lines.

## Handoff

Stage 26 closed per D-CLOSURE-26-01 on 2026-06-26. Next owner: user
(commit approval). See
[part-08](./cache-handling-phase26-implementation/part-08-manager-closure-20260626.md)
for the closure record, per-row final classification, Manager
decisions verbatim, code change summary, and follow-up tasks. Per
AGENTS.md and prior closures (D-CLOSURE-24-01, D-CLOSURE-25-01),
AI agents do not commit or push without explicit user approval.
