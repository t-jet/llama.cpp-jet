# Cache handling Phase 26 design

Status: closed; implementation PASS D26-IMPL-MGR and Manager closure D-CLOSURE-26-01 2026-06-26
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope source: user direction 2026-06-25
Current gate: terminal (Stage 26 closed)

## Scope

This stage resolves every open follow-up from Stage 24 and Stage 25,
aligns cache Prometheus metrics with the upstream llama.cpp convention,
and reruns the Stage 24 S02/S03 comparison cases against the new binary.

Three goals:

1. Carry-over inventory: resolve D-EXEC-24-03-a (Windows SEH handler),
   D-EXEC-24-03-b (widen silent-crash investigation to S02 hybrid earlier
   manifestation), D-EXEC-24-03-c (cold-store metric vs filesystem
   drift), PF-03 (cross-stage performance comparison evidence gap), and
   the tx_* routing confirmation on D-EXEC-24-03 acceleration in S02
   hybrid.
2. Metrics alignment: rename `llamacpp_X` to `llamacpp:X` per upstream
   convention; resolve the duplicate `mode` label Prometheus scraper
   error on `cache_prompt_evidence_records_total`; update fixture
   scripts that scrape by name.
3. Stage 24 rerun: S02-chat native+hybrid, S03-chat native+hybrid via
   `stage24-chat-s02-s03-comparison.ps1` against the post-metrics binary
   so the prior Stage 24 evidence stays comparable and the carry-over
   status is verifiable with new architecture.

## Contents

| Part | Title |
| --- | --- |
| [part-01](./cache-handling-phase26-design/part-01-carry-over-inventory.md) | Carry-over inventory (D-EXEC-24-03 a/b/c + PF-03 + Stage 25 S02 confirmation) |
| [part-02](./cache-handling-phase26-design/part-02-metrics-alignment-plan.md) | Metrics alignment plan (rename, label conflict, fixture updates) |
| [part-03](./cache-handling-phase26-design/part-03-seh-handler-crash-dump.md) | Windows SEH handler + crash-dump design |
| [part-04](./cache-handling-phase26-design/part-04-cold-store-metric-drift-fix.md) | Cold-store metric vs filesystem drift fix |
| [part-05](./cache-handling-phase26-design/part-05-stage24-rerun-plan.md) | Stage 24 rerun plan |
| [part-06](./cache-handling-phase26-design/part-06-implementation-order.md) | Implementation order |
| [part-07](./cache-handling-phase26-design/part-07-test-plan.md) | Test plan |

## Architectural observations

Two observations worth noting in design review:

1. Goal 1 work (carry-over fixes) is partially architectural correction
   to closed stages. Per the Stage 15+ correction workflow, durable
   fixes that change behavior land in the originating stage's
   implementation log; this entry doc treats Stage 26 as the single
   delivery gate for the D-EXEC-24-03 a/b/c and PF-03 follow-ups so
   the user gets one review cycle. Each part file records its
   originating stage (24 or 25) explicitly.
2. The Stage 25 runner (`stage25-atomic-20260625-01`) already exercised
   the Stage 24 S02/S03 workload with the post-`tx_*` binary and
   produced S02 hybrid FAIL-http-request at req 48. That is the
   evidence base for the Stage 25 closure follow-up on `tx_*`
   acceleration. The Stage 24 rerun in part-05 is the second of the
   two confirmations and must reproduce against the post-metrics binary,
   not the post-`tx_*`-only binary.

## Architecture invariants preserved

- Cache stats field names (`n_hits`, `n_misses`, `cache_cold_bytes`,
  etc.) are NOT renamed. Only the Prometheus metric NAMES are renamed.
  Public JSON stats via `/stats` or get_cache_stats() stay stable.
- `mode` label on cache metrics is preserved (current behavior). The
  duplicate-label fix removes the redundant `mode` passed as the first
  label argument to `write_cache_metric_with_two_labels` for
  `cache_prompt_evidence_records_total`, NOT the `mode` label itself.
- Test fixture scripts that scrape metrics by name are updated in this
  stage. Test scripts that read JSON get_cache_stats are NOT touched.
- Stage 24 rerun preserves all prior runner parameters and report
  fields. New fields (metrics-format check, label-uniqueness check) are
  appended to the runner summary; existing fields stay unchanged.

## Exclusions

- No change to public CLI flags.
- No change to public endpoint schemas.
- No change to model fixture selection.
- No change to runner script behavior beyond metrics-format assertion
  additions.
- No change to test plan for closed stages.

## Hard constraints (binding)

- DO NOT touch production code (design only).
- DO NOT modify existing test plan or test reports.
- DO NOT modify tracker or document-index (Manager owns).
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part file under 300 lines.

## Handoff

Design is reviewable. Next owner: independent Architect for design
review (D26-DESIGN-01). After design PASS, Manager design gate
(D26-DESIGN-MGR). After Manager gate PASS, implementation planning
(D26-IMPL-PLAN). No code change yet.
