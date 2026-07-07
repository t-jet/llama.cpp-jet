# Stage 34 implementation plan: real agentic transcript replay

Status: CLOSED 2026-07-07 (D-CLOSURE-34-REOPEN-01)
Date: 2026-07-07
Stage: 34
Owner: Developer
Branch: work-branch

## Scope

This document is the implementation entry for Stage 34. It records the approved
design baseline, fixed implementation decisions D34-OQ-01 through D34-OQ-05, and
the implementation evidence needed for review.

## Approved baseline

- Design PASS:
  [cache-handling-phase34-design.md](cache-handling-phase34-design.md)
- Independent design review PASS:
  [part 01](cache-handling-phase34-design/part-01-design-review-20260630.md)
- Manager design gate PASS:
  [part 02](cache-handling-phase34-design/part-02-manager-design-gate-20260630.md)
- Manager intake:
  [.manager-inputs/manager-input-20260630-stage34-real-agentic-transcript-replay.md](.manager-inputs/manager-input-20260630-stage34-real-agentic-transcript-replay.md)
- Stage tracker row 34 is open for implementation planning.

Binding prior-stage decisions:

- Stage 17: exact restore only; prefix candidates are diagnostic unless a later
  safe-prefix design exists.
- Stage 25: cache mutations run through synchronous `tx_*` transactions under
  one recursive cache mutex.
- Stage 31: compatibility namespace excludes prompt-local identity.
- Stage 32: chat-completion reuse evidence reads
  `usage.prompt_tokens_details.cached_tokens`; `timings.cache_n` is fallback.
- Stage 33: budgets must be sized from expected duplicate spacing and active
  branch tips, not from a fixed 512 MiB default.

## Fixed decisions

| Open question | Decision |
| --- | --- |
| D34-OQ-01 | Use JSONL for both normalized replay events and expected-hit rows. Required replay-event fields: `schema_version`, `transcript_row`, `request_id`, `event_kind`, `session_id_hash`, `agent_id_hash`, `parent_agent_id_hash`, `branch_id_hash`, `parent_branch_id_hash`, `turn_index`, `model_id_hash`, `prompt_source`, `prompt_capture`, `render_policy`, `request_body_path`, `messages_sha256`, `token_count`, `token_checksum`, and `blocked_reason`. Required expected-hit fields: `schema_version`, `replay_request_id`, `transcript_row`, `branch_id_hash`, `predecessor_request_id`, `candidate_source`, `expected_class`, `expected_result`, `required_residency`, `token_count`, `token_checksum`, `budget_window_id`, `bounded_miss_reason`, and `notes`. |
| D34-OQ-02 | Carry branch/session/agent data in harness sidecar JSONL and optional request-body metadata fields named under `metadata.stage34`. Production server must ignore those fields for namespace construction. If server-side diagnostics need them, add redacted/hash-only `prepared_prompt_metadata` fields for evidence and ranking only. |
| D34-OQ-03 | No payload pinning in first implementation. Current `tx_restore` deep-copies target bytes, draft bytes, entry tokens, checkpoints, and metadata into `cache_response` before the apply step. `try_restore_from_cache` then applies `plan.target_bytes` and `plan.draft_bytes` outside the cache mutex. Implementation must add C++ regression coverage proving concurrent restore plans survive eviction/demotion of the source entry after capture. If that test cannot be written against current hooks, add test-only hooks before adding production pinning. |
| D34-OQ-04 | Do not implement safe prefix restore in Stage 34. Prefix matches after subagent return are recorded as `unsafe_prefix_rejected` or another bounded prefix-candidate reason. Exact parent-state hits are still accepted when the rendered prompt exactly matches a saved state. |
| D34-OQ-05 | First live Qwen MTP run uses analyzer-derived budgets. Minimum hot entries = active main tip + max concurrent subagent tips + duplicate burst window + one spare. Convert this to MiB using a dry-run estimate from token count and prior observed payload bytes per entry, then round up to the next 512 MiB with a floor of 2048 MiB. Cold budget must hold every expected exact candidate for the replay duration, with a floor of 8192 MiB. Rows that exceed the computed budget are marked `EXPECTED-COLD-MISS` before live execution. |

