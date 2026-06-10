# Stage 13 design - Part 3: Acceptance checks and implementation handoff

Source: [../cache-handling-phase13-design.md](../cache-handling-phase13-design.md)

## Acceptance checks

Stage 13 can close only after implementation and QA record endpoint
evidence for these checks:

| Check | Required evidence |
| --- | --- |
| Route audit complete | Inventory of native, OpenAI-compatible, Anthropic-compatible, metrics, and slot surfaces with explicit in-scope or unavailable status. |
| Public schemas stable | Before/after request and response compatibility checks for each in-scope route family. |
| Command-line cache selection shared | Same server flags enable or disable hybrid cache behavior across equivalent public route families. |
| Metadata construction shared | Endpoint adapters produce `PreparedPromptMetadata` through shared helpers or equivalent centralized logic, with route-specific adapter code limited to request-shape extraction. |
| Richest safe metadata used | Chat, tool, media, template, token, and prompt-shape metadata are captured when safely available. |
| Degraded fallback bounded | Requests without safe boundary metadata use token/position fallback and emit bounded degraded diagnostics. |
| Endpoint parity proven | Equivalent prompts on real public endpoints select the same namespace and restore policy when compatibility inputs match. |
| Cache behavior endpoint-neutral | Hits, checkpoint restores, cold promotion, misses, and fallback are controlled by cache settings and prompt compatibility, not by route name. |
| Marker interface stays internal | Fork-only Jinja markers remain test harness input and are stripped before tokenization and inference. |
| Stage 12 sequencing respected | Synthetic Stage 12 V2/V3/non-MTP expansion is not resumed before Stage 13 endpoint corrections and endpoint-oriented tests. |

Real public endpoints must be tested after implementation. Synthetic
Stage 12 rows can supplement investigation, but they cannot replace
endpoint parity evidence.

## Minimum endpoint test set

QA planning should include:

- native `/completion` with plain prompt, token-array prompt, and any
  supported multimodal prompt shape available in local fixtures
- native `/embedding` if cache-eligible prompt state exists for that
  route in the current implementation
- OpenAI-compatible chat/completions/responses routes exposed by the
  build
- OpenAI-compatible embeddings route if exposed and cache-eligible
- Anthropic-compatible messages/completions routes exposed by the build
- `/metrics` snapshots and bounded log checks for hits, restores,
  degraded fallback, and restore failures
- `/slots` regression check proving Stage 13 did not change save/restore
  semantics

## Implementation-planning handoff

Developer planning should produce:

- route inventory and call-flow map from public route to `server_task`
- metadata-construction helper plan, with route adapter responsibilities
- fallback and diagnostic plan for boundary-missing cases
- endpoint parity test plan and benchmark-driver changes
- explicit non-goal checks for request fields, cache control endpoints,
  `/slots`, and public Jinja markers
- risk list for multimodal, Anthropic adapter coverage, and embedding
  cache eligibility

Implementation may start only after independent design review and
Manager design gate approval. QA execution may start only after
implementation review accepts the endpoint corrections.
