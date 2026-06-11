# Stage 14 known decisions for Manager

Source: [../cache-handling-phase14-implementation.md](../cache-handling-phase14-implementation.md)

## Status

Planning date: 2026-06-11
Plan state: drafted for Manager implementation-plan gate.
Implementation state: not started.

## Why these decisions need Manager input

The Developer can run the merge activity inside the contract
rules the design Part 1 sets, but a small set of decisions
need a Manager record before the Developer proceeds. The
decisions below name the reason, the recommended default, and
the artifact the Manager record appears in. Each decision is a
single binary choice unless noted. The Developer surfaces the
decision with the pre-merge report, the merge log, or the
rework part file. The Manager records the decision with a date
and a one-line rationale that names a prior-stage contract
from design Part 1.

## Carry-forward decisions

### D1: upstream reference strategy (carry-forward verbatim)

Reason: design Part 1 "Upstream reference strategy" names the
remote-tracking ref `origin/upstream_master` as the merge
source. Last fetched 2026-06-04 per the original D1 record.
No `upstream` remote is required. No local `upstream_master`
tracking branch is required. The Developer operates against
`origin/upstream_master` directly. The Developer verifies the
remote ref tip is current against the actual upstream `master`
via `git ls-remote https://github.com/ggml-org/llama.cpp.git
master` (or the GitHub REST API endpoint) before the merge
opens. A stale remote ref is a known gap recorded in the
merge log, not a blocker that halts the cycle. Status:
ACCEPT, carry-forward, Path C 2026-06-11. The Developer
records the verification commands and outputs in the pre-merge
report "Upstream reference verification" section per
upstream-merge-guide Part 1 section 2.

### D2: `test-stage10-policy-lru` pre-existing semantic bug is out of scope

Reason: design Part 1 non-goals list the pre-existing
semantic bug as out of Stage 14 scope. Tracked separately.
The merge does not require its fix and does not let the fix
gate the cycle. Status: ACCEPT, carry-forward. Triage records
any upstream commit that exposes a related path as DEFER or
INTEGRATE with a one-line reason that references the
tracked-separately record.

### D3: synthetic Stage 12 V2/V3/non-MTP matrix expansion remains paused

Reason: the 2026-06-09 close-at-current-progress Manager
decision keeps the expansion paused. Lifting the pause
requires a separate Manager decision outside Stage 14. Status:
ACCEPT, carry-forward. Triage records any upstream commit that
resumes the expansion as a rework candidate for Stage 12.

## Open Manager decisions at the implementation-plan gate

The decisions below are open. The Developer surfaces each with
the pre-merge report (D4, D5, D6, D7), the Manager review (D8,
D9, D10, D11), the merge log, or the rework part file. The
Manager records each decision before the gate that depends on
the decision opens.

### D4: local `upstream_master` tracking branch is missing (RESOLVED 2026-06-11)

Reason: on 2026-06-11 the local repo has no local
`upstream_master` branch. Only `origin/upstream_master` exists
at SHA `db94854ff56549f62b84d2f31608259a9e5e0e9f`. The
Manager selected Path C: the cycle operates against
`origin/upstream_master` directly. The Developer does not
create a local branch.

Manager record: resolved via Manager decision 2026-06-11
(Path C). Recorded in the implementation log Manager
decisions log as (RESOLVED 2026-06-11) D4.

### D5: worktree is dirty at cycle open (open)

Reason: on 2026-06-11 the working tree has uncommitted edits
to `cache-handling-architecture/part-05-...`,
`document-index.md`,
`self-improvement/assets/{architect,manager}.md`, and an
untracked design file `cache-handling-phase14-design.md`. The
upstream-merge-guide Part 4 section 11 rule says the cycle
opens with a clean working tree.

Recommended default: the Developer stashes or commits the
edits before the merge opens. The untracked design file is the
Stage 14 design entry, which is expected to be present but
untracked until the next indexing cycle; the Developer can add
it with `git add -N` so `git diff --check` covers it.

Manager record: a one-line decision in the pre-merge report
"Manager decisions requested" section, with the date and the
chosen path (stash, commit, or discard per edit).

### D6: `origin` remote URL is the local jet fork, not upstream (open)

Reason: the `origin` remote is
`https://github.com/t-jet/llama.cpp-jet.git` (the local jet
fork), not `https://github.com/ggml-org/llama.cpp.git` (the
upstream repository). D6 surfaces the gap between
`origin/upstream_master` (last fetched 2026-06-04, jet fork's
snapshot of upstream) and the actual upstream `master` tip.

Recommended default: the Developer uses
`origin/upstream_master` as the upstream reference per Path
C. The Developer records the actual upstream tip via `git
ls-remote https://github.com/ggml-org/llama.cpp.git master`
and records the gap in the pre-merge report "Upstream
reference verification" section. The gap is a known gap
recorded in the merge log per D1, not a blocker.

Manager record: a one-line decision in the pre-merge report
"Manager decisions requested" section, with the date, the
actual `origin` URL, the actual remote ref tip SHA, the
actual upstream tip SHA, and the gap.

### D7: fork point SHA is unknown until Step 1 (open)

Reason: the merge base between the local default branch and
`upstream_master` is unknown until Step 1 runs. The Developer
records the recovered fork point in the pre-merge report
"Cover and metadata" section.

Recommended default: the fork point is the merge base of the
local default branch and `upstream_master`. A fork point the
Developer cannot recover is itself a known gap recorded in the
pre-merge report "Open questions" section per
upstream-merge-guide Part 1 section 2.

