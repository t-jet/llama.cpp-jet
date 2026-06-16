# Stage 16 implementation part 7: bug fix iteration 3 F-16-BF-08 compile error

Status: applied
Date: 2026-06-16
Stage: 16 (chat-path prompt-span boundary)
Branch: work-branch
Scope: compile-error fix only. F-16-BF-08 from [part-06-architect-bugfix-review-iteration-2.md](part-06-architect-bugfix-review-iteration-2.md).
Trigger: Architect review REWORK verdict. F-16-BF-08 BLOCKING: code does not compile.
Related: [part-05-bugfix-iteration-2-mtp-matching.md](part-05-bugfix-iteration-2-mtp-matching.md) (previous fix, left the dead assignment).

## Root cause

F-16-BF-08: `attached_boundary = true;` at
`tools/server/server-cache-hybrid.cpp:3129` assigns to an
undeclared variable.

The F-16-TR-06 bug-fix iteration 2 ([part-05](part-05-bugfix-iteration-2-mtp-matching.md))
replaced the original `bool attached_boundary = false;`
declaration plus single-flag control flow with a
`const prompt_boundary * best_boundary = nullptr;` plus
`if (best_boundary) { ... } else { ... }` structure. The
`attached_boundary` declaration at the start of the
matching-loop block was removed, but the assignment
`attached_boundary = true;` inside the new `if (best_boundary)`
branch was left in place. The new `if (best_boundary)` branch
is the success indicator on its own; the `attached_boundary`
flag served no purpose in the new code.

Verified: `Select-String -Path tools/server/server-cache-hybrid.cpp -Pattern 'attached_boundary'`
returns one match, the assignment at line 3129. The variable
is not a class member, function parameter, or local. Function
`attach_checkpoint_payload` starts at line 3039 and has no
`attached_boundary` declaration. The build will not compile.

Developer in part-05 marked Status: applied without
rebuilding. The build at the start of part-06 was for the
prior F-16-TR-02 fix, not the F-16-TR-06 change (the change
is uncommitted per `git status`).

## Fix

Delete the dead `attached_boundary = true;` line at
`tools/server/server-cache-hybrid.cpp:3129`. One-line fix.
The `if (best_boundary)` branch is the success indicator;
the `else` branch sets `checkpoint_boundary_required = true`
for the strict validator pre-loop check at line 2984 to
reject.

The strict validator at lines 2994-3024 was reviewed in
part-06 item 2 (PASS). It has no `attached_boundary`
reference and needs no change.

No other code in the file references `attached_boundary`
(verified by full-file `Select-String`). No other variable
or function depended on the flag.

## Diff

Deletion only. The block before and after the change at
`tools/server/server-cache-hybrid.cpp:3120-3135`:

```text
                descriptor.boundary_checksum = cache_token_span_checksum(
                    entry.tokens,
                    static_cast<size_t>(descriptor.token_span_start),
                    static_cast<size_t>(descriptor.token_span_end));
-               attached_boundary = true;
            } else {
                descriptor.checkpoint_boundary_required = true;
            }
```

The matching loop logic is unchanged: `best_boundary`
populates the descriptor's `checkpoint_boundary_required`,
`checkpoint_boundary_native`, `checkpoint_boundary_kind`,
`boundary_id`, and recomputed `boundary_checksum`; the
`else` branch sets only `checkpoint_boundary_required = true`
and lets the strict validator's pre-loop check at line 2984
reject. The strict validator's relaxed match mirrors this
block.

### Diff stats

```text
 tools/server/server-cache-hybrid.cpp | 1 -
 1 file changed, 0 insertions(+), 1 deletion(-)
```

## Risks

None expected. One-line deletion of dead code.

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| R-16-BF-08-01 | The deletion removes a side effect that downstream code depended on | None | Verified by full-file `Select-String`: `attached_boundary` has one match in the file (the deleted line). No class member, no function parameter, no other local references the variable. The `if (best_boundary)` branch already sets all the descriptor fields the downstream code reads. |
| R-16-BF-08-02 | The matching-loop logic changes as a side effect | None | The deletion is one line. The remaining `if (best_boundary) { ... } else { ... }` block is byte-identical to part-05 except for the removed `attached_boundary = true;` line. The strict validator mirrors the matching loop and is unchanged. |

