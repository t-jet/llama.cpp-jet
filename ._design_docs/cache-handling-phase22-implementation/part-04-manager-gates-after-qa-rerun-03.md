# Stage 22 manager gates after QA rerun 03

## Manager D22-RERUN-03-F1 bug-fix review gate

VERDICT: REWORK
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-03-fixes.md](../.test_reports/stage22-heavy-20260619-03-fixes.md)

Decision D22-RERUN-FIX-03: do not open QA rerun yet. Architect review found two
blocking issues in the D22-RERUN-03-F1 fix.

Decision D22-RERUN-FIX-04: Developer must correct
F-D22-RERUN-03-F1-AR-01. The checkpoint-dependent exact fallback must be limited
to prior checkpoint state plus restore-visible resident exact blob unless
Manager approves a broader fallback contract.

Decision D22-RERUN-FIX-05: Developer must correct
F-D22-RERUN-03-F1-AR-02. The metadata-only source path must guard checkpoint
metadata validation by selected payload kind, or the fix evidence must prove
exact fallback cannot reach that path.

Decision D22-RERUN-FIX-06: correction evidence must preserve the existing
D22-RERUN-03-F1 goal: req-009 exact entry remains lookup-visible after
demotion or eviction work, req-008 and req-010 behavior stays preserved, and
forbidden warning families remain absent.

Handoff: Developer owns correction. Architect re-review follows Developer
evidence.

## Manager D22-RERUN-03-F1 correction gate

VERDICT: PASS
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-03-fixes.md](../.test_reports/stage22-heavy-20260619-03-fixes.md)

Decision D22-RERUN-FIX-07: accept the D22-RERUN-03-F1 correction for QA rerun.
Architect correction re-review passed with no findings. F-D22-RERUN-03-F1-AR-01
and F-D22-RERUN-03-F1-AR-02 are closed.

Decision D22-RERUN-FIX-08: QA rerun scope is the Stage 21 HV-chat-feasible
profile with the D22-RERUN-03-F1 corrected binary. Required checks are req-008,
req-009, and req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in
demoting state`; zero `payload_unavailable`; zero `cannot restore yet`; redacted
prompt evidence; and stable public metric names.

Decision D22-RERUN-FIX-09: no runner, fixture, endpoint schema, CMake, or public
metric-name change is authorized for the rerun. Any runner-health workaround
must be documented as execution setup, not product behavior.

Handoff: QA owns the D22-RERUN-03-F1 heavy rerun. Developer test-results review
follows the QA report.

## Manager QA rerun gate 04

VERDICT: FAIL - test-results review required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-04.md](../.test_reports/stage22-heavy-20260619-04.md)

Decision D22-RERUN-10: classify QA rerun 04 as a failed execution against the
active acceptance gate. The D22-RERUN-03-F1 correction did not close the
required req-009 exact-repeat miss. Req-008 and req-010 restore with
`cache_n=26`; req-009 returns `cache_n=0` and JSONL `exact_entry_absent`.

Decision D22-RERUN-11: the prior warning fixes remain accepted. QA rerun 04
shows zero `descriptor not found`, zero `not in demoting state`, zero
`payload_unavailable`, and zero `cannot restore yet`.

Decision D22-RERUN-12: Developer owns the QA rerun 04 test-results review.
Developer must classify the unchanged req-009 `exact_entry_absent`, state
whether D22-RERUN-03-F1 root cause was incomplete or a new root cause is present,
and define focused retest scope. No bounded exception is approved.

Handoff: Developer owns test-results review for
`stage22-heavy-20260619-04.md`.

## Manager test-results review gate 04

VERDICT: FAIL - bug-fix loop required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-04-developer-review.md](../.test_reports/stage22-heavy-20260619-04-developer-review.md)

Decision D22-RERUN-13: accept Developer classification of req-009
`exact_entry_absent` as product bug D22-RERUN-04-F1. The failure is not prompt
drift, not a harness mismatch, and not accepted bounded behavior.

Decision D22-RERUN-14: treat D22-RERUN-03-F1 as incomplete rather than closed.
The heavy rerun did not exercise exact-blob fallback:
`cache_exact_blob_restores_total` stayed zero, and the failure stayed in
lookup visibility with `exact_entry_absent`.

Decision D22-RERUN-15: open the next Developer bug-fix loop. The fix must
target the multi-entry heavy sequence where req-008 demotion or eviction work
removes or hides the req-009 exact entry before lookup. Preserve req-008 and
req-010 hits, preserve zero forbidden warning families, and avoid public
runner, fixture, schema, CMake, or metric-name changes.

Decision D22-RERUN-16: fix evidence must add focused regression coverage for
the A/B/C sequence: save multiple exact originals, create hot-budget pressure,
restore A so demotion or eviction work runs, then assert B remains exact
lookup-visible and restores. Evidence must include `test-cache-controller`,
`llama-server`, updated fix report, and clean `git diff --check`.

Handoff: Developer owns the D22-RERUN-04-F1 product fix. Architect review
follows Developer evidence.

## Manager D22-RERUN-04-F1 bug-fix gate

VERDICT: PASS
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-04-fixes.md](../.test_reports/stage22-heavy-20260619-04-fixes.md)

Decision D22-RERUN-FIX-10: accept the D22-RERUN-04-F1 fix for QA rerun.
Architect bug-fix review passed with no findings. The accepted fix keeps
demotion-retained entries in the prefix lookup index while removing them from
the LRU eviction index.

Decision D22-RERUN-FIX-11: QA rerun scope is the Stage 21 HV-chat-feasible
profile with the D22-RERUN-04-F1 binary. Required checks are req-008, req-009,
and req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in demoting
state`; zero `payload_unavailable`; zero `cannot restore yet`; redacted prompt
evidence; stable public metric names; and no runner, fixture, schema, CMake, or
public metric-name changes.

