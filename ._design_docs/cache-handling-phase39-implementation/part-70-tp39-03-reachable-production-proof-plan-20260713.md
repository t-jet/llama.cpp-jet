# Part 70: TP-39-03 reachable production proof plan

Date: 2026-07-13
Status: REVIEWED REWORK IN DESIGN PART 30
Authority: D39-EXEC-09 and design Part 29

## Planned correction

1. Add a compile-time and runtime guarded read-only proof response under the
   existing admission latch and cache lock. Reuse descriptor, header, cold byte
   map, filesystem, generation, and runtime-pair validators without promotion
   or mutation.
2. Return the bounded fields in design Part 29. Reject stale process/generation,
   missing components, overflow, and every descriptor/header/file mismatch.
   Keep paths, content, tokens, nonce, credentials, and HMAC inputs redacted.
3. Extend driver evidence records so every `R_exact`, `R_checkpoint`, `S_exact`,
   and `S_checkpoint` binds pass, process, workload role, request number,
   pressure step, kind, payload, owner, generation, runtime predicates, and
   normal demotion evidence.
4. Keep measurement fresh and production-only. Use ordinary pressure to produce
   real cold exact and checkpoint objects, then reconcile proof response, final
   headers, descriptor fields, cold byte map, filesystem lengths, totals, and
   staging/quarantine inventory.
5. Replace only live TP-39-03 owner setup with
   `tp39_03_setup:"same_owner_kind_sequence"`. Reject owner-move fields in this
   mode. Require one owner with hot exact plus hot checkpoint and empty cold.
6. Apply only lowers checked positive budgets and hot order, consumes once, and
   invokes one ordinary `tx_update()`. It does not change ownership, links,
   residency, files, counters, or decisions before production pressure.
7. Assert exact-first normal demotion, then checkpoint `evicted/both_filled`
   because the retained cold exact sibling is excluded by same owner. Require
   zero failed-checkpoint cold transaction, retained metadata/topology, zero
   pruning, exact decision cardinality, and file/byte reconciliation.
8. Preserve focused complete-set owner-reassignment, rollback, collision,
   security, and selector tests. Add focused proof-surface and natural
   same-owner transition tests plus route schema/redaction cases.

## Acceptance

- Proof operations are pure, non-consuming, process-bound, and default OFF.
- Measurement serialized bytes come only from normal demotion.
- Baseline to post-setup diff contains no payload, ownership, link, residency,
  file, accounting, metric, or decision change.
- One subsequent production `tx_update()` causes exact demotion and the decisive
  checkpoint `evicted/both_filled` outcome in exact-before-checkpoint order.
- Every resident and serialized input has complete role/kind/owner/generation/
  request/pressure provenance.

## Gate

Design Part 30 returns REWORK. Design Part 31 and implementation Part 71 are the
D39-EXEC-10 correction candidates for same-process serialized provenance and
exact named-test mapping. Manager acceptance remains required after fresh
review. This plan authorizes no implementation or execution.