## Out of scope

| ID | Finding | Why out of scope |
| --- | --- | --- |
| F-16-BF-09 | [part-09-post-closure-chat-path-prompt-boundary.md](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md) is 354 lines, exceeds 300-line cap | Non-blocking. Document-level. Architect or follow-up Developer session splits into a continuation part. Not blocking the F-16-BF-08 compile fix gate. |
| F-16-BF-10 | part-05 brief R-16-BF-06-04 wording imprecision on checksum re-computation | Non-blocking. Wording is accurate; the "may not match" clause documents the intentional design where the descriptor checksum is recomputed over the actual span. |
| F-16-BF-11 | test_stage9 `bad_id` case relies on the type/metadata filter, not the strict-match branch | Non-blocking. The fix does not affect this test path. |
| F-16-BF-12 | Comment block at server-cache-hybrid.cpp:3087-3101 is 15 lines | Non-blocking. Comment explains a non-obvious invariant. Justified per AGENTS.md. |
| F-16-BF-13 | Brief R-16-BF-06-05 boundary at token_end=0 edge case not present in current fix | Non-blocking. Risk is theoretical; no production or test path emits a `token_end=0` prompt boundary. |
| F-16-BF-14 | Architecture part-09 does not document the n_tokens=11 test case limitation | Non-blocking. Architect follow-up to add a one-line note to the Limitations and known gaps section. |
| F-16-TR-03 | Coverage BLOCKED by Release build without /Zi | Out of scope for compile fix. Manager decision required on whether to add `/Zi /DEBUG` to `CMAKE_CXX_FLAGS_RELEASE` or build a separate RelWithDebInfo target. |
| F-16-TR-01 | UT1/UT2 test code missing in tests/test-cache-controller.cpp | Out of scope. Per test plan Pass/fail criteria, the unit rows are non-blocking for PASS. |

The 61-token MTP test case at n_tokens=11 (Manager decision
option a, b, or c) is out of scope for the compile fix. The
F-16-BF-08 fix does not change admission behavior: the
matching loop still rejects when no "prompt" boundary has
`token_end <= 11` (system prompt-span at ~12, user
prompt-span at ~62, end-of-prompt at 61). The Manager
decides whether to tighten prompt-span coverage, reclassify
the test case, or accept the limitation.

## Handoff

Next owner: **Architect** in a new fresh session for
bug-fix re-review iteration 3. Focus:

1. F-16-BF-08 fix verified: `attached_boundary = true;` line
   deleted at `tools/server/server-cache-hybrid.cpp:3129`.
   The variable is no longer referenced anywhere in the
   file.
2. Code compiles (Developer did not rebuild per scope; QA
   rerun validates the build).
3. Matching-loop relaxation unchanged from part-05. The
   deleted line was a no-op after the `if (best_boundary)`
   branch populated the descriptor.
4. Strict validator unchanged from part-05. No
   `attached_boundary` reference there.
5. test_stage9 contract preserved: the strict match for
   non-prompt boundaries (metadata != "prompt") is unchanged.
   The `bad_span` and `id_mismatch` assertions continue to
   hold.

After Architect PASS on the F-16-BF-08 compile fix, the next
gate is **QA** in a new fresh session for the test rerun.
The Manager decision on the 61-token MTP test case at
n_tokens=11 is required before QA rerun. The Developer
handoff to the Manager should include this part-07 record
plus the part-06 caveat analysis. The Manager decides on
test reclassification (option b), prompt-span tightening
(option a), or accepted limitation (option c).

This part-07 record does not address F-16-BF-09 through
F-16-BF-14, F-16-TR-03, F-16-TR-01, or the 61-token MTP
Manager decision. Those are separate work items owned by
their respective agents and gates.
