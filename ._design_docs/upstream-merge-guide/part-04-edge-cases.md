# Part 4: Edge cases, advanced variants, and post-closure follow-ups

Source: [../upstream-merge-guide.md](../upstream-merge-guide.md)

## 1. Advanced variant preference (summary)

When the local fork and upstream both addressed the same defect in different ways, the cycle prefers the more advanced variant. The criteria for "advanced" are in part 2 section 7. The default tiebreaker is the local's prior-stage closure evidence, which is already audited, tested, and known to work. The local's variant is preferred over the upstream's variant when both are equivalent on the criteria, because the local's variant carries a known-good audit trail.

When the two variants are complementary (each handles a different corner case the other does not), both are kept. The layering is documented. The Architect reviews the layering. The Manager approves.

The chosen variant replaces the rejected variant. The replacement is a minimum-diff commit. The Architect reviews the replacement. The Manager approves.

The local's prior rationale is preserved in the code as a comment or in the stage's implementation log as a historical record. The upstream's rationale is referenced in the merge log. Both rationales are discoverable from the same file.

## 2. New upstream features that modify local features

The upstream added a feature that the local's features depend on. The local's features must adapt to the new feature. The adaptation is not a rework; it is a local adjustment during the merge.

The pattern:

1. The Architect identifies the local feature the upstream change depends on. The identification is in the pre-merge report "Triage" column, with the prior-stage contract the local feature preserves.
2. The Developer reads the upstream feature's design (the upstream commit message, the upstream PR description, the upstream tests) and identifies the local feature's call sites that need adaptation.
3. The Developer applies the adaptation. The adaptation is additive (a new field, a new parameter, a new code path) or refactorive (a renamed identifier, a restructured control flow). The adaptation is recorded in the merge log.
4. The Architect reviews the adaptation. The Manager approves any case where the local's prior behavior is preserved by a local workaround rather than by the upstream's new behavior.
5. The focused tests that exercise the local feature are run. The regression rerun includes the new behavior's test.

A local feature that the upstream feature subsumes is a candidate for replacement. The replacement is a minimum-diff commit. The Architect reviews the replacement. The Manager approves.

A local feature that the upstream feature does not subsume is a candidate for co-existence. The co-existence is documented. The Architect reviews the co-existence. The Manager approves.

A local feature that the upstream feature breaks is a rework candidate. The rework follows the standard stage workflow.

## 3. Upstream refactorings that break local private contracts

