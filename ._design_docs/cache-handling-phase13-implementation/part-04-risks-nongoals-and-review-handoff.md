# Stage 13 implementation - Part 4: risks, non-goals, and review handoff

Source: [../cache-handling-phase13-implementation.md](../cache-handling-phase13-implementation.md)

## Risk list

| Risk | Impact | Planned control |
| --- | --- | --- |
| Embeddings eligibility is ambiguous | Metadata may be attached to tasks that never safely reuse prompt state, or cache behavior may be claimed without real support | Decide from current execution path before implementation. If embeddings are not cache-eligible, document exclusion and test public schema only. If eligible, attach shared metadata and test native plus OpenAI embeddings. |
| Multimodal metadata is incomplete | Unsafe reuse across different media, projector, dynamic image-token settings, or marker layouts | Treat missing media/projector/marker facts as degraded. Reject restore candidates that depend on unavailable facts and recompute. Do not infer media identity from text alone. |
| Anthropic conversion loses source structure | Boundaries may be wrong after conversion to OpenAI chat form | Preserve source facts before conversion when practical. Otherwise use degraded fallback with a specific conversion-loss reason. |
| Responses conversion merges or rewrites items | Tool calls, reasoning, or item status can lose reliable span identity | Carry internal source breadcrumbs only if safe. Degrade when item merging makes boundaries unreliable. |
| Audio transcription build or fixture support is unavailable | A public route family that creates completion prompt state may be skipped without evidence | Keep transcription routes in scope. If support is missing, QA records unavailable or blocked evidence with exact prerequisite, then reviewer decides whether that is acceptable for gate. |
| Public schemas drift | Clients could see cache-only fields or changed response shape | Keep cache inputs internal. Add schema compatibility checks to QA handoff and implementation evidence. |
| Rendered-text boundary search is fragile | Duplicate message content can map to the wrong token range | Prefer native span capture when available. Mark rendered-text search as degraded and isolate by preparation id and degraded reason. |
| Endpoint family leaks into `preparation_id` | Namespace fragments by route even when prompt state is equivalent | Use route-neutral preparation ids for equivalent prompt state. Keep endpoint family in diagnostic source labels, bounded logs, counters, or evidence only. |
| Namespace fragmentation from over-specific degraded reasons | Equivalent safe prompts may miss reuse | Keep degraded reason classes stable and bounded. Use endpoint family for diagnostics, not route-specific policy. |
| Prompt-content diagnostics leak data | Logs could expose user prompts or media details | Log endpoint family, fallback class, counts, and reason only. Avoid prompt text and raw media. |

## Non-goal checklist

The implementation plan keeps these items out of scope:

- no cache request fields
- no public marker API
- no public cache-control endpoint
- no `/slots` semantic change
- no endpoint-specific cache policy
- no template edits required from users
- no Stage 12 synthetic matrix resumption before Stage 13 endpoint
  corrections and real endpoint testing complete

## Independent plan review checklist

Plan reviewer should check:

- route inventory matches `tools/server/server.cpp`
- handler paths match `tools/server/server-context.cpp`
- transcription routes are inventoried as in-scope completion prompt-state routes or have explicit unavailable evidence rules
- conversion paths match `tools/server/server-chat.cpp`
- metadata type assumptions match `tools/server/server-task.h`
- hybrid diagnostics assumptions match `tools/server/server-cache-hybrid.cpp`
- `preparation_id` remains route-neutral for equivalent prompt state and endpoint family labels stay out of namespace inputs
- plan keeps implementation out of route policy decisions
- QA handoff requires real endpoint parity evidence
- all implementation-planning files stay under 300 lines

## Handoff verdict

VERDICT: READY FOR INDEPENDENT PLAN RE-REVIEW.

Implementation remains blocked until the independent plan re-review
passes. After plan review, implementation should proceed one route
family at a time, updating this log after each completed step with real
evidence.
