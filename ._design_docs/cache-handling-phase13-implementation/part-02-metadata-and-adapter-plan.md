# Stage 13 implementation - Part 2: metadata construction and endpoint adapter plan

Source: [../cache-handling-phase13-implementation.md](../cache-handling-phase13-implementation.md)

## Current functions to refactor or extend

| Function or type | Current role | Stage 13 plan |
| --- | --- | --- |
| `prepared_prompt_metadata` in `tools/server/server-task.h` | Holds boundaries, compatibility key, preparation id, degraded reason, protection hints, and native/inferred flag | Reuse the type. Add fields only if a route cannot represent required identity safely with existing fields and boundaries. Preserve existing serialization assumptions. |
| `prompt_boundary` in `tools/server/server-task.h` | Represents system, message, and tool-call span boundaries | Reuse existing boundary kinds where they are enough. Avoid adding public API concepts. If media identity needs more detail, prefer conservative namespace keys or metadata strings over route-specific policy. |
| `cache_metadata_content_text` | Extracts text from chat content | Extend to cover structured chat content consistently, including text arrays, tool output text, and safe refusal/reasoning text where rendered into prompt. It must not treat unsupported media as text. |
| `cache_metadata_token_index` | Maps prompt character offsets to token offsets | Keep as fallback support. Native or adapter-captured token spans should avoid repeated rendered-text searches when route preparation can provide better spans. |
| `cache_metadata_checksum` | Computes token-span checksum | Keep as shared span checksum utility for all routes. |
| `cache_metadata_from_chat_messages` | Builds inferred boundaries from rendered prompt and original chat messages | Refactor into adapter-level chat metadata source. Mark inferred output degraded unless native spans are captured during prompt preparation. |
| `cache_metadata_for_request` | Completion helper that chooses chat metadata or minimal metadata | Replace with a route-neutral builder that accepts a small metadata input struct: diagnostic source label, prepared prompt, tokens, optional original structured messages, optional source prompt shape, optional multimodal facts, and fallback reason. |
| `handle_completions_impl` | Shared completion task creation path | Keep cache-policy free. It should call the shared builder after prompt tokenization and before posting `server_task`. |
| `handle_embeddings_impl` | Embedding task creation path | Add helper use only if embedding tasks can participate safely in cache lookup/save. If not eligible, document the explicit reason and ensure no misleading metadata is attached. |
| `server_chat_convert_responses_to_chatcmpl` | Converts OpenAI Responses input to chat-completion body | Preserve conversion output schema. Add or preserve source-structure breadcrumbs only internally if needed before `oaicompat_chat_params_parse`; do not expose request fields. |
| `server_chat_convert_anthropic_to_oai` | Converts Anthropic messages to OpenAI chat body | Preserve Anthropic-compatible schema. Carry enough internal source structure to build boundaries after conversion, or document degraded fallback when conversion loses safe detail. |
| `hybrid_cache_controller::compute_namespace_id`, `hybrid_cache_controller::find_best_match`, and checkpoint descriptor helpers | Consume metadata for namespace and boundary validation. Current namespace computation includes `metadata.preparation_id`. | Do not move endpoint policy here. Because `preparation_id` is namespace-affecting, it must remain route-neutral for equivalent prompt state unless unsafe degraded isolation is explicitly justified. Endpoint family must not be used as `preparation_id`. |

## Shared builder shape

Implementation should introduce one internal helper family near the
current metadata helpers in `server-context.cpp`, or a small dedicated
server metadata module if review prefers separation. The plan assumes
local helper refactor first, with module extraction only if the code
becomes hard to review.

The builder should take internal inputs, not raw public schema ownership:

| Input | Purpose |
| --- | --- |
| diagnostic source label enum or string | Route family and conversion source for logs, counters, and implementation evidence only; it must not feed namespace inputs |
| prepared prompt JSON/string | Lets fallback map source text to token spans |
| `server_tokens` | Provides token count and checksum source |
| optional original chat messages | Captures message, role, tool, reasoning, and text content boundaries |
| optional native span list | Allows future prompt preparation code to pass exact token spans |
| optional source prompt shape | Distinguishes string prompt, token array, mixed prompt, embedding input, multimodal prompt |
| optional multimodal facts | Records whether media/projector/marker layout is safe enough for reuse |

