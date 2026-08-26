# Stage 40 implementation plan review

Date: 2026-08-26
Reviewer: Architect (independent session)
Plan: part-01-pre-merge-analysis-20260826.md + part-06-merge-rework-implementation-plan-20260826.md
Status: REWORK

## Summary

Part-01 covers most required sections (metadata, upstream reference verification, commit range, aggregate summary, manager decisions requested, open questions) and the 11 REWORK-REQUIRED assignments are individually plausible against the listed prior-stage surfaces. However, the per-commit triage table required by the guide (part 01 section 5) and the design pre-merge analysis contract is absent: only the 11 REWORK rows plus aggregates are present, so the Architect cannot verify triage correctness for the ~144 INTEGRATE and ~25 NO-OP rows. Part-06 is well-structured (8 phases, 3 rework tracks, semantic scans, regression/evidence matrix, stop conditions), but its Track 1 SHAs do not exactly match part-01 (two of five differ), and the Manager staleness decision D40-PLAN-01 is recorded in neither document, which leaves both in a stale "Manager decides" state. Additional required fields (metadata, `git remote -v`, closure contracts, I-34-01/02 naming) are missing. Corrections are listed below; after they land, the plan is ready for re-review.

## Findings

| ID | Type | Finding | Severity | Contract | Resolution |
| ---- | ------ | --------- | ---------- | ---------- | ------------ |
| F40-PMR-01 | Completeness | Per-commit triage table missing. Only the 11 REWORK rows and aggregate counts exist; no per-row entries for INTEGRATE (~144) and NO-OP (~25) with SHA, subject, matched file-glob group, affected contract, one-line reason, follow-up owner. REWORK rows also lack reason, glob group, and follow-up owner per row. | BLOCKING | design pre-merge analysis contract; guide part-01 section 5 | Developer completes the full per-commit triage table before re-review; add reason/glob/follow-up to each REWORK row. |
| F40-PMR-02 | Consistency | Track 1 SHAs in part-06 differ from part-01: `f5014e1a79d3` vs `f014e1a79d3`; `8c146a836630` vs `8c146a83630`; prefix lengths inconsistent. Execution could route a wrong upstream commit. | NON-BLOCKING | part-06 references part-01 rows | Align plan rows to analysis SHAs; use one consistent truncation (12 chars) everywhere. |
| F40-PMR-03 | Doc state | Staleness decision D40-PLAN-01 (3-commit gap all NO-OP, merge with recorded gap, actual tip `fc35562ba`) is not recorded in part-01 metadata or part-06 entry gates; both remain in "Manager decision needed / Manager resolves" state. | NON-BLOCKING | D40-PLAN-01; D40-INTAKE-04 | Record the decision and disposition in both docs; entry gate re-checks staleness for new commits only. |
| F40-PMR-04 | Metadata | Cover/metadata per guide section 5 lacks owner (Developer), reviewer (Architect), approver (Manager), analysis close date, and integration branch name; "Branch: work-branch" is the working branch, while the merge records on the local default branch. | NON-BLOCKING | guide part-01 section 5 | Add the required metadata fields. |
| F40-PMR-05 | Verification | `git remote -v` output missing from upstream reference verification, required by guide section 2 and the design upstream reference policy. | NON-BLOCKING | guide part-01 section 2; design policy | Add the remote configuration output. |
| F40-PMR-06 | Closure contracts | Aggregate summary omits the Stage 39 closure contracts the design pre-merge contract requires (coverage floor 0.8486, VS2022 conformance gap disposition); VS2022 appears only as decision request 6. | NON-BLOCKING | design pre-merge contract; Stage 39 | Add a closure-contract statement (floor + gap owner). |
| F40-PMR-07 | Contract preservation | Part-06 Track 2 (SSE replay row `1a87dcdc452d`) references Stage 34 replay but does not explicitly name I-34-01/I-34-02 (idempotent saves, `use_count` increments, slow `tx_save` reads outside the mutex, second-pass dedupe). | NON-BLOCKING | I-34-01; I-34-02; Stage 34 | Name I-34-01/I-34-02 in Track 2 and Phase 6 rework closure. |
| F40-PMR-08 | INFO | Filtered count "approx 180" not finalized; open question 3 covers it. | INFO | NA | Resolve before merge setup so the merge command matches the accepted range. |
| F40-PMR-09 | INFO | Working tree "Near-clean"; D40-INTAKE-05 stale items named only by reference in the plan entry gate. | INFO | D40-INTAKE-05 | Name the stale items in the Phase 1 preflight output. |

Triage note: the 11 REWORK assignments and their track mapping (MTP/KV/spec 5, route/session 2, checkpoint 4) are reasonable and consistent with the design's three tracks; no REWORK row looks misclassified, but correct classification of INTEGRATE/NO-OP cannot be confirmed until F40-PMR-01 closes. Open questions 1 and 2 (KV struct layout, second cold-path checkpoint writer) are the right critical unknowns and map to Track 1 and Track 3; no critical open item appears missing beyond the triage table itself.

## Verdict

REWORK - send back to Developer. Merge execution stays blocked (guide part 01 section 5). Required corrections, in order:

1. Complete the per-commit triage table for all in-scope commits (F40-PMR-01) and finalize the filtered count.
2. Align part-06 Track 1 SHAs to part-01 (F40-PMR-02).
3. Record D40-PLAN-01 in part-01 and part-06 (F40-PMR-03).
4. Add missing metadata fields and `git remote -v` output (F40-PMR-04, F40-PMR-05).
5. Add the Stage 39 closure-contract statement (F40-PMR-06).
6. Name I-34-01/I-34-02 in Track 2 (F40-PMR-07).

Next gate: Architect re-review of the corrected part-01 and part-06, then Manager approval, then merge execution authorizes.
