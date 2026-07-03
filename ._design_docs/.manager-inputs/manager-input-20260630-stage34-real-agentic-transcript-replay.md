# MANAGER INPUTS - NOT AN APPROVED DESIGN

Date: 2026-06-30
Stage: 34
Title: Real agentic transcript replay and concurrent cache reuse
Branch: work-branch
Current gate: Design
Next owner: Architect

## User directive

"Open and manage execution of the next phase. The goal of this phase is to make hybrid cache to have expected cache hits while replaying the real agentic development GitHub Copilot session recorded in the `._analysis\chat_log.jsonl` including subagent calls and returning to the main agent and continuing session. After returning from subagent agent should pick up it's previous cached session and continue without regenerating all tokens in his prompt from the scratch. Main agent and subagents should reuse current cache without recalculating it while they are running.
It's a main goal and all possibilities should be considered to achieve it. Of course, it should work  for any agentic workload, not only for this specific one."

## Intake status

Stage 33 is closed as PARTIAL with no product bug. Its reuse row was reclassified
as expected behavior for long-spaced duplicate traffic against a small hot-cache
budget. Stage 34 is a new design stage, not a Stage 33 correction loop.

No approved Stage 34 design, implementation plan, implementation, test plan, or
test report exists at intake. The active gate is Design.

## Source evidence

- `._analysis/chat_log.jsonl`: real GitHub Copilot agentic development session.
  The file has 354 JSONL records and one top-level Copilot `sessionId`.
- `._design_docs/.test_reports/test-report-20260630-03-stage33-01-manager-closure.md`:
  Stage 33 closure and optional follow-up.
- `._design_docs/cache-handling-phase17-design.md`: prior agentic reuse design.
- `._design_docs/cache-handling-phase31-design.md`: namespace compatibility
  decision separating runtime compatibility from prompt-local validation.
- `._design_docs/cache-handling-phase32-implementation.md`: focused duplicate
  chat reuse evidence after cached-token extraction and metric fixes.
- `tools/server/server-cache-hybrid.cpp`, `tools/server/server-context.cpp`,
  `tools/server/server-cache-graph.cpp`, and `tools/server/server-chat.cpp`.

## Required design scope

The design must cover real agentic transcript replay rather than only synthetic
exact-repeat traffic. It must include:

- Main-agent continuation after subagent return, with reuse of the main agent's
  previous cached prompt/session state.
- Subagent calls that reuse compatible cache state while they run, without
  forcing all prompt tokens to be recalculated from scratch.
- Concurrent main-agent and subagent execution against the same cache state,
  with safe sharing, isolation, and validation rules.
- Replay of `._analysis/chat_log.jsonl` as an evidence source, while keeping the
  solution generic for any agentic workload.
- Workload-shape decisions: how to convert Copilot request and response records
  into server requests, how to preserve main/subagent branch identity, how to
  model return-to-parent context, and how to measure expected hits.
- Cache policy decisions for hot retention, cold restore, branch graph lookup,
  checkpoint boundaries, namespace compatibility, and prompt identity.
- Observability needed to prove reuse: cached token counts, hit/miss deltas,
  namespace count, restore miss reasons, branch lookup candidates, and evidence
  tying rows back to transcript turns without storing sensitive prompt text by
  default.
- Regression coverage for generic agentic workloads, not only this transcript.

## Acceptance target for design gate

Design gate can pass only when Architect records:

- Trace from transcript rows to replayed server requests and cache metadata.
- Expected cache-hit model for main-agent continuation and subagent return.
- Concurrency and isolation rules for multiple active agents sharing cache.
- Required production changes, test harness changes, and durable evidence paths.
- Failure classification for zero hits, unexpected namespace growth, unsafe
  prefix rejection, cold payload absence, and cross-agent contamination.
- A generic acceptance plan that uses the real transcript as one fixture, not as
  a hardcoded special case.

