# Phase 4 Design: LRU Eviction Policy with Protected Roots - Part 3: Protected-root budget behavior

Source: [../cache-handling-phase4-design.md](../cache-handling-phase4-design.md)

## Protection model

Protected roots are entries that server policy believes are likely to be reused as stable workflow roots. Protection is a retention preference, not a memory exemption.

Phase 4 treats protection as a weighted LRU class:

1. Evict unprotected entries first, oldest use sequence first.
2. If the cache is still over budget, consider protected entries.
3. Evict protected entries oldest first only when keeping them would violate the hot payload budget.

This satisfies the architecture rule that protected roots have higher priority but still count against memory.

## What can mark an entry protected

Protection can come from:

- server-side prepared-prompt metadata from earlier phases
- configured server rules that identify system or controller-root prompt regions
- future internal branch-root classification, once branch graph stages exist

Phase 4 must not accept untrusted request input as a direct protected-root command. If later work adds request-provided cache markers, Stage 10 security review must validate and sanitize them before they affect protection.

## Budget cases

### Budget can be satisfied by unprotected eviction

The policy evicts the oldest unprotected entries until resident bytes fit. It records that protected roots were skipped, but it does not warn unless protected bytes are near or above the budget.

### Protected roots fit only after unprotected eviction

This is normal pressure. The policy emits debug-level diagnostics with protected and unprotected byte totals. Metrics record protected-root decisions as `skipped_unprotected_eviction_candidate` or equivalent.

### Protected roots exceed the budget

The policy must emit an explicit warning. The warning should include:

- configured hot payload budget
- resident protected payload bytes
- resident total payload bytes
- number of protected entries
- selected action

The action is to evict protected entries by LRU order until the cache fits, unless the only over-budget object is the incoming entry and admission was rejected before insertion.

### One protected entry exceeds the budget

The controller rejects admission for a new entry that individually exceeds the configured budget. If an already resident protected entry becomes over budget because of a runtime configuration change or accounting correction, the policy may evict it and must warn.

### Unlimited budget

With `--cache-ram -1`, the policy records usage and protected decisions but does not evict for RAM pressure.

## Diagnostics

Protected-root diagnostics must be specific enough to explain why an entry that looked protected was still evicted. Required messages:

- protected root skipped during ordinary unprotected eviction
- protected-root budget pressure detected
- protected root evicted because protected bytes exceeded the budget
- protected root admission rejected because one entry exceeded the budget

These logs must use existing server logging conventions. Warning level is appropriate when protected entries must be evicted or rejected. Debug level is enough when protected entries are merely skipped while unprotected entries satisfy the budget.

## Invariants

- Protection never permits resident payload bytes to remain over budget after the policy has legal eviction candidates.
- Protection never splits target and draft payloads.
- Protection does not change namespace matching or restore correctness.
- Protection state is visible in stats so tests and operators can tell whether budget pressure is coming from protected entries.

