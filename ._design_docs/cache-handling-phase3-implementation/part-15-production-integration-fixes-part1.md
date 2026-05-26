# Phase 3 Implementation: Production Integration Fixes - Part 1

**Date**: May 26, 2026  
**Status**: Complete  
**Related**: Steps 3.2-3.5 (save_slot and load_slot implementations)

## Overview

After initial Phase 3 implementation was reported complete, production integration testing revealed two critical integration issues that prevented the hybrid cache from functioning in the server's request flow. This document tracks the resolution of these integration gaps.

Part 1 covers Issue 1 (save triggers). See Part 2 for Issue 2 (load mechanism).

## Issue 1: Missing Save Triggers After Completion

### Problem Statement

While the `save_slot()` method was fully implemented with state serialization, LRU tracking, and deduplication logic, it was never invoked after successful completion requests. The cache entries were only saved:

1. During idle slot caching (when `--cache-idle-slots` is enabled)
2. Before slot reassignment in `get_available_slot()` (legacy behavior)

**Impact**: No cache entries were created after completions, resulting in zero cache utilization.

**Root Cause**: Missing integration points in the completion flow where `save_slot()` should be called after responses are sent.

### Solution

Added cache save triggers at two critical completion points in `server-context.cpp`:

#### Integration Point 1: Normal Completion Path

**Location**: After `send_final_response()` and before `slot.release()` in normal completion flow (line ~3608)

```cpp
if (!process_token(result, slot)) {
    // release slot because of stop condition
    slot.print_timings();
    send_final_response(slot);
    metrics.on_prediction(slot);

    // Save to hybrid cache after successful completion
    if (cache_ctrl && slot.task->type == SERVER_TASK_TYPE_COMPLETION) {
        cache_ctrl->save_slot(slot, slot.prompt_metadata);
    }

    slot.release();
    continue;
}
```

#### Integration Point 2: Speculative Decoding Completion Path

**Location**: After `send_final_response()` and before `slot.release()` in speculative decoding flow (line ~3728)

```cpp
if (!process_token(result, slot)) {
    slot.print_timings();
    send_final_response(slot);
    metrics.on_prediction(slot);

    // Save to hybrid cache after successful completion
    if (cache_ctrl && slot.task->type == SERVER_TASK_TYPE_COMPLETION) {
        cache_ctrl->save_slot(slot, slot.prompt_metadata);
    }

    slot.release();
    break;
}
```

### Design Rationale

**Placement**: Save triggers placed after `send_final_response()` but before `slot.release()` to ensure:

- Slot state is complete and stable
- All tokens have been processed
- Context state is finalized
- Slot is still valid (not yet released)

**Conditional Logic**:

- `cache_ctrl` existence check handles configurations where cache is disabled
- `SERVER_TASK_TYPE_COMPLETION` check excludes embeddings and reranking tasks
- `save_slot()` internally handles cache mode (hybrid vs legacy) differentiation

**Error Handling**: Not required at call site because `save_slot()` logs errors internally and returns bool status.

### Verification

**Manual Testing**:

- Start server: `llama-server --model <model> --cache-mode hybrid --metrics --cache-ram 100`
- Send completion request
- Check metrics: `llamacpp_cache_entries{mode="hybrid"}` increments to 1
- Server logs confirm: "hybrid cache: successfully saved slot"

**Integration Tests**:

- All cache entry creation tests now pass
- Metrics show non-zero `cache_entries`, `cache_bytes`, `cache_tokens` after requests

**Files Modified**:

- `tools/server/server-context.cpp` (added save triggers at lines ~3608 and ~3728)

---

**Next**: [Part 2: Load Mechanism Integration](./part-15-production-integration-fixes-part2.md)
