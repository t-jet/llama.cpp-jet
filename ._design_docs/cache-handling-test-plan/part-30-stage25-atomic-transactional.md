# Test plan part 30: Stage 25 atomic transactional cache writes

Status: closed; final report -01; D-CLOSURE-25-01

This part defines the validation surface for Stage 25 atomic transactional
cache writes. It covers atomicity, isolation, reentrancy, worker idle
semantics, diagnostic evidence, regression of inherited invariants,
performance impact, and integration reuse of the Stage 24 chat runner.

## 1. Scope

In scope:

- tx_* canonical entry points (atomic commit, abort, idempotent retry).
- Slot-level isolation under concurrent requests.
- Reentrancy from prompt-eval, tool-call, and partial-response paths.
- Worker idle transition: any open transaction must drain before idle.
- Diagnostic evidence: txn log, commit marker, abort marker, leak scan.
- Performance impact relative to the Stage 24 baseline.
- Integration reuse of Qwen3.5-4B-MTP fixture and S02/S03 chat rows.

Out of scope:

- Product code changes (developer-owned).
- Stage 24 runner script edits.
- Tracker, document-index, and report file edits.
- New CLI flags, new metric names, new endpoint schemas.

## 2. Test categories

The plan defines seven categories that map to the test ID prefixes below.

| # | Category | Prefix | Purpose |
| --- | --- | --- | --- |
| 1 | Atomicity | TP-25-AT-01..02 | Staged payload survives crash before commit; commit marker visible only after staged payload is durable. |
| 2 | Isolation | TP-25-AT-03..04 | Concurrent writers on distinct slot ids do not interleave; same-slot writers serialize. |
| 3 | Reentrancy | TP-25-AT-05 | Nested prompt-eval during commit preserves invariants and does not lose the commit marker. |
| 4 | Worker idle | TP-25-AT-06 | Worker flushes any open transaction before reporting idle. |
| 5 | Diagnostic | TP-25-AT-07 | Txn log records begin, stage, commit, abort, and idle-flush with monotonic sequence numbers. |
| 6 | Regression | TP-25-EX-01..04 | Existing invariants F-21-EXEC-01, F-21-RERUN-01, F-22-DR-01, and Stage 16 chat-path boundary remain green. |
| 7 | Performance and integration | TP-25-PF-01..03, TP-25-IT-01..02 | Slot p50/p95 latency, N=4 vs N=1 throughput ratio, Stage 24 baseline comparison, and integration rerun of S02/S03 chat rows. |

## 3. Test IDs

| ID | Category | Description |
| --- | --- | --- |
| TP-25-AT-01 | Atomicity | Crash before commit leaves no partial cache entry. |
| TP-25-AT-02 | Atomicity | Commit marker appears only after staged payload is durable. |
| TP-25-AT-03 | Isolation | Concurrent writers on distinct slot ids do not interleave payloads. |
| TP-25-AT-04 | Isolation | Concurrent writers on the same slot id serialize; loser aborts cleanly. |
| TP-25-AT-05 | Reentrancy | Prompt-eval reentry during commit preserves invariants. |
| TP-25-AT-06 | Worker idle | Worker flushes open transaction on idle transition. |
| TP-25-AT-07 | Diagnostic | Txn log captures begin, stage, commit, abort, and idle-flush events. |
| TP-25-EX-01 | Regression | F-21-EXEC-01 exact-execution invariant still passes. |
| TP-25-EX-02 | Regression | F-21-RERUN-01 rerun-determinism invariant still passes. |
| TP-25-EX-03 | Regression | F-22-DR-01 dry-run determinism invariant still passes. |
| TP-25-EX-04 | Regression | Stage 16 chat-path boundary still passes. |
| TP-25-PF-01 | Performance | Slot p50 and p95 latency within Stage 24 envelope. |
| TP-25-PF-02 | Performance | N=4 concurrent throughput ratio vs N=1 within design band. |
| TP-25-PF-03 | Performance | Stage 24 baseline comparison; no regression above 5 percent. |
| TP-25-IT-01 | Integration | Qwen3.5-4B-MTP fixture exercises the transactional path. |
| TP-25-IT-02 | Integration | S02-chat and S03-chat rows reuse the Stage 24 runner; D-EXEC-24-03 applied as informational reference. |

