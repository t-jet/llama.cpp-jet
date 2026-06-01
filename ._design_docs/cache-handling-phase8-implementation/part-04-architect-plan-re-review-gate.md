# Architect Plan Re-Review Gate — Stage 8 Implementation Plan

**File:** `part-04-architect-plan-re-review-gate.md`
**Date:** 2026-05-31
**Reviewer:** Architect agent
**Stage:** cache-handling-phase8-implementation
**Gate type:** Implementation-plan re-review (post-correction)

---

## Scope

Re-review of the corrected `part-01-implementation-plan.md` against the three
findings recorded in `part-03-architect-plan-review-gate.md`:

| Finding | Type       | Status   |
|---------|------------|----------|
| B1      | Blocking   | RESOLVED |
| N1      | Non-block  | RESOLVED |
| N2      | Non-block  | RESOLVED |

---

## Finding B1 — Manager Design Gate PASS

**Source:** `cache-handling-phase8-design/part-06-manager-design-gate.md`

**Evidence:**

- Gate verdict: PASS
- Open findings: 0
- Manager explicitly recorded "Proceed to implementation planning"
- Design entry doc gate table updated: `Stage 8 manager design gate | PASS`

**Verdict:** ✅ RESOLVED. The design gate is closed. Implementation planning
may proceed.

---

## Finding N1 — 5-Step Pressure Order in Step 8.9

**Original finding (part-03-architect-plan-review-gate.md):**
Step 8.9 (branch-metadata budget enforcement) lists dependencies as
"Steps 8.1, 8.2" but the design Part 2 budget model specifies a 5-step
pressure order that includes payload demotion (Stage 6) and payload
eviction (Step 8.1) before metadata pruning (Step 8.2). The plan should
clarify that budget enforcement calls both eviction and pruning in the
correct order, not just pruning.

**Corrected text (part-01-implementation-plan.md, Step 8.9):**

```text
Budget enforcement follows the design's 5-step pressure order: demotion,
payload eviction, cold cleanup, metadata pruning, then admission rejection
or over-budget diagnostics. This means `enforce_metadata_budget` is not a
standalone pruning call — it is the final step in a pressure pipeline that
first tries to free hot-payload RAM (demotion to cold), then cold payload
storage (eviction), then orphaned cold metadata (cleanup), before resorting
to metadata pruning. If all four relief steps fail to bring the cache under
budget, the enforcement rejects new metadata admission or emits over-budget
diagnostics.
```

**Verdict:** ✅ RESOLVED. The 5-step pressure order (demotion → payload
eviction → cold cleanup → metadata pruning → admission rejection) is
correctly documented and matches the Stage 8 design Part 2 budget model.

---

## Finding N2 — Cold Cleanup Ownership Check Location in Step 8.10

**Original finding (part-03-architect-plan-review-gate.md):**
Step 8.10 (cold cleanup ownership safety) lists affected files including
`server-cache-store-cold.h/.cpp` but does not specify whether the ownership
query is a new method on the cold store or a forest-level check that
iterates retained nodes. The design Part 4 says "prove descriptor ownership
before deletion" but does not mandate where the check lives.

**Corrected text (part-01-implementation-plan.md, Step 8.10):**

```text
The ownership check is a **forest-level method** (`cleanup_cold()` on
`branch_forest_index`), not a cold-store method. It iterates all retained
branch nodes in the forest, collects referenced descriptor IDs, and passes
the safe-to-delete set to the cold store. This keeps the ownership logic
co-located with the topology it protects and avoids giving the cold store
visibility into branch-graph internals. The cold store receives only a
simple "delete these IDs" call.
```

**Verdict:** ✅ RESOLVED. The ownership check is explicitly a forest-level
method (`cleanup_cold()` on `branch_forest_index`). Affected files are
correctly listed: `server-cache-graph.h/.cpp` (forest method),
`server-cache-store-cold.h/.cpp` (batch `delete_ids()`), and
`server-cache-hybrid.cpp` (caller).

---

## Overall Verdict

| Criterion | Status |
|-----------|--------|
| B1: Manager design gate PASS                 | PASS   |
| N1: 5-step pressure order correct            | PASS   |
| N2: Forest-level ownership check specified   | PASS   |
| All findings resolved                        | PASS   |
| Implementation plan internally consistent    | PASS   |
| Implementation plan aligns with design       | PASS   |
| No new findings introduced                   | PASS   |

**VERDICT: ✅ PASS — Implementation plan is approved.**

**Handoff:** Proceed to implementation. The Developer agent may begin coding
against `part-01-implementation-plan.md`. Next gate: Manager
implementation-plan approval.

---

## Checklist

- [x] B1 verified — manager design gate recorded as PASS with 0 open findings
      in `cache-handling-phase8-design/part-06-manager-design-gate.md`
- [x] N1 verified — Step 8.9 documents the 5-step pressure pipeline
      (demotion → eviction → cold cleanup → pruning → rejection)
- [x] N2 verified — Step 8.10 specifies `cleanup_cold()` as a forest-level
      method with `delete_ids()` on the cold store
- [x] No new findings introduced by corrections
- [x] Implementation plan is internally consistent
- [x] Implementation plan aligns with design documents
- [x] Re-review artifact produced (this file)
- [x] Entry doc and index updated

---

## Remaining Findings

**None.** All findings from the original review are resolved. No new findings
were identified during re-review.
