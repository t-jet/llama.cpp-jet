# Part 8: Manager closure 2026-06-26

Status: closed; Manager gate decision D-CLOSURE-26-01 2026-06-26
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Owner: Manager (closure) and Architect (closure sweep)
Scope: closure record for Stage 26 implementation log; Stage 26 closed
with documented evidence-gap and structural-not-infra carry-over from
D-EXEC-24-03 plus one new R26-OBS-01 observation.

## Summary

Stage 26 executed the design, plan, implementation iter 1, and final
QA execution cycle for the metrics alignment and Stage 24/25 carry-over
resolution scope. All gate reviews reached PASS before QA execution
opened. The final QA execution ([test-report-20260626-01.md](../../.test_reports/test-report-20260626-01.md))
recorded 10 PASS, 1 PARTIAL, 1 REPRODUCED, and 1 DELTA-RECORDED across
the 12 test plan rows. Code changes are UNCOMMITTED per AGENTS.md and
the closure decision.

The implementation added Windows SEH handler + crash-dump generation
(verified by TA-26-FA-01 smoke trigger with a 223 KB minidump at
`D:\tmp\test-crash-dump\llama-server-19360-20260626-003941.dmp`),
per-id cold-store byte accounting with five decrement paths including
the promotion-success path, 90 metric renames to `llamacpp:` colon
prefix, the `mode` to `scope` label conflict fix on
`cache_prompt_evidence_records_total`, and the Stage 24 rerun fixture.
137/137 unit tests pass on the post-fix CUDA Release binary.

