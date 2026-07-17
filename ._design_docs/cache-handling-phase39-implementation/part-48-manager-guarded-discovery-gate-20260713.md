# Stage 39 Manager guarded-discovery gate

Date: 2026-07-13
Verdict: PASS
Decision: D39-EXEC-03

Design Part 18 closes F39-GDR-RR-01. Parts 15 and 45-47 now define a guarded
`discover` and snapshot-bound `apply` flow that mirrors production selection,
keeps discovery non-mutating, and revalidates complete state before setup.

Developer rework is authorized. D39-EXEC-01 and D39-EXEC-02 still apply. The
route remains default-off, test-only, loopback-only, token-protected, idle-only,
and one-shot. Discovery must not change counters or consume the seam. Apply may
prepare state, but normal `tx_save` and `tx_update` paths own product decisions,
metrics, logs, and accounting. Public cache semantics and the 80 percent
coverage gate remain unchanged.

Next owner: Developer. Next gate: implementation rework, then fresh Architect
implementation re-review.
