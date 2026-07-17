VERDICT: REWORK

# Part 16: independent guarded discovery review

Date: 2026-07-13
Scope: design Part 15 and implementation Part 45 against implementation Parts
43-44, design Part 11, and current production code

## Gate result

Discovery is needed and its guarded route, admission-before-cache lock order,
retryable non-consuming behavior, snapshot-bound apply, redaction, terminal
one-shot mutation, and normal `tx_update()` handoff fit the accepted seam.
Parts 15 and 45 are not implementation-ready because two shared-selector
contracts contradict current code and the generation contract lacks a complete
mutation owner.

## Blocking findings

### F39-GDR-01: shared hot builder is not discovery-safe

Part 15 requires one shared hot builder and forbids discovery metric mutation.
Current `build_policy_candidates()` increments
`n_eviction_payload_blocked_refs` while enumerating entries at
`server-cache-hybrid.cpp:4464-4469`. Calling it from discovery, apply
validation, or response rebuilding would mutate observable state. Repeated
discovery would therefore not be non-mutating.

Correction must define a pure hot inventory builder. Production may record the
blocked-ref metric around that pure result, but discovery, validation, and
snapshot calls must not. Add a test that compares counters, LRU, generation,
descriptors, budgets, files, topology, and one-shot state across successful and
failed repeated discovery.

### F39-GDR-02: proposed cold predicate is not current production predicate

Current transaction room-making at `server-cache-hybrid.cpp:4978-4983`
accepts every cold descriptor whose `owner_entry_id` differs from the incoming
descriptor owner. It does not require a live entry or a kind-specific
`payload_id` / `checkpoint_payload_id` link. Part 15 adds that link as an
eligibility condition while saying production policy is unchanged. A shared
builder using Part 15 wording would narrow production behavior for a dangling
or mismatched descriptor.

Correction must choose and document one policy. Either preserve the current
production candidate predicate and make owner-link corruption a retryable,
non-consuming seam snapshot failure, or explicitly authorize a production
integrity-policy change with failure taxonomy, recovery, and regression tests.
Do not describe both as the same predicate. Healthy-state tests must prove
complete mixed `exact_blob` and `checkpoint` sets, per incoming owner,
including omitted and extra row rejection.

### F39-GDR-03: generation ownership is incomplete

Part 15 requires a monotonic generation change for every identity, owner,
residency, protection, slot-reference, pair, size, LRU, cold-rank, eligibility,
or budget change, including changed-then-restored state. Part 45 says only to
increment at every mutation. It does not identify mutation sites or how forest
slot-reference changes advance the controller generation. It also leaves the
opaque token construction and the singular response `generation` ambiguous
after apply changes state.

Correction must provide a mutation matrix or one centralized epoch owner that
covers controller transactions, completion/recovery changes, forest reference
changes, seam setup/rollback, and budgets. Specify process lifetime, nonce
entropy, token regeneration/comparison, and separate before/after generation
fields. Tests must cover stable repeated discovery, changed-then-restored
staleness, slot-reference drift, budget drift, token redaction, and after-state
generation.

## Evidence review

Part 45 correctly requires controller, route, driver, model smoke, OFF/ON,
PowerShell 5/7, forced merge failure, and coverage evidence. That evidence does
not exist yet: only `test_stage39_live_pressure_control_validation` is present,
the named Python route file is absent, and the canonical driver has no guarded
discover/apply flow. This is expected while code is blocked, but no later
implementation review may substitute planned evidence for executed artifacts.

## Handoff

REWORK. Architect or Developer documentation owner must correct Parts 15 and 45
for F39-GDR-01 through F39-GDR-03. Fresh independent Architect re-review follows.
Manager correction gate, code changes, QA, and Stage 39 closure remain blocked.
