VERDICT: PASS

# Stage 35 pre-merge analysis re-review 2026-07-07

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md) and [part 01](part-01-pre-merge-analysis-20260707.md)

## Scope

Review type: independent Architect re-review after F35-PLAN-01 through
F35-PLAN-03.

Subject reviewed:

- Corrected Stage 35 implementation entry.
- Corrected Developer pre-merge analysis part 01.
- Manager refresh and dirty-worktree decisions in part 03.
- Stage 35 approved design entry.
- Prior failing review part 02.

No merge, fetch, conflict resolution, production code change, regression run,
commit, push, PR, or reviewer response was performed.

## Evidence checked

| Check | Review evidence | Result |
| --- | --- | --- |
| Source ref | `git rev-parse origin/upstream_master` -> `108f186d1701d56133a0239dd6754c8814374cbf` | PASS |
| Actual upstream master | `git ls-remote https://github.com/ggml-org/llama.cpp.git master` -> `108f186d1701d56133a0239dd6754c8814374cbf` | PASS |
| Total range count | `git rev-list --count HEAD..origin/upstream_master` -> `308` | PASS |
| Delta from prior tip | `git rev-list --count 47e1de77aa0f06bf73cfd8c5281d95979f89fcbe..108f186d1701d56133a0239dd6754c8814374cbf` -> `1`; the added commit is `108f186d1` touching SYCL backend/docs files | PASS |
| Filtered table count | Parsed per-commit table rows -> `89` | PASS |
| Aggregate counts | Parsed decisions -> `NO-OP=13`, `INTEGRATE=67`, `REWORK-REQUIRED=9`, `DEFER=0`, `REVERT=0` | PASS |
| Old count mismatch | `rg "6 REWORK\|six REWORK"` across entry, part 01, and part 03 -> no matches | PASS |
| Dirty-worktree exception | Part 03 D35-PREMERGE-02 accepts dirty state only for planning docs; D35-PREMERGE-03 keeps merge execution blocked until clean | PASS |
| Merge authorization | Entry and part 01 still say merge execution is not authorized | PASS |

## Re-review checklist

| Prior finding | Re-review result |
| --- | --- |
| F35-PLAN-01: upstream staleness verdict stale | Closed. Source ref and actual upstream `master` now both resolve to `108f186d1701d56133a0239dd6754c8814374cbf`. |
| F35-PLAN-02: implementation entry said 6 while part 01 said 9 | Closed. Entry and part 01 both use 9 REWORK-REQUIRED candidates. |
| F35-PLAN-03: dirty worktree exception unresolved | Closed for planning gate. Manager recorded a planning-only exception and kept merge execution blocked until cleanup. |

## Findings

No blocking, non-blocking, or informational findings.

## Rework classification review

The 9 REWORK-REQUIRED rows are reviewable enough for Manager routing. Each row
names an upstream SHA, a surface group, a protected contract family, a decision,
and the reason for not treating the item as normal integrate work:

- EAGLE3 speculative decoding: Stage 5 target/draft plus checkpoint/MTP.
- Router model management API: Stage 13 route compatibility.
- Child-router communication: route lifecycle and evidence handling.
- Step3.5/3.7 flash mtp3: Stage 5 MTP and draft-context semantics.
- Model download process: server lifecycle and test harness behavior.
- Checkpoints at every user message: Stage 9 and architecture part 9 boundary.
- SSE replay buffer: Stage 34 branch/session replay evidence.
- DFlash support: target/draft speculative contract review.
- DeepSeek V4: KV-cache and checkpoint contract review.

This is enough for Manager to decide whether to group or downgrade the reworks.
The analysis does not yet choose the final routing, which is correct for this
gate.

## Remaining Manager decisions

Manager still needs to decide:

- Whether all 9 REWORK-REQUIRED candidates open rework parts before merge
  execution, or whether some downgrade to INTEGRATE with focused checks.
- Whether router process changes, model-management API, and SSE session changes
  are one route rework or separate items.
- How checkpoint-at-every-user-message maps to the Stage 9 and architecture
  part 9 prompt-span boundary.
- Whether EAGLE3, Step MTP, DFlash, and DeepSeek V4 share one MTP/KV rework or
  split into separate reworks.
- When and how to clean or commit planning docs before any merge execution,
  because AGENTS.md forbids commits without explicit human approval.

## Decision

Implementation-planning gate state: PASS for corrected pre-merge analysis.

Next owner: Manager.

Allowed next work: Manager pre-merge approval and rework routing decision.

Merge execution, regression reruns, commits, pushes, PRs, and reviewer
responses remain unauthorized until Manager explicitly approves the next step.
