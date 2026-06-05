# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 1: Gap Analysis

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

Status note, 2026-05-25: this gap analysis predates the smaller upstream target. Items that call for `/cache/stats`, cache fields in `/health`, or new cache policy/budget flags are deferred/private-fork work, not phase 1/2 acceptance criteria.

## Gap Analysis

### Architecture Stage 1: Mode Gate and Controller Interface

| Requirement | Phase 1 Status | Gap | Phase 2 Action |
|-------------|----------------|-----|----------------|
| cache_mode enum | ✅ Complete | None | - |
| --cache-mode CLI flag | ✅ Complete | None | - |
| Abstract cache_controller interface | ✅ Complete | None | - |
| Legacy adapter wrapper | ✅ Complete | None | - |
| Hybrid controller implementation | ⚠️ Partial | save_slot/load_slot are placeholders | **Implement full save/load logic** |
| Mode dispatch in server_context | ✅ Complete | None | - |
| Diagnostics logging | ✅ Complete | None | - |

**Stage 1 Completion**: 85% → Target: 100%

### Architecture Stage 2: Prepared-Prompt Boundary Metadata

| Requirement | Phase 1 Status | Gap | Phase 2 Action |
|-------------|----------------|-----|----------------|
| PreparedPromptMetadata structure | ✅ Complete | None | - |
| BoundarySpan structure | ✅ Complete | None | - |
| HTTP prompt-preparation extension | ❌ Not Done | No boundary extraction | **Implement extraction in chat template path** |
| Metadata field in server_task | ✅ Structure exists | Never populated | **Add population logic** |
| Thread metadata through pipeline | ❌ Not Done | No data flow | **Implement threading HTTP→task→context** |
| Fallback diagnostics | ❌ Not Done | No diagnostics | **Add logging when metadata absent** |
| /completion endpoint handling | ❌ Not Done | No minimal metadata | **Add minimal metadata or diagnostics** |

**Stage 2 Completion**: 30% → Target: 100%

### Additional Phase 1 Limitations

| Limitation | Impact | Phase 2 Action |
|------------|--------|----------------|
| Dual cache structures | Architecture debt, circular dependencies | **Refactor to single cache controller path** |
| Placeholder save/load | Hybrid mode non-functional | **Full implementation** |
| Missing HTTP stats | No observability | **Add /health cache metrics** |
| O(n) LRU scan | Performance bottleneck | **Optimize to O(log n) with indexing** |
| Incomplete slot integration | Temporary workarounds | **Clean integration** |

---

## Phase 2 Scope

### In Scope ✅

**P1: Complete Hybrid Save/Load (Week 1-2)**
- Implement `hybrid_cache_controller::save_slot()` with full state serialization
- Implement `hybrid_cache_controller::load_slot()` with prefix matching
- Support target + draft state pairing
- Handle checkpoint storage in cache entries
- Add validation and error handling

**P2: Boundary Metadata Extraction (Week 2-3)**
- Implement boundary capture in `apply_chat_template()` (server-chat.cpp)
- Extract SYSTEM_START/END boundaries for system prompts
- Extract MESSAGE_START/END boundaries for user/assistant messages
- Extract TOOL_CALL_START/END boundaries for tool invocations
- Store boundaries with token offsets in prepared_prompt_metadata

**P3: Metadata Threading (Week 3-4)**
- Populate `server_task.prompt_metadata` during task creation
- Thread metadata from HTTP layer through task queue
- Make metadata available in `server_context_impl` slot processing
- Add fallback path when metadata is missing
- Add diagnostics for boundary extraction failures

**P4: Statistics Endpoint Integration (Week 4)**
- Add cache statistics to existing `/health` endpoint
- Create dedicated `/cache/stats` endpoint with detailed metrics
- Expose per-namespace statistics (if multiple namespaces active)
- Add Prometheus-compatible metric format option
- Document metric meanings and interpretation

**P5: Slot Architecture Refactoring (Week 5-6)**
- Remove dual cache structures (prompt_cache + cache_ctrl)
- Unify slot save/load to use only cache controller interface
- Resolve circular dependencies between server-context and cache modules
- Move `legacy_cache_controller` implementation to separate file
- Clean up include dependencies

**P6: Performance Optimizations (Week 6-7)**
- Replace linear LRU scan with priority queue or indexed structure
- Optimize cache entry lookup with hash map by token prefix
- Add fast-path for exact match detection
- Profile memory allocations in hot paths
- Add performance benchmarks

**P7: Integration Testing (Week 7-8)**
- End-to-end tests with real chat templates
- Multi-slot concurrent access tests
- Boundary metadata round-trip tests
- Statistics endpoint correctness tests
- Performance regression tests
- Legacy mode unchanged verification

### Explicitly Out of Scope ❌

These remain deferred to later phases per architecture document:

