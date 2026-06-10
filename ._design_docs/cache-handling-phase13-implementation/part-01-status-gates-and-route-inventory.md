# Stage 13 implementation - Part 1: status, gates, and route inventory

Source: [../cache-handling-phase13-implementation.md](../cache-handling-phase13-implementation.md)

## Status

| Item | State |
| --- | --- |
| Manager design gate | PASS, 2026-06-09 |
| Implementation planning | Reworked after independent plan review, 2026-06-09 |
| Independent plan review | REWORK, 2026-06-09 |
| Independent plan re-review | PASS, 2026-06-09 |
| Product code changes | Complete, ready for implementation review |
| Test, script, or report changes | Focused controller regression added; endpoint suites not run |
| QA planning | Not started |
| Endpoint execution | Not started |

This route inventory is based on inspection of current route registration
and handler code. Implementation is now complete and ready for review.

Rework record: the first plan review found two blockers. This revision
adds audio transcription routes to the route inventory and makes
`preparation_id` route-neutral for equivalent prompt state.

## Route inventory

Routes are registered in `tools/server/server.cpp`. In proxy mode,
the same public route names are routed through model proxy handlers, so
implementation must check both normal and proxy wiring when verifying
endpoint availability. Stage 13 implementation work targets normal local
server task creation.

| Public route | Handler field | Current handler path | Task path | Stage 13 status |
| --- | --- | --- | --- | --- |
| `POST /completion` | `post_completions` | parse JSON, call `handle_completions_impl` with `TASK_RESPONSE_TYPE_NONE` | `SERVER_TASK_TYPE_COMPLETION` with `task.tokens`, `task.prompt_metadata`, `task.params` | In scope |
| `POST /completions` | `post_completions` | same as `/completion` | same as `/completion` | In scope |
| `POST /v1/completions` | `post_completions_oai` | parse JSON, call `handle_completions_impl` with `TASK_RESPONSE_TYPE_OAI_CMPL` | `SERVER_TASK_TYPE_COMPLETION` | In scope |
| `POST /chat/completions` | `post_chat_completions` | parse OpenAI chat body through `oaicompat_chat_params_parse`, then `handle_completions_impl` with original `messages` pointer | `SERVER_TASK_TYPE_COMPLETION` | In scope |
| `POST /v1/chat/completions` | `post_chat_completions` | same as `/chat/completions` | same as `/chat/completions` | In scope |
| `POST /v1/responses` | `post_responses_oai` | `server_chat_convert_responses_to_chatcmpl`, `oaicompat_chat_params_parse`, then `handle_completions_impl` | `SERVER_TASK_TYPE_COMPLETION` | In scope |
| `POST /responses` | `post_responses_oai` | same as `/v1/responses` | same as `/v1/responses` | In scope |
| `POST /v1/audio/transcriptions` | `post_transcriptions_oai` | requires `has_mtmd` and `allow_audio`, converts with `convert_transcriptions_to_chatcmpl`, parses through `oaicompat_chat_params_parse`, then calls `handle_completions_impl` with `TASK_RESPONSE_TYPE_OAI_ASR` | `SERVER_TASK_TYPE_COMPLETION` with converted chat messages and completion prompt metadata | In scope; if local build or fixtures lack audio support, QA must record unavailable or blocked evidence rather than omit the route |
| `POST /audio/transcriptions` | `post_transcriptions_oai` | same as `/v1/audio/transcriptions` | same as `/v1/audio/transcriptions` | In scope; same availability rule |
| `POST /v1/messages` | `post_anthropic_messages` | `server_chat_convert_anthropic_to_oai`, `oaicompat_chat_params_parse`, then `handle_completions_impl` | `SERVER_TASK_TYPE_COMPLETION` | In scope |
| `POST /v1/messages/count_tokens` | `post_anthropic_count_tokens` | Anthropic body converts to OpenAI chat, then tokenizes prompt and returns count | no `server_task` inference path | Inventory only; no cache state should be introduced |
| `POST /embedding` | `post_embeddings` | parse `input` or `content`, tokenize, call `handle_embeddings_impl` | `SERVER_TASK_TYPE_EMBEDDING` without current `prompt_metadata` assignment | In scope for eligibility decision |
| `POST /embeddings` | `post_embeddings` | same as `/embedding` | same as `/embedding` | In scope for eligibility decision |
| `POST /v1/embeddings` | `post_embeddings_oai` | call `handle_embeddings_impl` with `TASK_RESPONSE_TYPE_OAI_EMBD` | `SERVER_TASK_TYPE_EMBEDDING` | In scope for eligibility decision |
| `GET /metrics` | `get_metrics` | queue `SERVER_TASK_TYPE_METRICS` or direct metrics path | metrics result only | In scope for diagnostics evidence, no schema expansion required |
| `GET /slots` | `get_slots` | server slot inspection | no hybrid cache task creation | Regression only |
| `POST /slots/:id_slot` | `post_slots` | slot save, restore, or erase tasks | `SERVER_TASK_TYPE_SLOT_SAVE`, `SERVER_TASK_TYPE_SLOT_RESTORE`, `SERVER_TASK_TYPE_SLOT_ERASE` | Regression only; no semantic change |

Other routes are out of Stage 13 cache scope unless plan review finds
that they create prompt state. `POST /infill`, `/tokenize`,
`/detokenize`, `/rerank`, LoRA routes, health, props, and model-list
endpoints are not endpoint parity targets for this stage.

## Current metadata path

`handle_completions_impl` tokenizes the prepared prompt, creates
`server_task`, and assigns `task.prompt_metadata` through
`cache_metadata_for_request`. That helper can call
`cache_metadata_from_chat_messages` when original chat messages are
available, otherwise it creates minimal completion metadata over the
whole prompt.

`handle_embeddings_impl` currently tokenizes embedding input and creates
`SERVER_TASK_TYPE_EMBEDDING` tasks without assigning
`task.prompt_metadata`. Stage 13 implementation must decide whether
embedding tasks are cache-eligible in the current server execution path;
if they are, it must attach safe metadata through the same helper family.

## Planned implementation steps

| Step | Work | Completion evidence expected later |
| --- | --- | --- |
| 13.1 | Route audit and handler map confirmation | Complete; see Part 8 |
| 13.2 | Metadata helper refactor plan execution | Complete; see Part 8 |
| 13.3 | Endpoint adapter updates, including transcription availability handling | Complete for task metadata; audio support remains a QA availability check |
| 13.4 | Degraded diagnostics | Complete for bounded debug logging |
| 13.5 | Endpoint parity tests | Not run; remains QA handoff after implementation review |
