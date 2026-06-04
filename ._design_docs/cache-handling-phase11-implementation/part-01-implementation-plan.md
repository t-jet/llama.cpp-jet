# Stage 11 implementation plan, prerequisites, and gates

Source: [../cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md)

## Status

Planning date: 2026-06-04
Plan state: drafted for Architect implementation-plan review and Manager implementation-plan gate.
Implementation state: closed.
QA execution state: closed.

## Accepted design baseline

The implementation plan is built on the accepted design in
[../cache-handling-phase11-design.md](../cache-handling-phase11-design.md),
Parts 01 through 06, with the Architect design review in
[../cache-handling-phase11-design/part-07-design-review-gate-01.md](../cache-handling-phase11-design/part-07-design-review-gate-01.md)
recording verdict PASS and 7 of 7 author decisions accepted. The Manager
design-gate decision is PASS, dated 2026-06-04.

The Stage 11 scope is fixed by the architecture and is carried into the
design verbatim. This plan does not redefine the scope.

### Prior-stage contracts the plan keeps

The design Part 1 prior-stage contracts table lists every contract the
merge must preserve. The Architect's review grouped the rows into 25
contracts, which the plan confirms and preserves. The full per-row table
remains the authoritative source in the design Part 1.

| # | Contract category | Owner | What the merge and rework must preserve |
| --- | --- | --- | --- |
| 1 | Hybrid opt-in CLI flag and mode gate | Architecture, Stage 1 | `--cache-mode hybrid` stays explicit and opt-in. Mode dispatch in `server_context` keeps hybrid and legacy controllers separated. |
| 2 | Legacy default path unchanged | Architecture, Stage 1 | When `--cache-mode` is absent or not `hybrid`, the legacy cache path behaves exactly as before the merge. |
| 3 | Compatibility namespace key | Stage 2, Stage 5, Stage 7, Stage 9 | The namespace key continues to include target identity, draft identity or absence, tokenizer-compatible prompt semantics, workload profile, and material runtime modifiers. |
| 4 | Draft runtime mode identity | Stage 5, Architecture Part 6 | Target-only, separate draft, MTP-on-target, and MTP-on-separate-draft descriptors stay distinct in the namespace and in the runtime shape observed by the cache. |
| 5 | Target and draft pairing | Stage 5 | Save, restore, offload, eviction, and cold-layer operations preserve target and draft coupling. Partial paired restore is a blocking defect. |
| 6 | Prepared-prompt boundary metadata | Stage 2, ADR-004, Stage 9 | Boundaries captured at prompt preparation flow into `server_task` and reach `server_context`. Checkpoint placement at prepared-prompt boundaries when metadata is available stays in force. |
| 7 | Hot and cold residency | Stage 4, Stage 6, Stage 9 | Hot and cold residency, eviction, and promotion rules apply to both full-state blobs and checkpoint payloads. |
| 8 | Byte-accounted LRU with protected roots | Stage 4, Architecture Part 2 | Resident-byte accounting and protected-root priority remain in force. The shared hot-payload, branch-metadata, and cold-layer budget pool stays global across namespaces. |
| 9 | Payload descriptor separation and validation | Stage 5, Stage 10 | Descriptors carry id, kind, pair state, version, size, checksum, store reference, and residency state. Pre-restore validation is mandatory. |
| 10 | Atomic target and draft restore | Stage 5 | A partial paired restore is a blocking defect. |
| 11 | Cold store integrity and root containment | Stage 6, Stage 10 | Versioned descriptors, checksums, atomic write and rename, staging files, normalized root, and root-containment checks remain in force. |
| 12 | Branch forest, namespace validation, slot references | Stage 7 | The shared forest, namespace validation before restore, slot references without ownership transfer, and global LRU eviction remain in force. |
| 13 | Metadata-only nodes and re-materialization | Stage 8 | Re-materialization from the nearest retained payload-bearing ancestor, validation mismatch handling, and mismatch-parent selection with deterministic tie-breaking remain in force. |
| 14 | Equivalent-branch deduplication | Stage 8 | Convergence on the same validated prompt path joins the existing node rather than creating a duplicate. |
| 15 | Cold cleanup ownership | Stage 8 | Pruning verifies that no retained branch or descendant owns the descriptor before cold deletion. |
| 16 | Checkpoint payloads as first-class branch nodes | Stage 9 | Checkpoint payloads move, restore, evict, and demote as first-class branch node references. |
| 17 | Workload profile detection and restore strategy | Stage 9 | Plain-transformer, checkpoint-dependent, and target-plus-draft profile detection and the restore strategy order remain in force. |
| 18 | Public Prometheus metric set and label shape | Stage 10, ADR-008, S10-IMPL-01 | R61-R68 metric set, bounded labels, absence of sensitive material in labels, and the S10-IMPL-01 corrected metric shape remain in force. |
| 19 | Bounded diagnostics for failure and fallback paths | Stage 10 | Structured diagnostics for unsupported configuration, marker validation, namespace or pair rejection, cold-store failure, and restore failure remain in force. |
| 20 | OWASP review mitigations | Stage 10 | Cold-store path normalization, root containment, marker sanitization, descriptor integrity, paired atomicity, and monitoring mitigations remain in force. |
| 21 | Deterministic test seams | Stage 10 | Injected clocks, fake stores, deterministic graph lookup, and worker completion order remain in force. |
| 22 | T114 combined 80% hybrid path coverage floor | Stage 10, test plan Part 12 | The combined-rate 80% floor on the 19-file hybrid-mode denominator remains a closure contract. |
| 23 | T114a 70% product-only hybrid path coverage floor | Test plan Part 13 | The product-only 70% floor on the 11 product files named in the Architect review Finding B is a closure contract from Stage 11 onward. |
| 24 | T115 per-file aggregation rule | Test plan Part 12, Part 13 | The per-file table lists each hybrid-mode file exactly once, with deduplication by lowercased full path. |
| 25 | T121 public checkpoint admission row | Stage 10 implementation Part 9, test plan Part 12 | The four `cache_checkpoint_*` rows stay exposed through the public /metrics endpoint when a hybrid-mode server with MTP or checkpoint-capable draft is exercised. |

