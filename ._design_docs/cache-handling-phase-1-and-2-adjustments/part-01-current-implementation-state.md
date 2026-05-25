# Cache handling phase 1 and 2 adjustments - Part 1: Current implementation state

Source: [../cache-handling-phase-1-and-2-adjustments.md](../cache-handling-phase-1-and-2-adjustments.md)

## Current implementation state

The current code is no longer only a phase 1 foundation. It includes:

- `--cache-mode MODE`
- cache controller interface and legacy/hybrid controllers
- hybrid non-destructive exact-blob cache
- LRU and prefix indexes
- span-shaped `prepared_prompt_metadata`
- generic rendered-text metadata inference
- `/cache/stats`
- extra `cache` data in `/health`
- focused unit tests and coverage reports

Some earlier issues in `cache-handling-phases-1-and-2-implementation-gaps.md` were already addressed:

- divergent partial exact-blob matches are rejected
- missing paired draft payloads are rejected before restore
- short cached prefixes can be found by the prefix index
- metadata now has token spans, checksums, protection flags, compatibility fields, and degraded metadata

These fixes should remain, but several parts still do not match the updated architecture.

## Required changes

### 1. Remove public cache stats endpoints from the upstream target

Status: required for compatibility

Current mismatch:

- `tools/server/server.cpp` registers `GET /cache/stats`.
- `tools/server/server-context.cpp` adds cache stats to `GET /health`.
- `tools/server/tests/unit/test_cache_modes.py` expects those response shapes.
- `cache-handling-phase2-design.md` and `cache-handling-phase2-implementation.md` describe `/cache/stats` and `/health` cache stats as phase 2 deliverables.

Updated architecture target:

- Do not add new HTTP endpoints for the initial upstream target.
- Keep `/health` response shape unchanged.
- Expose cache counters through the existing Prometheus `/metrics` endpoint when `--metrics` is enabled.

Design:

- Remove public registration of `/cache/stats`.
- Remove cache details from `/health`.
- Keep an internal `get_cache_stats()` helper if useful for metrics, logging, and tests.
- Add cache counters to the existing `/metrics` endpoint instead of adding JSON endpoints.
- Update tests to stop asserting `/cache/stats` or `/health.cache`.

Suggested metric names:

| Metric | Meaning |
| --- | --- |
| `llamacpp_cache_entries` | Current cache entry count by mode. |
| `llamacpp_cache_bytes` | Current cache resident bytes by mode. |
| `llamacpp_cache_tokens` | Current cached token count by mode. |
| `llamacpp_cache_hits_total` | Successful cache restores by mode. |
| `llamacpp_cache_misses_total` | Cache lookup misses by mode. |
| `llamacpp_cache_evictions_total` | Cache evictions by mode. |
| `llamacpp_cache_restore_failures_total` | Restore failures by reason when reason labels are practical. |

Acceptance criteria:

- `GET /health` remains the upstream shape.
- `GET /cache/stats` is not registered in the upstream target.
- `GET /metrics` includes cache metrics only when `--metrics` is enabled.
- Existing clients that call `/health`, `/models`, `/v1/models`, `/props`, and `/slots` see no cache-specific response changes.

### 2. Move boundary capture out of `server_context`

Status: required

Current mismatch:

- `server-common.cpp` stores `_cache_prompt_metadata_source` in the request JSON.
- `server-context.cpp` reconstructs boundaries by searching rendered prompt text.
- The phase 2 docs describe generic extraction as complete or planned, but this is not the updated target.

Updated architecture target:

- JSON parsing, chat template application, multimodal normalization, and tokenization stay in the HTTP/prompt-preparation layer.
- `server_context` receives native C++ fields on `server_task`, not raw request JSON or hidden `_cache_*` JSON.
- Boundary metadata should be captured during prompt preparation when possible. Rendered-text inference is a degraded fallback, not completion of stage 2.

Design:

- Add a small prompt-preparation result type near the HTTP/task creation path:

```cpp
struct prepared_prompt_result {
    server_tokens tokens;
    prepared_prompt_metadata metadata;
};
```

- Populate `prepared_prompt_metadata` before creating `server_task`.
- Remove `_cache_prompt_metadata_source` from request JSON.
- Keep rendered-text inference only as an explicit degraded fallback if native capture is not ready.
- Set `metadata.degraded_reason` for any inferred, partial, or minimal metadata.
- For `/completion`, produce only minimal token-span metadata from the documented prompt shapes. Do not add request fields for cache metadata.

Acceptance criteria:

- `server_context` does not parse cache-specific request JSON.
- Chat metadata is attached to `server_task` before enqueue.
- Inferred metadata is marked degraded.
- Fixture tests cover repeated message content, empty messages, tool calls, system/developer messages, and templates that add role/control tokens.

### 3. Treat Jinja cache markers as tests only

Status: required documentation correction; implementation only if tests depend on it

Current mismatch:

- Phase docs discuss template-specific extraction and marker-style approaches as implementation paths.
- The updated architecture says marker macros are private test harnesses, not a public template contract.

Design:

