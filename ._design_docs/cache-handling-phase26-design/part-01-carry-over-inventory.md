# Part 1: Carry-over inventory

Status: design draft
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope: per-issue current state, fix scope, and expected evidence.

## Inventory

| ID | Origin | Current state | Fix scope | Expected evidence |
| --- | --- | --- | --- | --- |
| D-EXEC-24-03-a | Stage 24 closure (part-16) follow-up (a) | OPEN. SEH handler + minidump not installed. | Windows SetUnhandledExceptionFilter (or AddVectoredExceptionHandler) writing a minidump with registers + call stack + last-error info. Detailed in part-03. | crash dump file in `--crash-dump-dir`, exit code surfaced to runner on graceful shutdown, dump re-runnable from saved file |
| D-EXEC-24-03-b | Stage 24 closure (part-16) follow-up (b); Stage 25 closure D25-EXEC-04 | OPEN. S03 hybrid crash root cause is at a layer below hybrid cache code. Stage 25 -01 S02 hybrid crashed at req 48 (was PASS in Stage 24 -06), Stage 24 -06 S03 hybrid crashed at req 490. | Widen silent-crash investigation: (1) reproduce S02 hybrid early crash with new binary; (2) compare stack/race against S03 hybrid crash; (3) attribute whether tx_* routing accelerated D-EXEC-24-03. Detailed in part-03 + part-05. | crash dump captured from a live S02 hybrid rerun showing the same crash signature as Stage 25 -01; crash attribution note in part-05 results |
| D-EXEC-24-03-c | Stage 24 closure (part-16) follow-up (c); Stage 25 closure follow-up | OPEN. Cold-store metric reports 352 MiB (n_cold_payload_bytes); filesystem has 5.78 GiB on disk (115 cold files of 50.25 MiB each, -06 S02 hybrid). | Identify accounting gap between metric (descriptor-owned) and filesystem (payload bytes on disk). Likely the metric counts only descriptor-tracked bytes; the cold payload files include header overhead, alignment padding, or count bytes not subtracted on eviction. Detailed in part-04. | metric vs filesystem delta in test report rows <= 10% OR explicit accounting-fix note with new metric naming |
| PF-03 | Stage 25 closure D25-EXEC-03 | BLOCKED-evidence-gap. Cross-stage latency comparison not measurable from current run root. | Stage 24 rerun with the post-`tx_*` binary produces Stage 24-equivalent latency for hybrid legs; side-by-side comparison vs Stage 24-06 hybrid legs closes the gap. Detailed in part-05. | comparison.json for S02/S03 hybrid legs with per-leg latency percentiles and delta vs Stage 24-06 |
| Stage 25 S02 hybrid confirmation | Stage 25 closure follow-up (e) | OPEN. Stage 25-01 S02 hybrid crashed at req 48. Stage 24-06 S02 hybrid was PASS at req 876. The manifestation shift is the only signal of `tx_*` routing effect. | Stage 24 rerun in part-05 produces a second S02 hybrid measurement against the post-metrics binary (which is functionally equivalent to the post-`tx_*` binary for cache hot path). If the rerun PASSES, the manifestation was attributable to Stage 25 build/load conditions (CUDA warmup, MTP config, prompt set); if it FAILS again at req 48, the `tx_*` routing is implicated. | per-leg verdict for S02 hybrid in the rerun report with the request index at failure (or PASS) |

## Cross-cutting notes

- D-EXEC-24-03-a (SEH handler) is a precondition for D-EXEC-24-03-b
  (silent-crash investigation) because without a crash dump the rerun
  cannot attribute the crash root cause. Implementation order in
  part-06 sequences SEH first so the rerun produces useful evidence.
- D-EXEC-24-03-c (cold-store metric drift) does not block PF-03 (cross-
  stage latency comparison) because the drift is on the cold-store
  size, not on the latency path. PF-03 can proceed even if the drift
  remains a separate observation after the rerun.
- Stage 25 S02 hybrid confirmation is part of the Stage 24 rerun
  evidence, not a separate rerun. Part-05 records both S02 and S03
  hybrid verdicts explicitly so the Stage 25 follow-up (e) gets closed
  or escalated.

## Carry-over source citations

- Stage 24 closure: [cache-handling-phase24-implementation/part-16-manager-closure-20260625.md](../cache-handling-phase24-implementation/part-16-manager-closure-20260625.md), follow-up tasks (a), (b), (c).
- Stage 25 closure: [cache-handling-phase25-implementation/part-10-manager-closure-20260625.md](../cache-handling-phase25-implementation/part-10-manager-closure-20260625.md), follow-up tasks (a) through (e).
- Stage 24 final report: [test-report-20260624-06.md](../.test_reports/test-report-20260624-06.md), cold-store metric drift and S03 hybrid crash signature.
- Stage 25 integration test: [test-report-20260625-01.md](../.test_reports/test-report-20260625-01.md), S02 hybrid early-crash at req 48 and S03 hybrid crash signature byte-identical to Stage 24 -06.

## Handoff

This part is the inventory table the rest of the design builds on.
Parts 03, 04, and 05 expand each row into a concrete fix or rerun
plan. Next part: part-02 metrics alignment plan.
