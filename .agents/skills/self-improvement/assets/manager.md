# Manager improvement memory

## Improvement: stage gate reconstruction

Condition:
- When starting or resuming a staged delivery workflow from manager mode

Action:
- Do reconstruct progress from `document-index.md`, the requested stage source, and the latest durable prior-stage implementation, fix, and test-report evidence before selecting exactly one active gate; at closure, compare earlier blocked reports against later reconciliation reports before deciding, treat stale entry-document statuses or a missing durable closure decision as gate-blocking documentation work, and explicitly state whether any docs were changed.
