# Stage 25 design: Part 6: new invariants and architecture cross-reference

Source: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)

This part names the three new invariants that Stage 25 introduces,
records the architecture cross-reference, and lists the prior
invariants that Stage 25 preserves.

## New invariants

### I-25-01: atomicity

Every cache-state mutation that happens in response to a slot
request runs inside a single critical section that holds
`cache_state_mutex_` for the duration of the operation. Other
threads that need to mutate cache state block until the section
exits. The section includes demotion, eviction, new-entry
admission, cold restore, and owner-view sync.

Implementation contract:

- Each public mutation entry point acquires the mutex once at entry
  and releases once at exit.
- Each private helper that mutates cache state asserts the mutex is
  held by the caller (`tx_assert_mutex_held`).
- A reentrant call from inside a transaction is permitted only
  through the documented inner-call set (`tx_save -> tx_evict_entry`,
  `tx_restore -> tx_update`, `tx_update -> tx_evict_entry`).

### I-25-02: isolation

Parallel slot requests cannot observe partial transaction state. A
slot thread that begins a transaction sees a consistent snapshot of
`payload_descriptors`, `hot_payloads`, `entries`, and the cold store
that does not change until the section exits. Any other transaction
that began before the slot thread's transaction has either fully
committed or has not yet started.

Implementation contract:

- The mutex is exclusive. There is no shared-mode reader.
- The cold-store read on promote is inside the same critical section
  as the descriptor transition, so a parallel transaction that
  observes the descriptor sees either the pre-promote `cold`
  residency or the post-promote `hot` residency with bytes
  installed; never a transient state with descriptor `hot` and
  `hot_payloads` empty.

### I-25-03: durability within transaction

Cold-store writes commit (atomic write + rename) before the
transaction that initiated them returns. A slot thread that calls
`tx_demote_payload` and receives a successful return knows the cold
file is durable on disk and the descriptor has transitioned to
`cold` with bytes registered in `n_cold_payload_bytes`.

Implementation contract:

- The worker task that writes the cold file runs inline within the
  transaction. The transaction does not return until the rename
  succeeds.
- On rename failure the transaction reverts the descriptor to `hot`
  (or evicted if hot bytes are gone) and returns false. The slot
  thread observes the revert and falls back per existing Stage 17
  policy.
- The Stage 6 cold-store atomic-write + rename invariant is
  preserved; Stage 25 only moves when the write happens.

## Architecture cross-reference

The existing architecture entry doc
[cache-handling-architecture.md](../../cache-handling-architecture.md)
and its part files do not currently describe the async-vs-sync
distinction for cache mutations. Stage 25 introduces the
distinction as a new architecture invariant.

After Stage 25 closes, the architecture will gain a new part file:
`cache-handling-architecture/part-10-atomic-transaction-invariants.md`.
The new part file will:

- Document the atomicity, isolation, and durability invariants
  (I-25-01..03).
- Update the Part 2 restore and residency flow sequence diagram to
  show synchronous transactions instead of the async I/O worker.
- Update the Part 4 payload-eviction-vs-branch-pruning narrative to
  note that eviction is now synchronous and atomic with descriptor
  transitions.

The architecture update is out of scope for the design gate. It is
performed after Stage 25 implementation closes and the new behavior
is verified.

## Preserved prior invariants

Stage 25 preserves:

| ID | Invariant | Source |
| --- | --- | --- |
| F-21-EXEC-01 | prompt-only save/lookup keeps exact repeats as exact hits | Stage 21 |
| F-21-RERUN-01 | demoting payloads count against hot budget until hot bytes released | Stage 21 |
| F-22-DR-01 | `demote_payload` already-demoting check precedes generic non-hot rejection | Stage 22 |
| Stage 5 | target/draft payloads move as one descriptor-owned unit | Stage 5 |
| Stage 6 | cold I/O uses atomic write + rename; controller owns descriptor transition | Stage 6 |
| Stage 8 | payload eviction and branch pruning stay separate; metadata-only nodes valid only after ownership clear | Stage 8 |
| Stage 17 | cold-budget rejection leaves descriptor hot and does not produce partial cold residency | Stage 17 |
| Stage 22 | descriptor is source of truth for residency; entries and branch nodes derived views | Stage 22 |
| D-EXEC-24-01 | over-hot-budget skips demotion and falls through to immediate eviction | Stage 24 |
| D-EXEC-24-02 | token-limit loop guarantees progress by force-evicting one entry per iteration | Stage 24 |

The architecture-level invariant for chat-path prompt-span boundary
(Part 9) is preserved. The atomicity, isolation, and durability
invariants above are additions, not replacements.