Manager record: a one-line approval of the SHA in the
pre-merge report cover section, with the date. A change to the
fork point after the pre-merge analysis closes reopens the
pre-merge analysis per design Part 6.

### D8: rework-trigger threshold for a specific contract (open, surfaces at Step 2)

Reason: design Part 4 decision rule says a prior-stage
contract weakening is a rework candidate unless the Manager
records a rationale to the contrary. The threshold is implicit
in the rule, not explicit in a number, because the rule is
qualitative.

Recommended default: a contract weakening that requires local
code change to keep the contract intact is a rework. A
contract weakening that the merge can satisfy with a
documented mapping or a non-code adjustment is a known gap
with a follow-up plan.

Manager record: a one-line threshold statement in the merge
log "Decisions" section for any borderline case the pre-merge
analysis flags, with the affected prior-stage contract cited.

### D9: acceptance of a known gap (open, surfaces at Step 2)

Reason: design Part 4 decision rule says a change that affects
a non-hybrid surface only and does not touch any prior-stage
contract is a DEFER decision and is recorded as a known gap
with a follow-up plan. The Manager reviews the known gap list
as part of the Stage 14 closure decision.

Recommended default: a known gap is accepted when the Manager
records a follow-up owner and a target cycle. A known gap is
rejected when the Manager decides the change is material and
the rework is required before Stage 14 can close.

Manager record: a per-gap accept or reject in the merge log
"Known gaps" section, with the follow-up owner, target cycle,
and the affected prior-stage contract.

### D10: documented mapping for a metric or field rename (open, surfaces at Step 2)

Reason: design Part 6 risk table names the case where an
upstream change renames a public metric or a bounded diagnostic
field. The Architect records the upstream change in the
pre-merge report with the proposed mapping. The Manager
decides whether the rename is a rework, a known gap, or a
silent integration with a documented mapping.

Recommended default: a rename that lands inside the same
metric or field name and changes only the value format is a
known gap with a documented mapping. A rename that changes the
metric or field name itself, the label set, or the bounded enum
is a rework.

Manager record: a per-rename decision in the merge log
"Decisions" section, with the proposed mapping and the
affected prior-stage contract.

### D11: extension of the upstream commit range (open, surfaces at Step 2)

Reason: design Part 1 commit range rule is all upstream
commits reachable from the `upstream_master` tip but not from
the local fork point. A change to that rule is a Manager
decision, not a Developer choice, because the rule defines the
scope the merge integrates.

Recommended default: the rule is applied as written. An
extension is allowed only when the Architect recommends it for
a contract reason and the Manager records the extension in the
merge log "Cover and metadata" section.

Manager record: a one-line approval of the extended range in
the merge log, with the date and the Architect recommendation
that justified the extension.

## Naming conventions

The naming conventions below are the Developer's conventions.
The Manager approves them at the implementation-plan gate; the
Developer fills the date and sequence number at Step 1 and
Step 6.

- Pre-merge report: `pre-merge-report-YYYYMMDD-NN.md` (NN is
  the next available suffix). The Developer opens the first
  Stage 14 pre-merge report at Step 1.
- Pre-merge report review: same root with
  `-architect-review.md` suffix.
- Stage 14 test report: `test-report-YYYYMMDD-NN.md`.
- Stage 14 fixes report: same root with `-fixes.md` suffix.
- Stage 14 Developer test-results review: same root with
  `-developer-review.md` suffix.
- Stage 14 Architect test-results review: same root with
  `-architect-review.md` suffix.
- Stage 14 merge log: `merge-log-YYYYMMDD-NN.md`. The Developer
  opens the first Stage 14 merge log at Step 3.
- Stage 14 merge log review: same root with
  `-architect-review.md` suffix.
- Per-rework part file: opened in the affected stage's
  `cache-handling-phaseN-design/` directory using the affected
  stage's naming convention. The Architect names the part file
  at Step 4.
- Per-rework implementation plan: opened in the affected
  stage's `cache-handling-phaseN-implementation/` directory
  using the affected stage's naming convention. The Developer
  names the plan at Step 4.

## Pre-merge analysis commit range rule

The commit range rule is inherited from upstream-merge-guide
Part 1 section 3. The rule is deterministic so the same
upstream state always produces the same commit set:

1. Start with the upstream commits reachable from
   `upstream_master` tip but not from the local fork point.
   This is the natural commit range for the merge.
2. Filter the range to commits whose change set touches at
   least one of the file-glob groups from design Part 2
   "File-glob groups for scope selection". A commit is in
   scope if any of its changed paths matches a glob in any
   group, or if its commit message references a relevant
   subsystem even when the path filter does not match.
3. Exclude commits that touch only tests, documentation,
   build, or CI configuration for the affected file-glob
   groups, unless the commit also changes a runtime path any
   prior-stage contract governs.
4. Exclude merge commits and pure version bumps unless they
   affect a runtime path any prior-stage contract governs.
5. Record the resulting commit set in the pre-merge report
   "Commit range" section before the triage starts.

The file-glob groups are stage-specific. The Architect reviews
the groups at design time. A new file-glob group the Architect
adds during the cycle is recorded in the pre-merge report
"Open questions" section and is approved by the Manager.

## Handoff state

The Developer surfaces the eleven decisions above with the
pre-merge report (D4, D5, D6, D7), the Manager review (D8, D9,
D10, D11), the merge log, and the rework part file. The
Manager records each decision in the matching artifact section
before the gate that depends on the decision opens. The
implementation gate, the rework Stage N gates, the test-plan
gate, and the QA execution gate remain closed until the
implementation-plan review and the Manager implementation-plan
gate both pass.