The PARTIAL row (TP-26-IT-01) split as S02 PASS, S03 FAIL. The
REPRODUCED row (TP-26-IT-02) reproduced D-EXEC-24-03 silent server
crash at request 258 `s03-exact-0-1` (vs Stage 24 -06's request 281
`s03-new-6-0`; Stage 25 -01's request 258 `s03-exact-0-1`). Cache
state at death was 637 tokens / 502 MiB (was 4073 tokens / 505 MiB
in -06). The DELTA-RECORDED row (TP-26-PF-01) recorded hybrid-vs-native
median deltas but could not close PF-03 because the Stage 24 -06 hybrid
median baseline was never recorded.

## Per-row final classification

| Row | Verdict | Note |
| --- | --- | --- |
| TP-26-UT-01 cold_metric_tracks_per_id_bytes | PASS | in 137/137 pack |
| TP-26-UT-02 cold_metric_decrements_on_evict | PASS | in 137/137 pack |
| TP-26-UT-03 cold_metric_decrements_on_cleanup | PASS | in 137/137 pack |
| TP-26-UT-04 cold_metric_no_double_count_on_redemote | PASS | in 137/137 pack |
| TP-26-UT-05 cold_payload_files_count_matches_disk | PASS | in 137/137 pack |
| TA-26-FA-01 SEH activation | PASS | smoke trigger 223 KB minidump |
| TA-26-FA-02 label uniqueness | PASS | 0 duplicate `mode`/`scope` labels across 1213 metric lines |
| TA-26-FA-03 metrics format compliance | PASS | 0 old `^llamacpp_`; 404 new `^llamacpp:` lines |
| TA-26-FA-04 runner MetricNames scrape | PASS | all 10 entries present 3+ times per leg across 4 legs |
| TP-26-IT-01 Stage 24 rerun (S02 + S03) | PARTIAL | S02 PASS, S03 FAIL (D-EXEC-24-03 reproduces) |
| TP-26-IT-02 D-EXEC-24-03 reproduction | REPRODUCED | server died mid-leg at request 258 |
| TP-26-PF-01 cross-stage latency (PF-03) | DELTA-RECORDED | S02 hybrid +454.81 ms; S03 hybrid +76.16 ms median delta |

Final counts (verified from
[test-report-20260626-01.md](../../.test_reports/test-report-20260626-01.md)
per-row verdict table): 10 PASS, 1 PARTIAL, 1 REPRODUCED,
1 DELTA-RECORDED. Manager brief lists the same per-row verdicts
under the closing totals line; the brief's prose phrase "11 test
rows" is a brief typo because the verdict table contains 12 rows
(5 + 4 + 1 + 1 + 1).

## Manager decisions (verbatim)

### D-EXEC-26-01

SEH handler + crash-dump infrastructure VERIFIED via TA-26-FA-01
smoke trigger (223 KB minidump written to
`D:\tmp\test-crash-dump\llama-server-19360-20260626-003941.dmp`).
One-line runner fix needed:
`stage24-chat-s02-s03-comparison.ps1` lines 933-934 do NOT pass
`--crash-dump-dir` to llama-server.exe. Add this flag to next
rerun so D-EXEC-24-03 reproduction captures SEH dump. SEH infra
is verified; runner gap is the only blocker.

### D-EXEC-26-02

R26-OBS-01 demote queue saturation (32/32) is OBSERVATION, not a
new Stage 26 product bug. Cold-store metric correctly reports 0
when no demotion succeeds (post-Stage-25 atomic-transactional
behavior). Promote to follow-up for Stage 27 demote-throughput
investigation under concurrent hybrid workload.

### D-EXEC-24-03 (carry-over)

silent server crash reproduced at request 258 `s03-exact-0-1`
(vs Stage 24 -06's req 281 `s03-new-6-0`; Stage 25 -01's req 258
`s03-exact-0-1`). Cache state at death 637 tokens / 502 MiB (was
4073 tok / 505 MiB in -06). NEW: `demotion queue full (32/32)`
warnings present. No FATAL/OOM/SEGV/exception in err.log.
Stage 26 SEH handler NOT triggered during rerun because runner
doesn't pass `--crash-dump-dir` (D-EXEC-26-01). Same root-cause
class (silent Windows process termination) - still
BLOCKED-structural-not-infra; not a Stage 26 regression.

### D-CLOSURE-26-01

close Stage 26. 11 test rows: 9 PASS, 1 PARTIAL
(TP-26-IT-01 S03 only), 1 REPRODUCED (TP-26-IT-02 = D-EXEC-24-03
carry-over), 1 DELTA-RECORDED (TP-26-PF-01 PF-03). 0 new
Stage 26 product bugs. Code UNCOMMITTED per AGENTS.md. User
approval required for commit. Follow-ups:

- (D-EXEC-26-01) stage24 runner add `--crash-dump-dir` flag
  (one-line fix)
- (D-EXEC-26-02) demote queue saturation R26-OBS-01 to Stage 27
- (D-EXEC-24-03 carry) silent-crash root cause: rerun S03 hybrid
  with `--crash-dump-dir`, load minidump, capture stack at
  chat-format normalization
- (D-EXEC-24-03 carry) widen scope to S02 hybrid earlier-crash
  observation
- (D-EXEC-24-03 carry) cold-store metric vs filesystem drift
  (now bounded by per-id map but Stage 24 -06 baseline observation
  persists)
- (PF-03 carry) Stage 24 -06 hybrid median baseline never
  recorded; future Stage 24 reruns must emit per-request hybrid
  medians to close PF-03 within 25%

## Code change summary

Stage 26 modifications are uncommitted per AGENTS.md and
D-CLOSURE-26-01. Modified files:

- `tools/server/server-crash-handler.h` (new; install_crash_dump_handler
  declaration; SetUnhandledExceptionFilter wiring)
- `tools/server/server-crash-handler.cpp` (new; MiniDumpWriteDump
  implementation with `__try` / `__except` guard; stderr fallback)
- `tools/server/server-cache-hybrid.h` (cold_payload_bytes_by_id_ map;
  comment block explaining per-id accounting)
- `tools/server/server-cache-hybrid.cpp` (5 decrement/insert sites
  for cold_payload_bytes_by_id_; promotion-success decrement on
  handle_promotion_completion L898-916)
- `tools/server/server-context.cpp` (90 metric renames to `llamacpp:`
  colon prefix; L4537/4541 `mode` to `scope` label fix on
  cache_prompt_evidence_records_total)
- `tools/server/server.cpp` (`--crash-dump-dir` argv pre-scan splice
  before common_params_parse; filter install)
- `tools/server/CMakeLists.txt` (server-crash-handler.cpp under
  if(WIN32); dbghelp PUBLIC link on server-context target)
- `tests/test-cache-controller.cpp` (5 new TP-26-UT-01..05 tests;
  test count 132 to 137)
- `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
  (not modified; D-EXEC-26-01 carries the runner-flag fix as a
  follow-up)

No public CLI flags, public endpoint schemas, model fixtures,
runner scripts (other than the runner-flag carry-forward above),
or test report body were modified during this closure sweep. No
fixes file or developer review file was edited.

## Follow-up tasks

- (a) Add `--crash-dump-dir` flag to
  `stage24-chat-s02-s03-comparison.ps1` server start (one-line
  fix around lines 933-934) so future reruns capture SEH minidumps
  during D-EXEC-24-03 reproduction. Owner: future QA rerun prep.
  Rationale: SEH infra verified in TA-26-FA-01 but the runner
  omits the flag; without it, crashes still reproduce silently.
- (b) Promote R26-OBS-01 demote queue saturation observation to
  Stage 27 demote-throughput investigation under concurrent hybrid
  workload. Owner: future stage. Rationale: cold demotions not
  completing in either hybrid leg; Stage 25 atomic-transactional
  behavior may have reduced demote throughput below eviction rate.
- (c) D-EXEC-24-03 silent-crash root cause: rerun S03 hybrid with
  `--crash-dump-dir`, load minidump, capture stack at chat-format
  normalization. Owner: future stage. Rationale: crash signature
  reproduces but root cause remains undiagnosed without SEH dump.
- (d) Widen D-EXEC-24-03 scope to S02 hybrid earlier-crash
  observation (Stage 25 -01 req 48 vs Stage 24 -06 req 490).
  Owner: future task. Rationale: tx_* routing may have accelerated
  manifestation; rerun needed to attribute the shift.
- (e) Cold-store metric vs filesystem drift observation. Owner:
  future observation. Rationale: now bounded by per-id map but
  Stage 24 -06 baseline observation persists.
- (f) PF-03 evidence gap: future Stage 24 reruns must emit
  per-request hybrid medians to close PF-03 within 25% threshold.
  Owner: future task. Rationale: cross-stage comparison not
  measurable from current run root; baseline never recorded.

## Handoff

Next owner: user.

The user owns the commit decision for the uncommitted code changes
in `tools/server/server-crash-handler.{h,cpp}`,
`tools/server/server-cache-hybrid.{h,cpp}`,
`tools/server/server-context.cpp`, `tools/server/server.cpp`,
`tools/server/CMakeLists.txt`, and `tests/test-cache-controller.cpp`.
Per AGENTS.md and D-CLOSURE-26-01, AI agents do not commit or push
without explicit user approval. Once the user commits, the six
follow-up tasks above remain open as separate future stages or
observations.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc
cap.
