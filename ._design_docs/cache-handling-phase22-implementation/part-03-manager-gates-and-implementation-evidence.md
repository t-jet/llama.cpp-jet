# Stage 22 manager gates and implementation evidence

## Architect implementation-plan review gate 01

VERDICT: PASS
Date: 2026-06-18
Reviewer: Architect
Scope: implementation plan only; no production code or tests reviewed for acceptance as changed.

### Checks

| Area | Result | Notes |
| --- | --- | --- |
| D22-DESIGN-01/02 | PASS | Plan starts from accepted corrected design and keeps implementation closed until this review plus Manager implementation-plan gate pass. |
| F-22-DR-01 closure | PASS | Step 3 and TP-22-UT8 require the `demoting` in-flight branch before generic non-hot rejection. Current code still has the old order, so the planned change is real and testable. |
| F-22-DR-02 closure | PASS | TP-22-UT7 requires target/draft demotion completion plus duplicate success idempotence, pair state, target bytes, draft bytes, counters, and owner-view checks. |
| Stage 21 invariants | PASS | TP-21-UT1..UT6 remain binding, named, and required as visible PASS evidence. Plan preserves F-21-EXEC-01 prompt-only exact repeat and F-21-RERUN-01 demoting-budget behavior. |
| Target/draft ownership | PASS | Stage 5 pairing is listed as inherited baseline, helper contract keeps descriptor ownership central, and TP-22-UT7 covers paired completion. |
| Public surface stability | PASS | Plan names no CLI, endpoint schema, public metric, runner, fixture, or CMake changes. Internal diagnostics may be added only without public metric-name changes. |
| Testability and feasibility | PASS | Existing hooks cover residency, demotion start, cold store setup, queue control, and Stage 21 tests. Plan allows only a minimal test-only hook if completion injection or inspection is missing. |
| Evidence plan | PASS | Focused build, `test-cache-controller.exe`, `llama-server`, exact Stage 21 and Stage 22 PASS lines, binary mtimes, warnings, counters, and `git diff --check` are required. QA rerun remains after implementation review and Manager gate. |
| Rollback | PASS | Rollback is file-scoped to Stage 22 edits and explicitly preserves F-21-EXEC-01 and F-21-RERUN-01. |

### Findings

No blocking, non-blocking, or informational findings opened in this review.

### Decisions

- Implementation plan is narrow enough for current `server-cache-hybrid.cpp` and `test-cache-controller.cpp`.
- Helper names may vary, but descriptor-source-of-truth, hot-map release timing, owner-view sync, and idempotent completion semantics are binding.
- Developer must not use async timing alone as proof of duplicate/stale completion handling; TP-22-UT2, TP-22-UT3, TP-22-UT7, and TP-22-UT8 need deterministic assertions.

### Handoff

Next owner: Manager for implementation-plan gate.

Gate state: PASS. Manager may decide whether to open Stage 22 implementation.

## Manager implementation-plan gate

VERDICT: PASS
Date: 2026-06-18
Owner: Manager

Decision D22-IMPLPLAN-01: accept the Stage 22 implementation plan. Architect
implementation-plan review gate 01 passed with no findings.

Decision D22-IMPLPLAN-02: Developer implementation is open. Implementation must
stay within `tools/server/server-cache-hybrid.cpp`, `tests/test-cache-controller.cpp`,
and this implementation log unless a later review identifies a documented need.

Decision D22-IMPLPLAN-03: Implementation evidence must include TP-22-UT1..UT8,
visible TP-21 invariant PASS lines, `test-cache-controller.exe`, `llama-server`,
and clean `git diff --check` output before implementation review.

Handoff: Developer owns implementation in a fresh session. Architect
implementation review follows Developer evidence.

## Developer implementation evidence

Date: 2026-06-18
Verdict: PASS for focused Stage 22 implementation evidence; ready for Architect
implementation review.

Changed files: `tools/server/server-cache-hybrid.cpp`, `tests/test-cache-controller.cpp`, and this implementation log.

Implementation summary: `demote_payload` now checks `demoting` before generic non-hot rejection and records `in_progress`. `handle_demotion_completion` uses local helper logic equivalent to `sync_payload_owner_views`, `release_hot_payload_after_success`, and `complete_demoted_payload`. Success from `demoting` transitions once to `cold`; duplicate/stale completions are bounded and idempotent; failures revert to `hot` when hot bytes remain or mark `evicted` and zero resident bytes when hot bytes are gone.

Focused Stage 22 tests added and registered: `test_stage22_demotion_success_transitions_once`, `test_stage22_duplicate_success_idempotent`, `test_stage22_stale_success_after_evicted`,
`test_stage22_demotion_failure_with_hot_bytes_reverts`, `test_stage22_demotion_failure_without_hot_bytes_evicts`,
`test_stage22_target_draft_completion_idempotent`, and
`test_stage22_demote_already_demoting_in_progress`. TP-22-UT6 is satisfied by
directly registered TP-21-UT1..UT6 PASS lines, not by a wrapper.