## Ordered implementation steps

1. Add replay parser and schema tests.
   - Parse append-style provider JSONL into normalized events.
   - Treat `._analysis/chat_log.jsonl` as one fixture, not a hardcoded schema.
   - Classify missing prompts as `BLOCKED-transcript-incomplete`.

2. Add request renderer.
   - Emit `/v1/chat/completions` request bodies.
   - Preserve captured-versus-reconstructed prompt classification.
   - Write sidecar metadata with hashes and paths, not raw prompt text by
     default.

3. Add expected-hit analyzer.
   - Tokenize rendered requests with the selected server/model path.
   - Compute exact duplicates, parent continuation candidates, sibling
     candidates, token counts, checksums, required residency, and budget windows.
   - Fail preflight if no exact resident-hit row is predicted.

4. Add replay runner.
   - Run one server process in sequential mode and concurrent mode.
   - Use `--parallel` high enough to overlap main and subagent work.
   - Capture `requests.jsonl`, `events.jsonl`, `expected-hits.jsonl`,
     `metrics-before.txt`, `metrics-after.txt`, `summary.json`, server log,
     cold-store file proof, and optional raw prompt directory.
   - Default `-OutputDir` resolves to `<workspace>/_test_output/stage34-<run-name>`
     when the caller passes a relative path, so non-durable replay artifacts
     live in the project-root `_test_output/` tree and never under
     `._design_docs/` (which is durable documentation only per
     `cache-handling-test-plan.md`).

5. Add expected-hit result analyzer.
   - Read chat cached tokens from `usage.prompt_tokens_details.cached_tokens`;
     fall back to `timings.cache_n`.
   - Join replay rows to metrics deltas and expected-hit rows.
   - Classify every miss with a bounded reason.

6. Add bounded production diagnostics only if harness evidence cannot prove a
   required row.
   - Candidate additions: parent and sibling branch lookup counters, redacted
     branch/session evidence in prompt evidence records, and hot/cold selected
     candidate residency.
   - Do not add prompt text or raw namespace labels.

7. Add C++ unit and regression coverage.
   - Namespace remains stable when only session, branch, request id, transcript
     row, prompt hash, or checksum fields differ.
   - Branch/session evidence fields do not bypass token/checksum/descriptor
     validation.
   - Prefix continuation remains rejected without slot mutation.
   - Concurrent restore plans apply from copied target/draft bytes after the
     source entry is evicted, demoted, or superseded.
   - Cold promotion failure reports `payload_unavailable`.

8. Add harness-level tests.
   - Synthetic generic agentic fixture covers main request, subagent request,
     subagent return, continuation, exact duplicate burst, and incompatible
     model/template split.
   - Real `chat_log.jsonl` parser smoke test covers row count, one top-level
     session, and captured-versus-reconstructed classification.

9. Run evidence and update implementation log.
   - Record build/test commands, pass/fail counts, replay artifact paths,
     analyzer verdict, and hygiene checks after each completed implementation
     step.

## Affected files

Production files expected:

- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-task.h`
- `tools/server/server-task.cpp`

Harness and script files expected:

- `._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1`
- `._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-replay-parser.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-request-renderer.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-result-analyzer.ps1`

Test files expected:

- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- `tools/server/tests/unit/test_chat_completion.py`
- New harness fixture under
  `._design_docs/cache-handling-test-scripts/_fixtures/stage34/`

Documentation expected:

- This implementation log.
- Later Stage 34 implementation parts if this file approaches 300 lines.
- `._design_docs/document-index.md` and
  `._design_docs/cache-handling-stage-tracker.md`.
- Later QA test-plan entries after implementation-plan review passes.

## No-code-yet boundaries

This gate may only create or update planning documents. It must not:

- edit production C++ or Python/PowerShell harness code;
- add fixtures or tests;
- run live replay, server launches, or model-backed tests;
- generate Stage 34 evidence artifacts;
- change accepted design decisions except through a new design-review loop;
- commit or push.

## Evidence plan

Implementation evidence must include:

- `git status --short` before and after each implementation step.
- Clean Release CUDA configure and clean `test-cache-controller` build.
- Direct `test-cache-controller.exe` run with total pass count.
- `ctest -R cache -V`.
- Targeted Python unit tests for chat cached-token reporting and metrics shape.
- Replay parser synthetic fixture test.
- Expected-hit analyzer dry-run on synthetic fixture and `chat_log.jsonl`.
- Sequential replay on synthetic fixture.
- Concurrent replay on synthetic fixture.
- Live real-transcript replay on Qwen MTP fixture only after dry-run predicts at
  least one exact resident hit.
- `git diff --check`.
- Per-file line count, ASCII, LF-only, no BOM, and no trailing whitespace for
  new markdown files.

All Stage 34 non-durable replay artifacts MUST be written under
`_test_output/stage34-<run-name>/` at the project root. The gitignored
`_test_output/` tree is the only acceptable location; writing replay
artifacts under `._design_docs/` violates the durable-vs-non-durable
separation in `cache-handling-test-plan.md` and was the F34-PATH-01
correction in this rework.

Live replay evidence must include:

- non-zero `cache_n` on predicted exact resident hit rows;
- positive `llamacpp:cache_hits_total{mode="hybrid"}` delta;
- bounded namespace count;
- HELP/TYPE uniqueness;
- hot/cold bytes, payload counts, evictions, demotions, promotions, and
  promotion failures;
- cold-store filesystem byte proof;
- server-log scan for checksum, token count, namespace, restore apply, crash,
  and request errors.

## Risks and fallback

- Transcript prompt gaps may block exact replay. Fallback: classify rows as
  `BLOCKED-transcript-incomplete` or use declared reconstruction policy.
- Prefix opportunities may dominate. Fallback: record prefix candidates and
  keep exact restore as the only hit path.
- Budget under-sizing may hide valid hits. Fallback: rerun analyzer with larger
  hot/cold budgets before classifying product failure.
- Concurrency failures may resemble misses. Fallback: compare sequential and
  concurrent replay from the same expected-hit plan.
- Production diagnostics may be insufficient. Fallback: add bounded hash-only
  diagnostics after a focused evidence gap is documented.
- Deep-copy proof may fail. Fallback: design explicit payload pin/refcount in a
  follow-up implementation-plan correction before changing restore behavior.

## Rollback

- Harness-only changes can be reverted by removing Stage 34 scripts and
  fixtures.
- Production diagnostic changes must be guarded so cache behavior can fall back
  to Stage 33 behavior by disabling the new evidence path.
- If replay runner behavior is unstable, keep parser/analyzer artifacts and
  defer live concurrency execution to QA rather than weakening cache validation.

## Review handoff

Implementation-plan review PASS is recorded in
`._design_docs/cache-handling-phase34-implementation/part-01-implementation-plan-review-20260630.md`.
Manager implementation-plan gate PASS is recorded in
`._design_docs/cache-handling-phase34-implementation/part-02-manager-implementation-plan-gate-20260630.md`.

Implementation evidence is recorded in
`._design_docs/cache-handling-phase34-implementation/part-03-implementation-evidence-20260630.md`.

Implementation review REWORK is recorded in
`._design_docs/cache-handling-phase34-implementation/part-04-implementation-review-20260630.md`.

Rework evidence for F34-IMPL-01 through F34-IMPL-03 is recorded in
`._design_docs/cache-handling-phase34-implementation/part-05-rework-evidence-20260630.md`.

Historical 2026-06-30 handoff: Architect implementation re-review was next;
that path later closed and was superseded by the 2026-07-01 reopen.

## Manager closure

Closed by [part-09-manager-closure-20260630.md](cache-handling-phase34-implementation/part-09-manager-closure-20260630.md) on 2026-06-30 per D-CLOSURE-34-01.
That closure is superseded by [part-10-manager-reopen-20260701.md](cache-handling-phase34-implementation/part-10-manager-reopen-20260701.md).
Stage 34 was reopened for live execution because smaller local model fallback was
not exhausted before accepting timeout-limited rows.
Developer reopened-gate tooling fixes are recorded in
[part-11-reopened-live-tooling-fixes-20260701.md](cache-handling-phase34-implementation/part-11-reopened-live-tooling-fixes-20260701.md).
This note was superseded by the 2026-07-05 reopen cycle.

Reopened implementation for D34-REOPEN-06 and D34-REOPEN-07 is recorded in
[part-15-implementation-evidence-20260705.md](cache-handling-phase34-implementation/part-15-implementation-evidence-20260705.md).
It covers the idempotent-save invariant comments, tx_save SPLIT restructure,
five focused C++ regressions, focused build/test evidence, and remaining QA
handoff items.

Independent implementation review is recorded in
[part-16-implementation-review-20260705.md](cache-handling-phase34-implementation/part-16-implementation-review-20260705.md).
Verdict: REWORK. The production `tx_save` SPLIT is largely conformant, but
T-34-PATHB-01 and T-34-PATHB-02 do not exercise the required production
slow-read and second-pass dedupe branches.

Focused rework evidence is recorded in
[part-17-implementation-rework-evidence-20260705.md](cache-handling-phase34-implementation/part-17-implementation-rework-evidence-20260705.md).
Historical pre-review state: REWORK EVIDENCE READY for Architect
implementation re-review. Superseded by part 18 PASS below.

Independent implementation re-review is recorded in
[part-18-implementation-re-review-20260705.md](cache-handling-phase34-implementation/part-18-implementation-re-review-20260705.md).
Verdict: PASS. The part 16 blocking findings are fixed; Manager
implementation gate is next, then QA test-plan update if Manager accepts.

### Final row counts

- 21 PASS
- 1 PARTIAL (TP-34-AH-02 EXPECTED-BEHAVIOR)
- 9 BLOCKED-driver-killed-mid-cycle
- 0 FAIL
- 0 BLOCKED-evidence-gap

### Closure decisions applied

- D-CLOSURE-34-01 PARTIAL with 21 PASS / 1 PARTIAL / 9 BLOCKED-driver-killed-mid-cycle / 0 FAIL / 0 BLOCKED-evidence-gap (pattern matches Stage 33 closure)
- D-CLOSURE-34-02 BLOCKED-driver-killed-mid-cycle rows are wall-clock-limited (not product defects)
- D-CLOSURE-34-03 TP-34-RN-02 renderer fix applied in `cache-handling-test-scripts/lib/stage34-request-renderer.ps1` (110 -> 123 lines, +13)
- D-CLOSURE-34-04 F34-PATH-01 durable-doc rule enforced; non-durable outputs relocated from `._design_docs/cache-handling-test-scripts/._test_output/` to project-root `_test_output/stage34-*`
- D-CLOSURE-34-05 optional live re-execution session (60-90 min, Qwen3.6-27B-MTP-GGUF) deferred to user

### Code state

Production C++ (`tools/server/server-cache-hybrid.{cpp,h}`, `tools/server/server-context.cpp`, `tools/server/server-task.{cpp,h}`) carries the uncommitted Stage 27/28/30/31/32 fixes. Stage 34-specific renderer change in `cache-handling-test-scripts/lib/stage34-request-renderer.ps1` is untracked (`??`). Per AGENTS.md, all code UNCOMMITTED; user approval required for commit.

Next owner: user.

Final reopen-cycle closure is recorded in
[part-21-manager-closure-20260707.md](cache-handling-phase34-implementation/part-21-manager-closure-20260707.md).
D-CLOSURE-34-REOPEN-01 closes Stage 34 with 5 PASS, 0 FAIL, 0 BLOCKED, 0 SKIP,
and 1 N/A-not-an-execution-row (TP-34-CC expected behavior).
