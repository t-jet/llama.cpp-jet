# Part 2: Conflict patterns and resolution playbook

Source: [../upstream-merge-guide.md](../upstream-merge-guide.md)

## 1. Conflict resolution policy

The Developer follows three rules when the merge tool surfaces a conflict.

1. **Hybrid and legacy default preservation.** The Developer must not resolve a conflict in a way that changes the opt-in default behavior, the legacy default path, the namespace key, the pair-state contract, the residency contract, the descriptor validation contract, the cold store integrity contract, the branch graph contract, the metadata-only and re-materialization contract, the checkpoint payload contract, the workload profile contract, the public Prometheus metric set and label shape, the bounded diagnostic fields, or the OWASP mitigations. A conflict that would force any of those changes is a rework candidate, not a resolution candidate. The exact contract names depend on the affected stage's design; substitute the stage-specific list when applying the rule.
2. **Local-first for hybrid / local-feature mode.** When an upstream change conflicts with a hybrid-mode or local-feature local change, the local change is the resolution unless the upstream change is itself a REWORK-REQUIRED decision with an Architect-approved integration plan. The Developer records the conflict, the local code that won, the upstream SHA, and the contract the resolution preserves.
3. **Upstream-first for legacy / default path.** When an upstream change conflicts with a legacy-mode or default-path local change, the upstream change is the resolution unless the legacy-mode local change is required to keep the feature gate isolated from the legacy path. The Developer records the conflict, the legacy-mode impact, and the test that proves the legacy path is unchanged.

The Developer must not resolve a conflict by deleting code, by commenting out a path, or by inserting a runtime no-op without recording the choice in the merge log with the contract the resolution preserves. Any such choice is also recorded in the merge log as a follow-up item for a later rework.

## 2. Conflict types the playbook covers

| Type | What the merge tool catches | What it misses | Where the playbook covers it |
| --- | --- | --- | --- |
| Textual conflict | Yes (the 3-way merge inserts `<<<<<<<` markers) | Nothing extra | Section 3 |
| Semantic duplicate (both parents add the same identifier) | No | Both copies end up adjacent in the file | Section 4 |
| Mechanical rename across many files | The merge tool resolves the file where the rename lands; the call sites in other files are not in the diff | Call sites in other files keep the old name | Section 5 |
| Stale local defensive code that upstream fixed | No | The local's defensive code stays, the upstream's fix lands beside it | Section 6 |
| Divergent fix paths for the same defect | No | Both fixes are integrated; the system has two ways to do the same thing | Section 7 |
| New struct field in upstream that local code uses | No | Local code may compile but read uninitialized memory; or the local's struct layout is incompatible | Section 8 |
| New enum value or new task type | No | Local switches on the enum may fall through | Section 9 |
| New helper function that overlaps with a local helper | No | Both helpers exist; the caller uses one, the other is dead code | Section 10 |
| Symbol rename in a public API | Only at the API boundary | All call sites and doc references need a follow-up sweep | Section 5 |
| Behavior change in a function the local depends on | No | The local continues to call the function and the new return shape or side effect breaks the local path | Section 11 |

A conflict the merge tool does not catch is a "semantic conflict." A semantic conflict surfaces during build, during focused test, or during a production repro. The Developer runs a duplicate scan, a call-site grep, and a focused regression to surface semantic conflicts before the cycle closes. The Architect reviews the scan and the grep in the pre-merge review.

## 3. Textual conflicts

The 3-way merge inserts conflict markers when both parents modified the same region. The Developer resolves each marker by hand, using the policy in section 1.

Resolution pattern:

1. Read the three regions (merge base, local, upstream). The merge base is what both parents started from.
2. Apply the policy. For hybrid-mode files, the local change wins unless the upstream change is a REWORK-REQUIRED integration. For legacy-mode files, the upstream change wins unless the local change is required to keep the gate isolated.
3. Re-add any local content the upstream change removed when the local content is part of a hybrid-mode or local-feature contract. Drop any local content the upstream change replaced when the local content is in a legacy-mode path.
4. Verify the resolution compiles and the focused test that covers the conflict region passes.
5. Record the resolution in the merge log "Conflicts encountered" section: file, conflict type, resolution, local adjustment, prior-stage contract preserved.

