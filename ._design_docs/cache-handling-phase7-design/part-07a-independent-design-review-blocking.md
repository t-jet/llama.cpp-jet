# Part 07A: independent design review blocking findings

Source: [Part 07](part-07-independent-design-review.md)  
Reviewer: Architect agent  
Date: 2026-05-31  
Verdict: REWORK

## B1: BranchNode struct mismatch with architecture

Location: `part-02-component-design.md` section 2.1.

The architecture defines `BranchNode` as a shared forest node with:

- `node_id`
- `namespace_id`
- `parent_id`
- `n_tokens`
- `pos_min`
- `pos_max`
- `usage`
- `residency_state`
- `protected_root`
- `is_metadata_only`
- `exact_blob_ref`
- `checkpoint_ref`

The reviewed design defined a slot metadata record instead:

```cpp
struct BranchNode {
    slot_id      parent_slot_id;
    int64_t      fork_offset;
    int64_t      generation;
    int64_t      subtree_size;
    int32_t      ref_count;
    int64_t      created_at;
    int64_t      last_used;
};
```

The design omitted namespace identity, token span fields, residency state, protection state, and
payload references. It also added fields that were not part of the architecture model.

Required correction:

1. Adopt the architecture's `BranchNode` fields and justify any Stage 7-specific additions.
2. Or document an approved architecture deviation.
3. Clarify that `BranchNode` is a shared forest node, not a per-slot metadata extension.

## B2: Budget model contradiction with architecture

Locations:

- `part-02-component-design.md` section 2.4
- `part-01-overview-and-objectives.md` section 1.2

The architecture requires a shared budget model across all namespaces:

- hot payload RAM
- branch metadata RAM
- cold-layer storage

It also requires global LRU eviction regardless of namespace.

The reviewed design used this per-namespace slot-count model:

```cpp
struct NamespaceBudget {
    int32_t max_slots;
    int32_t used_slots;
    int32_t reserved_slots;
};
```

That model contradicted the accepted architecture. It introduced per-namespace quotas where the
architecture required one shared budget pool.

Required correction:

1. Replace per-namespace slot limits with a global byte-budget model.
2. Or document an approved architecture deviation.
3. Preserve global payload eviction across namespaces.

## B3: NamespaceKey lacks compatibility semantics

Location: `part-02-component-design.md` section 2.3.

The architecture requires namespace compatibility to include:

- target model identity
- draft model identity or absence of draft
- tokenizer-compatible prompt semantics
- workload profile
- material runtime modifiers, including adapters, control vectors, multimodal projector identity,
  and multimodal token layout

The reviewed design defined this key:

```cpp
struct NamespaceKey {
    int64_t namespace_id;
    slot_id slot_id;
    bool operator==(const NamespaceKey& other) const = default;
};
```

That key was a lookup key, not a compatibility key. It did not prevent unsafe cross-model or
cross-configuration restores.

Required correction:

1. Redefine `NamespaceKey`, or add a separate compatibility key, with the architecture-required
   fields.
2. Add strict validation before restore.
3. Or document an approved architecture deviation.

## Blocking risk assessment

| Risk | Likelihood | Impact | Assessment |
| --- | --- | --- | --- |
| BranchNode mismatch causes implementation rework | High | High | Blocking. The struct is the foundation for Stage 7. |
| Budget model contradicts global eviction | High | High | Blocking. Eviction, metrics, and configuration depend on this choice. |
| Missing compatibility validation permits unsafe restores | High | High | Blocking. The cache must reject mismatched namespaces. |
