# Cache handling Phase 27 implementation log

Status: closed; Manager gate decision D-CLOSURE-27-01 2026-06-26
Date: 2026-06-26
Stage: 27 (D-EXEC-24-03 Heap Corruption Fix in tx_save Path)
Owner: Manager (closure) and Architect (closure sweep)
Source design: [cache-handling-phase27-design.md](cache-handling-phase27-design.md) + parts 01..05
Scope: implementation log for Stage 27 enqueue-only demotion leak fix.
Current gate: terminal (Stage 27 closed)

## Scope

This log records Stage 27 implementation evidence. The stage was opened
by user direction 2026-06-26 ("Close the current stage and open a next
one dedicated to bugfixing") after Stage 26 closure D-CLOSURE-26-01 was
reverted (D26-REOPEN-01) when D-EXEC-24-03 heap corruption continued to
reproduce on every Stage 24 rerun. Stage 27 fixed D-EXEC-24-03 by
replacing an enqueue-only demotion path that leaked hot memory under
the Stage 25 worker retirement (Option B) with the synchronous inline
`tx_demote_payload` variant.

The cascade: Stage 26 closed -> D26-REOPEN-01 -> Stage 27 opened ->
D-EXEC-24-03 fix applied -> Stage 24 -07 verification PASS -> Stage 27
closed per D-CLOSURE-27-01.

## Architecture invariants preserved

- I-25-01 atomicity, I-25-02 isolation, I-25-03 durability-within-transaction (Stage 25).
- F-21-EXEC-01 save only prompt tokens (Stage 21).
- F-21-RERUN-01 descriptor tracking (Stage 21).
- F-22-DR-01 demotion coordination (Stage 22).
- D-EXEC-26-02 function-scope argv vector (Stage 26).
- Stage 26 cold-store per-id accounting (`cold_payload_bytes_by_id_`).

## Contents

| Part | Title | Author | Status |
| --- | --- | --- | --- |
| [part-10](./cache-handling-phase27-implementation/part-10-manager-closure-20260626.md) | Manager closure record D-CLOSURE-27-01 | Manager | this session |

No earlier implementation parts were authored for Stage 27: the
Developer went straight from approved design (parts 01..05) to fix
application and verification. The fix evidence is recorded in the
test reports [.test_reports/test-report-20260626-05.md](.test_reports/test-report-20260626-05.md)
through [.test_reports/test-report-20260626-07-fixes.md](.test_reports/test-report-20260626-07-fixes.md)
and summarized in part-10.

## Hard constraints (binding)

- DO NOT modify existing test reports, fixes files, or developer reviews.
- DO NOT modify tracker or document-index except as required for this closure sweep.
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part file under 300 lines.

## Handoff

Stage 27 closed per D-CLOSURE-27-01 on 2026-06-26. Next owner: user
(commit approval). See
[part-10](./cache-handling-phase27-implementation/part-10-manager-closure-20260626.md)
for the closure record, per-row final classification, Manager
decisions verbatim, code change summary, and follow-up tasks. Per
AGENTS.md and prior closures (D-CLOSURE-24-01, D-CLOSURE-25-01,
D-CLOSURE-26-01, D-CLOSURE-26-02), AI agents do not commit or push
without explicit user approval.
