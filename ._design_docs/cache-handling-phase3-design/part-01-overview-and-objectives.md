# Phase 3 Design: Non-Destructive Exact Blob Cache - Part 1: Overview and Objectives

Source: [../cache-handling-phase3-design.md](../cache-handling-phase3-design.md)

**Architecture Reference**: This design implements Stage 3 from the [Phased Delivery Plan](../cache-handling-architecture/part-04-adr-009-distinguish-payload-eviction-from-branch.md#stage-3-non-destructive-exact-blob-cache) in [cache-handling-architecture.md](../cache-handling-architecture.md).

## Overview

Stage 3 transforms the hybrid cache controller from placeholder functionality into a production-ready, non-destructive exact blob cache. This stage builds directly on the foundations established in Stages 1 and 2:

- **Stage 1 delivered**: Mode selection infrastructure, abstract cache controller interface, boundary metadata structures, and placeholder hybrid cache implementation with LRU tracking
- **Stage 2 functionally present**: Boundary metadata threading from HTTP layer through task pipeline, slot integration with cache controller, Prometheus metrics integration, and performance indexes (LRU multimap, token prefix index). **Note**: Boundary capture currently uses rendered-text inference (degraded mode); native capture and comprehensive namespace keys are completed in parallel with Stage 3 (see [Stage 2 Completion Requirements](#stage-2-completion-requirements) below).

Stage 3 completes the core caching functionality by implementing full save and restore operations for exact full-state blobs with non-destructive hits and proper usage tracking.

**Implementation Strategy**: Stage 3 core work proceeds using degraded Stage 2 functionality with explicit markers, while Stage 2 completion (native boundary capture, comprehensive namespace keys, fixture tests) proceeds in parallel. Gap 2.2 (namespace keys) must complete before Phase 3 Step 3.6 (multi-namespace testing).

## Primary Objectives

### 1. Non-Destructive Cache Hits (R99, R80, R81, R82, R83)

Transform cache behavior from destructive (legacy FIFO) to non-destructive:

- **Legacy mode**: When a slot loads a cached prompt, the entry is consumed and removed from the cache
- **Hybrid mode**: When a slot loads a cached prompt, the entry remains in cache and updates its usage metadata

This enables true shared reuse across multiple slots and requests over time.

### 2. Complete State Serialization and Restoration

Implement full save/load cycle for exact full-state blobs:

- **Save path**: Serialize complete llama_context state (target + optional draft) into `hybrid_cache_entry`
- **Load path**: Deserialize and restore complete llama_context state from cached entry
- **Atomicity**: Both save and restore must be atomic operations that succeed or fail cleanly

### 3. Usage Tracking and LRU Management

Build on existing LRU infrastructure to track cache effectiveness:

- **Access tracking**: Update `last_used_time` and `use_count` on every cache hit
- **LRU eviction**: Use existing `lru_index` for efficient eviction when under pressure
- **Protected roots**: Honor `protected_root` flag to preserve important cache entries

### 4. Multi-Slot Shared Access

Enable multiple slots to reference the same cached state:

- **Concurrent reads**: Multiple slots can load from the same cache entry
- **Independent lifetimes**: Each slot manages its own loaded state independently
- **No ownership transfer**: Cache entries are never "moved" to a slot

### 5. Metrics and Observability

Expose cache behavior through structured metrics:

- **Hit/miss tracking**: Count successful and failed cache lookups
- **Restore failures**: Track when state restoration fails for any reason
- **Usage distribution**: Report per-entry statistics for debugging and tuning

## Stage 2 Completion Requirements

### Current Stage 2 Status

**Architecture Stage 2 Goal**: Prepared-Prompt Boundary Metadata (R27-R33, R115)

**Current Implementation**:
- ✅ `prepared_prompt_metadata` structure exists with span-based boundaries
- ✅ `prompt_boundary` includes token_start, token_end, checksum, protect flag
- ✅ Metadata threading from HTTP layer through task pipeline to slots
- ⚠️ **Boundary capture uses rendered-text inference** (degraded/fallback approach)
- ⚠️ **Namespace compatibility keys incomplete**
- ❌ **No fixture tests proving boundary correctness**

**Risk**: Rendered-text inference produces incorrect boundaries for:
- Repeated message content (same text in multiple messages)
- Empty messages or minimal content
- Tool calls with JSON arguments
- Templates that escape or transform content
- Templates that add role/control tokens outside message spans

### Missing Stage 2 Functionality

Phase 3 implementation should complete Stage 2 in parallel with Stage 3 core work. The following Stage 2 gaps must be addressed:

#### Gap 2.1: Native Boundary Capture

**Current Behavior**:
- `server-context.cpp` searches rendered prompt text for message content
- Boundaries are post-processed from final prompt string
- Metadata is marked as inferred/degraded but not consistently

**Required Behavior** (Architecture requirement R27-R33):
- Capture boundaries during chat template application and tokenization
- Return boundaries alongside tokens from prompt preparation
- Mark any fallback/inferred boundaries explicitly as degraded

**Implementation Design**:

```cpp
// In server-chat.cpp or new server-prompt-prep.cpp
struct prompt_preparation_result {
    server_tokens tokens;
    prepared_prompt_metadata metadata;
    bool boundaries_native;  // true if captured natively, false if inferred
};

prompt_preparation_result prepare_chat_prompt(
    const llama_model* model,
    const llama_chat_message* messages,
    size_t n_messages,
    const char* tmpl,
    bool add_generation_prompt)
{
    prompt_preparation_result result;
    
    // Option A: Native capture during template application
    // - Track token positions as template renders each message
    // - Record boundary spans in result.metadata
    // - Set result.boundaries_native = true
    
    // Option B: Enhanced inference with validation
    // - Apply template and tokenize
    // - Infer boundaries from rendered text
    // - Validate against source messages
    // - Set result.boundaries_native = false
    // - Set result.metadata.degraded_reason = "inferred_from_rendered_text"
    
    return result;
}
```

**Files to Modify**:
- `tools/server/server-chat.cpp`: Add native capture during template application
- `tools/server/server-common.cpp`: Use native boundaries when available
- `tools/server/server-context.cpp`: Remove or mark rendered-text inference as fallback
- `tools/server/server-task.h`: Add `boundaries_native` flag to metadata

**Acceptance Criteria**:
- Chat boundaries captured without text search
- Degraded metadata explicitly marked with reason
- Fixture tests prove correctness (see Gap 2.3)

#### Gap 2.2: Comprehensive Namespace Compatibility Keys

**Current Behavior**:
- `compute_namespace_id()` uses basic model parameters
- Recent improvements added prompt metadata to key
- Still missing critical runtime configuration

**Required Behavior** (Architecture requirement R5-R14, R84-R86):
- Include all materially different runtime state in namespace key
- Prevent unsafe cross-restore between incompatible configurations

**Implementation Design**:

```cpp
// In server-cache-hybrid.h or new server-cache-compat.h
struct cache_compatibility_key {
    // Model identity
    std::string model_path_hash;      // Hash of model file path
    std::string model_params_hash;    // Hash of key model parameters
    
    // Draft model (for speculative decoding)
    std::string draft_model_hash;     // Hash or "none"
    
    // Tokenizer and template
    std::string tokenizer_id;         // From model metadata or computed
    std::string template_id;          // Template hash or version
    
    // Active modifiers
    std::vector<std::string> lora_adapters;  // Adapter paths + scales
    std::vector<std::string> control_vectors; // Vector paths + layer ranges
    
    // Multimodal configuration
    std::string mm_projector_id;      // Projector identity or "none"
    int mm_patch_size;                // Image token grid size
    bool mm_use_dynamic_tokens;       // Dynamic vs. fixed token count
    
    // Context and KV configuration
    int n_ctx;                        // Context window size
    int n_batch;                      // May affect checkpoint layout
    bool kv_unified;                  // KV cache mode
    
    // Workload profile
    std::string workload_profile;     // "plain_transformer" | "checkpoint_dependent" | etc.
    
    // Compute deterministic string representation
    std::string compute() const {
        std::ostringstream oss;
        oss << "model:" << model_params_hash
            << "|draft:" << draft_model_hash
            << "|tok:" << tokenizer_id
            << "|tmpl:" << template_id
            << "|lora:[" << join(lora_adapters, ",") << "]"
            << "|ctrl:[" << join(control_vectors, ",") << "]"
            << "|mm:" << mm_projector_id << ":" << mm_patch_size << ":" << mm_use_dynamic_tokens
            << "|ctx:" << n_ctx << ":" << n_batch << ":" << kv_unified
            << "|prof:" << workload_profile;
        return oss.str();
    }
};

// Builder function called at cache controller creation
cache_compatibility_key build_compatibility_key(
    const llama_model* model,
    const llama_model* model_draft,
    const common_params& params);
```

**Files to Modify**:
- `tools/server/server-cache-hybrid.h`: Add compatibility key structure
- `tools/server/server-cache-hybrid.cpp`: Implement key builder and comparison
- `tools/server/server-context.cpp`: Build key at controller creation
- `tools/server/server-task.h`: Store prompt-specific components in metadata

**Acceptance Criteria**:
- Different adapters produce different namespace keys
- Different draft models produce different keys
- Different multimodal configurations produce different keys
- Tests cover namespace mismatches for each key component

#### Gap 2.3: Fixture Tests for Boundary Correctness

**Current Behavior**:
- Generic unit tests for metadata structure
- No tests proving boundary extraction correctness
- No fixtures for problematic edge cases

**Required Behavior** (Architecture requirement R99-R106, R125-R129):
- Deterministic fixtures for representative chat patterns
- Byte-for-byte validation of boundary positions
- Coverage for known-problematic cases

**Implementation Design**:

```cpp
// In tests/test-cache-controller.cpp or new tests/test-boundaries.cpp

// Fixture 1: Repeated content
TEST_CASE("boundary_extraction_repeated_messages") {
    // Setup: Two messages with identical content
    std::vector<llama_chat_message> messages = {
        {"user", "Hello"},
        {"assistant", "Hi there!"},
        {"user", "Hello"}  // Same as first message
    };
    
    // Act: Prepare prompt and extract boundaries
    auto result = prepare_chat_prompt(model, messages.data(), messages.size(), tmpl, false);
    
    // Assert: Three distinct message boundaries
    REQUIRE(result.metadata.boundaries.size() >= 6);  // 3 messages × 2 boundaries
    
    // Assert: First and third "Hello" have different token positions
    auto msg1_start = find_boundary(result.metadata, MESSAGE_START, 0);
    auto msg3_start = find_boundary(result.metadata, MESSAGE_START, 2);
    REQUIRE(msg1_start.token_start != msg3_start.token_start);
}

// Fixture 2: Empty message
TEST_CASE("boundary_extraction_empty_message") {
    std::vector<llama_chat_message> messages = {
        {"system", "You are helpful"},
        {"user", ""},  // Empty content
        {"assistant", "How can I help?"}
    };
    
    auto result = prepare_chat_prompt(model, messages.data(), messages.size(), tmpl, false);
    
    // Assert: Boundary exists for empty message
    auto empty_msg = find_boundary_pair(result.metadata, MESSAGE_START, MESSAGE_END, 1);
    REQUIRE(empty_msg.found);
    // Token span may be zero-length or contain only role tokens
}

// Fixture 3: Tool calls
TEST_CASE("boundary_extraction_tool_calls") {
    std::vector<llama_chat_message> messages = {
        {"assistant", nullptr, {{"get_weather", "{\"location\":\"Paris\"}"}}},
    };
    
    auto result = prepare_chat_prompt(model, messages.data(), messages.size(), tmpl, false);
    
    // Assert: Tool call boundary exists
    auto tool_call = find_boundary_pair(result.metadata, TOOL_CALL_START, TOOL_CALL_END, 0);
    REQUIRE(tool_call.found);
    
    // Assert: Tool name "get_weather" is within the span
    auto tokens_in_span = slice(result.tokens, tool_call.start, tool_call.end);
    auto decoded = decode_tokens(model, tokens_in_span);
    REQUIRE(decoded.find("get_weather") != std::string::npos);
}

// Fixture 4: System/developer messages
TEST_CASE("boundary_extraction_system_message") {
    std::vector<llama_chat_message> messages = {
        {"system", "You are a helpful assistant"},
        {"user", "Hello"}
    };
    
    auto result = prepare_chat_prompt(model, messages.data(), messages.size(), tmpl, false);
    
    // Assert: System boundary has protection flag
    auto sys_msg = find_boundary_pair(result.metadata, SYSTEM_START, SYSTEM_END, 0);
    REQUIRE(sys_msg.found);
    REQUIRE(result.metadata.protect_system == true);
}

// Fixture 5: Templates with role tokens
TEST_CASE("boundary_extraction_role_tokens") {
    // Use a template that adds "<|im_start|>user\n" before content
    std::vector<llama_chat_message> messages = {
        {"user", "Test message"}
    };
    
    auto result = prepare_chat_prompt(model, messages.data(), messages.size(), 
                                      chatml_template, false);
    
    // Assert: Message boundary excludes or includes role tokens consistently
    auto msg = find_boundary_pair(result.metadata, MESSAGE_START, MESSAGE_END, 0);
    REQUIRE(msg.found);
    
    // Validate that boundary decision is documented
    // (Either include role tokens or exclude them, but be consistent)
}
```

**Files to Create/Modify**:
- `tests/test-boundaries.cpp`: New focused boundary test suite
- `tests/fixtures/chat_templates/`: Template variants for testing
- `tests/test-cache-controller.cpp`: Add boundary validation helpers

**Acceptance Criteria**:
- All fixture tests pass with native boundary capture
- Tests cover: repeated content, empty messages, tool calls, system messages, role tokens
- Coverage ≥90% for boundary extraction code paths

### Stage 2 Completion Timeline

**Recommended Implementation Sequence**:

#### **Sequence Option A: Complete Stage 2 Before Stage 3**
1. **Week 1-2**: Implement Gap 2.2 (Comprehensive namespace keys)
   - Least risky, improves safety immediately
   - Required for correct multi-namespace operation
2. **Week 3-4**: Implement Gap 2.3 (Fixture tests with current inference)
   - Establishes correctness baseline
   - May reveal inference bugs to fix
3. **Week 5-7**: Implement Gap 2.1 (Native boundary capture)
   - Most complex, benefits from fixture tests
   - Validates against established test suite
4. **Week 8+**: Proceed with Stage 3 core work

**Pros**: Clean stage separation, reduced risk  
**Cons**: Delays Stage 3 value delivery

#### **Sequence Option B: Parallel Track (Recommended)**
1. **Phase 3 Core Track** (4-6 weeks):
   - Implement Stage 3 exact blob save/load (Steps 3.1-3.6)
   - Use existing degraded boundary metadata
   - Mark boundary limitations explicitly
   
2. **Stage 2 Completion Track** (parallel, 6-8 weeks):
   - Week 1-2: Gap 2.2 (Namespace keys) - **BLOCKING for Phase 3 multi-namespace tests**
   - Week 3-4: Gap 2.3 (Fixture tests)
   - Week 5-8: Gap 2.1 (Native capture)

3. **Integration** (Week 9):
   - Replace degraded boundaries with native boundaries
   - Re-run all Phase 3 tests with native metadata
   - Validate no regressions

**Pros**: Delivers Stage 3 value sooner, efficient parallelization  
**Cons**: More coordination, must manage degraded metadata carefully

#### **Sequence Option C: Minimal Stage 2 for Phase 3**
1. **Immediate** (before Phase 3 Step 3.1):
   - Gap 2.2: Comprehensive namespace keys (1-2 weeks)
   - Explicit degraded metadata markers (1 day)
2. **During Phase 3**:
   - Use degraded boundaries throughout Phase 3 implementation
3. **Post-Phase 3**:
   - Gap 2.3: Fixture tests (2-3 weeks)
   - Gap 2.1: Native capture (3-4 weeks)

**Pros**: Fastest to Stage 3 completion  
**Cons**: Technical debt, may need Phase 3 rework later

### Recommendation: **Option B (Parallel Track)**

**Rationale**:
- Namespace keys (Gap 2.2) are blocking for correct Phase 3 multi-namespace testing
- Native boundary capture (Gap 2.1) is valuable but not blocking for exact blob cache
- Parallel work maximizes developer productivity
- Explicit degraded markers prevent confusion about boundary quality

**Phase 3 Dependencies**:
- ✅ Stage 1: Complete
- ⚠️ Stage 2: Functional but degraded (acceptable with explicit markers)
- 🔄 Gap 2.2: **Must complete before Phase 3 Step 3.6** (multi-namespace tests)
- 🔄 Gap 2.1 + 2.3: **Can complete in parallel** with Phase 3 core work

## Requirements Addressed

This stage directly implements or enables the following requirements:

| Requirement | Description | Implementation |
|-------------|-------------|----------------|
| R99 | Tests for non-destructive prompt-cache hits | Test coverage section specifies comprehensive test cases |
| R80 | Slots reference shared branches without ownership transfer | Cache entries remain in `entries` list after load |
| R81 | Restoring branch for one slot doesn't consume it for others | `load_slot()` updates usage without erasing entry |
| R82 | Slot-local live state exists, cache objects not one-shot | Slot copies state; cache retains original |
| R83 | Multiple slots traverse same branch graph over time | LRU and non-destructive hits enable reuse |
| R90 | Preserve inference correctness above hit rate | Validation on restore, explicit failure on mismatch |
| R91 | Every restore path produces equivalent valid model state | Full state restoration with integrity checks |

## Non-Goals for Stage 3

The following features are **explicitly deferred** to later stages:

- **Checkpoint-based branching** (Stage 4+): This stage only handles exact full-state blobs
- **Cold storage offload** (Stage 6+): All cached state remains in RAM
- **Payload eviction vs. branch pruning** (Stage 8+): Eviction removes entire entries, not just payloads
- **Metadata-only branch nodes** (Stage 8+): All entries must have full state data
- **Branch graph topology** (Stage 8+): Entries are independent, no parent-child relationships yet
- **Validation mismatch handling** (Stage 8+): Assumes validation always succeeds for now
- **Multimodal support** (Stage 10): Only text-based prompts are supported

## Design Principles

1. **Incremental correctness**: Each implementation step must maintain a working, testable system
2. **Explicit failure modes**: When restore cannot succeed, fail loudly with diagnostic logging
3. **Test-driven development**: Write tests before implementation to define expected behavior
4. **Backward compatibility**: Legacy mode behavior must remain unchanged
5. **Performance awareness**: Use existing prefix index and LRU index to minimize overhead

## Success Criteria Summary

Stage 3 is complete when:

1. Hybrid cache can save exact full-state blobs from slots
2. Hybrid cache can restore exact full-state blobs to slots
3. Cache hits are non-destructive (entries remain after load)
4. Multiple slots can reuse the same cached entry
5. Usage metadata updates correctly on each hit
6. Metrics accurately report hits, misses, and restore failures
7. All tests pass with ≥80% code coverage
8. Legacy mode behavior remains unchanged

---

**Next**: [Part 2: Component Design](./part-02-component-design.md)
