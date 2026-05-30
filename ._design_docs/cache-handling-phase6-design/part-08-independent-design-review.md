# Phase 6 design: cold layer and asynchronous I/O - Part 8: Independent design review

Source: [../cache-handling-phase6-design.md](../cache-handling-phase6-design.md)

## Verdict: PASS

The Stage 6 design is complete and consistent. No blocking findings were identified. The design is
approved to proceed to implementation planning.

## Scope and gate status

- Prerequisite: Stage 5 design gate accepted per Part 10 of the Stage 5 design. Stage 5 closure
  confirmed in
  [part-01-scope-prerequisites-and-assumptions.md](part-01-scope-prerequisites-and-assumptions.md).
- Review scope: Stage 6 design parts 1 through 7, cross-checked against the Stage 5 descriptor
  and pairing contract, Stage 6 exit criteria in
  [cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md](../cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md),
  and requirements in cache-handling-requirements.md.
- Reviewer is independent. No implementation plan, code, or test scripts were produced.

## Verified items

### Stage 5 continuity

- `PayloadDescriptor` fields (`payload_id`, `pair_state`, `format_version`, `residency_state`,
  `store_ref`, target/draft checksum fields, byte-size fields) are correctly referenced in Part 1
  prerequisites. No descriptor fields are redefined or contradicted.
- The reserved `cold` residency state from Stage 5 Part 3 is now activated under explicit Stage 6
  rules. The transition `hot -> cold -> evicted` is consistent with Stage 5
  reserving-but-rejecting `cold`.
- `store_ref` is treated as the Stage 5 abstract handle extended to hold a `cold_ref`. Part 2
  explicitly handles the case where the Stage 5 implementation used a concrete hot-RAM pointer
  type, requiring a descriptor format version increment if so.

### Required components

- `server_cache_store_cold`: interface operations, cold file format, and configuration defined in
  Part 2.
- `server_cache_io_worker`: interface operations, queue model, thread lifecycle, and locking model
  defined in Parts 2 and 4.
- Cold descriptor format: all required fields (magic, format_version, checksum_algorithm,
  payload_id, pair_state, sizes, per-side checksums, header_checksum) are present in Part 2.

### Locking model and thread safety

- Part 4 locking table explicitly assigns lock scope per resource (work queue, descriptor registry,
  hot store, cold files).
- The `server_context` thread is prohibited from blocking on cold I/O, a full queue, or the worker
  join.
- Both completion models (result queue drained at scheduling points; per-descriptor lock with
  cross-thread callback) are documented. The implementation must choose one and document it.

### Atomic write and rename

- Part 3 specifies the staging-path-then-rename protocol.
- Orphaned staging files are acknowledged and excluded from indexing.
- Final path derivation from `payload_id` via path-safe encoding is explicit.

### Target/draft pairing across cold transitions

- Parts 3 and 4 require both sides to move together. Target and draft bytes are written to the same
  cold file. No partial demotion or partial promotion is permitted.
- Part 7 Decision 7 records this as an explicit design decision.
- Part 6 fault injection includes draft-side promotion failure for `target_and_draft` descriptors.

### Startup validation

- Part 5 startup validation table lists five required checks with "log diagnostic and abort server
  startup" as the failure behavior for each.

### Integrity validation

- Part 3 lists ten ordered checks performed on promotion read, from magic through per-side
  checksums.
- Part 5 has separate handling sections for checksum mismatch and format version mismatch, each
  with required log fields, metric updates, and cold file disposition.

### Metrics

- Part 5 defines counters (demotions, promotions, cold evictions), a latency histogram
  (`cache_cold_restore_latency_seconds`), and gauges (cold payload bytes, hot payload count, cold
  payload count).
- Existing Stage 4 and Stage 5 metrics are correctly extended rather than duplicated.

### Hidden decisions

- Part 7 records seven numbered design decisions. No decisions were found only in prose without
  explicit recording.

### Stage 6 exit criteria

All six exit criteria from the architecture document are addressed:

- Payloads can be offloaded and restored on demand: demotion and promotion protocols in Part 3.
- Cold I/O is asynchronous: worker model in Part 4; `server_context` blocking prohibited.
- Integrity checks protect against corruption: validation in Parts 3 and 5.
- Budgets configurable without unnecessary upstream CLI change: `--cache-cold-path` in Part 2.
- Startup validation rejects invalid configurations: Part 5 startup table.
- Target/draft pairing preserved across cold transitions: Part 3 pair handling.

### No scope creep

- Branch graph, namespace traversal, metadata-only nodes, re-materialization, checkpoints, and
  workload profiles are all excluded in Part 1 and Part 7 with explicit stage references.

### No embedded implementation plan or code

- No code fragments, task breakdowns, or sprint assignments appear in any part file.

### Test hooks and fault injection

- Part 6 defines five test hooks (injectable store backend, delay, queue capacity override,
  promotion failure injection, direct residency query).
