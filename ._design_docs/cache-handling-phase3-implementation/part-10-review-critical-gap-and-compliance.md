### Critical Gap: Missing Comprehensive Namespace Keys ❌

#### Design Requirement (Step 3.1, Task 2)

From **Part 3: Implementation Steps**, Step 3.1:

> **Task 2: [Gap 2.2 Integration] Implement comprehensive namespace key builder**  
> (see Part 1, Gap 2.2 for design)

From **Part 1: Gap 2.2 - Comprehensive Namespace Compatibility Keys**, the design specifies:

```cpp
struct cache_compatibility_key {
    std::string model_path_hash;
    std::string model_params_hash;
    std::string draft_model_hash;
    std::string tokenizer_id;
    std::string template_id;
    std::vector<std::string> lora_adapters;
    std::vector<std::string> control_vectors;
    std::string mm_projector_id;
    int mm_patch_size;
    bool mm_use_dynamic_tokens;
    int n_ctx;
    int n_batch;
    bool kv_unified;
    std::string workload_profile;
    
    std::string compute() const;
};
```

**Required Components**:
1. Model identity (path hash, params hash)
2. Draft model identity or "none"
3. Tokenizer and template identity
4. Active LoRA adapters with scales
5. Control vectors with layer ranges
6. Multimodal projector identity
7. Multimodal configuration (patch size, dynamic tokens)
8. Context and KV configuration (n_ctx, n_batch, kv_unified)
9. Workload profile

#### What Was Actually Implemented

**From implementation log (Step 3.1)**:
- Basic `compute_namespace_id()` using simple parameters
- Uses `compatibility_key` from metadata when available
- **Does NOT implement** the comprehensive `cache_compatibility_key` structure
- **Does NOT implement** `build_compatibility_key()` function
- **Does NOT include** tests for namespace isolation across:
  - Different LoRA adapters
  - Different draft models
  - Different multimodal configurations
  - Different templates/tokenizers

#### Impact and Risk Assessment

**Severity**: **HIGH** ⚠️

**Functional Impact**:
Without comprehensive namespace keys, the following unsafe scenarios are possible:

1. **LoRA Adapter Pollution**: Different LoRA adapters can incorrectly share cache entries, causing wrong inference results
2. **Draft Model Mismatch**: Different draft models can incorrectly share cache entries in speculative decoding
3. **Multimodal Config Mismatch**: Different multimodal configurations can incorrectly share projector states
4. **Template/Tokenizer Mismatch**: Different templates or tokenizers can incorrectly share token sequences

**Architecture Violations**:
- **R5-R14**: "Namespace must prevent unsafe cross-restore between materially different runtimes"
- **R84-R86**: "Workload profile awareness for namespace isolation"

**Deployment Risk Matrix**:

| Scenario | Risk Level | Explanation |
|----------|-----------|-------------|
| Single model, no adapters | ✅ Low | Current basic namespace keys sufficient |
| Multiple models in cache | ⚠️ High | Unsafe cross-restore possible |
| LoRA adapters | ⚠️ High | Cache pollution between adapters |
| Speculative decoding | ⚠️ High | Wrong draft model state restoration |
| Multimodal inference | ⚠️ Medium | Projector config mismatch possible |

---

### Step-by-Step Compliance Check

#### Step 3.1: Helper Methods and Data Structures

| Design Task | Implementation Status | Evidence |
|-------------|----------------------|----------|
| 1. Add compatibility_key field | ✅ Done | Field exists (prior work) |
| 2. **[Gap 2.2] Comprehensive namespace key builder** | ❌ **NOT DONE** | Basic version only, comprehensive structure missing |
| 3. compute_namespace_id() (no-argument) | ✅ Done | Exists in codebase |
| 4. compute_namespace_id(metadata) | ✅ Done | Uses basic compatibility_key |
| 5. find_exact_match() helper | ✅ Done | Implemented correctly |
| 6. update_lru_index() helper | ✅ Done | Exists (prior work) |
| 7. boundaries_native flag | ✅ Done | Added to prepared_prompt_metadata |
| 8. Degraded metadata markers | ✅ Done | boundaries_native=false, degraded_reason set |

