# Stage 12 close-at-current-progress decision - 20260609

- Date: 2026-06-09 local
- Owner: Manager
- Trigger: user direction to stop Stage 12 testing and move to Stage 13 endpoint work
- Evidence roots:
  - `._design_docs/.test_reports/mtp-jinja-b02-final-20260609`
  - `._design_docs/.test_reports/mtp-jinja-run-20260609-V2`

## Stop action

Stage 12 execution was stopped on request.

Stopped processes:

- `llama-server` PID 33740
- row driver `powershell` PID 14228
- V2 stress/long-run runner `powershell` PID 30520

No `llama-server`, `k6`, `node`, or Windows PowerShell test runner remained
after the stop check.

## Accepted progress

V1 follow-up is complete:

- Report: `test-report-20260609-01.md`
- Developer review: `test-report-20260609-01-developer-review.md`
- Result: 36 PASS, 2 BLOCKED-infra, 0 FAIL, 0 product bugs

V2 bench is complete:

- Report: `test-report-20260609-02-V2-bench.md`
- Result: 14 PASS, 2 BLOCKED-fixture, 0 FAIL, 0 product bugs
- B02 V2 was reclassified as fixture/profile blocked: the fixed driver runs
  Qwen3-8B + Qwen3-0.6B with `draft-simple`, but this fixture does not admit
  checkpoints at the in-scope context.

V2 stress/long-run partial progress:

- S01 original and marked ran to evidence.
- S02 original and marked hit the 40-minute infrastructure cap.
- S03 original and marked ran to evidence.
- S04 original and marked ran to evidence.
- S05 original hit the runner cap because that driver has three 30-minute
  profile sub-runs under one row.
- S05 marked was interrupted by the stop request.

V3 and non-MTP follow-up sessions were not run.

## Closure decision

Stage 12 remains closed. The 2026-06-07 closure decision still stands, and
the post-closure follow-up evidence collected on 2026-06-09 found no product
bug.

Manager decision: do not spend more wall-clock time on synthetic Stage 12
matrix expansion. Carry useful findings forward to Stage 13 and run the test
suite afterward against the real endpoints that Stage 13 is meant to fix.

## Stage 13 handoff

Next owner: Stage 13 implementation/testing.

Handoff rules:

- Treat Stage 12 follow-up gaps as non-gating historical evidence.
- Preserve B02 V1 fallback fix and V2 `draft-simple` harness correction.
- Do not continue V2/V3/non-MTP synthetic sessions before Stage 13.
- After Stage 13 endpoint corrections land, run the endpoint-oriented suite
  using real `/completion`, `/v1/chat/completions`, and other public endpoints
  as they are used in production.
