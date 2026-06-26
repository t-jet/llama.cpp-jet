# Stage 27 design entry: D-EXEC-24-03 heap corruption fix in tx_save path

Status: closed; Manager gate decision D-CLOSURE-27-01 2026-06-26
Date: 2026-06-26
Stage: 27 (D-EXEC-24-03 Heap Corruption Fix in tx_save Path)
Owner: Architect (design); Developer (implementation); Manager (closure)
Source design: parts 01..05 in this directory
Scope: bugfix-only stage dedicated to fixing D-EXEC-24-03 heap corruption per Manager decision D27-DESIGN-01 (2026-06-26) and user direction "Close the current stage and open a next one dedicated to bugfixing."
Stage 27 closed 2026-06-26 per D-CLOSURE-27-01; implementation log at [cache-handling-phase27-implementation.md](cache-handling-phase27-implementation.md).

## Goal

D-EXEC-24-03 reproduces on every Stage 24 rerun after Stage 25 closure: the server exits with STATUS_HEAP_CORRUPTION (0xC0000374) at request 258 of the S03-chat hybrid leg, between `s03-exact-0-0` (last OK, cache_n=15) and `s03-exact-0-1` (first failed). The Stage 26 commit (4556965c7) shipped a candidate fix in `admit_latest_checkpoint_and_store_metadata` but has NOT been verified against the failure signature. Stage 27 confirms the candidate, finishes the fix if the candidate is incomplete, and proves the regression is closed by a focused test plus a fresh Stage 24 rerun.

## Constraints (binding from D27-DESIGN-01)

- ONE bug class: heap corruption in the tx_save path. No scope creep.
- Preserve Stage 25 atomic transactional semantics (no background ops, tx_save is the canonical save entry point).
- Preserve Stage 22 invariants F-21-EXEC-01 (prompt-only save) and F-21-RERUN-01 (descriptor tracking).
- Preserve Stage 26 carry-over fixes D-EXEC-26-01 (SEH handler), D-EXEC-26-02 (argv function-scope vector), and the cold-store per-id accounting fix.
- Minimal fix: one function modification preferred; multi-function only if evidence forces it.
- Bugfix-only: do not rename metrics, do not change the runner, do not change the test plan, do not touch Stage 26 docs.

## Root cause (one-line)

Wasteful `entry.checkpoints = checkpoints; checkpoints.clear();` pattern in `admit_latest_checkpoint_and_store_metadata` allocates and immediately frees a ~50 MiB payload-sized buffer per save; under sustained hybrid checkpoint admission on the MTP fixture, this trips the Windows heap manager and produces STATUS_HEAP_CORRUPTION on the next allocation. The Stage 26 commit replaced this pattern with a metadata-only copy that never allocates the payload buffer, but the fix has not yet been verified against the S03 hybrid failure.

## Architecture invariants preserved

- I-25-01 atomicity, I-25-02 isolation, I-25-03 durability-within-transaction (Stage 25).
- F-21-EXEC-01 save only prompt tokens (Stage 21).
- F-21-RERUN-01 descriptor tracking (Stage 21).
- F-22-DR-01 demotion coordination (Stage 22).
- D-EXEC-26-02 function-scope argv vector (Stage 26).
- Stage 26 cold-store per-id accounting (cold_payload_bytes_by_id_).

## Contents

| Part | Title | Status |
| --- | --- | --- |
| [part-01](./cache-handling-phase27-design/part-01-root-cause-analysis.md) | Root cause analysis: crash signature mapped to tx_save path | this draft |
| [part-02](./cache-handling-phase27-design/part-02-fix-design.md) | Fix design: minimal modification + verification path | this draft |
| [part-03](./cache-handling-phase27-design/part-03-regression-test.md) | Regression test design: deterministic heap-corruption reproducer | this draft |
| [part-04](./cache-handling-phase27-design/part-04-verification-plan.md) | Verification plan: clean build, unit tests, Stage 24 rerun -05 | this draft |
| [part-05](./cache-handling-phase27-design/part-05-risks.md) | Risks and open questions | this draft |

## Hard constraints (binding)

- DO NOT modify production code in this design session.
- DO NOT modify test plan, tracker, document-index, runner, or Stage 26 docs.
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part file under 300 lines.
- `git diff --check` clean on every file at close.

## Handoff

Stage 27 closed per D-CLOSURE-27-01 on 2026-06-26. Next owner: user (commit approval). Implementation log: [cache-handling-phase27-implementation.md](cache-handling-phase27-implementation.md); closure record: [part-10](./cache-handling-phase27-implementation/part-10-manager-closure-20260626.md). Code changes UNCOMMITTED per AGENTS.md; user approval required for commit. Follow-ups: TP-26-UT6 test artifact fix (D-EXEC-27-09); S02 hybrid cold-store drift (D-EXEC-24-03-c); ASan infrastructure cleanup.