The Developer does not use `git checkout --ours` or `git checkout --theirs` blindly. Either is acceptable only when the local side is empty and the upstream side is a clean replacement, or when the upstream side is empty and the local side is unchanged. In any other case, the Developer resolves by hand and records the choice.

## 4. Semantic duplicates (3-way merge cannot detect)

A semantic duplicate happens when both parents add the same identifier (a function, a `const`, a struct member) in the same scope. The merge base has neither; the local adds one; the upstream adds the other; the 3-way merge accepts both and the file ends up with two adjacent copies. The build fails on the second copy with a "redefinition" error.

Surface and fix pattern:

1. Before the merge, list the files both parents modified (`git diff --name-only LOCAL..TRACK` intersected with `git diff --name-only LOCAL_TIP..LOCAL_HEAD` for any post-merge work). The intersection is the highest-risk file set.
2. After the merge, scan the intersection for duplicates. A regex scan of any name appearing twice at file scope is a starting point. A manual scope check rules out methods on different classes, function overloads, and template specializations.
3. For each true duplicate, pick one copy to keep. The kept copy is the one that is byte-identical with the local's working tree, or the one whose lexical position is closer to its natural neighbors. Record the line numbers kept and removed, the upstream commit that added the kept copy, and the upstream commit that added the removed copy.
4. Apply the minimum-diff removal. No insertions. The diff is N lines removed, 0 inserted.
5. Verify the build, the focused test, and the regression rerun. Record the diff in the merge log "Conflicts encountered" section as a semantic conflict.

A build defect fix on a duplicate is itself a commit. The commit is atomic. The commit is reviewed by the Architect before the cycle closes. A duplicate that the prior build halt was masking is also fixed in the same atomic commit, with a Manager authorization for the wider diff. The merge log records the wider scope.

A duplicate whose two bodies are not byte-identical is not a duplicate; it is a divergent fix path. Section 7 applies.

## 5. Mechanical renames across many files

A public API rename in upstream (function name, struct member name, enum value name, macro name) requires a mechanical rename of every call site in the local repo. The 3-way merge handles the file where the rename lands. The other call sites in other files are not in the merge diff and keep the old name.

Surface and fix pattern:

1. Identify the renamed symbol in the upstream commit. Record the old name, the new name, and the upstream SHA.
2. Grep the local repo for the old name. Exclude the upstream-affected file (it is in the merge diff). Exclude build output, third-party dependencies, and vendored code. The remaining matches are the call sites the merge did not touch.
3. Apply a mechanical rename. The rename is a script or a sequence of `replace_string_in_file` calls. The diff is the call sites with the old name replaced by the new name. The diff does not change semantics.
4. Verify the rename did not change any non-call-site match (variable names that happen to share the old name, comments that intentionally reference the old name for historical reasons). The Developer reads each match before applying the rename.
5. Run the focused tests that cover the renamed symbol. Run the regression rerun. Record the rename in the merge log "Conflicts encountered" section with the file list, the line counts, and the test that proves the rename is complete.

A reference to the old name in a doc (a fix report, a design doc, a comment that documents a historical bug) is not a call site. The reference is updated in a follow-up, not in the rename commit. The follow-up is recorded in the merge log "Follow-up items" section.

## 6. Stale local defensive code that upstream fixed

The local fork has a defensive guard, a null check, or a retry loop that addressed a defect the upstream has since fixed in a different way. The merge integrates the upstream fix; the local's defensive guard stays; the system now has both the guard and the fix.

Surface and fix pattern:

