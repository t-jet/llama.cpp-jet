# Phase 5 implementation: implementation re-review

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Review scope

Review date: May 28, 2026

This re-review checks only the Part 7 blocking rollback finding after the review-fix pass in Part 8. No code fixes were made.

Reviewed design baseline:

- [Phase 5 design entry](../cache-handling-phase5-design.md)
- [Phase 5 design Part 3](../cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md)
- [Phase 5 implementation entry](../cache-handling-phase5-implementation.md)
- [Part 7: Implementation review](part-07-implementation-review.md)
- [Part 8: Review-fix evidence](part-08-review-fix-evidence.md)

Reviewed code and tests:

- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`
- `include/llama.h`
- `src/llama-kv-cache.cpp`
- `src/llama-kv-cache-iswa.cpp`
- `src/llama-memory-recurrent.cpp`
- `src/llama-memory-hybrid.cpp`
- `src/llama-memory-hybrid-iswa.cpp`

## Verdict

PASS.

The Part 7 blocker is fixed. The production restore paths now treat an empty pre-restore target or draft side as a real pre-image. They preflight whole-sequence clearing before applying cached bytes, roll back empty sides with whole-sequence removal, and return false before hit accounting or recency refresh on validation or apply failure.

## Decisions

### Empty-side rollback primitive

`llama_memory_seq_rm(..., seq_id, -1, -1)` is an acceptable exact empty-side rollback primitive for the supported llama memory backends reviewed here.

The public API contract in `include/llama.h:707` through `:712` says whole-sequence removal never fails. The implementation normalizes `p0 < 0` to zero and `p1 < 0` to the end of the sequence range before dispatching to the memory backend at `src/llama-context.cpp:3708` through `:3717`.

The relevant backends satisfy that contract for a valid slot sequence id:

- `src/llama-kv-cache.cpp:343` through `:403` removes all cells for the sequence over the full range and returns true.
- `src/llama-memory-recurrent.cpp:150` through `:232` treats the full range as `rm_all`, clears the recurrent sequence index, removes matching cells, and returns true for valid sequence ids.
- `src/llama-kv-cache-iswa.cpp:80` through `:86` applies the same full removal to both KV caches.
- `src/llama-memory-hybrid.cpp:140` through `:146` and `src/llama-memory-hybrid-iswa.cpp:146` through `:152` remove recurrent state first, then attention state. If recurrent removal were unsupported, they fail before mutating attention state.

That makes whole-sequence removal a valid way to restore "no serialized pre-image" to an empty sequence for Stage 5 rollback.

### Unsupported clear paths fail before live apply

Both production restore entry points validate the descriptor and payload before snapshot or clear work:

- `tools/server/server-context.cpp:5410` through `:5415`
- `tools/server/server-context.cpp:5572` through `:5577`

They then snapshot non-empty sides and check empty-side clearing before applying target payload bytes:

- `tools/server/server-context.cpp:5421` through `:5461`
- `tools/server/server-context.cpp:5583` through `:5623`

If clearing is not available, restore returns false and increments failure and fallback counters before the target payload is applied. Because the clear is a whole-sequence clear of a side whose serialized size is already zero, this preflight does not change the required live pre-image.

### Draft failure after target apply

A draft apply failure after target apply now calls the same rollback lambda in both restore paths:

- `tools/server/server-context.cpp:5462` through `:5485`, used by the failure branch at `:5516` through `:5522`
- `tools/server/server-context.cpp:5624` through `:5647`, used by the failure branch at `:5676` through `:5682`

The rollback lambda restores serialized pre-images when present and clears a side when the pre-image was empty. It also restores slot prompt metadata. The success path updates LRU recency and slot restored-token state only after target and draft apply have succeeded:

- `tools/server/server-context.cpp:5527` through `:5538`
- `tools/server/server-context.cpp:5687` through `:5698`

No half-restored target/draft pair remains through the Part 7 failure path.

### Failure-injection and evidence

The focused regression in `tests/test-cache-controller.cpp:795` through `:803` models the Part 7 blocker directly: target bytes apply, draft apply fails, target and draft pre-images are empty, rollback clears both live sides, no rollback failure is counted, fallback is recorded, and no hit is recorded.

The helper at `tools/server/server-cache-hybrid.cpp:472` through `:502` is still a debug seam rather than a model-backed live-slot probe. That is acceptable for this re-review because the production primitive was checked against the supported memory backends above, and Part 8 records that no small target-plus-draft model fixture was available.

## Required corrections

None for the Part 7 blocker.

## Handoff

State: ready for QA review.

Next owner: QA or manager for Stage 5 verification gating.