The plan keeps every contract above. A contract that an upstream change
would weaken is a rework candidate, not a silent integration.

### T114 and T114a closure contracts

T114 (combined 80% on the 19-file hybrid-mode denominator) and T114a
(product-only 70% on the 11 product files) are both closure contracts
for Stage 11. The Stage 10 closure record cited T114 only. T114a is the
new row introduced by the Action B test-plan enhancement in
[../cache-handling-test-plan/part-13-t114-product-only-coverage.md](../cache-handling-test-plan/part-13-t114-product-only-coverage.md)
and is effective Stage 11 onward.

The Stage 11 test report cites the `## Combined result` block in
`coverage-report.md` for the T114 verdict and the `## Product-only
result` block for the T114a verdict. The XML root attributes are not the
verdict source. The citation rules match the Action A QA process
guidance.

## Prerequisites and gates

The Stage 11 merge activity is gated on the prerequisites below. A
prerequisite that is not met is a blocker, not a skip.

| Prerequisite | Owner | Status | Source |
| --- | --- | --- | --- |
| Stage 10 closure record on disk with no open product bug, QA harness blocker, environment blocker, or accepted public-evidence limit | Manager | PASS, 2026-06-04 | [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md) closure section |
| Stage 11 design authoring, independent Architect design review, and Manager design-gate decision all PASS | Manager | PASS, 2026-06-04 | [../cache-handling-phase11-design/part-07-design-review-gate-01.md](../cache-handling-phase11-design/part-07-design-review-gate-01.md) |
| `run_coverage.ps1` updated to emit the `## Product-only result` block in `coverage-report.md` for the T114a row | Developer | NOT STARTED | [../cache-handling-test-plan/part-13-t114-product-only-coverage.md](../cache-handling-test-plan/part-13-t114-product-only-coverage.md) required-script-behavior section. Detailed scope and placement rationale in [part-04-prerequisites.md](part-04-prerequisites.md). |
| Architect implementation-plan review of this plan | Architect | NOT STARTED | Next gate. |
| Manager implementation-plan gate decision | Manager | NOT STARTED | Follows Architect review. |

The `run_coverage.ps1` prerequisite is the only open prerequisite at the
start of implementation planning. The plan lists it as a separate
Developer gate that runs before Step 1 of the merge activity. The
placement rationale is in [part-04-prerequisites.md](part-04-prerequisites.md).

## Ordered steps

The merge activity follows the six steps below. Steps 1 through 6 do not
start until the prerequisite Developer gate for the `run_coverage.ps1`
change closes.

### Step 1: pre-merge analysis

Owner: Developer. Reviewer: Architect. Approver: Manager for any
rework-trigger decision.

Inputs: design Part 2 (file-glob groups, triage matrix, pre-merge
report format), the local repo state at the fork point, and the
fetched upstream `master` ref and tags.

Activities:

1. Confirm the working tree is clean, the local default branch is
   checked out at the fork point, and the upstream ref and tags are
   fetched. Record the fork point SHA, the upstream remote, the
   upstream ref, and the fetched tip SHA in the pre-merge report.
