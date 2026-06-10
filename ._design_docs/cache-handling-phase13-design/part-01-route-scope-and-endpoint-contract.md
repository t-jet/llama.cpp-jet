# Stage 13 design - Part 1: Route scope and endpoint contract

Source: [../cache-handling-phase13-design.md](../cache-handling-phase13-design.md)

## Route families

Stage 13 covers every public route family that can create prompt state or
reuse cached model state.

| Route family | Stage 13 contract |
| --- | --- |
| Native `/completion` | Preserve documented prompt shapes. Derive the richest safe internal metadata from string, token-array, mixed, and multimodal inputs. Use token/position fallback when the request shape cannot express message, tool, or media boundaries. |
| Native `/embedding` | Preserve documented embedding request shapes. Use the same command-line cache enablement rules as completion routes when prompt state is cache-eligible. Do not add cache controls to embedding payloads. |
| OpenAI-compatible chat/completions/responses | Preserve OpenAI-compatible schemas. Capture message, tool, template, and media boundary metadata during prompt preparation when the adapter can derive it safely. |
| OpenAI-compatible embeddings | Preserve schema and normal embedding response behavior. Apply the same hybrid-mode routing rules as native embeddings for cache-eligible prompt preparation. |
| Anthropic-compatible messages/completions | Preserve Anthropic-compatible schemas. Map message, tool, and media structure into the shared internal metadata model before task creation. |
| Metrics and logs | Use existing `/metrics` and bounded logs. Report normal cache behavior and degraded fallback without adding a cache-specific public control endpoint. |

If a listed route is not compiled or exposed in the current server build,
implementation planning must record that as an endpoint inventory result,
not as a design skip.

## Compatibility rules

- Public request and response schemas stay compatible with the route
  family.
- Server command-line options select hybrid cache behavior. Request
  bodies do not need cache-specific fields.
- Endpoint adapters may differ in how they derive metadata, but they must
  feed the same internal cache policy and namespace rules.
- Cache behavior must not depend on endpoint name once equivalent
  prompt state, model identity, draft configuration, template identity,
  multimodal identity, and cache CLI settings are the same.
- `/slots` remains separate from hybrid cold-store and branch-graph
  internals.

## Stage 12 boundary

Stage 12 synthetic matrix gaps do not narrow this contract. Stage 13
uses them only as investigation history. Endpoint parity must be proven
with real public endpoints after Stage 13 implementation lands.
