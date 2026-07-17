# Stage 39 Developer results review 20260717

Status: REWORK REQUIRED
Reviewed report: `test-report-20260717-01.md`

## Verdict

The report's 14 PASS, 0 FAIL, 0 SKIP, and 1 BLOCKED totals are correct. No
product failure is established. TP-39-03 is blocked by a stale canonical
PowerShell workload and apply schema. Coverage is deliberately deferred under
Manager Part 139's fail-fast rule, not failed coverage tooling.

## Root-cause evidence

The TP-39-03 log proves checkpoint-capable product behavior. Each admitted owner
created three context checkpoints. The first save reports 164.758 MiB exact
state, then the controller reports 215.009 MiB hot payload. The 50.251 MiB
difference matches the latest checkpoint. The second owner repeats the pattern:
429.079 MiB total hot payload includes both exact and checkpoint bytes.

Discovery returns two eligible entry-level exact policy rows, 172,761,412 and
171,777,772 bytes, with empty cold sets. This matches current source:
`enumerate_hot_policy_candidates_core()` ranks entries, and
`stage39_build_snapshot_locked()` emits each candidate through
`owner->payload_id`. Checkpoint identity and component sizes come from the
guarded `proof` operation. Empty cold sets are correct because the run used a
2 GiB hot budget and created no cold file.

The driver still expects one cold checkpoint candidate and sends historical
`tp39_03_cold_owner_setup:"selected_incoming_owner"`. Binding Part 43 instead
requires one eligible source owner with hot exact plus hot checkpoint, empty
cold, `tp39_03_setup:"same_owner_kind_sequence"`, and exact/checkpoint
`prepared_bindings`. The script also submits source/incoming twice and erases
the slot, making both owners eligible. The accepted route fixture submits source
then incoming once, leaving only the source owner eligible while the incoming
request holds the slot reference.

## Classification and ownership

| Finding | Classification | Owner | Correction and retest |
| --- | --- | --- | --- |
| TP-39-03 | QA workload/driver blocker | Developer | Update only the canonical PowerShell path and its pure tests to use the accepted two-request lifecycle, exact one-row/empty-cold preflight, guarded pair proof, natural setup tag, prepared bindings, and Part 43 budget formulas. Re-run script self-tests and one bounded TP-39-03 canonical node after Architect review and Manager authorization. |
| Coverage | Acceptable fail-fast deferral | QA | After TP-39-03 passes under a fresh Manager gate, run all four Part 43 PowerShell 7/5 success and forced-merge-failure blocks in distinct fresh roots. Require real merged XML/report, at least 80 percent changed-line coverage, forced exits and artifact absence exactly as specified. |

No product, fixture, seam, or test-plan change is justified by this evidence.

## Next gate

Developer implements Part 140's bounded driver correction. Architect reviews
schema parity and fail-closed tests. Manager then authorizes a fresh TP-39-03
plus four-block coverage retest. Stage 39 remains open until both pass.
