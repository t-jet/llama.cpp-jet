VERDICT: REWORK

# Part 142: Architect D39-QA-01 driver fix review

Date: 2026-07-17
Scope: Part 141, the D39-QA-01 fix report, and the TP-39-03 PowerShell correction

## Review basis

Reviewed test-plan Part 43, Parts 140-141, the fix report, the guarded route
schema and proof builder, the canonical PowerShell path, and its embedded pure
self-tests. No model, build, test, or coverage command ran.

## Findings

### F142-01: proof request cannot return both required kinds

Blocking. The canonical driver sends `payload_ids` with only the discovered
exact payload ID. `stage39_build_runtime_proof_locked()` emits one row for each
requested ID; it does not expand an exact ID to the owner's checkpoint. The
next helper requires two ordered rows, so every valid run stops with
`SKIP-preflight-tp39-03-proof-binding` before apply.

Correction: obtain the same owner's checkpoint payload ID from an approved
non-mutating surface, send both IDs in exact/checkpoint order, and keep the
snapshot, process, owner, kind, pair, component-size, checksum, and generation
checks fail closed. Do not infer or synthesize the checkpoint ID.

### F142-02: terminal prepared proof is not asserted

Blocking. A successful natural apply returns `prepared_proof`,
`test_session_id`, and `run_id`, but `Assert-Tp3903` checks none of them and
never performs authenticated `prepared_proof` retrieval. Part 43 binds the
canonical formulas and ordered production observations to the terminal HMAC
snapshot. The fix report's claim that terminal checks remain in place is not
supported by the script.

Correction: require the successful terminal proof, validate its session/run,
ordered exact/checkpoint bindings, process and generation chain, terminal HMAC,
accounting and state assertions, then retrieve it through the guarded operation
and require byte-equivalent authenticated content. Preserve token redaction.

### F142-03: second-owner negative is not meaningful

Blocking under Part 140's named pure-test contract. The first negative appends
the same hot row twice. It proves only count rejection, not rejection of a
second eligible owner.

Correction: append a distinct eligible exact row with a different nonzero
payload and owner plus its matching empty cold set. Require the same preflight
failure under PowerShell 7 and Windows PowerShell 5.

## Checks that passed

- Workload has one source request and one incoming request; TP-39-03 skips slot
  erase, retaining the incoming reference.
- Discovery requires exactly one eligible hot exact row and one empty cold set.
- Request schema uses `same_owner_kind_sequence`, two `prepared_bindings`, and
  excludes historical owner-move and cold-rank fields.
- Checked formulas implement `H_low = R_exact` and
  `C_low = max(S_exact, S_checkpoint)` with the 64-byte header and both strict
  upper bounds.
- Existing caps, snapshot-token redaction, exact decision/log checks, retained
  topology, cold file reconciliation, and artifact capture remain present.
- Missing/reordered kinds, owner drift, zero draft component, stale generation,
  missing/drifting process identity, nonempty cold, and historical-field tests
  execute a rejecting helper rather than a tautology.

## Gate

Developer rework required. Manager must not authorize canonical TP-39-03 or
coverage execution. Fresh Architect re-review follows corrections to F142-01
through F142-03.
