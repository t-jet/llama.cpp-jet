# Stage 22 bug-fix and closure evidence summary

## D22-EXEC-01 bug-fix evidence

Report: [stage22-heavy-20260619-01-fixes.md](../.test_reports/stage22-heavy-20260619-01-fixes.md).

Developer fix evidence is PASS. Exact restore now allows a demoting descriptor
when the hot payload record is still present and validation succeeds. Demoting
without hot bytes remains unavailable. `test-cache-controller` and
`llama-server` built successfully, and `test-cache-controller.exe` passed
106/106 tests. Architect bug-fix review and Manager bug-fix gate passed.

## QA rerun 02

Report: [stage22-heavy-20260619-02.md](../.test_reports/stage22-heavy-20260619-02.md).

QA rerun 02 failed. The D22-EXEC-01 fix partly works: req-008 and req-010
restore with `cache_n=26`, and the old exact-repeat `payload_unavailable` miss
is gone. Stage 22 still cannot close because req-009 returns `cache_n=0` and
the rerun records four `descriptor not found` demotion-completion warnings.

## D22-RERUN-01 bug-fix evidence

Report: [stage22-heavy-20260619-02-fixes.md](../.test_reports/stage22-heavy-20260619-02-fixes.md).

Developer fix evidence is PASS. Exact lookup now treats demoting descriptors
with resident hot bytes as restore-visible. `remove_payload` keeps a demoting
descriptor tombstone as `evicted` instead of erasing it before a queued
completion can arrive, so completion takes the stale-success path instead of
logging descriptor-not-found. `test-cache-controller.exe` passed 108/108 tests.

## QA rerun 03

Report: [stage22-heavy-20260619-03.md](../.test_reports/stage22-heavy-20260619-03.md).
Developer review: [stage22-heavy-20260619-03-developer-review.md](../.test_reports/stage22-heavy-20260619-03-developer-review.md).

QA rerun 03 failed. D22-RERUN-01 fixed the descriptor lifetime warning family:
`descriptor not found`, `not in demoting state`, `payload_unavailable`, and
`cannot restore yet` are all zero. Stage 22 still cannot close because req-009
returns `cache_n=0` with JSONL `exact_entry_absent`; req-008 and req-010 return
`cache_n=26`.

## D22-RERUN-03-F1 bug-fix evidence

Report: [stage22-heavy-20260619-03-fixes.md](../.test_reports/stage22-heavy-20260619-03-fixes.md).

Developer fix evidence first received Architect REWORK for two blocking
findings: narrow exact fallback to prior checkpoint state plus restore-visible
resident exact blob, and guard checkpoint metadata precheck by selected payload
kind. The correction passed. Checkpoint-dependent candidate selection now keeps
a prior-checkpoint entry visible only when the exact blob is resident and
restore-visible, and metadata-only source validation runs checkpoint checks only
when the selected payload kind is checkpoint. `test-cache-controller.exe`
passed 109/109 tests.

## D22-RERUN-04 and D22-RERUN-05 evidence

QA rerun 04 and rerun 05 still failed req-009 with `exact_entry_absent` while
req-008 and req-010 restored with `cache_n=26`. D22-RERUN-04-F1 kept
demotion-retained entries in the prefix lookup index. D22-RERUN-05-F1 then
filtered branch-forest payload candidates through the LRU index, so
demotion-retained entries removed from LRU cannot be selected again by later
pressure passes while they remain lookup-visible through branch and prefix
paths. `test-cache-controller.exe` passed 110/110 tests.

## D22-RERUN-06 evidence

Report: [stage22-heavy-20260619-06-fixes.md](../.test_reports/stage22-heavy-20260619-06-fixes.md).

QA rerun 06 changed the failure to `payload_unavailable` for req-009 and
req-010, with two `promotion completion: descriptor not found` warnings.
D22-RERUN-06 preserved `promoting` descriptors while queued promotion
completion owns the lifetime and added bounded idempotent handling for duplicate
or stale promotion completion states. `test-cache-controller.exe` passed
111/111 tests.

## D22-RERUN-07 evidence

Report: [stage22-heavy-20260620-07-fixes.md](../.test_reports/stage22-heavy-20260620-07-fixes.md).

QA rerun 07 fixed descriptor-not-found warnings but still returned
`payload_unavailable` for req-009 and req-010; req-010 also had a request send
error after server exit. D22-RERUN-07 completes a queued cold checkpoint
promotion during checkpoint restore validation before `try_restore_from_cache()`
reaches the cold-payload miss branch. The focused regression is
`test_stage22_cold_checkpoint_exact_restore_promotes_in_request`; the prior
rerun 06 descriptor-lifetime regression remains covered. `test-cache-controller`
passed 112/112 tests.

Architect review passed with the required fragility review. It found Stage 22
fragile but did not require a blocking design rewrite before QA rerun.

## QA rerun 08 and closure

Report: [stage22-heavy-20260620-08.md](../.test_reports/stage22-heavy-20260620-08.md).
Developer review: [stage22-heavy-20260620-08-developer-review.md](../.test_reports/stage22-heavy-20260620-08-developer-review.md).

QA rerun 08 passed the heavy gate: req-008, req-009, and req-010 each restored
with `cache_n=26`; forbidden warning families were zero; prompt evidence was
redacted and bounded; request send errors were absent; and after-metrics was
available. Developer test-results review found no remaining Stage 22 heavy
acceptance product bug. Manager closure passed in
[Part 5](part-05-manager-gates-after-qa-rerun-07.md).

Non-gating follow-ups:

- D22-RERUN-08-FOLLOWUP-01: negative `llamacpp_cache_bytes{mode="hybrid"}`
  after-metrics value. Separate observability follow-up, not a Stage 22 closure
  blocker.
- Architect advisory: simplify restore/promote contract after QA into a named
  helper, documented timeout contract, and focused timeout, queue-full,
  promotion-failure, and process-stability tests.

Next owner: Manager/QA to resume Stage 21 heavy-tier closure using the Stage 22
fixed binary and QA rerun 08 evidence.
