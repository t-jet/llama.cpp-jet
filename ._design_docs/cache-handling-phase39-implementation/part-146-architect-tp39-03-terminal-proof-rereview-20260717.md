VERDICT: REWORK

# Part 146: Architect TP-39-03 terminal proof re-review

Date: 2026-07-17
Scope: Part 144 finding F142-02 after Part 145

## Review basis

Reviewed Parts 141, 144, and 145, the active fix report, test-plan Part 43,
the guarded apply and authenticated retrieval paths, the canonical PowerShell
driver, and its pure self-tests. Parser validation and preflight-free
PowerShell 7 and Windows PowerShell 5 self-tests passed. No model, build,
coverage, product, fixture, seam, or test-plan command ran.

## Finding disposition

| Finding | Result | Evidence |
| --- | --- | --- |
| F142-01 | CLOSED | The guarded linked proof expands the source owner to ordered exact and checkpoint rows. The binding request sends both concrete IDs. |
| F142-02 | OPEN | Raw transport comparison, consumption, successful terminal assertions, and artifact redaction are present. Pure regression coverage does not reject several terminal assertion groups or any credential leak. |
| F142-03 | CLOSED | The second-owner negative uses distinct payload and owner IDs and reaches source-count rejection. |

## Checks that passed

- Apply response bytes are read before parsing. The driver extracts the embedded
  `prepared_proof` object directly from those bytes. Authenticated retrieval
  returns the same stored JSON object as the response body, and the driver
  compares the two byte arrays without object reserialization.
- Apply is already consumed on success. The driver replays the original apply
  request and requires rejection containing `consumed`.
- The success assertion covers session, run, process, HMAC, ordered bindings,
  generation chain, serialized sizes, staging sizes, entry and branch state,
  exact descriptor/file/byte-map accounting, checkpoint eviction and link
  observations, cold and staging inventories, topology, exact decision and
  transaction cardinality, diagnostics, and the complete forbidden-effect map.
- Saved apply and retrieval artifacts replace `terminal_hmac`; the apply request
  artifact replaces snapshot and proof tokens. The live log assertion rejects
  all three secrets.

## F146-01: pure terminal negatives are incomplete

Blocking. The pure matrix has meaningful negatives for retrieval consumption,
retry rejection, raw-byte drift, decisions, transactions, diagnostics, one
byte-map field, one forbidden observation, and one forbidden effect. It never
mutates terminal identity or status, generation order, prepared records,
entry/branch state, exact cold inventory, staging inventory, topology, the
checkpoint link, or the log. In particular, the only pure redaction call uses
an empty log, so removing the live secret-leak checks would leave both shell
self-tests green.

Part 144 required one rejecting mutation for each terminal assertion group.
Add focused mutations for the missing groups, including a nonempty log case for
snapshot token, proof token, and terminal HMAC. Keep each case isolated and
restore the fixture in `finally`. Both shells must reject every mutation before
the self-test may report PASS.

## Scope confirmation

Part 141 remains bounded to the canonical PowerShell driver and pure self-tests.
Its one-source/one-incoming workload, no slot erase, strict request schema,
checked formulas, positive budgets, six-chat cap, 20-minute cap, 16-GiB RSS cap,
and 4-GiB cold-root cap remain correct.

## Gate

F142-02 remains open through F146-01. Canonical TP-39-03 and coverage remain
blocked. Developer owns the pure terminal-negative correction; fresh Architect
re-review follows.