Handoff: QA owns the D22-RERUN-04-F1 heavy rerun. Developer test-results review
follows the QA report.

## Manager QA rerun gate 05

VERDICT: FAIL - test-results review required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-05.md](../.test_reports/stage22-heavy-20260619-05.md)

Decision D22-RERUN-17: accept QA rerun 05 as a valid failed execution against
the active acceptance gate. The D22-RERUN-04-F1 fix did not close the required
req-009 exact-repeat miss. Req-008 and req-010 restore with `cache_n=26`;
req-009 returns `cache_n=0` and JSONL `exact_entry_absent`.

Decision D22-RERUN-18: the prior warning fixes remain accepted. QA rerun 05
shows zero `descriptor not found`, zero `not in demoting state`, zero
`payload_unavailable`, and zero `cannot restore yet`. Clean build,
`test-cache-controller` 110/110, redacted prompt evidence, and metric-family
checks passed.

Decision D22-RERUN-19: Developer owns the QA rerun 05 test-results review.
Developer must classify the unchanged req-009 `exact_entry_absent`, state
whether D22-RERUN-04-F1 root cause was incomplete or a new root cause is
present, and define the focused retest scope. No bounded exception is approved.

Handoff: Developer owns test-results review for
`stage22-heavy-20260619-05.md`.

## Manager test-results review gate 05

VERDICT: FAIL - bug-fix loop required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-05-developer-review.md](../.test_reports/stage22-heavy-20260619-05-developer-review.md)

Decision D22-RERUN-20: accept Developer classification of req-009
`exact_entry_absent` as product bug D22-RERUN-05-F1. The failure is not prompt
drift, not a runner mismatch, and not accepted bounded behavior.

Decision D22-RERUN-21: treat D22-RERUN-04-F1 as incomplete. The prefix-index
retention fix covered one subcase, but the live A/B/C heavy sequence still
hides or removes B before exact lookup. `cache_exact_blob_restores_total`
stayed zero, so exact fallback still was not reached.