- Part 6 defines ten fault injection points covering all major failure modes.

### Security constraints

- Part 7 security notes cover: path derivation from `payload_id` only, no user-supplied content
  in paths, traversal sequence rejection, path normalization at startup, log sanitization, and
  world-writable directory warning.

### Demotion and promotion failure handling

- Part 5 has explicit failure tables for both demotion and promotion with required behavior per
  failure mode.
- The ordering constraint (hot bytes must not be released before the cold write confirms) is stated
  in Part 3 with an explicit implementation contract requirement.

### Worker shutdown race

- Part 4 specifies: in-progress task completes before join; queued tasks receive cancelled
  callbacks; cancelled demotion reverts to `hot` if bytes held or `evicted` if bytes released;
  cancelled promotion leaves descriptor `cold`.

### Requirement traceability

- Part 6 traces R7, R9, R10, R37, R93 (partial), R97, R102, R104, R112, R120, R121, R122, R125,
  R127, and R128. Deferred requirements are listed with stage assignments.

## Non-blocking observations

None of these block the design gate. They are recorded for implementation planning.

### NB-1: Transient states not formalized in the Part 2 state model

Part 3 introduces `demoting` and `promoting` as internal transient states. Part 2 defines only the
externally visible states (`hot`, `cold`, `evicted`). The full state machine including transient
states should be documented in the implementation to prevent ambiguity about descriptor access
during transitions.

### NB-2: Promotion and demotion protocols set transient state before the enqueue attempt

Part 3 sets the descriptor to the `promoting` transient state (step 2) before the enqueue attempt
(step 3). Part 5 states that a queue-full failure leaves the descriptor `cold`, which implies an
implicit revert of the transient state. The same pattern applies to the demotion protocol. The
implementation contract should make the revert explicit rather than requiring the reader to
reconcile Parts 3 and 5.

### NB-3: `cold_ref_for(payload_id)` use cases are not documented

`server_cache_store_cold::cold_ref_for(payload_id)` is listed as a required interface operation in
Part 2. Within Stage 6 scope the controller already holds `cold_ref` in `store_ref` for any cold
descriptor. The documented scenarios (promotion, removal) do not require a separate lookup by
`payload_id`. The implementation should document the specific use case that requires this operation
or remove it if unused.

### NB-4: Completion callback model choice deferred

Part 4 permits two completion callback models and defers the choice to implementation. This is
acceptable at the design gate. The implementation must document the chosen model and ensure the
locking guarantees for descriptor state mutations are consistent with that choice.

### NB-5: Hot byte ownership transfer timing

Part 3 demotion failure handling distinguishes two cases based on whether hot bytes have been
released before the failure. The point in the demotion protocol at which the controller releases
hot bytes is not pinned to a specific step number. The implementation must document exactly when
byte release occurs relative to enqueue and the completion callback.

## Decisions on the five flagged items

### 1. Cold budget deferral (no `--cache-cold-budget`)

Acceptable. The architecture document explicitly defers a separate cold budget until implementation
evidence shows operators need it. Part 7 records this decision and identifies the evidence
condition that would trigger adding it. No gap at the design gate.

### 2. `store_ref` schema compatibility (Stage 5 to Stage 6)

Acceptable at the design gate. Part 2 correctly identifies the two possible outcomes (no schema
change if `store_ref` is already abstract; descriptor format version increment if it is a concrete
pointer type) and requires the implementation to determine which applies. This must be resolved and
recorded at the start of Stage 6 implementation, not deferred further into the stage.

### 3. Single worker thread assumption

Acceptable for the initial design gate. Part 7 Decision 2 records the assumption explicitly and
provides the evidence condition for relaxing it. The locking model is simpler because of this
choice. No blocking concern.

### 4. Cold file retention after integrity failure

Correct default. Retaining the cold file preserves evidence for operator inspection and post-mortem
analysis. Part 5 specifies that deletion must not be the default and that any removal must be
logged. This is the right operational posture.

### 5. Cross-restart cold file reuse exclusion

Correct. The design explicitly excludes cold-layer restore guarantees across server restarts. Part 7
acknowledges the `payload_id` collision risk and documents that magic bytes, format version, and
checksum validation prevent a silent incorrect restore even if a stale cold file is encountered.
No gap.

## Required corrections before implementation

None. The design is approved to proceed to implementation planning without corrections.

## Implementation planning prerequisites

The implementation plan must address the following before implementation work begins:

- Document the chosen completion callback model (NB-4).
- Document the full descriptor state machine including `demoting` and `promoting` transient states
  (NB-1).
- Resolve the `store_ref` abstraction question and record whether a descriptor format version
  increment is needed (flagged decision 2).
- Make the transient-state revert on queue-full explicit in the demotion and promotion protocol
  implementations (NB-2).
- Pin the hot-byte ownership transfer point in the demotion implementation contract (NB-5).
- Justify or remove `cold_ref_for(payload_id)` (NB-3).

Date: May 30, 2026
