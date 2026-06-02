# Stage 9 test-results review after rerun - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
QA report: [../.test_reports/test-report-20260601-06.md](../.test_reports/test-report-20260601-06.md)
Prior report: [../.test_reports/test-report-20260601-05.md](../.test_reports/test-report-20260601-05.md)
Fix record: [../.test_reports/test-report-20260601-05-fixes.md](../.test_reports/test-report-20260601-05-fixes.md)
Owner: Developer
Status: PASS with accepted evidence limits

## Scope

This review classifies the remaining non-pass rows from QA rerun report
20260601-06. It does not change product code.

Rows reviewed:

- Q102 BLOCKED
- Q103 BLOCKED
- Q109 SKIP

## Classification summary

| Row | QA status | Classification | Review decision |
| --- | --- | --- | --- |
| Q102 | BLOCKED | Accepted public-evidence limit | Public `/metrics` was scraped, but checkpoint admission stayed at zero, so checkpoint-active restore and hit labels could not be proven from the live server. Focused metric-shape evidence passed. |
| Q103 | BLOCKED | Accepted public-evidence limit | The MTP fixture loaded, produced draft activity, and created live context checkpoints, but the public request path did not admit a checkpoint because the checkpoint span lacked matching boundary metadata. |
| Q109 | SKIP | Expected skip | The fixture-unavailable row does not apply because QA found and used a local MTP fixture. |

## Q102 and Q103 review

The rerun fixed the earlier harness issue: the first overlong public prompt was
discarded, the second probe used a shorter prompt, and the server reached the
checkpoint creation path with the local Qwen3.5 MTP fixture.

The remaining blocker is the admission precondition, not restore behavior. QA
captured these facts:

- `/health` returned 200.
- Responses reported MTP draft activity with `draft_n=7`.
- The server created live context checkpoints.
- Save-side checkpoint admission was skipped with
  `missing checkpoint boundary metadata`.
- `cache_checkpoint_admissions_total{mode="hybrid"} 0`.
- `cache_checkpoint_admission_failures_total{mode="hybrid"} 1`.
- `cache_checkpoint_restores_total` and `cache_checkpoint_hits_total` stayed at
  the zero `profile="none"` rows.
- Repeated public requests returned `cache_n=0`.

This is not valid evidence of a checkpoint restore product failure. A checkpoint
restore or checkpoint hit cannot happen until a checkpoint descriptor is
accepted into the hybrid cache graph.

The code path matches the Stage 9 boundary policy. During checkpoint admission,
the descriptor takes the runtime checkpoint span from `slot.prompt.checkpoints`.
If prepared prompt boundaries are present, admission accepts only a matching
boundary span and checksum. If no boundary matches, validation rejects the
checkpoint before graph attachment. Focused coverage already checks both cases:
matching boundary admission succeeds, mismatched boundary admission fails, and
the no-boundary fallback can use token-span checksum evidence.

Classification:

- Q102: accepted public-evidence limit. Public metric shape exists, but the live
  fixture did not produce checkpoint-active rows because no checkpoint was
  admitted.
- Q103: accepted public-evidence limit. The local MTP fixture is usable for
  startup and draft activity, but this prompt/fixture path does not satisfy the
  checkpoint admission precondition.

## Q109 review

Q109 covers the fixture-unavailable path. It remains an expected skip because
QA found a local MTP fixture and used it for Q102/Q103 probing. No developer
action is required.

## Product-bug decision

No Stage 9 product bug remains from report 20260601-06.

Q112 is closed by the rerun: clean build, focused CTest, `test-step13-stage8`,
`test-cache-controller`, `test-step10-metrics`, `test-step12-branch-graph`, and
the Python public-surface checks all passed. Q100 is no longer blocked because
the Stage 8 cleanup ownership coverage completed in the focused rerun.

Q102 and Q103 can remain accepted blocked evidence limits for Stage 9 closure.
They should not hold the gate unless Manager requires live public
checkpoint-dependent restore evidence beyond the focused controller and metrics
coverage already accepted in implementation review.

## Closure recommendation

Stage 9 can proceed toward closure with Q102 and Q103 recorded as accepted
public-evidence limits.

Next owner: Manager.

Recommended gate action:

- Accept report 20260601-06 as closing the Q112 product bug and Q100 execution
  blocker.
- Carry Q102/Q103 as fixture/prompt evidence limits, not product bugs.
- Require a future QA or Developer follow-up only if the project decides that a
  live public checkpoint-dependent restore row is mandatory before closure.
