# Phase 5 implementation: BUG-002 restore timing review

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Scope

Review date: 2026-05-28

This is an independent implementation review of the BUG-002 fix for H53/H54 public MTP restore accounting. The review covers `tools/server/server-context.cpp`, `tools/server/tests/unit/test_cache_modes.py`, [Part 15](part-15-bug-002-mtp-restore-timing.md), and [test-report-20260528-08-fixes.md](../.test_reports/test-report-20260528-08-fixes.md).

No build or test command was run for this review. Code and evidence inspection was enough because the Developer report already includes a rebuild, focused pytest run, and public H53/H54 rerun with the Qwen3.5 MTP fixture.

## Verdict

PASS.

The BUG-002 fix is scoped to successful exact hybrid restores. `server_slot::hybrid_cache_restored` is cleared on slot reset and prompt clear, set only after descriptor validation, target/draft state apply, LRU refresh, prompt restoration, and metadata restoration succeed, and then consumed by the prompt loop to expose the restored prompt through `timings.cache_n`.

## Findings

No blocking findings.

Review notes:

- Failed restore paths still return before `hybrid_cache_restored` is set, so descriptor, target apply, draft apply, snapshot, and clear-preflight failures do not report a hit through prompt timing.
- Slot reset and prompt clear clear the marker. That covers normal request completion, slot erase, prompt replacement after a miss, cache-disabled startup, and legacy mode.
- The prompt loop change treats only a successful hybrid restore like prompt reuse when `cache_prompt` is absent. It also skips the checkpoint/SWA replay fallback for that exact restored state, which prevents a valid restore from being replayed back to `n_past=0`.
- Stage 5 transaction semantics remain intact. The fix does not move hit accounting earlier, does not weaken target/draft rollback, and does not alter the legacy cache controller.
- Normal separate draft mode keeps the same target/draft restore contract. The marker is mode-neutral inside hybrid exact restore and does not encode or change speculative decoding policy.
- Public timing now matches the restored prompt state. The H53/H54 rerun evidence shows `cache_n=11` and `cache_n=12` on the repeated requests with one hit, one miss, and zero restore or fallback failures.
- The regression test uses the public `/completion` path, omits `cache_prompt`, asserts `timings.cache_n > 0`, checks prompt work was reduced, and confirms a hybrid hit metric. It does not depend on the marker name or a private implementation hook.
- The fix report and Part 15 do not overclaim. They keep the accepted scope to H53/H54 public MTP acceptance and leave QA confirmation as the next gate.

## Handoff

State: ready for QA confirmation.

QA should rerun H53 and H54 with the Qwen3.5 MTP fixture and confirm that the repeated public request reports `timings.cache_n > 0` with no restore, descriptor validation, pairing, or fallback failures.
