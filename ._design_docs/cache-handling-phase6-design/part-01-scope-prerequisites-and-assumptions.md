# Phase 6 design: cold layer and asynchronous I/O - Part 1: Scope, prerequisites, and assumptions

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Objective

Stage 6 extends the hybrid cache with a versioned filesystem store and an asynchronous I/O worker. It allows payloads evicted from hot RAM to survive as cold files, and promotes them back to hot on demand without blocking the `server_context` thread.

The cold layer is opt-in. Unless an operator provides an explicit cold store root path, the server behaves exactly as Stage 5: payloads are evicted from RAM and discarded. No disk I/O is introduced automatically.

## Prerequisites

- Stage 5 is closed per [Phase 5 implementation Part 11](../cache-handling-phase5-implementation/part-11-stage-closure-decision.md) and the manager closure decision in the same document.
- `PayloadDescriptor` exists as a first-class structure with `payload_id`, `pair_state`, `format_version`, `residency_state`, `store_ref`, target and draft checksum fields, and byte-size fields as specified in [Phase 5 design Part 2](../cache-handling-phase5-design/part-02-interfaces-components-and-data-model.md).
- `residency_state` has the value `hot` in Stage 5. The value `cold` is reserved but rejected in Stage 5 as documented in [Phase 5 design Part 3](../cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md).
- `store_ref` is defined as an abstract handle in Stage 5 capable of representing either a hot in-memory reference or a future cold-store reference without changing descriptor ownership rules.
- Target/draft pairing, transactional restore, and pre-apply validation are enforced as specified in [Phase 5 design Part 3](../cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md).
- The Stage 4 LRU eviction policy with protected roots remains active as the residency selector.
- The default legacy cache path remains unchanged when hybrid mode is disabled.

## In scope

- Define the `server_cache_store_cold` component: versioned filesystem-based payload store, disabled unless an explicit root path is configured.
- Define the cold store file format: file layout, version field, integrity checksums, and metadata fields needed for reload.
- Define atomic write and rename semantics for cold file creation.
- Define the `server_cache_io_worker` component: a background thread that handles demotion writes and promotion reads without blocking `server_context`.
- Define the hot-to-cold demotion protocol: which residency policy triggers demotion, how the descriptor transitions to `cold`, how the worker is notified, and how completion or failure is reported back.
- Define the cold-to-hot promotion protocol: how a cache miss or restore request triggers promotion, how the worker reads and validates the cold file, and how the descriptor transitions to `hot` on success.
- Define target/draft pair rules for cold transitions: both sides must be demoted and promoted as one unit.
- Define startup validation for the cold store root path and cold store budget, including diagnostic failures for invalid configurations.
- Define the residency policy: when payloads are candidates for demotion and when cold payloads are eligible for promotion.
- Define metrics: `cache_payload_promotions_total`, `cache_payload_demotions_total`, and cold restore latency.

## Out of scope

- Branch graph topology, metadata-only nodes, branch pruning, or re-materialization.
- Checkpoint payloads as first-class branch nodes.
- New eviction policy selection beyond the Stage 4 LRU policy.
- Separate cold-layer budget distinct from `--cache-ram`. A separate cold budget may be added if later implementation evidence shows a need, but Stage 6 does not require it.
- Cross-server or distributed cache coherence.
- Cold-layer restore guarantees across server restarts. Cold files written during a server session may persist on disk, but the design does not guarantee that a future server start will accept them as valid restore sources unless the format version and checksums are compatible.
- Implementation plan, code changes, or test scripts.

## Assumptions

- Stage 5 descriptor fields `store_ref` and `residency_state` are already schema-stable. Stage 6 reuses them without changing the descriptor schema version, unless implementation evidence shows an incompatible extension is needed.
- Cold file content is not shared across processes. Integrity is enforced by checksums and version tags, not by locking or access control beyond filesystem permissions.
- The filesystem on which the cold store root resides supports atomic rename at the directory level. On most POSIX-compatible and Windows filesystems this is true within a single volume. Cross-volume rename is not required.
- Integrity validation on promotion uses the same checksum algorithm chosen for Stage 5 descriptors. The algorithm identifier is stored in each cold file header so future changes do not silently break older files.
- The `server_context` thread remains single-threaded. The I/O worker runs on a separate thread. Communication between them uses a bounded work queue and explicit completion or failure notifications, not shared mutable descriptor state without locks.
- Cold store root path is operator-supplied. The design does not derive a default cold path from any runtime location, model path, or temporary directory.
- If the cold store root is not configured, the system is a strict superset of Stage 5 behavior. No new paths that assume cold availability are exercised.
