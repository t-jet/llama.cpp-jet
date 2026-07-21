# Part 7: C5 architecture decisions

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

All decisions below are accepted and implemented unless stated otherwise.

## ADR-001: Keep hybrid cache opt-in

Context: Legacy prompt cache is established behavior and broad replacement would
increase regression risk.

Decision: Select `legacy` or `hybrid` through `--cache-mode` and a controller
factory. Default to legacy. Keep legacy implementation separate.

Consequences: Hybrid changes do not silently alter default behavior. Shared
interfaces must remain small enough for both controllers.

## ADR-002: Build prompt metadata after preparation

Context: Cache safety depends on rendered and tokenized boundaries. Raw request
JSON and heuristic rescanning cannot reliably describe model input positions.

Decision: Build token-indexed boundary metadata in prompt preparation and carry
it on `server_task` into `server_context`.

Consequences: Route adapters can provide their richest safe structure without
moving HTTP parsing into the cache. Missing structure becomes an explicit
degraded mode.

## ADR-003: Use a shared branch forest

Context: Flat, slot-owned entries cannot preserve reusable roots across several
slots and branches.

Decision: Store namespace topology, token spans, checksums, usage, protection,
and slot references in `branch_forest_index`. Entries link payload ownership to
forest nodes.

Consequences: Slots can share immutable saved state. Topology and payload
lifecycle require separate accounting and cleanup rules.

## ADR-004: Separate namespace partitioning from prompt validation

Context: Including prompt-local boundaries and checksums in namespace hashes
created one namespace per prompt and prevented legitimate reuse.

Decision: Namespace uses stable runtime compatibility plus an optional stable
metadata compatibility key. Tokens, boundaries, checksums, and request-local
fields validate candidates after lookup.

Consequences: Compatible prompts share a bounded namespace. More candidates may
be inspected, so post-lookup validation is mandatory.

## ADR-005: Use profile-aware exact and checkpoint restore

Context: Plain transformers can reuse full state efficiently. SWA, recurrent,
hybrid, and MTP-like runtimes need checkpoint-safe restore points.

Decision: Detect workload profile from initialized runtime state. Prefer exact
blobs for plain transformers and checkpoints for checkpoint-dependent profiles.
Allow strict-prefix restore only at validated chat boundaries, with a
checkpoint-or-recompute rule for draft and checkpoint-dependent runtimes.

Consequences: `/completion` strict prefixes and any unproved prefix are reported
as `unsafe_prefix_rejected` and recomputed.

## ADR-006: Separate metadata from paired payload bytes

Context: Branch lookup data must remain cheap and available when large state
bytes move between storage tiers.

Decision: Keep descriptors in RAM and store target plus optional draft bytes in
hot or cold records. Pair state is binary, while namespace carries richer draft
mode identity.

Consequences: Target and draft save, validate, promote, restore, rollback, and
evict atomically. Exact and checkpoint descriptors can be ranked separately.

## ADR-007: Use byte-accounted LRU and protected preference

Context: FIFO and entry counts do not represent memory cost or likely reuse.

Decision: Use deterministic resident-byte LRU. Protected roots are lower-priority
victims but remain inside all budgets. Do not expose a policy selector until a
second policy exists.

Consequences: Large entries create proportionate pressure. Protection is a
preference, not an unlimited reservation.

## ADR-008: Separate payload eviction from branch pruning

Context: Deleting a payload does not always make its branch topology useless.
Removing an ancestor can make retained descendants unreachable.

Decision: Payload eviction leaves metadata-only nodes and evicted descriptor
tombstones. Prune metadata only under its own budget and only for safe leaves
without protection, references, or retained descendants.

Consequences: Re-materialization and mismatch-parent selection can use retained
topology. Payload and pruning metrics remain distinct.

## ADR-009: Serialize cache mutations, split live restore apply

Context: Background demotion and promotion exposed partially coordinated state.
Holding a global cache lock while applying llama state would block unrelated
slots for too long.

Decision: Run cache-state mutations synchronously under one recursive mutex.
Capture restore state under lock, apply to live contexts outside lock, and
finalize under lock.

Consequences: No worker thread or queue mutates cache state. Restore plans must
own deep copies, and apply must support complete rollback.

## ADR-010: Keep slow save reads outside the cache mutex

Context: Serializing model state can be slow enough to stall every slot.

Decision: Validate and dedupe under lock, read target/draft state outside lock,
then dedupe again before admission.

Consequences: Equivalent concurrent saves are idempotent. The second pass is a
required correctness step, not an optional optimization.

## ADR-011: Use a local versioned cold store

Context: RAM alone cannot retain branch-heavy working sets, but external cache
services would enlarge scope and trust boundaries.

Decision: Store versioned, checksummed payload files below one configured local
root. Use internal IDs for names. Do not promise cross-restart restore.

Consequences: Operators manage disk capacity and permissions. Corruption causes
recompute or mutation shutdown, never unchecked restore.

## ADR-012: Demote before capacity eviction

Context: Hot pressure previously discarded reusable bytes even when cold space
could retain them.

Decision: On hot pressure, stage the full pair, make cold room with deterministic
victims, and evict only when both enabled layers are capacity-exhausted. Keep
non-capacity failures hot.

Consequences: Cold room-making is a multi-file transaction. Accounting includes
serialized file overhead and quarantine bytes.

## ADR-013: Make cold room-making crash recoverable

Context: Deleting cold victims before incoming payload publication could lose
both old and new reusable state on failure.

Decision: Use a manifest, reversible victim quarantine, incoming publish,
durable commit marker, descriptor apply, and idempotent cleanup/recovery.

Consequences: Disk operations cost more but cannot silently create partial
ownership. Unknown manifests disable mutation.

## ADR-014: Preserve route schemas and bound observability

Context: Cache behavior must work through existing clients without introducing
unbounded labels or leaking prompt data.

Decision: Keep cache controls on server CLI. Preserve public route schemas. Use
fixed metric enums, aggregate namespace labels, bounded logs, and opt-in redacted
or raw evidence.

Consequences: Deep forensic data lives in internal stats or controlled evidence
files rather than public labels or response fields.

## ADR-015: Standardize Windows evidence on VS2022

Context: Repository build documentation requires Visual Studio 2022, while the
latest local Stage 39 runs used Visual Studio 2026. Toolset drift weakens the
claim that local evidence follows upstream build rules.

Decision: Require VS2022 Developer PowerShell and CMake generator
`Visual Studio 17 2022` for authoritative Windows build, test, and coverage
evidence. Keep `/Zi` and `/DEBUG:FULL` for coverage symbols.

Consequences: VS2026 remains acceptable for investigation only. Stage 39
behavioral evidence must be rerun on VS2022 before Windows build-environment
conformance is closed.