2. Enumerate the commit range per design Part 2 (all upstream commits
   reachable from `master` tip but not from the fork point) and apply
   the file-glob filter. Record the total and filtered counts.
3. Open the pre-merge report with the required sections: cover and
   metadata, commit range, per-commit triage table, aggregate
   summary, open questions.
4. Assign one triage decision per in-scope commit: NO-OP, INTEGRATE,
   REWORK-REQUIRED, DEFER, or REVERT. Cite the prior-stage contract
   from Part 1 that the commit leaves untouched, modifies, or breaks.
   Restating the commit subject is not acceptable.

Exit criteria: the pre-merge report is on disk with the triage table
complete, the aggregate summary populated, and open questions named.

### Step 2: Manager review of the pre-merge analysis

Owner: Manager. Reviewer: Architect. Input: the pre-merge report
from Step 1.

Activities:

1. Architect records a review verdict on the pre-merge report. The
   verdict PASSES only when triage reasons cite a contract, a path, or
   a test surface, and the aggregate summary is consistent with the
   triage table.
2. Manager reviews the Architect verdict. Manager is the only agent
   who can change NO-OP, INTEGRATE, or DEFER into REWORK-REQUIRED.
   Manager records the change with the date and the prior-stage
   contract the change protects.
3. Rework part files for any escalation open in Step 4, not here. The
   pre-merge report records the Manager decisions and the rework part
   file links.

Exit criteria: the pre-merge report carries an Architect verdict and a
Manager decision on every revisited row.

### Step 3: merge execution

Owner: Developer. Reviewer: Architect. Inputs: the accepted pre-merge
report from Step 2 and design Part 3 (merge command family and
conflict resolution policy).

Activities:

1. Re-confirm the commit range. If it changed, reopen Step 1 and stop.
2. Run the merge into the local default branch. A fast-forward is
   acceptable only when the pre-merge analysis lists no INTEGRATE or
   REWORK-REQUIRED decisions. The merge log records the strategy used.
3. Resolve conflicts with the policy from design Part 3: hybrid and
   legacy default preservation, local-first for hybrid mode,
   upstream-first for legacy mode. The Developer does not delete code,
   comment out a path, or insert a runtime no-op without recording the
   choice in the merge log.
4. Run the local build, ctest, and (when applicable) focused exporter
   coverage from design Part 3. Record failures with the prior-stage
   contract the failing test covers.
5. Update the merge log with the merge command, conflict list,
   resolution list, build result, and test result.

Exit criteria: the integration branch builds, the prior-stage ctest
binaries pass, and the merge log records the merge command, conflicts,
resolutions, and intermediate test results.

### Step 4: per-rework planning

Owner: Architect (design), Developer (implementation). Reviewer:
Architect. Approver: Manager. Inputs: the pre-merge report from
Step 1, the Manager rework-trigger decisions from Step 2, design
Part 4, and the affected stage's current design and implementation
log.

Activities:

1. For each REWORK-REQUIRED entry, the Architect opens a rework part
   file in the affected stage's design directory. The rework part
   file references the prior-stage contract from Part 1, the
   upstream change that triggered the rework, and the contract gap
   the rework must close.
2. The rework follows the standard stage workflow (Design,
   Implementation, Test, Closure) but is limited to the contract
   gap. Broader redesign opens as a new stage through the standard
   intake.
3. The Developer writes a rework implementation plan in the affected
   stage's implementation log. The rework plan follows the same
   shape as the original stage plan but is scoped to the contract
   gap.
4. The rework evidence lives in the affected stage's implementation
   log. The Stage 11 implementation log records the rework list, the
   status of each rework, and the close date.
5. When more than one upstream change maps to the same prior stage,
   the Architect opens a single rework. A second rework opens only
   when a later Stage 11 cycle surfaces a new contract gap.

Exit criteria: every REWORK-REQUIRED entry has an opened rework with
a status recorded in the Stage 11 implementation log, or has been
reclassified by Manager as a known gap with a follow-up owner and
target cycle.

### Step 5: regression test scope

Owner: QA. Reviewer: Developer. Approver: Architect and Manager.
Inputs: design Part 5, the rework part files from Step 4 (when
reworks are open), the test plan Parts 10 through 13, and the
`coverage-report.md` `## Combined result` and `## Product-only
result` blocks (after the `run_coverage.ps1` prerequisite closes).

Activities:

1. Run the minimum regression scope for the no-rework case, narrowed
   to the test plan parts whose prior-stage contract touched a path
   the merge changed. The minimum scope is in
   [part-02-evidence-plan-and-risks.md](part-02-evidence-plan-and-risks.md).