Correction evidence: removed inert `test_stage22_stage21_invariant_pack`
registration. `cmake --build build-cov --config Release --target
test-cache-controller -j 4` exit 0. `.\build-cov\bin\Release\test-cache-controller.exe`
exit 0 with 104 tests PASS, visible TP-21 PASS lines for all six invariant
tests, and visible TP-22 PASS lines for seven focused Stage 22 tests.

Diff check: `git diff --check -- tests/test-cache-controller.cpp
._design_docs/cache-handling-phase22-implementation.md` exit 0, clean.

Line counts: `server-cache-hybrid.cpp` 4202, `test-cache-controller.cpp` 3777,
this file at 291 after evidence update. No public CLI, endpoint, metric,
fixture, runner, or CMake change. `tests/test-cache-controller.cpp` already had
pre-existing whitespace-only dirty diff before this session; Stage 22 edits are
the new focused test block and registration.

## Manager implementation gate

VERDICT: PASS
Date: 2026-06-19
Owner: Manager

Decision D22-IMPL-01: accept Stage 22 implementation after Architect
implementation re-review gate 01 PASS. F-22-IR-01 is closed by removing the
placeholder TP-22 wrapper and mapping TP-22-UT6 to direct TP-21-UT1..UT6 PASS
evidence.

Decision D22-IMPL-02: QA execution is open. QA must rerun the Stage 21
HV-chat-feasible profile with the Stage 22 binary, using the existing Stage 21
runner contract and Qwen3.6-27B-MTP fixture.

Decision D22-IMPL-03: QA acceptance checks are zero descriptor-not-found
warnings, zero demoting-state mismatch product warnings, exact-repeat req-008
through req-010 exact matches, redacted prompt evidence, stable public metric
names, and `cache_n > 0` for exact repeats unless QA records a Manager-approved
bounded cold-promotion latency result.

Handoff: QA owns fresh Stage 22 execution report. Developer test-results review
follows QA report.

## Manager QA execution gate

VERDICT: FAIL - bug-fix loop required
Date: 2026-06-19
Owner: Manager

Source reports:

- [stage22-heavy-20260619-01.md](../.test_reports/stage22-heavy-20260619-01.md)
- [stage22-heavy-20260619-01-developer-review.md](../.test_reports/stage22-heavy-20260619-01-developer-review.md)

Decision D22-EXEC-01: classify TP-21-HV1 as product bug and open Developer
bug-fix loop. QA proved the Stage 22 implementation removed the two prior
warning failures (`descriptor not found` and `not in demoting state` both zero),
but req-008, req-009, and req-010 still found exact matches and returned
`cache_n=0` with `payload_unavailable`.

Decision D22-EXEC-02: no bounded cold-promotion latency exception is approved.
The current acceptance contract still requires exact repeats to produce
`cache_n > 0`. Any exception would need a separate Manager decision with retry
window, allowed miss count, and evidence rules.

Decision D22-EXEC-03: async changes are not mandated. The user noted async
behavior as a thinking hint only. Developer may investigate timing and residency
ordering, but Architect must independently decide during bug-fix review whether
any async part of the proposed solution is necessary.

Decision D22-EXEC-04: expand the bug-fix write scope to include
`tools/server/server-context.cpp`. Developer investigation found the remaining
exact-repeat miss reaches a valid match, then `try_restore_from_cache` rejects
`payload_residency_state::demoting` before restore validation. That restore
decision is outside `server-cache-hybrid.cpp`, so `server-context.cpp` is now in
scope for the minimal fix. The fix must still preserve the Stage 22 design
constraints and avoid public CLI, endpoint schema, runner, fixture, CMake, or
public metric-name changes unless a later review explicitly requires them.

Handoff: Developer owns the bug fix. Architect bug-fix review and QA rerun
follow the fix evidence.

## Manager bug-fix gate

VERDICT: PASS
Date: 2026-06-19
Owner: Manager

Decision D22-FIX-01: accept the D22-EXEC-01 bug fix for QA rerun. Architect
bug-fix review passed with no findings and explicitly decided no async change is
required. The accepted fix permits demoting payload restore only while hot bytes
remain present, and preserves cold/promoting unavailable behavior.

