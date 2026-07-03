# Stage 34 design: real agentic transcript replay and concurrent cache reuse

Status: Design PASS; implementation planning open
Date: 2026-06-30
Stage: 34 (Real agentic transcript replay and concurrent cache reuse)
Owner: Architect
Current gate: Implementation planning
Branch: work-branch

## Scope

Stage 34 designs a replay and cache-policy path for real agentic sessions.
The immediate fixture is `._analysis/chat_log.jsonl`, but the design must work
for any agentic workload that can expose stable session, branch, request, and
return-to-parent events.

This stage does not implement code, test scripts, QA reports, or PR text.

In scope:

- transcript row to replay request mapping
- main-agent continuation after subagent return
- concurrent main and subagent reuse of one hybrid cache controller
- branch and session identity carried as validation metadata
- compatibility namespace rules from Stage 31
- hot, cold, and cache-budget decisions from Stage 17 and Stage 33
- evidence for expected hits and safe misses

Out of scope:

- output memoization
- prompt-text storage by default
- special-casing `chat_log.jsonl`
- unsafe prefix restore without full token/checksum validation
- cross-process distributed cache coherence

## Inputs

- Manager intake: `.manager-inputs/manager-input-20260630-stage34-real-agentic-transcript-replay.md`
- Stage 17 design: exact restore, prefix-candidate diagnostics, cold budget
- Stage 31 design: compatibility namespace excludes prompt-local validation
- Stage 32 implementation evidence: tight duplicate chat rows restored with
  `cache_n=1911` and `cache_hits_total` delta `5`
- Stage 33 closure: long-spaced duplicates missed because 512 MiB hot cache
  held about 6 entries and duplicate intervals exceeded retention
- Current server surfaces: `cache_metadata_for_request`,
  `hybrid_cache_controller::tx_restore`, `tx_save`, `tx_apply_restore`,
  `branch_forest_index`, and chat usage cached-token reporting

## Transcript model

The replay parser reads append-style JSONL records and builds a normalized event
stream. `chat_log.jsonl` has one top-level Copilot `sessionId`, 354 JSONL rows,
and 10 main Manager requests. Subagent work appears inside response/tool
records, not as separate top-level Copilot sessions. A generic parser must not
assume this exact shape.

Each normalized event has:

| Field | Meaning |
| --- | --- |
| `transcript_row` | JSONL row number |
| `request_id` | Provider request id or derived stable id |
| `agent_id` | agent name plus mode/instruction URI hash |
| `parent_agent_id` | caller agent id for subagent work |
| `session_id` | provider session id or generated replay session id |
| `branch_id` | stable branch path inside the session |
| `parent_branch_id` | branch to resume after subagent return |
| `turn_index` | monotonic order within branch |
| `event_kind` | main_request, subagent_request, subagent_return, continuation |
| `model_id` | model/deployment identity used for compatibility checks |
| `prompt_source` | rendered request source, never stored raw unless enabled |

The mapper emits one replay request for each LLM call that would have reached
the model in the original agent. Tool-only events become timeline markers.
Subagent returns become continuation events for the parent branch.

## Replay request mapping

Replay requests use `/v1/chat/completions` where possible because Stage 32
proved cached-token extraction there. The replay harness renders each event
into chat messages:

- system/developer setup from the selected agent instructions
- prior branch transcript summary or exact visible messages available in the log
- current user or manager instruction
- subagent call envelope for child branches
- subagent return envelope for parent continuation

The request body may include internal replay metadata only if the production
server ignores it for compatibility namespace construction. Candidate fields:
`session_id`, `branch_id`, `parent_branch_id`, `agent_id`, `turn_index`, and
`transcript_row`. These fields are validation/evidence data, not namespace
inputs.

If a transcript lacks enough prompt text to reproduce a real provider request,
the row is classified `BLOCKED-transcript-incomplete` or rendered with a
declared reconstruction policy. The report must distinguish captured prompts
from reconstructed prompts.

## Branch and session identity

Session identity groups all work from one agentic run. Branch identity separates
the main agent from subagents and separates subagent invocations from each
other. Parent identity records where the main agent resumes.

Identity rules:

- `session_id` is stable across the whole replay.
- main branch id is stable across main-agent turns.
- each subagent call gets a child branch id derived from parent branch,
  call-site row, agent id, and invocation index.
- subagent return records map the child branch back to `parent_branch_id`.
- continuation requests for the main agent must lookup the parent branch tip
  first, then process only the post-return suffix if safe prefix restore exists.
- until safe prefix restore exists, continuation can still prove exact reuse
  when the rendered prompt exactly matches a prior saved state; otherwise it
  records `unsafe_prefix_rejected`, not a hit.

Branch/session fields must help ranking and diagnostics. They must not override
token, checksum, descriptor, pair-state, or model compatibility validation.

## Cache sharing and concurrency

All main and subagent requests in one server process share the same hybrid cache
controller, branch forest, hot payload budget, cold path, and metrics.

Required concurrency behavior:

- `tx_restore` and `tx_save` continue to own cache-state mutation under the
  recursive cache mutex.
- `try_restore_from_cache` may apply the captured state outside the cache mutex,
  as Stage 25 designed, but the plan must remain immutable after capture.
- concurrent requests can read and restore the same payload snapshot.
- eviction, demotion, promotion, and metadata pruning cannot delete a payload
  already captured in a restore plan.
- failed apply restores roll back the slot and call `tx_apply_restore(false)`.
- cross-agent contamination is impossible unless namespace, token span,
  checksum, pair state, payload descriptor, and route/profile all validate.

Implementation planning must decide whether payload snapshots need an explicit
pin/refcount while a restore plan is applying. If current deep-copy behavior is
sufficient for target/draft bytes, record that proof.

