# Phase 6 design: cold layer and asynchronous I/O - Part 6: Testability and requirement traceability

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Exit criterion testability

Each exit criterion from the Stage 6 architecture definition is listed below with its testable check.

| Exit criterion | Testable check |
| --- | --- |
| Payloads can be offloaded to disk and restored on demand | Demote a hot descriptor, confirm `residency_state == cold` and a cold file exists, trigger a restore, confirm the descriptor returns to `hot` and the restore succeeds. |
| Cold I/O happens asynchronously without blocking `server_context` | Run a demotion or promotion while measuring `server_context` latency; confirm no blocking call to the cold store is made from the controller's request path. Use a fake store backend with configurable I/O delay to measure independently. |
| Integrity checks protect against corruption | Flip a byte in a cold file, trigger a promotion, confirm the descriptor moves to `evicted` and a checksum mismatch diagnostic is emitted. Truncate a cold file and confirm a similar hard failure. |
| Budgets are configurable and enforced without changing the upstream CLI | Start the server with a `--cache-cold-path` option, confirm hot budget still applies, confirm cold payloads accumulate without hot budget enforcement applying to them. |
| Startup validation rejects invalid budget configurations | Start with a non-existent or non-writable cold path, confirm the server exits with a diagnostic before accepting requests. |
| Target/draft pairing preserved across cold transitions | Save a `target_and_draft` descriptor, demote it, confirm both sides are in the cold file, promote it, confirm both sides restore correctly. Inject a failure on draft side during promotion and confirm the descriptor does not end up partially hot. |

## Test hooks for cold I/O simulation

The following test hooks must be available for focused testing without requiring disk I/O against a real filesystem.

| Hook | Purpose |
| --- | --- |
| Injectable `server_cache_store_cold` backend | Allow tests to substitute a fake in-memory cold store that records file operations without disk access. This supports testing the demotion and promotion protocols without filesystem side effects. |
| Configurable worker completion delay | Allow tests to inject a delay between task enqueue and callback to verify that `server_context` does not block during I/O. |
| Configurable queue capacity override | Allow tests to set the work queue capacity to 1 to exercise queue-full behavior. |
| Controlled promotion failure injection | Allow tests to configure the fake store to return failure on a specific `payload_id` or after a configurable count of successful operations. |
| Direct residency state query | Allow tests to read the current `residency_state` of a descriptor without going through the normal restore path. |

Test hooks must be available through the same in-process test interface used by Stage 5 focused tests. They must not require a separate process or HTTP endpoint.

## Fault injection points

| Fault | Location | Purpose |
| --- | --- | --- |
| Checksum corruption | Cold file byte flip before promotion | Confirm `evicted` transition and diagnostic emission. |
| Header truncation | Short-write in fake store | Confirm header checksum validation failure and no partial parse. |
| `payload_id` mismatch | Cold file written with wrong `payload_id` | Confirm rejection and diagnostic noting possible collision or corruption. |
| `pair_state` mismatch | Cold file with `target_only` for a `target_and_draft` descriptor | Confirm rejection and diagnostic. |
| format_version unknown | Cold file with version set to 255 | Confirm rejection without parsing payload. |
| Demotion write failure | Fake store returns OS error on write | Confirm descriptor reverts to `hot` or transitions to `evicted` depending on byte release order. |
| Queue full at demotion | Queue capacity 1 with two simultaneous demotions | Confirm second demotion fails fast and emits diagnostic. |
| Queue full at promotion | Queue capacity 1 with two simultaneous promotions | Confirm second promotion leaves descriptor `cold` and request falls back. |
| Worker thread shutdown race | `stop()` called while a task is in progress | Confirm in-progress task completes cleanly; queued tasks receive cancelled result. |
| Draft-side promotion failure for `target_and_draft` | Fake store returns success on target read but failure on draft checksum | Confirm no partial-hot state; descriptor transitions to `evicted`. |

## Requirement traceability

Requirements are drawn from [cache-handling-requirements.md](../cache-handling-requirements.md) as read from [part-01-status.md](../cache-handling-requirements/part-01-status.md) and [part-02-fully-slot-independent-shared-reuse.md](../cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md).

| Requirement | Coverage in Stage 6 | Disposition |
| --- | --- | --- |
| R7: usage-based hot or cold residency for full-state blobs | Demotion/promotion residency policy in Part 3 | Covered |
| R9: preserve target/draft coupling across offload and cold-layer operations | Pair handling in Part 3 | Covered |
| R10: never allow one side of a pair to be demoted or promoted independently | Pair rules in Parts 3 and 4 | Covered |
| R37: separate payload descriptors from payload bytes | Inherited from Stage 5; Stage 6 extends with cold residency | Covered |
| R93: configurable budget controls for hot payload RAM and cold-layer usage | `--cache-ram` for hot (Stage 4); `--cache-cold-path` enabling cold layer (Stage 6) | Covered; separate cold budget deferred (see Part 7) |
| R97: benchmarkable hot-to-cold and cold-to-hot transitions | Metrics `cache_payload_demotions_total`, `cache_payload_promotions_total`, latency histogram | Covered |
| R102: tests for cold offload and restore of full-state blobs | Exit criteria checks and fault injection in this part | Covered |
| R104: tests for target-plus-draft pairing across hot and cold transitions | Exit criterion and fault injection for paired cold transition | Covered |
| R112: cold-layer logic separated into coherent units | `server_cache_store_cold` and `server_cache_io_worker` as separate components | Covered |
| R120: fail safe; correctness over cache hit rate | Hard failure for any integrity check; no partial restore; fallback preserved | Covered |
| R121: explicit diagnostics for restore failures and integrity problems | Part 5 diagnostic requirements | Covered |
| R122: persistent formats versioned for forward evolution | Cold file format version field; `checksum_algorithm` field; reject unknown versions | Covered |
| R125: isolatable policy and residency policy testing | Injectable store backend; test hooks for residency queries | Covered |
| R127: storage-facing code designable for test substitution | Injectable `server_cache_store_cold` backend | Covered |
| R128: deterministic integration tests for cold offload and restore | Fake store with configurable behavior; direct residency state query | Covered |
| R132/R133: security review for cold-layer persistence and file handling | Security notes in Part 7; deferred full security review to Stage 10 | Partially covered; Stage 10 required for full review |

### Deferred requirements

| Requirement | Reason deferred | Stage |
| --- | --- | --- |
| R8: branch metadata resident in RAM even when payloads are cold | Branch metadata does not exist yet; Stage 6 has descriptors only | Stage 7 |
| R38a-R38c: payload demotion must not require branch pruning | No branch graph in Stage 6 | Stage 7/8 |
| R84-R86: checkpoint-dependent model behavior | Checkpoints not first-class in Stage 6 | Stage 9 |
| R93 (cold budget): configurable cold-layer byte limit | Deferred pending implementation evidence; see Part 7 | Possible Stage 6 revision or later |
| R107: 80% test coverage | Full coverage validation deferred to Stage 10 | Stage 10 |
