# Architecture part 9: chat-path prompt-span boundary invariant

Status: post-closure follow-up + bug-fix expansion, 2026-06-16 (F-16-TR-06 matching-loop relaxation appended 2026-06-16)
Source: `._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md`
Source issue: model log analysis 2026-06-16, MTP fixture chat-completion path
Predecessor: Stage 15 two-diff fix (2026-06-13) and the documented
"third-diff extension" left for the chat path
Bug-fix trigger: F-16-TR-02 (test-report-20260616-01.md, MTP internal-checkpoint mismatch)
F-16-TR-06 (test-report-20260616-02.md, MTP checkpoint position misalignment)

## Invariant

When `cache_metadata_from_chat_messages` produces per-message
boundaries (the chat path produced structured message metadata and
emitted at least one `MESSAGE_START` / `MESSAGE_END` pair), it MUST
also emit a per-checkpoint prompt-span boundary for every message
end position. Each such boundary is a `MESSAGE_END` at
`[0, message_token_end]` with `metadata = "prompt"`, `protect = false`,
and a checksum computed over `[0, message_token_end]`. In addition,
the chat path MUST emit an end-of-prompt boundary at
`[0, n_prompt_tokens]` with the same shape, as a safety net for
cases where no message ends at `n_prompt_tokens` (e.g., system + user
only).

This invariant holds regardless of:

- The number of messages (single-message, multi-turn, system +
  user + assistant, tool calls).
- The model architecture (Qwen2.5, Qwen3 dense, Qwen3 MoE,
  Qwen3-MTP, Qwen3.5-MTP, Qwen3.6-MTP).
- The chat template (jinja-rendered or static).
- The hybrid cache mode flag (`legacy`, `hybrid`).
- The boundary inference strategy (rendered-text search, native
  metadata, fallback path).
- The MTP speculative-decoding internal checkpoint creation
  pattern (per-message-end or end-of-prefill).

## Why this is an architecture-level invariant

The boundary metadata model (R27-R33 in
[cache-handling-requirements.md](../cache-handling-requirements.md))
is a stable topic-level contract. The chat path is one of three
metadata entry points:

1. Chat path (`cache_metadata_from_chat_messages`):
   per-message boundaries, `boundaries_native = false`.
2. Fallback path (`cache_metadata_for_request` after chat path
   returns no boundaries): single prompt-span boundary, no
   `boundaries_native` flag.
3. Test-only hand-crafted path (`tests/test-cache-controller.cpp`):
   arbitrary boundaries, used by unit tests.

The fallback path (entry point 2) already emits the prompt-span
boundary. Without the invariant, the chat path (entry point 1)
emits only message-span boundaries, leaving the assistant role
header at the end of the rendered prompt without a boundary.
This gap is structural: the assistant role has no content to
search for in rendered text, so the per-message loop cannot emit
a boundary for it.

The hybrid cache checkpoint path requires a boundary whose
`token_end` equals the checkpoint's `n_tokens`. The chat path's
per-message boundaries never cover the assistant role header, and
the per-message boundaries' `token_start` equals the message start
(not 0), so the strict validator's `token_start` check rejects
them. The MTP speculative-decoding path adds a wrinkle: it
creates internal checkpoints at message end positions (e.g., the
first MTP checkpoint is at end of user message, before the
assistant role header is rendered). The fix is to add per-message
prompt-span boundaries at `[0, message_token_end]` and the
end-of-prompt boundary at `[0, n_prompt_tokens]`, mirroring the
fallback path's shape.

## Why per-checkpoint rather than single prompt-span (2026-06-16 expansion)

The original 2026-06-16 fix (commit `ae2df9657`) emitted a single
`MESSAGE_END` at `[0, n_prompt_tokens]`. The QA execution
[test-report-20260616-01.md](../../.test_reports/test-report-20260616-01.md)
FAILed on the MTP fixture because the MTP speculative-decoding
internal checkpoint is created at `n_tokens = 11` (end of user
message), not at `n_tokens = n_prompt_tokens` (= 61). The
single-boundary fix did not match the MTP internal checkpoint's
`n_tokens`.

The expansion emits one `[0, token_end]` boundary per message
inside the per-message loop, in addition to the
`[0, n_prompt_tokens]` end-of-prompt boundary. This covers:

- MTP internal checkpoints at message end positions (e.g., end
  of user message for the failing test case).
- End-of-prefill checkpoint (covered by the last message's
  boundary when the last message ends at `n_prompt_tokens`,
  or by the explicit end-of-prompt boundary otherwise).

The per-message boundary emission adds 1 boundary per message
(1-5 boundaries for typical chat-completion requests). The
metadata cost is small; the existing fallback path already
emits 2 boundaries (`MESSAGE_START` + `MESSAGE_END` at
`[0, tokens.size()]`).

## Affected surfaces

- `tools/server/server-context.cpp`:
  `cache_metadata_from_chat_messages` MUST emit a
  `[0, token_end]` `MESSAGE_END` boundary per message inside
  the per-message loop, AND the `[0, n_prompt_tokens]`
  end-of-prompt boundary after the loop. Test rows for
  chat-completion hybrid cache save in the test plan.
