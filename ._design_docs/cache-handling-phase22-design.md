# Stage 22 design: demotion coordination refactor

Status: Manager design gate PASS; implementation planning open
Date: 2026-06-18
Stage: 22 (Demotion Coordination Refactor)
Owner: Architect
Source trigger: D21-EXEC-07, user-directed Tek Option 2 after F-21-RERUN-02
Baseline: current dirty worktree on `work-branch`; do not revert Stage 21 fixes

## Contents

This document is under the 300-line cap. No part files are needed.

## Scope

Stage 22 refactors demotion coordination in `tools/server/server-cache-hybrid.cpp`.
The immediate defect is F-21-RERUN-02: the Stage 21 heavy rerun found six
warnings where `handle_demotion_completion` received a completion after the
payload descriptor was already `cold` instead of `demoting`, plus three exact
repeat restores blocked by "payload is demoting".

The design covers these affected surfaces:

- `demote_payload`
- `mark_payload_kind_evicted`
- `handle_demotion_completion` (the log prefix and some reports abbreviate this
  as `handle_demot_completion`)
- descriptor tracking in `payload_descriptors`, `hot_payloads`, entry payload
  ids, and branch node sync
- focused unit tests in `tests/test-cache-controller.cpp`
- heavy rerun evidence for Stage 21 exact-repeat restore

Out of scope:

- new cache policy
- new public CLI flags or public metric names
- broad Stage 21 closure
- HV-expanded heavy profile
- prompt text or chat template changes

## Inherited invariants

Stage 22 must preserve these already-fixed Stage 21 invariants:

- F-21-EXEC-01: prompt-only save/lookup must keep exact repeats as exact hits,
  not unsafe prefix candidates. Unit coverage TP-21-UT1..UT3 remains binding.
- F-21-RERUN-01: demoting payloads still count against resident hot budget, and
  `resident_payload_bytes` is not zeroed until hot bytes are actually released.
  Unit coverage TP-21-UT4..UT6 remains binding.
- Stage 5 pairing: target/draft payloads move as one descriptor-owned unit.
- Stage 6 cold I/O: worker writes cold files asynchronously; controller owns the
  authoritative descriptor transition.
- Stage 8 graph rules: payload eviction and branch pruning stay separate.
  Metadata-only nodes remain valid only after descriptor ownership is clear.
- Stage 17 cold budget: cold-budget rejection leaves the descriptor hot and does
  not produce partial cold residency.

## Problem statement

Current demotion state is split across the descriptor, hot map, entry cached
bytes, branch node state, and asynchronous completion queue. Stage 21 fixes made
budget accounting correct for demoting payloads, but the coordination path still
allows a stale or duplicate demotion outcome to reach `handle_demotion_completion`
after another path has already made the descriptor `cold`.

That creates two observable symptoms:

- `handle_demotion_completion` rejects a completion with residency `cold`
  instead of treating the completion as idempotent.
- Exact-repeat restore finds the matching prompt-only entry but cannot use the
  payload while the descriptor remains transient or was synchronized in the
  wrong order.

The refactor must make one component own the state machine and make completion
handling idempotent for the expected duplicate/stale completion case.

## Design

### State ownership

The descriptor is the source of truth for residency. Entries and branch nodes are
derived views. `hot_payloads` is the source of truth for whether hot bytes still
exist in memory.

Stage 22 introduces a small internal helper set rather than adding new public
state:

- `sync_payload_owner_views(payload_id)`: refresh every entry that references
  the payload id, then sync branch nodes from those entries.
- `release_hot_payload_after_success(descriptor)`: erase exactly the hot record
  for the descriptor's payload id after a successful demotion.
- `complete_demoted_payload(descriptor, ref)`: set cold store ref, set residency
  to cold, account cold bytes/count, release hot bytes, and sync owner views.

Implementation may choose different helper names, but the ownership contract is
binding.

### `demote_payload`

`demote_payload` keeps this validation order:

1. descriptor exists
2. if descriptor is already `demoting`, reject as an in-flight demotion
3. descriptor is `hot`
4. cold store configured
5. hot record exists
6. target/draft pair is complete when pair state requires it
7. cold budget allows the whole target/draft shape
8. set descriptor to `demoting`
9. enqueue worker write
10. if enqueue fails, restore descriptor to `hot`

Additional Stage 22 requirements:

- Keep `resident_payload_bytes` unchanged while state is `demoting`.
- Do not erase `hot_payloads` before completion success.
- Do not sync branch node as metadata-only when a payload is merely demoting.
- If `demote_payload` sees a payload already `demoting`, treat that as an
  in-flight rejection, not as a new demotion request.

### `mark_payload_kind_evicted`

When cold store is configured and the descriptor is hot, this function should
prefer demotion and return after successful enqueue. That path must:

- call `demote_payload`
- refresh entry payload accounting while resident bytes are still present
- keep entry payload id attached
- keep descriptor bytes nonzero
- avoid falling through to immediate eviction

