# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 8: Implementation Notes

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

### Implementation Notes

**Namespace ID Computation**:
```cpp
std::string hybrid_cache_controller::compute_namespace_id() const {
    // Compute from current context state
    std::string key = model_tgt ? llama_model_desc(model_tgt) : "";
    if (model_dft) {
        key += "|draft:" + std::string(llama_model_desc(model_dft));
    }
    // Future: add LoRA adapters, quantization settings, etc.
    return std::to_string(std::hash<std::string>{}(key));
}
```

**Lookup Filtering**:
```cpp
for (auto it = entries.begin(); it != entries.end(); ++it) {
    // Enforce namespace isolation
    if (it->namespace_id != request_namespace) {
        continue;  // Skip entries from different namespaces
    }
    // ... continue with prefix matching ...
}
```

**Statistics**:
- `get_stats()` reports total namespaces and entries per namespace
- Helps operators understand multi-model cache pressure
- Enables future per-namespace observability

---

## Open Questions and Decisions

### Q1: Boundary Extraction Detail

**Question**: How deeply should Phase 1 integrate with the chat template engine for boundary extraction?

**Options**:
- A) Minimal: Use heuristic post-processing of formatted prompt
- B) Moderate: Add boundary tracking hooks to template engine
- C) Deep: Fully integrate boundaries into template compilation

**Recommendation**: Start with (A) for Phase 1, transition to (B) in Phase 2. Phase 1 should prove the architecture without requiring template engine changes.

### Q2: Protection Mechanism

**Question**: How should entries be marked as protected in Phase 1?

**Options**:
- A) Manual API: Explicit endpoint to mark cache entries as protected
- B) Heuristic: Automatically protect entries with system prompts
- C) Policy-based: Configure protection rules via server settings
- D) Deferred: No automatic protection in Phase 1, add in Phase 2

**Recommendation**: (D) for Phase 1 - add the `protected_root` flag but don't automatically set it. This allows the architecture to exist without adding complexity. Phase 2 can add policy-based protection.

### Q3: Metadata Transport

**Question**: Should `prepared_prompt_metadata` be part of `server_task` or a separate parallel structure?

**Options**:
- A) Part of `server_task`: Direct field access
- B) Separate structure: Passed alongside task
- C) Optional attachment: Task holds `std::optional<prepared_prompt_metadata>`

**Recommendation**: (A) - Direct field in `server_task`. Simpler to implement and maintain. Can always refactor later if needed.

---

## Success Criteria

Phase 1 is complete when:

✅ Legacy mode works identically to current implementation  
✅ Hybrid mode can be enabled via `--cache-mode hybrid`  
✅ Hybrid mode preserves cache entries after hits  
✅ LRU eviction works correctly under memory pressure  
✅ Protected root mechanism exists (even if not automatically used)  
✅ Prepared-prompt metadata structures are defined and transported  
✅ All existing cache-related tests pass in both modes  
✅ New Phase 1 tests achieve >90% coverage of new code  
✅ Documentation explains mode differences  
✅ Zero performance regression in legacy mode

---

## Appendix: File Map

### New Files

```
tools/server/
├── server-cache-controller.h          # Abstract interface
├── server-cache-controller.cpp        # Factory function
├── server-cache-legacy.h              # Legacy wrapper
├── server-cache-legacy.cpp
├── server-cache-hybrid.h              # Phase 1 hybrid implementation
└── server-cache-hybrid.cpp

tests/
├── test-cache-controller.cpp          # Unit tests
└── test-server-cache-integration.cpp  # Integration tests
```

### Modified Files

```
common/common.h                        # Add cache_mode enum
tools/server/main.cpp                  # Add --cache-mode arg
tools/server/server-task.h             # Add boundary metadata structs
tools/server/server-task.cpp           # Add metadata to task creation
tools/server/server-context.h          # Change prompt_cache to cache_ctrl
tools/server/server-context.cpp        # Use cache_controller interface
tools/server/server-chat.cpp           # Add boundary extraction (placeholder)
```

---

## References

- [cache-handling-requirements.md](../cache-handling-requirements.md) - Full requirements
- [cache-handling-architecture.md](../cache-handling-architecture.md) - Overall architecture
- [AGENTS.md](../../AGENTS.md) - Contribution guidelines
- [llama.cpp server documentation](../../tools/server/README.md)

---

**End of Phase 1 Design Document**