Decision D22-RERUN-22: open the next Developer bug-fix loop. The fix must keep
B discoverable through the same lookup path the server uses after A's demotion
or eviction work runs. It must preserve req-008 and req-010 hits, preserve zero
forbidden warning families, and avoid runner, fixture, endpoint schema, CMake,
or public metric-name changes.

Decision D22-RERUN-23: fix evidence must add or strengthen focused regression
coverage for the rerun 05 shape: save A/B/C, apply near/new hot-budget pressure,
restore A, then assert B remains discoverable through prefix and branch lookup
with correct namespace, token span, boundary metadata, payload ownership, and
restore-visible resident exact state. Evidence must include
`test-cache-controller`, `llama-server`, updated fix report, and clean
`git diff --check`.

Handoff: Developer owns the D22-RERUN-05-F1 product fix. Architect review
follows Developer evidence.

## Manager D22-RERUN-05-F1 bug-fix gate

VERDICT: PASS
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-05-fixes.md](../.test_reports/stage22-heavy-20260619-05-fixes.md)

Decision D22-RERUN-FIX-12: accept the D22-RERUN-05-F1 fix for QA rerun.
Architect bug-fix review passed with no findings. The accepted fix filters
branch-forest eviction candidates through LRU membership, so
demotion-retained entries stay lookup-visible but cannot be selected again by
later hot-budget passes after LRU removal.

Decision D22-RERUN-FIX-13: QA rerun scope is the Stage 21 HV-chat-feasible
profile with the D22-RERUN-05-F1 binary. Required checks are req-008, req-009,
and req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in demoting
state`; zero `payload_unavailable`; zero `cannot restore yet`; redacted prompt
evidence; stable public metric names; and no runner, fixture, schema, CMake, or
public metric-name changes.

Handoff: QA owns the D22-RERUN-05-F1 heavy rerun. Developer test-results review
follows the QA report.

## Manager QA rerun gate 06

VERDICT: FAIL - test-results review required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-06.md](../.test_reports/stage22-heavy-20260619-06.md)

Decision D22-RERUN-24: accept QA rerun 06 as a valid failed execution against
the active acceptance gate. The D22-RERUN-05-F1 fix did not close the heavy
gate. Req-008 restored with `cache_n=26`; req-009 and req-010 returned
`cache_n=0` with JSONL `payload_unavailable`.

Decision D22-RERUN-25: the failure signature changed from rerun 05. The rerun
now has two `descriptor not found` promotion-completion warnings and two
`payload_unavailable` misses. `not in demoting state` and `cannot restore yet`
remain zero. Clean build, `test-cache-controller` 110/110, redacted prompt
evidence, stable metric-family count, and no runner/fixture/schema/CMake/public
metric-name changes passed.

Decision D22-RERUN-26: Developer owns the QA rerun 06 test-results review.
Developer must classify req-009 and req-010 `payload_unavailable`, determine
whether D22-RERUN-05-F1 exposed a promotion-completion ownership bug or
regressed an accepted invariant, and define focused retest scope. No bounded
exception is approved.

Handoff: Developer owns test-results review for
`stage22-heavy-20260619-06.md`.

## Manager test-results review gate 06

VERDICT: FAIL - bug-fix loop required
Date: 2026-06-19
Owner: Manager

Source report:

- [stage22-heavy-20260619-06-developer-review.md](../.test_reports/stage22-heavy-20260619-06-developer-review.md)

Decision D22-RERUN-27: accept Developer classification of req-009 and req-010
`payload_unavailable` as product bugs D22-RERUN-06-F1 and D22-RERUN-06-F2.
Accept the two `promotion completion: descriptor not found` warnings as product
bug D22-RERUN-06-F3. No bounded exception is approved.

Decision D22-RERUN-28: treat the failure as a promotion-completion
ownership/lifetime bug exposed by D22-RERUN-05-F1, not as a rollback of the
accepted demotion invariant. Rerun 06 reaches exact candidates for req-009 and
req-010, queues promotion for cold payload ids 4 and 6, then loses descriptor
ownership by completion time.

Decision D22-RERUN-29: open the next Developer bug-fix loop. The fix must
preserve cold-payload descriptor ownership while promotion is in flight, or make
promotion completion idempotent without forbidden descriptor-not-found warnings.
It must preserve req-008 behavior, keep lookup visibility from D22-RERUN-05-F1,
and avoid runner, fixture, endpoint schema, CMake, or public metric-name
changes.

Decision D22-RERUN-30: fix evidence must add focused regression coverage for
cold promotion completion after exact-repeat lookup finds a cold checkpoint
payload. Evidence must cover payload ids selected for promotion, descriptor
lifetime or idempotent completion behavior, retry/restore behavior, unchanged
public surface, `test-cache-controller`, `llama-server`, updated fix report, and
clean `git diff --check`.

Handoff: Developer owns the D22-RERUN-06 product fix. Architect review follows
Developer evidence.

## Manager D22-RERUN-06 bug-fix gate

VERDICT: PASS
Date: 2026-06-20
Owner: Manager

Source report:

- [stage22-heavy-20260619-06-fixes.md](../.test_reports/stage22-heavy-20260619-06-fixes.md)

Decision D22-RERUN-FIX-14: accept the D22-RERUN-06 fix for QA rerun. Architect
bug-fix review passed with no findings. The accepted fix preserves `promoting`
descriptors through queued promotion completion and adds bounded idempotent
handling for duplicate or stale promotion completion states.

Decision D22-RERUN-FIX-15: QA rerun scope is the Stage 21 HV-chat-feasible
profile with the D22-RERUN-06 binary. Required checks are req-008, req-009, and
req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in demoting
state`; zero `payload_unavailable`; zero `cannot restore yet`; redacted prompt
evidence; stable public metric names; and no runner, fixture, schema, CMake, or
public metric-name changes.

