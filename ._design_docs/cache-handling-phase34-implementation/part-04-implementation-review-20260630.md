# Stage 34 implementation review 2026-06-30

VERDICT: REWORK

## Scope and gate status

Review subject:

- `._design_docs/cache-handling-phase34-implementation.md`
- `._design_docs/cache-handling-phase34-implementation/part-03-implementation-evidence-20260630.md`
- Stage 34 replay scripts, fixture, dry-run output, C++ test changes, and Python test
- Accepted Stage 34 design and implementation-plan gate documents

Gate status: REWORK. Implementation review cannot pass with open blockers.

## Blocking findings

### F34-IMPL-01: Replay event model does not implement branch/subagent state

Required by:

- `._design_docs/cache-handling-phase34-design.md`, "Transcript model",
  "Branch and session identity", "Acceptance criteria"
- `._design_docs/cache-handling-phase34-implementation.md`, steps 1 and 8

Evidence:

- `._design_docs/cache-handling-test-scripts/lib/stage34-replay-parser.ps1:95`
  implements `ConvertTo-Stage34ReplayEvents`.
- The same parser emits only `event_kind = "main_request"`,
  `BranchId "main"`, and `ParentBranchId ""` at lines 126-131,
  148-153, and 169-174.
- Synthetic fixture rows in
  `._design_docs/cache-handling-test-scripts/_fixtures/stage34/synthetic-agentic.jsonl`
  have no explicit branch, parent, subagent-call, subagent-return, or
  continuation records.
- Dry-run evidence confirms the shape:
  synthetic `events.jsonl` has `main_request=5`, one unique branch, and zero
  parent-branch rows; real `chat_log.jsonl` dry-run has `main_request=56`, one
  unique branch, and zero parent-branch rows.

Impact:

Stage 34's core acceptance target is real agentic replay: main branch,
subagent branches, subagent return, and parent continuation. Current output
flattens the transcript into a single main branch. It cannot prove concurrent
main/subagent reuse or main-agent continuation after subagent return.

Required correction:

Parse or synthesize normalized events with the approved event kinds
`main_request`, `subagent_request`, `subagent_return`, and `continuation`, with
stable child branch ids and `parent_branch_id` on return/continuation rows.
Update the synthetic fixture so it covers that state machine without
Copilot-specific fields, then regenerate dry-run evidence that shows multiple
branches and parent links.

### F34-IMPL-02: Expected-hit model is based on message hashes only, not token/checksum and branch plan

Required by:

- `._design_docs/cache-handling-phase34-design.md`, "Hit model" and
  "Observability and evidence"
- `._design_docs/cache-handling-phase34-implementation.md`, step 3 and
  evidence plan

Evidence:

- `._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1:19`
  keys candidates only by `messages_sha256|model_id_hash`.
- Lines 15 and 33 approximate residency from `HotBudgetMiB / 512` and
  nonzero `ColdBudgetMiB`, not rendered token count, payload byte estimate, or
  active branch tips.
- Lines 53-56 write `token_count` and `token_checksum`, but the current dry-run
  event rows keep both at zero/empty.

Impact:

The analyzer can predict hits without the design-required token-span checksum,
branch predecessor, candidate source, and budget residency proof. Current
`chat_log.jsonl` evidence reports 23 expected-hit rows, but those are hash
duplicates in a flattened single-branch model with no token/checksum data. That
is not enough to decide whether a zero-hit run is a product failure or a
bounded miss.

Required correction:

Make expected-hit rows derive from the rendered replay plan's token count,
token checksum, branch id, predecessor candidate, expected class, and computed
budget window. Preflight should fail when token/checksum data required for an
exact resident-hit prediction is missing.

### F34-IMPL-03: Restore-plan deep-copy regression is only target-only

Required by:

- `._design_docs/cache-handling-phase34-implementation.md`, D34-OQ-03 and
  ordered step 7

Evidence:

- `tests/test-cache-controller.cpp:1729` admits the test entry with
  `target_bytes = 64` and `draft_bytes = 0`.
- Assertions at lines 1739-1745 check only `plan.target_bytes`.
- The evidence report states draft bytes follow the same production copy path
  but the current hook exercises only target-only restore.

Impact:

The test is useful, but it does not fully prove the accepted D34-OQ-03 claim
that captured restore plans preserve target and draft bytes after source
payload eviction/demotion. Stage 34 is explicitly tied to Qwen MTP and
target/draft cache pairing.

Required correction:

Add focused coverage for a target+draft payload restore plan, or document why
the existing hooks cannot expose draft bytes and add the minimal test-only hook
needed. The corrected evidence must prove both byte vectors survive source
payload eviction or demotion after plan capture.

## Non-blocking findings

None.

## Passed checks

- Branch/session/agent metadata is sidecar/request metadata and not added to
  `prepared_prompt_metadata.compatibility_key`.
- The renderer avoids raw prompt text by default; raw prompt output requires
  `-IncludeRawPrompts`.
- Result analyzer prefers
  `usage.prompt_tokens_details.cached_tokens` before `timings.cache_n`.
- No safe-prefix restore was added.
- Python cached-token regression passed.
- Synthetic dry-run is reproducible, though not sufficient for gate PASS.
- `git diff --check` produced no whitespace warnings for tracked diffs.

## Checks run

| Check | Result |
| --- | --- |
| `git diff --check` | PASS, no output |
| `python -m pytest tests/test-stage34-result-analyzer.py -q` | PASS, 1 passed |
| `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -TranscriptPath ._design_docs/cache-handling-test-scripts/_fixtures/stage34/synthetic-agentic.jsonl -OutputDir ._design_docs/cache-handling-test-scripts/._test_output/stage34/review-synthetic-dry-run -Mode dry-run` | PASS command exit; evidence still has one branch only |
| Event-shape inspection of synthetic and chatlog dry-run `events.jsonl` | FAIL gate: only `main_request`, one branch, no parent branch rows |
| Path correction note (added 2026-06-30 by Developer rework) | The `-OutputDir` paths cited in this review's row 3 point under `._design_docs/cache-handling-test-scripts/._test_output/`, which is the wrong non-durable location per `cache-handling-test-plan.md`. F34-PATH-01 corrected the runner default and moved evidence to the project-root `_test_output/stage34-*` tree. This review's findings row above is preserved verbatim; the path correction is documented in [part 05](part-05-rework-evidence-20260630.md). |

## Handoff

State: rework required.

Next owner: Developer.

Next gate: implementation re-review after F34-IMPL-01 through F34-IMPL-03 are
fixed and evidence is regenerated.
