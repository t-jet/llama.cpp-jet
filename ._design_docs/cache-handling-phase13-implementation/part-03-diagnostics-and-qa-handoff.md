# Stage 13 implementation - Part 3: diagnostics and QA handoff

Source: [../cache-handling-phase13-implementation.md](../cache-handling-phase13-implementation.md)

## Fallback and degraded diagnostics plan

Degraded fallback is valid only when more complete metadata cannot be derived
safely. Stage 13 implementation should use existing observability
surfaces and bounded messages. It should avoid route-specific public
response fields.

| Case | Expected behavior | Diagnostic requirement |
| --- | --- | --- |
| Flat native prompt string | Build whole-prompt token span metadata | `degraded_reason` states minimal flat prompt metadata |
| Native token-array prompt | Build token/position metadata without pretending message boundaries exist | Bounded debug or stats note for token-array fallback |
| OpenAI chat with mapped text roles | Build message, system/developer, and tool spans when mapping is safe | Route-neutral preparation id identifies metadata method; diagnostic source label identifies chat route family outside namespace inputs |
| OpenAI responses after item conversion | Preserve source facts when conversion keeps them safe; otherwise fallback | Bounded reason names conversion loss or unsupported source item |
| OpenAI audio transcription converted to chat | Treat converted chat completion prompt state as in scope. If audio support or fixtures are unavailable, record unavailable or blocked evidence | Diagnostic source label may name transcription route; `preparation_id` must remain route-neutral unless unsafe degraded isolation is justified |
| Anthropic messages after conversion | Preserve system and message/tool facts when safe; otherwise fallback | Bounded reason names Anthropic conversion loss or unsafe media/tool shape |
| Multimodal prompt without safe media identity | Reject restore candidates that rely on missing media/projector/marker facts; recompute safely | Bounded degraded reason names missing multimodal fact |
| Embedding request not cache-eligible | Do not attach misleading metadata or claim endpoint parity for cache behavior | Implementation evidence states why embedding route is excluded or metadata-only |
| Missing or unmapped boundary | Token/position fallback; no native boundary claim | Existing logs or stats show degraded fallback without leaking prompt content |

Diagnostics must avoid dumping full prompts or raw media. Route name,
endpoint family, fallback class, token count, and bounded reason are
enough.

## Public schema stability checks

QA planning after implementation should compare request and response
compatibility for each in-scope endpoint family. Stage 13 must not add
cache request fields or response fields.

Required checks:

- native `/completion`, `/completions`, and `/v1/completions` still
  accept documented prompt shapes
- OpenAI `/chat/completions` and `/v1/chat/completions` still accept
  chat messages, tools, stream options, and multimodal inputs supported
  by the current build
- OpenAI `/responses` and `/v1/responses` still accept supported
  Responses input forms
- OpenAI `/audio/transcriptions` and `/v1/audio/transcriptions` are
  exercised when audio build support and fixtures exist; otherwise QA
  records the route as unavailable or blocked with the exact missing
  prerequisite
- Anthropic `/v1/messages` still accepts supported message forms
- native and OpenAI embeddings still return normal embedding response
  shapes when server starts with `--embeddings`
- `/metrics` remains metrics-only
- `/slots` save, restore, and erase semantics are unchanged

## Real endpoint parity test handoff

QA should build an endpoint-oriented suite after implementation review
accepts the code. Synthetic Stage 12 rows can inform setup but cannot
replace real endpoint evidence.

Minimum public endpoint rows:

| Row | Endpoint family | Prompt shape | Expected evidence |
| --- | --- | --- | --- |
| E13-01 | Native completion | plain string prompt | Same CLI cache settings produce expected miss/hit or restore behavior |
| E13-02 | Native completion | token-array or mixed prompt | Safe token/position fallback and bounded degraded diagnostic |
| E13-03 | Native completion | available multimodal prompt shape | Safe recompute or restore with media identity guarded |
| E13-04 | OpenAI chat completion | system/user/assistant messages | Namespace and restore policy match equivalent native prepared prompt where compatible |
| E13-05 | OpenAI chat completion | tools or tool outputs | Tool spans captured or degraded with explicit reason |
| E13-06 | OpenAI responses | string input and item-list input | Conversion path preserves schema and metadata source facts where safe |
| E13-07 | OpenAI audio transcription | supported audio upload through `/v1/audio/transcriptions` or `/audio/transcriptions` | Converted chat completion path creates prompt state with route-neutral preparation identity, or QA records unavailable/blocked evidence for missing audio build support or fixtures |
| E13-08 | Anthropic messages | system/messages/tool-use shape | Conversion path preserves schema and safe metadata |
| E13-09 | Native embedding | `input` or `content` | Cache eligibility verdict proven with real route behavior |
| E13-10 | OpenAI embeddings | `/v1/embeddings` | Same eligibility and schema behavior as native embeddings |
| E13-11 | Metrics/logs | degraded fallback request | Existing observability shows bounded degraded reason |
| E13-12 | Slots regression | save, restore, erase | No Stage 13 behavior change |

QA should record server flags for each row, especially `--cache-mode
hybrid`, cache RAM/budget flags, draft model settings, `--embeddings`,
and any multimodal/projector/audio flags. Evidence must include public
HTTP requests, public responses, and cache diagnostics from the same
run. If an endpoint is unavailable because the local build or fixture
set cannot support it, QA must record the exact unavailable condition
instead of dropping the row.

## Implementation evidence expected later

When implementation starts, the developer log should be updated after
each step with:

- changed files and the route family each change affects
- before/after metadata behavior for each handler path
- focused unit or regression tests for helper behavior
- public endpoint smoke evidence before QA handoff
- known degraded paths and why they are safe
- confirmation that no public schema, marker API, or `/slots` behavior
  changed
