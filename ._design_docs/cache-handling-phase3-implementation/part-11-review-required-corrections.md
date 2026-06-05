
**File**: `tools/server/server-cache-hybrid.cpp`

```cpp
cache_compatibility_key build_compatibility_key(
    const llama_model* model,
    const llama_model* model_draft,
    const common_params& params) {
    
    cache_compatibility_key key;
    
    // Model identity
    key.model_path_hash = compute_file_hash(params.model);
    key.model_params_hash = compute_model_params_hash(model);
    
    // Draft model
    if (model_draft) {
        key.draft_model_hash = compute_model_params_hash(model_draft);
    } else {
        key.draft_model_hash = "none";
    }
    
    // Tokenizer and template
    key.tokenizer_id = get_tokenizer_id(model);
    key.template_id = get_template_id(params);
    
    // LoRA adapters
    for (const auto& adapter : params.lora_adapters) {
        key.lora_adapters.push_back(
            adapter.path + ":" + std::to_string(adapter.scale)
        );
    }
    std::sort(key.lora_adapters.begin(), key.lora_adapters.end());
    
    // Control vectors
    for (const auto& cv : params.control_vectors) {
        key.control_vectors.push_back(
            cv.path + ":" + 
            std::to_string(cv.layer_start) + "-" + 
            std::to_string(cv.layer_end)
        );
    }
    std::sort(key.control_vectors.begin(), key.control_vectors.end());
    
    // Multimodal configuration
    key.mm_projector_id = params.mmproj.empty() ? "none" : compute_file_hash(params.mmproj);
    key.mm_patch_size = params.mm_patch_size;
    key.mm_use_dynamic_tokens = params.mm_use_dynamic_tokens;
    
    // Context configuration
    key.n_ctx = params.n_ctx;
    key.n_batch = params.n_batch;
    key.kv_unified = params.kv_unified;
    
    // Workload profile
    key.workload_profile = params.workload_profile;
    
    return key;
}
```

##### C. Update compute_namespace_id()

**File**: `tools/server/server-cache-hybrid.cpp`

Replace simple namespace computation with comprehensive key builder:

```cpp
std::string hybrid_cache_controller::compute_namespace_id() const {
    cache_compatibility_key key = build_compatibility_key(
        model, model_draft, params);
    return key.compute();
}
```

##### D. Add Namespace Isolation Tests

**File**: `tests/test-cache-controller.cpp`

```cpp
TEST_CASE("hybrid_namespace_isolation_lora_adapters") {
    // Setup: Create entries with same tokens but different LoRA adapters
    // Verify: They produce different namespace keys
    // Verify: Cache lookup doesn't match across adapters
}

TEST_CASE("hybrid_namespace_isolation_draft_model") {
    // Setup: Create entries with same tokens but different draft models
    // Verify: They produce different namespace keys
    // Verify: Cache lookup doesn't match across draft configs
}

TEST_CASE("hybrid_namespace_isolation_multimodal") {
    // Setup: Create entries with same tokens but different MM projectors
    // Verify: They produce different namespace keys
    // Verify: Cache lookup doesn't match across MM configs
}

TEST_CASE("hybrid_namespace_isolation_template") {
    // Setup: Create entries with same tokens but different templates
    // Verify: They produce different namespace keys
    // Verify: Cache lookup doesn't match across templates
}

TEST_CASE("hybrid_namespace_isolation_context_config") {
    // Setup: Create entries with same tokens but different n_ctx
    // Verify: They produce different namespace keys
    // Verify: Cache lookup doesn't match across context sizes
}
```

**Estimated Effort**: 2-3 days
- Structure and builder: 1 day
- Integration and testing: 1-2 days

---

#### 2. Update Implementation Log Documentation (MEDIUM)

**Priority**: **HIGH** - Correct documentation to reflect actual status

##### A. Update Step 3.1 Section

**Location**: Step 3.1 subsection

**Change**: Add "Missing Implementation" section:

```markdown
### Missing Implementation ⚠️

#### Gap 2.2: Comprehensive Namespace Keys (REQUIRED)

**Status**: NOT IMPLEMENTED  
**Blocking Issue**: Comprehensive namespace key builder missing

**What's Missing**:
- [ ] `cache_compatibility_key` structure not created
- [ ] `build_compatibility_key()` function not implemented
- [ ] Comprehensive namespace tests not added
- [ ] Current implementation uses basic compatibility_key only

**Impact**:
- Multi-model deployments: High risk of unsafe cross-restore
- LoRA adapter scenarios: High risk of cache pollution
- Speculative decoding: High risk of wrong draft model state
- Single model deployments: Low risk, current implementation sufficient

**Required Before**: Step 3.6 acceptance per design document

**Design Reference**: 
- [Part 1: Gap 2.2](cache-handling-phase3-design/part-01-overview-and-objectives.md#gap-22-comprehensive-namespace-compatibility-keys)
- [Part 3: Step 3.1, Task 2](cache-handling-phase3-design/part-03-implementation-steps.md#step-31)
```

##### B. Update Steps 3.2-3.5 Sections

**Change**: Add clarification notes:

```markdown
**Implementation Note**: This functionality was implemented in Phase 1/2 as part
of initial hybrid cache development. Phase 3 design includes these steps for
validation and documentation closure. See [Phase 1 Implementation Log] for
original implementation details.
```

##### C. Update Final Verification Section

**Change**: Update Gap 2.2 checkbox:

```markdown
### Stage 2 Completion Prerequisites

From acceptance criteria:

- [x] Gap 2.1: Can use degraded text-search boundary (with markers)
- [ ] **Gap 2.2: Comprehensive namespace keys REQUIRED before Step 3.6** ⚠️
- [x] Gap 2.3: Fixture tests (independent, can be parallel)
```

##### D. Update Sign-Off Section

**Change**: Revise status and add corrected summary:

```markdown
