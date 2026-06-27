# Stage 28 implementation: technical debt removal + open bug fixes

Status: closed; Manager gate decision D-CLOSURE-28-01 2026-06-27
Date: 2026-06-26
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Author: Developer (implementation)
Source design: [cache-handling-phase28-design.md](cache-handling-phase28-design.md) + parts 01..05
Manager gate: D28-DESIGN-01 (2026-06-26); amendment D28-DESIGN-01-AMD (2026-06-26)
Current gate: terminal (Stage 28 closed)

## Scope

This implementation plan covers Stage 28, the consolidation stage
opened by user direction 2026-06-26 to remove all technical debt and
fix all known open bugs discovered during Stages 24-27. Stage 28
does NOT introduce new architecture, new CLI flags, new endpoint
schemas, or new metric names. It fixes what is broken and cleans
what is stale.

The plan covers three HIGH severity bugs (R28-BUG-01 test artifact,
R28-BUG-02 cold-store metric drift, R28-BUG-03 ASan LNK2038), one
HIGH severity code retention (R28-BUG-04 async worker with phased
deletion A/B/C), five MEDIUM severity tech debt items in iteration
2 (R28-TD-01..04, R28-TD-06..07), and one conditional MEDIUM
(R28-TD-05 worker thread deletion, gated on R28-BUG-04 Phase B
compile-clean). The 11 LOW severity items are out-of-scope.

Out of scope (carried forward or deferred to a future stage):

- 11 LOW severity cosmetic items (R28-TD-08..18) per design part-01.
- New hybrid cache features or policy changes.
- Public CLI flag, endpoint schema, or metric name changes.
- Runner contract changes beyond the R28-TD-04 leak_scan fix and
  R28-TD-07 --crash-dump-dir pass-through.
- Test plan additions (TP-28-UT-01..03 will be tracked in the test
  plan as a separate durable doc update per part-04).
- Document-index entry for Stage 28 (added at closure sweep, not
  in this planning session).

## Inherited invariants

Stage 28 must preserve these already-fixed invariants:

- F-21-EXEC-01: prompt-only save/lookup keeps exact repeats as
  exact hits, not unsafe prefix candidates.
- F-21-RERUN-01: demoting payloads count against hot budget
  until hot bytes are released.
- F-22-DR-01: demote_payload already-demoting check precedes
  generic non-hot rejection.
- I-25-01 atomicity, I-25-02 isolation, I-25-03 durability-
  within-transaction (Stage 25).
- D-EXEC-26-01: SEH handler installed before any cold-store
  mutation; crash dump written to --crash-dump-dir.
- D-EXEC-26-02: function-scope argv vector for crash-dump-dir;
  cold-store per-id accounting via cold_payload_bytes_by_id_.
- D-EXEC-27-08: mark_payload_kind_evicted calls
  tx_demote_payload (NOT legacy demote_payload) at
  tools/server/server-cache-hybrid.cpp:3396.

## Stage 27 closure context

Stage 28 opens from Stage 27 closure per D-CLOSURE-27-01 with three
follow-up tasks carried forward:

- (a) TP-26-UT6 test artifact fix (now R28-BUG-01).
- (b) S02 hybrid cold-store metric vs filesystem drift, 5.37 GiB
  vs 512 MiB (now R28-BUG-02 with mandatory diagnosis step).
- (c) AddressSanitizer infrastructure LNK2038 mismatch (now
  R28-BUG-03, side-channel build-cuda-asan only).

Stage 27 implementation is UNCOMMITTED per AGENTS.md; Stage 28
implementation will be UNCOMMITTED too until the user approves
a combined commit. If the user commits Stage 27 between Stage 28
design and implementation, Stage 28 must rebase to the new HEAD
and re-verify all line numbers against the committed state (per
R28-RISK-01).

## Approved baseline

