# Part 7: independent Architect design re-review

Date: 2026-07-12
Status: REWORK REQUIRED

## Scope

This review checks the Manager intake, design entry, Parts 1-3, the independent
review in Part 5, and the corrections in Part 6 against the cache requirements,
ADR-009, and current hybrid-cache pressure and startup paths.

## Finding closure

| Finding | Result | Basis |
| --- | --- | --- |
| F39-AR2-01 | CLOSED | Parts 1-2 select verified `--cache-ram 0` semantics: prompt caching and the controller are disabled. TP-39-05 fixes the expected startup and metric result. |
| F39-AR2-02 | CLOSED | Part 2 defines an immutable staged file, exact closed-file length, checked arithmetic, format overhead, and cleanup ownership. TP-39-13 covers each required boundary. |
| F39-AR2-03 | CLOSED | Part 2 defines same-directory quarantine, a manifest and commit marker, reverse rollback, pre/post-commit recovery, cleanup accounting, and failure injection at every mutation. TP-39-14 covers multi-victim and crash boundaries. |
| F39-AR2-04 | OPEN | Part 3 fixes metric families and result/reason values, but both public families also carry `mode`. No fixed `mode` value set is specified. Public label cardinality therefore remains partly delegated to implementation. |

## Advisory closure

| Part 5 advisory | Result |
| --- | --- |
| Multi-victim order and partial failure | CLOSED: existing rank plus payload ID is deterministic; TP-39-14 covers every victim position. |
| Descriptor lifecycle terminology | CLOSED: Parts 1-3 consistently retain an evicted descriptor tombstone, lookup entry, and branch owner. |
| TP-39-02 both-filled wording | CLOSED: row now says cold pressure with eligible victims; `both_filled` is reserved for failed room-making. |
| Missing or corrupt victim accounting | CLOSED: uncertain and quarantined bytes remain charged; unknown manifests disable mutation. |

## Blocking finding

### F39-AR3-01: public `mode` label domain is unspecified

Part 3 promises bounded public labels but lists fixed values only for `result`
and `reason`. The two new metric families include `mode`, so Developer must
still choose its values and QA cannot reject an unexpected series.

Required correction: define the complete fixed `mode` value set for both metric
families. If Stage 39 emits only in hybrid mode, use one value such as `hybrid`.
State that unknown values are forbidden, and add the expected mode value to each
TP-39 evidence tuple.

## Implementability and compatibility

Except for F39-AR3-01, the corrected protocol is implementable against the
current synchronous `tx_save` and `tx_demote_payload` path. It deliberately
replaces estimated-size planning and irreversible `cold_budget_make_room()`
deletion with staged-size planning and quarantine. Existing startup code confirms
that `--cache-ram 0` creates no controller. No public CLI, endpoint, or on-disk
payload format change is required. Legacy mode, topology, and restore ranking
remain out of scope.

## Verdict

REWORK REQUIRED. F39-AR3-01 blocks Manager design gate PASS and Developer
planning. Correction is narrow; fresh Architect re-review is required afterward.
