# Requirements for Alternate Hybrid Cache Mode in `llama-server` - Part 2: Fully Slot-Independent Shared Reuse

Source: [../cache-handling-requirements.md](../cache-handling-requirements.md)

### Fully Slot-Independent Shared Reuse

- R80. Slots must be able to reference shared branch nodes without transferring ownership of the underlying cache object.
- R81. Restoring a branch for one slot must not inherently consume that branch node for other slots.
- R82. Slot-local live state may still exist, but cache objects in the branch graph must not be modeled as one-shot entries.
- R83. The architecture must allow multiple idle or active slots to traverse the same shared branch graph over time.
- R83a. If multiple requests or slots converge on the same validated prompt path, the implementation must reuse or join the equivalent branch instead of creating duplicate equivalent branch nodes.

### Checkpoint-Dependent Model Behavior

- R84. For checkpoint-dependent models, the branch graph must prefer checkpoint nodes as the canonical branch structure.
- R85. Full-state blobs may still exist for exact-restore efficiency, but checkpoint nodes must remain the source of branch continuity when rollback limits make arbitrary token-offset reuse unsafe.
- R86. The architecture must preserve correct behavior for SWA, RS-limited, recurrent, and MTP-heavy cases.

### Multimodal Support

- R87. The long-term architecture must define how multimodal branches are matched and restored.
- R88. Existing media hashing support may be reused as part of branch matching metadata.
- R89. If a long-term feature is not yet safe for multimodal prompts, the implementation must fail explicitly rather than silently downgrading correctness.

## Cross-Cutting Acceptance Requirements

### Correctness

- R90. Every phase must preserve inference correctness as a higher priority than cache hit rate.
- R91. Every restore path must produce equivalent valid model state for its intended branch object.
- R92. Any unsupported combination of features must fail explicitly.

### Performance

- R93. The implementation must define configurable budget controls for hot payload RAM residency, branch-metadata RAM retention, and cold-layer usage.
- R94. The implementation must be benchmarkable separately for:
- R95. exact full-state blob hit rate.
- R96. checkpoint-based branch hit rate.
- R97. hot-to-cold and cold-to-hot transitions.
- R98. overall prompt processing savings.

### Testability

- R99. The implementation must include tests for non-destructive prompt-cache hits.
- R100. The implementation must include tests for protected roots or cache markers.
- R101. The implementation must include tests for prepared-prompt boundary propagation.
- R102. The implementation must include tests for cold offload and restore of full-state blobs.
- R103. The implementation must include tests for cold offload and restore of checkpoints.
- R104. The implementation must include tests for target-plus-draft pairing across hot and cold transitions.
- R105. The implementation must include tests for safe fallback when a payload is missing, invalid, or unsupported.
- R106. The implementation must include tests for checkpoint-dependent model behavior.
- R107. Test coverage for the new functionality should be at least 80%.

## Explicit Exclusion

The following feature is explicitly excluded from this requirements document:

- replaying model-generated output up to tool or user boundaries