- [Stage 28 design](cache-handling-phase28-design.md): Architect
  design PASS and Manager design gate PASS (D28-DESIGN-01),
  amended 2026-06-26 (D28-DESIGN-01-AMD) to include R28-BUG-04
  async worker code retention after inventory revealed 2 broken
  production paths and the 41+ test refs to debug_*_io_worker_for_tests.
  Five design files cover tech debt inventory, per-bug fix design,
  prioritized fix order, verification plan, and risks.
- [Stage 27 closure](cache-handling-phase27-implementation/part-10-manager-closure-20260626.md):
  three follow-up tasks carried into Stage 28 (now R28-BUG-01..03
  plus R28-BUG-04 from amendment).
- [Stage 27 fix evidence](.test_reports/test-report-20260626-07-fixes.md):
  S03 hybrid leg 687 reqs vs 258 crash threshold (2.65x past
  failure point); S02 hybrid cold-store 5.37 GiB vs 502 MiB metric
  drift = pre-existing D-EXEC-24-03-c = R28-BUG-02 root cause data.

## OQ decisions (verbatim)

These decisions are recorded for Manager implementation-plan gate:

- OQ-28-01 (R28-BUG-02 defer): DEFER-NO. Fix in Stage 28 iter 1.
  Iterate diagnosis if root cause is more involved than the 3
  candidates.
- OQ-28-02 (iter 2 in scope): YES. User direction "remove all
  technical debt" includes MEDIUM items.
- OQ-28-03 (runner fixes iter 1 vs iter 2): ITER-2. Runner fixes
  do not unblock HIGH fixes.
- OQ-28-04 (LOW prose typos bundled): BUNDLE-NO. LOW out-of-scope
  per design part-03.
- OQ-28-05 (R28-TD-05 in scope): YES-conditional. R28-TD-05 worker
  thread deletion in iter 2, conditional on R28-BUG-04 Phase B
  compile-clean in iter 1.
- OQ-28-06 (R28-BUG-04 Phase A sync vs rebuild async): SYNC.
  tx_promote_payload synchronous under cache_state_mutex_.
  Reopen if Stage 24 -08 rerun shows restore latency > 2x current.

## Contents

| Part | Title | Status |
| --- | --- | --- |
| [part-01a](./cache-handling-phase28-implementation/part-01a-steps-1-5.md) | Ordered implementation steps 1-5 (R28-BUG-01..04 phase A) | this draft |
| [part-01b](./cache-handling-phase28-implementation/part-01b-steps-6-10.md) | Ordered implementation steps 6-10 (R28-BUG-04 phase B + R28-TD-01..07) | this draft |
| [part-02](./cache-handling-phase28-implementation/part-02-affected-files.md) | Per-step affected files, estimated line count, test impact | this draft |
| [part-03a](./cache-handling-phase28-implementation/part-03a-steps-1-5-evidence.md) | Evidence plan steps 1-5 (build + test + Stage 24 -08 contract) | this draft |
| [part-03b](./cache-handling-phase28-implementation/part-03b-steps-6-10-evidence.md) | Evidence plan steps 6-10 + Stage 24 -08 binding contract | this draft |
| [part-04](./cache-handling-phase28-implementation/part-04-risks-and-oq-resolutions.md) | Per-step risks, OQ-28-01..06 resolutions, worst-case per step | this draft |
| [part-05](./cache-handling-phase28-implementation/part-05-open-questions.md) | 5 open questions for Manager review | this draft |

Note: parts 1 and 3 were split (part-01 to part-01a/part-01b,
part-03 to part-03a/part-03b) to comply with the 300-line
durable-doc cap. Reading order is 01a -> 01b, 03a -> 03b.

## Hard constraints (binding)

- DO NOT modify production code in this session (PLAN ONLY).
- DO NOT modify runner, test plan, document-index, or tracker.
- DO NOT commit or push (per AGENTS.md).
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part file under 300 lines.
- git diff --check clean on every file at close.

## Handoff

Next owner: Manager (implementation-plan gate review). After gate
PASS: Developer (implementation iter 1, then iter 2). After
implementation PASS: QA (regression + Stage 24 -08 rerun). After
QA PASS: Manager (closure per D-CLOSURE-28-01, conditional on user
commit approval per AGENTS.md).

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
