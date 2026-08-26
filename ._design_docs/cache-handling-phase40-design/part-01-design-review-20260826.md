# Stage 40 design review

Date: 2026-08-26
Reviewer: Architect (independent session)
Design: cache-handling-phase40-design.md
Status: PASS

## Summary

Stage 40 defines the operational contract for an upstream merge cycle after Stage 39 closure. The design reuses the Stage 35 template correctly, extends file-glob filters to cover Stages 36-39 surfaces, names prior-stage contracts from Stages 36/38/39 plus earlier durable invariants, and follows the upstream-merge-guide procedure. No blocking contradictions, missing contracts, or gaps that would force the Developer to invent filters were found. Two non-blocking findings and two observations are recorded below.

## Findings

| ID | Type | Finding | Severity | Contract | Resolution |
| --- | --- | --- | --- | --- | --- |
| F40-DR-01 | clarity | Rework routing section (three tracks) misses a one-liner decision rule that maps contract category to track. Without it, a commit breaking both a retention contract and a route lifecycle contract could be routed to the wrong track. Stage 35 had the same omission and required no correction, so this is NON-BLOCKING. | NON-BLOCKING | Stage 40 design section "Rework routing" | Add a one-sentence mapping: "Retention, eviction, coverage floor contracts go to track 3 (checkpoint placement); MTP/KV/draft/isolation to track 1 (MTP/KV/speculative); slot/stream/routing/restore to track 2 (route/session lifecycle)." |
| F40-DR-02 | missing-surface | The "Prefix/checkpoint partial restore" file-glob group cites `tools/server/server-cache-controller.*` and checkpoint/checksum paths but omits `tools/server/server-cache-policy.*`. Stage 38 restore-candidate selection lives in `policy`. The "Two-layer payload retention" group covers `policy` separately, so a Stage-38 restore change would be assigned to the wrong group, risking misattributed triage. | NON-BLOCKING | File-glob paragraph "Prefix/checkpoint partial restore" | Add `tools/server/server-cache-policy.*` to the "Prefix/checkpoint partial restore" group, or add a comment that restore-candidate selection changes route through the "Two-layer payload retention" group. |
| F40-DR-03 | observation | Stage 40 design is not entered in `document-index.md`. Consistent with upstream merge precedent (Stages 14, 35 were similarly absent at design gate). Not a blocker for design review. | INFO | document-index.md | Manager should add the Stage 40 entry during or after the Manager design gate. |
| F40-DR-04 | observation | The file-glob `._test_reports/**` (Coverage/report tooling group) may not match files at `._design_docs/.test_reports/` because the dot-prefix depth differs from the workspace root. Same pattern as Stage 35. | INFO | "File-glob commit filters" table, "Coverage and report tooling" row | Confirm the actual committed depth of test-report files and adjust the glob if needed. |

## Verdict

PASS.

Stage 40 design review PASS with 0 BLOCKING, 2 NON-BLOCKING, 2 INFO findings.

No rework required. Handoff to next gate: Manager design gate.

## Next gate

Manager design gate. The two NON-BLOCKING findings should be addressed before the design gate closes, but they are not blockers against the design revision.