The immediate eviction path remains valid only when demotion is unavailable or
fails before enqueue. In that path it may set residency `evicted`, zero resident
bytes, erase hot bytes, clear the entry payload id, refresh accounting, and sync
branch nodes as metadata-only or evicted.

### `handle_demotion_completion` / `handle_demot_completion`

Completion handling becomes idempotent and descriptor-driven:

- Missing descriptor: record diagnostic and return. Do not recreate ownership.
- Success with descriptor `demoting`: transition once to `cold`, set cold ref,
  release hot bytes, update cold counters, and sync owner views.
- Success with descriptor already `cold`: treat as duplicate or stale success.
  Record an idempotent completion diagnostic, do not increment cold counters
  again, do not warn as product failure, and do not change hot budget accounting
  except to ensure the hot record is absent.
- Success with descriptor `evicted`: ignore as stale success after immediate
  eviction or cleanup; record a bounded diagnostic only.
- Failure with descriptor `demoting` and hot bytes present: revert to `hot`.
- Failure with descriptor `demoting` and hot bytes absent: mark `evicted`, zero
  resident bytes, refresh/sync owner views.
- Failure with descriptor already `cold`: do not downgrade a valid cold payload.
  Record stale failure diagnostic and leave state cold.

Counters must not double count duplicate completions. Existing public metric
families stay stable; implementation may add internal reason counters only if
already exposed by the stats object without changing public metric names.

### Restore while demoting

Stage 22 does not implement blocking restore waits. If a repeat request arrives
while the payload is still `demoting`, restore may return bounded
`payload_unavailable`. After completion processing, the same exact repeat must be
able to restore from cold or promoted state according to existing restore flow.

## Tests

Add focused unit coverage before heavy rerun:

| ID | Test | Required assertion |
| --- | --- | --- |
| TP-22-UT1 | Demotion success transitions once | `demoting` -> completion success -> `cold`; hot bytes released; resident bytes no longer counted hot; branch node synced. |
| TP-22-UT2 | Duplicate success idempotent | second success completion for same payload leaves state `cold`, does not double count cold bytes/count, and emits no "not in demoting state" warning path. |
| TP-22-UT3 | Stale success after evicted | completion success after immediate eviction does not crash, does not restore ownership, and keeps descriptor or entry in evicted/metadata-only state. |
| TP-22-UT4 | Failure with hot bytes reverts | demotion failure while hot record exists returns descriptor to `hot` and keeps resident bytes counted. |
| TP-22-UT5 | Failure after hot release evicts | demotion failure with no hot record marks evicted, zeroes resident bytes, and syncs branch node. |
| TP-22-UT6 | Stage 21 invariant pack | TP-21-UT1..UT6 still pass unchanged after the refactor. |
| TP-22-UT7 | Target/draft completion stays paired | `target_and_draft` demotion completion succeeds, then duplicate success stays idempotent; pair state, target bytes, draft bytes, cold counters, and entry/branch owner views remain coherent. |
| TP-22-UT8 | Already demoting reject is in-flight | calling `demote_payload` on a `demoting` descriptor takes the in-flight rejection path before generic non-hot rejection and asserts the focused diagnostic/counter behavior. |

The tests may use existing debug hooks. If a hook is missing, add the smallest
test-only hook needed to inject a completion result and inspect residency,
resident bytes, hot record presence, and relevant counters.

## Observability

Implementation evidence must capture:

- no `descriptor not found for payload_id` warnings during rerun
- no `payload_id X is not in demoting state (residency=4)` warnings during rerun
- exact repeats req-008, req-009, and req-010 lookup exact matching entries
- prompt evidence JSONL remains redacted and bounded
- public metric names remain unchanged
- any new internal diagnostic reason is bounded and documented in the
  implementation log

## Acceptance

Design gate acceptance:

- this design exists, is indexed, and is under 300 lines
- Stage 22 tracker row is ordered after Stage 21 and says design authored,
  pending review
- Stage 21 remains paused for Stage 22 refactor, not closed

Implementation acceptance:

- focused unit tests TP-22-UT1..UT8 pass
- existing 97 `test-cache-controller` tests still pass, including TP-21-UT1..UT6
- `git diff --check` is clean for touched files
- no public endpoint schema, CLI flag, or public metric-name change

QA acceptance:

- rerun Stage 21 HV-chat-feasible profile with Stage 22 binary
- F-21-RERUN-01 remains PASS: zero descriptor-not-found warnings
- F-21-RERUN-02 is fixed: zero demoting-state mismatch warnings
- req-008, req-009, and req-010 produce `cache_n > 0` or a Manager-approved
  bounded result if cold promotion latency still requires a second retry row
- TP-21-HV2 comparison is updated against Stage 16 and Stage 20 baselines

## Rollback

Rollback is file-scoped:

