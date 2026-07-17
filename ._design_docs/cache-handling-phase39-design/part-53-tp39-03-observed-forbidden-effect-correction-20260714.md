# Part 53: TP-39-03 observed forbidden-effect correction

Date: 2026-07-14
Status: ARCHITECT CORRECTION; MANAGER GATE NEXT
Scope: D39-EXEC-26 terminal evidence only

## Finding

D39-EXEC-26 captures real entry, branch, inventory, metric, topology, and
generation state. Seven fields in `terminal_state.forbidden_effects` are not
derived from that state or from production event observations:

- `checkpoint_classification_delta`;
- `checkpoint_publish_delta`;
- `checkpoint_commit_delta`;
- `checkpoint_cold_file_delta`;
- `checkpoint_descriptor_mutation_delta`;
- `checkpoint_link_mutation_delta`; and
- `explicit_generation_advance_delta`.

The implementation serializes each field as literal zero. Controller and pure
tests then assert those literals. This cannot prove that the forbidden effect
did not occur. `success_snapshot_count` and `failed_apply_count` are also
literal outcomes, but the response status, missing success token, failed
control result, and consumed retry independently prove those two values.

Part 52 requires deltas from the pre-apply snapshot and says each zero delta
must be changed in a negative test. Route execution remains blocked.

## Required observations

Keep all product behavior, fault control flow, fixture, budgets, metrics, and
routes unchanged. Under `LLAMA_STAGE39_LIVE_TEST_SEAM`, record observations at
the existing production boundaries:

- count entry into checkpoint cold-budget classification;
- count checkpoint publish and committed cold transaction completion;
- compare pre-apply and terminal checkpoint cold inventory;
- snapshot checkpoint descriptor fields and the owner entry's checkpoint link,
  then compare them at terminal capture; and
- count any guarded explicit generation advance. The expected count is zero;
  do not add an advance to obtain evidence.

Each counter must increment only where the named production effect happens.
Descriptor and link comparisons must cover identity, owner, kind, residency,
store reference, component sizes, checksums, resident bytes, pair state, and
the entry link. A changed-then-restored effect needs an event count as well as
the terminal comparison.

Derive every listed delta from these observations. Do not serialize a zero
literal for an event that the field claims to measure. Keep decision,
transaction, diagnostic, common-sync, final-generation, topology, staging,
and HMAC capture as implemented in D39-EXEC-26.

## Test correction

Add focused controller-only negative probes that make each observed delta
nonzero without running a model and prove the common terminal matrix rejects
it. Pure response-shape tests must still remove every required terminal field
and change every required zero-valued field. Keep separate midpoint and step-2
checks:

- midpoint has no checkpoint attempt or preparation;
- step 2 prepares checkpoint once and removes staging before classification;
- both retain exactly one exact decision and transaction, one common sync,
  unchanged topology, failed apply, consumed retry, and authenticated
  byte-equivalent retrieval with tamper rejection.

## Gate

Manager may authorize only this guarded observation correction, one reused
seam build, pure negatives, and both controller faults. Fresh Architect review
must pass before two sequential route nodes. Model execution, default build,
fixture changes, canonical TP-39-03, coverage, full QA, commit, and push remain
blocked.