## 4. Classification rules

PASS:

- All assertions pass.
- Required evidence files exist and are non-empty.
- No leak scan findings.
- Verdict file reports PASS.

FAIL:

- Any assertion fails.
- Any required evidence file is missing or empty.
- Leak scan reports a finding.
- Verdict file reports FAIL.
- Handoff: open a reproducible bug report with evidence and txn log excerpts.

BLOCKED:

- Clean build is missing or stale.
- Fixture, port, cold-path, or CUDA runtime proof is missing.
- Test does not execute; classification is not a product bug.

SKIP:

- A test marked obsolete by stage design.
- Obsolete entries are removed from the plan; SKIP is not a hiding mechanism.

Use plain ASCII labels only. Do not use unicode status icons.

## 5. Evidence paths

Each test must produce the following evidence:

- `requests.jsonl` per variant under `<run_root>/<row>/<variant>/`.
- `summary.json` per variant with verdict, requests, cache_n, cold_budget,
  cleanup, cuda_runtime_proof, prompt_evidence, leak_scan, evidence_paths.
- `comparison.json` per row for native vs hybrid stage25.
- `txn.log` per variant for diagnostic tests (TP-25-AT-07).
- `commit_marker.bin` and `staged_payload.bin` for atomicity tests
  (TP-25-AT-01 and TP-25-AT-02).

Run root template: `._test_output/stage25-atomic-<YYYYMMDD>-NN/`.

Report target: `._design_docs/.test_reports/test-report-<YYYYMMDD>-NN.md`.

Bug handoff: `test-report-<YYYYMMDD>-NN-fixes.md` beside the triggering
report with reproducible evidence and txn log excerpts.

## 6. Risks

| ID | Risk | Mitigation |
| --- | --- | --- |
| R-25-TP-01 | Stale binary masks transactional regressions. | Clean build is mandatory before every execution; record binary mtime. |
| R-25-TP-02 | Crash simulation corrupts unrelated fixtures. | Crash target is the staging directory only; never the whole cache root. |
| R-25-TP-03 | N=4 contention wait exceeds threshold on slower hardware. | Record wait time; classify as hardware-bound, not a Stage 25 product bug. |
| R-25-TP-04 | Stage 24 baseline drift invalidates the performance comparison. | Reuse the same `--cache-ram`, cold-path, and prompt set as the -06 baseline. |
| R-25-TP-05 | S03 silent-crash class (D-EXEC-24-03) reappears. | Preserve evidence per part-29; informational only, not a Stage 25 regression. |

## 7. Handoff

Plan closed with final report
[test-report-20260625-01.md](../.test_reports/test-report-20260625-01.md).
Closure accepted per D-CLOSURE-25-01 on 2026-06-25. Per-row final
classification: 14 PASS / 1 BLOCKED-evidence-gap (TP-25-PF-03) /
2 BLOCKED-structural-not-infra (TP-25-IT-01, TP-25-IT-02). Code
changes UNCOMMITTED per AGENTS.md; user approval required for
commit. Follow-ups: D-EXEC-24-03-a SEH handler; D-EXEC-24-03-b
silent-crash investigation widen to S02 hybrid earlier-crash;
D-EXEC-24-03-c cold-store metric vs filesystem drift; PF-03
evidence gap rerun; confirm via rerun whether tx_* routing
accelerated D-EXEC-24-03 manifestation in S02 hybrid.

This file uses LF line endings, plain ASCII labels, no BOM, no
trailing whitespace, and stays under the 300-line durable-doc cap.