1. Identify the local's defensive intent. The intent is the rationale: what defect was the guard preventing, what was the upstream fix's rationale.
2. Compare the two solutions. If the upstream fix subsumes the local's intent, take the upstream verbatim and document the local's intent in a code comment as a follow-up item for a future cycle. Do not delete the local's defensive code in the merge commit; the comment-only adjustment is the local adjustment.
3. If the upstream fix is partial and the local's defensive code catches a case the upstream fix does not, keep both and document the layering: the upstream fix handles the common case, the local's guard handles the edge case the upstream fix does not.
4. If the upstream fix is a refactor that makes the local's defensive code unreachable, take the upstream verbatim and delete the local's defensive code. The deletion is in the merge commit, not in a follow-up. Record the deletion in the merge log.
5. The Architect reviews the resolution and the layering comment. The Manager approves any case where the local's defensive code is kept or deleted.

## 7. Divergent fix paths for the same defect (advanced variant preference)

The local fork and upstream both addressed the same defect, but in different ways. The local's fix is one approach; the upstream's fix is a different approach. The merge integrates both. The system has two ways to handle the same case, which is a maintenance hazard.

Resolution rule: prefer the more advanced variant. The advanced variant is the one that:

- Covers more cases (handles the corner cases the other fix does not).
- Has stronger evidence (more focused tests, more repro coverage, more k6, more production data).
- Has a wider scope (covers related defects the other fix does not address).
- Has a cleaner interface (fewer parameters, fewer side effects, fewer call sites to update).
- Has a smaller surface area (fewer lines, fewer files, fewer dependent changes).
- Has better isolation (does not change behavior in unrelated paths).

When the variants are equivalent on those criteria, the Architect and the Manager decide. The default tiebreaker is: the variant that the local's prior stage closure already reviewed wins. The local's variant is already audited, tested, and known to work; the upstream's variant is new and needs a new review.

The chosen variant replaces the other. The replacement is a minimum-diff commit that deletes the rejected variant and any code that called the rejected helper. The replacement is reviewed by the Architect. The Manager approves.

When the two variants are complementary (each handles a different corner case the other does not), keep both. Document the layering. The layering is reviewed by the Architect. The Manager approves.

The local's prior rationale (the bug report, the focused test, the QA evidence) is preserved in the code as a comment or in the stage's implementation log as a historical record. The upstream's rationale is referenced in the merge log "Conflicts encountered" section. Both rationales are discoverable from the same file.

A divergent fix path that turns into a refactor (the upstream changed the function signature; the local still calls the old signature) is handled by section 5 (mechanical rename) for the signature, and by section 8 (new struct field) for any new parameter the upstream added.

## 8. New struct field in upstream that local code uses

The upstream added a field to a struct the local code uses. The local code may not have the new field. The local code may have an unrelated field at the same offset (struct layout incompatibility).

Surface and fix pattern:

1. Identify the struct in the upstream commit. Record the field name, the type, the default value, and the upstream SHA.
2. Grep the local repo for the struct's name. List every file that constructs, copies, or compares the struct.
3. For each call site, add the new field with the local's existing value or the upstream's default. The addition is a one-line per call site change. The diff is additive.
4. If the local has a different default for the same field, decide which default wins. The default that keeps the local's prior behavior wins unless the upstream's default is required by an Architect-approved integration plan. The decision is in the merge log.
5. Verify the focused tests that exercise the struct. Verify the regression rerun. Record the additions in the merge log.

A struct layout that the local relies on (size of, offset of, alignment of) is fragile. The Developer does not rely on the layout in the local's code. A local use of `sizeof(struct)` or `offsetof(struct, field)` is a follow-up item, not a layout contract.

## 9. New enum value or new task type

The upstream added a new value to an enum the local code switches on. The local's switch has no `case` for the new value. The local's switch may fall through to a default that does not apply.

Surface and fix pattern:

1. Identify the enum in the upstream commit. Record the new value name, the integer value, and the upstream SHA.
2. Grep the local repo for the enum. List every file that switches on the enum.
3. For each switch, add a `case` for the new value. The new `case` either calls the local's existing handler (when the new value is semantically equivalent to a case the local already handles) or calls a new handler the Developer adds. The new handler is the local's interpretation of the new value.
4. When the local's existing handler is a no-op (the new value is a no-op in the local's context), the case is a no-op. The `default` arm is updated to log the unhandled value for traceability. The log is a structured diagnostic field, not a print.
5. Verify the focused tests that exercise the enum. Verify the regression rerun. Record the additions in the merge log.