Decision D22-FIX-02: QA rerun scope is the Stage 21 HV-chat-feasible profile
with the Stage 22 bug-fix binary. Required checks are req-008, req-009, and
req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in demoting
state`; no exact-repeat `payload_unavailable` while hot bytes remain; redacted
prompt evidence; and stable public metric names.

Handoff: QA owns the D22-EXEC-01 focused heavy rerun.

## Manager QA rerun gate 02

VERDICT: FAIL - bug-fix loop required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-02.md](../.test_reports/stage22-heavy-20260619-02.md)

Decision D22-RERUN-01: classify the D22-EXEC-01 focused heavy rerun as a
remaining product bug. The accepted bug fix partly works: req-008 and req-010
restore from demoting residency with `cache_n=26`, and the old
`payload_unavailable` exact-repeat miss is gone. The stage still fails because
req-009 returns `cache_n=0` and the rerun records four
`descriptor not found` demotion-completion warnings.

Decision D22-RERUN-02: no bounded exception is approved. The active acceptance
contract still requires req-008, req-009, and req-010 to produce `cache_n > 0`
and requires zero `descriptor not found` warnings.

Decision D22-RERUN-03: Developer owns the next bug-fix iteration. The fix must
preserve the D22-EXEC-01 improvement (demoting+hot exact restores allowed,
cold/promoting still unavailable), keep public CLI, endpoint, fixture, runner,
CMake, and public metric names stable, and add focused regression evidence for
the descriptor lifetime path that produced payload ids 1, 2, 5, and 6 warnings.

Required next gates:

1. Developer updates the existing D22 fix report or creates the next paired
   fixes report with root cause, code scope, focused tests, build evidence, and
   `git diff --check`.
2. Architect reviews the new fix in a fresh session.
3. If Architect passes the fix, Manager opens another QA rerun of Stage 21
   HV-chat-feasible with the same Qwen3.6-27B-MTP fixture and acceptance checks.

Handoff: Developer owns D22-RERUN-01 bug fix. Stage 21 remains paused until
Stage 22 produces a clean QA rerun or Manager records a different explicit
closure decision.

## Manager D22-RERUN-01 bug-fix gate

VERDICT: PASS
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-02-fixes.md](../.test_reports/stage22-heavy-20260619-02-fixes.md)

Decision D22-RERUN-FIX-01: accept the D22-RERUN-01 bug fix for QA rerun.
Architect bug-fix review passed with no findings. The accepted fix keeps
demoting exact lookup visible only when resident bytes and a hot payload record
remain, and tombstones removed demoting descriptors as zero-byte `evicted`
records so queued completion handling does not lose ownership state.

Decision D22-RERUN-FIX-02: QA rerun scope is the Stage 21 HV-chat-feasible
profile with the D22-RERUN-01 binary. Required checks are req-008, req-009, and
req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in demoting
state`; no exact-repeat `payload_unavailable`; no exact-repeat `cannot restore
yet`; redacted prompt evidence; and stable public metric names.

Handoff: QA owns the D22-RERUN-01 heavy rerun. Developer test-results review
follows the QA report.

## Manager QA rerun gate 03

VERDICT: FAIL - test-results review required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-03.md](../.test_reports/stage22-heavy-20260619-03.md)

Decision D22-RERUN-04: classify QA rerun 03 as a failed execution against the
active acceptance gate. The D22-RERUN-01 fix closed the descriptor warning
families: `descriptor not found`, `not in demoting state`, `payload_unavailable`,
and `cannot restore yet` are all zero. The stage still fails because req-009
returns `cache_n=0` and JSONL `exact_entry_absent`; req-008 and req-010 both
restore with `cache_n=26`.

Decision D22-RERUN-05: no bounded exception is approved. The active acceptance
contract still requires req-008, req-009, and req-010 to produce `cache_n > 0`.

Decision D22-RERUN-06: Developer owns the QA rerun 03 test-results review.
Developer must classify req-009 `exact_entry_absent`, assign owner, and state
the next retest scope. If this is a product bug, the next fix must preserve the
now-clean descriptor warning counts and the req-008/req-010 exact-repeat hits.

Handoff: Developer owns test-results review for
`stage22-heavy-20260619-03.md`.

## Manager test-results review gate 03

VERDICT: FAIL - bug-fix loop required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-03-developer-review.md](../.test_reports/stage22-heavy-20260619-03-developer-review.md)

Decision D22-RERUN-07: accept Developer classification of req-009
`exact_entry_absent` as product bug D22-RERUN-03-F1. The failure is not a
harness issue and no bounded behavior exception is approved.

Decision D22-RERUN-08: open the next Developer bug-fix loop. The fix must
preserve the clean D22-RERUN-01 warning state (`descriptor not found`, `not in
demoting state`, `payload_unavailable`, and `cannot restore yet` all zero) and
must preserve req-008 and req-010 exact-repeat hits.

Decision D22-RERUN-09: fix evidence must include focused regression coverage for
the req-009 pattern: multiple exact originals, one exact repeat that triggers
demotion or eviction work, then the next exact repeat remains lookup-visible and
restores with `cache_n > 0`. Evidence must include `test-cache-controller`,
`llama-server`, updated fix report, and clean `git diff --check`.

Handoff: Developer owns the D22-RERUN-03-F1 product fix. Architect bug-fix
review follows Developer evidence.