Handoff: QA owns the D22-RERUN-06 heavy rerun. Developer test-results review
follows the QA report.

## Manager QA rerun gate 07

VERDICT: FAIL - test-results review required
Date: 2026-06-20
Owner: Manager

Source report:

- [stage22-heavy-20260620-07.md](../.test_reports/stage22-heavy-20260620-07.md)

Decision D22-RERUN-31: accept QA rerun 07 as a valid failed execution against
the active acceptance gate. D22-RERUN-06 fixed the descriptor-not-found warning
family, but the heavy gate still failed. Req-008 restored with `cache_n=26`;
req-009 returned `cache_n=0` with JSONL `payload_unavailable`; req-010 had a
request send error and JSONL `payload_unavailable`.

Decision D22-RERUN-32: the remaining failure is not the same as rerun 06.
`descriptor not found`, `not in demoting state`, and `cannot restore yet` are
zero. `payload_unavailable` remains non-zero, and after-metrics scrape failed
because the server exited. Clean build, `test-cache-controller` 111/111, and
redacted prompt evidence passed. QA made no runner, fixture, schema, CMake,
product-code, or public metric-name changes.

Decision D22-RERUN-33: Developer owns the QA rerun 07 test-results review.
Developer must classify req-009 and req-010 `payload_unavailable`, classify the
req-010 request error/server exit, state whether the D22-RERUN-06 fix is
incomplete or a new restore/promote retry behavior is needed, and define the
focused retest scope. No bounded exception is approved.

Decision D22-RERUN-34: the next Architect review must include a Stage 22
fragility review. Architect must review the Stage 22 fix history from
D22-EXEC-01 through the current fix, decide whether the implementation or
architecture needs a simpler ownership model or stronger invariants, and record
any required design or implementation changes before QA rerun authorization.

Handoff: Developer owns test-results review for
`stage22-heavy-20260620-07.md`.