2. For each closed rework, run the expanded scope the rework part
   file records. The expanded scope adds the rework-specific
   evidence on top of the minimum scope for the reworked stage.
3. Record the T114 verdict from the `## Combined result` block, the
   T114a verdict from the `## Product-only result` block, the T115
   per-file aggregation verdict, and the T121 public checkpoint
   admission verdict. The XML root attributes are not the verdict
   source.
4. Open a new test report per execution session. When the regression
   surfaces a FAIL or BLOCKED row, open a paired fixes report.

Exit criteria: every test plan row whose prior-stage contract the
merge touched is on disk with a verdict, and the closure contracts
T114, T114a, T115, and T121 are all PASS.

### Step 6: merge log and Stage 11 closure

Owner: Developer. Reviewer: Architect. Approver: Manager. Inputs: the
pre-merge report, the Manager decisions from Step 2, the merge log
updates from Step 3, the rework list from Step 4, the test report
and evidence from Step 5, and design Part 6.

Activities:

1. Open the merge log with the required sections: cover and metadata,
   decisions, deferred upstream commits, known gaps, conflicts
   encountered, reworks opened, regression evidence, and closure
   status.
2. Record the final triage decision per in-scope commit, with a
   reason that names a prior-stage contract from Part 1. Changes
   from the pre-merge report carry the date and the agent who
   changed the decision.
3. Record the architecture exit criteria from design Part 1 that the
   integration branch has met, and the criteria still open with the
   follow-up action the Manager assigned.
4. Manager records the Stage 11 closure decision in the Stage 11
   implementation log. The closure confirms the integration branch
   satisfies the architecture exit criteria and the prior-stage
   closure contracts.

Exit criteria: the merge log is on disk with every required section
populated, and the Manager has recorded a Stage 11 closure decision
in the Stage 11 implementation log.

## Affected code, docs, and scripts

### Code

The pre-merge analysis is the authoritative list of code paths the
merge touches. The Developer uses the file-glob groups from design
Part 2, "File-glob groups for scope selection," as the scope filter,
not as the integration list. The groups cover:

- Cache controller and modes, cache policy, cold store, and branch
  graph under `tools/server/server-cache-*`,
  `tools/server/server-prompt-cache.*`,
  `tools/server/server-cache-policy-*`,
  `tools/server/server-cache-store-*`,
  `tools/server/server-cache-graph.*`, and
  `tools/server/server-cache-io-worker.*`.
- Speculative decoding under `common/speculative.*`,
  `common/sampling-ext.*`, and `tools/server/server-speculative.*`.
- Server context and slot under `tools/server/server-context.*`,
  `tools/server/server-slot.*`, `tools/server/server-task.*`,
  `tools/server/server-queue.*`, and `tools/server/server-chunk.*`.
- HTTP and routes under `tools/server/server-routes.*`,
  `tools/server/server-utils.*`, and `tools/server/server-http.*`.
- Metrics and observability under `tools/server/server-common.*` and
  `tools/server/server-httplog.*`.
- Common argument parsing under `common/arg.*` and `common/common.*`.
- Sampling and grammar under `common/sampling.*` and
  `common/grammar-parser.*` (only when the commit also changes a path
  the cache layer reads from).

The pre-merge report's per-commit triage table produces the concrete
file list the merge is expected to touch. The Developer does not list
specific files in this plan; the pre-merge report owns that list.

### Documentation

- `._design_docs/` tree, with the per-stage doc trees the reworks
  touch. The Stage 11 implementation log, the pre-merge report, and
  the merge log live under `._design_docs/`.
- `tools/server/README.md`, `tools/server/README-dev.md`,
  `tools/server/bench/README.md`, `tools/server/tests/README.md` when
  a rework or a NO-OP, INTEGRATE, DEFER, or REVERT decision changes
  the operator surface, the developer surface, the benchmark setup, or
  the public test surface. Stage 11 does not change these documents as
  part of the merge; a rework that does is a contract gap and opens a
  rework of the stage that owns the document.

### Scripts

- `._design_docs/cache-handling-test-scripts/run_coverage.ps1`. The
  T114a row requires the script to emit the `## Product-only result`
  block in `coverage-report.md` per the test plan Part 13 required
  script behavior. This is the prerequisite Developer gate in
  [part-04-prerequisites.md](part-04-prerequisites.md).
- Other scripts the reworks touch. The rework part file for each
  rework names the script, the change, and the contract the change
  protects.

## Handoff state

Implementation planning is drafted. The pre-merge report, the merge
execution, the rework Stage N work, the regression reruns, the merge
log, the test plan, the implementation review, the test report, and
the QA execution remain closed until the implementation-plan review
and the Manager implementation-plan gate both pass.