## Namespace and validation

Stage 31 remains binding. Compatibility namespace may include model, tokenizer,
chat template, draft/MTP mode, LoRA/control/media identity, context size, KV
layout, workload profile, and `metadata.compatibility_key`.

Namespace must not include prompt-local data:

- transcript row
- request id
- session id or branch id
- agent name or role metadata unless it changes rendered prompt ABI
- boundary spans or checksums
- prompt hash
- tool-call id

Those fields belong in validation, ranking, or redacted evidence. A compatible
namespace only admits candidates for validation; it never proves reuse by
itself.

## Hit model

Stage 34 expected hits are classified before the run:

| Class | Expected outcome |
| --- | --- |
| exact duplicate request burst | first miss, later exact hits if hot or cold promotion succeeds |
| main continuation after subagent return | hit only if exact parent prompt state is replayed; otherwise prefix candidate evidence |
| subagent repeated setup | prefix candidate or exact hit when child setup plus task prompt repeats |
| shared agent instructions across branches | prefix candidate until safe prefix restore is implemented |
| different model/template/profile | namespace split and miss |

The acceptance report must compute an expected-hit table from the replay plan:
request id, branch id, predecessor candidate, token count, checksum, expected
hit class, and required budget residency. A zero-hit run fails only when at
least one row was predicted to be an exact resident hit under the configured
budget and no bounded miss reason explains it.

## Hot, cold, and budget policy

Stage 33 showed that a 512 MiB hot budget can evict useful entries before long
spaced duplicates return. Stage 34 must size budgets from the expected-hit
table, not from a fixed legacy comparison default.

Budget rules:

- hot budget must hold the active main branch tip plus active subagent branch
  tips and at least one expected duplicate burst window.
- cold budget must be large enough to retain evicted exact candidates for the
  replay duration or the row must be marked `EXPECTED-COLD-MISS`.
- cold promotion must be included in hit evidence; a cold candidate that cannot
  promote is `payload_unavailable`.
- reports must include hot entry count, hot bytes, cold bytes, cold payload
  count, evictions, demotions, promotions, and promotion failures.

## Observability and evidence

Required per-request evidence:

- transcript row, replay request id, session id hash, branch id hash
- agent id hash and parent branch id hash
- prompt token count and token-span checksum
- namespace count and lookup namespace hash
- `cache_n` from `usage.prompt_tokens_details.cached_tokens` when present
- hit/miss result and bounded miss reason
- branch lookup candidates by bounded source: token span, checksum span,
  parent branch, sibling branch
- hot/cold residency of selected candidate
- output equivalence or deterministic replay classification

Required aggregate evidence:

- `llamacpp:cache_hits_total{mode="hybrid"}` delta
- `llamacpp:cache_misses_total{mode="hybrid"}` delta
- restore miss deltas by bounded reason
- namespace count with bounded labels
- HELP/TYPE uniqueness for cache metrics
- cold-store filesystem byte proof
- error scan for checksum, token count, namespace validation, restore apply,
  crash, and request errors

Prompt text is off by default. Raw prompt capture is opt-in and must stay under
a configured evidence directory.

## Production and harness changes

Developer planning should cover these surfaces:

- replay parser for provider JSONL into normalized agent events
- request renderer for chat completions with branch/session metadata
- expected-hit analyzer using rendered token vectors
- optional cache metadata fields for branch/session evidence
- branch lookup diagnostics for parent and sibling candidates
- restore-plan payload lifetime proof or pinning
- bounded metrics/log additions only if existing metrics cannot prove the rows
- focused C++ tests for validation and concurrent restore snapshots

The harness must run one server process with `--parallel` high enough for main
and subagent overlap. It must also support a deterministic sequential mode so
QA can isolate replay-mapping bugs from concurrency bugs.

## Acceptance criteria

Design and later implementation can pass only when:

- replay mapping is deterministic and records captured versus reconstructed
  prompts
- branch/session identity is present in evidence and excluded from namespace
- exact duplicate bursts prove non-zero `cache_n` and hit-counter deltas
- main-agent continuation after subagent return either hits an exact parent
  state or records a bounded prefix/validation miss
- concurrent main/subagent requests share cache safely without contamination
- namespace count stays bounded unless a real compatibility input changes
- hot/cold budgets explain every expected hit, miss, eviction, and promotion
- `chat_log.jsonl` is one fixture; at least one synthetic generic agentic
  fixture covers the same state machine without Copilot-specific fields
- reports include enough evidence for Developer review without raw prompt text

## Risks and open decisions

Open decisions for Developer planning:

- D34-OQ-01: exact JSONL schema for replay event records and expected-hit rows
- D34-OQ-02: whether branch/session metadata is carried in request JSON,
  internal task metadata, or evidence-only sidecar
- D34-OQ-03: whether current restore-plan deep copies prove safe concurrent
  payload use or need explicit payload pinning
- D34-OQ-04: whether Stage 34 implements safe prefix restore or records prefix
  candidates only; default is candidates only
- D34-OQ-05: budget sizing for the first live run on the Qwen MTP fixture

Risks:

- transcript lacks full provider request prompts; mitigate with captured versus
  reconstructed classification
- prefix opportunities may dominate but exact restore cannot use them yet
- concurrency failures may look like cache misses; mitigate with sequential and
  concurrent replay modes
- raw evidence can leak prompt text; default to hashes and counts

## Handoff

Design authoring and independent design review are complete. Manager design gate
PASS is recorded in
`._design_docs/cache-handling-phase34-design/part-02-manager-design-gate-20260630.md`.

Next owner: Developer fresh session for implementation planning.

No implementation or QA execution is approved until implementation planning and
implementation-plan review pass.
