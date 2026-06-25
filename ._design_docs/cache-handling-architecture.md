# Software Architecture: Alternate Hybrid Cache Mode for llama-server

Status: Target state - atomic transactional cache writes per Stage 25
Date: 2026-06-25
Primary source: `cache-handling-requirements.md`

## Target state summary

The hybrid cache controller operates as an atomic transactional state machine under a single recursive mutex. Every demote, evict, restore, admit, and cold-store transition runs synchronously inside a `tx_*` transaction invoked from the slot request that triggered it; no background thread or async drain mutates cache state. The transactional method, slot-lifecycle bindings (`tx_restore`, `tx_apply_restore`, `tx_save`, `tx_load`), and the three new invariants I-25-01 atomicity, I-25-02 isolation, and I-25-03 durability-within-transaction are recorded in [Stage 25 design](cache-handling-phase25-design.md) and applied throughout the parts below.

## Contents

This document is split into smaller part files. Read the parts in order when you need the full content.

- [Part 1: Method](./cache-handling-architecture/part-01-method.md)
- [Part 2: Restore and Residency Flow](./cache-handling-architecture/part-02-restore-and-residency-flow.md)
- [Part 3: API Endpoint Compatibility](./cache-handling-architecture/part-03-api-endpoint-compatibility.md)
- [Part 4: ADR-009: Distinguish Payload Eviction from Branch Pruning and Support Metadata-Only Branch Nodes](./cache-handling-architecture/part-04-adr-009-distinguish-payload-eviction-from-branch.md)
- [Part 5: Stage 4: LRU Eviction Policy with Protected Roots](./cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md)
- [Part 6: Stage 5 Draft Context Modes and Pairing](./cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md)
- [Part 7: Speculative decode-batch cap invariant](./cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md)
- [Part 8: Stage 13 Endpoint Compatibility Corrections](./cache-handling-architecture/part-08-stage-13-endpoint-compatibility-corrections.md)
- [Part 9: Chat-Path Prompt-Span Boundary Invariant](./cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md) (post-closure follow-up, 2026-06-16)
