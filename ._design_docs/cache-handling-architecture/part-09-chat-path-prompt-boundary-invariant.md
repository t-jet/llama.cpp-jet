# Architecture part 9: chat-path prompt-span boundary invariant

Status: post-closure follow-up, 2026-06-16
Source: `._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md`
Source issue: model log analysis 2026-06-16, MTP fixture chat-completion path
Predecessor: Stage 15 two-diff fix (2026-06-13) and the documented
"third-diff extension" left for the chat path

## Invariant

When `cache_metadata_from_chat_messages` produces per-message
boundaries (the chat path produced structured message metadata and
emitted at least one `MESSAGE_START` / `MESSAGE_END` pair), it MUST
also emit one additional `MESSAGE_END` boundary at `[0, n_prompt_tokens]`
with `metadata = "prompt"`, `protect = false`, and a checksum
computed over the full prompt range.

This invariant holds regardless of:

- The number of messages (single-message, multi-turn, system +
  user + assistant, tool calls).
- The model architecture (Qwen2.5, Qwen3 dense, Qwen3 MoE,
  Qwen3-MTP, Qwen3.5-MTP, Qwen3.6-MTP).
- The chat template (jinja-rendered or static).
- The hybrid cache mode flag (`legacy`, `hybrid`).
- The boundary inference strategy (rendered-text search, native
  metadata, fallback path).

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
`token_end` equals the checkpoint's `n_tokens` (the full prompt
size at end of prefill). The chat path's per-message boundaries
never cover the assistant role header, so the checkpoint cannot
attach. The fix is to add a prompt-span boundary in the chat
path, mirroring the fallback path's shape.

## Affected surfaces

- `tools/server/server-context.cpp`:
  `cache_metadata_from_chat_messages` MUST emit the prompt-span
  boundary. Test rows for chat-completion hybrid cache save in
  the test plan.
- `tools/server/server-cache-hybrid.cpp`:
  `attach_checkpoint_payload` and `validate_checkpoint_descriptor_metadata`
  unchanged. The matching loop and the strict validator continue
  to require `boundary.token_end == descriptor.token_span_end`
  (after the Stage 15 fix removed the `token_start` filter). The
  new chat-path boundary satisfies this requirement for the
  first end-of-prefill checkpoint.
- `tools/server/server-task.h`:
  `prepared_prompt_metadata` unchanged. `boundaries_native` flag
  unchanged. The new boundary is added with `boundaries_native =
  false` (matching the chat path's existing flag) so the strict
  validator's `boundaries_native` check is satisfied.
- Public API: unchanged. The new boundary is internal to
  `prepared_prompt_metadata` and is not exposed via HTTP.
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
  MTP variants).
- All tool-calling chat templates that emit a tool-call response
  in the conversation.

The invariant does NOT apply to:

- Native `/completion` requests that bypass the chat template.
  The fallback path emits the prompt-span boundary already.
- Embedding requests. Cache is excluded for embedding routes
  per the Stage 13 contract.
- Transcription routes. Cache is excluded for transcription
  routes per the Stage 13 contract.

## Verification

The invariant is verifiable in three ways:

1. **Unit test**: a new unit test in `tests/test-cache-controller.cpp`
   that calls `cache_metadata_from_chat_messages` with a
   representative chat input and asserts the metadata has at
   least one `MESSAGE_END` boundary at `[0, tokens.size()]` with
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
| New boundary at same span as per-message | None | The new boundary is at [0, N], which no per-message boundary can be at |
| `boundaries_native = false` blocks admission | None | The Stage 15 fix removed the `degraded() || !boundaries_native` fallback; chat path's flag is correct for inferred-from-rendered-text boundaries |
| Checksum mismatch on [0, N] | None | The new boundary uses `cache_metadata_checksum(tokens, 0, n_prompt_tokens)`, same function and range the strict validator uses |
| Future chat templates omit assistant role header | Low | The invariant is unconditional in the chat path; the boundary is harmless and matches the same `n_prompt_tokens` |

## Handoff

This is an architecture-level invariant. The next stage that
modifies the chat path metadata generation MUST preserve the
invariant. The fix in
`._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md`
is the canonical implementation.

The test plan follow-up picks up the unit test proposal (TP-15-UT1
added in part-09, equivalent to "verify `cache_metadata_from_chat_messages`
emits a prompt-span boundary"). The QA follow-up picks up the
integration test proposal (TP-15-PC1..TP-15-PC7).
