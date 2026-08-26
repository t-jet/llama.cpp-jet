# Stage 40 F7 fix evidence

Date: 2026-08-26
Fixer: Developer
Status: READY for Architect final review

## F7 fix strategy

Merged `server_prompt_cache_state` wraps `server_prompt prompt` + `server_prompt_data data`.
Local `server-slot.h::prompt_save()` (kept whole-file local) still used old flat-member contracts:
`cur->tokens`, `cur->checkpoints`, `trim_checkpoints(*cur,...)`, `prompt_cache.discard(cur)`.
Server-task.cpp `discard(server_prompt*)` compared `&*it == prompt` on `server_prompt_cache_state`.

Fix: route through `cur->prompt.*` for all inner-prompt accesses and pass `&cur->prompt`
to `discard()`. In `discard()` body, compare `&it->prompt` and use `it->prompt.n_tokens()`.

## Files modified

| File | Change description |
| --- | --- |
| `tools/server/server-slot.h` | prompt_save(): 4 changes |
| `tools/server/server-task.cpp` | discard(): 2 changes |

## Lines changed (exact)

### server-slot.h prompt_save()

| Line | Old | New | Purpose |
| --- | --- | --- | --- |
| 245 | `prompt_cache.discard(cur)` | `prompt_cache.discard(&cur->prompt)` | discard takes `server_prompt*`, pass inner prompt |
| 253 | `prompt_cache.discard(cur)` | `prompt_cache.discard(&cur->prompt)` | same for draft failure path |
| 258 | `cur->tokens` | `cur->prompt.tokens` | merged struct wraps prompt |
| 259 | `cur->checkpoints` | `cur->prompt.checkpoints` | merged struct wraps prompt |
| 261 | `cur->tokens` | `cur->prompt.tokens` | clone path |
| 262 | `cur->checkpoints` | `cur->prompt.checkpoints` | clone path |
| 264 | `trim_checkpoints(*cur,` | `trim_checkpoints(cur->prompt,` | function expects `server_prompt&` |

### server-task.cpp discard()

| Line | Old | New | Purpose |
| --- | --- | --- | --- |
| 1793 | `&*it == prompt` | `&it->prompt == prompt` | compare inner prompt addr |
| 1795 | `it->n_tokens()` | `it->prompt.n_tokens()` | call n_tokens on inner prompt |

## Stale reference check

| Pattern | Result |
| --- | --- |
| `trim_checkpoints(*cur` in server-slot.h | 0 matches |
| `discard(cur)` in server-slot.h | 0 matches |
| `&*it == prompt` in server-task.cpp | 0 matches |
| `it->n_tokens()` in server-task.cpp | 0 matches |

## Merge state

| Check | Value |
| --- | --- |
| MERGE_HEAD | fc35562ba46fbbf8e30cac85edbb39642c37d248 (open) |
| Staged files | tools/server/server-slot.h, tools/server/server-task.cpp |
| No-commit | confirmed |

## Next gate

Architect final re-review (third review pass). Targeted compile of
server-slot.h/server-context.cpp TU recommended before full CUDA rebuild.
