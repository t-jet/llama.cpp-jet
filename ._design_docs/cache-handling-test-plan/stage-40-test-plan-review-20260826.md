# Stage 40 test-plan review

Date: 2026-08-26
Reviewer: QA (independent session)
Plan: part-44-stage40-upstream-merge-regression.md
Status: REWORK

## Summary

Plan covers all 3 rework tracks, Stages 36/38/39 surface, source-ref proof, and clean-build rules. Scope matches design regression contract. Out of scope is correct. 2 NON-BLOCKING defects and 2 INFO items need correction before Manager gate. Most critical: the command checklist has a broken command (backspace char eats the leading 'b'), and the preconditions use `git rev-arse` instead of `git rev-parse`. These are text bugs that will confuse an executor at the terminal. No blocking coverage gaps found.

## Findings

| ID | Type | Finding | Severity | Resolution |
|----|------|---------|----------|------------|
| F1 | Typo | Lines 52-53: `git rev-arse --verify MERGE_HEAD` and `git rev-arse origin/upstream_master`. Should be `git rev-parse` both places. | NON-BLOCKING | Fix both instances to `git rev-parse`. |
| F2 | Broken syntax | Command checklist: control char (backspace 0x08) before `build-cuda\bin\Release\test-cache-controller.exe`. Renders as `"uild-cuda\bin...` - leading 'b' eaten. | NON-BLOCKING | Remove the stray control character. |
| F3 | Wording | TP-40-CORE-01 PASS signal says "Stage 40 routes". Stage 40 is a merge cycle, not a feature stage -- it has no defined routes. Should say "merged routes" or delete the reference. | INFO | Change to "merged route-state rows" or align with Stage 35 precedent "router-state rows". |
| F4 | Genericity | Clean-build section says "Developer CUDA rebuild timed out during implementation session." This ties the plan to a specific past session event. Plan must be generic. | NON-BLOCKING | Replace with: "Full CUDA rebuild may exceed one session." No need to name whose session. |
| F5 | Evidence format | Plan lacks an explicit "Evidence format" section (cf. Stage 35 plan had one). The PASS/FAIL/BLOCKED/PARTIAL classification section is good but doesn't tell the executor *how* to format per-row evidence (raw log paths, HTTP snippets, model paths, etc.). | INFO | Not blocking. Add a brief "Evidence format" section if the author wants. Can also defer to Stage 35 precedent. |

## Contract coverage check

| Contract area | Design reference | Plan rows | Coverage |
|------|------|------|---|
| Clean build + stale-binary | Design "Regression and closure evidence" #1 | TP-40-BLD-01 | OK |
| Source-ref proof + staleness | Design #10 | TP-40-SRC-01 | OK |
| Cache core focused tests | Design #2 | TP-40-CORE-01/02 | OK |
| Track 1: MTP/KV/speculative | Design "Rework routing" #1 | TP-40-MTP-01/02/03 | OK |
| Track 2: Route/session lifecycle | Design "Rework routing" #2 | TP-40-RT-01/02/03 | OK |
| Track 3: Checkpoint placement | Design "Rework routing" #3 | TP-40-CP-01/02 | OK |
| Metrics: bounded, unique HELP/TYPE, hybrid | Design #4 | TP-40-MET-01/02/03 | OK |
| HTTP probes for touched routes | Design #3 | TP-40-RT-01 | OK |
| Focused coverage (0.8486, VS2022) | Design #5 | TP-40-COV-01 | OK |
| Cold-store filesystem | Design #6 | TP-40-CS-01 | OK |
| Checkpoint/MTP admission | Design #7 | TP-40-CP-01/02 | OK |
| Hybrid hit/performance (Stage 36) | Design #8 | TP-40-HYB-01 | OK |
| Stage 34 replay/synthetic | Design #9 | TP-40-AG-01/02 | OK |
| Stages 38/39: two-layer + prefix restore | Design contract table | TP-40-PRS-01 | OK |

All 14 contract surfaces covered. No blocking gap.

### Out-of-scope check

- Part-16/part-18 fix evidence: correctly excluded.
- Upstream CI/test/lint: correctly excluded.
- Replacing local tests: correctly excluded.

## Verdict

**REWORK** -- 2 NON-BLOCKING fixes (F1 typos, F2 control char), 1 NON-BLOCKING wording fix (F4), 2 INFO items (F3, F5). Apply fixes, then re-submit for QA re-review.

Defects:

- F1: `git rev-arse` -> `git rev-parse` (lines 52-53)
- F2: Backspace char before `build-cuda\bin\...` in command checklist
- F4: "Developer CUDA rebuild timed out" -> generic rewording

No blocking coverage gap. Plan structure is solid.

## Next gate

Manager test-plan gate (after REWORK fixes applied and QA confirms).

---

## Re-review 2026-08-26 (QA independent session)

Status: PASS

Re-reviewed part-44-stage40-upstream-merge-regression.md after the author applied the 5 fixes. Verified each fix at byte level in the current file.

| ID | Type | Verification result |
|----|------|--------------------|
| F1 | Typo | Fixed. `rev-arse` count 0, `rev-parse` count 5 (preconditions and command checklist). |
| F2 | Broken syntax | Partially fixed. Backspace 0x08 removed; 0 non-printable control chars remain. One residual: command checklist line still read `uild-cuda\bin\...` (leading 'b' missing, so the copy-paste command stayed broken). QA restored the leading 'b' in this re-review. Now `build-cuda\bin\Release\test-cache-controller.exe`. |
| F3 | Wording | Fixed. PASS signal now says "merged route-state rows" (1 exact hit), no stale "Stage 40 routes" reference. |
| F4 | Genericity | Fixed. 0 hits for "timed out", "Developer CUDA", "implementation session"; clean-build section is generic. |
| F5 | Evidence format | Fixed. "Evidence format" section present (1 hit) with per-row path + verdict label + classification and an example. |

Hygiene: CR bytes 0, bytes >127 0, trailing whitespace 0, line count 184 (under cap). No blocking coverage gap remains.

Verdict: **PASS** -- QA clears the plan to proceed. Note: F2 required a QA edit restoring the missing leading 'b'; the author should ensure the final committed file matches this corrected line.

Next gate: Manager test-plan gate.
