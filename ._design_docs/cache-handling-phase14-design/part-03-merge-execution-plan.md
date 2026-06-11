# Stage 14 design: merge execution plan and conflict resolution -- Part 3

Source: [../cache-handling-phase14-design.md](../cache-handling-phase14-design.md)

## Goal

The merge execution plan is the operational contract for running
the upstream merge. It names the merge command family, the conflict
resolution policy, the build and test command family the Developer
runs between merge steps, and the rule that keeps
`--cache-mode hybrid`, the legacy default path, the Stage 12 stress
harness outputs, the Stage 13 endpoint parity rows, and the MTMD
placeholder path unchanged.

## Merge command family

The merge is a single integration event. The Developer opens a
working state, runs the merge, resolves conflicts, and verifies
the merged tree before closing the integration branch. The exact
commands depend on the fork's local conventions and are not fixed
by this design; the design fixes the command family and the order
in which the Developer applies it.

The merge command family is built from the following steps, in
order:

1. Confirm the working tree is clean and the local default branch
   is checked out at the fork point.
2. Fetch the upstream ref and tags recorded in the pre-merge
   analysis. Per Manager decision D1 (2026-06-04, revised
   2026-06-11), the upstream reference is the remote-tracking ref
   `origin/upstream_master`, used directly. The fetch command is
   `git fetch origin`.
3. Re-confirm the commit range against the fetched
   `origin/upstream_master` ref. If the range changed since the
   pre-merge analysis, the Developer reopens the pre-merge analysis
   and the Architect re-reviews the report.
4. Run the merge into the local default branch. The merge tool
   choice is recorded in the merge log. A fast-forward is
   acceptable only when the pre-merge analysis lists no INTEGRATE
   or REWORK-REQUIRED decisions, because a fast-forward would
   skip the local adjustments those decisions require. A
   `--no-ff` merge commit is required otherwise. The merge is a
   real two-parent merge; the parent SHAs are verified with
   `git rev-list --parents -n 1 <merge-sha>`.
5. Resolve conflicts that the merge tool surfaces. The conflict
   resolution policy is below.
6. Run the local build command family.
7. Run the local regression ctest command family.
8. Re-run the focused exporter coverage command family when the
   pre-merge analysis lists at least one REWORK-REQUIRED or
   INTEGRATE decision that touched a hybrid-mode source file.
9. Update the merge log with the merge command, the conflict
   list, the resolution list, the build result, the test result,
   and the date.

The Developer does not push the integration branch to a remote,
open a PR, or close the Stage 14 gate until step 9 is complete and
the regression evidence in Part 5 is on disk.

## Conflict resolution policy

The conflict resolution policy is the contract the Developer
follows when the merge tool surfaces a conflict. The policy is
built on three rules.

1. Hybrid and legacy default preservation. The Developer must not
   resolve a conflict in a way that changes `--cache-mode hybrid`
   semantics, the legacy default path, the namespace key, the
   pair-state contract, the hot/cold residency contract, the
   descriptor validation contract, the cold store integrity
   contract, the branch graph contract, the metadata-only and
   re-materialization contract, the checkpoint payload contract,
   the workload profile contract, the public Prometheus metric
   set and label shape, the bounded diagnostic fields (including
   the bounded `cache metadata:` format at task launch), the
   diagnostic-source namespace isolation rule, the MTMD
   placeholder path, the Stage 12 stress harness output shape
   (S01..S08, L01..L03), the Stage 12 benchmark output shape
   (B01..B08), the Stage 12 configuration matrix, the Stage 13
   endpoint parity rows E13-01..E13-16, the T114 combined
   coverage floor, the T114a product-only coverage floor, the
   T115 per-file aggregation rule, the T121 public checkpoint
   admission row, or the OWASP mitigations. A conflict that
   would force any of those changes is a rework candidate, not
   a resolution candidate.

2. Local-first for hybrid mode. When an upstream change conflicts
   with a hybrid-mode local change, the local hybrid-mode change
   is the resolution unless the upstream change is itself a
   REWORK-REQUIRED decision with an Architect-approved
   integration plan. The Developer records the conflict, the
   local code that won, the upstream SHA, and the contract the
   resolution preserves.

3. Upstream-first for legacy mode. When an upstream change
   conflicts with a legacy-mode local change, the upstream
   change is the resolution unless the legacy-mode local change
   is required to keep the hybrid-mode gate isolated from the
   legacy path. The Developer records the conflict, the
   legacy-mode impact, and the test that proves the legacy path
   is unchanged.

The Developer must not resolve a conflict by deleting code, by
commenting out a path, or by inserting a runtime no-op without
recording the choice in the merge log with the contract the
resolution preserves. Any such choice is also recorded in the
merge log as a follow-up item for a later rework.

## Build and test command family

The Developer runs the local build and test command family
between merge steps. The design does not fix exact command lines;
it fixes the purpose and the order.

| Step | Purpose | Failure handling |
| --- | --- | --- |
| Local configure | Confirm the build directory exists and the configure step matches the closed-stage build configuration. | A configure failure blocks the merge and is recorded in the merge log. |
| Local build | Compile the integration branch with the same target set used by the closed stages. | A compile failure is a rework candidate unless the failure is a pre-existing failure that the closed stages already documented. |
| Local ctest | Run the focused cache test binaries that the closed stages used for the ctest evidence. | A ctest failure is a rework candidate. The Developer records the failing test name, the assertion, and the contract the test covers. |
| Focused exporter coverage | Run the focused exporter coverage script for the hybrid-mode source files when the merge touched a hybrid-mode path. | A coverage failure against the T114 combined floor (80%) or the T114a product-only floor (70%) is a closure-contract failure, not a rework candidate. The Developer reopens the coverage evidence and the Manager decides whether the failure is a known gap. |
| Stage 12 stress harness preflight | Run the Stage 12 stress harness preflight checks when the merge touched a stress-harness source file. | A preflight failure blocks the merge and is recorded in the merge log; the cycle's stress rerun waits for a Manager decision. |
| Stage 12 benchmark harness preflight | Run the Stage 12 benchmark harness preflight checks when the merge touched a benchmark source file. | A preflight failure blocks the merge and is recorded in the merge log; the cycle's benchmark rerun waits for a Manager decision. |
| Stage 13 endpoint probe | Run the Stage 13 endpoint probe for the E13-01..E13-16 parity rows when the merge touched an endpoint adapter source file. | An endpoint parity failure is a rework candidate. The Developer records the failing row, the request payload, and the contract the row covers. |

The Developer does not run upstream CI, upstream test suites, or
upstream lint configurations as Stage 14 evidence. The Stage 14
closure contract is the prior-stage contracts in Part 1, not the
upstream project's CI matrix.

## Re-execution rules for the merge

The Developer may re-execute the merge from scratch when the
pre-merge analysis is reopened or when the first attempt produced
an unrecoverable conflict. A re-execution is not a rework; it is
part of the merge execution plan. The Developer records the
reason for the re-execution in the merge log.

The Developer does not partially undo a merge commit by rewriting
history. A failed merge is closed with a reverse merge, an
explicit `git reset` to the fork point, or a new merge attempt
from the fork point against the latest upstream tip. The chosen
approach is recorded in the merge log.
