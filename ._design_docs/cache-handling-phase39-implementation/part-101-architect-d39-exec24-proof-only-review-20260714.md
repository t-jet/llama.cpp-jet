# Part 101: Architect D39-EXEC-24 proof-only review

Date: 2026-07-14
Verdict: PASS FOR ONE PROOF-ONLY SMOKE
Scope: Parts 50 and 98-100, corrected helper, source schema, and exec24 capture

## Evidence verdict

D39-EXEC-24 safely authorizes one proof-only midpoint smoke after a Manager
gate. The captured lifecycle is production-consistent: the first saved source
is pinned, the second normal admission transfers the slot reference, and the
source becomes the sole eligible hot exact row. Both admissions returned 200,
nodes moved from one to two, cold state stayed empty, and decision and
transaction totals stayed zero. The helper stopped before proof or apply.

The corrected pure lifecycle set reports 12 passed and 29 deselected. No model
rerun followed the correction.

## Schema evidence

`stage39_build_snapshot_locked()` iterates `hot_candidates`. For each row it
copies the row payload and owner into the cold-set key, then calls
`enumerate_cold_policy_candidates_core(incoming_owner)`. That selector includes
only cold descriptors owned by someone else. Apply later selects the cold set
by equality with the chosen hot payload and owner.

Therefore exec24's hot owner 1 and
`cold_sets[0].incoming_owner_entry_id == 1` are required. The prior helper
assertion was reversed. The corrected equality matches design Part 15 and the
test-plan contract.

Coupled assumptions are now explicit:

- "incoming" means selected hot pressure candidate, not latest chat owner;
- one cold set exists per hot row and copies both hot-row key fields;
- different-owner filtering applies only to nested cold candidates;
- no global owner uniqueness rule spans hot and cold arrays;
- the hot row is the owner's exact link; read-only proof expands both owner
  links and orders exact before checkpoint;
- the active second-chat owner is expected to be absent while it holds the
  slot reference.

No further schema mismatch was found.

## Authorized contract

Design Part 51 is binding. Manager may authorize exactly one fresh
`slot-release-midpoint` test after confirming the corrected 12-case pure PASS.
The test may finish `admit_pair()` through stable repeat discovery and
read-only proof capture. It must stop before `_mtp_prepared_apply()` or any
control request with `operation=apply`.

Acceptance requires the complete Part 51 artifact set, the 1-to-2 lifecycle,
the exact/checkpoint same-owner hot pair, positive target and draft components,
matching runtime pair, internally reconciled resident sizes, stable repeated
reads, unchanged zero pre-apply metrics, empty cold storage, redacted secrets,
and explicit proof that apply, prepared, terminal, and fault artifacts do not
exist.

One failed proof-only smoke closes this authorization. Classification must name
the first failed invariant. Prompt, budget, wait, request-count, schema, or
assertion calibration is forbidden.

## Process review

Stage 39's transaction and fault ordering needed careful review. The number of
turns was still excessive. Work proceeded by discovering one prerequisite per
model run: fixture capability, draft selector, log level, metrics parsing,
capture timing, slot lifecycle, then field meaning. Several gates approved a
local symptom without tracing the complete path from chat admission through
slot ownership, discovery schema, proof expansion, and apply selection.

Future stages should use one executable contract capsule before model work. It
should contain the literal command and requests, schema provenance for every
asserted field, a state-transition table, pure mocked tests for every stop,
the complete artifact manifest, and one decision tree for failure
classification. Review the whole admission-to-selection path once. Run the
model only after pure tests pass, capture raw responses before interpretation,
and batch all read-only evidence in one smoke. Keep fault runs separate and
require a fixed stop before each mutation boundary.

This review supersedes Part 100's Architect-review-next handoff, not its
evidence. Next owner: Manager for the Part 51 proof-only gate. Fault execution,
step 2, canonical TP-39-03, coverage, full QA, product changes, build, commit,
and push remain blocked.