The builder should return `prepared_prompt_metadata` with:

- stable `compatibility_key`
- route-neutral `preparation_id`, because it is included in namespace
  computation
- `boundaries_native = true` only when spans come from native capture
- degraded reason when spans are inferred, minimal, multimodal-unsafe, or unavailable
- token-span checksums on every span that can affect restore validation
- protection hints for system and developer messages when safely mapped

## Preparation identity and diagnostics split

Stage 13 must keep two concepts separate:

| Concept | May affect namespace? | Allowed contents |
| --- | --- | --- |
| `preparation_id` | Yes, current hybrid namespace includes `metadata.preparation_id` | Route-neutral preparation method, such as native spans, rendered-text inference, token-position fallback, or unsafe degraded isolation class |
| Diagnostic source label | No | Endpoint family, public route, conversion source, adapter name, fallback counter label, and bounded log context |

Equivalent prompt state prepared through different public routes should
use the same `preparation_id` when model, template, draft configuration,
multimodal identity, cache settings, and safe boundary metadata match.
Do not set `preparation_id` to "chat", "responses", "anthropic",
"transcriptions", "completion", or any other endpoint family name.

Unsafe degraded paths may use a distinct `preparation_id` only when
the implementation evidence explains why route-neutral reuse would risk
wrong restore behavior. Put endpoint source labels in bounded logs,
diagnostic counters, or implementation evidence, not in namespace
inputs.

## Endpoint adapter responsibilities

Adapters may extract request-shape facts, call existing conversion
helpers, and pass structured metadata inputs to the shared builder. They
must not decide cache admission, restore policy, cold promotion, branch
retention, checkpoint behavior, or namespace matching beyond passing the
facts used by the shared builder.

| Adapter | Responsibilities |
| --- | --- |
| Native completion | Preserve string, token-array, array-of-prompts, mixed, and multimodal prompt support. Build minimal token/position metadata for flat prompts and more complete metadata only when structure is safe. |
| OpenAI chat completions | Pass original `messages` plus converted rendered prompt. Capture roles, system/developer protection, tool calls, tool outputs, reasoning text, and text content spans when safely renderable. |
| OpenAI responses | Convert with `server_chat_convert_responses_to_chatcmpl`, but keep source item types available for metadata where conversion preserves safe meaning. Degrade when item merging or unsupported fields prevent safe boundaries. |
| OpenAI audio transcriptions | Convert with `convert_transcriptions_to_chatcmpl` and treat the resulting prompt state as completion scope. Pass converted chat messages and audio/media facts when safe. If build support or local fixtures are unavailable, leave implementation behavior explicit and require QA unavailable or blocked evidence. |
| Anthropic messages | Convert with `server_chat_convert_anthropic_to_oai`, preserve system and message roles, tool use/output, and media facts when conversion keeps them safe. Degrade when billing header normalization or conversion loses reliable spans. |
| Embeddings | Determine cache eligibility first. If eligible, use token/position metadata at minimum and richer metadata only for structured inputs. If not eligible, record no-cache rationale in implementation evidence. |
| Metrics | Surface existing counters and bounded logs for normal and degraded behavior. Do not add public cache-control routes. |
| Slots | No adapter changes. Only regression evidence after implementation. |

## Non-goals

- No cache-specific request fields.
- No public marker API.
- No public cache-control endpoint.
- No `/slots` save, restore, or erase behavior change.
- No endpoint-specific cache policy.
- No requirement for users to edit templates.

## Compatibility rules for implementation

Equivalent prompt state should reach the same namespace when model,
template, draft configuration, multimodal identity, cache settings, and
safe boundary metadata match. Different degraded reasons may
intentionally isolate unsafe metadata paths. That isolation is
acceptable only when the implementation evidence explains why richer
metadata was unavailable. Endpoint family alone is not a valid isolation
reason.

Fork-only Jinja markers remain test input. Marked prompts must be
stripped before tokenization and inference, and Stage 13 must not expose
the marker format as public endpoint contract.
