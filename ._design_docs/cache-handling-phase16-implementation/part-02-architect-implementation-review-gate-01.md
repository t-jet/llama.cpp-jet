# Stage 16 implementation part 2: architect implementation review gate 01 (chat-path prompt-span boundary fix)

Status: PASS
Date: 2026-06-16
Stage: 16 (post-closure chat-path prompt-span boundary fix)
Reviewer: Architect (fresh session)
Scope: implementation review of commit `ae2df9657` on `tools/server/server-context.cpp`. Code change is already applied; this review verifies conformance to the approved design and the five handoff checklist items.

## Verification checklist

Five items from implementation plan Handoff section. Each verified against the current code state, not just the design description.

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Boundary added at correct point in `cache_metadata_from_chat_messages` (after per-message loop, before `return metadata`) | PASS | `server-context.cpp:4486-4498` is the new block. Per-message loop closes at `server-context.cpp:4484` (`}` of `for (const auto & message : messages)`). New code ends at `server-context.cpp:4498`. `return metadata;` is at `server-context.cpp:4500`. Diff hunk `@@ -4483,6 +4483,20 @@` confirms 14-line insertion in the correct span. |
| 2 | Conditional `!messages.empty()` correct | PASS | Function returns early on `!messages.is_array()` at `server-context.cpp:4395` (degraded_reason set, no boundaries). Empty `messages` array is an array, so it falls through. Per-message loop is a no-op on empty array (zero iterations). New conditional at `server-context.cpp:4495` skips the new boundary when `messages` is empty, matching the loop's no-op. Behavior uniform: zero boundaries emitted on empty `messages` regardless of which path runs. |
| 3 | Checksum function call uses same parameters the strict validator uses | PASS | `cache_metadata_checksum(tokens, 0, n_prompt_tokens)` at `server-context.cpp:4496`. Function definition at `server-context.cpp:4359-4373` is byte-for-byte identical to `cache_token_span_checksum` at `server-cache-hybrid.cpp:204-215`. Both: same FNV-1a 64-bit init `1469598103934665603ull`, same mul `1099511628211ull`, same `cache_token_ids()` call, same clamp `std::min(token_start, ...) / std::min(std::max(token_end, token_start), ...)`, same loop body. Strict validator calls `cache_token_span_checksum(entry.tokens, boundary.token_start, boundary.token_end)` at `server-cache-hybrid.cpp:2996` and rejects on mismatch (line 2997). The new boundary's checksum will match the validator's recompute. |
| 4 | No other code path in chat path or fallback path affected | PASS | Fallback path at `server-cache-hybrid.cpp:cache_metadata_for_request` (called from `server-context.cpp:4515-4522`) is unchanged: still emits `MESSAGE_START` and `MESSAGE_END` at `[0, tokens.size()]` with `metadata = "prompt"` and `cache_metadata_checksum(tokens, 0, tokens.size())`. Per-message loop in `cache_metadata_from_chat_messages` (lines 4411-4484) is unchanged. The only mutation is the new boundary block at lines 4486-4498. |
| 5 | Existing unit tests in `tests/test-cache-controller.cpp` unaffected | PASS | `grep_search` for `cache_metadata_from_chat_messages` in the test file returns zero matches. `grep_search` for `cache_metadata_checksum` returns zero matches. `grep_search` for `cache_token_span_checksum` returns zero matches. All 20+ uses of `prepared_prompt_metadata` in tests construct it directly via `add_span` and use a local `token_checksum` helper at `test-cache-controller.cpp:27-35`. The chat path function is internal to `server-context.cpp`; tests do not link to it. No test recompile required, no test logic affected. |

All five items PASS. Total: 5 PASS, 0 FAIL.