The upstream refactored an internal helper, a private API, a struct layout, or a control flow that the local depends on. The build succeeds (the local's call site is unchanged), but the runtime behavior changes.

The pattern:

1. The Architect reviews the upstream commit's diff for refactorings, not just signature changes. The review records the refactoring in the pre-merge report.
2. The Developer grep for the refactored identifier in the local repo. The list of call sites is the blast radius.
3. For each call site, the Developer verifies the local's behavior under the new internal shape. The verification is a focused test, a code read, or a focused C++ test that exercises the call site.
4. A local call site that breaks under the new internal shape is fixed in the merge. The fix is recorded in the merge log.
5. A local call site that depends on the old internal shape is a rework candidate when the local's behavior is part of a prior-stage contract. The rework follows the standard stage workflow.

A refactoring that the Architect did not catch during the pre-merge review and that the focused tests did not catch is a blocker for cycle closure. The Architect opens a rework for the affected stage.

## 4. Symbol renames in public APIs

The upstream renamed a public API (a function, a struct member, an enum value, a macro). The cycle applies the rename to every call site. The pattern is in part 2 section 5.

The follow-up rules:

- A doc that references the old name (a fix report, a design doc, a comment that documents a historical bug) is updated in a follow-up, not in the rename commit.
- A test that references the old name is updated in the rename commit, not in a follow-up. A test that references the old name after the rename is a build defect.
- A third-party dependency or vendored code that references the old name is out of scope. The cycle does not update third-party code.
- A binary symbol that the local links against (a DLL, a .so) is rebuilt as part of the cycle. A binary symbol that the local does not link against is out of scope.

## 5. Post-closure follow-ups

A bug, an invariant, or a contract gap that surfaces after the cycle closes opens a new part file in the affected stage's design tree. The cycle's design gate does not reopen. The post-closure follow-up opens a new design review gate and a new Manager design gate, both scoped to the follow-up correction only.

The pattern:

1. The Architect opens a new part file in the affected stage's design directory. The part file references the closed cycle's merge log, the post-closure evidence (a crash log, a focused test, a production repro), and the prior-stage contract the follow-up preserves.
2. The Architect reviews the follow-up part file. The review records a verdict in the follow-up part file, not in a separate review document.
3. The Manager records a follow-up design-gate decision in the follow-up part file and links it from the affected stage's design entry doc.
4. The Developer writes a follow-up implementation plan in the affected stage's implementation log. The plan follows the same shape as the original stage plan but is scoped to the contract gap.
5. The Architect reviews the plan. The Manager records a follow-up implementation-plan gate decision.
6. The Developer implements the follow-up. The follow-up evidence is recorded in the affected stage's implementation log.
7. The Architect reviews the follow-up implementation. The QA executes the follow-up evidence. The Architect reviews the test report. The Manager records a follow-up closure decision in the affected stage's implementation log.

A follow-up that grows beyond a contract gap opens as a new stage through the standard stage intake. A follow-up that is itself a rework for the same contract gap is merged with the original rework into a single rework.

A follow-up that is itself a new upstream merge cycle opens a new implementation log that points to this guide for procedure and to the affected stage's design for the prior-stage contract list.

## 6. Architecture-level invariants

Some invariants are durable across stages. The invariants live in the architecture, not in any single stage's design. The cycle preserves the architecture-level invariants. An upstream change that would weaken an architecture-level invariant is a rework candidate, not a silent integration.

Examples of architecture-level invariants:

- The opt-in default for any feature flag.
- The legacy default path for any feature.
- The namespace key shape for any feature's identity.
- The pair-state contract for any feature that pairs two contexts.
- The residency contract for any payload that lives in hot, cold, or branch-metadata storage.
- The descriptor validation contract for any payload the cache saves.
- The cold store integrity contract for any file the cold store writes.
- The branch graph contract for any shared forest.
- The metadata-only and re-materialization contract for any branch node.
- The checkpoint payload contract for any checkpoint the cache saves.
- The workload profile contract for any profile the cache detects.
- The public Prometheus metric set and label shape.
- The bounded diagnostic field set.
- The OWASP mitigations.
- The deterministic test seams.
- The coverage floors (combined and product-only).
- The per-file aggregation rule.
- The public admission row for the MTP or checkpoint path.

A new architecture-level invariant is added to the architecture's invariants section, not to a stage's design. The Architect opens a new part file in the architecture directory for the invariant. The invariant is reviewed by the Architect. The Manager approves.

## 7. Stale upstream tracking branch

The local tracking branch (e.g., `upstream_master`) can lag behind the upstream remote. The lag is a known gap. The Manager decides whether to fast-forward the tracking branch first or merge with the gap and re-sync after.

The fast-forward path:

1. The Developer fetches the upstream remote (`git fetch <remote>`) and fast-forwards the tracking branch (`git fetch <remote> <ref>:<tracking>` or `git push . <ref>:<tracking>`).
2. The Developer re-runs the pre-merge analysis on the refreshed range. The Architect re-reviews the report.
3. The cycle continues with the refreshed range.

The gap path:

1. The Developer records the gap in the merge log "Decisions" section, with the missing upstream SHAs, the upstream commit subjects, and the file-glob group matches.
2. The Developer merges with the gap. The cycle continues with the gap.
3. After the cycle closes, the Developer re-syncs the tracking branch. The re-sync is a fast-forward, not a merge.
4. The follow-up for the re-sync is recorded in the merge log "Follow-up items" section. The follow-up owner is the Developer. The target cycle is the next cycle.

A gap that grows between the cycle's pre-merge analysis and the regression rerun is a known gap. The Manager decides whether the gap invalidates the regression evidence or is a follow-up for the next cycle.

## 8. Upstream CI matrix adoption (not done)

The cycle does not adopt the upstream CI matrix as a closure contract. The cycle's closure contract is the prior-stage contracts, not the upstream project's CI matrix.

The reasons:

- The upstream CI matrix tests upstream behavior, not the local fork's hybrid-mode or feature-mode behavior.
- The upstream CI matrix runs on the upstream's platform set, not the local fork's host platform.
- The upstream CI matrix does not test the local fork's prior-stage contracts.
- Adopting the upstream CI matrix as a closure contract would force the local fork to keep upstream behavior identical, which is the opposite of the fork's purpose.

The Developer does not run upstream CI, upstream test suites, or upstream lint configurations as cycle evidence. The Developer does run the local build, ctest, focused exporter coverage, public HTTP probe, k6, and OWASP table as cycle evidence. The evidence is the local fork's evidence, not the upstream's.

## 9. Replacement of local tests with upstream tests (not done)

The cycle does not replace local fork tests with upstream tests. The local fork tests are owned by the affected stage's design and are part of the prior-stage closure evidence.

The reasons:

- The local fork tests exercise the local fork's hybrid-mode or feature-mode behavior, not the upstream's default behavior.
- The local fork tests are part of the prior-stage closure evidence. Replacing them would invalidate the prior-stage closure.
- An upstream test that covers a path the local fork test covers is additive, not a replacement. The local fork test stays. The upstream test is added. The cycle's evidence cites the local fork test.

The Developer does not delete a focused test binary during the merge, even when the upstream change makes the test surface smaller. The Developer does not replace a local focused test with an upstream test, even when the upstream test is more comprehensive. The Developer adds the upstream test alongside the local focused test.

## 10. History rewrites (not done)

The cycle does not rewrite the integration branch's history. A failed merge is closed with a reverse merge, an explicit `git reset` to the fork point, or a new merge attempt from the fork point. The chosen approach is recorded in the merge log.

The reasons:

- History rewrites break the link to the prior-stage commits, the prior-stage closure evidence, and the prior-stage contracts.
- History rewrites break the link to the local's working tree, which may have uncommitted edits the Developer needs to preserve.
- History rewrites break the link to the upstream's commit history, which the cycle needs to reference for triage reasons.
- History rewrites are not auditable. The audit trail of a rebased branch is harder to reconstruct than the audit trail of a merge.

A reverse merge, an explicit `git reset`, and a new merge attempt are all auditable. The merge log records the chosen approach. The Architect reviews the chosen approach.

## 11. Working tree state at cycle open and close

The cycle opens with a clean working tree. Uncommitted edits are a blocker. The Developer stashes, commits, or discards the edits before the cycle opens. The cycle's pre-merge report records the working tree state at open.

The cycle closes with a clean working tree. Uncommitted edits from the cycle are a blocker. The Developer commits the edits as cycle commits, with the Architect's review. The cycle's merge log records the working tree state at close.

A cycle that opens or closes with a dirty working tree is a citation error. The Architect flags the dirty state. The Manager rejects the cycle until the dirty state is resolved.

## 12. CRLF/LF worktree preservation

The cycle's merges preserve the worktree's line-ending format. A file that is LF in the worktree stays LF. A file that is CRLF in the worktree stays CRLF. The Developer reads the worktree's line endings before applying a patch and applies the patch in the same format.

A patch that introduces CRLF in a file the worktree keeps as LF is a line-ending rewrite. The rewrite is recorded in the merge log. The Architect reviews the rewrite.

A patch that introduces LF in a file the worktree keeps as CRLF is a line-ending rewrite. The rewrite is recorded in the merge log. The Architect reviews the rewrite.

A build target that emits CRLF (e.g., MSVC with specific settings) is verified post-build. The build artifacts' line endings are recorded in the cycle's build evidence.

## 13. Multiple reviewers and sign-off

A cycle with multiple reviewers (Architect, Manager, Developer, QA) is the standard cycle. The cycle's sign-off is the sequence of reviews and approvals in the cycle's implementation log.

A cycle with a single reviewer (e.g., a small cycle with no rework) is allowed. The single reviewer's verdict is the cycle's sign-off. The cycle's merge log records the single-reviewer exception with the Manager's approval.

A cycle with a third-party reviewer (e.g., a security review, a benchmark review) is allowed. The third-party reviewer's verdict is part of the cycle's evidence. The cycle's merge log records the third-party review.

A cycle with no reviewer is a blocker. The Architect does not start the cycle without a reviewer. The Manager does not close the cycle without a sign-off.

## 14. Cycle reuse across stages

This guide is reusable across stages. A new stage that adds a new feature to the fork follows the same procedure. The pre-merge analysis uses the new stage's file-glob groups. The triage reasons cite the new stage's prior-stage contracts. The merge log records the new stage's closure contracts.

A new stage that the prior stages did not address (a cross-cutting concern, a new feature, a new layer) opens a new stage design through the standard stage intake. The new stage's design is reviewed by the Architect. The Manager approves. The new stage's implementation follows the standard stage workflow. The cycle that includes the new stage in the pre-merge range cites the new stage's design for the prior-stage contract list.

A new cycle that re-opens the upstream merge activity (because the tracking branch is stale, because a new upstream release shipped, because a new bug surfaced) points to this guide for procedure and to the affected stage's design for the prior-stage contract list. The cycle does not re-derive the procedure.

## 15. Open questions and follow-up pointers

A cycle that surfaces a question the Architect cannot answer during the pre-merge review records the question in the pre-merge report "Open questions" section. The Manager decides. The decision is recorded in the merge log.

A cycle that surfaces a question the Architect can answer but the cycle does not close records the question in the merge log "Follow-up items" section. The follow-up owner is the Developer or the Architect, depending on the question. The target cycle is the next cycle.

A cycle that surfaces a question the next cycle should answer records the question in the affected stage's implementation log "Open questions" section. The next cycle's pre-merge report reads the question and addresses it.

A follow-up that grows into a rework or a new stage opens through the standard stage intake. A follow-up that is itself a cycle opens a new implementation log. A follow-up that is a doc correction opens a new part file in the doc tree.
