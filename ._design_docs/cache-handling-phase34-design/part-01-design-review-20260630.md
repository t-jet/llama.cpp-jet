# Stage 34 design review 2026-06-30

VERDICT: PASS

## Scope and gate status

Review subject:

- `._design_docs/cache-handling-phase34-design.md`
- Manager intake
  `._design_docs/.manager-inputs/manager-input-20260630-stage34-real-agentic-transcript-replay.md`
- Stage 17 design baseline for agentic reuse, prefix rejection, cold budget, and
  observability
- Stage 31 design baseline for compatibility namespace versus validation-only
  prompt identity
- Stage 32 closure and fix evidence for duplicate chat reuse and metric shape
- Stage 33 closure for hot-budget and duplicate-spacing limits
- Current restore-plan code surfaces checked only for concurrency feasibility

Gate status: PASS. No blocking findings.

## Findings

Blocking findings: 0.

Non-blocking findings: 0.

## Review decisions

| Check | Decision |
| --- | --- |
| Architecture and requirements traceability | PASS. The design carries R80-R83 shared branch reuse, R90-R92 correctness-first fallback, R93-R98 benchmarkable hot/cold behavior, and R99-R106 testability. It keeps exact restore as the only required restore path and records prefix opportunities as candidates unless safe prefix restore is added. |
| Transcript replay mapping | PASS. The design matches the inspected `chat_log.jsonl` shape: 354 JSONL rows, one top-level `sessionId`, 10 request-array items, and response/tool records stored as nested patch rows. It requires captured-versus-reconstructed classification instead of assuming every row is a model call. |
| Main-agent continuation after subagent return | PASS. Parent and child branch identity, `subagent_return`, and `continuation` events are modeled. The design correctly limits hits to exact parent-state replay unless a later safe-prefix implementation exists. |
| Concurrent cache sharing safety | PASS. The design keeps one hybrid controller and Stage 25 `tx_restore` / `tx_save` mutation ownership. Code feasibility check confirms `tx_restore` copies target and draft bytes into the restore plan before apply, and apply runs outside the cache mutex from captured bytes. Developer planning still must record this proof or add pinning if the implementation changes the data shape. |
| Namespace compatibility | PASS. Stage 31 remains binding: session, branch, request id, transcript row, prompt hash, and checksum data are validation/evidence inputs, not compatibility namespace inputs. |
| Expected-hit model | PASS. The design requires a pre-run expected-hit table and makes zero-hit failure depend on exact resident-hit predictions plus bounded miss reasons. This avoids repeating the Stage 33 workload-budget mismatch. |
| Hot/cold budget policy | PASS. Budgets are derived from active branch tips, duplicate windows, and cold retention needs. The design requires expected cold misses to be classified rather than treated as product bugs. |
| Observability and privacy | PASS. Evidence uses hashes, counts, bounded reasons, metric deltas, namespace count, candidate classes, and cold-store proof. Raw prompt text is opt-in and confined to an evidence directory. |
| Generic workload acceptance | PASS. `chat_log.jsonl` is one fixture. A synthetic generic agentic fixture must cover the same state machine without Copilot-specific fields. |
| Testability | PASS. The required harness, expected-hit analyzer, sequential and concurrent replay modes, C++ validation tests, and bounded report artifacts are enough for Developer planning and QA test-plan work. |
| Contradictions or missing decisions | PASS. Open items D34-OQ-01 through D34-OQ-05 are implementation-planning choices, not design blockers. None weakens the architecture contract. |

## Evidence notes

- Transcript inspection found the compact patch-log schema (`kind`, `k`, `v`,
  sometimes `i`) and verified the design's warning that subagent work is not
  guaranteed to be a separate top-level session.
- Stage 32 closure proves the current `/v1/chat/completions` evidence path can
  report repeated exact chat reuse: `cache_n` values
  `0,1911,1911,1911,1911,1911` and hybrid hit delta `5`.
- Stage 33 closure explains why long-spaced duplicate traffic can miss under a
  512 MiB hot budget. Stage 34's expected-hit and budget model addresses that
  failure mode.
- `tools/server/server-cache-hybrid.cpp` copies `payload->target` and
  `payload->draft` into `cache_response` during `tx_restore`; the slot apply
  path consumes `plan.target_bytes` and `plan.draft_bytes` after the cache
  mutex is released.

## Required corrections

None.

## Handoff

State: ready for Manager design gate.

Next owner: Manager.

Next gate: Manager design gate. After Manager approval, Developer planning must
turn D34-OQ-01 through D34-OQ-05 into fixed implementation decisions and must
record the restore-plan payload lifetime proof or the explicit pinning design.
