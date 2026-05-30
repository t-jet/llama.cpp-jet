# Phase 6 design: cold layer and asynchronous I/O - Part 7: Exclusions, risks, and review readiness

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Exclusions and deferred work

Stage 6 does not include:

- Branch graph nodes, namespace traversal, branch-metadata budget, or branch pruning. These are Stage 7 and Stage 8 work.
- Metadata-only branch nodes or re-materialization from retained ancestors. These are Stage 8 work.
- Checkpoint payloads as first-class branch node references. This is Stage 9 work.
- A configurable cold-layer byte budget (`--cache-cold-budget`). The design defers this option until implementation evidence shows that operators need it. If the evidence arrives during Stage 6 implementation, the option should be added with startup validation and documented in Part 2. If not, it remains deferred to a later revision.
- Cold-layer restore guarantees across server restarts. Cold files written during a server session may persist on disk. A future server start may or may not be able to use them depending on format version compatibility and checksum validity. Stage 6 does not define a startup scan that indexes cold files automatically.
- Cross-process or distributed cache coherence.
- Workload profiles or checkpoint-first restore planning. These are Stage 9 work.
- Operator documentation. This is Stage 10 work.
- A full OWASP security review. Stage 6 defines security constraints on cold file path handling and integrity validation (see security notes below). The comprehensive security review is Stage 10 work.
- Performance benchmarks. Stage 10 requires a benchmark suite. Stage 6 defines the metrics required to support it.
- An implementation plan, code changes, or test scripts.

## Security notes

The following security constraints apply to Stage 6 design and must be carried into any implementation.

Cold file path construction: file paths for cold payloads must be derived exclusively from `payload_id` using a path-safe encoding (hex or base64url). No user-supplied content, model name, request text, or any other externally influenced value may appear in cold file names or directory structure.

Cold store root path: the root path comes from operator configuration only. The implementation must reject any path that contains traversal sequences, that resolves outside the configured root, or that resolves to a system directory. Path normalization must happen at startup, not at each file operation.

Cold file validation: cold files are read back and validated against checksums and the in-memory descriptor before any payload bytes are used. The implementation must not trust cold file content before this validation passes.

Log sanitization: log messages must not include cold file absolute paths beyond the store root, payload bytes, checksums treated as sensitive, or request content.

Privilege boundaries: the cold store root directory should be accessible only to the server process user. The design does not define access control enforcement, but the startup check should warn if the directory is world-writable.

## Known risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Filesystem permission errors at runtime after startup passes | Medium | Treat each write and read failure as a non-retryable demotion or promotion failure; emit diagnostic; revert or evict; do not crash. |
| Partial write leaves corrupt staging file | Low | Atomic rename ensures only complete files become visible at their final paths. Staging files that are never renamed are orphaned and do not affect correctness. |
| Worker thread shutdown race leaves staging file on disk | Low | Worker completes in-progress task before joining. Cancelled queued tasks receive a failure callback. The controller never promotes from a staging path. |
| Hot byte release before cold write confirms | Medium | Described in Part 3. Controller must not release hot bytes before the completion callback confirms the cold write. If the controller cannot hold bytes until completion, it must mark the descriptor `evicted` on failure rather than `hot`. |
| Descriptor state left ambiguous after worker cancellation | Low | Cancelled demotion: revert to `hot` if bytes held, or `evicted` if bytes released. Cancelled promotion: remain `cold`. Both transitions must be explicit in the implementation. |
| Cold file accumulation fills disk | Medium | No automatic cold budget in Stage 6. Operator must monitor cold store size. Startup check verifies write access but not available space. A future `--cache-cold-budget` option addresses this risk if evidence shows it is needed. |
| Stale cold files persist after descriptor eviction | Low | Controller must call `server_cache_store_cold::remove` when a cold descriptor transitions to `evicted`. The implementation must not rely on garbage collection or cleanup scans as the primary removal mechanism. |
| Promotion latency causes request queue buildup | Medium | `server_context` falls back to the slower path immediately on promotion enqueue. Requests do not wait for promotion. Latency accumulates only in cold restore latency metrics, not in request latency. |
| Incompatible cold files from a different server build | Low | Format version field and magic bytes ensure detection. Version mismatch transitions the descriptor to `evicted` and emits a diagnostic. |
| `payload_id` collision between server sessions | Very low | `payload_id` is stable within a session. Across restarts, cold files from a previous session carry their own `payload_id` values. If a new session produces a conflicting `payload_id`, the new file will overwrite the old at the final path. The header checksum and `payload_id` field on the old file will not match the new descriptor, preventing a silent incorrect restore. |

## Design decisions

The following design decisions are recorded for review.

1. Cold layer disabled by default. No cold I/O is introduced unless the operator provides `--cache-cold-path`. This preserves Stage 5 behavior exactly when unconfigured.
2. Single worker thread. One background thread simplifies locking and avoids contention on the cold store. Multiple workers may be considered if implementation evidence shows single-thread throughput is insufficient, but that is a later revision.
3. Atomic rename for persistence. Staging file plus rename ensures that a reader never sees a partial file at the indexed path. This is the simplest atomicity guarantee available on POSIX and Windows filesystems within a single volume.
4. No separate cold budget in Stage 6. Deferred until implementation evidence shows operators need it. The design records this decision explicitly so a future revision can add it without reopening the cold file format.
5. Fallback on promotion queue full. The controller does not block. The request falls back. This keeps `server_context` latency bounded at the cost of a miss. This is consistent with the Stage 3 and Stage 5 fallback contracts.
6. Cold file format is self-describing. The file header carries version, checksum algorithm, sizes, and checksums. This makes the format independently inspectable and forward-compatible without requiring a separate manifest.
7. Pair transition atomicity. Target and draft bytes are written to the same cold file. There is no scenario where one side is cold and the other is hot. This is a direct extension of the Stage 5 pairing invariant.

## Review readiness

This document set is ready for independent design review if the reviewer confirms:

- Stage 5 closure is accepted as the prerequisite.
- Stage 6 scope is limited to cold storage, asynchronous I/O, and related residency policy.
- No implementation plan or code change is embedded.
- Cold file format covers version, magic, checksum algorithm, sizes, per-side checksums, and a header checksum.
- Atomic write/rename semantics are explicit.
- Worker thread model, queue contract, locking model, and shutdown race are specified.
- Completion callbacks and failure handling for demotion and promotion are explicit.
- Target/draft pairing is enforced across cold transitions.
- Startup validation failures, integrity check failures, and demotion/promotion failure modes are explicit.
- Metrics cover promotions, demotions, cold evictions, cold restore latency, and byte/count gauges.
- Test hooks and fault injection points are defined for isolated testing.
- Requirements R7, R9, R10, R37, R93 (partial), R97, R102, R104, R112, R120, R121, R122, R125, R127, and R128 are addressed.
- Deferred requirements are listed with explicit reasons.
- Security constraints on path construction, file validation, and logging are documented.

## Gate status

Status: Draft. Awaiting independent design review.

Open findings: none known. This is a new design document and has not yet been reviewed.