- revert only Stage 22 edits in `tools/server/server-cache-hybrid.cpp`
- revert only Stage 22 tests in `tests/test-cache-controller.cpp`
- keep F-21-EXEC-01 prompt-only save tests and behavior
- keep F-21-RERUN-01 descriptor tracking tests and behavior
- leave Stage 21 paused until a replacement design or Manager decision exists

If rollback is needed after implementation starts, Developer must record which
Stage 22 test failed and whether F-21-EXEC-01 or F-21-RERUN-01 regressed.

## Handoff

Next owner: Manager for design gate.

After design review PASS, Manager decides whether to open implementation
planning. Developer must not start production refactor work until the Manager
design gate is recorded.

## Design review gate 01

VERDICT: REWORK

Date: 2026-06-18
Reviewer: Architect
Scope: Stage 22 design only, checked against requirements, architecture,
Stage 21 implementation/evidence, current `server-cache-hybrid.cpp`, and current
`test-cache-controller.cpp`.

### Findings

| ID | Severity | Finding | Required correction |
| --- | --- | --- | --- |
| F-22-DR-01 | BLOCKING | `demote_payload` has conflicting state-order wording. The design says to keep the current validation order with `descriptor is hot` before enqueue, then also says an already `demoting` payload must be treated as an in-flight rejection. In current code, `server-cache-hybrid.cpp` checks `residency != hot` before the `demoting` check, so the in-flight branch is unreachable and logs a generic residency failure. | Make the Stage 22 design explicit: either move the `demoting` check before the generic hot-state rejection, or state the exact diagnostic/counter outcome for `demoting` under the generic rejection. The chosen behavior must have a focused unit assertion. |
| F-22-DR-02 | BLOCKING | Target/draft pair ownership is documented as an invariant, but TP-22-UT1..UT6 do not require any `target_and_draft` demotion completion case. Stage 5 architecture and requirements R9/R10 require paired target/draft payloads to move, fail, and remain owned together across hot/cold transitions. Stage 21 uses an MTP fixture, so this is not optional coverage. | Add at least one Stage 22 test requirement that exercises target-and-draft demotion completion, including duplicate success idempotence or failure handling, and asserts pair-state, target bytes, draft bytes, counters, and owner view sync stay coherent. |
| F-22-DR-03 | NON-BLOCKING | `cache-handling-phase21-implementation.md` still contains D21-EXEC-08 saying Stage 22 design authoring was blocked and the design document was not on disk. Current top status, tracker row, and document index supersede that note. Because it lives in the Manager decision history, it is historical rather than a current blocking contradiction. | Manager or next documentation owner should add a short supersession note if this history keeps confusing later reviews. Do not treat D21-EXEC-08 as the active Stage 22 gate state. |

### Decisions

- F-21-RERUN-02 is correctly identified as the Stage 22 trigger.
- F-21-EXEC-01 and F-21-RERUN-01 are explicitly preserved in scope,
  tests, and rollback.
- Public endpoint schema, CLI flags, and public metric names stay stable.
- Idempotent completion semantics are directionally correct, but the two
  blocking findings above must be corrected before Manager gate approval.

### Handoff

Next owner: Architect re-review.

Gate state: corrected, pending re-review. Manager design gate must not open
implementation planning until Architect re-review closes F-22-DR-01 and
F-22-DR-02.

## Design correction record 01

Date: 2026-06-18
Owner: Architect

- F-22-DR-01 corrected: `demote_payload` now requires the already-demoting
  in-flight rejection before generic non-hot rejection, with TP-22-UT8.
- F-22-DR-02 corrected: TP-22-UT7 now requires target/draft demotion completion
  coverage, including pair state, target bytes, draft bytes, counters, and owner
  view sync.
- Handoff state: closed by design re-review gate 01.

## Design re-review gate 01
VERDICT: PASS
Date: 2026-06-18
Reviewer: Architect
Scope: correction record 01, current demotion code, and current test hooks.
Findings: F-22-DR-01 and F-22-DR-02 are closed; no new blocker found.
Decisions: TP-22-UT8 binds demoting-before-hot rejection; TP-22-UT7 binds target/draft completion idempotence.
Handoff: Manager may decide whether to open implementation planning.

## Manager design gate

VERDICT: PASS
Date: 2026-06-18
Owner: Manager

Decision D22-DESIGN-01: accept the corrected Stage 22 design. Architect
re-review gate 01 closed F-22-DR-01 and F-22-DR-02 with no new blockers.

Decision D22-DESIGN-02: Stage 22 implementation planning is open. The plan must
preserve F-21-EXEC-01 and F-21-RERUN-01, implement the corrected demoting
validation order, include target/draft completion coverage, and keep public CLI,
endpoint schema, and public metric names stable.

Handoff: Developer owns implementation planning. No production refactor work may
start until implementation-plan review and Manager implementation-plan gate pass.
