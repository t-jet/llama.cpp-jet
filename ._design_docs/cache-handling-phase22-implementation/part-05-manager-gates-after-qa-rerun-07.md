# Stage 22 manager gates after QA rerun 07

## Manager test-results review gate 07

VERDICT: FAIL - bug-fix loop required
Date: 2026-06-20
Owner: Manager

Source report:

- [stage22-heavy-20260620-07-developer-review.md](../.test_reports/stage22-heavy-20260620-07-developer-review.md)

Decision D22-RERUN-35: accept Developer classification of req-009 and req-010
`payload_unavailable` as product bugs D22-RERUN-07-F1 and D22-RERUN-07-F2.
Accept req-010 request send error and server exit before after-metrics scrape
as product stability bugs D22-RERUN-07-F3 and D22-RERUN-07-F4. No bounded
exception is approved.

Decision D22-RERUN-36: treat D22-RERUN-06 as incomplete for the active heavy
gate. The descriptor-not-found warning family remains fixed, but exact-repeat
cold promotion still returns `payload_unavailable` before the promoted payload
can be used. Req-010 also shows process stability risk after the same cold
promotion miss path.

Decision D22-RERUN-37: open the next Developer bug-fix loop. Unless Manager
approves a different restore contract later, the fix must make req-008, req-009,
and req-010 restore with `cache_n > 0` in the same heavy profile. It must keep
zero `descriptor not found`, zero `not in demoting state`, zero
`payload_unavailable`, and zero `cannot restore yet`; keep after-metrics
scrapable; and avoid runner, fixture, endpoint schema, CMake, product-surface,
or public metric-name changes.

Decision D22-RERUN-38: fix evidence must add focused regression coverage for
cold checkpoint exact restore when the selected payload is cold. Evidence must
cover promotion queueing, completion, the accepted restore or retry behavior,
req-010 process stability, after-metrics availability, unchanged public surface,
`test-cache-controller`, `llama-server`, updated fix report, and clean
`git diff --check`.

Decision D22-RERUN-39: the next Architect review must perform the fragility
review requested in D22-RERUN-34. Architect must review the Stage 22 fix
history from D22-EXEC-01 through the current fix, decide whether implementation
or architecture needs a simpler ownership model, stronger invariants, or an
explicit restore/promote retry contract, and record any required changes before
QA rerun authorization.

Handoff: Developer owns the D22-RERUN-07 product fix. Architect review follows
Developer evidence and must include D22-RERUN-39.

## Manager D22-RERUN-07 bug-fix gate

VERDICT: PASS
Date: 2026-06-20
Owner: Manager

Source report:

- [stage22-heavy-20260620-07-fixes.md](../.test_reports/stage22-heavy-20260620-07-fixes.md)

Decision D22-RERUN-FIX-16: accept the D22-RERUN-07 fix for QA rerun. Architect
bug-fix review passed with no findings. The accepted fix completes cold
checkpoint promotion during checkpoint restore validation before the restore
path reaches the cold-payload miss branch.

Decision D22-RERUN-FIX-17: accept Architect's Stage 22 fragility review for the
current gate. The review found Stage 22 fragile but did not require a blocking
design rewrite before QA rerun. The advisory follow-up is to simplify the
restore/promote contract after QA into a named helper, documented timeout
contract, and tests for timeout, queue-full, promotion failure, and
process-stability paths.

Decision D22-RERUN-FIX-18: QA rerun scope is the Stage 21 HV-chat-feasible
profile with the D22-RERUN-07 binary. Required checks are req-008, req-009, and
req-010 `cache_n > 0`; zero `descriptor not found`; zero `not in demoting
state`; zero `payload_unavailable`; zero `cannot restore yet`; redacted prompt
evidence; stable public metric names; after-metrics scrape available; and no
runner, fixture, schema, CMake, product-surface, or public metric-name changes.

Handoff: QA owns the D22-RERUN-07 heavy rerun. Developer test-results review
follows the QA report.

## Manager QA rerun gate 08

VERDICT: PASS - test-results review required
Date: 2026-06-20
Owner: Manager

Source report:

- [stage22-heavy-20260620-08.md](../.test_reports/stage22-heavy-20260620-08.md)

Decision D22-RERUN-40: accept QA rerun 08 as a valid passing execution for the
active heavy gate. Req-008, req-009, and req-010 each restored with
`cache_n=26`; forbidden warning families were zero; prompt evidence was
redacted and bounded; after-metrics scrape was available; and QA made no runner,
fixture, schema, CMake, product-code, product-surface, or public metric-name
changes.

Decision D22-RERUN-41: Developer owns test-results review for QA rerun 08.
Developer must confirm no product bugs remain for Stage 22 heavy acceptance and
classify the non-gating negative `llamacpp_cache_bytes{mode="hybrid"}` metric
observation as product bug, separate follow-up, or non-issue. No stage closure
is authorized until this review is recorded.

Handoff: Developer owns test-results review for
`stage22-heavy-20260620-08.md`.

## Manager test-results review gate 08

VERDICT: PASS
Date: 2026-06-20
Owner: Manager

Source report:

- [stage22-heavy-20260620-08-developer-review.md](../.test_reports/stage22-heavy-20260620-08-developer-review.md)

Decision D22-RERUN-42: accept Developer test-results review for QA rerun 08.
No remaining Stage 22 heavy acceptance product bug is found. Req-008, req-009,
and req-010 restored with `cache_n=26`; forbidden warning families were zero;
prompt evidence was redacted and bounded; request send errors were absent; and
after-metrics was available.

Decision D22-RERUN-43: classify negative
`llamacpp_cache_bytes{mode="hybrid"}` as separate non-gating product
observability follow-up D22-RERUN-08-FOLLOWUP-01. It is not a Stage 22 closure
blocker, but it should be triaged before relying on that byte gauge for capacity
or eviction reporting.

## Manager Stage 22 closure gate

VERDICT: PASS - Stage 22 closed
Date: 2026-06-20
Owner: Manager

Closure sources:

- [cache-handling-phase22-design.md](../cache-handling-phase22-design.md)
- [cache-handling-phase22-implementation.md](../cache-handling-phase22-implementation.md)
- [stage22-heavy-20260620-08.md](../.test_reports/stage22-heavy-20260620-08.md)
- [stage22-heavy-20260620-08-developer-review.md](../.test_reports/stage22-heavy-20260620-08-developer-review.md)

Decision D22-CLOSURE-01: close Stage 22. The accepted implementation preserves
the inherited Stage 21 prompt-only save and demotion-budget invariants, fixes
the demotion and promotion ownership gaps exposed by Stage 21/22 heavy reruns,
and passes the required HV-chat-feasible evidence with all three exact repeats
restoring.

Decision D22-CLOSURE-02: carry forward two non-blocking follow-ups:
D22-RERUN-08-FOLLOWUP-01 for the negative public cache-byte gauge, and
Architect's restore/promote simplification advisory. Neither blocks Stage 22
closure or Stage 21 resumption.

Decision D22-CLOSURE-03: Stage 21 may resume. The next Manager action is to
route Stage 21 heavy-tier closure using the Stage 22 fixed binary and QA rerun
08 evidence, then decide whether any remaining Stage 21 acceptance or closure
rows still need fresh execution.

Handoff: Stage 22 closed. Next owner: Manager for Stage 21 resume gate.
