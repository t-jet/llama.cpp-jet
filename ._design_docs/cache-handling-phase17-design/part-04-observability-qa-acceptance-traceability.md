# Stage 17 design: observability, QA, acceptance, and traceability -- Part 4

Source: [../cache-handling-phase17-design.md](../cache-handling-phase17-design.md)

## Observability

Stage 17 uses existing server logs and Prometheus metrics. It adds no cache HTTP
inspection endpoint.

Required metric families or equivalent existing-family extensions:

| Metric | Type | Required labels | Meaning |
| --- | --- | --- | --- |
| `cache_restore_misses_total` | Counter | `reason`, `profile`, `pair_state` | Restore lookup misses by bounded reason. |
| `cache_prompt_evidence_records_total` | Counter | `mode`, `result` | Prompt evidence records written or failed. |
| `cache_prefix_candidates_total` | Counter | `result`, `reason` | Prefix candidates accepted by policy or rejected. Stage 17 expected result is rejected unless future implementation adds safe prefix restore. |
| `cache_checkpoint_admissions_total` | Counter extension | `policy`, `result`, `reason` | Checkpoint admission under semantic or dense policy. |
| `cache_cold_bytes` | Gauge | none or bounded `state` | Cold payload bytes currently owned by live descriptors. |
| `cache_cold_budget_bytes` | Gauge | none | Configured cold budget bytes, with `-1` represented by documented unlimited value or separate state metric. |
| `cache_cold_evictions_total` | Counter | `reason`, `payload_kind` | Cold payload eviction due to cold-byte pressure or cleanup. |
| `cache_cold_demotions_skipped_total` | Counter | `reason`, `payload_kind` | Demotions skipped before filesystem write. |

Metric labels must not include prompt text, raw paths, raw namespace values, raw
descriptor ids, or free-form marker labels.

## Diagnostic lines

Bounded diagnostic lines must be available for:

- restore miss reason classification
- prompt evidence mode and write failure
- prefix candidate rejection
- checkpoint admission skipped by semantic policy
- cold budget startup validation
- cold eviction and skipped demotion
- orphan staging cleanup

Diagnostics should carry preparation id or redacted hashes only.

## Testability

Focused tests should cover:

- each restore-miss reason enum
- raw evidence disabled unless explicitly configured
- redacted evidence contains no prompt text
- first-user boundary and boundary count recording
- prefix candidate found but rejected as unsafe
- exact repeat still restores through exact path
- semantic checkpoint policy skips dense optional checkpoints
- checkpoint-dependent or MTP exception keeps required checkpoints
- cold budget values `0`, positive, and `-1`
- cold startup validation and orphan staging cleanup
- cold eviction before demotion write
- target/draft pair integrity when cold budget blocks one side
- metric label allowlist for prompt and path leakage

## QA plan hooks

Stage 17 test-plan work should add rows in three tiers.

| Tier | Rows | Required coverage |
| --- | --- | --- |
| Synthetic agentic prompts | 12k, 24k, and 60k generated chat prompts; exact repeat; new user turn; same branch continuation; different agent with same system/tool prefix | `cache_n`, miss reason, namespace hash, token count, boundary count, first-user boundary, checksum, checkpoint create/skip counts |
| Stress-longrun extension | Stage 12/15 S and L framework with agentic prompt generator, cold pressure, branch forest growth, mixed exact and near-prefix requests | no crash, no corrupt restore, bounded miss reasons, cold bytes under budget, skipped demotions before write failure |
| Heavy manual or nightly | Qwen3.6-27B-MTP, near-60k prompts, cold path, 8 GiB hot cache, bounded cold budget, several-hour run | reproduce or refute Stage 16 log class; compare exact repeats, new user turns, cold pressure, host allocation failures |

The synthetic tier runs often. The heavy tier is not a normal PR gate.

## Acceptance criteria

Stage 17 design is acceptable when:

- restore misses have bounded, documented reasons
- prompt identity evidence has raw and redacted modes
- exact restore remains the only required restore implementation for this
  stage, and prefix restore is explicitly deferred behind safety checks
- cold storage has a disk budget with `0`, positive, and `-1` semantics
- startup validation, cold-byte accounting, eviction, skipped demotion, and
  orphan staging cleanup are specified
- checkpoint-density policy uses semantic branch points while preserving
  checkpoint-dependent and MTP correctness
- QA hooks cover synthetic, stress-longrun, and heavy reproduction paths
- requirement traceability is explicit
- each document stays under 300 lines

## Requirement traceability

| Requirement | Stage 17 disposition |
| --- | --- |
| R4a, R5, R15-R17 | Covered. Exact restore remains supported and non-destructive. |
| R6, R12, R84-R86 | Covered. Checkpoint-dependent and MTP modes keep checkpoint-safe continuity. |
| R7, R49-R60, R93 | Covered. Cold storage gains explicit disk budget and byte accounting. |
| R8, R38a-R38c, R71a-R71e, R79a-R79b | Covered. Cold eviction preserves payload/pruning distinction and metadata-only topology. |
| R9, R10, R52 | Covered. Cold budget and restore policy preserve target/draft pairing. |
| R14, R34-R36d, R90-R92, R120-R124 | Covered. Unsafe exact, prefix, payload, or checkpoint candidates fall back safely with diagnostics. |
| R21, R21a, R57a-R57e | Covered. Hot, cold, and metadata budgets remain separate and policy-visible. |
| R27-R33 | Covered through prepared metadata fields, first-user boundary, and Stage 16 prompt-span invariant. |
| R37-R48 | Covered. Evidence and cold policy use descriptors, token spans, checksums, usage, and residency state. |
| R61-R68 | Covered. Restore misses, checkpoint admissions, cold transitions, evictions, and fallback reasons are observable. |
| R69-R83a | Constrained. Prefix policy uses branch graph semantics but does not implement new prefix restore in Stage 17. |
| R87-R89 | Constrained. Unsupported multimodal prefix reuse must fail explicitly. |
| R94-R98 | Covered for future benchmark evidence through exact hit rate, checkpoint admission, cold transitions, and prompt savings fields. |
| R99-R106, R125-R129 | Covered through focused and QA plan hooks. |
| R107-R119, R130-R131 | Covered by scoped controller/evidence interfaces and no legacy path changes. |
| R132-R133 | Covered for prompt evidence and cold filesystem handling; full implementation still needs security review before closure. |

## Handoff state

Ready for independent design review. Open review questions for the next gate:

- Is `--cache-cold-max-mib` the accepted CLI name, or should implementation use
  an existing cold-budget naming convention?
- Should redacted evidence write JSONL, per-request JSON, or both?
- Should Stage 17 implementation stop at evidence plus policy, or should
  Manager open a later stage for safe prefix restore implementation?