- **Branch Graph Foundation** (Stage 7)
  - Shared branch forest
  - Multi-slot branch reuse
  - Topology-based traversal

- **Cold Storage** (Stage 6)
  - Payload offload to disk
  - Hot/cold residency management
  - Asynchronous I/O

- **Metadata-Only Nodes** (Stage 8)
  - Branch nodes without payloads
  - Re-materialization from ancestors

- **Checkpoint-First Restore** (Stage 9)
  - Checkpoints as canonical branch points
  - Workload profile detection

---

## Architecture Overview

### Phase 1 Architecture (Current State)

```
┌─────────────────────────────────────────────────────────────────┐
│                      server_context_impl                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Dual Cache Architecture (TEMPORARY)                   │    │
│  │                                                          │    │
│  │  ┌────────────────────┐    ┌─────────────────────┐    │    │
│  │  │  prompt_cache      │    │  cache_ctrl         │    │    │
│  │  │  (legacy path)     │    │  (new interface)    │    │    │
│  │  │                    │    │                     │    │    │
│  │  │  - Used by         │    │  - Factory creates  │    │    │
│  │  │    legacy mode     │    │    based on mode    │    │    │
│  │  │  - slot methods    │    │                     │    │    │
│  │  │    call directly   │    │  - Hybrid save/load │    │    │
│  │  │                    │    │    PLACEHOLDER      │    │    │
│  │  └────────────────────┘    └─────────────────────┘    │    │
│  │                                                          │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    HTTP Layer (server-chat.cpp)                  │
│                                                                  │
│  apply_chat_template(messages) → tokens                         │
│                                                                  │
│  ❌ No boundary extraction                                      │
│  ❌ No metadata population                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Phase 2 Target Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      server_context_impl                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Unified Cache Architecture                            │    │
│  │                                                          │    │
│  │         cache_ctrl (cache_controller*)                  │    │
│  │                  │                                       │    │
│  │    ┌─────────────┴──────────────┐                      │    │
│  │    │                             │                       │    │
│  │    ▼                             ▼                       │    │
│  │  ┌──────────────────┐   ┌──────────────────────┐       │    │
│  │  │ Legacy Controller│   │ Hybrid Controller    │       │    │
│  │  │                  │   │                      │       │    │
│  │  │ - Wraps existing │   │ - FULL save/load    │       │    │
│  │  │   prompt_cache   │   │   implementation     │       │    │
│  │  │                  │   │ - Uses metadata      │       │    │
│  │  │ - Unchanged      │   │ - Optimized LRU      │       │    │
│  │  │   behavior       │   │ - Stats enabled      │       │    │
│  │  └──────────────────┘   └──────────────────────┘       │    │
│  │                                                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
│  ALL slot operations go through cache_ctrl interface            │
└─────────────────────────────────────────────────────────────────┘
                               ▲
                               │ metadata
                               │
┌─────────────────────────────┴───────────────────────────────────┐
│                      server_task                                 │
│                                                                  │
│  struct server_task {                                           │
│    // ... existing fields ...                                   │
│    prepared_prompt_metadata prompt_metadata;  // POPULATED     │
│  };                                                              │
└─────────────────────────────┬───────────────────────────────────┘
                               ▲
                               │ metadata extracted
                               │
┌─────────────────────────────┴───────────────────────────────────┐
│               HTTP Layer (server-chat.cpp)                       │
│                                                                  │
│  apply_chat_template(messages) → {                              │
│    tokens,                                                       │
│    boundaries: [SYSTEM_START, MESSAGE_START, ...]  ✅          │
│  }                                                               │
│                                                                  │
│  ✅ Boundary extraction during template application            │
│  ✅ Metadata population                                         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│               HTTP Endpoints (server-http.cpp)                   │
│                                                                  │
│  GET /health → includes cache_stats                   ✅       │
│  GET /cache/stats → detailed cache metrics            ✅       │
└─────────────────────────────────────────────────────────────────┘
```

### Key Architectural Changes

1. **Eliminate Dual Cache Structures**:
   - Remove `prompt_cache` from `server_context_impl` in hybrid mode
   - All cache operations go through `cache_ctrl` interface
   - Legacy mode uses wrapper that owns `server_prompt_cache` internally

2. **Boundary Metadata Flow**:
   ```
   HTTP Chat Template
         ↓ (extract boundaries)
   prepared_prompt_metadata
         ↓ (attach to task)
   server_task.prompt_metadata
         ↓ (pass to context)
   cache_ctrl.save_slot(slot, metadata)
   ```

3. **Statistics Exposure**:
   ```
   cache_ctrl.get_stats()
         ↓
   Format as JSON
         ↓
   /health endpoint (summary)
   /cache/stats endpoint (detailed)
   ```

---

## Detailed Component Design

### Component 1: Hybrid Save/Load Implementation

**File**: `tools/server/server-cache-hybrid.cpp`