**Step 3.1 Status**: 7/8 tasks completed. **Missing: Comprehensive namespace key builder (Gap 2.2)**

#### Step 3.2-3.5: Save/Load Implementation

| Step | Design Requirement | Implementation Status | Notes |
|------|-------------------|----------------------|-------|
| 3.2 | save_slot() without serialization | ✅ Exists | Implemented in prior phase |
| 3.3 | Add state serialization | ✅ Exists | Implemented in prior phase |
| 3.4 | load_slot() without restoration | ✅ Exists | Implemented in prior phase |
| 3.5 | Add state restoration | ✅ Exists | Implemented in prior phase |

**Status**: Functionality exists and works correctly. Implementation predates Phase 3 but meets design specifications.

**Recommendation**: Update documentation to clarify which phase originally implemented these features and cross-reference original implementation logs.

#### Step 3.6: End-to-End Validation

| Design Requirement | Implementation Status | Notes |
|-------------------|----------------------|-------|
| Integration tests | ✅ Pass (24/24) | All tests passing |
| Performance benchmarks | ✅ Verified | Meets baseline |
| Coverage ≥80% | ✅ Achieved 93.625% | Exceeds requirement |
| Metrics validation | ✅ Working | Comprehensive tracking |
| **Gap 2.2 complete before Step 3.6** | ❌ **BLOCKING** | Required by design document |

**Status**: Tests pass and coverage excellent, but **blocking prerequisite (Gap 2.2) not met** per design acceptance criteria.

---

### Architecture Compliance Review

| Architecture Requirement | Implementation Status | Risk Level | Notes |
|-------------------------|----------------------|------------|-------|
| **R5-R14**: Hybrid model and model-family awareness | ⚠️ Partial | **High** | Basic namespace exists, comprehensive keys missing |
| **R15-R26**: Non-destructive hits, LRU, protected roots | ✅ Complete | Low | Fully implemented |
| **R27-R33**: Prepared-prompt boundaries | ✅ Degraded | Low | Degraded mode with explicit markers |
| **R34-R36**: Correctness and fallback | ✅ Complete | Low | Working correctly |
| **R69-R83**: Shared branch graph (Stage 3 subset) | ✅ Complete | Low | Non-destructive reuse working |
| **R80-R83**: Slot-independent reuse | ✅ Complete | Low | Multi-slot access verified |
| **R84-R86**: Workload profile awareness | ⚠️ Partial | **High** | Structure exists, comprehensive keys needed |
| **R90-R91**: Preserve inference correctness | ✅ Complete | Low | Verified in tests |
| **R99**: Non-destructive cache hit tests | ✅ Complete | Low | All tests passing |

**Critical Architecture Gap**: Requirements R5-R14 and R84-R86 require comprehensive namespace isolation to prevent unsafe cross-restore. Current implementation has basic isolation but missing comprehensive keys for multi-model/multi-adapter scenarios.

---

### Required Corrections

#### 1. Implement Gap 2.2: Comprehensive Namespace Keys (CRITICAL)

**Priority**: **IMMEDIATE** - Required by design before Step 3.6 acceptance

**What to Implement**:

##### A. Create cache_compatibility_key Structure

**File**: `tools/server/server-cache-hybrid.h`

```cpp
struct cache_compatibility_key {
    std::string model_path_hash;           // Hash of model file path
    std::string model_params_hash;         // Hash of model hyperparameters
    std::string draft_model_hash;          // Hash of draft model or "none"
    std::string tokenizer_id;              // Tokenizer identifier
    std::string template_id;               // Template identifier
    std::vector<std::string> lora_adapters; // Active LoRA adapters with scales
    std::vector<std::string> control_vectors; // Control vectors with layer ranges
    std::string mm_projector_id;           // Multimodal projector identifier
    int mm_patch_size;                     // Multimodal patch size
    bool mm_use_dynamic_tokens;            // Multimodal dynamic token flag
    int n_ctx;                             // Context size
    int n_batch;                           // Batch size
    bool kv_unified;                       // KV cache unified flag
    std::string workload_profile;          // Workload profile identifier
    
    // Compute SHA-256 hash of all components
    std::string compute() const;
};
```

##### B. Implement build_compatibility_key() Function
