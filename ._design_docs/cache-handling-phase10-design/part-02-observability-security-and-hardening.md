# Stage 10 design: observability, security, and hardening -- Part 2

Source: [../cache-handling-phase10-design.md](../cache-handling-phase10-design.md)

## Observability contract

Stage 10 must audit the existing hybrid metrics and fill any remaining gaps for
R61-R68. Metrics must use bounded labels and must not include prompt text,
request marker text, file paths, payload bytes, checksums, model paths, or
serialized state contents.

| Requirement | Required observable event |
| --- | --- |
| R62 | Exact blob hit attempts and accepted hits, with result, profile, pair state, and residency where useful. |
| R63 | Checkpoint restore attempts and accepted checkpoint hits, with result, profile, pair state, and residency. |
| R64 | Payload promotions from cold to hot, by payload kind, pair state, result, and reason. |
| R65 | Payload demotions from hot to cold, by payload kind, pair state, result, and reason. |
| R66 | Payload evictions, by payload kind, pair state, residency, and reason. |
| R66a | Branch pruning or node deletion, by node role, protection state, result, and reason. |
| R67 | Protected-root decisions, by decision, pressure source, result, and reason. |
| R68 | Fallback restores and restore failures, by restore strategy, payload kind, profile, result, and reason. |

Additional Stage 10 metrics must cover:

- unsupported or degraded configuration decisions
- descriptor integrity validation failures
- cache marker validation failures
- cold-store path or root validation failures at startup
- branch validation mismatch and metadata-only re-materialization outcomes
- hot, cold, and branch-metadata byte gauges
- cold-store operation latency and queue pressure
- benchmark counters needed to calculate exact hit rate, checkpoint hit rate,
  cold transition frequency, and prompt-processing savings

## Structured diagnostics

Stage 10 diagnostics must use the existing server logging style while carrying
machine-readable fields when the logging path supports them.

Required fields:

- event name
- hybrid mode enabled or disabled
- workload profile
- payload kind when relevant
- pair state
- residency state
- bounded reason enum
- result enum
- request route when useful and safe
- slot id or branch node id only if already non-sensitive in current logs

Diagnostics are required for:

- unsupported runtime shape or unsafe configuration combination
- cache marker rejected, ignored, or normalized
- candidate rejected by namespace, pair state, version, checksum, boundary, or
  descriptor owner validation
- cold-store root startup rejection or warning
- cold promotion, demotion, eviction, and cleanup failure
- protected-root budget pressure
- branch pruning and metadata-only retention decisions
- fallback path selection
- integrity violation and descriptor invalidation

## Security review scope

Stage 10 must record a focused OWASP review before implementation can close.
The review is scoped to functionality introduced by the hybrid cache.

| Category | Stage 10 review focus |
| --- | --- |
| A01 Broken access control | Cold-store root permissions, root containment, file ownership assumptions, and whether request-provided markers can influence protected cache state beyond allowed policy. |
| A03 Injection | Path traversal, log injection, metric-label injection, marker parsing, enum parsing, and any externally influenced strings used in diagnostics or namespace material. |
| A04 Insecure design | Fail-safe restore behavior, budget exhaustion, protection abuse, descriptor owner checks, target/draft atomicity, and unsupported multimodal or draft combinations. |
| A05 Security misconfiguration | Unsafe cold-store paths, impractical budgets, world-writable directories, stale startup configuration, and metrics/log settings that expose sensitive material. |
| A08 Software and data integrity failures | Descriptor version checks, checksum validation, payload kind validation, pair-state validation, cold file magic, staging-file handling, and cleanup ownership checks. |
| A09 Security logging and monitoring failures | Missing diagnostics for integrity failures, fallback paths, unsupported configurations, marker rejection, cold-store errors, and suspicious repeated validation failures. |

The review must classify each item as mitigated, accepted with rationale, or not
applicable. Any unmitigated item that can affect correctness, confidentiality, or
operator control blocks Stage 10 closure.

## Cold-store hardening

Cold-store hardening must carry forward Stage 6 constraints and add the missing
production checks.

Required behavior:

1. Normalize the configured root at startup and retain the canonical path.
2. Reject traversal, empty, relative-ambiguous, system-directory, and unsupported
   root paths before accepting requests.
3. Warn or reject according to platform support when the root is world-writable
   or writable by unintended users.
4. Derive payload file names only from internal payload identifiers using
   path-safe encoding.
5. Keep staging files under the normalized root and never promote from a staging
   path.
6. Before each file operation, prove the resolved path remains under the root.
7. Validate magic, format version, payload id, payload kind, pair state, sizes,
   and checksums before using bytes.
8. Treat invalid files as integrity failures with descriptor invalidation and
   safe fallback.
9. Remove cold files only after descriptor owner checks prove no retained branch
   or descendant owns them.
10. Sanitize all path diagnostics so operators see enough context to fix the
    issue without leaking request material or arbitrary filesystem paths.

## Descriptor and restore hardening

Stage 10 must require pre-restore validation for every payload kind:

- descriptor owner matches the selected branch node
- namespace, workload profile, pair state, and speculative-mode identity match
- payload kind is allowed by the selected restore plan
- hot or cold residency matches the selected operation
- size and checksum fields are present and within configured bounds
- metadata-only re-materialization validation passed for the selected path
- target and draft payloads are both available before paired restore begins

Any failure before live-state mutation falls back without changing live state.
Any failure after restore application begins must use the Stage 5 transactional
restore contract. A partial paired restore remains a blocking defect.

## Abuse and pressure handling

Stage 10 implementation planning must include tests or review evidence for:

- repeated invalid marker submissions
- budget values too small to retain a useful protected root
- hot budget exhaustion while cold storage is unavailable
- cold budget exhaustion if a cold byte budget exists
- branch-metadata budget exhaustion with protected roots
- large branch forests with metadata-only ancestors
- promotion queue pressure and worker shutdown while operations are pending
- repeated checksum or descriptor-version failures
- unsupported multimodal, draft, or workload-profile combinations

The cache must prefer recompute and explicit diagnostics over unsafe reuse.
