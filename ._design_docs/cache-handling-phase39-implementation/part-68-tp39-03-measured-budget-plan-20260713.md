# Part 68: TP-39-03 measured startup-budget plan

Date: 2026-07-13
Status: SUPERSEDED IN PART BY D39-EXEC-09 IMPLEMENTATION PART 70
Authority: D39-EXEC-07, D39-EXEC-08, and design Parts 25 and 27

## Correction

Update only TP-39-03 driver measurement, startup-budget derivation, ordering,
and preflight assertions.

1. Use hot 166 MiB and cold 2048 MiB for measurement. Remove its compatible
   `cold_sets` requirement, but require normal production demotion.
2. Count `target_only` as complete only with same-process
   `runtime_has_draft=false` and
   `runtime_pair_matches(target_only,false)=true`. Record resident components
   and normally demoted serialized bytes for both roles. Reconcile final file,
   header, descriptor, byte map, and filesystem length.
3. Implement Part 25's checked integer helpers with `U = 1,048,576` and a fixed
   one-MiB safety margin. Assert all four startup inequalities before launch.
4. Keep measurement order source, incoming, source filler, incoming filler. It
   sends no guarded apply or owner reassignment and proves runtime pair shape,
   normal demotion, sizes, files, reconciliation, RSS, and checkpoint capability.
5. Start canonical with a new process, empty root, and derived startup budgets.
   Send source then incoming, wait for idle save after each, then discover
   before fillers or apply.
6. Fail closed unless discovery proves runtime pair shape, source demotion,
   immutable file/header and descriptor-size reconciliation, incoming hot
   residency, and exactly one Part 19-compatible cold checkpoint set.
7. Derive existing lowered apply budgets from that snapshot and enforce all
   four apply inequalities before seam consumption.

Part 67 supplies regression inputs: resident sizes 172,761,412 and 171,777,772
bytes, illustrative hot startup 166 MiB, checkpoint log 50.251 MiB, peak RSS
5,397,516,288 bytes, and zero cold bytes at 2048 MiB. The resident values are
candidates until Part 27's runtime proof. Never substitute the 50.251 MiB state
log for immutable serialized bytes.

## Acceptance and gate

- Measurement may have no compatible `cold_sets`, but must create and reconcile
  real cold files through normal production demotion and cannot apply.
- Canonical cannot launch from missing or guessed sizes.
- Startup hot and cold each fit either measured pair plus one MiB but not both.
- Canonical discovers after source then incoming and before filler or apply.
- Compatible-set and apply-budget preflights bind one canonical snapshot.
- Part 19 security, compatibility, rollback, and normal pressure stay unchanged.

Implementation Part 69 is the current D39-EXEC-08 plan. Fresh independent
Architect review is next. Code, tests, execution, coverage, commit, and push
remain blocked.