The new value's semantics are owned by the upstream's design. The local's interpretation is a follow-up if the local needs a different behavior. The follow-up is a rework, not a silent integration.

## 10. New helper function that overlaps with a local helper

The upstream added a helper function (in `common/`, in `tools/`, in `src/`) that overlaps with a local helper of the same purpose. The local's call sites use the local's helper. The upstream's helper is integrated but unused.

Resolution pattern:

1. Compare the two helpers' signatures, behavior, and edge cases. The comparison is in the merge log.
2. When one helper subsumes the other, replace the subsumed helper with the subsuming one. The replacement is a minimum-diff commit that updates the call sites to use the subsuming helper and deletes the subsumed helper. The Architect reviews the signature change. The Manager approves.
3. When neither subsumes the other, keep both. The call sites keep their existing helper. The unused helper is dead code; the Developer records the dead code in the merge log "Follow-up items" section. The dead code is removed in a follow-up commit, not in the merge.
4. When the two helpers are in different namespaces (e.g., one is `static` in a `.cpp`, the other is a public function in a header), the merge is non-conflicting. The local's static helper is unaffected. The upstream's public helper is integrated. The Developer records the redundancy in the merge log.

## 11. Behavior change in a function the local depends on

The upstream changed the return shape, the side effect, or the precondition of a function the local depends on. The local continues to call the function. The new behavior breaks the local's path at runtime, even though the build succeeds.

Surface and fix pattern:

1. The Architect reviews the upstream commit's diff for behavior changes, not just signature changes. The review records the change in the pre-merge report "Triage" column.
2. The Developer grep for the function name in the local repo. The list of call sites is the blast radius.
3. For each call site, adapt the local's code to the new behavior. The adaptation is recorded in the merge log.
4. The Architect reviews the adaptation. The Manager approves any case where the local's prior behavior is preserved by a local workaround rather than by the upstream's new behavior.
5. The focused tests that exercise the call sites are run. The regression rerun includes the new behavior's test.

A behavior change that the Architect did not catch during the pre-merge review and that the focused tests did not catch is a blocker for cycle closure. The Architect opens a rework for the affected stage. The rework follows the standard stage workflow.

## 12. Post-merge duplicate scan

A semantic conflict can hide in a file the merge tool did not flag. The Developer runs the scan below after the merge is complete.

1. For each file in the intersection of `git diff --name-only LOCAL..TRACK` and any post-merge work, run a regex scan for any name appearing twice at file scope. A name with two definitions at file scope is a candidate.
2. For each candidate, read both definitions. Methods on different classes, function overloads, and template specializations are not duplicates. Two `static` functions with the same name and byte-identical bodies are duplicates.
3. For each true duplicate, follow the fix pattern in section 4.
4. Record the scan result in the merge log. The scan is part of the cycle evidence.

The scan is mandatory for any cycle that touches a file the local and the upstream both modified. The scan is optional but recommended for any cycle that touches a file the local modified but the upstream did not, because the local's modification may have introduced a duplicate the Architect did not catch.

## 13. Conflict recording format

Every conflict the cycle surfaces is recorded in the merge log "Conflicts encountered" section with the columns below.

| Column | What it records |
| --- | --- |
| File | The file the conflict lives in. |
| Conflict type | The conflict type from section 2 (textual, semantic duplicate, mechanical rename, stale defensive code, divergent fix path, new struct field, new enum value, new helper, behavior change, other). |
| Resolution | The resolution summary, with the policy rule from section 1 that was applied. |
| Local adjustment | The local code that was added, removed, or modified. The diff hunk. |
| Prior-stage contract preserved | The prior-stage contract the resolution preserves. The contract owner (the stage or the architecture). |
| Test | The focused test that proves the resolution. |
| Date | The date the conflict was recorded. |
