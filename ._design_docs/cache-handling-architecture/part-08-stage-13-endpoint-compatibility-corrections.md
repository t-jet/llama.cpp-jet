# Software Architecture: Alternate Hybrid Cache Mode for llama-server - Part 8: Stage 13 Endpoint Compatibility Corrections

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

## Scope

Stage 13 corrects endpoint behavior after the Stage 12 fix pass.
Stage 12 fixes are treated as the baseline. Any Stage 12 rows that have
not been rerun remain QA evidence work; they do not narrow the endpoint
contract.

The target is endpoint parity: public compatible routes keep their
documented request and response schemas while using every enabled
hybrid-cache enhancement selected by llama-server command-line options.

## Public contract

- OpenAI-compatible endpoints, Anthropic-compatible endpoints, and native
  llama-server completion surfaces must share the same cache-mode
  selection rules.
- Command-line options decide whether hybrid cache behavior is enabled.
  Request payloads must not need cache-specific fields.
- Endpoint adapters may build different `PreparedPromptMetadata` because
  their request shapes differ, but they must use the richest safe metadata
  each route can derive.
- Degraded token/position fallback is valid only when richer
  message/tool/media boundaries cannot be derived safely.
- The fork-only Jinja marker interface remains a test harness. It must
  not become a public endpoint contract.

## Route families

Stage 13 covers every route family that can create prompt state or reuse
cached model state:

| Route family | Required behavior |
| --- | --- |
| OpenAI-compatible chat/responses/completions | Preserve the public schema. Capture internal boundary metadata during prompt preparation when possible. |
| Anthropic-compatible messages/completions | Preserve Anthropic-compatible schema. Map message, tool, and media structure into the same internal metadata model. |
| Native `/completion` and `/embedding` | Preserve documented prompt shapes. Derive metadata from supported token, string, mixed, and multimodal inputs. |
| Metrics and logs | Report normal cache behavior and degraded fallback through existing observability surfaces. Do not add a cache-specific public control endpoint. |

## Required corrections

1. Audit endpoint routing so compatible endpoints cannot bypass the
   hybrid-cache controller when `--cache-mode hybrid` and cache budget
   options enable it.
2. Centralize cache metadata construction enough that endpoint families
   differ only in adapter logic, not cache policy.
3. Replace hard-coded minimal metadata paths with richest safe metadata
   derivation for each supported prompt shape.
4. Emit bounded degraded diagnostics when boundary metadata is missing or
   unsafe.
5. Keep marker parsing limited to fork tests and adopted test templates.
   Marked prompts must be stripped before tokenization and must not reach
   model inference.
6. Update benchmark and endpoint parity tests so OpenAI-compatible,
   Anthropic-compatible, and native routes prove the same command-line
   cache behavior.

## Non-goals

- Do not add cache-specific request fields.
- Do not require users to edit model templates for cache support.
- Do not add a cache control endpoint.
- Do not change `/slots` save/restore semantics.
- Do not weaken Stage 12 benchmark, stress, or long-run requirements.

## Acceptance checks

- With equivalent prompts and compatible runtime settings, endpoint
  families select the same namespace and restore policy.
- Cache hits, checkpoint restores, degraded fallback, and cold promotion
  behavior are controlled by server options, not by endpoint name.
- Requests without boundary-capable structure still run safely through
  token/position fallback and produce explicit degraded diagnostics.
- Public schemas remain compatible with OpenAI-compatible and
  Anthropic-compatible clients.
- Endpoint parity evidence is recorded in the Stage 13 design,
  implementation, and QA reports before closure.

## Handoff

Architect owns this architecture contract. Developer owns route audit,
metadata construction corrections, and benchmark-script updates. QA owns
the endpoint parity matrix and Stage 12 reruns needed to prove corrected
routes keep the benchmark behavior.
