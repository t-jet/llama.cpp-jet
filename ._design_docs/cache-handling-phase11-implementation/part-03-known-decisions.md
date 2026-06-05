# Stage 11 open decisions for Manager

Source: [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)

## Status

Planning date: 2026-06-04
Plan state: drafted for Manager implementation-plan gate.
Implementation state: closed.

## Why these decisions need Manager input

The Developer can run the merge activity inside the contract rules
the design Part 1 sets, but a small set of decisions need a Manager
record before the Developer proceeds. The decisions below name the
reason, the recommended default, and the artifact the Manager record
appears in.

Each decision is a single binary choice. The Developer surfaces the
decision with the pre-merge report, the merge log, or the rework part
file. The Manager records the decision with a date and a one-line
rationale that names a prior-stage contract from design Part 1.

## Decisions

### D1: Upstream fork point SHA

Reason: the pre-merge analysis needs a concrete fork point SHA before
Step 1 can enumerate the commit range. The design Part 1 leaves the
concrete value to the implementation plan because the value depends on
the local repo state at the time the merge opens.

Recommended default: the fork point is the most recent commit on the
local default branch that is also reachable from the upstream `master`
tip. The Developer records the SHA in the pre-merge report cover
section before triage starts.

Manager record: a one-line approval of the SHA in the pre-merge
report cover section, with the date. A change to the fork point after
the pre-merge analysis closes reopens the pre-merge analysis per
design Part 6.

### D2: Rework-trigger threshold for a specific contract

Reason: the design Part 4 decision rule says a prior-stage contract
weakening is a rework candidate unless the Manager records a
rationale to the contrary. The threshold is implicit in the rule, not
explicit in a number, because the rule is qualitative.

Recommended default: a contract weakening that requires local code
change to keep the contract intact is a rework. A contract weakening
that the merge can satisfy with a documented mapping or a non-code
adjustment is a known gap with a follow-up plan.

Manager record: a one-line threshold statement in the merge log
"Decisions" section for any borderline case the pre-merge analysis
flags, with the affected prior-stage contract cited.

### D3: Acceptance of a known gap

Reason: the design Part 4 decision rule says a change that affects a
non-hybrid surface only and does not touch any prior-stage contract is
a DEFER decision and is recorded as a known gap with a follow-up
plan. The Manager reviews the known gap list as part of the Stage 11
closure decision.

Recommended default: a known gap is accepted when the Manager records
a follow-up owner and a target cycle. A known gap is rejected when the
Manager decides the change is material and the rework is required
before Stage 11 can close.

Manager record: a per-gap accept or reject in the merge log "Known
gaps" section, with the follow-up owner, target cycle, and the
affected prior-stage contract.

### D4: Documented mapping for a metric or field rename

Reason: the design Part 6 risk table names the case where an upstream
change renames a public metric or a bounded diagnostic field. The
Architect records the upstream change in the pre-merge report with
the proposed mapping. The Manager decides whether the rename is a
rework, a known gap, or a silent integration with a documented
mapping.

Recommended default: a rename that lands inside the same metric or
field name and changes only the value format is a known gap with a
documented mapping. A rename that changes the metric or field name
itself, the label set, or the bounded enum is a rework.

Manager record: a per-rename decision in the merge log "Decisions"
section, with the proposed mapping and the affected prior-stage
contract.

### D5: Extension of the upstream commit range

Reason: the design Part 1 commit range rule is all upstream commits
reachable from the upstream `master` tip but not from the local fork
point. A change to that rule is a Manager decision, not a Developer
choice, because the rule defines the scope the merge integrates.

Recommended default: the rule is applied as written. An extension is
allowed only when the Architect recommends it for a contract reason
and the Manager records the extension in the merge log "Cover and
metadata" section.

Manager record: a one-line approval of the extended range in the
merge log, with the date and the Architect recommendation that
justified the extension.

## Handoff state

The Developer surfaces the five decisions above with the pre-merge
report and the merge log. The Manager records each decision in the
matching artifact section before the gate that depends on the
decision opens. The implementation gate, the rework Stage N gates,
the test-plan gate, and the QA execution gate remain closed until
the implementation-plan review and the Manager implementation-plan
gate both pass.
