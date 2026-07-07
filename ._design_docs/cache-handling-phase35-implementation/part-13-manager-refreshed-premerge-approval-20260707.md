# Stage 35 Manager refreshed pre-merge approval 2026-07-07

Verdict: PASS for refreshed pre-merge analysis. Merge execution remains
blocked until the next clean-tree gate.

## Inputs

- [Refreshed pre-merge analysis](part-11-refreshed-pre-merge-analysis-20260707.md)
- [Refreshed pre-merge analysis review](part-12-refreshed-pre-merge-analysis-review-20260707.md)
- [MTP/KV/speculative rework design](../cache-handling-phase35-design/part-04-rework-mtp-kv-speculative-20260707.md)
- [Manager source-ref decision](part-10-manager-source-ref-decision-20260707.md)

## Decisions

| ID | Decision |
| --- | --- |
| D35-REFRESH-01 | Accept the Architect PASS in part 12. Finding counts are 0 blocking, 0 non-blocking, and 0 informational. |
| D35-REFRESH-02 | Accept refreshed source tip `6c487e2f79dea747d70325250121e750ed364b2b`, 312 total upstream commits, 91 filtered commits, and decision counts `13/68/10/0/0`. |
| D35-REFRESH-03 | Add `024c46ae4e37` (`llama: fix quantized kv-cache for dsv4 (#25202)`) to the existing MTP/KV/speculative rework track. No separate DeepSeek V4 track is opened. |
| D35-REFRESH-04 | Keep `6c487e2f79de` (`server: enforce prompt cache RAM limit (#25070)`) as INTEGRATE with focused prompt-cache, hybrid opt-in, checkpoint, and route/session scans during merge implementation. |
| D35-REFRESH-05 | Keep the planning-only dirty-tree exception for current docs. The real merge still requires a clean tree and explicit approval before any cleanup or merge commit. |

## Handoff

Next owner: Manager / user.

Next gate: clean-tree gate before Developer merge execution.

The refreshed analysis is approved, but current planning docs are dirty.
Manager must obtain explicit approval for a cleanup commit or another clean-tree
path before delegating merge execution.
