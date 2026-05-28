# Manager improvement memory

## Improvement: stage gate reconstruction

Condition:
- When starting or resuming a staged delivery workflow from manager mode

Action:
- Do reconstruct progress from `document-index.md`, the requested stage source, and the latest durable prior-stage implementation, fix, and test-report evidence before selecting exactly one active gate; at closure, compare earlier blocked reports against later reconciliation reports before deciding, treat stale entry-document statuses or a missing durable closure decision as gate-blocking documentation work, and explicitly state whether any docs were changed.

## Improvement: memory-first startup

Condition:
- When an incoming task requires self-improvement memory loading before task work

Action:
- Do read the self-improvement skill and agent memory file before sending any progress update or starting task-specific inspection.

## Improvement: closure stale-status sweep

Condition:
- When closing a stage after QA rerun or bug-fix evidence changes the stage state

Action:
- Do search linked parent docs and stage parts for stale status phrases such as `current gate`, `ready for QA`, `open`, and `blocked`; update durable entry docs, test-plan scope notes, and index descriptions so they match the closure decision, but treat older report-local next-action text as historical when a later entry doc or reconciliation part explicitly supersedes it.

## Improvement: codex delegation flags

Condition:
- When delegating a fresh agent session through `codex exec`

Action:
- Do pass global CLI options such as `--cd`, `--sandbox`, and `-a never` before the `exec` subcommand, then pass the prompt with `exec -`; use a timeout long enough for documentation edits and, if the wrapper times out, inspect the worktree and target deliverables before deciding whether to rerun; don't put global options after `exec`.