## Findings

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-16-IR-01 | INFO | Line references in approved design/implementation drift by 1-3 lines vs current state | Plan says `server-context.cpp:4392` (early return) — actual `server-context.cpp:4395`. Plan says `server-cache-hybrid.cpp:2997` (checksum call) — actual `server-cache-hybrid.cpp:2996`. Plan says `cache_token_span_checksum` at `server-cache-hybrid.cpp:204-217` — actual `204-215`. Semantic claims hold. | None required for PASS. Optional: tighten line numbers in any future evidence doc. Drift reflects off-by-N between the design's reference and the post-fix code; the code is correct, the references are stale-by-3. |
| F-16-IR-02 | non-blocking | Test plan rows TP-15-UT1 and TP-15-UT2 still missing from durable test plan | Implementation plan Tests section lists 9 proposed rows (TP-15-PC1..PC7, TP-15-UT1, TP-15-UT2). Design review F-16-02 flagged this. Test plan integration is the QA owner's next action, not Developer's at this gate. | QA picks up TP-15-UT1 and TP-15-UT2 in test plan follow-up. No blocker for implementation review gate. |
| F-16-IR-03 | INFO | Comment block is 9 lines, addresses reader of the fix history | `server-context.cpp:4486-4494`. Comment is technically the kind AGENTS.md flags ("explains a non-obvious invariant" — prompt-span boundary is not obvious without reading the design). | None. Comment is justified: it tells the next reader why the boundary exists (assistant role header has no boundary, first end-of-prefill checkpoint needs one). References to the two design docs are not addresses-to-user, they are pointers to the durable record. Acceptable. |
| F-16-IR-04 | INFO | Diff hunk header `@@ -4483,6 +4483,20 @@` shows 20 lines in new file, 6 in original | hunk starts at `}` of the inner `if` at line 4483, runs through blank line 4485, then 14 added lines (4486-4499), then `return metadata;` at line 4500. The 6 unchanged lines are 4483-4488. The 20 new lines are 4483-4502. | None. Diff format is correct. |

Counts: BLOCKING 0, non-blocking 1, INFO 3.

## Code review

Style and AGENTS.md adherence:

