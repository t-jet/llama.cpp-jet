# Stage 40 F1 fix evidence

Date: 2026-08-26
Fixer: Developer
Status: FIX APPLIED

## BLOCKING finding F1

Architect impl review (part-15): upstream removed `struct result_timings` from `server-task.h` (replaced by `server_slot_stats`) but local-only `server-slot.h` returned `result_timings` from `get_timings()`. The struct had no definition in staged tree. Would not compile.

## Fix strategy: OPTION B

Adopt upstream `server_slot_stats`:
- `server_slot_stats` defined in staged `server-common.h` (added by upstream merge)
- Staged `server-task.h` already uses `server_slot_stats stats;` (member named `stats`, not `timings`)
- Staged `server-task.cpp` all `to_json()` callers already use `stats.to_json()`
- Re-adding `result_timings` (Option A) would leave `to_json()` broken (calls `stats.to_json()`)

## Files modified

### tools/server/server-slot.h

Changed `get_timings()` return type and body:

```
// BEFORE:
    result_timings get_timings() const {
        result_timings timings;
        timings.cache_n = n_prompt_tokens_cache;
        timings.prompt_n = ...
        ...

// AFTER:
    server_slot_stats get_timings() const {
        server_slot_stats stats;
        stats.n_prompt_cached    = n_prompt_tokens_cache;
        stats.n_prompt_processed = n_prompt_tokens_processed;
        stats.n_gen              = n_decoded;
        stats.n_draft_tokens    = n_draft_total;
        stats.n_draft_accepted  = n_draft_accepted;
        // map slot timing fields to server_slot_stats timestamps
        stats.t_start       = t_start_process_prompt;
        stats.t_prompt_last = t_start_generation;
        stats.t_gen_last    = t_start_generation + (int64_t)(t_token_generation * 1000.0);
        return stats;
```

### tools/server/server-context.cpp

Changed member access from `res->timings` to `res->stats` (2 call sites, lines 1866 & 1893):

```
// BEFORE: (both call sites)
    res->timings = slot.get_timings();
// AFTER:
    res->stats = slot.get_timings();
```

## Verification

### result_timings grep count (on-disk files, staged after fix)

| File | result_timings hits |
|---|---|
| tools/server/server-slot.h | **0** (was 2) |
| tools/server/server-context.cpp | **0** (was 0, uses res->stats now) |
| tools/server/server-task.h | **0** (was 3, all server_slot_stats now) |
| tools/server/server-task.cpp | **0** (was 2, all stats.to_json() now) |

### server_slot_stats grep count (on-disk, confirms fix uses correct type)

| File | server_slot_stats hits |
|---|---|
| tools/server/server-task.h | 2 (members) |
| tools/server/server-task.cpp | 0 (uses stats.to_json()) |
| tools/server/server-common.h | 1 (struct definition) |
| tools/server/server-slot.h | 2 (return type + local var) |
| tools/server/server-context.cpp | 0 (uses res->stats = slot.get_timings()) |

### Compile attempt

Build: `MSBuild server-context.vcxproj /t:ClCompile`
Target: compile server-chat.cpp, server-task.cpp, server-context.cpp (all files in server-context vcxproj)

Result: **PARTIAL PASS for F1 scope** -- no errors from server-slot.h (header) or server-context.cpp.

2 errors reported, both from **server-task.cpp** (pre-existing, NOT from F1-fix files):
- `error C2446: '==': no conversion from 'server_prompt *' to 'server_prompt_cache_state *'`
- `error C2039: 'n_tokens': is not a member of 'server_prompt_cache_state'`

These are a separate merge artifact: upstream renamed `server_prompt_cache` element type from `server_prompt` to `server_prompt_cache_state` (staged server-task.h diff), but `server-task.cpp` still uses old pointer comparisons and `n_tokens()` on the new type. My F1 fix did not touch server-task.cpp.

The F1-impacted translation units (server-slot.h consumed by server-context.cpp, and server-context.cpp itself) compiled without errors.

## Ready for Architect re-review

- [x] F1 fix applied (Option B: adopt server_slot_stats)
- [x] Zero stale result_timings refs
- [x] Files staged (git add)
- [x] F1-scope compile verified (no errors from server-slot.h or server-context.cpp)
- [ ] Pre-existing server-task.cpp errors (separate issue, not in F1 scope)