- `tools/server/server-cache-hybrid.cpp`:
  `attach_checkpoint_payload` and `validate_checkpoint_descriptor_metadata`
  were relaxed for F-16-TR-06: the strict
  `boundary.token_end == descriptor.token_span_end` check is
  replaced with a "prompt" vs non-prompt split. For boundaries
  with `metadata == "prompt"` (the per-message and end-of-prompt
  boundaries added by the chat path), the matching loop picks
  the largest boundary with `token_end <= descriptor.token_span_end`,
  and the descriptor's `boundary_checksum` is recomputed over
  the actual checkpoint span. For non-prompt boundaries (test
  fixtures with hand-crafted metadata), the strict match is
  preserved.
- `tools/server/server-task.h`:
  `prepared_prompt_metadata` unchanged. `boundaries_native` flag
  unchanged. The new boundaries are added with `boundaries_native =
  false` (matching the chat path's existing flag) so the strict
  validator's `boundaries_native` check is satisfied.
- Public API: unchanged. The new boundaries are internal to
  `prepared_prompt_metadata` and are not exposed via HTTP.
- Public metrics: unchanged. The
  `cache_checkpoint_admissions_total` counter is the
  operator-visible evidence of success.

## Cross-stage applicability

This invariant applies to any future stage that exercises the
chat-completion hybrid cache path on a chat template that includes
an assistant role header at the end of the rendered prompt. This
includes:

- All current chat templates (Qwen, Llama, Mistral, etc.) that
  render `<|im_start|>assistant\n` or equivalent at the end.
- All MTP chat-completion rows (Qwen3.5-MTP, Qwen3.6-MTP, future
  MTP variants). The per-message boundary emission covers the
  MTP internal checkpoint pattern (at end of user message for
  short prompts, growing positions for longer prompts).
- All tool-calling chat templates that emit a tool-call response
  in the conversation.

The invariant does NOT apply to:

- Native `/completion` requests that bypass the chat template.
  The fallback path emits the prompt-span boundary already.
- Embedding requests. Cache is excluded for embedding routes
  per the Stage 13 contract.
- Transcription routes. Cache is excluded for transcription
  routes per the Stage 13 contract.

## Limitations and known gaps

The per-message boundary emission covers MTP internal checkpoints
that align with message end positions (e.g., end of user message
for short prompts). For longer prompts where the MTP creates
checkpoints at non-message-end positions (model log shows
positions 9, 17, 70, 196, 709, 60959, 61269, 11829, 12309, 21141,
21525, 22033, 22929, 23313, 23637, ... for a Qwen3.6-27B-MTP
workload), the strict validator would still reject those
checkpoints. The model log shows those positions follow a
non-linear pattern that is not predictable from the chat
structure alone.

For longer prompts, the recommended alternative is Option B
(relax the matching loop to find the boundary whose span
contains the checkpoint span). This is documented in
[test-report-20260616-01-fixes.md](../../.test_reports/test-report-20260616-01-fixes.md)
as a future Manager decision. The per-message boundary emission
addresses the specific failing test case (61-token prompt) and
any future case where the MTP creates a checkpoint at a message
end position.

## Verification

The invariant is verifiable in three ways:

1. **Unit test**: a new unit test in `tests/test-cache-controller.cpp`
   that calls `cache_metadata_from_chat_messages` with a
   representative chat input (system, user, assistant) and
   asserts the metadata has at least one `MESSAGE_END` boundary
   at `[0, tokens.size()]` with `metadata == "prompt"`, plus one
   `MESSAGE_END` boundary at `[0, user_message_end]` with
   `metadata == "prompt"`. This is a pure-metadata test, no
   model required.

2. **Integration test**: a new integration test that exercises
   hybrid cache save on the chat-completion path with a real
   model and asserts `n_checkpoint_payload_descriptors` increases
   after the first save (was 0 before the fix).

3. **QA evidence**: the Stage 15 B05/B06 benchmark report
   rerun on the MTP fixture should show non-zero
   `cache_checkpoint_admissions_total` and `cache_n > 0` on
   subsequent identical chat-completion requests. The pre-fix
   state had 0/30 restores on the MTP fixture; the post-fix
   state should have 29/30 or 30/30.

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| New per-message boundaries at same span as per-message | None | The new boundary is at [0, N], which no per-message boundary can be at |
| `boundaries_native = false` blocks admission | None | The Stage 15 fix removed the `degraded() || !boundaries_native` fallback; chat path's flag is correct for inferred-from-rendered-text boundaries |
| Checksum mismatch on [0, N] | None | The new boundary uses `cache_metadata_checksum(tokens, 0, token_end)`, same function and range the strict validator uses |
| Future chat templates omit assistant role header | Low | The invariant is unconditional in the chat path; the boundary is harmless and matches the same `n_prompt_tokens` |
| MTP creates checkpoint at non-message-end position | Low to medium | Per-message boundary emission covers message-end positions; non-message-end positions would require Option B (relax matching loop) per test-report-20260616-01-fixes.md |
| Metadata cost from N+1 boundaries per request | Negligible | Each boundary is a small struct (~40 bytes); 1-5 boundaries per request is well within the existing per-request metadata budget |

## Handoff

This is an architecture-level invariant. The next stage that
modifies the chat path metadata generation MUST preserve the
invariant. The fix in
`._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md`
is the canonical implementation.

The test plan follow-up picks up the unit test proposal (TP-15-UT1
added in part-09, equivalent to "verify `cache_metadata_from_chat_messages`
emits per-checkpoint prompt-span boundaries"). The QA follow-up
picks up the integration test proposal (TP-15-PC1..TP-15-PC7).