- **Concise code, no restating**: the new block is 5 lines of code (`if` line, `const` line, `add_span` line, closing `}`, blank). One new variable (`prompt_checksum`). The block adds what it must: one boundary, no debug output, no logging, no metric.
- **Naming**: `prompt_checksum` is local and self-describing. The `MESSAGE_END` type is reused from the existing enum, matching the per-message boundaries' type. The `"prompt"` metadata string matches the fallback path's value at `server-context.cpp:4520-4521`. Consistent.
- **Comment quality**: 9-line comment block. AGENTS.md says comments should be sparse and not restate the code. This comment does not restate the code; it documents a non-obvious invariant (the first end-of-prefill checkpoint has `n_tokens` = full prompt size, per-message boundaries do not cover that, the prompt-span boundary exists to fill the gap). The two cross-references to `._design_docs/.../part-09-...md` are pointers to the durable design record, not addresses to a future user. Acceptable per AGENTS.md "explains a non-obvious invariant" guidance.
- **Style consistency**: the new block sits between the per-message loop and `return metadata;` in the same indentation level as the surrounding code. No new includes, no new forward declarations, no header changes.
- **Adherence to scope rules**: the implementation matches the approved design (Option A, surgical) exactly. The matching loop is unchanged. The strict validator is unchanged. The fallback path is unchanged. The public API, CLI flags, and metrics are unchanged. No drift into Option B (relax matching loop) territory.
- **Public surface**: no new symbols exposed. `cache_metadata_checksum` was already declared and defined in the chat path module; the new code reuses it. No header changes.
- **Defensive coding**: the `!messages.empty()` guard correctly handles the empty-array case (matches the per-message loop's no-op). The `cache_metadata_checksum` function itself clamps `token_start` and `token_end` to `token_ids.size()`, so a degenerate `n_prompt_tokens == 0` would compute a deterministic hash over zero tokens, not crash. No defensive code needed beyond what the checksum function already provides.

No code style, naming, or AGENTS.md violations found.

## Test plan readiness

Proposed rows in the implementation plan (TP-15-PC1..TP-15-PC7, TP-15-UT1, TP-15-UT2) are adequate for QA verification:

| Row | Coverage | Adequate |
| --- | --- | --- |
| TP-15-PC1 | `n_checkpoint_payload_descriptors > 0` on chat path with MTP fixture after first save | Yes — verifies the fix took effect at the cache-stats layer |
| TP-15-PC2 | `cache_checkpoint_admissions_total{mode="hybrid"} > 0` after first chat-completion save | Yes — verifies the public Prometheus counter increments |
| TP-15-PC3 | `cache_checkpoint_admission_failures_total{mode="hybrid"}` no increase on chat path | Yes — verifies the strict validator no longer rejects |
| TP-15-PC4 | `cache_n > 0` on 29/30 or 30/30 subsequent identical chat requests | Yes — verifies the end-to-end cache hit |
| TP-15-PC5 | multi-turn `cache_n > 0` on subsequent identical requests | Yes — extends the per-message boundary coverage to multi-turn |
| TP-15-PC6 | `/completion` (native) regression: `cache_n > 0` with MTP fixture | Yes — guards against the fix breaking the native path |
| TP-15-PC7 | 5 `n_ctx_seq` warnings unchanged | Yes — guards against the fix changing the model load |
| TP-15-UT1 | Structural unit test: 3-message input, assert `MESSAGE_END` boundary at `[0, n_prompt_tokens]` with `metadata == "prompt"` | Yes — locks the metadata shape at the unit-test level |
| TP-15-UT2 | Degenerate: empty `messages` array, assert no prompt-span boundary added | Yes — locks the `!messages.empty()` guard |

All 9 rows are present in the implementation plan's Tests section. The structural unit tests (TP-15-UT1, TP-15-UT2) are non-blocking but recommended. The operational rows (TP-15-PC1..PC7) are required for PASS. No additional rows required.

No missing rows identified. Test plan integration is the QA owner's next action.

## Verdict

**PASS.** Implementation review for Stage 16 closes with 0 BLOCKING findings. The code change matches the approved design exactly. All five handoff checklist items verified against the current code state. Code style, naming, and comment quality conform to AGENTS.md. No drift into Option B territory. No public surface changes.

## Handoff

Next owner: **Manager** (implementation-plan gate decision).

Manager records the implementation-plan gate decision in this part file. The implementation-plan gate is the decision point after the implementation review PASS, before the test-plan integration and QA verification.

After Manager's implementation-plan gate decision:

- QA picks up test plan integration: adds TP-15-PC1..PC7, TP-15-UT1, TP-15-UT2 to the durable test plan (per design part-09 Test plan rows proposed section).
- QA runs verification per implementation plan Evidence plan section: build verification, unit test (TP-15-UT1, TP-15-UT2), integration test (TP-15-PC1..PC3), benchmark rerun (TP-15-PC4..PC7).
- After QA verification, Manager revisits Manager decisions A, B, C per implementation plan Manager decisions section. Decision A (reclassify B02/B05/B06 to IN-SCOPE for MTP fixture) reopens if TP-15-PC1, PC2, PC3, PC4 all PASS.

If this gate had been REWORK, the next owner would be Developer in a new fresh session. The Developer would re-author the code change to address any BLOCKING findings. No BLOCKING findings exist.

Architect verdict recorded here. Implementation review gate complete.

## Manager implementation-gate decision

Date: 2026-06-16
Verdict: **PASS** (implementation gate approved)
Recorded by: Manager

Decision text (verbatim):

> Implementation review approved. Stage 16 advances from `implementation-planning` to `test-planning`. The 0 BLOCKING, 1 non-blocking (F-16-IR-02 test plan rows TP-15-UT1/TP-15-UT2 still missing from durable test plan; QA picks up) and 3 INFO findings do not block gate progression. All 5 handoff verification checklist items PASS.
>
> F-16-IR-01 (line-number drift by 1-3 lines in approved design vs current code) is INFO only; semantic claims hold. No code change required.
>
> Next gate: test planning (QA, fresh session). QA integrates TP-15-PC1..PC7 and TP-15-UT1/TP-15-UT2 into a new part-26 of the test plan (per implementation plan Manager decision B recommendation), defines test automation scripts, defines coverage measurement (per user reminder about test coverage), defines evidence and report format, and defines clean-build rules. Then QA runs a fresh-session test-plan review. Then Manager test-plan gate. Then QA test execution. Then Developer test-results review. Then Manager revisits decisions A, B, C based on QA output.

Tracker row updated to `test-planning` status, Manager gate decision `2026-06-16 (implementation gate)`.
