# Stage 13 design - Part 2: Metadata construction and parity rules

Source: [../cache-handling-phase13-design.md](../cache-handling-phase13-design.md)

## Metadata construction model

Stage 13 keeps prompt preparation in the HTTP or adapter layer and cache
policy in `server_context` or dedicated cache components. Endpoint code
builds or forwards `PreparedPromptMetadata`; it does not choose cache
policy directly.

The construction model has four steps:

1. Parse the public request using the existing route schema.
2. Produce flattened prompt tokens through the route's current prompt
   preparation path.
3. Build `PreparedPromptMetadata` from the richest safe structure the
   route already has.
4. Attach tokens and metadata to `server_task` before the task reaches
   cache planning.

## Metadata richness

Adapters should use this order when metadata sources are available:

| Metadata source | Use when | Required behavior |
| --- | --- | --- |
| Native structured boundaries | Route has message, tool, media, template, or role structure before flattening. | Preserve stable spans, compatibility keys, protection hints, template identity, media marker layout, and projector identity where available. |
| Tokenized prompt plus known request shape | Route has supported prompt pieces but no full message boundary model. | Record token spans and degraded reason. Preserve enough namespace data to prevent unsafe reuse. |
| Minimal token/position fallback | Route has only flattened or token-array prompt state. | Mark metadata degraded and emit bounded diagnostics. Continue safely without pretending message-aware boundaries exist. |

Multimodal requests need conservative handling. If media spans, projector
identity, dynamic image-token settings, or marker layout cannot be
derived safely, restore candidates that depend on those facts must be
rejected and recomputed.

## Endpoint parity rules

- Hybrid mode enablement is identical across route families:
  `--cache-mode hybrid` plus the relevant cache budget and draft settings
  decide whether hybrid behavior is active.
- Equivalent prompts on compatible route families must enter the same
  namespace when model, template, draft, multimodal, and cache settings
  match.
- Exact blob hits, checkpoint restores, cold promotion, fallback, and
  degraded behavior use cache-controller policy, not endpoint-specific
  policy.
- Degraded fallback is valid only when richer boundaries cannot be
  derived safely.
- Degraded fallback must be observable through existing bounded logs,
  counters, or stats already used by the cache implementation.
- Fork-only Jinja markers remain test harness input. Stage 13 must not
  expose markers as public endpoint contract, and marked prompts must be
  stripped before tokenization and inference.

## Implementation constraints

Implementation planning should centralize metadata construction enough to
avoid one-off endpoint policy. Small adapter functions per route family
are acceptable when request shapes differ. Copying cache-policy decisions
into route handlers is not acceptable.

Any route that cannot derive rich metadata must document the fallback
reason in implementation evidence and endpoint tests.
