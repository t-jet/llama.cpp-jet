# Stage 11 design: rework assessment process -- Part 4

Source: [../cache-handling-phase11-design.md](../cache-handling-phase11-design.md)

## Goal

The rework assessment process is the contract for what happens when an
upstream change would invalidate one or more prior stage contracts. It
names the mapping rule, the rework workflow, and the decision rule for
recording a known gap instead of opening a rework.

## Mapping an upstream change to a prior stage

The Architect maps each upstream change to a stage, not to a file. The
mapping uses the prior-stage contracts in Part 1 as the lens, not the
file paths the upstream commit touched.

The mapping rule is:

1. Identify the prior-stage contract from Part 1 that the upstream change
   would weaken, rename, or remove.
2. The contract owner is the affected stage. If the contract is shared
   across stages, the rework opens for the stage that owns the
   contract's primary contract section in the architecture or
   requirements.
3. The rework may also touch secondary stages when the same change
   affects their contract, but the rework is opened against the primary
   stage. The secondary stages receive follow-up tasks in their
   implementation logs, not a separate rework.
4. The mapping is recorded in the pre-merge report's per-commit triage
   table and in the rework Stage N design entry.

The Architect does not open a rework for an upstream change that does
not weaken a prior-stage contract. A cosmetic upstream change, a
documentation-only upstream change, or a test-only upstream change that
the closed stages did not depend on is a NO-OP or INTEGRATE decision,
not a rework.

## Rework workflow

A rework follows the standard stage workflow: Design, Implementation,
Test, Closure. The rework is not a fresh stage; it is a delta against
the affected stage's current state.

The rework workflow is:

1. Architect opens a rework for stage N by writing a new part file in
   the stage N design directory. The rework part file references the
   current design entry doc, the current implementation log entry doc,
   the prior-stage contract from Part 1, the upstream change that
   triggered the rework, and the contract gap the rework must close.
2. Architect reviews the rework part file and records a review verdict
   in the rework part file itself, not in a separate review document.
3. Manager records a rework design-gate decision in the rework part
   file and links it from the stage N design entry doc.
4. Developer writes a rework implementation plan in the stage N
   implementation log. The rework plan follows the same shape as the
   original stage N plan, but its steps are limited to the contract gap
   the rework must close.
5. Architect reviews the rework plan and records a review verdict.
6. Manager records a rework implementation-plan gate decision.
7. Developer implements the rework. The rework evidence is recorded
   in the stage N implementation log, not in the Stage 11
   implementation log.
8. Architect reviews the rework implementation and records a review
   verdict.
9. QA executes the rework evidence and records a test report. The test
   report references the rework part file and the rework
   implementation plan.
10. Architect reviews the test report and records a test-results
    verdict.
11. Manager records a rework closure decision in the stage N
    implementation log. The rework closure does not open a new stage
    gate; it confirms the stage N contract is intact on the integrated
    tree.

The rework may not redesign the affected stage from scratch. The rework
is limited to the contract gap the upstream change exposed. A broader
redesign is a new stage design, not a rework, and is opened through the
standard stage intake process.

## Decision rule for known gap vs rework

The Manager decides whether an upstream change becomes a rework or a
known gap with a follow-up plan. The decision rule is:

1. A change that weakens a prior-stage contract without an obvious local
   fix is a rework candidate. The rework opens unless the contract
   weakening is intentional and approved by the Manager.
2. A change that exposes a contract gap the prior stage designs did not
   record is a rework candidate. The rework opens even if the upstream
   change is small, because the gap is the durable problem.
3. A change that weakens a prior-stage contract but has a local fix
   ready and reviewed in the rework part file is still a rework. The
   rework opens to record the local fix and its evidence.
4. A change that affects a non-hybrid surface only and does not touch
   any prior-stage contract is a NO-OP or INTEGRATE decision and is
   not a rework.
5. A change that the Architect or Manager decides is not material to
   the hybrid cache, the checkpoint layer, speculative decoding, server
   context, slot lifecycle, or the HTTP layer is a DEFER decision and
   is recorded as a known gap with a follow-up plan in the merge log.

A known gap with a follow-up plan is not a closure contract on its own.
The known gap appears in the merge log and in the document index when
it is durable. The Manager reviews the known gap list as part of the
Stage 11 closure decision. A known gap is accepted when the Manager
records a follow-up owner and a target cycle. A known gap is rejected
when the Manager decides the change is material and the rework is
required before Stage 11 can close.

## Multiple upstream changes to the same prior stage

When more than one upstream change maps to the same prior stage, the
Architect opens a single rework for that stage. The rework part file
lists every upstream change in its scope, and the rework implementation
plan addresses the combined contract gap. A second rework for the same
stage opens only when a later Stage 11 cycle surfaces a new contract
gap that the first rework did not close.

The Developer does not start a second rework on a stage that already
has an open rework. The Developer waits for the first rework to close
or for the Manager to merge the two reworks into one.

## Boundary with the Stage 11 implementation log

The rework evidence lives in the affected stage's implementation log,
not in the Stage 11 implementation log. The Stage 11 implementation
log only records the list of reworks the merge opened, the status of
each rework, and the date each rework closed. The Stage 11
implementation log does not record the rework's design, plan, code, or
test evidence. The Stage 11 implementation log links to those
artifacts in the affected stage's tree.
