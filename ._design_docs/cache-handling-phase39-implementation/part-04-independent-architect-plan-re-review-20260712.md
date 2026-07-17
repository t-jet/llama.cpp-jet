# Part 4: independent Architect implementation-plan re-review

Date: 2026-07-12
Verdict: REWORK REQUIRED

## Scope

Reviewed the approved Stage 39 design, Manager design gate, implementation
Parts 1 through 3, and the current cold-store, I/O-worker, controller, stats,
exporter, and test surfaces. F39-IPR-01 is closed. F39-IPR-02 and F39-IPR-03
remain open as narrowed below.

## Finding closure

### F39-IPR-01: closed

Part 1 places the durable `committed` marker before descriptor apply and hot
release. Pre-commit rollback retains hot bytes and restores quarantined victims.
Post-commit completion retains the published incoming file. The listed failure
points cover the required mutation boundaries, so no boundary intentionally
deletes the last payload copy.

### F39-IPR-02: open

The physical-byte equation does not describe each transaction state. Part 1
defines `F = C - V + S` only after publish, but then applies
`P = F + T + R` "at every state." Before publish, final bytes are `C - V`,
staging is `S`, and quarantine is `V`, so physical bytes are `C + S`. Using the
written `F` before publish instead gives `C + 2S`. The exact-fit example asserts
the intended `C + S` peak, but the governing equation contradicts it.

Correction: provide a state table for prepared, each quarantine step,
published, committed, and cleaned. Define final, staging, quarantine, logical,
and total physical bytes in every row, including partial multi-victim progress.
Show the bound and checked arithmetic from those row equations.

Acceptance: the exact-fit, one-byte-over, cleanup-failure, and restart examples
derive directly from one unambiguous state model.

### F39-IPR-03: open

`server_cache_store_cold::recover_transactions()` cannot by itself complete
controller descriptor and logical-accounting state: the store does not own
`per_id_map`, hot records, or controller counters. Part 1 calls recovery before
worker wiring and reconciliation but does not define what recovery returns or
which controller API consumes committed manifests. Developer must still choose
the ownership and call contract for post-commit completion.

The TP matrix also uses `cold_room*`, alternative tuples, and slash-separated
recovery reasons. F39-IPR-03 required an exact metric and log tuple per row.
These placeholders leave fixture outcomes and expected series undecided.

Correction: define recovery-result records and the controller call that applies
or reconciles each committed transaction before ordinary cold reconciliation.
Replace every wildcard, alternative, and slash notation with named subcases and
one exact decision/transaction tuple per subcase. State which focused harness
captures logs for rows without a live test.

Acceptance: method ownership and startup order are implementable from fixed
signatures, and every TP-39 subcase has one production entry, test, tuple, log,
and artifact source.

## Regression checks

Plan still preserves lookup entries and branch nodes, keeps legacy and
`--cache-ram 0` behavior unchanged, uses exact closed-file size, and retains the
approved bounded public label domains. No new regression finding was found.

## Verdict and handoff

REWORK REQUIRED. Code and Manager implementation-plan gate remain blocked.
Developer must correct Part 1 for the narrowed F39-IPR-02 and F39-IPR-03, then
request another fresh Architect implementation-plan re-review.