- Do not require bundled model templates, user templates, or request payloads to contain cache markers.
- Keep `cache_mark(...)` only in fork fixtures such as `._test_models/*/chat_template_new.jinja`.
- In marked fixture renders, require a general `<|template_markup:v1:...|>` header as the first rendered bytes. The header must list every enhancement used by the render as `feature_name=feature_version`; current cache-boundary fixtures list `cache_boundary=1`.
- Test marker rendering with byte-for-byte comparisons against the original template output.
- Do not feed marked prompts to the model.

Acceptance criteria:

- Production code does not require modified Jinja templates.
- Tests may use marker templates, but documentation labels them fork-only fixtures.
- Marked fixture renders without the template-markup header, or without the required feature id for the parser being used, are rejected before marker parsing.

### 4. Strengthen namespace compatibility keys

Status: required before broad hybrid reuse

Current mismatch:

- `hybrid_cache_controller::compute_namespace_id()` uses model parameter count and context size.
- The updated architecture requires materially different runtime state to be isolated: tokenizer/template assumptions, active adapters, control vectors, draft model identity, multimodal projector identity, media token layout, and workload profile.
- `prepared_prompt_metadata.compatibility_key` exists but is not the primary source for restore compatibility.

Design:

- Introduce a structured compatibility key builder used by both save and load.
- Include at least:
  - target model identity
  - draft model identity or absence
  - context size and KV/cache state-relevant runtime settings
  - tokenizer and chat-template identity/version
  - active LoRA adapters and scales
  - control vectors and layer range
  - multimodal projector identity
  - dynamic image token settings
  - media marker count and token span layout for multimodal prompts
  - workload profile
- Store the computed key in the cache entry and in `prepared_prompt_metadata.compatibility_key` when prompt preparation can provide request-specific parts.
- Reject cache candidates with mismatched keys before comparing token prefixes.

Acceptance criteria:

- Two different adapters, draft models, templates, or multimodal layouts cannot share a cache entry.
- Tests cover namespace misses for at least model/draft, adapter-like synthetic key, and multimodal-layout synthetic key.

### 5. Make target/draft restore failure leave a known-valid slot

Status: required

Current mismatch:

- The implementation prevalidates target and draft payload presence.
- It still applies target state before draft state. If draft restore fails after target restore succeeds, the function returns `false` but the target context may already have changed.

Updated architecture target:

- Target and draft payloads are one paired restore object.
- Restore failure must leave the slot in a known-empty or known-valid state before fallback recomputes.

Design:

- Validate all expected payloads and sizes before applying either side.
- If the runtime cannot apply target/draft atomically, add an explicit recovery path:
  - on any apply failure, clear the affected slot sequence in target and draft contexts when the API permits it
  - clear slot prompt accounting
  - force normal prompt recomputation
  - count the event as `restore_failure`, not a cache hit
- Prefer a helper such as `restore_paired_state_or_reset(slot, entry)` so this rule is not spread across scheduling code.

Acceptance criteria:

- A target-plus-draft restore either applies both sides or leaves the slot ready for recomputation.
- Cache hit counters increment only after both sides apply successfully.
- Model-backed tests cover target-only restore and target-plus-draft failure paths.

### 6. Keep public CLI surface minimal

Status: required documentation and future-work correction

Current mismatch:

- Phase 1 and 2 docs include or imply additional knobs such as policy selectors, endpoint controls, separate budgets, or old example names like `--cache-size`.
- The updated architecture says initial upstream target should add only `--cache-mode` and reuse existing cache/checkpoint flags.

Design:

- Keep only this new public flag in phases 1 and 2:
  - `--cache-mode MODE`
- Reuse existing flags:
  - `--cache-ram`
  - `--ctx-checkpoints`
  - `--swa-checkpoints`
  - `--checkpoint-every-n-tokens`
  - `--cache-idle-slots`
  - `--no-cache-idle-slots`
- Defer or keep private:
  - `--cache-eviction-policy`
  - `--cache-budget-*`
  - `--cache-cold-dir`
  - cache-specific endpoint flags
- Fix examples that mention `--cache-size`; use `--cache-ram`.

Acceptance criteria:

- `common/arg.cpp` adds no cache flags other than `--cache-mode` for this stage.
- Docs describe deferred flags as deferred/private-fork, not phase 1/2 requirements.

### 7. Adjust protected-root policy

Status: required before production hybrid mode

Current mismatch:

- `save_slot()` sets `entry.protected_root = slot.checkpoints_enabled`.
- That can mark most useful entries as protected simply because checkpoints are enabled, not because the prompt contains protected spans.

Updated architecture target:

- Protected roots raise eviction priority but do not bypass accounting.
- Protection should come from explicit metadata/protection hints, not broad runtime state.

Design:

- Base protection on `prepared_prompt_metadata`:
  - `protect_system`
  - `protect_messages`
  - span-level `protect`
- If metadata is absent or degraded, avoid broad automatic protection.
- Keep all protected entries counted against `--cache-ram`.
- Emit diagnostics when protected entries dominate the budget.

Acceptance criteria:

- Enabling checkpoints alone does not mark every saved entry as protected.
- Tests cover protected and unprotected entries under byte/token pressure.

